//
//  AnigmaAuthority.swift
//  AnigmaHostKit
//
//  [Brief description of file purpose]
//

import AnigmaClientKit  // For AuthorityRouting
import AnigmaCore
import AnigmaDaemonCore  // For proto types
import AnigmaPrimitives
import AnigmaSidecar  // For SidecarBridge
import Combine
import ContractsCore
import CryptoKit
import Foundation

/// The authoritative source of truth for Anigma renderers.
/// This actor is the Host API. Renderers should only interact with it via `AnigmaClient`.
public actor AnigmaAuthority: AuthorityRouting {
    public let irPublisher = PassthroughSubject<(SurfaceId, PresentationIR), Never>()
    private var activeSurfaces: [SurfaceId: SurfaceState] = [:]
    private var activeJobs: [String: JobState] = [:]  // JobID -> State
    private let maxNoncesPerSurface = 1000

    // Phase 8: Truth storage for workspaces and artifacts
    private var workspaces: [String: WorkspaceState] = [:]
    private var artifacts: [String: ArtifactState] = [:]
    private var eventContinuations: [UUID: AsyncStream<AuthorityEvent>.Continuation] = [:]

    private let sidecarBridge: SidecarBridge

    private init(sidecarBridge: SidecarBridge) {
        self.sidecarBridge = sidecarBridge
    }

    public static func create(socketPath: String? = nil) async throws -> AnigmaAuthority {
        let bridge = try await SidecarBridge.create(socketPath: socketPath)
        return AnigmaAuthority(sidecarBridge: bridge)
    }

    /// Registers a new surface and mints its unique ID and initial capabilities.
    /// Host-only API.
    public func registerSurface(actorId: ActorId) -> (SurfaceId, ContractsCore.CapabilityToken) {
        let surfaceId = SurfaceId.generate()
        // Grant default capability for "ui:/" resources, but DENY "ui:/forbidden"
        let defaultScope = Scope(resource: "ui:/", action: "*", effect: .allow)
        let denyScope = Scope(resource: "ui:/forbidden", action: "*", effect: .deny)

        let token = ContractsCore.CapabilityToken(
            surfaceId: surfaceId,
            actorId: actorId,
            allowedActionFamilies: ["core", "ui", "filesystem", "test"],
            scopes: [defaultScope, denyScope],
            expiresAt: Date().addingTimeInterval(3600)
        )

        activeSurfaces[surfaceId] = SurfaceState(
            surfaceId: surfaceId, actorId: actorId, currentToken: token)
        return (surfaceId, token)
    }

    /// Updates the Presentation IR for a surface.
    /// Host-only API. Renderers MUST NOT call this.
    /// Returns an authoritative Snapshot ID minted by the authority.
    @discardableResult
    public func updateIR(_ ir: PresentationIR, for surfaceId: SurfaceId) -> String? {
        if var state = activeSurfaces[surfaceId] {
            // 1. Calculate Canonical Hash of IR (Proof of Content)
            // Use contentOnlyEncode() to strictly exclude snapshotId from the hash.
            let canonicalData = (try? ir.contentOnlyEncode()) ?? Data()
            let irHash = SHA256.hash(data: canonicalData).map { String(format: "%02x", $0) }
                .joined()

            // 2. Mint Authoritative Snapshot ID
            let snapshotId = UUID().uuidString.lowercased()

            // 3. Store Authoritative State
            state.currentIR = ir
            state.currentSnapshotId = snapshotId
            state.currentIRHash = irHash

            activeSurfaces[surfaceId] = state

            // 4. Publish the update
            irPublisher.send((surfaceId, ir))

            return snapshotId
        }
        return nil
    }

    /// Validates and ensures an intent is authorized to execute.
    /// This is used by `AnigmaClient` to implement `submitIntent`.
    public func validateAndRouteIntent(_ intent: ActionIntent) async -> ContractsCore.Receipt {
        let surfaceId = intent.header.surfaceId

        // 1. Validate Surface & Capability
        guard var state = activeSurfaces[surfaceId],
            state.currentToken.id == intent.header.capabilityToken,
            state.currentToken.isValid()
        else {
            return makeDenial(for: intent, code: .capabilityDenied)
        }

        // 2. Validate Nonce (Replay Protection)
        let nonceKey = "\(state.currentToken.id):\(intent.header.nonce)"
        if state.activeNonces.contains(nonceKey) {
            return makeDenial(for: intent, code: .invalidNonce)
        }
        if state.activeNonces.count >= maxNoncesPerSurface {
            return makeDenial(for: intent, code: .resourceExhausted)
        }
        state.activeNonces.insert(nonceKey)
        activeSurfaces[surfaceId] = state

        // 3. Validate IR Snapshot
        guard let currentSnapshotId = state.currentSnapshotId, let ir = state.currentIR else {
            return makeDenial(for: intent, code: .schemaUnreachable)
        }
        guard currentSnapshotId == intent.header.irSnapshotId else {
            return makeDenial(for: intent, code: .staleSnapshot)
        }

        // 4. Validate Action Schema & Parameters
        guard let definition = ActionCatalog.shared.definition(for: intent.action) else {
            return makeDenial(for: intent, code: .schemaUnreachable)
        }
        do {
            try validateParameters(intent: intent, definition: definition)
        } catch let error as DenialCode {
            return makeDenial(for: intent, code: error)
        } catch {
            return makeDenial(for: intent, code: .invalidParameters)
        }

        // 6. Validate Scope & Capability
        let targetResource = definition.resourceMapper(intent)
        if state.currentToken.checkScope(resource: targetResource, action: intent.action.rawValue)
            == .deny {
            return makeDenial(for: intent, code: .scopeViolation)
        }
        guard state.currentToken.allowedActionFamilies.contains(intent.action.family) else {
            return makeDenial(for: intent, code: .capabilityDenied)
        }

        // 7. Deterministic Reachability Check
        guard ir.isReachable(intent.action) else {
            return makeDenial(for: intent, code: .schemaUnreachable)
        }

        // 8. Success - Route to Core
        let intentHash = calculateIntentHash(intent)
        var jobSpec = AnigmaJobSpec()
        jobSpec.kind = intent.action.rawValue
        if let configCanonical = try? encodeJobConfig(intent) {
            jobSpec.configCanonical = configCanonical
        }

        let optimisticReceipt = ContractsCore.Receipt(
            ref: ReceiptRef(id: UUID().uuidString, intentHash: intentHash),
            status: .success,
            outcome: .string("Intent \(intent.action.rawValue) accepted and routed to daemon."),
            seal: .unsigned(hash: intentHash)
        )

        // Launch background task to submit and monitor the job
        Task {
            await self.submitAndMonitorJob(spec: jobSpec, intent: intent, surfaceId: surfaceId)
        }

        return optimisticReceipt
    }

    /// Proactively evaluates an intent without executing it.
    /// Used by renderers to reactively update UI state (e.g., button enabled/disabled).
    public func evaluateIntent(_ intent: ActionIntent) async -> IntentEvaluation {
        let surfaceId = intent.header.surfaceId
        guard let state = activeSurfaces[surfaceId] else {
            return .denied(reason: "Surface context not found")
        }

        // 1. Basic Token Check
        guard
            state.currentToken.id == intent.header.capabilityToken,
            state.currentToken.isValid()
        else {
            return .denied(reason: "Invalid or expired capability token")
        }

        // 2. Validate IR Snapshot
        guard let currentSnapshotId = state.currentSnapshotId, let ir = state.currentIR else {
            return .denied(reason: "UI state unavailable")
        }
        guard currentSnapshotId == intent.header.irSnapshotId else {
            return .denied(reason: "UI state is stale")
        }

        // 3. Validate Action Schema & Parameters
        guard let definition = ActionCatalog.shared.definition(for: intent.action) else {
            return .denied(reason: "Unknown action: \(intent.action.rawValue)")
        }

        do {
            try validateParameters(intent: intent, definition: definition)
        } catch {
            return .denied(reason: "Invalid parameters: \(error.localizedDescription)")
        }

        // 4. Validate Scope & Capability
        let targetResource = definition.resourceMapper(intent)
        if state.currentToken.checkScope(resource: targetResource, action: intent.action.rawValue)
            == .deny {
            return .denied(reason: "Access denied by governing scope")
        }
        guard state.currentToken.allowedActionFamilies.contains(intent.action.family) else {
            return .denied(
                reason: "Access denied: action family '\(intent.action.family)' not allowed")
        }

        // 5. Reachability Check
        guard ir.isReachable(intent.action) else {
            return .denied(reason: "Action is not reachable in the current view")
        }

        // 6. Check if action requires confirmation
        if intent.action.rawValue == "artifact.delete" || intent.action.rawValue == "job.cancel" {
            return .needsConfirmation(
                prompt: "Are you sure you want to perform this sensitive operation?")
        }

        return .allowed
    }

    private func submitAndMonitorJob(
        spec: AnigmaJobSpec, intent: ActionIntent, surfaceId: SurfaceId
    ) async {
        do {
            let response = try await self.sidecarBridge.submitJob(spec)

            guard response.error.code.isEmpty else {
                print("anigmad rejected job: \(response.error.code) \(response.error.message)")
                return
            }

            let jobId = response.jobID
            print(
                "Successfully submitted job to anigmad. ID: \(jobId) Receipt: \(response.receiptHash)"
            )

            self.activeJobs[jobId] = JobState(
                jobId: jobId,
                intent: intent,
                workspaceId: intent.header.surfaceId.rawValue,  // Fix conversion
                submittedAt: Date(),
                status: "QUEUED"
            )
            emitJobUpdate(jobId: jobId)  // Phase 8: Emit event
            await self.publishIRUpdateForJob(surfaceId: surfaceId)

            let eventStream = await self.sidecarBridge.streamJobEvents(jobId: jobId)
            for try await event in eventStream {
                print("Received event for job \(event.jobID): \(event.type) - \(event.message)")
                if var jobState = self.activeJobs[event.jobID] {
                    jobState.status = event.type
                    jobState.message = event.message
                    jobState.progress = Int(event.progressPermille)

                    if !event.receiptHash.isEmpty {
                        jobState.finalReceiptHash = event.receiptHash
                    }

                    if event.type == "SUCCEEDED" || event.type == "FAILED"
                        || event.type == "CANCELED" {
                        jobState.isTerminal = true
                        if let hash = jobState.finalReceiptHash, !hash.isEmpty {
                            do {
                                let verificationResponse = try await self.sidecarBridge.verifyChain(
                                    headReceiptHash: hash)
                                if verificationResponse.ok {
                                    jobState.receiptVerificationStatus = .verified
                                    jobState.isVerified = true
                                    jobState.verifiedAt = Date()
                                    print("✅ Receipt chain VERIFIED for job \(jobId)")
                                } else {
                                    jobState.receiptVerificationStatus = .failed(
                                        reason: verificationResponse.message)
                                    jobState.verificationError = verificationResponse.message
                                    print(
                                        "❌ Receipt chain FAILED verification for job \(jobId): \(verificationResponse.message)"
                                    )
                                }
                            } catch {
                                jobState.receiptVerificationStatus = .failed(
                                    reason: error.localizedDescription)
                                jobState.verificationError = error.localizedDescription
                                print("❌ Error verifying receipt chain for job \(jobId): \(error)")
                            }
                        } else {
                            // No receipt provided - mark as unavailable
                            jobState.receiptVerificationStatus = .unavailable
                            print("⚠️  No receipt hash provided for terminal job \(jobId)")
                        }
                    }
                    self.activeJobs[event.jobID] = jobState
                    emitJobUpdate(jobId: event.jobID)  // Phase 8: Emit event
                    await self.publishIRUpdateForJob(surfaceId: surfaceId)
                }
            }
        } catch {
            print("Error submitting or monitoring job: \(error)")
        }
    }

    private func publishIRUpdateForJob(surfaceId: SurfaceId) async {
        guard let surfaceState = self.activeSurfaces[surfaceId],
            let originalIR = surfaceState.currentIR
        else {
            return
        }

        var jobNodes: [ViewNode] = []
        for (jobId, jobState) in activeJobs {
            let jobNode = ViewNode(
                id: "job_\(jobId)",
                type: "JobStatus",
                properties: [
                    "jobId": .string(jobId),
                    "status": .string(jobState.status),
                    "message": .string(jobState.message ?? ""),
                    "progress": .number(Double(jobState.progress) / 1000.0),

                    // Receipt verification status (zero-trust model)
                    "receiptStatus": .string(jobState.receiptVerificationStatus.description),
                    "isVerified": .bool(jobState.isVerified),
                    "isTrusted": .bool(jobState.isTrusted),
                    "verifiedAt": .string(jobState.verifiedAt?.ISO8601Format() ?? "")
                ]
            )
            jobNodes.append(jobNode)
        }

        let jobsContainer = ViewNode(id: "jobs_container", type: "Container", children: jobNodes)

        var newRoot = originalIR.root
        if let existingContainerIndex = newRoot.children.firstIndex(where: {
            $0.id == "jobs_container"
        }) {
            newRoot.children[existingContainerIndex] = jobsContainer
        } else {
            newRoot.children.append(jobsContainer)
        }

        let updatedIR = PresentationIR(root: newRoot)

        self.updateIR(updatedIR, for: surfaceId)
    }

    private func validateParameters(intent: ActionIntent, definition: ActionDefinition) throws {
        for (paramName, schema) in definition.parameters {
            guard let value = intent.parameters[paramName] else {
                if schema.required { throw DenialCode.invalidParameters }
                continue
            }

            let isValidType: Bool
            switch (schema.type, value) {
            case (.string, .string), (.number, .number), (.bool, .bool), (.array, .array),
                (.object, .object), (.any, _):
                isValidType = true
            default:
                isValidType = false
            }
            if !isValidType { throw DenialCode.invalidParameters }
        }
    }

    private func makeDenial(for intent: ActionIntent, code: DenialCode) -> ContractsCore.Receipt {
        let intentHash = calculateIntentHash(intent)
        return ContractsCore.Receipt(
            ref: ReceiptRef(id: UUID().uuidString, intentHash: intentHash),
            status: .blocked,
            outcome: .string("Blocked: \(code.rawValue)"),
            seal: .unsigned(hash: intentHash)
        )
    }

    private func calculateIntentHash(_ intent: ActionIntent) -> String {
        let intentData = (try? intent.encode()) ?? Data()
        return SHA256.hash(data: intentData).map { String(format: "%02x", $0) }.joined()
    }

    private func encodeJobConfig(_ intent: ActionIntent) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(intent.parameters)
    }

    private struct SurfaceState {
        let surfaceId: SurfaceId
        let actorId: ActorId
        var currentToken: ContractsCore.CapabilityToken
        var currentIR: PresentationIR?
        var currentSnapshotId: String?
        var currentIRHash: String?
        var activeNonces: Set<String> = []
    }

    private struct JobState {
        let jobId: String
        let intent: ActionIntent
        let workspaceId: String
        let submittedAt: Date
        var status: String
        var message: String?
        var progress: Int = 0
        var finalReceiptHash: String?
        var isTerminal: Bool = false
        var isVerified: Bool = false

        // Receipt verification policy
        var receiptVerificationStatus: ReceiptVerificationStatus = .pending
        var verifiedAt: Date?
        var verificationError: String?

        /// Zero-trust policy: Only trust outputs with verified receipts
        var isTrusted: Bool {
            isTerminal && receiptVerificationStatus == .verified
        }
    }

    /// Receipt verification status for zero-trust model.
    private enum ReceiptVerificationStatus: Equatable {
        case pending
        case verified
        case failed(reason: String)
        case unavailable  // Daemon didn't provide receipt

        var description: String {
            switch self {
            case .pending:
                return "Pending"
            case .verified:
                return "Verified"
            case .failed(let reason):
                return "Failed: \(reason)"
            case .unavailable:
                return "Unavailable"
            }
        }
    }
}

