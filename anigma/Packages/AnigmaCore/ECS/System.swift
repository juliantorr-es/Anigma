//
//  System.swift
//  AnigmaCore
//
//  Protocol for ECS systems that process entities with specific components.
//  Systems contain the logic; components contain the data.
//
//  This implementation consolidates patterns from:
//  - Harmonia: OrchestrumCore/ECS/World.swift (simple `System` protocol with update)
//  - Apertum Accesum: ECSContracts.swift (rich `System: Actor` with dependencies, read/write sets)
//
//  We provide:
//  - A minimal synchronous `System` protocol (Harmonia-style)
//  - An async `AsyncSystem` actor protocol (Apertum-style)
//  - Both can be registered with World; the runner adapts accordingly.
//
//  Migration notes:
//  - Harmonia systems already conform to the minimal protocol.
//  - Apertum Accesum systems should migrate to `AsyncSystem`.
//

import Foundation

// MARK: - Minimal System Protocol

/// Minimal protocol for ECS systems.
/// Systems are stateless processors that operate on entities with specific components.
///
/// ## Example
/// ```swift
/// struct MovementSystem: System {
///     var name: String { "Movement" }
///
///     func update(world: World) async {
///         for (entity, position, velocity) in await world.query(PositionComponent.self, VelocityComponent.self) {
///             var newPos = position
///             newPos.x += velocity.dx
///             newPos.y += velocity.dy
///             await world.addComponent(entity, newPos)
///         }
///     }
/// }
/// ```
public protocol System: Sendable {
    /// Human-readable name for logging and debugging.
    var name: String { get }

    /// Process all relevant entities in the world.
    /// Called once per update cycle.
    func update(world: World) async
}

// MARK: - Rich Async System Protocol

/// Full-featured system protocol using Swift actors.
/// Provides dependency ordering, read/write component sets, and lifecycle hooks.
///
/// Use this for complex systems that need:
/// - Explicit dependency ordering
/// - Setup/teardown lifecycle
/// - Component access declarations for optimization
///
/// ## Example
/// ```swift
/// actor OcrSystem: AsyncSystem {
///     nonisolated var name: String { "OCR" }
///     nonisolated var dependencies: [String] { ["Import"] }
///     nonisolated var readComponents: [any Component.Type] { [FileComponent.self] }
///     nonisolated var writeComponents: [any Component.Type] { [OcrResultComponent.self] }
///
///     func update(world: World) async throws {
///         // Process documents needing OCR
///     }
/// }
/// ```
public protocol AsyncSystem: Actor {
    /// Human-readable name for logging and debugging.
    /// Must be nonisolated for access from non-async contexts.
    nonisolated var name: String { get }

    /// Names of other systems this one depends on.
    /// This system will run after all dependencies have completed.
    nonisolated var dependencies: [String] { get }

    /// Component types this system reads from (for query optimization).
    nonisolated var readComponents: [any Component.Type] { get }

    /// Component types this system writes to (for conflict detection).
    nonisolated var writeComponents: [any Component.Type] { get }

    /// Called once when the system is registered with the world.
    func setup(world: World) async throws

    /// Called each update cycle to process entities.
    func update(world: World) async throws

    /// Called when the system is removed or the world is shutting down.
    func teardown(world: World) async throws
}

// MARK: - AsyncSystem Defaults

public extension AsyncSystem {
    nonisolated var dependencies: [String] { [] }
    nonisolated var readComponents: [any Component.Type] { [] }
    nonisolated var writeComponents: [any Component.Type] { [] }

    func setup(world: World) async throws {}
    func teardown(world: World) async throws {    }
}

// MARK: - System Phase

/// Phase of system execution for dependency ordering.
public enum SystemPhase: String, Sendable, Codable {
    /// Pre‑processing phase (setup, validation).
    case preProcessing

    /// Main processing phase (transformation, generation).
    case processing

    /// Post‑processing phase (cleanup, export).
    case postProcessing
}

// MARK: - System Context

/// Context passed to systems during execution.
/// Provides access to timing, configuration, and other runtime info.
public struct SystemContext: Sendable {
    /// Delta time since last update (in seconds).
    public let deltaTime: TimeInterval

    /// Total elapsed time since world start (in seconds).
    public let totalTime: TimeInterval

    /// Current update tick number.
    public let tick: UInt64

    /// Whether this is the first update after world creation.
    public let isFirstUpdate: Bool

    public init(
        deltaTime: TimeInterval = 0,
        totalTime: TimeInterval = 0,
        tick: UInt64 = 0,
        isFirstUpdate: Bool = false
    ) {
        self.deltaTime = deltaTime
        self.totalTime = totalTime
        self.tick = tick
        self.isFirstUpdate = isFirstUpdate
    }
}

// MARK: - System Wrapper

/// Type-erased wrapper for any system.
/// Used internally by World to store heterogeneous system collections.
struct AnySystem: Sendable {
    let name: String
    private let _update: @Sendable (World) async throws -> Void
    private let _setup: (@Sendable (World) async throws -> Void)?
    private let _teardown: (@Sendable (World) async throws -> Void)?

    /// Wraps a minimal System.
    init(_ system: any System) {
        self.name = system.name
        self._update = { world in await system.update(world: world) }
        self._setup = nil
        self._teardown = nil
    }

    /// Wraps an AsyncSystem.
    init(_ system: any AsyncSystem) {
        self.name = system.name
        self._update = { world in try await system.update(world: world) }
        self._setup = { world in try await system.setup(world: world) }
        self._teardown = { world in try await system.teardown(world: world) }
    }

    func setup(world: World) async throws {
        try await _setup?(world)
    }

    func update(world: World) async throws {
        try await _update(world)
    }

    func teardown(world: World) async throws {
        try await _teardown?(world)
    }
}
