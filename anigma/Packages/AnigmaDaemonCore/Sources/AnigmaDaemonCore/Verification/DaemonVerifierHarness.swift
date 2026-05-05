import AnigmaPrimitives
import CryptoKit
import DatabaseCore
import Foundation
import StorageCore

public struct DaemonVerifierHarnessConfiguration: Sendable {
    public let daemonExecutablePath: String
    public let evidenceDirectory: String?
    public let sessionPrefix: String
    public let socketPath: String

    public init(
        daemonExecutablePath: String,
        evidenceDirectory: String? = nil,
        sessionPrefix: String = "verify",
        socketPath: String? = nil
    ) {
        self.daemonExecutablePath = daemonExecutablePath
        self.evidenceDirectory = evidenceDirectory
        self.sessionPrefix = sessionPrefix
        // Alignment: Derive default socket path from runtime authority to avoid /tmp collisions
        self.socketPath = socketPath ?? "\(RuntimeAuthority.shared.workingDirectory)/.anigmad-verify.sock"
    }
}

public struct VerifierLaneBundle: Codable, Sendable {
    public let id: String
    public let bundleType: String
    public let description: String
    public let createdAt: String
    public let createdBy: String
    public let sessionId: String
    public let daemonExecutablePath: String
    public let socketPath: String
    public let artifactPaths: [String]
    public let matrix: [VerifierLaneMatrixDimension]
    public let maturityLevel: String
    public let summary: String
}

public enum DaemonVerifierHarness {
    public static func run(
        configuration: DaemonVerifierHarnessConfiguration
    ) async throws -> VerifierLaneBundle {
        let sessionId = "\(configuration.sessionPrefix)-\(UUID().uuidString.prefix(8))"
        let recorder = FileVerifierEvidenceRecorder(
            evidenceDirectory: configuration.evidenceDirectory,
            sessionId: sessionId
        )

        print("--- Anigma Sidecar Daemon: Isolation Verification ---")
        print("Session ID: \(sessionId)")
        print("Evidence Bundle: \(recorder.bundlePath(forSessionId: sessionId))")
        print("Evidence Log: \(recorder.eventLogPath(forSessionId: sessionId))")
        print("Using executable: \(configuration.daemonExecutablePath)")
        print("Socket Path: \(configuration.socketPath)")

        try await recorder.recordLoopEvent(
            toolCallId: "init",
            event: .callAllowed,
            fingerprint: "verifier-init",
            context: [
                "executable": configuration.daemonExecutablePath,
                "sessionId": sessionId
            ]
        )

        let coordinator = VerifierLaneCoordinator(
            recorder: recorder,
            configuration: configuration,
            sessionId: sessionId
        )
        let dimensions = try await coordinator.run()
        let bundle = await coordinator.makeBundle(dimensions: dimensions)

        try await recorder.writeBundle(bundle, forSessionId: sessionId)

        print("\n--- VERIFICATION SUMMARY ---")
        print("Maturity: \(bundle.maturityLevel)")
        print("Findings: \(bundle.matrix.count)")
        for dimension in bundle.matrix {
            print("  - \(dimension.name): \(dimension.status) (\(dimension.score)/100)")
        }
        print("Bundle written to: \(recorder.bundlePath(forSessionId: sessionId))")

        return bundle
    }
}

