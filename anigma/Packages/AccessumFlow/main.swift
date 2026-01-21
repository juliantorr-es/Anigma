//
//  main.swift
//  AccessumFlow
//
//  [Brief description of file purpose]
//

import ArgumentParser
import AnigmaCore
import ContractsCore
import CryptoKit
import DatabaseCore
import DiaplasionModule
import Foundation
import Darwin
import HarmoniaModule
import MLWorkerCommon
import OSLog
import OutlineumModule

private let accessumLogger = Logger(subsystem: "com.anigma.AccessumFlow", category: "accessum")

#if !SWIFT_PACKAGE
@main
#endif
struct AccessumFlow: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "accessum-flow",
        abstract: "Operator shell that orchestrates Diaplasion, Outlineum, and Harmonia surface contracts.",
        subcommands: [Admin.self]
    )

    @Option(
        name: [.short, .customLong("spec")],
        help: "Path to a Diaplasion spec JSON (default: bundled happy-path fixture)."
    )
    var spec: String?

    @Option(
        name: [.short, .customLong("output-base")],
        help: "Base directory override for Accessum artifacts (default: Application Support/Anigma/Accessum)."
    )
    var outputBase: String = ""

    @Option(
        name: [.customLong("replay")],
        help: "Replay a previous run by its runId."
    )
    var replayRunId: String?

    @Option(
        name: [.customLong("retention-days")],
        help: "Prune ledger runs older than this many days before starting (default: 30)."
    )
    var retentionDays: Int = 30

    func run() async throws {
        let repoRoot = try Self.repositoryRoot()
        let runtimePaths = try Self.resolveRuntimePaths(outputBase: outputBase, repoRoot: repoRoot)
        let runStore = AccessumRunStore(dbURL: runtimePaths.dbURL)
        try await runStore.prepare()
        if retentionDays > 0 {
            let pruned = try await runStore.pruneRuns(olderThanDays: retentionDays)
            if pruned > 0 {
                accessumLogger.info("Pruned \(pruned) runs older than \(retentionDays) days")
            }
        }

        if let runId = replayRunId {
            accessumLogger.info("Replaying Accessum run \(runId)")
            try await Self.performReplay(
                runId: runId,
                repoRoot: repoRoot,
                paths: runtimePaths,
                store: runStore
            )
            return
        }

        let specSource = try Self.resolveSpecSource(specOption: spec, repoRoot: repoRoot)
        let specURL = specSource.url
        let specData = try Data(contentsOf: specURL)
        let specModel = try DiaplasionSpec.decode(from: specData)
        let pipelineVersion = DiaplasionModuleVersion.string
        let outlineumVersion = OutlineumModuleVersion.string
        let inputContext = try Self.hashInputs(specData: specData, inputURLs: specModel.inputURLs(relativeTo: specURL))
        let outlineumSpecURL = try Self.outlineumSpecURL(repoRoot: repoRoot)
        let outlineumSpec = try ZineRecipeSpec.load(from: outlineumSpecURL)
        let outlineumInputHash = try Self.computeOutlineumInputHash(spec: outlineumSpec, specURL: outlineumSpecURL)
        let runId = Self.computeRunId(
            inputHash: inputContext.hash,
            pipelineVersions: [
                "diaplasion": pipelineVersion,
                "outlineum": outlineumVersion
            ],
            outlineumInputHash: outlineumInputHash,
            contractVersion: Self.contractVersion
        )

        let artifactDir = runtimePaths.artifactDir(for: runId)
        try FileManager.default.createDirectory(at: artifactDir, withIntermediateDirectories: true)

        let runStart = Date()
        let timestamp = Self.isoTimestamp(runStart)
        let runRecord = AccessumRunRecord(
            runId: runId,
            status: "running",
            contractVersion: Self.contractVersion,
            timestamp: timestamp,
            specRef: specSource.description,
            specPath: specURL.path,
            artifactDir: artifactDir.path,
            inputHash: inputContext.hash,
            specDataHash: inputContext.specDataHash,
            outlineumInputHash: outlineumInputHash,
            pipelineVersions: [
                "diaplasion": pipelineVersion,
                "outlineum": outlineumVersion
            ],
            replayCommand: Self.replayCommand(runId: runId)
        )
        try await runStore.startRun(record: runRecord)
        try Self.writeStatus(
            paths: runtimePaths,
            runId: runId,
            status: "running",
            message: "Accessum run starting",
            artifactDir: artifactDir.path
        )
        accessumLogger.info("Starting Accessum run \(runId) for \(specSource.description)")

        let buildEnv = Self.buildEnvironment(repoRoot: repoRoot)
        let workerSupervisor = WorkerSupervisor()
        var steps: [AccessumStep] = []

        do {
            let (diStep, diTrace, pipelineArtifactDir) = try Self.runDiaplasionStep(
                specURL: specURL,
                specSource: specSource,
                repoRoot: repoRoot,
                pipelineVersion: pipelineVersion,
                inputContext: inputContext,
                artifactDir: artifactDir,
                env: buildEnv
            )
            steps.append(diStep)

            let mlStep = try await Self.runMLStep(
                runId: runId,
                repoRoot: repoRoot,
                artifactDir: artifactDir,
                pipelineVersion: pipelineVersion,
                diTrace: diTrace,
                pipelineArtifactDir: pipelineArtifactDir,
                env: buildEnv,
                supervisor: workerSupervisor
            )
            steps.append(mlStep)

            let outlineStep = try Self.runOutlineumStep(
                repoRoot: repoRoot,
                outlineumSpecURL: outlineumSpecURL,
                outlineumSpec: outlineumSpec,
                outlineumInputHash: outlineumInputHash,
                artifactDir: artifactDir,
                env: buildEnv
            )
            steps.append(outlineStep)

            let totalDuration = Int(Date().timeIntervalSince(runStart) * 1000)
            let metrics = AccessumMetrics(totalDurationMs: totalDuration, stepCount: steps.count)

            let trace = AccessumTrace(
                contractVersion: Self.contractVersion,
                status: "ok",
                timestamp: Self.isoTimestamp(Date()),
                command: "accessum flow",
                payload: AccessumPayload(
                    runId: runId,
                    specRef: specSource.description,
                    specPath: specURL.path,
                    artifactDir: artifactDir.path,
                    inputs: AccessumInputs(
                        inputHash: inputContext.hash,
                        specDataHash: inputContext.specDataHash,
                        files: inputContext.inputDetails.map {
                            AccessumInputFile(
                                path: $0.path,
                                hash: $0.hash,
                                byteCount: $0.byteCount
                            )
                        }
                    ),
                    steps: steps,
                    replay: AccessumReplay(
                        supported: true,
                        command: Self.replayCommand(runId: runId)
                    )
                ),
                governanceTrace: [],
                metrics: metrics
            )

            let traceURL = artifactDir.appendingPathComponent("trace.json")
            let traceData = try Self.writeTrace(trace, to: traceURL)
            try await runStore.completeRun(
                runId: runId,
                trace: trace,
                traceData: traceData,
                tracePath: traceURL.path,
                steps: steps,
                metrics: metrics
            )

            try Self.writeStatus(
                paths: runtimePaths,
                runId: runId,
                status: "ok",
                message: "Accessum run completed",
                artifactDir: artifactDir.path
            )

            accessumLogger.info("Accessum run \(runId) completed in \(totalDuration)ms")
            if let jsonString = String(data: traceData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            accessumLogger.error("Accessum run \(runId) failed: \(error.localizedDescription)")
            try? Self.writeStatus(
                paths: runtimePaths,
                runId: runId,
                status: "failed",
                message: "Accessum run failed: \(error.localizedDescription)",
                artifactDir: artifactDir.path
            )
            try await runStore.markRunFailed(runId: runId, errorMessage: error.localizedDescription, timestamp: Self.isoTimestamp(Date()))
            throw error
        }
    }

    private static func performReplay(
        runId: String,
        repoRoot: URL,
        paths: AccessumRuntimePaths,
        store: AccessumRunStore
    ) async throws {
        let artifactDir = paths.artifactDir(for: runId)
        let storedTrace = try await store.traceForRun(runId: runId)
        let specPath = storedTrace.payload.specPath
        let specURL = URL(fileURLWithPath: specPath)
        let specData = try Data(contentsOf: specURL)
        let specModel = try DiaplasionSpec.decode(from: specData)
        let pipelineVersion = DiaplasionModuleVersion.string
        let inputContext = try Self.hashInputs(specData: specData, inputURLs: specModel.inputURLs(relativeTo: specURL))
        let outlineumSpecURL = try Self.outlineumSpecURL(repoRoot: repoRoot)
        let outlineumSpec = try ZineRecipeSpec.load(from: outlineumSpecURL)
        let outlineumInputHash = try Self.computeOutlineumInputHash(spec: outlineumSpec, specURL: outlineumSpecURL)

        let buildEnv = Self.buildEnvironment(repoRoot: repoRoot)
        let workerSupervisor = WorkerSupervisor()
        var steps: [AccessumStep] = []
        let (diStep, diTrace, pipelineArtifactDir) = try Self.runDiaplasionStep(
            specURL: specURL,
            specSource: .cli(specURL),
            repoRoot: repoRoot,
            pipelineVersion: pipelineVersion,
            inputContext: inputContext,
            artifactDir: artifactDir,
            env: buildEnv
        )
        steps.append(diStep)
        let mlStep = try await Self.runMLStep(
            runId: runId,
            repoRoot: repoRoot,
            artifactDir: artifactDir,
            pipelineVersion: pipelineVersion,
            diTrace: diTrace,
            pipelineArtifactDir: pipelineArtifactDir,
            env: buildEnv,
            supervisor: workerSupervisor
        )
        steps.append(mlStep)
        let outlineStep = try Self.runOutlineumStep(
            repoRoot: repoRoot,
            outlineumSpecURL: outlineumSpecURL,
            outlineumSpec: outlineumSpec,
            outlineumInputHash: outlineumInputHash,
            artifactDir: artifactDir,
            env: buildEnv
        )
        steps.append(outlineStep)

        let newPayload = AccessumPayload(
            runId: runId,
            specRef: storedTrace.payload.specRef,
            specPath: specPath,
            artifactDir: artifactDir.path,
            inputs: storedTrace.payload.inputs,
            steps: steps,
            replay: storedTrace.payload.replay
        )

        do {
            if storedTrace.payload.inputs != newPayload.inputs || storedTrace.payload.steps != newPayload.steps {
                throw AccessumError.replayDrift(runId)
            }
            try await store.recordReplay(runId: runId, verdict: "ok", detail: "Replay matched")
            print("Replay succeeded for runId: \(runId)")
        } catch {
            try? await store.recordReplay(runId: runId, verdict: "drift", detail: error.localizedDescription)
            throw error
struct RunDiaplasionStepConfiguration: Sendable {
    let specURL: URL
    let specSource: String
    let repoRoot: URL
    let pipelineVersion: String
    let inputContext: [String: Any]
    let artifactDir: URL
    let env: [String: String]
    
    init(
        specURL: URL,
        specSource: String,
        repoRoot: URL,
        pipelineVersion: String,
        inputContext: [String: Any],
        artifactDir: URL,
        env: [String: String]
    ) {
        self.specURL = specURL
        self.specSource = specSource
        self.repoRoot = repoRoot
        self.pipelineVersion = pipelineVersion
        self.inputContext = inputContext
        self.artifactDir = artifactDir
        self.env = env
    }
}

// Function signature should be updated to:
// func runDiaplasionStep(config: RunDiaplasionStepConfiguration) async throws
        specSource: String,
        repoRoot: URL,
        pipelineVersion: String,
        inputContext: [String: Any],
        artifactDir: URL,
        env: [String: String]
    ) {
        self.specURL = specURL
        self.specSource = specSource
        self.repoRoot = repoRoot
        self.pipelineVersion = pipelineVersion
        self.inputContext = inputContext
        self.artifactDir = artifactDir
        self.env = env
    }
}

// Updated function signature:
func runDiaplasionStep(config: RunDiaplasionStepConfiguration) throws -> (step: AccessumStep, trace: DiaplasionTrace, artifactDir: URL) {
    try ensureDirectory(config.artifactDir)
    let batchStart = Date()
    let binPath = try buildProduct("diaplasion-pipeline", repoRoot: config.repoRoot, env: config.env)
    let executable = binPath.appendingPathComponent("diaplasion-pipeline")
    let outputBase = config.repoRoot.appendingPathComponent("Artifacts/diaplasion")
    let args = [
        "--spec", config.specURL.path,
        // ... rest of implementation using config properties
    ]
    // ... rest of function body
}
            "--output-base", outputBase.path
        ]
        let commandResult = try runCommand(executable.path, args: args, env: env, workingDirectory: repoRoot)
        let duration = Int(Date().timeIntervalSince(batchStart) * 1000)

        let pipelineArtifactDir = artifactPathForDiaplasion(
            repoRoot: repoRoot,
            pipelineVersion: pipelineVersion,
            inputHash: inputContext.hash
        )
        let pipelineTraceURL = pipelineArtifactDir.appendingPathComponent("trace.json")
        let trace = try jsonDecoder.decode(DiaplasionTrace.self, from: Data(contentsOf: pipelineTraceURL))

        let artifacts = [
            "artifactDir": pipelineArtifactDir.path,
            "plainText": pipelineArtifactDir.appendingPathComponent("plain.txt").path,
struct RunMLStepConfiguration: Sendable {
    let runId: String
    let repoRoot: URL
    let artifactDir: URL
    let pipelineVersion: String
    let diTrace: URL
    let pipelineArtifactDir: URL
    let env: [String: String]
    let supervisor: Supervisor
    
    init(
        runId: String,
        repoRoot: URL,
        artifactDir: URL,
        pipelineVersion: String,
        diTrace: URL,
        pipelineArtifactDir: URL,
        env: [String: String],
        supervisor: Supervisor
    ) {
        self.runId = runId
        self.repoRoot = repoRoot
        self.artifactDir = artifactDir
        self.pipelineVersion = pipelineVersion
        self.diTrace = diTrace
        self.pipelineArtifactDir = pipelineArtifactDir
        self.env = env
        self.supervisor = supervisor
    }
}

// Updated function signature:
// func runMLStep(config: RunMLStepConfiguration) async throws -> AccessumStep
                name: "diaplasion-pipeline",
                command: "\(executable.path) \(args.joined(separator: " "))",
                status: "success",
                exitCode: commandResult.exitCode ?? 0,
                durationMs: duration,
                artifacts: artifacts,
                hashes: hashes,
                detail: specSource.description
            ),

        pipelineArtifactDir: URL,
        env: [String: String],
        supervisor: WorkerSupervisor
    ) async throws -> AccessumStep {
        let mlBase = artifactDir.appendingPathComponent("ml", isDirectory: true)
        let mlRunDir = mlBase.appendingPathComponent(runId, isDirectory: true)
        try ensureDirectory(mlBase)
        try ensureDirectory(mlRunDir)

struct RunMLStepConfiguration: Sendable {
    let runId: String
    let repoRoot: URL
    let artifactDir: URL
    let pipelineVersion: String
    let diTrace: DITrace // Ensure DITrace is Sendable
    let pipelineArtifactDir: URL
    let env: [String: String]
    let supervisor: Supervisor // Ensure Supervisor is Sendable
    
    init(
        runId: String,
        repoRoot: URL,
        artifactDir: URL,
        pipelineVersion: String,
        diTrace: DITrace,
        pipelineArtifactDir: URL,
        env: [String: String],
        supervisor: Supervisor
    ) {
        self.runId = runId
        self.repoRoot = repoRoot
        self.artifactDir = artifactDir
        self.pipelineVersion = pipelineVersion
        self.diTrace = diTrace
        self.pipelineArtifactDir = pipelineArtifactDir
        self.env = env
        self.supervisor = supervisor
    }
}

// Then update the function signature to:
// func runMLStep(config: RunMLStepConfiguration) throws
            stepId: "mlx.embed",
            engine: .mlx,
            task: .embed,
            inputs: [artifactInput],
            options: MLTaskOptions(
                seed: Self.deterministicSeed(from: diTrace.plainTextHash),
                outputDirectory: mlRunDir.path
            )
        )

        let response = try await supervisor.dispatch(request: request)

        var artifacts: [String: String] = [
            "artifactDir": mlRunDir.path
        ]
        var hashes: [String: String] = [
            "inputHash": diTrace.plainTextHash
        ]

        for (index, artifact) in response.outputs.enumerated() {
            let key = "embedding.\(index)"
            artifacts[key] = artifact.path
            hashes["\(key).containerHash"] = artifact.hash
        }

        let detail = "engine=\(response.engineMeta?.modelId ?? "unknown") modelHash=\(response.engineMeta?.modelHash ?? "unknown")"
        let exitCode: Int32 = response.status == ContractsCore.MLWorkerStatus.completed ? 0 : 1
        return AccessumStep(
            name: "ml-worker-embed",
            command: "ml-worker --engine \(request.engine.rawValue) embed \(requestId)",
            status: response.status.rawValue,
            exitCode: exitCode,
            durationMs: response.metrics?.durationMs ?? 0,
            artifacts: artifacts,
            hashes: hashes,
            detail: detail
        )
    }

    private static func runOutlineumStep(
        repoRoot: URL,
        outlineumSpecURL: URL,
        outlineumSpec: ZineRecipeSpec,
        outlineumInputHash: String,
        artifactDir: URL,
        env: [String: String]
    ) throws -> AccessumStep {
        let batchStart = Date()
        let binPath = try buildProduct("outlineum-zine", repoRoot: repoRoot, env: env)
        let executable = binPath.appendingPathComponent("outlineum-zine")
        let outlineumBase = artifactDir.appendingPathComponent("outlineum", isDirectory: true)
        let args = [
            "--spec", outlineumSpecURL.path,
            "--output-base", outlineumBase.path
        ]
        let commandResult = try runCommand(executable.path, args: args, env: env, workingDirectory: repoRoot)
        let duration = Int(Date().timeIntervalSince(batchStart) * 1000)

        let outlineArtifactDir = try outlineumArtifactDirectory(
            base: outlineumBase,
            pipelineVersion: OutlineumModuleVersion.string,
            inputHash: outlineumInputHash
        )
        let pdfPath = outlineArtifactDir.appendingPathComponent("zine.pdf")
        let provenancePath = outlineArtifactDir.appendingPathComponent("provenance.json")
        let artifacts = [
            "artifactDir": outlineArtifactDir.path,
            "pdf": pdfPath.path,
            "provenance": provenancePath.path
        ]
        let pdfHash = try sha256Hex(of: pdfPath)
        let hashes = [
            "pdfHash": pdfHash
        ]

        return AccessumStep(
            name: "outlineum-zine",
            command: "\(executable.path) \(args.joined(separator: " "))",
            status: "success",
            exitCode: commandResult.exitCode ?? 0,
            durationMs: duration,
            artifacts: artifacts,
            hashes: hashes,
            detail: "Outlineum preview (zine-minimal fixture)"
        )
    }

    // MARK: - Helpers

    private static func buildProduct(_ product: String, repoRoot: URL, env: [String: String]) throws -> URL {
        _ = try runCommand("/usr/bin/swift", args: ["build", "--disable-sandbox", "-c", "release", "--product", product], env: env, workingDirectory: repoRoot)
        let info = try runCommand("/usr/bin/swift", args: ["build", "--disable-sandbox", "-c", "release", "--product", product, "--show-bin-path"], env: env, workingDirectory: repoRoot)
        let path = info.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw AccessumError.missingBinary(product)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func runCommand(_ executable: String, args: [String], env: [String: String], workingDirectory: URL) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.environment = ProcessInfo.processInfo.environment.merging(env) { _, new in new }
        process.currentDirectoryURL = workingDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let start = Date()
        try process.run()
        process.waitUntilExit()
        let duration = Int(Date().timeIntervalSince(start) * 1000)

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        if !stdoutString.isEmpty {
            FileHandle.standardError.write((stdoutString).data(using: .utf8)!)
        }
        if !stderrString.isEmpty {
            FileHandle.standardError.write((stderrString).data(using: .utf8)!)
        }

        if process.terminationStatus != 0 {
            throw AccessumError.commandFailed(executable: executable, arguments: args, exitCode: process.terminationStatus)
        }

        return CommandResult(exitCode: process.terminationStatus, stdout: stdoutString, stderr: stderrString, durationMs: duration)
    }

    private static func deterministicSeed(from hash: String) -> Int {
        let truncated = String(hash.prefix(8))
        return Int(truncated, radix: 16) ?? 0
    }

    private static func buildEnvironment(repoRoot: URL) -> [String: String] {
        let clangCache = repoRoot.appendingPathComponent(".cache-clang").path
        let swiftpmCache = repoRoot.appendingPathComponent(".cache/swiftpm").path
        try? FileManager.default.createDirectory(atPath: clangCache, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: swiftpmCache, withIntermediateDirectories: true)
        return [
            "CLANG_MODULE_CACHE_PATH": clangCache,
            "SWIFTPM_DIRECTORY": swiftpmCache
        ]
    }

    private static func replayCommand(runId: String) -> String {
        "accessum flow --replay \(runId)"
    }

    private static func writeTrace(_ trace: AccessumTrace, to url: URL) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(trace)
        try data.write(to: url)
        return data
    }

    private static func computeRunId(
        inputHash: String,
        pipelineVersions: [String: String],
        outlineumInputHash: String,
        contractVersion: Int
    ) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(inputHash.utf8))
        let sortedVersions = pipelineVersions.sorted { $0.key < $1.key }
        for (key, value) in sortedVersions {
            hasher.update(data: Data(key.utf8))
            hasher.update(data: Data(value.utf8))
        }
        hasher.update(data: Data(outlineumInputHash.utf8))
        hasher.update(data: Data(String(contractVersion).utf8))
        return "sha256:\(hasher.finalize().hexString)"
    }

    private static func artifactPathForDiaplasion(repoRoot: URL, pipelineVersion: String, inputHash: String) -> URL {
        repoRoot
            .appendingPathComponent("Artifacts")
            .appendingPathComponent("diaplasion")
            .appendingPathComponent(pipelineVersion)
            .appendingPathComponent(inputHash)
    }

    private struct AccessumRuntimePaths {
        let base: URL
        let artifactsRoot: URL
        let dbURL: URL
        let statusURL: URL

        func artifactDir(for runId: String) -> URL {
            artifactsRoot.appendingPathComponent(runId, isDirectory: true)
        }
    }

    private static func resolveRuntimePaths(outputBase: String, repoRoot: URL) throws -> AccessumRuntimePaths {
        let fm = FileManager.default

        let envBase = ProcessInfo.processInfo.environment["ANIGMA_ACCESSUM_BASE"] ?? ""
        let resolvedPath: URL
        if !outputBase.isEmpty {
            resolvedPath = URL(fileURLWithPath: outputBase, relativeTo: repoRoot).standardizedFileURL
        } else if !envBase.isEmpty {
            resolvedPath = URL(fileURLWithPath: envBase).standardizedFileURL
        } else {
            let supportDir = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            resolvedPath = supportDir
                .appendingPathComponent("Anigma", isDirectory: true)
                .appendingPathComponent("Accessum", isDirectory: true)
        }

        try fm.createDirectory(at: resolvedPath, withIntermediateDirectories: true)
        let artifactsRoot = resolvedPath.appendingPathComponent("Artifacts", isDirectory: true)
        try fm.createDirectory(at: artifactsRoot, withIntermediateDirectories: true)
        let dbURL = resolvedPath.appendingPathComponent("accessum.db")
        let statusURL = resolvedPath.appendingPathComponent("status.json")

        return AccessumRuntimePaths(
            base: resolvedPath,
            artifactsRoot: artifactsRoot,
            dbURL: dbURL,
            statusURL: statusURL
        )
    }

    private static let statusEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static func writeStatus(
        paths: AccessumRuntimePaths,
        runId: String?,
        status: String,
        message: String?,
        artifactDir: String?
    ) throws {
        let record = AccessumStatusRecord(
            runId: runId,
            status: status,
            message: message,
            artifactDir: artifactDir,
            timestamp: Self.isoTimestamp(Date())
        )
        let data = try statusEncoder.encode(record)
        try data.write(to: paths.statusURL)
    }

    private static func outlineumArtifactDirectory(base: URL, pipelineVersion: String, inputHash: String) throws -> URL {
        let target = base
            .appendingPathComponent(pipelineVersion, isDirectory: true)
            .appendingPathComponent(inputHash, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }

    private static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func outlineumSpecURL(repoRoot: URL) throws -> URL {
        return repoRoot.appendingPathComponent("Sources/OutlineumModule/TestFiles/zine-minimal/spec.json")
    }

    private static func sha256Hex(of fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data).hexString
    }

    private static func repositoryRoot() throws -> URL {
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let fileManager = FileManager.default
        while true {
            if fileManager.fileExists(atPath: current.appendingPathComponent("Package.swift").path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                throw AccessumError.rootNotFound
            }
            current = parent
        }
    }

    private static func hashInputs(specData: Data, inputURLs: [URL]) throws -> InputHashContext {
        var hasher = SHA256()
        hasher.update(data: specData)
        let specDataHash = SHA256.hash(data: specData).hexString

        let sortedInputs = inputURLs.sorted { $0.path < $1.path }
        var details: [TraceInputDetail] = []

        for url in sortedInputs {
            let data = try Data(contentsOf: url)
            hasher.update(data: data)
            details.append(TraceInputDetail(
                path: url.path,
                hash: SHA256.hash(data: data).hexString,
                byteCount: data.count
            ))
        }

        return InputHashContext(
            hash: hasher.finalize().hexString,
            specDataHash: specDataHash,
            inputDetails: details
        )
    }

    private static func computeOutlineumInputHash(spec: ZineRecipeSpec, specURL: URL) throws -> String {
        var canonical = spec
        canonical.images = canonical.images.sorted()
        canonical.metadata = canonical.metadata ?? [:]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let specData = try encoder.encode(canonical)

        var hasher = SHA256()
        hasher.update(data: specData)

        let baseDir = specURL.deletingLastPathComponent()
        for imagePath in canonical.images {
            let resolved = URL(fileURLWithPath: imagePath, relativeTo: baseDir).standardizedFileURL
            let data = try Data(contentsOf: resolved)
            hasher.update(data: data)
        }

        return hasher.finalize().hexString
    }

    private static func resolveSpecSource(specOption: String?, repoRoot: URL) throws -> SpecSource {
        if let spec = specOption {
            return .cli(URL(fileURLWithPath: spec, relativeTo: repoRoot).standardizedFileURL)
        }
        let bundleURL = try DiaplasionModuleResources.urlForHappyPathSpec()
        return .bundle(bundleURL)
    }

    private static func isoTimestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

