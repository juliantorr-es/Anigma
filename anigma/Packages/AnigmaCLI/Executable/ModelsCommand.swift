//
//  ModelsCommand.swift
//  AnigmaCLIExecutable
//
//  Model registry management and ML worker execution commands.
//

import ArgumentParser
import ContractsCore
import CryptoKit
import Foundation
import MLWorkerCommon
import ModelRegistry

private typealias WorkerArtifact = MLWorkerCommon.MLWorkerArtifact
private typealias WorkerEngine = ContractsCore.MLWorkerEngine
private typealias WorkerInput = MLWorkerCommon.MLArtifactRef
private typealias WorkerMetrics = MLWorkerCommon.MLWorkerMetrics
private typealias WorkerOptions = ContractsCore.MLTaskOptions
private typealias WorkerRequest = MLWorkerCommon.MLWorkerRequest
private typealias WorkerResponse = MLWorkerCommon.MLWorkerResponse
private typealias WorkerTask = ContractsCore.MLWorkerTask

struct AnigmaModelsCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "models",
            abstract: "Manage local models (download, import, verify, run).",
            subcommands: [
                ModelsListCommand.self,
                ModelsDownloadCommand.self,
                ModelsImportCommand.self,
                ModelsDeleteCommand.self,
                ModelsVerifyCommand.self,
                ModelsRunCommand.self,
                ModelsEmbedCommand.self
            ]
        )
    }
}

private enum ModelCLIError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case invalidTask(String)
    case invalidBackend(String)
    case invalidTrustTier(String)
    case modelNotFound(String)
    case unsupportedBackend(String)
    case workerNotFound
    case workerFailed(String)
    case outputMissing

    var description: String {
        switch self {
        case .invalidArguments(let message):
            return message
        case .invalidTask(let value):
            return "Unknown task: \(value)"
        case .invalidBackend(let value):
            return "Unknown backend: \(value)"
        case .invalidTrustTier(let value):
            return "Unknown trust tier: \(value)"
        case .modelNotFound(let modelId):
            return "Model not found: \(modelId)"
        case .unsupportedBackend(let backend):
            return "Backend not supported for execution: \(backend)"
        case .workerNotFound:
            return "ml-worker binary not found (set ML_WORKER_PATH or build the target)"
        case .workerFailed(let message):
            return "ml-worker failed: \(message)"
        case .outputMissing:
            return "Model execution produced no output artifact"
        }
    }
}

private enum ModelCLIPaths {
    static func anigmaDirectory() throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Failed to unwrap appSupport")
        }
        let anigmaDir = appSupport.appendingPathComponent("Anigma", isDirectory: true)
        try FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)
        return anigmaDir
    }

    static func registryPath() throws -> String {
        try anigmaDirectory().appendingPathComponent("models.sqlite").path
    }

    static func modelCacheDirectory() throws -> URL {
        let cacheDir = try anigmaDirectory().appendingPathComponent("ModelCache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }
}

private enum ModelCLIRegistry {
    static func openRegistry() async throws -> ModelRegistryStore {
        let path = try ModelCLIPaths.registryPath()
        return try await ModelRegistryStore(storagePath: path)
    }
}

private enum ModelCLIParsing {
    static func parseTaskKind(_ raw: String) throws -> ModelTaskKind {
        guard let task = ModelTaskKind(rawValue: raw) else {
            throw ModelCLIError.invalidTask(raw)
        }
        return task
    }

    static func parseTrustTier(_ raw: String) throws -> ModelTrustTier {
        guard let tier = ModelTrustTier(rawValue: raw) else {
            throw ModelCLIError.invalidTrustTier(raw)
        }
        return tier
    }

    static func parseBackend(_ raw: String) throws -> MLBackend {
        guard let backend = MLBackend(rawValue: raw) else {
            throw ModelCLIError.invalidBackend(raw)
        }
        return backend
    }
}

private struct ModelCLIInput {
    let path: String
    let hash: String
    let isTemporary: Bool

    static func fromText(_ text: String) throws -> ModelCLIInput {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma_prompt_\(UUID().uuidString).txt")
        try text.write(to: tempFile, atomically: true, encoding: .utf8)
        let data = Data(text.utf8)
        let hash = MLWorkerHasher.hashData(data)
        return ModelCLIInput(path: tempFile.path, hash: hash, isTemporary: true)
    }

    static func fromFile(_ path: String) throws -> ModelCLIInput {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let hash = MLWorkerHasher.hashData(data)
        return ModelCLIInput(path: url.path, hash: hash, isTemporary: false)
    }
}

private enum ModelCLIHasher {
    static func sha256Hex(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty {
                break
            }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func buildArtifactHashes(for path: URL) throws -> (installPath: String, hashes: [String: String], bytes: Int64) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory) else {
            throw ModelCLIError.invalidArguments("Path does not exist: \(path.path)")
        }

        if !isDirectory.boolValue {
            let hash = try sha256Hex(url: path)
            let parent = path.deletingLastPathComponent()
            let size = try path.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return (parent.path, [path.lastPathComponent: hash], Int64(size))
        }

        let basePath = path.path
        let enumerator = FileManager.default.enumerator(
            at: path,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var hashes: [String: String] = [:]
        var bytes: Int64 = 0

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: basePath + "/", with: "")
            let hash = try sha256Hex(url: fileURL)
            hashes[relativePath] = hash
            bytes += Int64(values.fileSize ?? 0)
        }

        return (basePath, hashes, bytes)
    }
}

