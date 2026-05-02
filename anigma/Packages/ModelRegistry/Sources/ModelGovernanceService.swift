//
//  ModelGovernanceService.swift
//  ModelRegistry
//
//  Governance layer for model operations - license gates, policy enforcement, audit trails.
//

import Foundation
import IntelligenceContracts
import FoundationContracts
import AnigmaPrimitives


/// Governance service for model lifecycle operations
public actor ModelGovernanceService {
    private let registry: ModelRegistryProtocol
    private let policyEngine: PolicyEngineProtocol?
    private let auditLog: AuditLogProtocol

    public init(
        registry: ModelRegistryProtocol,
        policyEngine: PolicyEngineProtocol? = nil,
        auditLog: AuditLogProtocol
    ) {
        self.registry = registry
        self.policyEngine = policyEngine
        self.auditLog = auditLog
    }

    // MARK: - Governed Operations

    /// Import model with license and policy gates
    public func importModel(
        from adapter: HuggingFaceAdapter,
        repo: String,
        revision: String? = nil,
        requestedBy: String,
        dataClassification: DataClassification = .internal_
    ) async throws -> GovernedImportResult {
        // Log governance decision point
        await auditLog.record(
            event: "model.import.start",
            actor: requestedBy,
            resource: repo,
            metadata: ["revision": revision ?? "main"]
        )

        // Fetch and verify (license gate runs inside adapter)
        let importResult = try await adapter.fetchAndVerify(repo: repo, revision: revision)

        // Additional policy gate based on data classification
        if let policy = policyEngine {
            let decision = try await policy.evaluateModelImport(
                spec: importResult.spec,
                dataClassification: dataClassification,
                requestedBy: requestedBy
            )

            guard decision.allowed else {
                await auditLog.record(
                    event: "model.import.blocked",
                    actor: requestedBy,
                    resource: repo,
                    metadata: ["reason": decision.reason ?? "policy denial"]
                )

                throw GovernanceError.policyDenial(decision.reason ?? "Policy blocked import")
            }

            await auditLog.record(
                event: "model.import.policy_approved",
                actor: requestedBy,
                resource: repo,
                metadata: decision.metadata
            )
        }

        // Register in durable registry
        let entry = try await registry.register(importResult.spec, installPath: importResult.installPath)

        await auditLog.record(
            event: "model.import.complete",
            actor: requestedBy,
            resource: repo,
            metadata: [
                "model_id": entry.id,
                "trust_tier": entry.spec.trustTier.rawValue,
                "license": entry.spec.license.declared,
                "warnings_count": String(importResult.warnings.count)
            ]
        )

        return GovernedImportResult(
            entry: entry,
            warnings: importResult.warnings,
            conversionNeeded: importResult.conversionNeeded
        )
    }

    /// Execute model run with policy enforcement and receipt generation
    public func executeRun(
        modelId: String,
        input: Data,
        params: ModelTaskOptions,
        requestedBy: String,
        dataClassification: DataClassification
    ) async throws -> GovernedRunResult {
        guard let entry = try await registry.find(id: modelId) else {
            throw GovernanceError.modelNotFound(modelId)
        }

        // Policy gate for execution
        if let policy = policyEngine {
            let decision = try await policy.evaluateModelExecution(
                spec: entry.spec,
                dataClassification: dataClassification,
                requestedBy: requestedBy
            )

            guard decision.allowed else {
                await auditLog.record(
                    event: "model.execute.blocked",
                    actor: requestedBy,
                    resource: modelId,
                    metadata: ["reason": decision.reason ?? "policy denial"]
                )

                throw GovernanceError.policyDenial(decision.reason ?? "Policy blocked execution")
            }
        }

        // Verify model integrity before execution
        let integrityOK = try await registry.verifyIntegrity(modelId)
        guard integrityOK else {
            await auditLog.record(
                event: "model.execute.integrity_failure",
                actor: requestedBy,
                resource: modelId,
                metadata: [:]
            )
            throw GovernanceError.integrityCheckFailed(modelId)
        }

        // Hash input for provenance
        let inputHash = input.blake3Hex()

        // Build run spec
        let runSpec = ModelRunSpec(
            modelHash: entry.spec.canonicalHash,
            inputHash: inputHash,
            params: params,
            seed: params.seed,
            backendVersion: "1.0.0", // Should come from actual backend
            timestamp: Date()
        )

        await auditLog.record(
            event: "model.execute.start",
            actor: requestedBy,
            resource: modelId,
            metadata: [
                "run_id": runSpec.requestId,
                "model_hash": entry.spec.canonicalHash,
                "input_hash": inputHash
            ]
        )

        // Record usage
        try await registry.recordUsage(modelId)

        // Actual execution would happen here via MLWorker
        // For now, return structure for wiring

        return GovernedRunResult(
            runSpec: runSpec,
            modelEntry: entry,
            policyDecision: "allowed"
        )
    }

    /// Store run receipt for court-safe evidence
    public func recordRunReceipt(
        _ receipt: ModelRunReceipt,
        modelId: String,
        requestedBy: String
    ) async throws {
        guard (try await registry.find(id: modelId)) != nil else {
            throw GovernanceError.modelNotFound(modelId)
        }

        // Store receipt in registry
        if let store = registry as? ModelRegistryStore {
            try await store.storeRunReceipt(receipt, modelId: modelId)
        }

        await auditLog.record(
            event: "model.execute.complete",
            actor: requestedBy,
            resource: modelId,
            metadata: [
                "run_id": receipt.runSpec.requestId,
                "output_hash": receipt.outputHash,
                "duration_ms": String(receipt.metrics.durationMs),
                "policy_decision": receipt.policyDecision
            ]
        )
    }

    /// Delete model with governance trail
    public func deleteModel(
        modelId: String,
        requestedBy: String,
        reason: String
    ) async throws {
        guard let entry = try await registry.find(id: modelId) else {
            throw GovernanceError.modelNotFound(modelId)
        }

        await auditLog.record(
            event: "model.delete",
            actor: requestedBy,
            resource: modelId,
            metadata: [
                "reason": reason,
                "trust_tier": entry.spec.trustTier.rawValue
            ]
        )

        // Delete from registry (cascades to hashes and run receipts via FK)
        try await registry.delete(modelId)

        // Delete artifacts from disk
        try? FileManager.default.removeItem(atPath: entry.installPath)
    }
}

