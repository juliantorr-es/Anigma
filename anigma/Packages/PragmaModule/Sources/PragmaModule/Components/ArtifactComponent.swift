import AnigmaPrimitives

import AnigmaPrimitives

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
    public var identifiableId: UUID { id.raw }

    /// Attempt that produced the artifact.
    public let attemptId: AttemptId

    /// Artifact kind.
    public let kind: ArtifactKind

    /// URI to the artifact content.
    public let uri: String

    /// SHA256 hash of the artifact content.
    public let contentHash: String

    /// Optional summary for display.
    public let summary: String?

    /// When the artifact was recorded.
    public let createdAt: Date

    public init(
        id: ArtifactId = ArtifactId(),
        attemptId: AttemptId,
        kind: ArtifactKind,
        uri: String,
        contentHash: String,
        summary: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.attemptId = attemptId
        self.kind = kind
        self.uri = uri
        self.contentHash = contentHash
        self.summary = summary
        self.createdAt = createdAt
    }
}
