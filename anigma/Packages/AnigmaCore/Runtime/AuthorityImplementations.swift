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
import ContractsCore
import GovernanceCore
import InferenceCore
// import BLAKE3 - Removed for build stability
import DatabaseCore
import AnigmaPrimitives

// MARK: - Database Authority Implementation

/// Phase 1 implementation of DatabaseAuthority
/// Wraps DatabaseActor and adds governance enforcement
actor DatabaseAuthorityImpl: DatabaseAuthority {
    private let databaseActor: DatabaseActor
    private let governance: GovernanceController
    private var evidenceAuthority: (any EvidenceAuthority)?

    /// Registered schemas
    private var schemas: [String: ModuleSchema] = [:]

    init(
        databaseActor: DatabaseActor,
        governance: GovernanceController,
        evidenceAuthority: (any EvidenceAuthority)?
    ) {
        self.databaseActor = databaseActor
        self.governance = governance
        self.evidenceAuthority = evidenceAuthority
    }

    /// Set evidence authority (called after initialization to resolve circular dependency)
    func setEvidenceAuthority(_ authority: any EvidenceAuthority) {
        self.evidenceAuthority = authority
    }

    /// Close database connection
    func close() async {
        await databaseActor.close()
    }

    /// Legacy escape hatch for modules still bound to DatabaseActor.
    func rawDatabaseActor() -> DatabaseActor {
        databaseActor
    }

    /// Execute SQL directly (internal use only - for schema setup)
    func executeDirectly(_ sql: String) async throws {
        try await databaseActor.execute(sql)
    }

    /// Execute SQL internally with parameters (for evidence recording)
    func executeInternal(_ sql: String, parameters: [DatabaseParameter]) async throws {
        _ = try await databaseActor.execute(sql, parameters: parameters)
    }

    // MARK: - DatabaseAuthority Protocol

    func registerSchema(_ schema: ModuleSchema) async throws {
        // Check if already migrated
        let rows = try await databaseActor.query(
            "SELECT version FROM schema_registry WHERE name = ?",
            parameters: [.text(schema.name)]
        )

        let currentVersion = rows.first?.int(for: "version") ?? 0

        // If already up to date (or ahead), skip
        if currentVersion >= schema.version {
            return
        }

        // Run migrations from current version to target version
        for version in (currentVersion + 1)...schema.version {
            guard let migrationSQL = schema.migrations[version] else {
                throw RuntimeError.configurationError(
                    "Missing migration for schema '\(schema.name)' version \(version)"
                )
            }

            // Execute migration
            try await databaseActor.execute(migrationSQL)

            // Record in registry
            if currentVersion == 0 {
                // Insert
                try await databaseActor.execute(
                    "INSERT INTO schema_registry (name, module, version, migrated_at) VALUES (?, ?, ?, ?)",
                    parameters: [
                        .text(schema.name),
                        .text(schema.module),
                        .int(version),
                        .int(Int(Date().timeIntervalSince1970))
                    ]
                )
            } else {
                // Update
                try await databaseActor.execute(
                    "UPDATE schema_registry SET version = ?, migrated_at = ? WHERE name = ?",
                    parameters: [
                        .int(version),
                        .int(Int(Date().timeIntervalSince1970)),
                        .text(schema.name)
                    ]
                )
            }
        }

        schemas[schema.name] = schema
    }

    /// Perform schema migration
    func migrateSchema(_ schema: ModuleSchema) async throws {
        try await registerSchema(schema)
    }

    func query(_ sql: String, parameters: [String: String]) async throws -> [DatabaseRow] {
        let dbParams = parameters
            .sorted { $0.key < $1.key }
            .map { DatabaseParameter.text($0.value) }
        return try await databaseActor.query(sql, parameters: dbParams)
    }

    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow] {
        return try await databaseActor.query(sql, parameters: parameters)
    }

    func mutate(
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
            context: ["project_id": context.projectId ?? ""]
        )

        // Check governance
        let decision = await governance.canWrite(proposal)

        guard decision.allowed else {
            let reasons = decision.failedChecks.map { $0.message }.joined(separator: ", ")
            throw RuntimeError.governanceViolation(reasons)
        }

        // Execute mutation
        let startTime = Date()
        let rowsAffected = try await databaseActor.execute(mutation.sql, parameters: mutation.parameters)
        let duration = Date().timeIntervalSince(startTime)

        // Record evidence (if authority is set)
        var evidence: Receipt
        if let evidenceAuth = evidenceAuthority {
            let payload = EvidencePayload.databaseMutation(
                sql: mutation.sql,
                rowsAffected: rowsAffected
            )

            let govDecision = GovernanceDecision(
                allowed: decision.allowed,
                reason: nil,
                checkResults: decision.checkResults.reduce(into: [:]) { $0[$1.checkId] = $1.passed },
                evaluatedAt: decision.evaluatedAt
            )

            evidence = try await evidenceAuth.record(
                operation: .databaseMutation,
                principal: context.principal,
                payload: payload,
                governanceDecision: govDecision,
                context: context
            )
        } else {
            // Fallback receipt (for testing or when evidence is disabled)
            evidence = Receipt(
                operationType: "database_mutation",
                principal: context.principal,
                outcome: .success,
                summary: "Database mutation: \(rowsAffected) rows affected",
                contentHash: "no-evidence",
                durationMs: Int64(duration * 1000)
            )
        }

        return MutationReceipt(rowsAffected: rowsAffected, evidence: evidence)
    }

    func transaction(
        context: ExecutionContext,
        _ block: @Sendable () async throws -> Void
    ) async throws {
        try await databaseActor.transaction {
            try await block()
        }
    }
}

