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
import AnigmaHostMac
import MLWorkerCommon
import AnigmaSidecar
import AnigmaPrimitives

/// Configuration for executing a governed ML run.
struct ExecuteGovernedMLRunConfiguration: Sendable {
    let modelId: String
    let taskKind: MLTaskKind
    let inputs: [ContractsCore.RunSpec.Input]
    let backend: ContractsCore.MLBackend
    let seed: Int?
    let temperature: Double?
    let topP: Double?
    let maxTokens: Int?
    
    init(
        modelId: String,
        taskKind: MLTaskKind,
        inputs: [ContractsCore.RunSpec.Input],
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

@MainActor
@Observable
final class MLStore {

    // MARK: - Properties

    /// Reference to DaemonStore to access bridge
    let daemonStore: DaemonStore

    /// Computed property to access active bridge
    var bridge: SidecarBridge? { daemonStore.daemonBridge }

    /// Registered models (cached from registry with full metadata)
    var registeredModels: [ModelRegistryEntry] = []
    
    /// ML worker status and task history for monitor surfaces
    var mlWorkerStatus: MLWorkerClient.WorkerStatusResponse?
    var mlWorkerTasks: [MLWorkerClient.TaskStatusResponse] = []
    
    private let mlWorkerClient: MLWorkerClient
    
    // Dependencies (Injected)
    var showToast: (String, String, String) -> Void = { _, _, _ in }
    var showError: (String) -> Void = { _ in }
    var logNetworkActivity: (String, String, String, String) -> Void = { _, _, _, _ in }

    // MARK: - Initialization

    init(daemonStore: DaemonStore, mlWorkerClient: MLWorkerClient = MLWorkerClient()) {
        self.daemonStore = daemonStore
        self.mlWorkerClient = mlWorkerClient
    }

    // MARK: - Model Registry Operations

    /// Load registered models from registry
    func loadRegisteredModels() async {
        guard let bridge = bridge else { return }
        
        do {
            let response = try await bridge.listModels()
            if let error = response.error {
                showError("Failed to load model registry: \(error.message)")
                return
            }
            self.registeredModels = response.models.map(mapModelInfoToRegistryEntry)
        } catch {
            showError("Failed to load model registry: \(error.localizedDescription)")
        }
    }

    /// Load ML worker installation/capability status
    func loadMLWorkerStatus() async {
        self.mlWorkerStatus = await mlWorkerClient.getStatus()
    }

    /// Import a HuggingFace model
    func importHuggingFaceModel(
        repo: String,
        revision: String = "main",
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async {
        guard let bridge = bridge else {
            showError("Daemon not connected")
            return
        }

        do {
            showToast("Importing Model", repo, "arrow.down.circle")
            logNetworkActivity("ML", "Import", repo, revision)

            // Note: Progress handling is not yet supported over the bridge in this simple call
            let response = try await bridge.installModel(modelId: repo, repo: repo, revision: revision)

            if let error = response.error {
                 showError("Failed to import model: \(error.message)")
            } else {
                 await loadRegisteredModels()
                 showToast("Model Imported", repo, "checkmark.circle.fill")
            }
        } catch {
            showError("Failed to import model: \(error.localizedDescription)")
        }
    }

    /// Verify model integrity via daemon
    func verifyModelIntegrity(_ modelId: String) async {
        guard let bridge = bridge else {
            showError("Daemon not connected")
            return
        }

        do {
            // Use daemon's model verification endpoint
            let response = try await bridge.verifyModel(modelId: modelId)
            if let error = response.error {
                showError("Model verification failed: \(error.message)")
            } else if response.isValid {
                showToast("Verification Successful", "Model \(modelId) verified", "checkmark.shield.fill")
            } else {
                showError("Model \(modelId) integrity check failed")
            }
        } catch {
            showError("Failed to verify model: \(error.localizedDescription)")
        }
    }

    /// Execute a governed ML run via local ML worker client
    func executeGovernedMLRun(config: ExecuteGovernedMLRunConfiguration) async throws -> ContractsCore.ExecutionReceipt {
        guard let modelEntry = registeredModels.first(where: { $0.modelId == config.modelId }) else {
            throw NSError(
                domain: "MLStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Model not found in registry: \(config.modelId)"]
            )
        }

        let runId = UUID().uuidString
        let queuedTask = MLWorkerClient.TaskStatusResponse(
            id: runId,
            requestId: runId,
            engine: config.backend.rawValue,
            task: config.taskKind.rawValue,
            status: "queued",
            createdAt: Date()
        )
        mlWorkerTasks.insert(queuedTask, at: 0)

        let modelSpec = ContractsCore.ModelSpec(
            id: modelEntry.modelId,
            source: .localPath(modelEntry.installPath ?? modelEntry.sourceLocation),
            task: mapRunTaskToModelTask(config.taskKind),
            backend: config.backend,
            trustTier: mapTrustTier(modelEntry.trustTier),
            license: ContractsCore.LicenseDecision(
                declared: modelEntry.license.declared ?? "unknown",
                allowed: modelEntry.license.allowed,
                reason: modelEntry.license.reason,
                extraTerms: []
            ),
            artifactHashes: modelEntry.artifactHashes.isEmpty ? ["model": modelEntry.artifactHash] : modelEntry.artifactHashes,
            tokenizerHash: modelEntry.tokenizerHash,
            conversionReceipt: nil,
            metadata: [
                "sourceType": modelEntry.sourceType,
                "status": modelEntry.status.rawValue,
                "backendCompatibility": modelEntry.backendCompatibility.preferredBackend ?? ""
            ],
            registeredAt: modelEntry.registeredAt,
            verifiedAt: modelEntry.lastVerified,
            storageBytes: modelEntry.storageBytes
        )

        let runSpec = ContractsCore.RunSpec(
            runId: runId,
            taskKind: config.taskKind,
            backend: config.backend.rawValue,
            inputs: []
        )

        do {
            let receipt = try await mlWorkerClient.executeGovernedRun(
                modelSpec: modelSpec,
                runSpec: runSpec
            )

            let completedTask = MLWorkerClient.TaskStatusResponse(
                id: runId,
                requestId: runId,
                engine: config.backend.rawValue,
                task: config.taskKind.rawValue,
                status: "completed",
                createdAt: queuedTask.createdAt,
                completedAt: Date(),
                metrics: MLWorkerMetrics(
                    totalTokens: receipt.tokensGenerated,
                    durationMs: receipt.executionTimeMs
                )
            )
            replaceTaskStatus(completedTask)
            return receipt
        } catch {
            let failedTask = MLWorkerClient.TaskStatusResponse(
                id: runId,
                requestId: runId,
                engine: config.backend.rawValue,
                task: config.taskKind.rawValue,
                status: "failed",
                createdAt: queuedTask.createdAt,
                completedAt: Date(),
                metrics: nil
            )
            replaceTaskStatus(failedTask)
            throw error
        }
    }

    /// Delete a model from registry and disk via daemon
    func deleteModel(_ modelId: String) async {
        guard let bridge = bridge else {
            showError("Daemon not connected")
            return
        }

        do {
            let response = try await bridge.deleteModel(modelId: modelId)
            if let error = response.error {
                showError("Failed to delete model: \(error.message)")
            } else {
                await loadRegisteredModels()
                showToast("Model Deleted", "\(modelId) removed", "trash.fill")
            }
        } catch {
            showError("Failed to delete model: \(error.localizedDescription)")
        }
    }

    /// Submit an ML task
    func submitMLTask(
        engine: String,
        task: MLTaskKind,
        inputs: [ContractsCore.MLArtifactRef],
        options: MLTaskOptions? = nil
    ) async {
        let requestId = UUID().uuidString
        let queuedTask = MLWorkerClient.TaskStatusResponse(
            id: requestId,
            requestId: requestId,
            engine: engine,
            task: task.rawValue,
            status: "queued",
            createdAt: Date()
        )
        mlWorkerTasks.insert(queuedTask, at: 0)

        do {
            let response = try await mlWorkerClient.runTask(
                engine: engine,
                task: task,
                inputs: inputs,
                options: options
            )

            let completedTask = MLWorkerClient.TaskStatusResponse(
                id: requestId,
                requestId: requestId,
                engine: engine,
                task: task.rawValue,
                status: response.status.rawValue,
                createdAt: queuedTask.createdAt,
                completedAt: Date(),
                metrics: response.metrics
            )
            replaceTaskStatus(completedTask)
        } catch {
            let failedTask = MLWorkerClient.TaskStatusResponse(
                id: requestId,
                requestId: requestId,
                engine: engine,
                task: task.rawValue,
                status: "failed",
                createdAt: queuedTask.createdAt,
                completedAt: Date(),
                metrics: nil
            )
            replaceTaskStatus(failedTask)
            showError("Failed to submit ML task: \(error.localizedDescription)")
        }
    }

    /// Clear completed ML tasks
    func clearCompletedMLTasks() {
        mlWorkerTasks.removeAll { $0.status.lowercased() == "completed" }
    }
    
    // MARK: - Mapping
    
    private func mapModelInfoToRegistryEntry(_ modelInfo: ModelInfo) -> ModelRegistryEntry {
        let backend = modelInfo.type.lowercased()
        
        return ModelRegistryEntry(
            modelId: modelInfo.id,
            sourceType: "daemon",
            sourceLocation: modelInfo.name,
            status: .ready,
            isRunnable: true,
            taskKind: "inference",
            backendFormat: backend,
            installPath: nil,
            storageBytes: Int64(modelInfo.sizeGB * 1_000_000_000),
            artifactHash: modelInfo.id,
            tokenizerHash: nil,
            artifactHashes: ["model": modelInfo.id],
            registeredAt: modelInfo.installedAt ?? Date(),
            lastVerified: Date(),
            usageCount: 0,
            license: LicenseInfo(
                declared: "unknown",
                allowed: true,
                reason: nil
            ),
            backendCompatibility: ModelBackendCompatibility(
                supportedBackends: [backend],
                preferredBackend: backend
            ),
            trustTier: ContractsCore.ModelTrustTier.compatible.rawValue
        )
    }
    
    private func mapRunTaskToModelTask(_ task: MLTaskKind) -> ContractsCore.ModelTaskKind {
        switch task {
        case .chat: return .inference
        case .embed: return .embedding
        case .transcribe: return .transcription
        case .classify: return .classification
        case .summarize: return .inference
        case .rerank: return .inference
        case .other: return .inference
        }
    }
    
    private func mapTrustTier(_ rawTier: String) -> ContractsCore.ModelTrustTier {
        switch rawTier.lowercased() {
        case "firstclass", "first_class", "first-class": return .firstClass
        case "compatible": return .compatible
        case "experimental": return .experimental
        default: return .experimental
        }
    }
    
    private func replaceTaskStatus(_ updated: MLWorkerClient.TaskStatusResponse) {
        if let index = mlWorkerTasks.firstIndex(where: { $0.id == updated.id }) {
            mlWorkerTasks[index] = updated
        } else {
            mlWorkerTasks.insert(updated, at: 0)
        }
    }
}