private actor VerifierLaneCoordinator {
    private let recorder: FileVerifierEvidenceRecorder
    private let configuration: DaemonVerifierHarnessConfiguration
    private let sessionId: String

    init(
        recorder: FileVerifierEvidenceRecorder,
        configuration: DaemonVerifierHarnessConfiguration,
        sessionId: String
    ) {
        self.recorder = recorder
        self.configuration = configuration
        self.sessionId = sessionId
    }

    func run() async throws -> [VerifierLaneMatrixDimension] {
        [
            try await runEchoCheck(),
            try await runMemoryLimitCheck(),
            try await runCpuLimitCheck(),
            try await runVaultIntegrityCheck()
        ]
    }

    func makeBundle(dimensions: [VerifierLaneMatrixDimension]) -> VerifierLaneBundle {
        let score = dimensions.reduce(0) { $0 + $1.score } / max(dimensions.count, 1)
        let maturityLevel: String
        switch score {
        case 95...:
            maturityLevel = "L5"
        case 75...:
            maturityLevel = "L4"
        default:
            maturityLevel = "L3"
        }

        let warnings = dimensions.filter { $0.status != .pass }.count
        let summary = "\(dimensions.count) checks executed, \(warnings) non-pass findings, overall score \(score)/100."
        let artifactPaths = [
            recorder.eventLogPath(forSessionId: sessionId),
            recorder.bundlePath(forSessionId: sessionId)
        ]

        return VerifierLaneBundle(
            id: sessionId,
            bundleType: "verifier-lane-runtime",
            description: "Evidence-backed verifier lane bundle for \(configuration.daemonExecutablePath)",
            createdAt: iso8601String(from: Date()),
            createdBy: "DaemonVerifierHarness",
            sessionId: sessionId,
            daemonExecutablePath: configuration.daemonExecutablePath,
            socketPath: configuration.socketPath,
            artifactPaths: artifactPaths,
            matrix: dimensions,
            maturityLevel: maturityLevel,
            summary: summary
        )
    }

    private func runEchoCheck() async throws -> VerifierLaneMatrixDimension {
        print("\n[TEST 1] Worker Echo...")

        let echoJob = Job(
            jobId: "echo-1",
            spec: JobSpec(
                kind: "artifact.copy",
                configCanonical: Data(),
                inputs: [
                    ArtifactRef(hash: "echo-test", mediaType: "text/plain", sizeBytes: 100)
                ]
            ),
            state: "queued",
            progressPermille: 0,
            outputs: [],
            finalReceiptHash: ""
        )

        let worker = WorkerProcess(executablePath: configuration.daemonExecutablePath)
        await worker.assignJob("echo-1")

        do {
            let outputs = try await worker.execute(
                job: echoJob,
                vaultData: ["echo-test": Data("echo".utf8)]
            )
            guard outputs.count == 1, !outputs[0].data.isEmpty else {
                throw HarnessError.emptyEchoOutput
            }

            try await recorder.recordLoopEvent(
                toolCallId: echoJob.jobId,
                event: .callAllowed,
                fingerprint: "test-worker-echo",
                context: [
                    "status": "success",
                    "outputSize": "\(outputs[0].data.count)"
                ]
            )
            print("SUCCESS: Echo job completed.")
            return VerifierLaneMatrixDimension(
                name: .performance,
                status: .pass,
                score: 100,
                evidence: [echoJob.jobId],
                notes: ["Echo worker completed successfully."]
            )
        } catch {
            try await recorder.recordLoopEvent(
                toolCallId: echoJob.jobId,
                event: .callBlocked,
                fingerprint: "test-worker-echo",
                context: ["error": String(describing: error)]
            )
            throw error
        }
    }

    private func runMemoryLimitCheck() async throws -> VerifierLaneMatrixDimension {
        print("\n[TEST 2] Memory Limit (Expected Termination)...")
        let leakJob = Job(
            jobId: "leak-1",
            spec: JobSpec(kind: "test.memory_leak", configCanonical: Data(), inputs: []),
            state: "queued",
            progressPermille: 0,
            outputs: [],
            finalReceiptHash: ""
        )
        let worker = WorkerProcess(executablePath: configuration.daemonExecutablePath)
        await worker.assignJob("leak-1")

        do {
            _ = try await worker.execute(job: leakJob, vaultData: [:])
            let note = "Memory leak job was not terminated on this host."
            print("WARNING: \(note)")
            try await recorder.recordLoopEvent(
                toolCallId: leakJob.jobId,
                event: .warningIssued,
                fingerprint: "test-memory-limit",
                context: ["status": "failed_to_terminate"]
            )
            return VerifierLaneMatrixDimension(
                name: .safety,
                status: .warn,
                score: 65,
                evidence: [leakJob.jobId],
                notes: [note]
            )
        } catch {
            try await recorder.recordLoopEvent(
                toolCallId: leakJob.jobId,
                event: .callAllowed,
                fingerprint: "test-memory-limit",
                context: [
                    "status": "terminated_as_expected",
                    "error": String(describing: error)
                ]
            )
            print("SUCCESS: Worker terminated as expected: \(error)")
            return VerifierLaneMatrixDimension(
                name: .safety,
                status: .pass,
                score: 100,
                evidence: [leakJob.jobId],
                notes: ["Memory guard terminated the worker as expected."]
            )
        }
    }

    private func runCpuLimitCheck() async throws -> VerifierLaneMatrixDimension {
        print("\n[TEST 3] CPU Limit (Expected Termination)...")
        let cpuJob = Job(
            jobId: "cpu-1",
            spec: JobSpec(kind: "test.cpu_burn", configCanonical: Data(), inputs: []),
            state: "queued",
            progressPermille: 0,
            outputs: [],
            finalReceiptHash: ""
        )
        let worker = WorkerProcess(executablePath: configuration.daemonExecutablePath)
        await worker.assignJob("cpu-1")

        do {
            _ = try await worker.execute(job: cpuJob, vaultData: [:])
            let note = "CPU burn job was not terminated on this host."
            print("WARNING: \(note)")
            try await recorder.recordLoopEvent(
                toolCallId: cpuJob.jobId,
                event: .warningIssued,
                fingerprint: "test-cpu-limit",
                context: ["status": "failed_to_terminate"]
            )
            return VerifierLaneMatrixDimension(
                name: .reliability,
                status: .warn,
                score: 65,
                evidence: [cpuJob.jobId],
                notes: [note]
            )
        } catch {
            try await recorder.recordLoopEvent(
                toolCallId: cpuJob.jobId,
                event: .callAllowed,
                fingerprint: "test-cpu-limit",
                context: [
                    "status": "terminated_as_expected",
                    "error": String(describing: error)
                ]
            )
            print("SUCCESS: Worker terminated as expected: \(error)")
            return VerifierLaneMatrixDimension(
                name: .reliability,
                status: .pass,
                score: 100,
                evidence: [cpuJob.jobId],
                notes: ["CPU guard terminated the worker as expected."]
            )
        }
    }

    private func runVaultIntegrityCheck() async throws -> VerifierLaneMatrixDimension {
        print("\n[TEST 4] Vault Streaming Integrity (100MB)...")
        let result = try await runVaultStreamingTest()
        return VerifierLaneMatrixDimension(
            name: .compliance,
            status: .pass,
            score: 100,
            evidence: [result.hash],
            notes: ["Vault streaming preserved the 100MB payload hash."]
        )
    }

    private func runVaultStreamingTest() async throws -> VaultIntegrityResult {
        let vaultPath = "/tmp/anigmad-test-vault"
        if FileManager.default.fileExists(atPath: vaultPath) {
            try? FileManager.default.removeItem(atPath: vaultPath)
        }
        let vaultURL = URL(fileURLWithPath: vaultPath)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)

        let dbPath = vaultURL.appendingPathComponent("test_vault.db").path
        let dbActor: any DatabaseExecutor = DatabaseActor(path: dbPath)
        try await dbActor.open()
        defer { Task { await dbActor.close() } }

        let vault = try await VaultAuthority(
            rootURL: vaultURL,
            database: dbActor,
            keyProvider: DefaultVaultKeyProvider.make()
        )

        print("  Generating 100MB of test data...")
        let dataSize = 100 * 1024 * 1024
        var testData = Data(count: dataSize)
        testData.withUnsafeMutableBytes { ptr in
            arc4random_buf(ptr.baseAddress!, dataSize)
        }
        let originalHash = BLAKE3Digest.hex(of: testData)
        print("  Original hash: \(originalHash)")

        print("  Ingesting into vault...")
        let ref = try await vault.ingest(
            data: testData,
            kind: .original,
            mime: "application/octet-stream"
        )
        print("  Ingested hash: \(ref.hashHex)")
        guard ref.hashHex == originalHash else {
            throw HarnessError.hashMismatch(expected: originalHash, actual: ref.hashHex)
        }

        print("  Retrieving from vault...")
        let retrievedData = try await vault.open(hash: ref.hashHex)
        let retrievedHash = BLAKE3Digest.hex(of: retrievedData)
        guard retrievedHash == originalHash else {
            throw HarnessError.hashMismatch(expected: originalHash, actual: retrievedHash)
        }

        try await recorder.recordLoopEvent(
            toolCallId: "vault-integrity",
            event: .callAllowed,
            fingerprint: "test-vault-integrity",
            context: [
                "hash": originalHash,
                "size": "\(dataSize)"
            ]
        )

        print("SUCCESS: Vault streaming integrity verified.")
        return VaultIntegrityResult(hash: originalHash, sizeBytes: dataSize)
    }
}

