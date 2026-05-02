//
//  AuthorityImplementations.swift
//  AnigmaCore
//
//  Initial implementations of runtime authorities (Phase 1).
//  These are wrappers around existing infrastructure to enable gradual migration.
//
//  See ADR-0006: Three-Tier Runtime Architecture
//

import Foundation
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import GovernanceCore
import InferenceCore
import DatabaseCore
import AnigmaPrimitives
import os.log

// MARK: - Database Authority Implementation

private let log = os.Logger(subsystem: "com.anigma.core", category: "runtime")

/// Phase 1 implementation of DatabaseAuthority
/// Wraps DatabaseActor and adds governance enforcement
public actor DatabaseAuthorityImpl: DatabaseAuthority {
    private let databaseActor: DatabaseActor
    private let governance: any GoverningController
    private var evidenceAuthority: (any EvidenceAuthority)?

    /// Registered schemas
    private var schemas: [String: ModuleSchema] = [:]

    public init(
        databaseActor: DatabaseActor,
        governance: any GoverningController,
        evidenceAuthority: (any EvidenceAuthority)?
    ) {
        self.databaseActor = databaseActor
        self.governance = governance
        self.evidenceAuthority = evidenceAuthority
    }

    /// Set evidence authority (called after initialization to resolve circular dependency)
    public func setEvidenceAuthority(_ authority: any EvidenceAuthority) {
        self.evidenceAuthority = authority
    }

    /// Close database connection
    public func close() async {
        await databaseActor.close()
    }

    /// Legacy escape hatch for modules still bound to DatabaseActor.
    public func rawDatabaseActor() -> DatabaseActor {
        databaseActor
    }

    /// Execute SQL directly (internal use only - for schema setup)
    public func executeDirectly(_ sql: String) async throws {
        _ = try await databaseActor.executeAsync(sql)
    }

    /// Execute SQL internally with parameters (for evidence recording)
    public func executeInternal(_ sql: String, parameters: [DatabaseParameter]) async throws {
        _ = try await databaseActor.executeAsync(sql, parameters: parameters)
    }

    // MARK: - DatabaseAuthority Protocol

    public func registerSchema(_ schema: ModuleSchema) async throws {
        try await SchemaRegistry.apply(
            name: schema.name,
            module: schema.module,
            targetVersion: schema.version,
            migrations: schema.migrations,
            using: databaseActor
        )

        schemas[schema.name] = schema
    }

    /// Perform schema migration
    public func migrateSchema(_ schema: ModuleSchema) async throws {
        try await registerSchema(schema)
    }

    public func query(_ sql: String, parameters: [String: String]) async throws -> [DatabaseRow] {
        let dbParams = parameters
            .sorted { $0.key < $1.key }
            .map { DatabaseParameter.text($0.value) }
        return try await databaseActor.query(sql, parameters: dbParams)
    }

    public func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow] {
        return try await databaseActor.query(sql, parameters: parameters)
    }

    public func mutate(
        _ mutation: DatabaseMutation,
        context: ExecutionContext
    ) async throws -> MutationReceipt {
        // Create governance proposal
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "database",
            operation: "mutation",
            entityId: mutation.entityId,
            componentType: mutation.componentType,
            context: ["projectId": context.projectId ?? ""]
        )

        // Evaluate proposal
        let decision = await governance.canWrite(proposal)
        
        if !decision.allowed {
            let modeSource = await governance.modeSource(for: context.projectId).rawValue
            let violation = decision.toGovernanceViolation(
                proposal: proposal,
                evaluatedModeSource: modeSource
            )
            throw RuntimeInitializationError.writeBlocked(violation: violation)
        }

        // Execute mutation
        let rowsAffected = try await databaseActor.executeAsync(mutation.sql, parameters: mutation.parameters)

        // Record evidence (if authority is set)
        var evidence: CoreReceipt
        if let evidenceAuth = evidenceAuthority {
            let payload = EvidencePayload.databaseMutation(
                sql: mutation.sql,
                rowsAffected: rowsAffected
            )
            evidence = try await evidenceAuth.record(
                operation: CoreOperationType.databaseMutation,
                principal: context.principal,
                payload: payload,
                governanceDecision: decision.asGovernanceDecision(),
                context: context
            )
        } else {
            // Placeholder CoreReceipt if evidence authority is not available
            evidence = CoreReceipt(
                operationType: "database_mutation",
                principal: context.principal,
                outcome: OperationOutcome.success,
                summary: "Mutation executed (evidence bypassed)",
                contentHash: "no-evidence"
            )
        }

        return MutationReceipt(rowsAffected: rowsAffected, evidence: evidence)
    }

    public func transaction(
        context: ExecutionContext,
        _ block: @escaping @Sendable () async throws -> Void
    ) async throws {
        try await databaseActor.transaction(block)
    }

    public func isVectorAvailable() async -> Bool {
        await databaseActor.isVectorAvailable()
    }
}