static let contractVersion: Int = 1

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    // MARK: - Data Structures

    private struct CommandResult {
        let exitCode: Int32?
        let stdout: String
        let stderr: String
        let durationMs: Int
    }

    private struct InputHashContext: Equatable {
        let hash: String
        let specDataHash: String
        let inputDetails: [TraceInputDetail]
    }

    private struct TraceInputDetail: Codable, Equatable {
        let path: String
        let hash: String
        let byteCount: Int
    }

    private enum SpecSource {
        case bundle(URL)
        case cli(URL)

        var url: URL {
            switch self {
            case .bundle(let url): return url
            case .cli(let url): return url
            }
        }

        var description: String {
            switch self {
            case .bundle(let url):
                return "bundle(\(url.lastPathComponent))"
            case .cli(let url):
                return "cli(\(url.path))"
            }
        }
    }

    private struct DiaplasionTrace: Codable {
        let pipelineVersion: String
        let inputHash: String
        let specDataHash: String
        let plainTextHash: String
        let pdfHash: String
        let pdfContentHash: String
    }

    private struct ZineRecipeSpec: Codable {
        var title: String
        var version: String?
        var images: [String]
        var metadata: [String: String]?

        static func load(from url: URL) throws -> ZineRecipeSpec {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ZineRecipeSpec.self, from: data)
        }
    }

    private struct DiaplasionSpecInput: Codable {
        var path: String
        var label: String?
    }

    private struct DiaplasionSpec: Codable {
        var title: String
        var description: String?
        var inputs: [DiaplasionSpecInput]

        func inputURLs(relativeTo specURL: URL) -> [URL] {
            inputs.map {
                URL(fileURLWithPath: $0.path, relativeTo: specURL.deletingLastPathComponent()).standardizedFileURL
            }
        }

        static func decode(from data: Data) throws -> DiaplasionSpec {
            try JSONDecoder().decode(DiaplasionSpec.self, from: data)
        }
    }

}