private struct VaultIntegrityResult: Sendable {
    let hash: String
    let sizeBytes: Int
}

private enum HarnessError: Error {
    case emptyEchoOutput
    case hashMismatch(expected: String, actual: String)
}

private final class FileVerifierEvidenceRecorder: LoopEvidenceRecorder, @unchecked Sendable {
    private let evidenceDirectory: String
    private let sessionId: String
    private let bundleEncoder: JSONEncoder
    private let eventEncoder: JSONEncoder

    init(evidenceDirectory: String? = nil, sessionId: String) {
        // Alignment: Use governed runtime authority for paths
        let defaultPath = RuntimeAuthority.shared.workingDirectory + "/.evidence"
        self.evidenceDirectory = evidenceDirectory ?? defaultPath
        self.sessionId = sessionId
        self.bundleEncoder = JSONEncoder()
        self.bundleEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.bundleEncoder.dateEncodingStrategy = .iso8601
        self.eventEncoder = JSONEncoder()
        self.eventEncoder.outputFormatting = [.sortedKeys]
        try? FileManager.default.createDirectory(
            atPath: self.evidenceDirectory,
            withIntermediateDirectories: true
        )
    }

    func recordLoopEvent(
        toolCallId: String,
        event: LoopEvent,
        fingerprint: String,
        context: [String: Sendable]
    ) async throws {
        let record = LoopEventRecord(
            toolCallId: toolCallId,
            event: event.rawValue,
            fingerprint: fingerprint,
            context: context.mapValues { String(describing: $0) }
        )
        let path = eventLogPath(forSessionId: sessionId)
        let line = try eventEncoder.encode(record)
        try append(data: line, to: path)
        try append(data: Data("\n".utf8), to: path)
    }

    func bundlePath(forSessionId sessionId: String) -> String {
        evidenceDirectory + "/session_\(sessionId).bundle.json"
    }

    func eventLogPath(forSessionId sessionId: String) -> String {
        evidenceDirectory + "/session_\(sessionId).events.jsonl"
    }

    func writeBundle(_ bundle: VerifierLaneBundle, forSessionId sessionId: String) async throws {
        let data = try bundleEncoder.encode(bundle)
        try data.write(to: URL(fileURLWithPath: bundlePath(forSessionId: sessionId)))
    }

    private func append(data: Data, to path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: URL(fileURLWithPath: path))
        }
    }
}

private struct LoopEventRecord: Codable, Sendable {
    let toolCallId: String
    let event: String
    let fingerprint: String
    let context: [String: String]
}

private func hexDigest(_ data: Data) -> String {
    BLAKE3Digest.hex(of: data)
}

private func iso8601String(from date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}
