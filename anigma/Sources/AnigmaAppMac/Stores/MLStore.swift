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
        // Not yet implemented in daemon API
        showError("Verify integrity not yet supported via daemon")
    }

    /// Execute a governed ML run.
    func executeGovernedMLRun(config: ExecuteGovernedMLRunConfiguration) async throws -> ContractsCore.ExecutionReceipt {
        guard let bridge = bridge else {
            throw NSError(domain: "MLStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Daemon not connected"])
        }
        
        // This method returned a ContractsCore.ExecutionReceipt which is quite specific.
        // We'll need to adapt this to use the daemon's job submission or specific endpoints.
        
        // For Phase 1, we only have embed/search endpoints explicitly.
        // General inference needs the generic job submission or new endpoints.
        
        // Stub for now to allow compilation
        throw NSError(domain: "MLStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Execution not yet implemented via daemon bridge"])
    }

    /// Delete a model from registry and disk
    func deleteModel(_ modelId: String) async {
        // Not yet implemented in daemon API
        showError("Delete model not yet supported via daemon")
    }

    /// Submit an ML task
    func submitMLTask(
        engine: String,
        task: String, // Simplified type
        inputs: [String], // Simplified type
        options: [String: String]? = nil
    ) async {
         // Placeholder
         showError("submitMLTask not yet implemented via daemon")
    }

    /// Clear completed ML tasks
    func clearCompletedMLTasks() {
        // Local state clear
    }
}
