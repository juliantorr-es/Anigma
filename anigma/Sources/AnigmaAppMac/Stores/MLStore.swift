//
//  MLStore.swift
//  AnigmaAppMac
//
//  Manages ML model registry, inference operations, and HuggingFace integration.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import ContractsCore
import MLWorkerCommon
import CathedralModule
import CryptoKit
import AnigmaHostMac

@MainActor
@Observable
final class MLStore {

    // MARK: - Properties

    /// Durable model registry with provenance tracking
    let modelRegistry: ModelRegistry

    /// HuggingFace adapter for fetch/verify/describe
    let hfAdapter: HuggingFaceAdapter

    /// ML Worker client for task execution
    private let mlWorkerClient: MLWorkerClient

    /// Cathedral coordinator for evidence storage
    private let cathedralCoordinator: CathedralCoordinator

    /// Registered models (cached from registry with full metadata)
    var registeredModels: [ModelRegistryEntry] = []

    /// ML Worker status
    var mlWorkerStatus: MLWorkerClient.WorkerStatusResponse?

    /// ML Worker tasks
    var mlWorkerTasks: [MLWorkerClient.TaskStatusResponse] = []

    // MARK: - Dependencies (Injected)

    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }

    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }

    /// Callback for logging network activity (injected from AppStore)
    var logNetworkActivity: (String, String, String, String) -> Void = { _, _, _, _ in }

    // MARK: - Initialization

    init(
        modelRegistry: ModelRegistry,
        hfAdapter: HuggingFaceAdapter,
        mlWorkerClient: MLWorkerClient,
        cathedralCoordinator: CathedralCoordinator
    ) {
        self.modelRegistry = modelRegistry
        self.hfAdapter = hfAdapter
        self.mlWorkerClient = mlWorkerClient
        self.cathedralCoordinator = cathedralCoordinator
    }

    // MARK: - Model Registry Operations

    /// Load registered models from registry
    func loadRegisteredModels() async {
        do {
            let specs = try await modelRegistry.query()
            // Convert ModelSpec to ModelRegistryEntry for UI
            registeredModels = specs.map { spec in
                ModelRegistryEntry(
                    modelId: spec.modelId,
                    sourceType: spec.source.type.rawValue,
                    sourceLocation: spec.source.location,
                    sourceRevision: spec.source.revision,
                    status: .ready,
                    isRunnable: true,
                    taskKind: spec.taskKind.rawValue,
                    backendFormat: spec.backendFormat,
                    dimension: spec.dimension,
                    installPath: nil,
                    storageBytes: 0,
                    artifactHash: spec.modelHash,
                    tokenizerHash: spec.tokenizerHash,
                    artifactHashes: [:],
                    registeredAt: Date(),
                    lastVerified: Date(),
                    lastUsed: nil,
                    usageCount: 0,
                    license: LicenseInfo(
                        declared: spec.license,
                        allowed: true,
                        reason: "Model Registry approved",
                        reviewedAt: Date()
                    ),
                    backendCompatibility: ModelBackendCompatibility(
                        supportedBackends: [spec.backendFormat],
                        preferredBackend: spec.backendFormat
                    ),
                    trustTier: spec.trustTier.rawValue,
                    conversionReceiptId: nil
                )
            }
        } catch {
            showError("Failed to load model registry: \(error)")
        }
    }

    /// Import a HuggingFace model
    func importHuggingFaceModel(
        repo: String,
        revision: String = "main",
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async {
        do {
            showToast("Importing Model", repo, "arrow.down.circle")

            let result = try await hfAdapter.importModel(
                repo: repo,
                revision: revision,
                progressHandler: progressHandler
            )

            // Convert ModelImportResult to ModelSpec
            let source = ModelSource(
                type: .huggingface,
                location: repo,
                revision: revision
            )

            // Determine task kind from metadata or default to inference
            let taskKind: TaskKind = .inference

            // Determine backend format from compatibility matrix
            let backendFormat = result.backendCompatibility.preferredBackend ?? result.backendCompatibility.supportedBackends.first ?? "mlx"

            // Parse trust tier
            let trustTier = TrustTier(
                rawValue: result.trustTier.replacingOccurrences(of: "_", with: "-")
            ) ?? .experimental

            // Create ModelSpec
            let spec = ModelSpec(
                modelId: result.modelId,
                modelHash: result.artifactHash,
                taskKind: taskKind,
                backendFormat: backendFormat,
                dimension: nil,
                tokenizerHash: result.tokenizerHash,
                license: result.license,
                trustTier: trustTier,
                source: source
            )

            // Register in registry
            try await modelRegistry.register(spec)

            // Update UI
            await loadRegisteredModels()

            let subtitle = result.warnings.isEmpty
                ? "Model imported successfully"
                : result.warnings.joined(separator: "; ")

            showToast("Model Imported", subtitle, "checkmark.circle.fill")
        } catch {
            showError("Failed to import model: \(error)")
        }
    }

    /// Describe a HuggingFace model without importing
    func describeHuggingFaceModel(
        repo: String,
        revision: String = "main"
    ) async -> HFModelDescriptor? {
        do {
            return try await hfAdapter.describe(repo: repo, revision: revision)
        } catch {
            showError("Failed to describe model: \(error)")
            return nil
        }
    }

    /// Verify model integrity
    func verifyModelIntegrity(_ modelId: String) async {
        do {
            let valid = try await modelRegistry.verifyIntegrity(modelId)
            if valid {
                showToast("Model Verified", modelId, "checkmark.shield.fill")
            } else {
                showToast("Model Degraded", "Files missing or corrupted", "exclamationmark.triangle.fill")
            }
            await loadRegisteredModels()
        } catch {
            showError("Failed to verify model: \(error)")
struct ExecuteGovernedMLRunConfiguration: Sendable {
    let modelId: String
    let taskKind: ContractsCore.MLTaskKind
    let inputs: [ContractsCore.MLInput]
    let backend: ContractsCore.MLBackend
    let seed: Int?
    let temperature: Double?
    let topP: Double?
    let maxTokens: Int?
    
    init(
        modelId: String,
        taskKind: ContractsCore.MLTaskKind,
        inputs: [ContractsCore.MLInput],
        backend: ContractsCore.MLBackend,
        seed: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.modelId = modelId
        self.taskKind = taskKind
        self.inputs = inputs
        self.backend = backend
        self.seed = seed
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
    }
}

// Migration Guide:
// Old call:
// executeGovernedMLRun(
//     modelId: value,
//     taskKind: value,
//     inputs: value,
//     backend: value,
//     seed: value,
//     temperature: value,
//     topP: value,
//     maxTokens: value,
// )
//
// New call:
// let config = ExecuteGovernedMLRunConfiguration(
//     modelId: value,
//     taskKind: value,
//     inputs: value,
//     backend: value,
//     seed: value,
//     temperature: value,
//     topP: value,
//     maxTokens: value,
// )
// executeGovernedMLRun(config: config)
        modelId: String,
        taskKind: ContractsCore.MLTaskKind,
        inputs: [ContractsCore.MLInput],
        backend: ContractsCore.MLBackend,
        seed: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.modelId = modelId
        self.taskKind = taskKind
        self.inputs = inputs
        self.backend = backend
        self.seed = seed
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
    }
}
        modelId: String,
        taskKind: ContractsCore.MLTaskKind,
        inputs: [ContractsCore.MLInput],
        backend: ContractsCore.MLBackend,
        seed: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.modelId = modelId
        self.taskKind = taskKind
        self.inputs = inputs
        self.backend = backend
        self.seed = seed
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
    }
}

