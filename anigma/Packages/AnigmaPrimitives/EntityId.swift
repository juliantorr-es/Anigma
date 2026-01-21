//
//  EntityId.swift
//  AnigmaPrimitives
//
//  Unique identifier for entities in the ECS world.
//  Canonical primitive for entity identification.
//

import Foundation

/// Lightweight, unique identifier for an entity in the ECS world.
/// Entities are just IDs - all data lives in components attached to them.
///
/// ## Usage
/// ```swift
/// let entity = EntityId()              // New random ID
/// let entity2 = EntityId(raw: someUUID) // From existing UUID
/// let entity3 = EntityId(uuidString: "...")  // From string
/// ```
public struct EntityId: Hashable, Codable, Sendable, CustomStringConvertible {
    /// The underlying UUID value.
    public let raw: UUID

    /// Creates a new entity ID with a fresh UUID.
    public init() {
        self.raw = UUID()
    }

    /// Creates an entity ID from an existing UUID.
    public init(raw: UUID) {
        self.raw = raw
    }

    /// Creates an entity ID from a UUID string.
    /// Returns nil if the string is not a valid UUID.
    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.raw = uuid
    }

    /// Short description for debugging (shows first 8 characters of UUID).
    public var description: String {
        "Entity(\(raw.uuidString.prefix(8)))"
    }
}

// MARK: - Source compatibility helpers

extension EntityId {
    @available(*, deprecated, message: "Use EntityId(raw:) or EntityId(uuidString:)/string literal init.")
    public init(rawValue: Int) {
        self.init(stringLiteral: "\(rawValue)")
    }

    @available(*, deprecated, message: "Use EntityId(raw:) or EntityId(uuidString:)/string literal init.")
    public init(rawValue: UUID) {
        self.init(raw: rawValue)
    }
}

// MARK: - Identifiable Conformance

extension EntityId: Identifiable {
    public var id: UUID { raw }
}

// MARK: - ExpressibleByStringLiteral (for testing convenience)

extension EntityId: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        if let uuid = UUID(uuidString: value) {
            self.raw = uuid
        } else {
            // For non-UUID strings, create a deterministic UUID from the string
            // This is useful for tests: EntityId("test-entity-1")
            let data = Data(value.utf8)
            var bytes = [UInt8](repeating: 0, count: 16)
            for (i, byte) in data.prefix(16).enumerated() {
                bytes[i] = byte
            }
            self.raw = UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
    }
}

// MARK: - Compatibility Typealiases

/// Alias for compatibility with Apertum Accesum's naming convention.
/// Migrate: Replace `EntityID` with `EntityId` in Apertum Accesum code.
public typealias EntityID = EntityId
