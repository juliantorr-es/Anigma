//
//  SpineIdentity.swift
//  AnigmaPrimitives
//
//  Canonical identity hierarchy for the Anigma Observability Spine.
//

import Foundation

public struct ProjectID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct PrincipalID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct SessionID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct RunID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct EpisodeID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

/// Canonical identity stack for propagation.
public struct AnigmaSpineIdentity: Sendable, Codable, Hashable {
    public let projectID: ProjectID
    public let principalID: PrincipalID
    public let sessionID: SessionID
    public let runID: RunID
    public let episodeID: EpisodeID?
    
    public init(
        projectID: ProjectID,
        principalID: PrincipalID,
        sessionID: SessionID,
        runID: RunID,
        episodeID: EpisodeID? = nil
    ) {
        self.projectID = projectID
        self.principalID = principalID
        self.sessionID = sessionID
        self.runID = runID
        self.episodeID = episodeID
    }
}

/// Implicit context propagation via TaskLocal.
public enum CorrelationIDContext {
    @TaskLocal public static var current: AnigmaSpineIdentity?
    
    public static func withContext<T>(_ identity: AnigmaSpineIdentity, operation: () async throws -> T) async rethrows -> T {
        try await $current.withValue(identity) {
            try await operation()
        }
    }
    
    /// Required identity for any governed operation.
    public static var required: AnigmaSpineIdentity {
        get throws {
            guard let current = current else {
                throw SpineIdentityError.missingContext
            }
            return current
        }
    }
}

public enum SpineIdentityError: Error, LocalizedError {
    case missingContext
    
    public var errorDescription: String? {
        switch self {
        case .missingContext:
            return "Operation failed: No AnigmaSpineIdentity found in TaskLocal context."
        }
    }
}