private struct ModelRuntimeConfig {
    let engine: WorkerEngine
    let environment: [String: String]
}

private enum ModelCLIRuntime {
    static func resolveRuntime(for entry: ModelRegistryEntry, task: WorkerTask) throws -> ModelRuntimeConfig {
        switch entry.spec.backend {
        case .mlx:
            var env = ProcessInfo.processInfo.environment
            let identifier = mlxIdentifier(for: entry.spec)
            env["MLX_MODEL_ID"] = identifier
            if task == .embed {
                env["MLX_MODEL_ID_EMBED"] = identifier
            } else {
                env["MLX_MODEL_ID_CHAT"] = identifier
            }
            if !entry.installPath.isEmpty {
                env["MLX_MODEL_PATH"] = entry.installPath
            }
            return ModelRuntimeConfig(engine: .mlx, environment: env)
        case .gguf:
            var env = ProcessInfo.processInfo.environment
            let modelPath = try resolveGGUFModelPath(entry: entry)
            env["LLAMA_MODEL_PATH"] = modelPath
            return ModelRuntimeConfig(engine: .llama, environment: env)
        case .coreml:
            throw ModelCLIError.unsupportedBackend(entry.spec.backend.rawValue)
        }
    }

    private static func mlxIdentifier(for spec: ModelSpec) -> String {
        switch spec.source {
        case .huggingFace(let repo, _):
            return repo
        case .localPath(let path):
            return path
        case .bundled(let name):
            return name
        }
    }

    private static func resolveGGUFModelPath(entry: ModelRegistryEntry) throws -> String {
        if let file = entry.spec.metadata["model_file"] {
            return URL(fileURLWithPath: entry.installPath).appendingPathComponent(file).path
        }

        let baseURL = URL(fileURLWithPath: entry.installPath)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: baseURL.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                return baseURL.path
            }
        }

        let files = try FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
        if let gguf = files.first(where: { $0.pathExtension.lowercased() == "gguf" }) {
            return gguf.path
        }

        throw ModelCLIError.invalidArguments("No .gguf file found in \(entry.installPath)")
    }
}

private enum ModelCLIWorker {
    static func resolveWorkerPath() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let override = env["ML_WORKER_PATH"], FileManager.default.isExecutableFile(atPath: override) {
            return override
        }

        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            "\(cwd)/.build/arm64-apple-macosx/release/ml-worker",
            "\(cwd)/.build/arm64-apple-macosx/debug/ml-worker",
            "\(cwd)/.build/release/ml-worker",
            "\(cwd)/.build/debug/ml-worker",
            "/usr/local/bin/ml-worker"
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func run(
        request: WorkerRequest,
        environment: [String: String]
    ) throws -> WorkerResponse {
        guard let workerPath = resolveWorkerPath() else {
            throw ModelCLIError.workerNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: workerPath)
        process.arguments = ["--engine", request.engine.rawValue]
        process.environment = environment

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payload = try encoder.encode(request)
        inputPipe.fileHandleForWriting.write(payload + Data("\n".utf8))
        try inputPipe.fileHandleForWriting.close()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ModelCLIError.workerFailed(errorText)
        }

