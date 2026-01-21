//
//  ModelRegistryAppStore.swift
//  AnigmaAppMac
//
//  AppStore integration for Model Registry - follows existing MLWorker pattern.
//

import Foundation
import SwiftUI
import Observation
import ContractsCore

/// Observable app store for model registry state
@MainActor
@Observable
public final class ModelRegistryAppStore {
    public var installedModels: [ModelRegistryEntry] = []
    public var selectedModel: ModelRegistryEntry?
    public var isImporting: Bool = false
    public var importProgress: Double = 0.0
    public var importStatus: String = ""
    public var lastError: String?

    private let hfAdapter: HuggingFaceAdapter
    private let modelRegistry: ModelRegistryStore

    public init(
        storagePath: String,
        artifactStore: URL,
        auditLog: AuditLogProtocol
    ) async throws {
        self.modelRegistry = try await ModelRegistryStore(storagePath: storagePath)
        self.hfAdapter = try HuggingFaceAdapter(cacheDir: artifactStore)
        await refreshModels()
    }

    // MARK: - Public Actions

    public func refreshModels() async {
        do {
            installedModels = try await modelRegistry.getAllModels()
        } catch {
            lastError = "Failed to load models: \(error.localizedDescription)"
        }
    }

    public func importFromHuggingFace(repo: String, revision: String? = nil) async {
        isImporting = true
        importStatus = "Fetching metadata for \(repo)..."
        importProgress = 0.1
        lastError = nil

        do {
            // Preview descriptor first
            let descriptor = try await hfAdapter.describe(repo: repo, revision: revision ?? "main")

            guard descriptor.isRunnable else {
                importStatus = "Model not directly runnable"
                lastError = "Unsupported format or missing task classification"
                isImporting = false
                return
            }

            importStatus = "Downloading model files..."
            importProgress = 0.3

            // Import using HuggingFace adapter directly
            let result = try await hfAdapter.importModel(
                repo: repo,
                revision: revision ?? "main"
            ) { progress in
                Task { @MainActor in
                    self.importProgress = 0.3 + (progress * 0.6)
                }
            }

            // Register using enhanced ModelRegistryEntry (via legacy conversion)
            let entry = ModelRegistryEntry.fromLegacy(
                modelId: result.modelId,
                sourceType: "huggingface",
                sourceLocation: result.sourceLocation,
                sourceRevision: result.sourceRevision,
                licenseDeclared: result.license,
                licenseDecision: result.licenseDecision,
                artifactHash: result.artifactHash,
                tokenizerHash: result.tokenizerHash,
                conversionReceiptId: result.conversionReceiptId,
                backendCompatibility: result.backendCompatibility,
                importedAt: Date(),
                trustTier: result.trustTier
            )

            try await modelRegistry.insertModel(entry)

            importStatus = "Model imported successfully"
            importProgress = 1.0

            if !result.warnings.isEmpty {
                lastError = "Warnings: " + result.warnings.joined(separator: ", ")
            }

            await refreshModels()

        } catch {
            importStatus = "Import failed"
            lastError = error.localizedDescription
        }

        isImporting = false
    }

    public func deleteModel(id: String) async {
        do {
            try await modelRegistry.deleteModel(id: id)
            await refreshModels()
        } catch {
            lastError = "Failed to delete model: \(error.localizedDescription)"
        }
    }

    public func verifyModel(id: String) async {
        do {
            // Verification logic - for now just check if it exists
            _ = try await modelRegistry.getModel(id: id)
            await refreshModels()
        } catch {
            lastError = "Failed to verify model: \(error.localizedDescription)"
        }
    }

    private func getRegistry() async -> ModelRegistryStore {
        modelRegistry
    }
}

/// Protocol for audit logging
public protocol AuditLogProtocol: Sendable {
    func log(event: String, metadata: [String: String]) async
}
