import Foundation
import GRPC
import NIO
import NIOCore
import NIOHPACK
import NIOPosix
import XCTest

@testable import AnigmaDaemonCore

final class GRPCConnectivityTests: XCTestCase {

    var daemonProcess: Process?
    var group: EventLoopGroup?
    var channel: GRPCChannel?

    var executablePath: String {
        // Find the build directory. We assume we are running from the project root.
        let fm = FileManager.default
        let possiblePaths = [
            ".build/debug/anigmad",
            ".build/release/anigmad",
            "../.build/debug/anigmad",
            ".build/arm64-apple-macosx/debug/anigmad"
        ]

        for path in possiblePaths {
            if fm.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback to checking SWIFT_PBUILD_DIR if set
        if let buildDir = ProcessInfo.processInfo.environment["SWIFT_PBUILD_DIR"] {
            let path = "\(buildDir)/anigmad"
            if fm.fileExists(atPath: path) {
                return path
            }
        }

        return "./anigmad"
    }

    override func tearDown() {
        // Ensure process is killed
        if let process = daemonProcess, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        // Clean up channel and group
        try? channel?.close().wait()
        try? group?.syncShutdownGracefully()
    }

    // MARK: - Helpers

    func startDaemon() async throws -> (Process, String) {
        let exe = executablePath
        guard FileManager.default.fileExists(atPath: exe) else {
            throw XCTSkip("anigmad executable not found at \(exe)")
        }

        let tempDir = FileManager.default.temporaryDirectory
        let socketPath = tempDir.appendingPathComponent("anigmad-test-\(UUID()).sock").path
        let configPath = tempDir.appendingPathComponent("anigmad-test-config-\(UUID()).json").path

        let configContent = """
            {
                "daemon": {
                    "bind_host": "127.0.0.1",
                    "bind_port": 50051,
                    "unix_socket": "\(socketPath)",
                    "tcp_enabled": false,
                    "execution_mode": "in_process",
                    "max_clients": 100,
                    "shutdown_timeout_seconds": 30
                },
                "vault": {
                    "root_path": "\(tempDir.appendingPathComponent("vault-\(UUID())").path)",
                    "max_size_gb": 100,
                    "encryption_enabled": true
                },
                "governance": {
                    "policy_path": "/tmp/anigma/policies",
                    "strict_mode": false,
                    "audit_all_operations": true,
                    "receipt_store_mode": "in_memory"
                },
                "resources": {
                    "max_memory_mb": 1024,
                    "max_concurrent_jobs": 2,
                    "max_concurrent_gpu_jobs": 0,
                    "worker_processes": 1
                },
                "telemetry": {
                    "enabled": false,
                    "export_interval_seconds": 60,
                    "retention_days": 1
                }
            }
            """
        try configContent.write(toFile: configPath, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: exe)
        process.arguments = ["--config", configPath]

        // Redirect to file for debugging
        let logPath = "/tmp/anigma_daemon_test.log"
        FileManager.default.createFile(atPath: logPath, contents: nil)
        let fileHandle = FileHandle(forWritingAtPath: logPath)
        process.standardOutput = fileHandle
        process.standardError = fileHandle

        try process.run()
        self.daemonProcess = process

        // Wait for socket
        for _ in 0..<50 {
            if FileManager.default.fileExists(atPath: socketPath) {
                // Keep the file handle open? Process has it now.
                return (process, socketPath)
            }
            if !process.isRunning {
                XCTFail("Daemon crashed on startup. Check /tmp/anigma_daemon_test.log")
                throw NSError(domain: "DaemonCrash", code: -1)
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        // Timeout
        XCTFail("Daemon timed out creating socket. Check /tmp/anigma_daemon_test.log")
        throw NSError(domain: "DaemonTimeout", code: -1)
    }

    func makeClient(socketPath: String) throws -> AnigmaAnigmaServiceAsyncClient {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.channel = try GRPCChannelPool.with(
            target: .unixDomainSocket(socketPath),
            transportSecurity: .plaintext,
            eventLoopGroup: self.group!
        )
        return AnigmaAnigmaServiceAsyncClient(channel: self.channel!)
    }

    // MARK: - Tests

    func testDaemonConnectivity() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let request = AnigmaHealthRequest()
        let response = try await client.healthCheck(request)

        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.apiVersion, "1.0.0")
    }

    func testStatusRequiresSystemRead() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = []
        }
        let session = try await client.openSession(sessionReq)