extension AccessumFlow {
    struct Admin: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "admin",
            abstract: "Inspect persisted Accessum runs."
        )

        @Option(
            name: [.customLong("stuck-minutes")],
            help: "Minutes before a running job is considered stuck."
        )
        var stuckMinutes: Int = 5

        @Option(
            name: [.customLong("base")],
            help: "Override the Accessum runtime base directory (default: Application Support)."
        )
        var baseDir: String?

        @Option(
            name: [.customLong("migration-task-id")],
            help: "Include latest migration trace for the given task_id."
        )
        var migrationTaskId: String?

        @Option(
            name: [.customLong("migration-db")],
            help: "Path to the migration trace SQLite DB (default: harmonia_harness.sqlite)"
        )
        var migrationDbPath: String?

    func run() async throws {
        let repoRoot = try AccessumFlow.repositoryRoot()
        let runtimePaths = try AccessumFlow.resolveRuntimePaths(outputBase: baseDir ?? "", repoRoot: repoRoot)
        let runStore = AccessumRunStore(dbURL: runtimePaths.dbURL)
        try await runStore.prepare()
        let summary = try await runStore.adminSummary(stuckMinutes: stuckMinutes)
        let migrationTrace: MigrationTraceRecord?
        if let taskId = migrationTaskId {
            let reporter = MigrationTraceReporter(dbPath: migrationDbPath ?? DatabaseConfiguration.defaultDatabasePath())
            migrationTrace = try await reporter.fetchLatest(taskId: taskId)
        } else {
            migrationTrace = nil
        }

        let payload = AccessumAdminPayload(
            summary: summary,
            basePath: runtimePaths.base.path
            , migrationTrace: migrationTrace
        )
        let envelope = AccessumAdminEnvelope(
            contractVersion: AccessumFlow.contractVersion,
            status: "ok",
            timestamp: AccessumFlow.isoTimestamp(Date()),
            command: "accessum flow admin",
            payload: payload,
            governanceTrace: []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(envelope)
        if let json = String(data: data, encoding: .utf8) {
            print(json)
        }
        accessumLogger.info("Accessum admin summary emitted \(summary.totalRuns) runs; \(summary.stuckRuns.count) stuck (> \(summary.stuckThresholdMinutes) min)")
    }
}
}