        let responseLine = outputData
            .split(separator: UInt8(ascii: "\n"))
            .first { !$0.isEmpty }
        guard let responseLine else {
            throw ModelCLIError.workerFailed("No response from worker")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(WorkerResponse.self, from: Data(responseLine))
        } catch {
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ModelCLIError.workerFailed("Decode failed: \(error). stderr: \(errorText)")
        }
    }
}

private struct ModelListPayload: Encodable {
    let models: [ModelSummary]
}

private struct ModelSummary: Encodable {
    let id: String
    let task: String
    let backend: String
    let trustTier: String
    let status: String
    let runnable: Bool
    let source: String
    let installPath: String
    let storageBytes: Int64
    let lastUsed: Date?
    let usageCount: Int64
}

struct ModelsListCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "list",
            abstract: "List registered models."
        )
    }

    @OptionGroup var output: OutputOptions

    @Option(name: .long, help: "Filter by task (inference|embedding|transcription|classification|image_generation|speech_synthesis).")
    var task: String?

    @Option(name: .long, help: "Filter by backend (mlx|gguf|coreml).")
    var backend: String?

    @Option(name: .long, help: "Filter by trust tier (first_class|compatible|experimental|quarantined).")
    var trustTier: String?

    @Flag(name: .long, help: "Only show runnable models.")
    var runnableOnly: Bool = false

    mutating func run() async throws {
        let registry = try await ModelCLIRegistry.openRegistry()

        let taskKind = try task.map { try ModelCLIParsing.parseTaskKind($0) }
        let backendKind = try backend.map { try ModelCLIParsing.parseBackend($0) }
        let tierKind = try trustTier.map { try ModelCLIParsing.parseTrustTier($0) }

        let query = ModelQuery(
            taskKind: taskKind,
            backend: backendKind,
            trustTier: tierKind,
            runnableOnly: runnableOnly
        )

        let entries = try await registry.query(query)
        let summaries = entries.map { entry in
            ModelSummary(
                id: entry.id,
                task: entry.spec.task.rawValue,
                backend: entry.spec.backend.rawValue,
                trustTier: entry.spec.trustTier.rawValue,
                status: entry.status.rawValue,
                runnable: entry.spec.isRunnable,
                source: entry.spec.source.identifier,
                installPath: entry.installPath,
                storageBytes: entry.spec.storageBytes,
                lastUsed: entry.lastUsed,
                usageCount: entry.usageCount
            )
        }

        switch output.format {
        case .json:
            try OutputWriter.emit(
                command: "anigma.models.list",
                payload: ModelListPayload(models: summaries),
                format: output.format
            )
        case .text:
            if summaries.isEmpty {
                print("No models registered.")
                return
            }
            for summary in summaries {
                let exists = FileManager.default.fileExists(atPath: summary.installPath)
                let existsLabel = summary.installPath.isEmpty ? "n/a" : (exists ? "present" : "missing")
                print("- \(summary.id) [\(summary.task) / \(summary.backend) / \(summary.trustTier)] status=\(summary.status)")
                print("  source: \(summary.source)")
                print("  install: \(summary.installPath) (\(existsLabel))")
            }
        }
    }
}

private struct ModelImportPayload: Encodable {
    let modelId: String
    let installPath: String
    let trustTier: String
    let warnings: [String]
}