        let statusReq = AnigmaStatusRequest.with {
            $0.ctx = AnigmaRequestContext.with {
                $0.clientID = session.clientID
                $0.capabilityToken = session.capabilityToken
                $0.nonce = UUID().uuidString
            }
        }

        do {
            _ = try await client.getStatus(statusReq)
            XCTFail("Expected status to require system.read scope")
        } catch {
            if let status = error as? GRPCStatus {
                XCTAssertEqual(status.code, .permissionDenied)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func testReceiptVerification() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        // 1. Get a session (to have a valid token)
        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["job.submit", "job.read", "audit.read"]
        }
        let session = try await client.openSession(sessionReq)

        // 2. Submit a job to generate a receipt
        let jobSpec = AnigmaJobSpec.with {
            $0.kind = "test.noop"
            $0.configCanonical = Data("{}".utf8)
        }

        let submitReq = AnigmaSubmitJobRequest.with {
            $0.ctx = AnigmaRequestContext.with {
                $0.clientID = session.clientID
                $0.capabilityToken = session.capabilityToken
                $0.nonce = UUID().uuidString
            }
            $0.spec = jobSpec
        }

        // This is where it failed previously
        let submitRes = try await client.submitJob(submitReq)

        // Check for error in response struct
        if submitRes.receiptHash.isEmpty {
            print("Submit failed with error code: \(submitRes.error.code)")
            print("Submit error message: \(submitRes.error.message)")
            XCTFail("Submission failed: \(submitRes.error.message)")
        }

        let receiptHash = submitRes.receiptHash
        XCTAssertFalse(receiptHash.isEmpty, "Submission should return a receipt hash")

        // Wait for job completion
        var finalReceiptHash: String?
        for _ in 0..<20 {  // Wait up to 2 seconds
            let statusReq = AnigmaGetJobStatusRequest.with {
                $0.ctx = submitReq.ctx
                $0.jobID = submitRes.jobID
            }
            let statusRes = try await client.getJobStatus(statusReq)
            if !statusRes.finalReceiptHash.isEmpty {
                finalReceiptHash = statusRes.finalReceiptHash
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        guard let targetHash = finalReceiptHash else {
            XCTFail("Job did not complete or emit final receipt hash")
            return
        }

        // 3. Get Receipt
        let getReceiptReq = AnigmaReceiptRequest.with {
            $0.ctx = submitReq.ctx
            $0.receiptHash = targetHash
        }
        let receiptRes = try await client.getReceipt(getReceiptReq)
        XCTAssertFalse(receiptRes.receiptCanonicalJson.isEmpty, "Should return receipt JSON")
        XCTAssertNil(
            receiptRes.error.code.isEmpty ? nil : receiptRes.error, "Should not return error")

        // 4. Verify Chain
        let verifyReq = AnigmaVerifyChainRequest.with {
            $0.ctx = submitReq.ctx
            $0.headReceiptHash = targetHash
        }
        let verifyRes = try await client.verifyChain(verifyReq)
        XCTAssertTrue(
            verifyRes.ok, "Chain verification should succeed. Message: \(verifyRes.message)")
        XCTAssertNil(verifyRes.error.code.isEmpty ? nil : verifyRes.error, "Should not error")
    }

    func testReceiptHashValidation() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["audit.read"]
        }
        let session = try await client.openSession(sessionReq)

        let invalidHash = "not-a-hash"
        let getReceiptReq = AnigmaReceiptRequest.with {
            $0.ctx = AnigmaRequestContext.with {
                $0.clientID = session.clientID
                $0.capabilityToken = session.capabilityToken
                $0.nonce = UUID().uuidString
            }
            $0.receiptHash = invalidHash
        }
        let receiptRes = try await client.getReceipt(getReceiptReq)
        XCTAssertEqual(receiptRes.error.code, "INVALID_RECEIPT_HASH")

        let verifyReq = AnigmaVerifyChainRequest.with {
            $0.ctx = getReceiptReq.ctx
            $0.headReceiptHash = invalidHash
        }
        let verifyRes = try await client.verifyChain(verifyReq)
        XCTAssertEqual(verifyRes.error.code, "INVALID_RECEIPT_HASH")
    }