// MARK: - Phase 8: Query API (Real Truth, No Mocks)

extension AnigmaAuthority {
    /// Lists workspaces from Authority state.
    public func listWorkspaces(cursor: String?, limit: Int)
        -> AnigmaClientKit.Page<AnigmaClientKit.WorkspaceSummary> {
        let allItems = Array(workspaces.values)
            .sorted { $0.createdAt > $1.createdAt }

        let start = 0 // In a real system, cursor would define start
        let end = min(start + limit, allItems.count)
        let items = allItems[start..<end].map { AnigmaClientKit.WorkspaceSummary(id: $0.id, name: $0.name) }

        let nextCursor = end < allItems.count ? "\(end)" : nil
        return AnigmaClientKit.Page(items: Array(items), cursor: nextCursor)
    }

    /// Lists artifacts for a workspace from Authority state.
    public func listArtifacts(workspaceID: String, cursor: String?, limit: Int)
        -> AnigmaClientKit.Page<AnigmaClientKit.ArtifactSummary> {
        guard let workspace = workspaces[workspaceID] else {
            return AnigmaClientKit.Page(items: [], cursor: nil)
        }

        let allItems = workspace.artifactIds.compactMap { artifacts[$0] }
            .sorted { $0.createdAt > $1.createdAt }

        let start = 0
        let end = min(start + limit, allItems.count)
        let items = allItems[start..<end].map { AnigmaClientKit.ArtifactSummary(id: $0.id, name: $0.name) }

        let nextCursor = end < allItems.count ? "\(end)" : nil
        return AnigmaClientKit.Page(items: Array(items), cursor: nextCursor)
    }

