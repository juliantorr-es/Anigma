//
//  SessionListingProviding.swift
//  HarmoniaModule
//
//  Capability module contract for session listing functionality.
//  Provides governed, trust-verified session access with both async and streaming interfaces.
//  Follows two-tier architecture: Core Governance + Capability Modules.
//

@preconcurrency import Foundation
import AnigmaCore
@preconcurrency import GRDB

// MARK: - Session Listing Surface Protocol

/// Capability module contract for session listing functionality.
/// Provides governed, trust-verified session access with both async and streaming interfaces.
/// 
/// This protocol defines the surface that capability modules must implement to provide
/// session listing services while maintaining Core Governance Layer requirements.
/// 
/// ## Architecture Notes
/// - Implementations should be actors for Swift6 concurrency safety
/// - Must evaluate governance access before touching any data stores
/// - Should use ECS queries for candidate session assembly
/// - Must provide trust verification for all yielded sessions
/// - Streaming interface uses AsyncThrowingStream for first-class error handling
public protocol SessionListingProviding: Sendable {
    /// Lists recent sessions for a project with governance and trust verification.
    /// - Parameters:
    ///   - projectId: Project identifier to list sessions for
    ///   - limit: Maximum number of sessions to return
    ///   - trustTier: Trust tier for access evaluation (default: .trusted)
    /// - Returns: Array of verified session reports
    /// - Throws: GovernanceError if access denied, TrustError if verification fails
    func listRecentSessions(
        projectId: UUID,
        limit: Int,
        trustTier: SessionTrustTier
    ) async throws -> [SessionReport]

    /// Streams recent sessions with real-time governance and trust verification.
    /// - Parameters:
    ///   - projectId: Project identifier to stream sessions for
    ///   - limit: Maximum number of sessions to stream
    ///   - trustTier: Trust tier for access evaluation (default: .trusted)
    /// - Returns: AsyncThrowingStream that yields verified sessions or throws governance/trust errors
    /// - Throws: GovernanceError immediately if access denied, TrustError during stream if verification fails
    func recentSessionsStream(
        projectId: UUID,
        limit: Int,
        trustTier: SessionTrustTier
    ) -> AsyncThrowingStream<SessionReport, any Error>

    /// Checks if the caller has permission to list sessions for the given project.
    /// - Parameters:
    ///   - projectId: Project identifier to check access for
    ///   - trustTier: Trust tier for access evaluation
    /// - Returns: True if access is allowed, false otherwise
    /// - Throws: GovernanceError if access evaluation fails
    func canListSessions(
        projectId: UUID,
        trustTier: SessionTrustTier
    ) async throws -> Bool
}

// MARK: - Convenience Extensions

public extension SessionListingProviding {
    /// Lists recent sessions with default trust tier (.trusted).
    func listRecentSessions(
        projectId: UUID,
        limit: Int
    ) async throws -> [SessionReport] {
        try await listRecentSessions(
            projectId: projectId,
            limit: limit,
            trustTier: .trusted
        )
    }

    /// Streams recent sessions with default trust tier (.trusted).
    func recentSessionsStream(
        projectId: UUID,
        limit: Int
    ) -> AsyncThrowingStream<SessionReport, any Error> {
        recentSessionsStream(
            projectId: projectId,
            limit: limit,
            trustTier: .trusted
        )
    }

    /// Checks access with default trust tier (.trusted).
    func canListSessions(projectId: UUID) async throws -> Bool {
        try await canListSessions(
            projectId: projectId,
            trustTier: .trusted
        )
    }
}

// MARK: - Governance Access Types

/// Memory access request for session listing operations.
/// Used by governance layers to evaluate read access permissions.
public struct SessionListingAccessRequest: Sendable {
    public let projectId: UUID
    public let operation: SessionListingOperation
    public let trustTier: SessionTrustTier
    public let requestedLimit: Int
    public let timestamp: Date

    public init(
        projectId: UUID,
        operation: SessionListingOperation,
        trustTier: SessionTrustTier,
        requestedLimit: Int
    ) {
        self.projectId = projectId
        self.operation = operation
        self.trustTier = trustTier
        self.requestedLimit = requestedLimit
        self.timestamp = Date()
    }
}

/// Operations supported by session listing.
public enum SessionListingOperation: String, Sendable, Codable {
    case list = "list"
    case stream = "stream"
    case checkAccess = "check_access"
}

/// Errors specific to session listing operations.
public enum SessionListingError: Error, Sendable, LocalizedError {
    case accessDenied(reason: String)
    case trustVerificationFailed(sessionId: String, reason: String)
    case governanceViolation(code: String, message: String)
    case quotaExceeded(requested: Int, allowed: Int)
    case invalidProject(projectId: UUID)
    case serviceUnavailable(reason: String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied(let reason):
            return "Access denied: \(reason)"
        case .trustVerificationFailed(let sessionId, let reason):
            return "Trust verification failed for session \(sessionId): \(reason)"
        case .governanceViolation(let code, let message):
            return "Governance violation (\(code)): \(message)"
        case .quotaExceeded(let requested, let allowed):
            return "Quota exceeded: requested \(requested), allowed \(allowed)"
        case .invalidProject(let projectId):
            return "Invalid project: \(projectId.uuidString)"
        case .serviceUnavailable(let reason):
            return "Service unavailable: \(reason)"
        }
    }
}

// MARK: - Session Trust Verification

/// Trust verification result for a session.
public struct SessionTrustResult: Sendable {
    public let sessionId: String
    public let isTrusted: Bool
    public let verificationTime: Date
    public let trustScore: Double
    public let reasons: [String]

    public init(
        sessionId: String,
        isTrusted: Bool,
        verificationTime: Date = Date(),
        trustScore: Double = 0.0,
        reasons: [String] = []
    ) {
        self.sessionId = sessionId
        self.isTrusted = isTrusted
        self.verificationTime = verificationTime
        self.trustScore = trustScore
        self.reasons = reasons
    }
}

/// Protocol for trust verification of sessions.
/// Implementations should integrate with Core Governance Layer trust stores.
public protocol SessionTrustVerifier: Sendable {
    /// Verifies the trust status of a session.
    /// - Parameter sessionId: Session identifier to verify
    /// - Returns: Trust verification result
    /// - Throws: TrustError if verification process fails
    func verifySession(sessionId: String) async throws -> SessionTrustResult

    /// Batch verifies multiple sessions.
    /// - Parameter sessionIds: Array of session identifiers to verify
    /// - Returns: Array of trust verification results
    /// - Throws: TrustError if batch verification fails
    func verifySessions(sessionIds: [String]) async throws -> [SessionTrustResult]
}
