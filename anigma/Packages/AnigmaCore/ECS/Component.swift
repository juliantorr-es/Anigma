//
//  Component.swift
//  AnigmaCore
//
//  Base protocol for all ECS components.
//  Components are pure data containers attached to entities.
//
//  This implementation consolidates patterns from:
//  - Harmonia: OrchestrumCore/ECS/World.swift (minimal `Component: Sendable`)
//  - Apertum Accesum: ECSContracts.swift (rich `Component` with entityID, version, etc.)
//
//  We take a middle-ground approach:
//  - Core protocol is minimal (just Sendable marker)
//  - Extended protocols add optional features (versioning, persistence, etc.)
//
//  Migration notes:
//  - Harmonia components already conform; no changes needed.
//  - Apertum Accesum components need to drop entityID storage (World manages that).
//

import Foundation

// MARK: - Core Component Protocol

/// Base protocol for all ECS components.
/// Components are pure data containers with no business logic.
/// They should be value types (structs) for copy-on-write semantics.
///
/// ## Minimal Example
/// ```swift
/// struct NameComponent: Component {
///     let name: String
/// }
/// ```
///
/// ## With Metadata
/// ```swift
/// struct DocumentComponent: VersionedComponent {
///     let title: String
///     let content: String
///     var version: Int = 1
///     var modifiedAt: Date = Date()
/// }
/// ```
public protocol Component: Sendable {}

// MARK: - Extended Component Protocols

/// Component that tracks a type identifier for serialization and storage.
/// Use this when components need to be persisted or transmitted.
public protocol TypedComponent: Component {
    /// Unique identifier for this component type (e.g., "document", "file").
    /// Used for storage keys and serialization.
    static var componentType: String { get }
}

extension TypedComponent {
    /// Default implementation: derives type name from the struct name.
    /// `DocumentComponent` → `"document"`
    public static var componentType: String {
        String(describing: Self.self)
            .replacingOccurrences(of: "Component", with: "")
            .lowercased()
    }
}

/// Component with optimistic locking version and modification timestamp.
/// Use this for components that need conflict detection or audit trails.
public protocol VersionedComponent: Component {
    /// Optimistic locking version - increment on each update.
    var version: Int { get }

    /// Timestamp of last modification.
    var modifiedAt: Date { get }
}

/// Component that is Codable for persistence and serialization.
/// Most components should conform to this for GRDB/JSON storage.
public protocol CodableComponent: Component, Codable {}

/// Full-featured component with type info, versioning, and Codable support.
/// Use this as the "kitchen sink" protocol for complex domain components.
public protocol PersistableComponent: TypedComponent, VersionedComponent, CodableComponent, Identifiable {
    /// Unique identifier for this component instance.
    var id: UUID { get }
}

// MARK: - Type Erasure

/// Type-erased wrapper for any component.
/// Useful for heterogeneous storage or event systems.
public struct AnyComponent: Sendable {
    /// The type name of the wrapped component.
    public let typeName: String

    /// The wrapped component (type-erased).
    private let _component: any Component

    /// Creates an AnyComponent wrapper.
    public init<C: Component>(_ component: C) {
        self.typeName = String(describing: C.self)
        self._component = component
    }

    /// Attempts to cast the wrapped component to a specific type.
    public func `as`<C: Component>(_ type: C.Type) -> C? {
        _component as? C
    }
}

// MARK: - Component Defaults for TypedComponent

/// Utility for generating component type names.
public enum ComponentTypeNaming {
    /// Derives a type name from a Swift type.
    /// `DocumentComponent` → `"document"`
    /// `FileRefComponent` → `"fileref"`
    public static func typeName<T>(for type: T.Type) -> String {
        String(describing: type)
            .replacingOccurrences(of: "Component", with: "")
            .lowercased()
    }
}