    /// Lists jobs for a workspace from Authority state.
    public func listJobs(workspaceID: String, cursor: String?, limit: Int)
        -> AnigmaClientKit.Page<AnigmaClientKit.JobSummary> {
        // For now, return all jobs (workspaceId will be added to JobState later)
        let items = activeJobs.values
            .map { $0 }  // Convert to array
            .sorted { $0.submittedAt > $1.submittedAt }
            .prefix(limit)
            .map { job in
                AnigmaClientKit.JobSummary(
                    id: job.jobId,
                    name: "Job \(job.jobId.prefix(8))",
                    status: job.status,
                    isTrusted: job.isTrusted,
                    finalReceiptHash: job.finalReceiptHash
                )
            }

        return AnigmaClientKit.Page(items: Array(items), cursor: nil)
    }

    /// Creates a default workspace if none exist (bootstrap).
    public func ensureDefaultWorkspace() {
        if workspaces.isEmpty {
            _ = createWorkspace(name: "Default Workspace", id: "default")
        }
    }

    /// Creates a new workspace.
    public func createWorkspace(name: String, id: String = UUID().uuidString.lowercased()) -> String {
        let workspace = WorkspaceState(
            id: id,
            name: name,
            artifactIds: [],
            createdAt: Date()
        )
        workspaces[id] = workspace
        emitEvent(.workspaceCreated(workspaceId: id))
        return id
    }