    func testReceiptAccessRequiresAuditRead() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["job.submit", "job.read"]
        }
        let session = try await client.openSession(sessionReq)

        let jobSpec = AnigmaJobSpec.with {
            $0.kind = "test.noop"
            $0.configCanonical = Data("{}".utf8)
        }

        let submitReq = AnigmaSubmitJobRequest.with {
            $0.ctx = AnigmaRequestContext.with {
                $0.clientID = session.clientID
                $0.capabilityToken = session.capabilityToken
                $0.nonce = UUID().uuidString
            }
            $0.spec = jobSpec
        }

        let submitRes = try await client.submitJob(submitReq)
        if submitRes.receiptHash.isEmpty {
            XCTFail("Submission failed: \(submitRes.error.message)")
        }

        var finalReceiptHash: String?
        for _ in 0..<20 {
            let statusReq = AnigmaGetJobStatusRequest.with {
                $0.ctx = submitReq.ctx
                $0.jobID = submitRes.jobID
            }
            let statusRes = try await client.getJobStatus(statusReq)
            if !statusRes.finalReceiptHash.isEmpty {
                finalReceiptHash = statusRes.finalReceiptHash
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        guard let targetHash = finalReceiptHash else {
            XCTFail("Job did not complete or emit final receipt hash")
            return
        }

        let getReceiptReq = AnigmaReceiptRequest.with {
            $0.ctx = submitReq.ctx
            $0.receiptHash = targetHash
        }
        let receiptRes = try await client.getReceipt(getReceiptReq)
        XCTAssertEqual(receiptRes.error.code, "AUTH_DENIED")

        let verifyReq = AnigmaVerifyChainRequest.with {
            $0.ctx = submitReq.ctx
            $0.headReceiptHash = targetHash
        }
        let verifyRes = try await client.verifyChain(verifyReq)
        XCTAssertEqual(verifyRes.error.code, "AUTH_DENIED")
    }

    func testListArtifactsRequiresVaultRead() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["vault.write"]
        }
        let session = try await client.openSession(sessionReq)

        let listReq = AnigmaListRequest.with {
            $0.ctx = AnigmaRequestContext.with {
                $0.clientID = session.clientID
                $0.capabilityToken = session.capabilityToken
                $0.nonce = UUID().uuidString
            }
        }

        let listRes = try await client.listArtifacts(listReq)
        XCTAssertEqual(listRes.error.code, "AUTH_DENIED")
    }

    func testRetrieveArtifactMissingReturnsNotFound() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["vault.read"]
        }
        let session = try await client.openSession(sessionReq)

        let retrieveReq = AnigmaRetrieveRequest.with {
            $0.ctx = AnigmaRequestContext.with {
                $0.clientID = session.clientID
                $0.capabilityToken = session.capabilityToken
                $0.nonce = UUID().uuidString
            }
            $0.hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        }

        let stream = client.retrieveArtifact(retrieveReq)
        do {
            for try await _ in stream {
                XCTFail("Expected missing artifact to fail")
            }
            XCTFail("Expected retrieveArtifact to throw notFound")
        } catch {
            if let status = error as? GRPCStatus {
                XCTAssertEqual(status.code, .notFound)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func testRetrieveArtifactIncludesReceiptTrailer() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["vault.write", "vault.read"]
        }
        let session = try await client.openSession(sessionReq)

        let ctx = AnigmaRequestContext.with {
            $0.clientID = session.clientID
            $0.capabilityToken = session.capabilityToken
            $0.nonce = UUID().uuidString
        }

        let begin = AnigmaIngestRequest.with {
            $0.part = .begin(
                AnigmaIngestBegin.with {
                    $0.ctx = ctx
                    $0.mediaType = "text/plain"
                    $0.filenameHint = "trailer.txt"
                }
            )
        }
        let chunk = AnigmaIngestRequest.with {
            $0.part = .chunk(AnigmaIngestChunk.with { $0.data = Data("trailer".utf8) })
        }
        let ingestResponse = try await client.ingestArtifact([begin, chunk])

        let retrieveReq = AnigmaRetrieveRequest.with {
            $0.ctx = ctx
            $0.hash = ingestResponse.artifact.hash
        }
        let call = client.makeRetrieveArtifactCall(retrieveReq)
        for try await _ in call.responseStream {}
        let trailers = try await call.trailingMetadata
        let receiptHash = trailers.first(name: "x-anigma-receipt-hash")
        XCTAssertNotNil(receiptHash)
    }

    func testListArtifactsWithVaultReadSucceeds() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["vault.read"]
        }
        let session = try await client.openSession(sessionReq)

        let listReq = AnigmaListRequest.with {
            $0.ctx = AnigmaRequestContext.with {
                $0.clientID = session.clientID
                $0.capabilityToken = session.capabilityToken
                $0.nonce = UUID().uuidString
            }
        }

        let listRes = try await client.listArtifacts(listReq)
        XCTAssertTrue(listRes.error.code.isEmpty)
    }

    func testListArtifactsPagination() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["vault.write", "vault.read"]
        }
        let session = try await client.openSession(sessionReq)

        let ctx = AnigmaRequestContext.with {
            $0.clientID = session.clientID
            $0.capabilityToken = session.capabilityToken
            $0.nonce = UUID().uuidString
        }

        func ingest(_ text: String, filename: String) async throws {
            let begin = AnigmaIngestRequest.with {
                $0.part = .begin(
                    AnigmaIngestBegin.with {
                        $0.ctx = ctx
                        $0.mediaType = "text/plain"
                        $0.filenameHint = filename
                    }
                )
            }
            let chunk = AnigmaIngestRequest.with {
                $0.part = .chunk(AnigmaIngestChunk.with { $0.data = Data(text.utf8) })
            }
            _ = try await client.ingestArtifact([begin, chunk])
        }

        try await ingest("alpha", filename: "alpha.txt")
        try await ingest("bravo", filename: "bravo.txt")

        let firstList = AnigmaListRequest.with {
            $0.ctx = ctx
            $0.pageSize = 1
        }
        let firstRes = try await client.listArtifacts(firstList)
        XCTAssertEqual(firstRes.artifacts.count, 1)
        XCTAssertFalse(firstRes.nextPageToken.isEmpty)

        let secondList = AnigmaListRequest.with {
            $0.ctx = ctx
            $0.pageSize = 1
            $0.pageToken = firstRes.nextPageToken
        }
        let secondRes = try await client.listArtifacts(secondList)
        XCTAssertEqual(secondRes.artifacts.count, 1)
    }

    func testStreamJobEvents() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["job.submit", "job.read"]
        }
        let session = try await client.openSession(sessionReq)

        let jobSpec = AnigmaJobSpec.with {
            $0.kind = "test.noop"
            $0.configCanonical = Data("{}".utf8)
        }

        let submitReq = AnigmaSubmitJobRequest.with {
            $0.ctx = AnigmaRequestContext.with {
                $0.clientID = session.clientID
                $0.capabilityToken = session.capabilityToken
                $0.nonce = UUID().uuidString
            }
            $0.spec = jobSpec
        }
        let submitRes = try await client.submitJob(submitReq)
        XCTAssertFalse(submitRes.jobID.isEmpty)

        let streamReq = AnigmaStreamJobEventsRequest.with {
            $0.ctx = submitReq.ctx
            $0.jobID = submitRes.jobID
        }
        let stream = client.streamJobEvents(streamReq)
        var events: [AnigmaJobEvent] = []
        for try await event in stream {
            events.append(event)
        }

        XCTAssertTrue(
            events.contains { $0.type == "PROGRESS" && $0.message == "EXECUTING" },
            "Expected a progress EXECUTING event."
        )
        XCTAssertTrue(
            events.contains { $0.type == "STATE" && $0.message == "SUCCEEDED" },
            "Expected a terminal SUCCEEDED state event."
        )
    }

    func testIngestReceipts() async throws {
        let (_, socketPath) = try await startDaemon()
        let client = try makeClient(socketPath: socketPath)

        let sessionReq = AnigmaOpenSessionRequest.with {
            $0.requestedClientName = "test-client"
            $0.requestedScopes = ["vault.write", "audit.read"]
        }
        let session = try await client.openSession(sessionReq)

        let ctx = AnigmaRequestContext.with {
            $0.clientID = session.clientID
            $0.capabilityToken = session.capabilityToken
            $0.nonce = UUID().uuidString
        }

        let begin = AnigmaIngestRequest.with {
            $0.part = .begin(
                AnigmaIngestBegin.with {
                    $0.ctx = ctx
                    $0.mediaType = "text/plain"
                    $0.filenameHint = "hello.txt"
                }
            )
        }
        let chunk = AnigmaIngestRequest.with {
            $0.part = .chunk(AnigmaIngestChunk.with { $0.data = Data("hello".utf8) })
        }

        let response = try await client.ingestArtifact([begin, chunk])
        XCTAssertFalse(response.receiptHash.isEmpty)

        let receiptReq = AnigmaReceiptRequest.with {
            $0.ctx = ctx
            $0.receiptHash = response.receiptHash
        }
        let receiptRes = try await client.getReceipt(receiptReq)
        XCTAssertFalse(receiptRes.receiptCanonicalJson.isEmpty)
    }
}
