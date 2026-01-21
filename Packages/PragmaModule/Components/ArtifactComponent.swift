//
//  ArtifactComponent.swift
//  PragmaModule
//
//  Component representing an artifact produced by an attempt.
//

import Foundation
import AnigmaCore

/// Component representing a artifact representing an artifact produced by an attempt.
public struct ArtifactComponent: Component, Codable, Identifiable, Sendable {
    /// Unique artifact identifier.
    public let id: ArtifactId

    /// Attempt that produced the artifact.
    public let attemptId: AttemptId

    /// Artifact kind.
    public let kind: ArtifactKind

    /// URI to the artifact content.
    public let uri: String

    /// SHA256 hash of the artifact content.
    public let sha256: String

    /// Optional summary for display.
    public let summary: String?

    /// When the artifact was recorded.
    public let createdAt: Date

    public init(
        id: ArtifactId = ArtifactId(),
        attemptId: AttemptId,
        kind: ArtifactKind,
        uri: String,
        sha256: String,
        summary: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.attemptId = attemptId
        self.kind = kind
        self.uri = uri
        self.sha256 = sha256
        self.summary = summary
        self.createdAt = createdAt
    }
}
