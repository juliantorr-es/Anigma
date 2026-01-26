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
import AnigmaSidecar
import AnigmaPrimitives

/// Configuration for executing a governed ML run.
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

@MainActor
@Observable
final class MLStore {

    // MARK: - Properties

    /// Reference to DaemonStore to access bridge
    let daemonStore: DaemonStore

    /// Computed property to access active bridge
    var bridge: SidecarBridge? { daemonStore.daemonBridge }

    /// Registered models (cached from registry with full metadata)
    var registeredModels: [ModelInfo] = []
    
    // Dependencies (Injected)
    var showToast: (String, String, String) -> Void = { _, _, _ in }
    var showError: (String) -> Void = { _ in }
    var logNetworkActivity: (String, String, String, String) -> Void = { _, _, _, _ in }

    // MARK: - Initialization

    init(daemonStore: DaemonStore) {
        self.daemonStore = daemonStore
    }

    // MARK: - Model Registry Operations

    /// Load registered models from registry
    func loadRegisteredModels() async {
        guard let bridge = bridge else { return }
        
        do {
            let response = try await bridge.listModels()
            self.registeredModels = response.models
        } catch {
            showError("Failed to load model registry: \(error.localizedDescription)")
        }
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

    /// Verify model integrity
    func verifyModelIntegrity(_ modelId: String) async {
        // Phase 2: Stub implementation - assume model is valid
        // TODO: Implement actual verification via daemon API
        print("Model integrity verification requested for \(modelId) - assuming valid (stub)")
    }

    /// Execute a governed ML run.
    func executeGovernedMLRun(config: ExecuteGovernedMLRunConfiguration) async throws -> ContractsCore.ExecutionReceipt {
        guard let _ = bridge else {
            throw NSError(domain: "MLStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Daemon not connected"])
        }
        
        // Phase 2: Stub implementation
        // TODO: Implement proper ML inference via daemon API
        // For now, return a stub receipt
        
        print("ML inference requested for model \(config.modelId), task \(config.taskKind)")
        
        // Create a stub execution receipt
        return ContractsCore.ExecutionReceipt(
            receiptHash: UUID().uuidString,
            artifactHash: UUID().uuidString,
            executedAt: Date(),
            executorProfile: ContractsCore.ExecutorProfile(
                id: "daemon-ml-stub",
                displayName: "Daemon ML Stub",
                version: "1.0.0"
            ),
            evidenceHash: UUID().uuidString,
            output: ContractsCore.ExecutionOutput(
                data: Data("Stub ML inference result".utf8),
                mediaType: "text/plain"
            )
        )
    }

    /// Delete a model from registry and disk
    func deleteModel(_ modelId: String) async {
        // Phase 2: Stub implementation
        // TODO: Implement model deletion via daemon API
        print("Model deletion requested for \(modelId) - stub implementation")
    }

    /// Submit an ML task
    func submitMLTask(
        engine: String,
        task: String, // Simplified type
        inputs: [String], // Simplified type
        options: [String: String]? = nil
    ) async {
        // Phase 2: Stub implementation
        // TODO: Implement ML task submission via daemon API
        print("ML task submitted: engine=\(engine), task=\(task), inputs=\(inputs.count)")
    }

    /// Clear completed ML tasks
    func clearCompletedMLTasks() {
        // Local state clear
    }
}