// MARK: - Supporting Types

public struct GovernedImportResult: Sendable {
    public let entry: ModelRegistryEntry
    public let warnings: [String]
    public let conversionNeeded: Bool
}

public struct GovernedRunResult: Sendable {
    public let runSpec: ModelRunSpec
    public let modelEntry: ModelRegistryEntry
    public let policyDecision: String
}

public enum DataClassification: String, Sendable {
    case public_ = "public"
    case internal_ = "internal"
    case confidential = "confidential"
    case sensitive = "sensitive"
}

public enum GovernanceError: Error, Sendable {
    case modelNotFound(String)
    case policyDenial(String)
    case integrityCheckFailed(String)
    case auditFailure(String)
}

// MARK: - Protocol Stubs

public protocol PolicyEngineProtocol: Sendable {
    func evaluateModelImport(
        spec: ModelSpec,
        dataClassification: DataClassification,
        requestedBy: String
    ) async throws -> PolicyDecision

    func evaluateModelExecution(
        spec: ModelSpec,
        dataClassification: DataClassification,
        requestedBy: String
    ) async throws -> PolicyDecision
}

public struct PolicyDecision: Sendable {
    public let allowed: Bool
    public let reason: String?
    public let metadata: [String: String]

    public init(allowed: Bool, reason: String? = nil, metadata: [String: String] = [:]) {
        self.allowed = allowed
        self.reason = reason
        self.metadata = metadata
    }
}

public protocol AuditLogProtocol: Sendable {
    func record(event: String, actor: String, resource: String, metadata: [String: String]) async
}

// MARK: - Data Extensions

private extension Data {
    func blake3Hex() -> String {
        return BLAKE3Digest.hex(of: self)
    }
}
