//
//  MemoryComponent.swift
//  AnigmaCore
//
//  ECS Component for storing governed, cross-session memories.
//

import Foundation
import AnigmaPrimitives

/// Component that stores a "fact" or "memory" about an entity (e.g., User, Project).
public struct MemoryComponent: SensitiveComponent, Codable, Sendable {
    public static var sensitivity: DataSensitivity { .confidential }

    /// The unique identifier for this memory.
    public let id: UUID

    /// The actual content of the memory.
    public let fact: String

    /// The source of this memory (e.g., "user_input", "inference_extraction").
    public let source: String

    /// Confidence score (0.0 to 1.0) if extracted via AI.
    public let confidence: Double

    /// When this memory was created.
    public let createdAt: Date

    /// When this memory should expire (governance-driven).
    public let expiresAt: Date?

    /// Keywords for indexing and retrieval.
    public let tags: Set<String>

    public init(
        fact: String,
        source: String,
        confidence: Double = 1.0,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        tags: Set<String> = []
    ) {
        self.id = UUID()
        self.fact = fact
        self.source = source
        self.confidence = confidence
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.tags = tags
    }
}