actor AccessumRunStore {
    private let database: DatabaseActor
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let isoFormatter: ISO8601DateFormatter
    private var prepared = false
    private static let schemaVersion = 2

    init(dbURL: URL) {
        self.database = DatabaseActor(dbPath: dbURL.path)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.isoFormatter = ISO8601DateFormatter()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    func prepare() async throws {
        guard !prepared else { return }
        try await database.open()
        try await ensureSchema()
        prepared = true
    }

    private func ensureSchema() async throws {
        let currentVersion = try await currentSchemaVersion()
        if currentVersion > Self.schemaVersion {
            throw AccessumError.schemaVersionMismatch(current: currentVersion, supported: Self.schemaVersion)
        }
        guard currentVersion < Self.schemaVersion else { return }
        for nextVersion in (currentVersion + 1)...Self.schemaVersion {
            try await applyMigration(version: nextVersion)
        }
    }

    private func currentSchemaVersion() async throws -> Int {
        let rows = try await database.query("PRAGMA user_version")
        guard let row = rows.first else { return 0 }
        return row.int(for: "user_version") ?? 0
    }

    private func applyMigration(version: Int) async throws {
        switch version {
        case 1:
            try await database.execute("""
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version INTEGER PRIMARY KEY,
                    appliedAt TEXT NOT NULL
                )
                """)

            try await database.execute("""
                CREATE TABLE IF NOT EXISTS runs (
                    runId TEXT PRIMARY KEY,
                    status TEXT NOT NULL,
                    contractVersion INTEGER NOT NULL,
                    timestamp TEXT,
                    startedAt TEXT,
                    finishedAt TEXT,
                    lastUpdated TEXT,
                    specRef TEXT,
                    specPath TEXT,
                    artifactDir TEXT,
                    inputHash TEXT,
                    specDataHash TEXT,
                    outlineumInputHash TEXT,
                    pipelineVersions TEXT,
                    replayCommand TEXT,
                    metricsJson TEXT,
                    tracePath TEXT,
                    traceJson TEXT,
                    errorMessage TEXT
                )
                """)

            try await database.execute("""
                CREATE TABLE IF NOT EXISTS steps (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    runId TEXT NOT NULL,
                    name TEXT NOT NULL,
                    status TEXT,
                    exitCode INTEGER,
                    durationMs INTEGER,
                    command TEXT,
                    detail TEXT,
                    artifactsJson TEXT,
                    hashesJson TEXT,
                    createdAt TEXT NOT NULL
                )
                """)

            try await database.execute("""
                CREATE TABLE IF NOT EXISTS artifacts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    runId TEXT NOT NULL,
                    stepName TEXT,
                    key TEXT,
                    path TEXT,
                    hash TEXT,
                    createdAt TEXT NOT NULL
                )
                """)

            try await database.execute("""
                CREATE TABLE IF NOT EXISTS replays (
                    runId TEXT PRIMARY KEY,
                    verdict TEXT,
                    detail TEXT,
                    timestamp TEXT NOT NULL
                )
                """)

            try await database.execute("""
                CREATE TABLE IF NOT EXISTS retention_events (
                    eventId INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    description TEXT NOT NULL,
                    runsRemoved INTEGER,
                    bytesFreed INTEGER
                )
                """)

        case 2:
            try await database.execute("ALTER TABLE steps ADD COLUMN started_at TEXT")
            try await database.execute("ALTER TABLE steps ADD COLUMN finished_at TEXT")
            try await database.execute("ALTER TABLE steps ADD COLUMN rewrite_path TEXT NOT NULL DEFAULT 'none'")
            try await database.execute("ALTER TABLE steps ADD COLUMN verify_status TEXT NOT NULL DEFAULT 'not_run'")
            try await database.execute("ALTER TABLE steps ADD COLUMN rollback_status TEXT NOT NULL DEFAULT 'not_needed'")
            try await database.execute("ALTER TABLE steps ADD COLUMN rollback_reason TEXT")
            try await database.execute("ALTER TABLE steps ADD COLUMN rule_id TEXT")
            try await database.execute("ALTER TABLE steps ADD COLUMN diff_artifact_path TEXT")
            try await database.execute("ALTER TABLE steps ADD COLUMN backup_path TEXT")
        default:
            break
        }

        let now = isoTimestamp(Date())
        try await database.execute("PRAGMA user_version = \(version)")
        try await database.execute("""
            INSERT OR REPLACE INTO schema_migrations (version, appliedAt) VALUES (?, ?)
            """,
            parameters: [
                .int(version),
                .text(now)
            ]
        )
    }

    func startRun(record: AccessumRunRecord) async throws {
        let now = isoTimestamp(Date())
        let pipelineText = try jsonString(record.pipelineVersions)
        try await database.execute("""
            INSERT OR REPLACE INTO runs (
                runId, status, contractVersion, timestamp, startedAt, finishedAt,
                lastUpdated, specRef, specPath, artifactDir, inputHash, specDataHash,
                outlineumInputHash, pipelineVersions, replayCommand
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(record.runId),
                .text(record.status),
                .int(record.contractVersion),
                .text(record.timestamp),
                .text(record.timestamp),
                .null,
                .text(now),
                .text(record.specRef),
                .text(record.specPath),
                .text(record.artifactDir),
                .text(record.inputHash),
                .text(record.specDataHash),
                .text(record.outlineumInputHash),
                .text(pipelineText),
                .text(record.replayCommand)
            ]
        )
    }

    func completeRun(
        runId: String,
        trace: AccessumTrace,
        traceData: Data,
        tracePath: String,
        steps: [AccessumStep],
        metrics: AccessumMetrics
    ) async throws {
        let now = isoTimestamp(Date())
        let metricsText = String(data: try encoder.encode(metrics), encoding: .utf8) ?? ""
        let traceText = String(data: traceData, encoding: .utf8) ?? ""

        try await database.transaction {
            try await database.execute("""
                UPDATE runs
                SET status = ?, finishedAt = ?, lastUpdated = ?, metricsJson = ?, tracePath = ?, traceJson = ?, errorMessage = NULL
                WHERE runId = ?
                """,
                parameters: [
                    .text("ok"),
                    .text(now),
                    .text(now),
                    .text(metricsText),
                    .text(tracePath),
                    .text(traceText),
                    .text(runId)
                ]
            )

            try await database.execute("DELETE FROM steps WHERE runId = ?", parameters: [.text(runId)])

            for step in steps {
                try await insertStep(runId: runId, step: step)
            }
        }
    }

    func markRunFailed(runId: String, errorMessage: String, timestamp: String) async throws {
        try await database.execute("""
            UPDATE runs
            SET status = ?, errorMessage = ?, lastUpdated = ?
            WHERE runId = ?
            """,
            parameters: [
                .text("failed"),
                .text(errorMessage),
                .text(timestamp),
                .text(runId)
            ]
        )
    }

    func traceForRun(runId: String) async throws -> AccessumTrace {
        let rows = try await database.query(
            "SELECT traceJson FROM runs WHERE runId = ? LIMIT 1",
            parameters: [.text(runId)]
        )
        guard let row = rows.first,
              let traceJson = row.string(for: "traceJson"),
              !traceJson.isEmpty,
              let data = traceJson.data(using: .utf8) else {
            throw AccessumError.traceMissing(runId)
        }
        return try decoder.decode(AccessumTrace.self, from: data)
    }

    private func insertStep(runId: String, step: AccessumStep) async throws {
        let now = isoTimestamp(Date())
        let artifactsJson = try jsonString(step.artifacts)
        let hashesJson = try jsonString(step.hashes)
        let detailParam: DatabaseParameter = step.detail.map { .text($0) } ?? .null
        let startedAtParam: DatabaseParameter = step.startedAt.map { .text($0) } ?? .null
        let finishedAtParam: DatabaseParameter = step.finishedAt.map { .text($0) } ?? .null
        let rollbackReasonParam: DatabaseParameter = step.rollbackReason.map { .text($0) } ?? .null
        let ruleIdParam: DatabaseParameter = step.ruleId.map { .text($0) } ?? .null
        let diffPathParam: DatabaseParameter = step.diffArtifactPath.map { .text($0) } ?? .null
        let backupPathParam: DatabaseParameter = step.backupPath.map { .text($0) } ?? .null
        try await database.execute("""
            INSERT INTO steps (
                runId, name, status, exitCode, durationMs, command, detail,
                artifactsJson, hashesJson, createdAt,
                started_at, finished_at, rewrite_path, verify_status,
                rollback_status, rollback_reason, rule_id,
                diff_artifact_path, backup_path
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(runId),
                .text(step.name),
                .text(step.status),
                .int(Int(step.exitCode)),
                .int(step.durationMs),
                .text(step.command),
                detailParam,
                .text(artifactsJson),
                .text(hashesJson),
                .text(now),
                startedAtParam,
                finishedAtParam,
                .text(step.rewritePath),
                .text(step.verifyStatus),
                .text(step.rollbackStatus),
                rollbackReasonParam,
                ruleIdParam,
                diffPathParam,
                backupPathParam
            ]
        )

        for (key, path) in step.artifacts {
            let hash = step.hashes[key]
            try await database.execute("""
                INSERT INTO artifacts (runId, stepName, key, path, hash, createdAt) VALUES (?, ?, ?, ?, ?, ?)
                """,
                parameters: [
                    .text(runId),
                    .text(step.name),
                    .text(key),
                    .text(path),
                    hash.map { .text($0) } ?? .null,
                    .text(now)
                ]
            )
        }
    }

    func recordRetentionEvent(description: String, runsRemoved: Int, bytesFreed: Int) async throws {
        let now = isoTimestamp(Date())
        try await database.execute("""
            INSERT INTO retention_events (timestamp, description, runsRemoved, bytesFreed)
            VALUES (?, ?, ?, ?)
            """,
            parameters: [
                .text(now),
                .text(description),
                .int(runsRemoved),
                .int(bytesFreed)
            ]
        )
    }

    func recordReplay(runId: String, verdict: String, detail: String?) async throws {
        let now = isoTimestamp(Date())
        try await database.execute("""
            INSERT OR REPLACE INTO replays (runId, verdict, detail, timestamp)
            VALUES (?, ?, ?, ?)
            """,
            parameters: [
                .text(runId),
                .text(verdict),
                detail.map { .text($0) } ?? .null,
                .text(now)
            ]
        )
    }

    func pruneRuns(olderThanDays days: Int) async throws -> Int {
        let positiveDays = max(1, days)
        let thresholdDate = Date().addingTimeInterval(-Double(positiveDays) * 86400)
        let threshold = isoTimestamp(thresholdDate)
        let rows = try await database.query(
            "SELECT runId FROM runs WHERE startedAt < ?",
            parameters: [.text(threshold)]
        )
        let runIds = rows.compactMap { $0.string(for: "runId") }
        guard !runIds.isEmpty else { return 0 }

        try await database.transaction {
            for runId in runIds {
                try await database.execute("DELETE FROM artifacts WHERE runId = ?", parameters: [.text(runId)])
                try await database.execute("DELETE FROM steps WHERE runId = ?", parameters: [.text(runId)])
                try await database.execute("DELETE FROM replays WHERE runId = ?", parameters: [.text(runId)])
            }
            let placeholders = runIds.map { _ in "?" }.joined(separator: ", ")
            let params = runIds.map { DatabaseParameter.text($0) }
            try await database.execute(
                "DELETE FROM runs WHERE runId IN (\(placeholders))",
                parameters: params
            )
        }

        try await recordRetentionEvent(
            description: "Pruned runs older than \(positiveDays) days",
            runsRemoved: runIds.count,
            bytesFreed: 0
        )

        return runIds.count
    }

    private func jsonString<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AccessumError.encodingFailed("unable to encode value")
        }
        return string
    }

    func adminSummary(stuckMinutes: Int) async throws -> AccessumAdminSummary {
        let totalRows = try await database.query("SELECT COUNT(*) AS total FROM runs")
        let totalRuns = totalRows.first?.int(for: "total") ?? 0

        let statusRows = try await database.query("SELECT status, COUNT(*) AS count FROM runs GROUP BY status")
        var counts: [String: Int] = [:]
        for row in statusRows {
            let status = row.string(for: "status") ?? "unknown"
            counts[status] = row.int(for: "count") ?? 0
        }

        let runningRows = try await database.query("""
            SELECT runId, status, lastUpdated, artifactDir
            FROM runs
            WHERE status = 'running'
            """)
        let threshold = Date().addingTimeInterval(-Double(max(1, stuckMinutes)) * 60)
        var stuckRuns: [AccessumRunSummary] = []

        for row in runningRows {
            guard let lastUpdated = row.string(for: "lastUpdated"),
                  let parsed = isoFormatter.date(from: lastUpdated),
                  parsed < threshold else {
                continue
            }
            let summary = AccessumRunSummary(
                runId: row.string(for: "runId") ?? "unknown",
                status: row.string(for: "status") ?? "running",
                lastUpdated: lastUpdated,
                artifactDir: row.string(for: "artifactDir")
            )
            stuckRuns.append(summary)
        }

        return AccessumAdminSummary(
            totalRuns: totalRuns,
            countsByStatus: counts,
            stuckThresholdMinutes: max(1, stuckMinutes),
            stuckRuns: stuckRuns
        )
    }

    private func isoTimestamp(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }
}

