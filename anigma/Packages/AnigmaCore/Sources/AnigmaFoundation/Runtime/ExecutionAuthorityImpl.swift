//
//  ExecutionAuthorityImpl.swift
//  AnigmaCore
//
//  Execution authority and runtime proxy extracted from the larger
//  authority implementation surface.
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

/// Phase 1 implementation of ExecutionAuthority
public actor ExecutionAuthorityImpl: ExecutionAuthority {
    private let world: World
    private let governance: any GoverningController
    private let evidenceAuthority: any EvidenceAuthority
    private let databaseAuthority: any DatabaseAuthority
    private let artifactsAuthority: any ArtifactAuthority
    private let inferenceAuthority: any InferenceAuthority
    private let accessibilityAuthority: any AccessibilityAuthority
    private let sourcesAuthority: any SourceAuthority

    /// Job records for in-memory tracking
    private var jobs: [JobId: JobRecord] = [:]

    public init(
        world: World,
        governance: any GoverningController,
        evidenceAuthority: any EvidenceAuthority,
        databaseAuthority: any DatabaseAuthority,
        artifactsAuthority: any ArtifactAuthority,
        inferenceAuthority: any InferenceAuthority,
        accessibilityAuthority: any AccessibilityAuthority,
        sourcesAuthority: any SourceAuthority
    ) {
        self.world = world
        self.governance = governance
        self.evidenceAuthority = evidenceAuthority
        self.databaseAuthority = databaseAuthority
        self.artifactsAuthority = artifactsAuthority
        self.inferenceAuthority = inferenceAuthority
        self.accessibilityAuthority = accessibilityAuthority
        self.sourcesAuthority = sourcesAuthority
    }

    public func execute<W: PlatformWorkflow>(
        _ workflow: W,
        context: ExecutionContext
    ) async throws -> CoreReceipt {
        let accessPrincipal = AccessPrincipal(
            id: context.principal.id,
            module: W.typeIdentifier,
            roles: context.principal.roles
        )

        let request = AccessRequest(
            principal: accessPrincipal,
            componentType: "workflow",
            sensitivity: DataSensitivity.internal,
            accessType: AccessType.write
        )

        try await governance.accessController.checkAccess(request)

        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "execution_authority",
            operation: "execute_workflow",
            entityId: nil,
            componentType: "workflow",
            context: ["workflow_type": W.typeIdentifier, "projectId": context.projectId ?? ""]
        )

        let decision = await governance.canWrite(proposal)
        if !decision.allowed {
            let modeSource = await governance.modeSource(for: context.projectId).rawValue
            let violation = decision.toGovernanceViolation(proposal: proposal, evaluatedModeSource: modeSource)
            throw RuntimeInitializationError.writeBlocked(violation: violation)
        }

        let proxy = RuntimeServicesProxy(
            database: databaseAuthority,
            evidence: evidenceAuthority,
            artifacts: artifactsAuthority,
            governance: governance,
            inference: inferenceAuthority,
            accessibility: accessibilityAuthority,
            sources: sourcesAuthority
        )

        let result = try await workflow.execute(context: context, runtime: proxy)

        let payload = EvidencePayload.workflowExecution(
            workflowType: W.typeIdentifier,
            inputs: [],
            outputs: result.outputRefs
        )

        return try await evidenceAuthority.record(
            operation: CoreOperationType.workflowExecution,
            principal: context.principal,
            payload: payload,
            governanceDecision: decision.asGovernanceDecision(),
            context: context
        )
    }

    public func submit(_ job: Job) async throws -> JobId {
        let proposal = WriteProposal(
            principal: "system",
            module: "execution_authority",
            operation: "submit_job",
            entityId: EntityId(uuidString: job.id.raw) ?? EntityId(),
            componentType: "job",
            context: [:]
        )

        let decision = await governance.canWrite(proposal)
        if !decision.allowed {
            let modeSource = await governance.modeSource(for: .none).rawValue
            let violation = decision.toGovernanceViolation(proposal: proposal, evaluatedModeSource: modeSource)
            throw RuntimeInitializationError.writeBlocked(violation: violation)
        }

        let accessPrincipal = AccessPrincipal(
            id: "system",
            module: "execution_authority",
            roles: ["system"]
        )

        let request = AccessRequest(
            principal: accessPrincipal,
            componentType: "job",
            sensitivity: DataSensitivity.internal,
            accessType: AccessType.write
        )

        try await governance.accessController.checkAccess(request)

        let record = JobRecord(job: job, status: JobStatus.pending)
        jobs[job.id] = record
        return job.id
    }

    public func jobStatus(_ id: JobId) async throws -> JobRecord {
        guard let record = jobs[id] else {
            throw RuntimeInitializationError.executionFailed("Job not found: \(id)")
        }
        return record
    }

    public func cancel(_ id: JobId, principal: Principal) async throws {
        let accessPrincipal = AccessPrincipal(
            id: principal.id,
            module: "execution_authority",
            roles: principal.roles
        )

        let request = AccessRequest(
            principal: accessPrincipal,
            componentType: "job",
            sensitivity: DataSensitivity.internal,
            accessType: AccessType.delete,
            entityId: EntityId(uuidString: id.raw)
        )

        try await governance.accessController.checkAccess(request)

        guard var record = jobs[id] else {
            return
        }

        record.status = JobStatus.cancelled
        jobs[id] = record
    }
}

