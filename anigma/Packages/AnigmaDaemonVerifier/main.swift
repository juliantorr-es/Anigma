import AnigmaDaemonCore
import CryptoKit
import Foundation
import GRPC
import NIOCore
import NIOPosix
import SwiftProtobuf

@main
struct AnigmaDaemonVerifier {
    static func main() async throws {
        print("--- Anigma Sidecar Daemon: Isolation Verification ---")

        // 1. Locate executable
        let exe = ".build/debug/anigmad"
        guard FileManager.default.fileExists(atPath: exe) else {
            print(
                "Error: anigmad executable not found at \(exe). Run 'swift build --product anigmad' first."
            )
            exit(1)
        }

        print("Using executable: \(exe)")

        // 2. Test 1: Basic Echo (Success)
        print("\n[TEST 1] Basic Echo...")
        let echoJob = Job(
            id: "echo-1",
            spec: JobSpec(
                kind: "artifact.copy", configCanonical: Data(),
                inputs: [
                    ArtifactRef(hash: "echo-test", mediaType: "text/plain", sizeBytes: 100)
                ]), clientId: "verifier")

        let worker1 = WorkerProcess(executablePath: exe)
        await worker1.assignJob("echo-1")
        do {
            let outputs = try await worker1.execute(
                job: echoJob,
                vaultData: ["echo-test": Data("echo".utf8)]
            )
            assert(outputs.count == 1)
            assert(!outputs[0].data.isEmpty)
            print("SUCCESS: Echo job completed.")
        } catch {
            print("FAILURE: Echo job failed: \(error)")
            exit(1)
        }

        // 3. Test 2: Memory Limit (Termination)
        print("\n[TEST 2] Memory Limit (Expected Termination)...")
        // Worker.swift sets limit to 256MB. We will try to allocate 500MB+
        let leakJob = Job(
            id: "leak-1",
            spec: JobSpec(kind: "test.memory_leak", configCanonical: Data(), inputs: []),
            clientId: "verifier")
        let worker2 = WorkerProcess(executablePath: exe)
        await worker2.assignJob("leak-1")
        do {
            _ = try await worker2.execute(job: leakJob, vaultData: [:])
            print("FAILURE: Memory leak job should have been terminated!")
            exit(1)
        } catch {
            print("SUCCESS: Worker terminated as expected: \(error)")
        }

        // 4. Test 3: CPU Time Limit (Termination)
        print("\n[TEST 3] CPU Time Limit (Expected Termination)...")
        // Worker.swift sets limit to 60s. We will try to burn CPU for 120s.
        // For the sake of this test tool, we'll check it faster if possible, but let's see.
        let cpuJob = Job(
            id: "cpu-1", spec: JobSpec(kind: "test.cpu_burn", configCanonical: Data(), inputs: []),
            clientId: "verifier")
        let worker3 = WorkerProcess(executablePath: exe)
        await worker3.assignJob("cpu-1")
        do {
            _ = try await worker3.execute(job: cpuJob, vaultData: [:])
            print("FAILURE: CPU burn job should have been terminated!")
            exit(1)
        } catch {
            print("SUCCESS: Worker terminated as expected: \(error)")
        }

        print("\n--- ALL ISOLATION TESTS PASSED ---")

        // 5. Test 4: Vault Streaming Integrity (100MB)
        print("\n[TEST 4] Vault Streaming Integrity (100MB)...")
        try await runStreamingTest(exe: exe)

        print("\n--- ALL TESTS PASSED ---")
    }