struct AccessumRunRecord {
    let runId: String
    let status: String
    let contractVersion: Int
    let timestamp: String
    let specRef: String
    let specPath: String
    let artifactDir: String
    let inputHash: String
    let specDataHash: String
    let outlineumInputHash: String
    let pipelineVersions: [String: String]
    let replayCommand: String
}

struct AccessumAdminSummary: Codable {
    let totalRuns: Int
    let countsByStatus: [String: Int]
    let stuckThresholdMinutes: Int
    let stuckRuns: [AccessumRunSummary]
}

struct AccessumRunSummary: Codable {
    let runId: String
    let status: String
    let lastUpdated: String
    let artifactDir: String?
}

struct AccessumAdminEnvelope: Codable {
    let contractVersion: Int
    let status: String
    let timestamp: String
    let command: String
    let payload: AccessumAdminPayload
    let governanceTrace: [String]
}

struct AccessumAdminPayload: Codable {
    let summary: AccessumAdminSummary
    let basePath: String
    let migrationTrace: MigrationTraceRecord?
}

struct AccessumStatusRecord: Codable {
    let runId: String?
    let status: String
    let message: String?
    let artifactDir: String?
    let timestamp: String
}

struct AccessumTrace: Codable, Equatable {
    let contractVersion: Int
    let status: String
    let timestamp: String
    let command: String
    let payload: AccessumPayload
    let governanceTrace: [String]
    let metrics: AccessumMetrics
}