struct ModelsImportCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "import",
            abstract: "Import a model from HuggingFace or a local path."
        )
    }

    @OptionGroup var output: OutputOptions

    @Option(name: .long, help: "HuggingFace repo id (e.g. mlx-community/Qwen3-4B-4bit).")
    var repo: String?

    @Option(name: .long, help: "HuggingFace revision (default: main).")
    var revision: String = "main"

    @Option(name: .long, help: "Local path to model file or directory.")
    var path: String?

    @Option(name: .long, help: "Explicit model id for local import.")
    var modelId: String?

    @Option(name: .long, help: "Task kind for local import.")
    var task: String?

    @Option(name: .long, help: "Backend for local import (mlx|gguf|coreml).")
    var backend: String?

    @Option(name: .long, help: "Trust tier for local import (first_class|compatible|experimental|quarantined).")
    var trustTier: String?

    @Option(name: .long, help: "License identifier for local import.")
    var license: String?

    mutating func run() async throws {
        if (repo == nil && path == nil) || (repo != nil && path != nil) {
            throw ModelCLIError.invalidArguments("Specify either --repo or --path.")
        }

        let registry = try await ModelCLIRegistry.openRegistry()
        let cacheDir = try ModelCLIPaths.modelCacheDirectory()

        if let repo {
            let adapter = HuggingFaceAdapter(artifactStore: cacheDir)
            let result = try await adapter.fetchAndVerify(repo: repo, revision: revision)

            let updatedSpec = try updateStorageBytes(spec: result.spec, installPath: result.installPath)
            let entry = try await registry.register(updatedSpec, installPath: result.installPath)

            let payload = ModelImportPayload(
                modelId: entry.id,
                installPath: entry.installPath,
                trustTier: entry.spec.trustTier.rawValue,
                warnings: result.warnings
            )
            return try emitImportPayload(payload)
        }

        guard let path else {
            throw ModelCLIError.invalidArguments("Missing --path.")
        }

        let absolutePath = URL(fileURLWithPath: path).standardizedFileURL
        let (installPath, artifactHashes, storageBytes) = try ModelCLIHasher.buildArtifactHashes(for: absolutePath)

        let modelId = modelId ?? defaultModelId(for: absolutePath)
        let taskKind = try (task.map { try ModelCLIParsing.parseTaskKind($0) } ?? .inference)
        let backendKind = try (backend.map { try ModelCLIParsing.parseBackend($0) } ?? inferBackend(for: absolutePath))
        let trustTier = try (trustTier.map { try ModelCLIParsing.parseTrustTier($0) } ?? .compatible)

        var metadata: [String: String] = [:]
        if absolutePath.pathExtension.lowercased() == "gguf" {
            metadata["model_file"] = absolutePath.lastPathComponent
        }

        let licenseDecision = LicenseDecision(
            declared: license ?? "local",
            allowed: true,
            reason: "Local import",
            timestamp: Date()
        )

        let spec = ModelSpec(
            id: modelId,
            source: .localPath(absolutePath.path),
            task: taskKind,
            backend: backendKind,
            trustTier: trustTier,
            license: licenseDecision,
            artifactHashes: artifactHashes,
            tokenizerHash: nil,
            conversionReceipt: nil,
            metadata: metadata,
            registeredAt: Date(),
            verifiedAt: Date(),
            storageBytes: storageBytes
        )

        let entry = try await registry.register(spec, installPath: installPath)
        let payload = ModelImportPayload(
            modelId: entry.id,
            installPath: entry.installPath,
            trustTier: entry.spec.trustTier.rawValue,
            warnings: []
        )
        try emitImportPayload(payload)
    }

    private func emitImportPayload(_ payload: ModelImportPayload) throws {
        switch output.format {
        case .json:
            try OutputWriter.emit(
                command: "anigma.models.import",
                payload: payload,
                format: output.format
            )
        case .text:
            print("Model ID: \(payload.modelId)")
            print("Install Path: \(payload.installPath)")
            print("Trust Tier: \(payload.trustTier)")
            if !payload.warnings.isEmpty {
                print("Warnings: \(payload.warnings.joined(separator: "; "))")
            }
        }
    }

    private func inferBackend(for path: URL) throws -> MLBackend {
        if path.pathExtension.lowercased() == "gguf" {
            return .gguf
        }
        if path.pathExtension.lowercased() == "mlmodel"
            || path.pathExtension.lowercased() == "mlpackage" {
            return .coreml
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory), isDirectory.boolValue {
            let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "gguf" { return .gguf }
                if ext == "mlmodel" || ext == "mlpackage" { return .coreml }
                if ext == "safetensors" { return .mlx }
            }
        }

        return .mlx
    }

    private func defaultModelId(for path: URL) -> String {
        let base = path.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "local-model-\(UUID().uuidString)" : base
    }

    private func updateStorageBytes(spec: ModelSpec, installPath: String) throws -> ModelSpec {
        guard !installPath.isEmpty else { return spec }
        let url = URL(fileURLWithPath: installPath)
        var bytes: Int64 = 0

        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else { continue }
                bytes += Int64(values.fileSize ?? 0)
            }
        }

        return ModelSpec(
            id: spec.id,
            source: spec.source,
            task: spec.task,
            backend: spec.backend,
            trustTier: spec.trustTier,
            license: spec.license,
            artifactHashes: spec.artifactHashes,
            tokenizerHash: spec.tokenizerHash,
            conversionReceipt: spec.conversionReceipt,
            metadata: spec.metadata,
            registeredAt: spec.registeredAt,
            verifiedAt: spec.verifiedAt,
            storageBytes: bytes
        )
    }
}

