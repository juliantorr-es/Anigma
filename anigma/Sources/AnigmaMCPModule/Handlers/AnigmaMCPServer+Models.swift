//
//  AnigmaMCPServer+Models.swift
//  AnigmaMCPModule
//
//  Model related tool handlers for MCP.
//

import Foundation
import MCP
import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import MLWorkerCommon
import ModelRegistry
import ModelRegistryModule
import CryptoKit

extension AnigmaMCPServer {
    func handleChat(arguments: [String: Value]?) async -> CallTool.Result {
        guard let message = arguments?["message"]?.stringValue else { return CallTool.Result(content: [.text("Missing message")], isError: true) }
        let modelID = arguments?["model_id"]?.stringValue ?? "llama-3.1-8b-instruct-4bit"
        let maxTokens = arguments?["max_tokens"]?.intValue ?? 512
        let temp = arguments?["temperature"]?.doubleValue ?? 0.7

        do {
            let input = try makeInputFromPrompt(message)
            defer {
                if input.isTemporary { try? FileManager.default.removeItem(atPath: input.path) }
            }

            let runtime: ModelRuntimeConfig
            if let registry = modelRegistry, let entry = try await registry.find(id: modelID) {
                runtime = try resolveRuntime(for: entry, task: .chat)
            } else {
                runtime = fallbackRuntime(for: modelID, task: .chat)
            }

            let request = WorkerRequest(
                requestId: UUID().uuidString,
                runId: UUID().uuidString,
                stepId: UUID().uuidString,
                engine: runtime.engine,
                task: .chat,
                inputs: [WorkerInput(path: input.path, hash: input.hash)],
                options: WorkerOptions(
                    seed: 42,
                    maxTokens: maxTokens,
                    temperature: temp,
                    topP: nil,
                    outputDirectory: nil
                )
            )

            let response = try runWorker(request: request, environment: runtime.environment)
            if response.status == .failed {
                return CallTool.Result(content: [.text(response.errorMessage ?? "Execution failed")], isError: true)
            }
            guard let output = response.outputs.first else {
                return CallTool.Result(content: [.text("No output artifact")], isError: true)
            }
            let responseText = try String(contentsOfFile: output.path, encoding: .utf8)
            return CallTool.Result(content: [.text(responseText)])
        } catch {
            return CallTool.Result(content: [.text("Chat execution error: \(error)")], isError: true)
        }
    }

