//
//  WorkBoardProviding.swift
//  PragmaModule
//
//  Work board surface protocol.
//

import AnigmaPrimitives
import Foundation

/// Surface protocol for work board snapshots and intents.
/// Conforming types must be actors to ensure thread-safe access.
public protocol WorkBoardProviding: Actor {
    /// Returns a snapshot for the given scope.
    func boardSnapshot(scope: WorkBoardScope, trustTier: TrustTier) async throws
        -> WorkBoardSnapshot

    /// Streams snapshots for the given scope.
    func boardStream(scope: WorkBoardScope, trustTier: TrustTier) -> AsyncThrowingStream<
        WorkBoardSnapshot, Error
    >

    /// Submits a work board intent.
    func submitIntent(_ intent: WorkBoardIntent) async throws -> WorkBoardIntentResult

    /// Checks whether an intent may be submitted.
    func canSubmitIntent(_ intent: WorkBoardIntent) async throws -> Bool
}