private struct ModelDeletePayload: Encodable {
    let modelId: String
    let deletedFiles: Bool
}

struct ModelsDeleteCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a model from the registry."
        )
    }

    @OptionGroup var output: OutputOptions

    @Argument(help: "Model id to delete.")
    var modelId: String

    @Flag(name: .long, help: "Delete model files from disk.")
    var deleteFiles: Bool = false

    mutating func run() async throws {
        let registry = try await ModelCLIRegistry.openRegistry()
        guard let entry = try await registry.find(id: modelId) else {
            throw ModelCLIError.modelNotFound(modelId)
        }

        var deletedFiles = false
        if deleteFiles && !entry.installPath.isEmpty {
            let url = URL(fileURLWithPath: entry.installPath)
            if url.path.count > 1, FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                deletedFiles = true
            }
        }

        try await registry.delete(modelId)

        let payload = ModelDeletePayload(modelId: modelId, deletedFiles: deletedFiles)
        switch output.format {
        case .json:
            try OutputWriter.emit(
                command: "anigma.models.delete",
                payload: payload,
                format: output.format
            )
        case .text:
            print("Deleted \(payload.modelId). Files deleted: \(payload.deletedFiles)")
        }
    }
}

private struct ModelVerifyPayload: Encodable {
    let modelId: String
    let valid: Bool
}

struct ModelsVerifyCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "verify",
            abstract: "Verify model integrity."
        )
    }

    @OptionGroup var output: OutputOptions

    @Argument(help: "Model id to verify.")
    var modelId: String

    mutating func run() async throws {
        let registry = try await ModelCLIRegistry.openRegistry()
        let valid = try await registry.verifyIntegrity(modelId)

        let payload = ModelVerifyPayload(modelId: modelId, valid: valid)
        switch output.format {
        case .json:
            try OutputWriter.emit(
                command: "anigma.models.verify",
                payload: payload,
                format: output.format
            )
        case .text:
            print("Model \(modelId) integrity: \(valid ? "valid" : "invalid")")
        }
    }
}

private struct ModelRunPayload: Encodable {
    let modelId: String
    let task: String
    let engine: String
    let outputText: String?
    let outputs: [WorkerArtifact]
    let metrics: WorkerMetrics?
}

struct ModelsRunCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "run",
            abstract: "Run an inference task using a registered model."
        )
    }

    @OptionGroup var output: OutputOptions

    @Argument(help: "Model id to execute.")
    var modelId: String

    @Option(name: .long, help: "Task (chat|summarize|classify|transcribe).")
    var task: String = "chat"

    @Option(name: .long, help: "Prompt text.")
    var prompt: String?

    @Option(name: .long, help: "Input file path.")
    var inputPath: String?

    @Option(name: .long, help: "Max tokens.")
    var maxTokens: Int?

    @Option(name: .long, help: "Temperature.")
    var temperature: Double?

    @Option(name: .long, help: "Top-p.")
    var topP: Double?

    @Option(name: .long, help: "Seed.")
    var seed: Int = 42

    @Option(name: .long, help: "Output directory for artifacts.")
    var outputDir: String?

    @Option(name: .long, help: "Write output text to this file.")
    var outputPath: String?

    mutating func run() async throws {
        let registry = try await ModelCLIRegistry.openRegistry()
        guard let entry = try await registry.find(id: modelId) else {
            throw ModelCLIError.modelNotFound(modelId)
        }

        let workerTask = try parseWorkerTask(task)
        let runtime = try ModelCLIRuntime.resolveRuntime(for: entry, task: workerTask)

        let input = try resolveInput()
        defer {
            if input.isTemporary {
                try? FileManager.default.removeItem(atPath: input.path)
            }
        }

        let request = WorkerRequest(
            requestId: UUID().uuidString,
            runId: UUID().uuidString,
            stepId: UUID().uuidString,
            engine: runtime.engine,
            task: workerTask,
            inputs: [WorkerInput(path: input.path, hash: input.hash)],
            options: WorkerOptions(
                seed: seed,
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP,
                outputDirectory: outputDir
            )
        )

        let response = try ModelCLIWorker.run(request: request, environment: runtime.environment)
        if response.status == .failed {
            throw ModelCLIError.workerFailed(response.errorMessage ?? "Execution failed")
        }

        guard let outputArtifact = response.outputs.first else {
            throw ModelCLIError.outputMissing
        }

        let outputText = try String(contentsOfFile: outputArtifact.path, encoding: .utf8)
        if let outputPath {
            let outURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try outputText.write(to: outURL, atomically: true, encoding: .utf8)
        }

        let payload = ModelRunPayload(
            modelId: modelId,
            task: workerTask.rawValue,
            engine: runtime.engine.rawValue,
            outputText: outputText,
            outputs: response.outputs,
            metrics: response.metrics
        )

        switch output.format {
        case .json:
            try OutputWriter.emit(
                command: "anigma.models.run",
                payload: payload,
                format: output.format
            )
        case .text:
            print(outputText)
        }
    }

    private func parseWorkerTask(_ raw: String) throws -> WorkerTask {
        guard let task = WorkerTask(rawValue: raw) else {
            throw ModelCLIError.invalidTask(raw)
        }
        return task
    }

    private func resolveInput() throws -> ModelCLIInput {
        if let inputPath {
            return try ModelCLIInput.fromFile(inputPath)
        }
        guard let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelCLIError.invalidArguments("Provide --prompt or --input-path.")
        }
        return try ModelCLIInput.fromText(prompt)
    }
}