// MARK: - Proxy Implementation

/// Proxy that provides runtime services to workflows
private actor RuntimeServicesProxy: RuntimeServices {
    let database: any DatabaseAuthority
    let evidence: any EvidenceAuthority
    let artifacts: any ArtifactAuthority
    let governance: any GoverningController
    let inference: any InferenceAuthority
    let accessibility: any AccessibilityAuthority
    let sources: any SourceAuthority

    init(
        database: any DatabaseAuthority,
        evidence: any EvidenceAuthority,
        artifacts: any ArtifactAuthority,
        governance: any GoverningController,
        inference: any InferenceAuthority,
        accessibility: any AccessibilityAuthority,
        sources: any SourceAuthority
    ) {
        self.database = database
        self.evidence = evidence
        self.artifacts = artifacts
        self.governance = governance
        self.inference = inference
        self.accessibility = accessibility
        self.sources = sources
    }

    // MARK: - RuntimeGovernanceAPI Conformance

    func setMode(_ mode: OperatingMode, for projectId: String?, by principal: Principal) async throws {
        let dbAdapter = DatabaseAuthorityAdapter(databaseAuthority: database)
        try await governance.setMode(mode, for: projectId, by: principal, using: dbAdapter)
    }

    func showMode(for projectId: String?) async throws -> (effective: OperatingMode, source: ModeSource) {
        let effectiveMode = await governance.getMode(for: projectId)
        let source = await governance.modeSource(for: projectId)
        return (effectiveMode, source)
    }

    func clearMode(for projectId: String?, by principal: Principal) async throws {
        let dbAdapter = DatabaseAuthorityAdapter(databaseAuthority: database)
        try await governance.clearMode(for: projectId, by: principal.id, using: dbAdapter)
    }

    // MARK: - RuntimeKillSwitchAPI Conformance

    func setKillSwitch(active: Bool, for projectId: String?, reason: String?, by principal: Principal) async throws {
        try await governance.setKillSwitch(active: active, for: projectId, reason: reason, by: principal, using: database)
    }

    func showKillSwitch(for projectId: String?) async throws -> (active: Bool, reason: String?) {
        return try await governance.showKillSwitch(for: projectId)
    }

    func isWriteAllowed(forProject projectId: String?) async -> Bool {
        let killSwitch = await governance.killSwitch
        return await killSwitch.isWriteAllowed(forProject: projectId)
    }

    func activate(reason: String, by principalId: String) async {
        let killSwitch = await governance.killSwitch
        await killSwitch.activate(reason: reason, by: principalId)
    }

    func killSwitchStatus() async -> (isActive: Bool, activationReason: String?) {
        let killSwitch = await governance.killSwitch
        return await killSwitch.killSwitchStatus()
    }

    func deactivate(by principalId: String) async {
        let killSwitch = await governance.killSwitch
        await killSwitch.deactivate(by: principalId)
    }

    #if DEBUG
    // MARK: - Diagnostics

    func runtimeDiagnostics() -> (instanceId: UUID, dbPath: String) {
        return (UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, "proxy-no-db-path")
    }
    #endif
}

// MARK: - Governance Helpers

extension WriteGateDecision {
    func toGovernanceViolation(
        proposal: WriteProposal,
        evaluatedModeSource: String?
    ) -> GovernanceViolation {
        let failedCheckStructs = self.failedChecks.map {
            GovernanceViolation.FailedCheck(checkId: $0.checkId, message: $0.message)
        }

        return GovernanceViolation(
            id: UUID(),
            principal: proposal.principal,
            projectId: proposal.context["projectId"],
            operation: proposal.operation,
            module: proposal.module,
            evaluatedModeSource: evaluatedModeSource,
            failedChecks: failedCheckStructs,
            timestamp: self.evaluatedAt
        )
    }
}