    /// Updates an existing workspace.
    public func updateWorkspace(id: String, name: String) throws {
        guard var workspace = workspaces[id] else {
            throw AnigmaError.notFound("Workspace \(id) not found")
        }
        workspace.name = name
        workspaces[id] = workspace
        // We could emit a workspaceUpdated event here if needed
    }

    /// Deletes a workspace.
    public func deleteWorkspace(id: String) throws {
        guard workspaces.removeValue(forKey: id) != nil else {
            throw AnigmaError.notFound("Workspace \(id) not found")
        }
        // Also cleanup artifacts associated with this workspace
        artifacts = artifacts.filter { $0.value.workspaceId != id }
    }
}

// MARK: - Artifact Management
extension AnigmaAuthority {
    /// Uploads an artifact to a workspace.
    public func uploadArtifact(workspaceId: String, name: String, data: Data) throws -> String {
        guard var workspace = workspaces[workspaceId] else {
            throw AnigmaError.notFound("Workspace \(workspaceId) not found")
        }

        let id = UUID().uuidString.lowercased()
        let artifact = ArtifactState(
            id: id,
            name: name,
            workspaceId: workspaceId,
            data: data,
            createdAt: Date()
        )

        artifacts[id] = artifact
        workspace.artifactIds.insert(id)
        workspaces[workspaceId] = workspace

        emitEvent(.artifactCreated(artifactId: id, workspaceId: workspaceId))
        return id
    }