// MARK: - Evidence Authority Implementation

/// Phase 1 implementation of EvidenceAuthority
public actor EvidenceAuthorityImpl: EvidenceAuthority {
    private let databaseAuthority: any DatabaseAuthority
    private let governance: any GoverningController
    private var sinks: [any EvidenceSink] = []

    public init(
        databaseAuthority: any DatabaseAuthority,
        governance: any GoverningController
    ) {
        self.databaseAuthority = databaseAuthority
        self.governance = governance
    }

    public func addSink(_ sink: any EvidenceSink) {
        sinks.append(sink)
    }

    public func record(
        operation: CoreOperationType,
        principal: Principal,
        payload: EvidencePayload,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws -> CoreReceipt {
        let startTime = Date()

        // Compute hash of the operation
        let contentHash = await computeHash(operation, principal, payload)

        // Create the CoreReceipt
        let receipt = CoreReceipt(
            operationType: operation.rawValue,
            principal: principal,
            timestamp: Date(),
            outcome: OperationOutcome.success,
            summary: "Executed \(operation.rawValue)",
            metadata: context.metadata,
            contentHash: contentHash,
            durationMs: Int64(Date().timeIntervalSince(startTime) * 1000)
        )

        // Persist evidence to database
        try await persistEvidence(receipt, payload, governanceDecision)

        // Emit to sinks
        for sink in sinks {
            try? await sink.record(
                receipt: receipt,
                payload: payload,
                operation: operation,
                governanceDecision: governanceDecision,
                context: context
            )
        }

        return receipt
    }

    public func query(
        filter: EvidenceFilter,
        principal: Principal
    ) async throws -> [EvidenceBundle] {
        // Phase 1: Not fully implemented
        return []
    }

    public func verify(receiptId: ReceiptID) async throws -> VerificationResult {
        // Phase 1: Not fully implemented
        return VerificationResult(isValid: true)
    }

    // MARK: - Helpers

    private func computeHash(_ operation: CoreOperationType, _ principal: Principal, _ payload: EvidencePayload) async -> String {
        // Use high-performance parallel cryptographic hashing
        var combinedData = Data()
        combinedData.append(operation.rawValue.data(using: .utf8) ?? Data())
        combinedData.append(principal.id.data(using: .utf8) ?? Data())
        combinedData.append(payload.serialize())
        
        return await BLAKE3Digest.digestHexAsync([UInt8](combinedData))
    }

    private func persistEvidence(
        _ receipt: CoreReceipt,
        _ payload: EvidencePayload,
        _ governanceDecision: GovernanceDecision?
    ) async throws {
        let sql = """
            INSERT INTO evidence_bundles (
                id, operation_type, principal_id, principal_name, timestamp,
                outcome, summary, input_refs, output_refs, content_hash,
                duration_ms, metadata, governance_decision, payload, chain_hash, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        _ = try await (databaseAuthority as! DatabaseAuthorityImpl).executeInternal(sql, parameters: [
            DatabaseParameter.text(receipt.id.raw),
            DatabaseParameter.text(receipt.operationType),
            DatabaseParameter.text(receipt.principal.id),
            DatabaseParameter.text(receipt.principal.displayName),
            DatabaseParameter.int(Int(receipt.timestamp.timeIntervalSince1970)),
            DatabaseParameter.text(receipt.outcome.rawValue),
            receipt.summary.map { DatabaseParameter.text($0) } ?? DatabaseParameter.null,
            DatabaseParameter.text("[]"), // input_refs
            DatabaseParameter.text("[]"), // output_refs
            DatabaseParameter.text(receipt.contentHash),
            DatabaseParameter.int(Int(receipt.durationMs)),
            DatabaseParameter.text("{}"), // metadata
            DatabaseParameter.text(""),   // governance_decision
            DatabaseParameter.text(""),   // payload
            DatabaseParameter.text(""),   // chain_hash
            DatabaseParameter.int(Int(Date().timeIntervalSince1970))
        ])
    }
}

// MARK: - Artifact Authority Implementation

/// Phase 1 implementation of ArtifactAuthority
public actor ArtifactAuthorityImpl: ArtifactAuthority {
    private let databaseAuthority: any DatabaseAuthority
    private let evidenceAuthority: any EvidenceAuthority
    private let governance: any GoverningController

    /// In-memory storage for Phase 1
    private var artifacts: [ArtifactID: Artifact] = [:]

    public init(
        databaseAuthority: any DatabaseAuthority,
        evidenceAuthority: any EvidenceAuthority,
        governance: any GoverningController
    ) {
        self.databaseAuthority = databaseAuthority
        self.evidenceAuthority = evidenceAuthority
        self.governance = governance
    }

    public func store(
        _ artifact: Artifact,
        context: ExecutionContext
    ) async throws -> (id: ArtifactID, receipt: CoreReceipt) {
        // Create governance proposal
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "artifact_authority",
            operation: "store",
            entityId: EntityId(uuidString: artifact.id.hash) ?? EntityId(),
            componentType: "artifact",
            context: ["projectId": context.projectId ?? "", "size": String(artifact.size)]
        )

        // Evaluate proposal
        let decision = await governance.canWrite(proposal)
        if !decision.allowed {
            let modeSource = await governance.modeSource(for: context.projectId).rawValue
            let violation = decision.toGovernanceViolation(proposal: proposal, evaluatedModeSource: modeSource)
            throw RuntimeInitializationError.writeBlocked(violation: violation)
        }
        
        // Check access control
        let accessPrincipal = AccessPrincipal(
            id: context.principal.id,
            module: "artifact_authority",
            roles: context.principal.roles
        )

        let request = AccessRequest(
            principal: accessPrincipal,
            componentType: "artifact",
            sensitivity: DataSensitivity.internal,
            accessType: AccessType.write,
            entityId: EntityId(uuidString: artifact.id.hash)
        )

        try await governance.accessController.checkAccess(request)

        // Store artifact in memory (Phase 1)
        artifacts[artifact.id] = artifact

        // Record evidence
        let receipt = try await evidenceAuthority.record(
            operation: CoreOperationType.artifactStorage,
            principal: context.principal,
            payload: EvidencePayload.artifactStorage(artifactId: artifact.id.hash, size: artifact.size),
            governanceDecision: decision.asGovernanceDecision(),
            context: context
        )

        return (artifact.id, receipt)
    }

    public func retrieve(_ id: ArtifactID, principal: Principal) async throws -> Artifact {
        guard let artifact = artifacts[id] else {
            throw RuntimeInitializationError.artifactNotFound(id)
        }

        // Check access control
        let accessPrincipal = AccessPrincipal(
            id: principal.id,
            module: "artifact_authority",
            roles: principal.roles
        )

        let request = AccessRequest(
            principal: accessPrincipal,
            componentType: "artifact",
            sensitivity: DataSensitivity.internal, // Default sensitivity for artifacts
            accessType: AccessType.read,
            entityId: EntityId(uuidString: id.hash)
        )

        try await governance.accessController.checkAccess(request)

        return artifact
    }

    public func list(
        filter: ArtifactFilter,
        principal: Principal
    ) async throws -> [ArtifactMetadata] {
        // Check access control
        let accessPrincipal = AccessPrincipal(
            id: principal.id,
            module: "artifact_authority",
            roles: principal.roles
        )

        let request = AccessRequest(
            principal: accessPrincipal,
            componentType: "artifact",
            sensitivity: DataSensitivity.internal,
            accessType: AccessType.query
        )

        try await governance.accessController.checkAccess(request)

        // Phase 1: Simple in-memory filtering
        return artifacts.values.map { artifact in
            ArtifactMetadata(
                id: artifact.id,
                mimeType: artifact.mimeType,
                size: artifact.size,
                createdAt: artifact.createdAt,
                tags: artifact.tags,
                metadata: artifact.metadata
            )
        }
    }

    public func delete(
        _ id: ArtifactID,
        context: ExecutionContext
    ) async throws -> CoreReceipt {
        // Create governance proposal
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "artifact_authority",
            operation: "delete",
            entityId: EntityId(uuidString: id.hash) ?? EntityId(),
            componentType: "artifact",
            context: ["projectId": context.projectId ?? ""]
        )

        // Evaluate proposal
        let decision = await governance.canWrite(proposal)
        if !decision.allowed {
            let modeSource = await governance.modeSource(for: context.projectId).rawValue
            let violation = decision.toGovernanceViolation(proposal: proposal, evaluatedModeSource: modeSource)
            throw RuntimeInitializationError.writeBlocked(violation: violation)
        }

        // Check access control
        let accessPrincipal = AccessPrincipal(
            id: context.principal.id,
            module: "artifact_authority",
            roles: context.principal.roles
        )

        let request = AccessRequest(
            principal: accessPrincipal,
            componentType: "artifact",
            sensitivity: DataSensitivity.internal,
            accessType: AccessType.delete,
            entityId: EntityId(uuidString: id.hash)
        )

        try await governance.accessController.checkAccess(request)

        artifacts.removeValue(forKey: id)

        // Record evidence
        return try await evidenceAuthority.record(
            operation: CoreOperationType.artifactStorage,
            principal: context.principal,
            payload: EvidencePayload.custom(type: "artifact_deletion", data: ["artifactId": id.hash]),
            governanceDecision: decision.asGovernanceDecision(),
            context: context
        )
    }
}

// MARK: - Inference Authority Implementation

/// Phase 1 implementation of InferenceAuthority
public actor InferenceAuthorityImpl: InferenceAuthority {
    private let uiPlane: any InferencePlane
    private let workerPlane: any InferencePlane
    private let governance: any GoverningController

    public init(
        uiPlane: any InferencePlane,
        workerPlane: any InferencePlane,
        governance: any GoverningController
    ) {
        self.uiPlane = uiPlane
        self.workerPlane = workerPlane
        self.governance = governance
    }

    public func chatCompletion(
        _ request: InferenceRequest,
        priority: InferencePriority,
        speculativeConfig: SpeculativeConfiguration?,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        let plane = priority == .ui ? uiPlane : workerPlane
        return try await plane.perform(request)
    }

    public func backgroundTask(
        _ task: InferenceRequest,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        return try await workerPlane.perform(task)
    }

    public func rerank(
        _ request: RerankRequest,
        priority: InferencePriority,
        context: ExecutionContext
    ) async throws -> RerankResponse {
        // Placeholder for rerank
        // STUB_TRACK: authority-reranking – Reranking not implemented
        log.warning("⚠️  STUB INVOKED: InferenceAuthority.rerank()")
        log.warning("   Reranking not implemented - returning empty results")
        return RerankResponse(results: [])
    }

    public func getStatus() async -> [InferencePlaneStatus] {
        return []
    }
}

// MARK: - Source Authority Implementation

/// Phase 1 implementation of SourceAuthority
public actor SourceAuthorityImpl: SourceAuthority {
    private let databaseAuthority: any DatabaseAuthority
    private let evidenceAuthority: any EvidenceAuthority
    private let governance: any GoverningController

    public init(
        databaseAuthority: any DatabaseAuthority,
        evidenceAuthority: any EvidenceAuthority,
        governance: any GoverningController
    ) {
        self.databaseAuthority = databaseAuthority
        self.evidenceAuthority = evidenceAuthority
        self.governance = governance
    }

    public func initialize() async throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS sources (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                path TEXT NOT NULL,
                depth TEXT NOT NULL,
                compute_policy_json TEXT NOT NULL,
                storage_policy_json TEXT NOT NULL,
                is_connected INTEGER NOT NULL,
                last_indexed_at INTEGER,
                status TEXT NOT NULL,
                stats_json TEXT,
                created_at INTEGER NOT NULL
            )
        """
        try await (databaseAuthority as! DatabaseAuthorityImpl).executeDirectly(sql)
    }

    public func listSources(principal: Principal) async throws -> [AnigmaSource] {
        // Check access control
        let accessPrincipal = AccessPrincipal(id: principal.id, module: "source_authority", roles: principal.roles)
        let request = AccessRequest(principal: accessPrincipal, componentType: "source", sensitivity: .internal, accessType: .query)
        try await governance.accessController.checkAccess(request)

        let rows = try await databaseAuthority.query("SELECT * FROM sources ORDER BY name ASC", parameters: [:])
        return try rows.map { try decodeSource(from: $0) }
    }

    public func addSource(_ source: AnigmaSource, context: ExecutionContext) async throws -> (id: String, receipt: CoreReceipt) {
        // Create governance proposal
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "source_authority",
            operation: "add",
            entityId: EntityId(uuidString: source.id) ?? EntityId(),
            componentType: "source",
            context: ["type": source.type.rawValue]
        )

        // Evaluate proposal
        let decision = await governance.canWrite(proposal)
        if !decision.allowed {
            let modeSource = await governance.modeSource(for: context.projectId).rawValue
            let violation = decision.toGovernanceViolation(proposal: proposal, evaluatedModeSource: modeSource)
            throw RuntimeInitializationError.writeBlocked(violation: violation)
        }

        let encoder = JSONEncoder()
        let computeJson = String(data: try encoder.encode(source.computePolicy), encoding: .utf8) ?? "{}"
        let storageJson = String(data: try encoder.encode(source.storagePolicy), encoding: .utf8) ?? "{}"
        let statsJson = source.stats.flatMap { try? encoder.encode($0) }.flatMap { String(data: $0, encoding: .utf8) }

        let sql = """
            INSERT INTO sources (
                id, name, type, path, depth, compute_policy_json, storage_policy_json,
                is_connected, last_indexed_at, status, stats_json, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        _ = try await (databaseAuthority as! DatabaseAuthorityImpl).executeInternal(sql, parameters: [
            .text(source.id),
            .text(source.name),
            .text(source.type.rawValue),
            .text(source.path),
            .text(source.depth.rawValue),
            .text(computeJson),
            .text(storageJson),
            .int(source.isConnected ? 1 : 0),
            source.lastIndexed.map { .int(Int($0.timeIntervalSince1970)) } ?? .null,
            .text(source.status.rawValue),
            statsJson.map { .text($0) } ?? .null,
            .int(Int(Date().timeIntervalSince1970))
        ])

        // Record evidence
        let receipt = try await evidenceAuthority.record(
            operation: .custom,
            principal: context.principal,
            payload: EvidencePayload.custom(type: "add_source", data: ["sourceId": source.id, "type": source.type.rawValue]),
            governanceDecision: decision.asGovernanceDecision(),
            context: context
        )

        return (source.id, receipt)
    }

    public func updateSource(_ source: AnigmaSource, context: ExecutionContext) async throws -> CoreReceipt {
        // Create governance proposal
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "source_authority",
            operation: "update",
            entityId: EntityId(uuidString: source.id) ?? EntityId(),
            componentType: "source",
            context: [:]
        )

        // Evaluate proposal
        let decision = await governance.canWrite(proposal)
        if !decision.allowed {
            let modeSource = await governance.modeSource(for: context.projectId).rawValue
            let violation = decision.toGovernanceViolation(proposal: proposal, evaluatedModeSource: modeSource)
            throw RuntimeInitializationError.writeBlocked(violation: violation)
        }

        let encoder = JSONEncoder()
        let computeJson = String(data: try encoder.encode(source.computePolicy), encoding: .utf8) ?? "{}"
        let storageJson = String(data: try encoder.encode(source.storagePolicy), encoding: .utf8) ?? "{}"
        let statsJson = source.stats.flatMap { try? encoder.encode($0) }.flatMap { String(data: $0, encoding: .utf8) }

        let sql = """
            UPDATE sources SET
                name = ?, type = ?, path = ?, depth = ?,
                compute_policy_json = ?, storage_policy_json = ?,
                is_connected = ?, last_indexed_at = ?, status = ?,
                stats_json = ?
            WHERE id = ?
        """

        _ = try await (databaseAuthority as! DatabaseAuthorityImpl).executeInternal(sql, parameters: [
            .text(source.name),
            .text(source.type.rawValue),
            .text(source.path),
            .text(source.depth.rawValue),
            .text(computeJson),
            .text(storageJson),
            .int(source.isConnected ? 1 : 0),
            source.lastIndexed.map { .int(Int($0.timeIntervalSince1970)) } ?? .null,
            .text(source.status.rawValue),
            statsJson.map { .text($0) } ?? .null,
            .text(source.id)
        ])

        // Record evidence
        return try await evidenceAuthority.record(
            operation: .custom,
            principal: context.principal,
            payload: EvidencePayload.custom(type: "update_source", data: ["sourceId": source.id]),
            governanceDecision: decision.asGovernanceDecision(),
            context: context
        )
    }

    public func removeSource(id: String, context: ExecutionContext) async throws -> CoreReceipt {
        // Create governance proposal
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "source_authority",
            operation: "remove",
            entityId: EntityId(uuidString: id) ?? EntityId(),
            componentType: "source",
            context: [:]
        )

        // Evaluate proposal
        let decision = await governance.canWrite(proposal)
        if !decision.allowed {
            let modeSource = await governance.modeSource(for: context.projectId).rawValue
            let violation = decision.toGovernanceViolation(proposal: proposal, evaluatedModeSource: modeSource)
            throw RuntimeInitializationError.writeBlocked(violation: violation)
        }

        let sql = "DELETE FROM sources WHERE id = ?"
        _ = try await (databaseAuthority as! DatabaseAuthorityImpl).executeInternal(sql, parameters: [.text(id)])

        // Record evidence
        return try await evidenceAuthority.record(
            operation: .custom,
            principal: context.principal,
            payload: EvidencePayload.custom(type: "remove_source", data: ["sourceId": id]),
            governanceDecision: decision.asGovernanceDecision(),
            context: context
        )
    }

    public func getSourceStatus(id: String, principal: Principal) async throws -> AnigmaSourceStatus {
        let rows = try await databaseAuthority.query("SELECT status FROM sources WHERE id = ?", parameters: [.text(id)])
        guard let row = rows.first, let statusStr = row["status"]?.stringValue else {
            throw RuntimeInitializationError.executionFailed("Source not found: \(id)")
        }
        return AnigmaSourceStatus(rawValue: statusStr) ?? .revoked
    }

    private func decodeSource(from row: DatabaseRow) throws -> AnigmaSource {
        let decoder = JSONDecoder()
        
        let id = row["id"]?.stringValue ?? ""
        let name = row["name"]?.stringValue ?? ""
        let type = AnigmaSourceType(rawValue: row["type"]?.stringValue ?? "") ?? .filesystem
        let path = row["path"]?.stringValue ?? ""
        let depth = AnigmaIndexingDepth(rawValue: row["depth"]?.stringValue ?? "") ?? .discovery
        
        let computeJson = row["compute_policy_json"]?.stringValue ?? "{}"
        let compute = try decoder.decode(AnigmaComputePolicy.self, from: Data(computeJson.utf8))
        
        let storageJson = row["storage_policy_json"]?.stringValue ?? "{}"
        let storage = try decoder.decode(AnigmaStoragePolicy.self, from: Data(storageJson.utf8))
        
        let isConnected = (row["is_connected"]?.intValue ?? 0) != 0
        let lastIndexed = row["last_indexed_at"]?.intValue.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        let status = AnigmaSourceStatus(rawValue: row["status"]?.stringValue ?? "") ?? .revoked
        
        let statsJson = row["stats_json"]?.stringValue
        let stats = try statsJson.map { try decoder.decode(AnigmaSourceStats.self, from: Data($0.utf8)) }
        
        return AnigmaSource(
            id: id,
            name: name,
            type: type,
            path: path,
            depth: depth,
            computePolicy: compute,
            storagePolicy: storage,
            isConnected: isConnected,
            lastIndexed: lastIndexed,
            status: status,
            stats: stats
        )
    }
}
