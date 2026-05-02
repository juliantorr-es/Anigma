//
//  MacAnigmaClient.swift
//  AnigmaHostMac
//
//  Concrete implementation of AnigmaClient for macOS.
//

import AnigmaClientKit
import AnigmaHostKit
import Combine
import ContractsCore
import Foundation

/// Concrete implementation of AnigmaClient that communicates with AnigmaAuthority.
/// Concrete implementation of AnigmaClient that communicates with AnigmaAuthority.
public final class MacAnigmaClient: AnigmaClient, @unchecked Sendable {
    public let query: QueryAPI
    public let command: CommandAPI
    public let events: EventsAPI

    private let authority: AnigmaAuthority
    private let surfaceId: SurfaceId
    private let actorId: ActorId
    private var capabilityToken: ContractsCore.CapabilityToken

    public init(
        authority: AnigmaAuthority,
        surfaceId: SurfaceId,
        actorId: ActorId,
        capabilityToken: ContractsCore.CapabilityToken
    ) {
        self.authority = authority
        self.surfaceId = surfaceId
        self.actorId = actorId
        self.capabilityToken = capabilityToken

        self.query = MacQueryAPI(authority: authority, surfaceId: surfaceId)
        self.command = MacCommandAPI(
            authority: authority,
            surfaceId: surfaceId,
            actorId: actorId,
            capabilityToken: capabilityToken
        )
        self.events = MacEventsAPI(authority: authority, surfaceId: surfaceId)
    }

    /// Submits an intent to the authority.
    public func submitIntent(
        action: String,
        parameters: [String: BindingValue] = [:]
    ) async -> CoreReceipt {
        let intent = ActionIntent(
            header: ActionIntent.Header(
                surfaceId: surfaceId,
                actorId: actorId,
                capabilityToken: capabilityToken.id,
                irSnapshotId: ""
            ),
            action: ActionRef(rawValue: action, family: "core"),
            parameters: parameters
        )

        let receipt = await authority.validateAndRouteIntent(intent)
        return CoreReceipt(rawValue: String(describing: receipt))
    }
}

// MARK: - Query API Implementation

// MARK: - Query API Implementation

final class MacQueryAPI: QueryAPI {
    private let authority: AnigmaAuthority
    private let surfaceId: SurfaceId

    init(authority: AnigmaAuthority, surfaceId: SurfaceId) {
        self.authority = authority
        self.surfaceId = surfaceId
    }

    func listWorkspaces(cursor: String?, limit: Int) async throws -> Page<WorkspaceSummary> {
        // Phase 8: Read from Authority state (real truth, no mocks)
        return await authority.listWorkspaces(cursor: cursor, limit: limit)
    }

    func listArtifacts(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<
        ArtifactSummary
    > {
        // Phase 8: Read from Authority state
        return await authority.listArtifacts(workspaceID: workspaceID, cursor: cursor, limit: limit)
    }

    func listJobs(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<
        JobSummary
    > {
        // Phase 8: Read from Authority state
        return await authority.listJobs(workspaceID: workspaceID, cursor: cursor, limit: limit)
    }

    func downloadArtifact(id: ArtifactID) async throws -> Data {
        return try await authority.downloadArtifact(id: id)
    }

    func getReceipt(hash: String) async throws -> CoreReceipt {
        let json = try await authority.getReceipt(hash: hash)
        return CoreReceipt(rawValue: json)
    }

    func evaluateAction(intent: ActionIntent) async throws -> IntentEvaluation {
        return await authority.evaluateIntent(intent)
    }
}

// MARK: - Command API Implementation

// MARK: - Command API Implementation

final class MacCommandAPI: CommandAPI {
    private let authority: AnigmaAuthority
    private let surfaceId: SurfaceId
    private let actorId: ActorId
    private let capabilityToken: ContractsCore.CapabilityToken

    init(
        authority: AnigmaAuthority,
        surfaceId: SurfaceId,
        actorId: ActorId,
        capabilityToken: ContractsCore.CapabilityToken
    ) {
        self.authority = authority
        self.surfaceId = surfaceId
        self.actorId = actorId
        self.capabilityToken = capabilityToken
    }

    public func createWorkspace(name: String) async throws -> WorkspaceID {
        return await authority.createWorkspace(name: name)
    }

    public func updateWorkspace(id: WorkspaceID, name: String) async throws {
        try await authority.updateWorkspace(id: id, name: name)
    }

    public func deleteWorkspace(id: WorkspaceID) async throws {
        try await authority.deleteWorkspace(id: id)
    }

    public func uploadArtifact(workspaceId: WorkspaceID, name: String, data: Data) async throws
        -> ArtifactID {
        return try await authority.uploadArtifact(workspaceId: workspaceId, name: name, data: data)
    }

    public func deleteArtifact(id: ArtifactID) async throws {
        try await authority.deleteArtifact(id: id)
    }

    public func cancelJob(id: JobID) async throws {
        try await authority.cancelJob(jobId: id)
    }

    public func deleteJob(id: JobID) async throws {
        try await authority.deleteJob(jobId: id)
    }

    public func verifyJob(id: JobID) async throws {
        try await authority.verifyJob(jobId: id)
    }

    public func evaluateAction(action: String, parameters: [String: BindingValue]) async throws
        -> IntentEvaluation {
        let intent = try makeIntent(action: action, parameters: parameters)
        return await authority.evaluateIntent(intent)
    }
    private func makeIntent(action: String, parameters: [String: BindingValue]) throws
        -> ActionIntent {
        let header = ActionIntent.Header(
            surfaceId: surfaceId,
            actorId: actorId,
            capabilityToken: capabilityToken.id,
            irSnapshotId: ""
        )
        return ActionIntent(
            header: header,
            action: ActionRef(rawValue: action, family: "core"),
            parameters: parameters
        )
    }
}

// MARK: - Events API Implementation

// MARK: - Events API Implementation

final class MacEventsAPI: EventsAPI {
    private let authority: AnigmaAuthority
    private let surfaceId: SurfaceId

    init(authority: AnigmaAuthority, surfaceId: SurfaceId) {
        self.authority = authority
        self.surfaceId = surfaceId
    }

    func events() -> AsyncThrowingStream<AnigmaEvent, Error> {
        // Phase 8: Subscribe to canonical Authority events
        AsyncThrowingStream { continuation in
            Task { @Sendable in
                for await _ in await authority.subscribeToEvents() {
                    // Map AuthorityEvent to AnigmaEvent
                    // For now, AnigmaEvent is a placeholder, so we just yield it
                    continuation.yield(AnigmaEvent())
                }
                continuation.finish()
            }
        }
    }
}
