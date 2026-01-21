//
//  ExecutorProfileProviding.swift
//  ContractsCore
//
//  Executor profile surface protocol.
//

import AnigmaPrimitives
import Foundation

/// Surface protocol for executor profile resolution.
public protocol ExecutorProfileProviding: Sendable {
    /// List profiles visible at the given trust tier.
    func listProfiles(trustTier: TrustTier) async throws -> [ExecutorProfileSummary]

    /// Fetch a profile by id.
    func getProfile(id: String, trustTier: TrustTier) async throws -> ExecutorProfile

    /// Resolve a profile with optional overrides.
    func resolveProfile(
        id: String,
        variantId: String?,
        taskOverrides: ExecutorProfileOverrides?,
        attemptOverrides: ExecutorProfileOverrides?,
        trustTier: TrustTier
    ) async throws -> ResolvedExecutorProfile

    /// Check if a profile can be used at the given trust tier.
    func canUseProfile(id: String, trustTier: TrustTier) async throws -> Bool
}
