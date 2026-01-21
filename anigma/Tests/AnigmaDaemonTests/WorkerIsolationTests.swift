import XCTest

@testable import AnigmaDaemonCore

final class WorkerIsolationTests: XCTestCase {

    var executablePath: String {
        // Find the build directory. We assume we are running from the project root.
        // This is a bit hacky but common in SwiftPM tests for executables.
        let fm = FileManager.default
        let possiblePaths = [
            ".build/debug/anigmad",
            ".build/release/anigmad",
            "../.build/debug/anigmad"
        ]

        for path in possiblePaths {
            if fm.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback to searching in the standard swift build location if on macOS
        #if os(macOS)
            let processInfo = ProcessInfo.processInfo
            if let buildDir = processInfo.environment["SWIFT_PBUILD_DIR"] {
                let path = "\(buildDir)/anigmad"
                if fm.fileExists(atPath: path) {
                    return path
                }
            }
        #endif

        return "./anigmad"
    }

    func testWorkerExecutionEcho() async throws {
        // Skip if executable not found
        let exe = executablePath
        guard FileManager.default.fileExists(atPath: exe) else {
            print("Skipping test: anigmad executable not found at \(exe)")
            return
        }

        let jobId = "test-job-1"
        let payload = Data("payload".utf8)
        let spec = JobSpec(
            kind: "artifact.copy",
            configCanonical: Data(),
            inputs: [
                ArtifactRef(hash: "abc", mediaType: "text/plain", sizeBytes: 123)
            ]
        )
        let job = Job(id: jobId, spec: spec, clientId: "test-client")

        let worker = WorkerProcess(executablePath: exe)
        await worker.assignJob(jobId)
        let outputs = try await worker.execute(job: job, vaultData: ["abc": payload])

        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(outputs[0].mediaType, "text/plain")
        XCTAssertEqual(outputs[0].data, payload)
    }
}