    func handleListModels(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Listing models")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: "Querying registry")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        let taskRaw = arguments?["task"]?.stringValue
        do {
            let taskKind = try taskRaw.map { try parseModelTaskKind($0) }
            let models = try await modelRegistry.query(ModelQuery(taskKind: taskKind))
            let text = models.map {
                [
                    "ID: \($0.id)",
                    "Task: \($0.spec.task.rawValue)",
                    "Backend: \($0.spec.backend.rawValue)",
                    "Trust: \($0.spec.trustTier.rawValue)",
                    "Status: \($0.status.rawValue)",
                    "Source: \($0.spec.source.identifier)",
                    "Install: \($0.installPath)"
                ].joined(separator: "\n")
            }.joined(separator: "\n---\n\n")
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Models ready")
            return CallTool.Result(content: [.text(text.isEmpty ? "None" : text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    func handleDownloadModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Downloading model")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 3, currentItem: "Checking configuration")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelDownloader = modelDownloader else {
            return CallTool.Result(content: [.text("Model downloader pending")], isError: true)
        }
        guard let repo = arguments?["repo"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing repo")], isError: true)
        }
        let revision = arguments?["revision"]?.stringValue ?? "main"

        do {
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 3, currentItem: "Downloading and verifying")
            let result = try await modelDownloader.fetchAndVerify(repo: repo, revision: revision)
            let spec = try updateStorageBytes(spec: result.spec, installPath: result.installPath)
            let entry = try await modelRegistry.register(spec, installPath: result.installPath)
            var text = "Model ID: \(entry.id)\nInstall: \(entry.installPath)\nTrust: \(entry.spec.trustTier.rawValue)"
            if result.conversionNeeded {
                text += "\nConversion: required"
            }
            if !result.warnings.isEmpty {
                text += "\nWarnings: \(result.warnings.joined(separator: "; "))"
            }
            await progress?.updateProgress(itemsProcessed: 3, totalItems: 3, currentItem: "Download complete")
            return CallTool.Result(content: [.text(text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    func handleImportLocalModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Importing local model")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 3, currentItem: "Validating inputs")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let path = arguments?["path"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing path")], isError: true)
        }

        do {
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 3, currentItem: "Building artifact metadata")
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let (installPath, hashes, bytes) = try buildArtifactHashes(for: url)

            let modelId = arguments?["model_id"]?.stringValue ?? defaultModelId(for: url)
            let taskKind = try arguments?["task"]?.stringValue.map { try parseModelTaskKind($0) } ?? .inference
            let backend = try arguments?["backend"]?.stringValue.map { try parseBackend($0) } ?? inferBackend(for: url)
            let trustTier = try arguments?["trust_tier"]?.stringValue.map { try parseTrustTier($0) } ?? .compatible

            var metadata: [String: String] = [:]
            if url.pathExtension.lowercased() == "gguf" {
                metadata["model_file"] = url.lastPathComponent
            }

            let license = arguments?["license"]?.stringValue ?? "local"
            let licenseDecision = LicenseDecision(
                declared: license,
                allowed: true,
                reason: "Local import",
                timestamp: Date()
            )

            let spec = ModelSpec(
                id: modelId,
                source: .localPath(url.path),
                task: taskKind,
                backend: backend,
                trustTier: trustTier,
                license: licenseDecision,
                artifactHashes: hashes,
                tokenizerHash: nil,
                conversionReceipt: nil,
                metadata: metadata,
                registeredAt: Date(),
                verifiedAt: Date(),
                storageBytes: bytes
            )

            let entry = try await modelRegistry.register(spec, installPath: installPath)
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 3, currentItem: "Registering model")
            let text = "Model ID: \(entry.id)\nInstall: \(entry.installPath)\nTrust: \(entry.spec.trustTier.rawValue)"
            await progress?.updateProgress(itemsProcessed: 3, totalItems: 3, currentItem: "Model import complete")
            return CallTool.Result(content: [.text(text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    func handleDeleteModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Deleting model")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Locating model")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelId = arguments?["model_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing model_id")], isError: true)
        }
        let deleteFiles = arguments?["delete_files"]?.boolValue ?? false

        do {
            guard let entry = try await modelRegistry.find(id: modelId) else {
                return CallTool.Result(content: [.text("Model not found: \(modelId)")], isError: true)
            }
            if deleteFiles && !entry.installPath.isEmpty {
                let url = URL(fileURLWithPath: entry.installPath)
                if url.path.count > 1, FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            }
            try await modelRegistry.delete(modelId)
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Delete complete")
            return CallTool.Result(content: [.text("Deleted \(modelId)")])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    func handleVerifyModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Verifying model integrity")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: "Checking registry")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelId = arguments?["model_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing model_id")], isError: true)
        }
        do {
            let valid = try await modelRegistry.verifyIntegrity(modelId)
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Integrity check complete")
            return CallTool.Result(content: [.text("Model \(modelId) integrity: \(valid ? "valid" : "invalid")")])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    func handleRunModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Running model")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 3, currentItem: "Resolving model")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelId = arguments?["model_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing model_id")], isError: true)
        }

        let taskRaw = arguments?["task"]?.stringValue ?? "chat"
        let prompt = arguments?["prompt"]?.stringValue
        let inputPath = arguments?["input_path"]?.stringValue
        let seed = arguments?["seed"]?.intValue ?? 42
        let maxTokens = arguments?["max_tokens"]?.intValue
        let temperature = arguments?["temperature"]?.doubleValue
        let topP = arguments?["top_p"]?.doubleValue
        let outputDir = arguments?["output_dir"]?.stringValue
        let outputPath = arguments?["output_path"]?.stringValue

        do {
            guard let entry = try await modelRegistry.find(id: modelId) else {
                return CallTool.Result(content: [.text("Model not found: \(modelId)")], isError: true)
            }
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 3, currentItem: "Preparing worker")
            let workerTask = try parseWorkerTask(taskRaw)
            let runtime = try resolveRuntime(for: entry, task: workerTask)
            let input = try resolveInput(prompt: prompt, inputPath: inputPath)

            defer {
                if input.isTemporary { try? FileManager.default.removeItem(atPath: input.path) }
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

            let response = try runWorker(request: request, environment: runtime.environment)
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 3, currentItem: "Processing output")
            if response.status == .failed {
                return CallTool.Result(content: [.text(response.errorMessage ?? "Execution failed")], isError: true)
            }
            guard let output = response.outputs.first else {
                return CallTool.Result(content: [.text("No output artifact")], isError: true)
            }

            let outputText = try String(contentsOfFile: output.path, encoding: .utf8)
            if let outputPath {
                let outURL = URL(fileURLWithPath: outputPath)
                try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try outputText.write(to: outURL, atomically: true, encoding: .utf8)
            }

            let text = "Output:\n\(outputText)\n\nArtifact: \(output.path)\nHash: \(output.hash)"
            await progress?.updateProgress(itemsProcessed: 3, totalItems: 3, currentItem: "Model run complete")
            return CallTool.Result(content: [.text(text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    func handleRunEmbedding(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Running embedding")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 3, currentItem: "Resolving model")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelId = arguments?["model_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing model_id")], isError: true)
        }

        let text = arguments?["text"]?.stringValue
        let inputPath = arguments?["input_path"]?.stringValue
        let seed = arguments?["seed"]?.intValue ?? 42
        let outputDir = arguments?["output_dir"]?.stringValue

        do {
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 3, currentItem: "Preparing runtime")
            guard let entry = try await modelRegistry.find(id: modelId) else {
                return CallTool.Result(content: [.text("Model not found: \(modelId)")], isError: true)
            }

            let runtime = try resolveRuntime(for: entry, task: .embed)
            let input = try resolveInput(prompt: text, inputPath: inputPath)

            defer {
                if input.isTemporary { try? FileManager.default.removeItem(atPath: input.path) }
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

            let response = try runWorker(request: request, environment: runtime.environment)
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 3, currentItem: "Processing embedding")
            if response.status == .failed {
                return CallTool.Result(content: [.text(response.errorMessage ?? "Execution failed")], isError: true)
            }
            guard let output = response.outputs.first else {
                return CallTool.Result(content: [.text("No output artifact")], isError: true)
            }

            let summary = "Embedding artifact: \(output.path)\nHash: \(output.hash)"
            await progress?.updateProgress(itemsProcessed: 3, totalItems: 3, currentItem: "Embedding complete")
            return CallTool.Result(content: [.text(summary)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    // MARK: - Model Helpers

    private enum ModelToolError: Error, CustomStringConvertible {
        case invalidArgument(String)
        case unsupportedBackend(String)
        case workerNotFound
        case workerFailed(String)

        var description: String {
            switch self {
            case .invalidArgument(let message):
                return message
            case .unsupportedBackend(let backend):
                return "Backend not supported: \(backend)"
            case .workerNotFound:
                return "ml-worker binary not found"
            case .workerFailed(let message):
                return "ml-worker failed: \(message)"
            }
        }
    }

    private struct ModelRuntimeConfig {
        let engine: WorkerEngine
        let environment: [String: String]
    }

    private struct ModelInput {
        let path: String
        let hash: String
        let isTemporary: Bool
    }

    private func parseModelTaskKind(_ raw: String) throws -> ModelTaskKind {
        guard let task = ModelTaskKind(rawValue: raw) else {
            throw ModelToolError.invalidArgument("Unknown task: \(raw)")
        }
        return task
    }

    private func parseBackend(_ raw: String) throws -> MLBackend {
        guard let backend = MLBackend(rawValue: raw) else {
            throw ModelToolError.invalidArgument("Unknown backend: \(raw)")
        }
        return backend
    }

    private func parseTrustTier(_ raw: String) throws -> ModelTrustTier {
        guard let tier = ModelTrustTier(rawValue: raw) else {
            throw ModelToolError.invalidArgument("Unknown trust tier: \(raw)")
        }
        return tier
    }

    private func parseWorkerTask(_ raw: String) throws -> WorkerTask {
        guard let task = WorkerTask(rawValue: raw) else {
            throw ModelToolError.invalidArgument("Unknown worker task: \(raw)")
        }
        return task
    }

    private func resolveRuntime(for entry: ContractsCore.ModelRegistryEntry, task: WorkerTask) throws -> ModelRuntimeConfig {
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
            throw ModelToolError.unsupportedBackend(entry.spec.backend.rawValue)
        }
    }

    private func fallbackRuntime(for modelId: String, task: WorkerTask) -> ModelRuntimeConfig {
        var env = ProcessInfo.processInfo.environment
        env["MLX_MODEL_ID"] = modelId
        if task == .embed {
            env["MLX_MODEL_ID_EMBED"] = modelId
        } else {
            env["MLX_MODEL_ID_CHAT"] = modelId
        }
        return ModelRuntimeConfig(engine: .mlx, environment: env)
    }

    private func mlxIdentifier(for spec: ModelSpec) -> String {
        switch spec.source {
        case .huggingFace(let repo, _):
            return repo
        case .localPath(let path):
            return path
        case .bundled(let name):
            return name
        }
    }

    private func resolveGGUFModelPath(entry: ContractsCore.ModelRegistryEntry) throws -> String {
        if let file = entry.spec.metadata["model_file"] {
            return URL(fileURLWithPath: entry.installPath).appendingPathComponent(file).path
        }

        let baseURL = URL(fileURLWithPath: entry.installPath)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: baseURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return baseURL.path
        }

        let files = try FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
        if let gguf = files.first(where: { $0.pathExtension.lowercased() == "gguf" }) {
            return gguf.path
        }

        throw ModelToolError.invalidArgument("No .gguf file found in \(entry.installPath)")
    }

    private func resolveWorkerPath() -> String? {
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

    private func runWorker(request: WorkerRequest, environment: [String: String]) throws -> WorkerResponse {
        guard let workerPath = resolveWorkerPath() else {
            throw ModelToolError.workerNotFound
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
            throw ModelToolError.workerFailed(errorText)
        }

        let responseLine = outputData
            .split(separator: UInt8(ascii: "\n"))
            .first { !$0.isEmpty }
        guard let responseLine else {
            throw ModelToolError.workerFailed("No response from worker")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(WorkerResponse.self, from: Data(responseLine))
        } catch {
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ModelToolError.workerFailed("Decode failed: \(error). stderr: \(errorText)")
        }
    }

    private func resolveInput(prompt: String?, inputPath: String?) throws -> ModelInput {
        if let inputPath {
            return try makeInputFromFile(inputPath)
        }
        guard let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelToolError.invalidArgument("Provide prompt or input_path")
        }
        return try makeInputFromPrompt(prompt)
    }

    private func makeInputFromPrompt(_ prompt: String) throws -> ModelInput {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_prompt_\(UUID().uuidString).txt")
        try prompt.write(to: tempFile, atomically: true, encoding: .utf8)
        let hash = MLWorkerHasher.hashData(Data(prompt.utf8))
        return ModelInput(path: tempFile.path, hash: hash, isTemporary: true)
    }

    private func makeInputFromFile(_ path: String) throws -> ModelInput {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let hash = MLWorkerHasher.hashData(data)
        return ModelInput(path: url.path, hash: hash, isTemporary: false)
    }

    private func sha256Hex(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func buildArtifactHashes(for path: URL) throws -> (installPath: String, hashes: [String: String], bytes: Int64) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory) else {
            throw ModelToolError.invalidArgument("Path does not exist: \(path.path)")
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

    private func inferBackend(for path: URL) throws -> MLBackend {
        let ext = path.pathExtension.lowercased()
        if ext == "gguf" { return .gguf }
        if ext == "mlmodel" || ext == "mlpackage" { return .coreml }

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