// MARK: - Evidence Authority Implementation

/// Phase 1 implementation of EvidenceAuthority
/// Consolidates ReceiptEngine, CathedralModule, and HarmoniaModule evidence systems
actor EvidenceAuthorityImpl: EvidenceAuthority {
    private let databaseAuthority: any DatabaseAuthority
    private let governance: GovernanceController
    private var evidenceSinks: [any EvidenceSink] = []

    init(
        databaseAuthority: any DatabaseAuthority,
        governance: GovernanceController
    ) {
        self.databaseAuthority = databaseAuthority
        self.governance = governance
    }

    func addSink(_ sink: any EvidenceSink) {
        evidenceSinks.append(sink)
    }

    func record(
        operation: OperationType,
        principal: Principal,
        payload: EvidencePayload,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws -> Receipt {
        let startTime = Date()

        // Create receipt
        let receipt = Receipt(
            operationType: operation.rawValue,
            principal: principal,
            timestamp: Date(),
            outcome: .success,
            summary: nil,
            metadata: context.metadata,
            inputRefs: [],
            outputRefs: [],
            contentHash: computeHash(operation, principal, payload),
            durationMs: 0
        )

        // Compute chain hash (for now, just use content hash - will improve in Phase 2)
        let chainHash = receipt.contentHash

        // Serialize for storage
        let payloadJSON = try serializePayload(payload)

        // Store in database
        let sql = """
            INSERT INTO evidence_bundles (
                id, operation_type, principal_id, principal_name, timestamp,
                outcome, summary, input_refs, output_refs, content_hash,
                duration_ms, metadata, governance_decision, payload, chain_hash, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        let params: [DatabaseParameter] = [
            .text(receipt.id.raw),
            .text(receipt.operationType),
            .text(receipt.principal.id),
            .text(receipt.principal.displayName),
            .int(Int(receipt.timestamp.timeIntervalSince1970)),
            .text(receipt.outcome.rawValue),
            receipt.summary.map { .text($0) } ?? .null,
            .text("[]"), // input_refs
            .text("[]"), // output_refs
            .text(receipt.contentHash),
            .int(0), // duration_ms
            .text("{}"), // metadata
            .null, // governance_decision
            .text(payloadJSON),
            .text(chainHash),
            .int(Int(Date().timeIntervalSince1970))
        ]

        try await (databaseAuthority as! DatabaseAuthorityImpl).executeInternal(sql, parameters: params)

        let duration = Date().timeIntervalSince(startTime)

        let finalizedReceipt = Receipt(
            id: receipt.id,
            operationType: receipt.operationType,
            principal: principal,
            timestamp: receipt.timestamp,
            outcome: receipt.outcome,
            summary: receipt.summary,
            metadata: receipt.metadata,
            inputRefs: receipt.inputRefs,
            outputRefs: receipt.outputRefs,
            contentHash: receipt.contentHash,
            durationMs: Int64(duration * 1000)
        )

        for sink in evidenceSinks {
            await sink.record(
                receipt: finalizedReceipt,
                payload: payload,
                operation: operation,
                governanceDecision: governanceDecision,
                context: context
            )
        }

        return finalizedReceipt
    }

    func query(
        filter: EvidenceFilter,
        principal: Principal
    ) async throws -> [EvidenceBundle] {
        // Build query based on filter
        var sql = "SELECT * FROM evidence_bundles WHERE 1=1"
        var params: [DatabaseParameter] = []

        if let sessionId = filter.sessionId {
            sql += " AND session_id = ?"
            params.append(.text(sessionId))
        }

        // Execute query
        let rows = try await databaseAuthority.query(sql, parameters: params)

        // Parse rows into evidence bundles
        return rows.compactMap { row in
            guard let idStr = row.string(for: "id"),
                  let operationType = row.string(for: "operation_type"),
                  let principalId = row.string(for: "principal_id"),
                  let principalName = row.string(for: "principal_name"),
                  let timestamp = row.int(for: "timestamp"),
                  let outcome = row.string(for: "outcome"),
                  let contentHash = row.string(for: "content_hash"),
                  let durationMs = row.int64(for: "duration_ms"),
                  let chainHash = row.string(for: "chain_hash")
            else { return nil }

            let receiptPrincipal = Principal(id: principalId, displayName: principalName)

            let receipt = Receipt(
                id: ReceiptID(raw: idStr),
                operationType: operationType,
                principal: receiptPrincipal,
                timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                outcome: OperationOutcome(rawValue: outcome) ?? .failure,
                summary: row.string(for: "summary"),
                contentHash: contentHash,
                durationMs: durationMs
            )

            // Parse payload (simplified for Phase 1)
            let payload = EvidencePayload.custom(type: operationType, data: [:])

            return EvidenceBundle(
                id: receipt.id,
                receipt: receipt,
                payload: payload,
                governanceDecision: nil,
                chainHash: chainHash
            )
        }
    }

    func verify(receiptId: ReceiptID) async throws -> VerificationResult {
        // Phase 1: Basic verification
        // Phase 2: Full cryptographic verification with chain integrity

        let rows = try await databaseAuthority.query(
            "SELECT * FROM evidence_bundles WHERE id = ?",
            parameters: [.text(receiptId.raw)]
        )

        guard !rows.isEmpty else {
            return VerificationResult(
                isValid: false,
                violations: ["Receipt not found"],
                chainIntact: false,
                timestampValid: false
            )
        }

        return VerificationResult(
            isValid: true,
            violations: [],
            chainIntact: true,
            timestampValid: true
        )
    }

    // MARK: - Helpers

    private func computeHash(_ operation: OperationType, _ principal: Principal, _ payload: EvidencePayload) -> String {
        // Use BLAKE3 for high-performance cryptographic hashing as per AnigmaPrimitives
        var combinedData = Data()
        combinedData.append("\(operation.rawValue)".data(using: .utf8)!)
        combinedData.append("\(principal.id)".data(using: .utf8)!)
        combinedData.append(payload.typeIdentifier.data(using: .utf8)!)

        // Add payload data if it's a simple custom payload
        if case .custom(_, let data) = payload {
            let sortedKeys = data.keys.sorted()
            for key in sortedKeys {
                combinedData.append("\(key):\(data[key] ?? "")".data(using: .utf8)!)
            }
        }

        return BLAKE3Digest.hex(of: combinedData)
    }

    private func serializePayload(_ payload: EvidencePayload) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

        // This assumes EvidencePayload is Codable or provides a dictionary representation
        // For Phase 1, we use the type identifier + a simplified JSON representation
        switch payload {
        case .databaseMutation(let sql, let rows):
            return "{\"type\":\"db_mutation\",\"sql\":\"\(sql)\",\"rows\":\(rows)}"
        case .artifactStorage(let hash, let size):
            return "{\"type\":\"artifact_storage\",\"hash\":\"\(hash)\",\"size\":\(size)}"
        case .custom(let type, let data):
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return "{\"type\":\"\(type)\",\"data\":\(String(data: jsonData, encoding: .utf8) ?? "{}")}"
        default:
            return "{\"type\":\"\(payload.typeIdentifier)\"}"
        }
    }
}

// MARK: - Artifact Authority Implementation

/// Phase 1 implementation of ArtifactAuthority
actor ArtifactAuthorityImpl: ArtifactAuthority {
    private let databaseAuthority: any DatabaseAuthority
    private let evidenceAuthority: any EvidenceAuthority
    private let governance: GovernanceController

    /// In-memory artifact storage (Phase 1 - will use VaultAuthority in Phase 2)
    private var artifacts: [ArtifactID: Artifact] = [:]

    init(
        databaseAuthority: any DatabaseAuthority,
        evidenceAuthority: any EvidenceAuthority,
        governance: GovernanceController
    ) {
        self.databaseAuthority = databaseAuthority
        self.evidenceAuthority = evidenceAuthority
        self.governance = governance
    }

    func store(
        _ artifact: Artifact,
        context: ExecutionContext
    ) async throws -> (id: ArtifactID, receipt: Receipt) {
        // Store artifact in memory (Phase 1)
        artifacts[artifact.id] = artifact

        // Store metadata in database
        guard let dbAuth = databaseAuthority as? DatabaseAuthorityImpl else {
            fatalError("Failed to cast to DatabaseAuthorityImpl")
        }
        
        let sql = """
            INSERT INTO artifact_metadata (id, mime_type, size, created_at, tags, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        
        let params: [DatabaseParameter] = [
            .text(artifact.id.hash),
            .text(artifact.mimeType),
            .int(Int(artifact.size)),
            .int(Int(artifact.createdAt.timeIntervalSince1970)),
            .text(artifact.tags.joined(separator: ",")),
            .text("{}")
        ]
        
        try await dbAuth.executeInternal(sql, parameters: params)

        // Record evidence
        let payload = EvidencePayload.artifactStorage(
            artifactId: artifact.id.hash,
            size: artifact.size
        )

        let receipt = try await evidenceAuthority.record(
            operation: .artifactStorage,
            principal: context.principal,
            payload: payload,
            governanceDecision: nil,
            context: context
        )

        return (artifact.id, receipt)
    }

    func retrieve(
        _ id: ArtifactID,
        principal: Principal
    ) async throws -> Artifact {
        guard let artifact = artifacts[id] else {
            throw RuntimeError.artifactNotFound(id)
        }

        // TODO: Check access control

        return artifact
    }

    func list(
        filter: ArtifactFilter,
        principal: Principal
    ) async throws -> [ArtifactMetadata] {
        // Phase 1: Simple in-memory filtering
        return artifacts.values.compactMap { artifact in
            // Apply filter
            if let mimeTypes = filter.mimeTypes, !mimeTypes.contains(artifact.mimeType) {
                return nil
            }

            return ArtifactMetadata(
                id: artifact.id,
                mimeType: artifact.mimeType,
                size: artifact.size,
                createdAt: artifact.createdAt,
                tags: artifact.tags,
                metadata: artifact.metadata
            )
        }
    }

    func delete(
        _ id: ArtifactID,
        context: ExecutionContext
    ) async throws -> Receipt {
        artifacts.removeValue(forKey: id)

        // Record evidence
        let payload = EvidencePayload.custom(
            type: "artifact_deletion",
            data: ["artifact_id": id.hash]
        )

        return try await evidenceAuthority.record(
            operation: .custom,
            principal: context.principal,
            payload: payload,
            governanceDecision: nil,
            context: context
        )
    }
}

// MARK: - Execution Authority Implementation

/// Phase 1 implementation of ExecutionAuthority
actor ExecutionAuthorityImpl: ExecutionAuthority {
    private let world: World
    private let governance: GovernanceController
    private let evidenceAuthority: any EvidenceAuthority
    private let databaseAuthority: any DatabaseAuthority
    private let artifactsAuthority: any ArtifactAuthority
    private let inferenceAuthority: any InferenceAuthority
    private let accessibilityAuthority: any AccessibilityAuthority

    /// In-memory job queue (Phase 1 - will use proper queue in Phase 2)
    private var jobs: [JobId: JobRecord] = [:]

    init(
        world: World,
        governance: GovernanceController,
        evidenceAuthority: any EvidenceAuthority,
        databaseAuthority: any DatabaseAuthority,
        artifactsAuthority: any ArtifactAuthority,
        inferenceAuthority: any InferenceAuthority,
        accessibilityAuthority: any AccessibilityAuthority
    ) {
        self.world = world
        self.governance = governance
        self.evidenceAuthority = evidenceAuthority
        self.databaseAuthority = databaseAuthority
        self.artifactsAuthority = artifactsAuthority
        self.inferenceAuthority = inferenceAuthority
        self.accessibilityAuthority = accessibilityAuthority
    }

    func execute<W: PlatformWorkflow>(
        _ workflow: W,
        context: ExecutionContext
    ) async throws -> Receipt {
        // Create governance proposal for workflow execution
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: W.typeIdentifier,
            operation: "workflow_execution",
            context: ["project_id": context.projectId ?? ""]
        )

        // Check governance
        let decision = await governance.canWrite(proposal)

        guard decision.allowed else {
            let reasons = decision.failedChecks.map { $0.message }.joined(separator: ", ")
            throw RuntimeError.governanceViolation(reasons)
        }

        // Create runtime services proxy
        let services = RuntimeServicesProxy(
            database: databaseAuthority,
            evidence: evidenceAuthority,
            artifacts: artifactsAuthority,
            governance: governance,
            inference: inferenceAuthority,
            accessibility: accessibilityAuthority
        )

        // Execute workflow
        let result = try await workflow.execute(context: context, runtime: services)

        // Record evidence
        let payload = EvidencePayload.workflowExecution(
            workflowType: W.typeIdentifier,
            inputs: [],
            outputs: result.outputRefs
        )

        let govDecision = GovernanceDecision(
            allowed: decision.allowed,
            checkResults: decision.checkResults.reduce(into: [:]) { $0[$1.checkId] = $1.passed },
            evaluatedAt: decision.evaluatedAt
        )

        let receipt = try await evidenceAuthority.record(
            operation: .workflowExecution,
            principal: context.principal,
            payload: payload,
            governanceDecision: govDecision,
            context: context
        )

        return receipt
    }

    func submit(_ job: Job) async throws -> JobId {
        let record = JobRecord(job: job, status: .pending)
        jobs[job.id] = record

        // TODO: Phase 2 - persist to database and enqueue

        return job.id
    }

    func jobStatus(_ id: JobId) async throws -> JobRecord {
        guard let record = jobs[id] else {
            throw JobError.jobNotFound(id)
        }
        return record
    }

    func cancel(_ id: JobId, principal: Principal) async throws {
        guard var record = jobs[id] else {
            throw JobError.jobNotFound(id)
        }

        record.status = .cancelled
        jobs[id] = record
    }
}

// MARK: - Inference Authority Implementation

/// Phase 1 implementation of InferenceAuthority.
/// Routes requests between UI and Background inference planes.
actor InferenceAuthorityImpl: InferenceAuthority {
    private let uiPlane: any InferencePlane
    private let workerPlane: any InferencePlane
    private let watchdog = InferenceWatchdog()
    private let governance: GovernanceController
    private var evidenceAuthority: (any EvidenceAuthority)?

    init(
        uiPlane: any InferencePlane,
        workerPlane: any InferencePlane,
        governance: GovernanceController,
        evidenceAuthority: (any EvidenceAuthority)? = nil
    ) {
        self.uiPlane = uiPlane
        self.workerPlane = workerPlane
        self.governance = governance
        self.evidenceAuthority = evidenceAuthority
    }

    func chatCompletion(
        _ request: InferenceRequest,
        priority: InferencePriority,
        speculativeConfig: SpeculativeConfiguration?,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // 1. Governance check
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "inference",
            operation: "chat",
            context: ["model": request.modelID ?? "default"]
        )
        let decision = await governance.canWrite(proposal)
        guard decision.allowed else {
            throw RuntimeError.governanceViolation("Inference denied by policy")
        }

        // 2. Determine plane
        let plane = (priority == .ui) ? uiPlane : workerPlane

        // 3. Handle Speculative Decoding
        var finalRequest = request
        if let spec = speculativeConfig {
            // Update request options with speculative parameters for the plane to handle
            var options = request.options
            options["speculative_draft_model"] = .string(spec.draftModelID)
            options["speculative_max_tokens"] = .integer(spec.maxDraftTokens)
            finalRequest = InferenceRequest(
                task: request.task,
                input: request.input,
                attachments: request.attachments,
                modelID: request.modelID,
                options: options
            )
        }

        // 4. Track process via watchdog
        await watchdog.heartbeat(pid: 0)

        let response = try await plane.perform(finalRequest)

        // 5. Record evidence
        _ = try await evidenceAuthority?.record(
            operation: .custom,
            principal: context.principal,
            payload: .custom(type: "inference_call", data: [
                "tokens": "\(response.usage.outputTokens ?? 0)",
                "speculative": speculativeConfig != nil ? "true" : "false"
            ]),
            governanceDecision: nil as GovernanceDecision?,
            context: context
        )

        return response
    }

    func backgroundTask(
        _ task: InferenceRequest,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // Background tasks ALWAYS use the worker plane to avoid blocking UI
        return try await workerPlane.perform(task)
    }

    func getStatus() async -> [InferencePlaneStatus] {
        // In a full implementation, this would query the planes for their actual health
        return [
            InferencePlaneStatus(planeId: "ui", isAvailable: true, currentLoad: 0.0),
            InferencePlaneStatus(planeId: "worker", isAvailable: true, currentLoad: 0.0)
        ]
    }
}