    /// Downloads an artifact's data.
    public func downloadArtifact(id: String) throws -> Data {
        guard let artifact = artifacts[id] else {
            throw AnigmaError.notFound("Artifact \(id) not found")
        }
        return artifact.data
    }

    /// Deletes an artifact.
    public func deleteArtifact(id: String) throws {
        guard let artifact = artifacts.removeValue(forKey: id) else {
            throw AnigmaError.notFound("Artifact \(id) not found")
        }

        if var workspace = workspaces[artifact.workspaceId] {
            workspace.artifactIds.remove(id)
            workspaces[artifact.workspaceId] = workspace
        }
    }
}

// MARK: - Phase 8: Event System (Replace Polling)

extension AnigmaAuthority {
    /// Subscribe to canonical events from Authority.
    public func subscribeToEvents() -> AsyncStream<AuthorityEvent> {
        AsyncStream { continuation in
            let id = UUID()
            eventContinuations[id] = continuation

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { await self?.removeEventContinuation(id) }
            }
        }
    }

    private func removeEventContinuation(_ id: UUID) {
        eventContinuations.removeValue(forKey: id)
    }

    private func emitEvent(_ event: AuthorityEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    /// Emit job update event after state changes.
    func emitJobUpdate(jobId: String) {
        guard let job = activeJobs[jobId] else { return }
        emitEvent(
            .jobUpdated(
                jobId: jobId,
                status: job.status,  // status is already a String
                isTrusted: job.isTrusted
            ))
    }
}