private struct ModelEmbedPayload: Encodable {
    let modelId: String
    let engine: String
    let output: WorkerArtifact
    let metrics: WorkerMetrics?
}

struct ModelsEmbedCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "embed",
            abstract: "Generate embeddings using a registered model."
        )
    }

    @OptionGroup var output: OutputOptions

    @Argument(help: "Model id to execute.")
    var modelId: String

    @Option(name: .long, help: "Text to embed.")
    var text: String?

    @Option(name: .long, help: "Input file path.")
    var inputPath: String?

    @Option(name: .long, help: "Seed.")
    var seed: Int = 42

    @Option(name: .long, help: "Output directory for artifacts.")
    var outputDir: String?

    @Option(name: .long, help: "Copy embedding header JSON to this path.")
    var outputPath: String?

    mutating func run() async throws {
        let registry = try await ModelCLIRegistry.openRegistry()
        guard let entry = try await registry.find(id: modelId) else {
            throw ModelCLIError.modelNotFound(modelId)
        }

        let runtime = try ModelCLIRuntime.resolveRuntime(for: entry, task: .embed)

        let input = try resolveInput()
        defer {
            if input.isTemporary {
                try? FileManager.default.removeItem(atPath: input.path)
            }
        }

        let request = WorkerRequest(
            requestId: UUID().uuidString,
            runId: UUID().uuidString,
            stepId: UUID().uuidString,
            engine: runtime.engine,
            task: .embed,
            inputs: [WorkerInput(path: input.path, hash: input.hash)],
            options: WorkerOptions(
                seed: seed,
                maxTokens: nil,
                temperature: nil,
                topP: nil,
                outputDirectory: outputDir
            )
        )

        let response = try ModelCLIWorker.run(request: request, environment: runtime.environment)
        if response.status == .failed {
            throw ModelCLIError.workerFailed(response.errorMessage ?? "Execution failed")
        }

        guard let outputArtifact = response.outputs.first else {
            throw ModelCLIError.outputMissing
        }

        if let outputPath {
            let outURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(atPath: outputArtifact.path, toPath: outURL.path)
        }

        let payload = ModelEmbedPayload(
            modelId: modelId,
            engine: runtime.engine.rawValue,
            output: outputArtifact,
            metrics: response.metrics
        )

        switch output.format {
        case .json:
            try OutputWriter.emit(
                command: "anigma.models.embed",
                payload: payload,
                format: output.format
            )
        case .text:
            print("Embedding artifact: \(outputArtifact.path)")
        }
    }

    private func resolveInput() throws -> ModelCLIInput {
        if let inputPath {
            return try ModelCLIInput.fromFile(inputPath)
        }
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelCLIError.invalidArguments("Provide --text or --input-path.")
        }
        return try ModelCLIInput.fromText(text)
    }
}