// MARK: - Handoff Authority Implementation

/// Phase 1 implementation of HandoffAuthority.
/// Routes tasks between execution planes based on privacy and performance.
actor HandoffAuthorityImpl: HandoffAuthority {
    private let router = PromptRouter()

    func determinePlane(for task: InferenceRequest, context: ExecutionContext) async -> HandoffDecision {
        // 1. Classify the task intent and risk
        let classification = await router.classify(task.input)

        // 2. Routing Logic

        // Rule: Anything with sensitive intent or high risk MUST stay on localSecure
        if classification.intent == .sensitiveDataQuery || classification.riskScore > 0.5 {
            return HandoffDecision(
                plane: .localSecure,
                reason: "Strict privacy requirement for \(classification.intent.rawValue)"
            )
        }

        // Rule: Creative tasks or image generation can go to Apple Intelligence
        if task.task == .textGeneration && task.input.contains("image") {
            return HandoffDecision(
                plane: .appleIntelligence,
                reason: "Optimized for native multimodal processing"
            )
        }

        // Rule: General high-performance requests go to governed cloud
        if task.options["high_perf"]?.asBool == true {
            return HandoffDecision(
                plane: .governedCloud,
                reason: "Performance optimization requested"
            )
        }

        // Default to localSecure for institutional safety
        return HandoffDecision(plane: .localSecure, reason: "Default institutional safety profile")
    }
}

// MARK: - Workflow Protocol

/// Proxy that provides runtime services to workflows
private actor RuntimeServicesProxy: RuntimeServices {
    let database: any DatabaseAuthority
    let evidence: any EvidenceAuthority
    let artifacts: any ArtifactAuthority
    let governance: GovernanceController
    let inference: any InferenceAuthority
    let accessibility: any AccessibilityAuthority

    init(
        database: any DatabaseAuthority,
        evidence: any EvidenceAuthority,
        artifacts: any ArtifactAuthority,
        governance: GovernanceController,
        inference: any InferenceAuthority,
        accessibility: any AccessibilityAuthority
    ) {
        self.database = database
        self.evidence = evidence
        self.artifacts = artifacts
        self.governance = governance
        self.inference = inference
        self.accessibility = accessibility
    }
}

// MARK: - Helper Extensions

extension DatabaseValue {
    var asInt64: Int64? {
        switch self {
        case .int(let value):
            return Int64(value)
        default:
            return nil
        }
    }
}