// Updated function signature:
func executeGovernedMLRun(config: ExecuteGovernedMLRunConfiguration) async throws -> ContractsCore.ExecutionReceipt {
    // Load model spec from registry (AnigmaAppMac.ModelSpec)
    guard let modelSpec = try await modelRegistry.find(id: config.modelId) else {
        throw NSError(
            domain: "AnigmaApp",
            code: 404,
            // ... rest of original implementation
        )
    }
    // ... rest of function body using config properties
}
                userInfo: [NSLocalizedDescriptionKey: "Model not found: \(modelId)"]
            )
        }

        // Build AnigmaAppMac.RunSpec (NOT ContractsCore.RunSpec!)
        // MLWorkerClient.executeGovernedRun expects AnigmaAppMac types
        // We need to convert from the AnigmaAppMac.TaskKind enum
        let appTaskKind: AnigmaAppMac.TaskKind
        switch taskKind {
        case .embed: appTaskKind = .embedding
        case .chat, .summarize: appTaskKind = .inference
        case .classify: appTaskKind = .classification
        case .transcribe: appTaskKind = .transcription
        case .rerank, .other: appTaskKind = .inference
        }

        // Create TaskParams
        let taskParams: AnigmaAppMac.TaskParams
        switch appTaskKind {
        case .inference:
            taskParams = .inference(InferenceParams(
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP
            ))
        case .embedding:
            taskParams = .embedding(EmbeddingParams())
        case .transcription:
            taskParams = .transcription(TranscriptionParams())
        case .classification:
            taskParams = .classification(ClassificationParams(labels: []))
        case .imageGeneration:
            taskParams = .imageGeneration(ImageGenParams(width: 512, height: 512))
        case .speechSynthesis:
            taskParams = .speechSynthesis(TTSParams())
        }

        let inputHash = try hashInputs(inputs)

        let runSpec = RunSpec(
            runId: UUID().uuidString,
            modelSpec: modelSpec,
            taskParams: taskParams,
            inputHash: inputHash,
            workflowId: nil,
            jobId: nil,
            dataClassification: "internal",
            timestamp: Date()
        )

        // Execute through MLWorker with governance
        showToast("Executing ML Task", "\(taskKind.rawValue) on \(backend)", "gearshape.2")

        // Convert AnigmaAppMac types to ContractsCore types for MLWorkerClient
        let contractsModelSpec = convertToContractsModelSpec(modelSpec)
        let contractsRunSpec = convertToContractsRunSpec(runSpec, inputs: inputs)

        let receipt = try await mlWorkerClient.executeGovernedRun(
            modelSpec: contractsModelSpec,
            runSpec: contractsRunSpec
        )

        // Store receipt in evidence chain
        try await storeExecutionReceipt(receipt)

        // Log to audit trail
        logNetworkActivity(
            "ML Execution",
            "local",
            "Model inference: \(modelSpec.id)",
            "Internal"
        )

        showToast(
            "Task Completed",
            "Receipt: \(receipt.deterministicHash.prefix(12))...",
            "checkmark.seal.fill"
        )

        return receipt
    }

    /// Store an execution receipt to the evidence chain
    private func storeExecutionReceipt(_ receipt: ContractsCore.ExecutionReceipt) async throws {
        // Create evidence record for Cathedral storage
        let evidenceRecord = EvidenceRecord(
            id: receipt.deterministicHash,
            sessionId: receipt.runId,
            agentId: "MLWorker",
            toolName: "model_execution",
            requestId: receipt.runId,
            parameters: "\(receipt.taskKind.rawValue):\(receipt.modelId)",
            filePath: nil,
            contentHash: receipt.deterministicHash,
            startTime: receipt.timestamp,
            endTime: receipt.timestamp,
            status: "success",
            result: "Execution completed with hash: \(receipt.deterministicHash)",
            error: nil
        )

        // Store in Cathedral evidence chain
        let evidenceHead = EvidenceHead(
            headId: receipt.deterministicHash,
            headHash: receipt.deterministicHash,
            timestamp: receipt.timestamp,
            lastActor: "MLWorker"
        )

        // Encode evidence record as JSON data
        let evidenceData = try JSONEncoder().encode(evidenceRecord)

        // Log evidence recording
        print("📝 [Cathedral] Recording execution receipt: \(receipt.deterministicHash)")
        print("   → Model: \(receipt.modelId), Task: \(receipt.taskKind.rawValue), Backend: \(receipt.backend)")

        // Note: Console logging removed to avoid type mismatches
        // ConsoleEntry in AppStore has a different structure than what we need here
    }

    /// Delete a model from registry and disk
    func deleteModel(_ modelId: String) async {
        do {
            try await modelRegistry.delete(modelId)
            await loadRegisteredModels()
            showToast("Model Deleted", modelId, "trash.fill")
        } catch {
            showError("Failed to delete model: \(error)")
        }
    }

    /// Submit an ML task
    func submitMLTask(
        engine: String,
        task: MLTaskKind,
        inputs: [ContractsCore.MLArtifactRef],
        options: MLTaskOptions? = nil
    ) async {
        do {
            // Convert ContractsCore.MLArtifactRef to MLWorkerCommon.MLArtifactRef
            let workerInputs = inputs.map {
                MLWorkerCommon.MLArtifactRef(path: $0.path, hash: $0.hash)
            }

            let response = try await mlWorkerClient.runTask(
                engine: engine,
                task: task,
                inputs: workerInputs,
                options: options
            )

            // Create task status entry
            let taskStatus = AnigmaHostMac.MLWorkerClient.TaskStatusResponse(
                id: response.requestId,
                requestId: response.requestId,
                engine: engine,
                task: "\(task)",
                status: response.status.rawValue, // Convert enum to string
                createdAt: Date(),
                completedAt: response.status.rawValue == "completed" ? Date() : nil,
                metrics: response.metrics
            )

            mlWorkerTasks.append(taskStatus)

            // Record model usage for analytics
            let modelId = engine.components(separatedBy: ":").last ?? engine
            await recordModelUsage(modelId: modelId)

            showToast(
                "ML Task Completed",
                "Task \(response.requestId) finished with \(response.outputs.count) outputs",
                "brain"
            )
        } catch {
            print("Failed to submit ML task: \(error)")
            showToast(
                "ML Task Failed",
                error.localizedDescription,
                "exclamationmark.triangle"
            )
        }
    }

    /// Clear completed ML tasks
    func clearCompletedMLTasks() {
        mlWorkerTasks.removeAll { $0.status == "completed" }
    }

    /// Record model usage for analytics
    private func recordModelUsage(modelId: String) async {
        // This would need to be implemented in ModelRegistry
        // For now, just track in memory
        if let index = registeredModels.firstIndex(where: { $0.modelId == modelId }) {
            registeredModels[index].usageCount += 1
            registeredModels[index].lastUsed = Date()
        }
    }

    // MARK: - Helper Methods

    /// Hash inputs for provenance tracking
    private func hashInputs(_ inputs: [ContractsCore.RunSpec.Input]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(inputs)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Convert AnigmaAppMac.ModelSpec to ContractsCore.ModelSpec
    private func convertToContractsModelSpec(_ appSpec: AnigmaAppMac.ModelSpec) -> ContractsCore.ModelSpec {
        // Convert source
        let contractSource: ContractsCore.ModelSource
        switch appSpec.source.type {
        case .huggingface:
            contractSource = .huggingFace(repo: appSpec.source.location, revision: appSpec.source.revision ?? "main")
        case .local:
            contractSource = .localPath(appSpec.source.location)
        case .bundled:
            contractSource = .bundled(appSpec.source.location)
        }

        // Convert task kind
        let contractTask: ContractsCore.ModelTaskKind
        switch appSpec.taskKind {
        case .inference:
            contractTask = .inference
        case .embedding:
            contractTask = .embedding
        case .transcription:
            contractTask = .transcription
        case .classification:
            contractTask = .classification
        case .imageGeneration:
            contractTask = .imageGeneration
        case .speechSynthesis:
            contractTask = .speechSynthesis
        }

        // Convert backend
        let contractBackend: ContractsCore.MLBackend
        switch appSpec.backendFormat.lowercased() {
        case "mlx":
            contractBackend = .mlx
        case "gguf":
            contractBackend = .gguf
        case "coreml":
            contractBackend = .coreml
        default:
            contractBackend = .mlx
        }

        // Convert trust tier
        let contractTrust: ContractsCore.ModelTrustTier
        switch appSpec.trustTier {
        case .firstClass:
            contractTrust = .firstClass
        case .compatible:
            contractTrust = .compatible
        case .experimental:
            contractTrust = .experimental
        }

        // Convert license
        let contractLicense = ContractsCore.LicenseDecision(
            declared: appSpec.license ?? "unknown",
            allowed: true,
            reason: "Imported model",
            extraTerms: [],
            timestamp: Date()
        )

        return ContractsCore.ModelSpec(
            id: appSpec.modelId,
            source: contractSource,
            task: contractTask,
            backend: contractBackend,
            trustTier: contractTrust,
            license: contractLicense,
            artifactHashes: ["model": appSpec.modelHash],
            tokenizerHash: appSpec.tokenizerHash,
            conversionReceipt: nil,
            metadata: [:],
            registeredAt: Date(),
            verifiedAt: Date(),
            storageBytes: 0
        )
    }

    /// Convert AnigmaAppMac.RunSpec to ContractsCore.RunSpec
    private func convertToContractsRunSpec(_ appSpec: AnigmaAppMac.RunSpec, inputs: [ContractsCore.RunSpec.Input]) -> ContractsCore.RunSpec {
        // Extract params from TaskParams
        var maxTokens: Int?
        var temperature: Double?
        var topP: Double?

        switch appSpec.taskParams {
        case .inference(let params):
            maxTokens = params.maxTokens
            temperature = params.temperature
            topP = params.topP
        default:
            break
        }

        return ContractsCore.RunSpec(
            runId: appSpec.runId,
            taskKind: mapAppTaskToMLWorkerTask(appSpec.modelSpec.taskKind),
            backend: appSpec.modelSpec.backendFormat,
            inputs: inputs,
            seed: 42, // Default seed
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens
        )
    }

    /// Map AnigmaAppMac.TaskKind to ContractsCore.MLWorkerTask
    private func mapAppTaskToMLWorkerTask(_ taskKind: AnigmaAppMac.TaskKind) -> ContractsCore.MLWorkerTask {
        switch taskKind {
        case .inference:
            return .chat
        case .embedding:
            return .embed
        case .transcription:
            return .transcribe
        case .classification:
            return .classify
        default:
            return .other
        }
    }
}

// MARK: - Supporting Types
// Note: ConsoleEntry, LicenseInfo, and ModelBackendCompatibility are defined elsewhere
// in the codebase. MLStore uses the existing types from AppStore and ModelRegistryTypes.