// MARK: - Phase 8: State Types

/// Workspace state owned by Authority.
struct WorkspaceState {
    let id: String
    var name: String
    var artifactIds: Set<String>
    let createdAt: Date
}

/// Artifact state owned by Authority.
struct ArtifactState {
    let id: String
    var name: String
    let workspaceId: String
    let data: Data
    let createdAt: Date
}

/// Canonical events emitted by Authority.
// MARK: - Job Management
extension AnigmaAuthority {
    /// Cancels a running job.
    public func cancelJob(jobId: String) async throws {
        guard let job = activeJobs[jobId] else {
            throw AnigmaError.notFound("Job \(jobId) not found")
        }

        if job.isTerminal {
            print("⚠️ Cannot cancel terminal job \(jobId)")
            return
        }

        let response = try await sidecarBridge.cancelJob(jobId: jobId)
        if !response.error.code.isEmpty {
            throw AnigmaError.sidecarError(response.error.message)
        }
    }

    /// Deletes a job from authority truth (only allowed for terminal jobs).
    public func deleteJob(jobId: String) throws {
        guard let job = activeJobs[jobId] else {
            throw AnigmaError.notFound("Job \(jobId) not found")
        }

        guard job.isTerminal else {
            throw AnigmaError.invalidIntent("Cannot delete non-terminal job \(jobId)")
        }

        activeJobs.removeValue(forKey: jobId)
        emitJobUpdate(jobId: jobId)
    }

    /// Retrieves a receipt's canonical JSON by its hash.
    public func getReceipt(hash: String) async throws -> String {
        let response = try await sidecarBridge.getReceipt(receiptHash: hash)
        if !response.error.code.isEmpty {
            throw AnigmaError.sidecarError(response.error.message)
        }
        return response.receiptCanonicalJson
    }

    /// Manually triggers verification of a job's receipt chain.
    public func verifyJob(jobId: String) async throws {
        guard var job = activeJobs[jobId] else {
            throw AnigmaError.notFound("Job \(jobId) not found")
        }

        guard let hash = job.finalReceiptHash, !hash.isEmpty else {
            throw AnigmaError.invalidIntent("Job \(jobId) has no final receipt hash")
        }

        let response = try await sidecarBridge.verifyChain(headReceiptHash: hash)
        if response.ok {
            job.receiptVerificationStatus = .verified
            job.isVerified = true
            job.verifiedAt = Date()
        } else {
            job.receiptVerificationStatus = .failed(reason: response.message)
            job.isVerified = false
        }

        activeJobs[jobId] = job
        emitJobUpdate(jobId: jobId)

        // Also update IR for any listening surfaces
        // For simplicity in this demo, we'll just emit the event
    }
}

/// Canonical events emitted by Authority.
public enum AuthorityEvent: Sendable {
    case jobUpdated(jobId: String, status: String, isTrusted: Bool)
    case artifactCreated(artifactId: String, workspaceId: String)
    case workspaceCreated(workspaceId: String)
    case daemonStatusChanged(isHealthy: Bool)
}