    static func runStreamingTest(exe: String) async throws {
        let socketPath = "/tmp/anigmad-test.sock"
        if FileManager.default.fileExists(atPath: socketPath) {
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        // Start daemon
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exe)
        process.arguments = ["--socket", socketPath]

        // Pipe stdout/stderr to suppress noise or for debugging
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        // Wait for socket
        var retries = 0
        while !FileManager.default.fileExists(atPath: socketPath) && retries < 10 {
            try await Task.sleep(for: .milliseconds(500))
            retries += 1
        }

        guard FileManager.default.fileExists(atPath: socketPath) else {
            print("FAILURE: Daemon failed to start on \(socketPath)")
            process.terminate()
            exit(1)
        }

        do {
            // Setup gRPC client
            let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let channel = try GRPCChannelPool.with(
                target: .unixDomainSocket(socketPath),
                transportSecurity: .plaintext,
                eventLoopGroup: group
            )

            let client = AnigmaAnigmaServiceAsyncClient(channel: channel)

            // Generate 100MB of data
            print("  Generating 100MB of test data...")
            let dataSize = 100 * 1024 * 1024
            var testData = Data(count: dataSize)
            testData.withUnsafeMutableBytes { ptr in
                arc4random_buf(ptr.baseAddress!, dataSize)
            }
            let originalHash = Data(SHA256.hash(data: testData)).map { String(format: "%02x", $0) }
                .joined()
            print("  Original hash: \(originalHash)")

            // Stream Ingest
            print("  Ingesting 100MB via streaming gRPC...")
            let uploadStart = Date()
            let response = try await ingestDataInChunks(client: client, data: testData)
            let uploadedHash = response.artifact.hash
            print("  Uploaded hash: \(uploadedHash)")
            XCTAssert(uploadedHash == originalHash, "Upload hash mismatch")

            let uploadDuration = Date().timeIntervalSince(uploadStart)
            print(
                "  Upload complete: \(String(format: "%.2f", uploadDuration))s (\(String(format: "%.2f", Double(dataSize) / 1024 / 1024 / uploadDuration)) MB/s)"
            )

            // Stream Retrieve
            print("  Retrieving 100MB via streaming gRPC...")
            let downloadStart = Date()
            var downloadedData = Data()
            var retrieveReq = AnigmaRetrieveRequest()
            retrieveReq.hash = uploadedHash

            for try await chunk in client.retrieveArtifact(retrieveReq) {
                downloadedData.append(chunk.data)
            }

            let downloadedHash = Data(SHA256.hash(data: downloadedData)).map {
                String(format: "%02x", $0)
            }.joined()
            print("  Downloaded hash: \(downloadedHash)")
            XCTAssert(downloadedHash == originalHash, "Download hash mismatch")

            let downloadDuration = Date().timeIntervalSince(downloadStart)
            print(
                "  Download complete: \(String(format: "%.2f", downloadDuration))s (\(String(format: "%.2f", Double(dataSize) / 1024 / 1024 / downloadDuration)) MB/s)"
            )

            print("SUCCESS: Streaming integrity verified.")

            try await channel.close().get()
            try await group.shutdownGracefully()

        } catch {
            print("FAILURE in streaming test: \(error)")
            process.terminate()
            throw error
        }

        process.terminate()
        process.waitUntilExit()
    }

    static func ingestDataInChunks(client: AnigmaAnigmaServiceAsyncClient, data: Data) async throws
        -> AnigmaIngestResponse {
        let (stream, continuation) = AsyncStream<AnigmaIngestRequest>.makeStream()

        let uploadTask = Task {
            try await client.ingestArtifact(stream)
        }

        var begin = AnigmaIngestBegin()
        begin.mediaType = "application/octet-stream"
        var reqBegin = AnigmaIngestRequest()
        reqBegin.begin = begin
        continuation.yield(reqBegin)

        let chunkSize = 64 * 1024
        var offset = 0
        while offset < data.count {
            let nextOffset = min(offset + chunkSize, data.count)
            var chunk = AnigmaIngestChunk()
            chunk.data = data.subdata(in: offset..<nextOffset)
            var reqChunk = AnigmaIngestRequest()
            reqChunk.chunk = chunk
            continuation.yield(reqChunk)
            offset = nextOffset
        }
        continuation.finish()

        return try await uploadTask.value
    }
}

// Minimal XCTAssert for the verifier
func XCTAssert(_ condition: Bool, _ message: String) {
    if !condition {
        print("ASSERTION FAILED: \(message)")
        exit(1)
    }
}