struct AccessumMetrics: Codable, Equatable {
    let totalDurationMs: Int
    let stepCount: Int
}

struct AccessumPayload: Codable, Equatable {
    let runId: String
    let specRef: String
    let specPath: String
    let artifactDir: String
    let inputs: AccessumInputs
    let steps: [AccessumStep]
    let replay: AccessumReplay
}

struct AccessumInputs: Codable, Equatable {
    let inputHash: String
    let specDataHash: String
    let files: [AccessumInputFile]
}

struct AccessumInputFile: Codable, Equatable {
    let path: String
    let hash: String
    let byteCount: Int
}

struct AccessumStep: Codable, Equatable {
    let name: String
    let command: String
    let status: String
    let exitCode: Int32
    let durationMs: Int
    let artifacts: [String: String]
    let hashes: [String: String]
    let detail: String?
    let rewritePath: String
    let verifyStatus: String
    let rollbackStatus: String
    let rollbackReason: String?
    let ruleId: String?
    let diffArtifactPath: String?
    let backupPath: String?
    let startedAt: String?
    let finishedAt: String?

    init(
        name: String,
        command: String,
        status: String,
        exitCode: Int32,
        durationMs: Int,
        artifacts: [String: String],
        hashes: [String: String],
        detail: String? = nil,
        rewritePath: String = "none",
        verifyStatus: String = "not_run",
        rollbackStatus: String = "not_needed",
        rollbackReason: String? = nil,
        ruleId: String? = nil,
        diffArtifactPath: String? = nil,
        backupPath: String? = nil,
        startedAt: String? = nil,
        finishedAt: String? = nil
    ) {
        self.name = name
        self.command = command
        self.status = status
        self.exitCode = exitCode
        self.durationMs = durationMs
        self.artifacts = artifacts
        self.hashes = hashes
        self.detail = detail
        self.rewritePath = rewritePath
        self.verifyStatus = verifyStatus
        self.rollbackStatus = rollbackStatus
        self.rollbackReason = rollbackReason
        self.ruleId = ruleId
        self.diffArtifactPath = diffArtifactPath
        self.backupPath = backupPath
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

struct AccessumReplay: Codable, Equatable {
    let supported: Bool
    let command: String
}

private extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private enum AccessumError: Error, LocalizedError {
    case rootNotFound
    case commandFailed(executable: String, arguments: [String], exitCode: Int32)
    case missingBinary(String)
    case traceMissing(String)
    case replayDrift(String)
    case schemaVersionMismatch(current: Int, supported: Int)
    case encodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .rootNotFound:
            return "Unable to locate repo root (Package.swift)."
        case .commandFailed(let executable, let args, let exitCode):
            return "Command failed: \(executable) \(args.joined(separator: " ")) (exit \(exitCode))"
        case .missingBinary(let product):
            return "Binary for \(product) not found."
        case .traceMissing(let runId):
            return "Trace missing for runId \(runId)."
        case .replayDrift(let runId):
            return "Replay drift detected for runId \(runId)."
        case .schemaVersionMismatch(let current, let supported):
            return "Accessum DB schema (\(current)) is newer than this binary supports (\(supported))."
        case .encodingFailed(let detail):
            return "Failed to encode to JSON: \(detail)"
        }
    }
}
