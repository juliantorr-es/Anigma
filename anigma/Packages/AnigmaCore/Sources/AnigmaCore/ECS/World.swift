//
//  World.swift
//  AnigmaCore
//
//  The ECS world container that manages entities, components, and systems.
//
//  This implementation consolidates patterns from:
//  - Harmonia: OrchestrumCore/ECS/World.swift (actor-based, UInt64 entities)
//  - Apertum Accesum: ECSContracts.swift (WorldProtocol with persistence hooks)
//
//  Key design decisions:
//  - Actor-based for thread safety (from both implementations)
//  - UUID-based EntityId (from Apertum Accesum, better for persistence)
//  - Observer pattern for reactive updates (from both)
//  - Multi-arity query methods for component joins (from both)
//  - Separation of concerns: persistence is handled by external stores
//
//  Migration notes:
//  - Harmonia: Replace `OrchestrumCore.World` imports with `AnigmaCore.World`
//  - Apertum Accesum: Implement `World` actor conforming to their `WorldProtocol`
//

import Foundation
import AnigmaPrimitives

/// The core ECS World that stores entities and components.

// MARK: - Component Storage

/// Type-erased component storage interface.
protocol AnyComponentStorage: Sendable {
    func hasComponent(for entity: EntityId) -> Bool
    mutating func removeComponent(for entity: EntityId)
    func entityIds() -> [EntityId]
}

/// Concrete storage for a specific component type.
/// Uses dictionary-based storage with O(1) lookup.
struct ComponentStorage<C: Component>: AnyComponentStorage, Sendable {
    private var components: [EntityId: C] = [:]

    func get(_ entity: EntityId) -> C? {
        components[entity]
    }

    mutating func set(_ entity: EntityId, _ component: C) {
        components[entity] = component
    }

    mutating func remove(_ entity: EntityId) {
        components[entity] = nil
    }

    func hasComponent(for entity: EntityId) -> Bool {
        components[entity] != nil
    }

    mutating func removeComponent(for entity: EntityId) {
        remove(entity)
    }

    func entityIds() -> [EntityId] {
        Array(components.keys)
    }

    func all() -> [(EntityId, C)] {
        components.map { ($0.key, $0.value) }
    }

    var count: Int { components.count }
}

// MARK: - World Observer

/// Observer protocol for world state changes.
/// Implement this to react to entity/component lifecycle events.
public protocol WorldObserver: AnyObject, Sendable {
    func entityCreated(_ entity: EntityId) async
    func entityDestroyed(_ entity: EntityId) async
    func componentAdded<C: Component>(_ entity: EntityId, component: C) async
    func componentRemoved<C: Component>(_ entity: EntityId, componentType: C.Type) async
    func systemRegistered(name: String) async
    func systemUnregistered(name: String) async
    func updateCycleCompleted(duration: TimeInterval) async
}

/// Default implementations make all observer methods optional.
public extension WorldObserver {
    func entityCreated(_ entity: EntityId) async {}
    func entityDestroyed(_ entity: EntityId) async {}
    func componentAdded<C: Component>(_ entity: EntityId, component: C) async {}
    func componentRemoved<C: Component>(_ entity: EntityId, componentType: C.Type) async {}
    func systemRegistered(name: String) async {}
    func systemUnregistered(name: String) async {}
    func updateCycleCompleted(duration: TimeInterval) async {}
}

// MARK: - World Events

/// Events emitted by the World for observers.
/// Use these for event-driven architectures or logging.
public enum WorldEvent: Sendable {
    case entityCreated(EntityId)
    case entityDestroyed(EntityId)
    case componentAdded(entityId: EntityId, componentType: String)
    case componentUpdated(entityId: EntityId, componentType: String)
    case componentRemoved(entityId: EntityId, componentType: String)
    case systemRegistered(name: String)
    case systemUnregistered(name: String)
    case updateCycleCompleted(duration: TimeInterval)
}

// MARK: - World

/// The ECS world container.
/// Manages entities, components, and systems with thread-safe actor isolation.
///
/// ## Basic Usage
/// ```swift
/// let world = World()
///
/// // Create entity and add components
/// let entity = await world.createEntity()
/// await world.addComponent(entity, NameComponent(name: "Player"))
/// await world.addComponent(entity, PositionComponent(x: 0, y: 0))
///
/// // Register systems
/// await world.registerSystem(MovementSystem())
///
/// // Run update loop
/// await world.update()
/// ```
///
/// ## Queries
/// ```swift
/// // Single component query
/// for (entity, name) in await world.query(NameComponent.self) {
///     print("\(entity): \(name.name)")
/// }
///
/// // Multi-component query
/// for (entity, pos, vel) in await world.query(PositionComponent.self, VelocityComponent.self) {
///     // Process entities with both components
/// }
/// ```
public actor World {
    // MARK: - State

    private var entities: Set<EntityId> = []
    private var componentStorages: [ObjectIdentifier: any AnyComponentStorage] = [:]
    private var systems: [AnySystem] = []
    private var observers: [ObjectIdentifier: WeakObserver] = [:]
    private var metadata: [String: Any] = [:]

    // Timing state for SystemContext
    private var tick: UInt64 = 0
    private var startTime = Date()
    private var lastUpdateTime = Date()

    /// Wrapper for weak observer references to avoid retain cycles.
    private struct WeakObserver: Sendable {
        weak var observer: (any WorldObserver)?
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Entity Management

    /// Creates a new entity with a fresh UUID.
    public func createEntity() -> EntityId {
        let entity = EntityId()
        entities.insert(entity)

        Task { [weak self] in
            await self?.notifyEntityCreated(entity)
        }

        return entity
    }

    /// Creates an entity with a predetermined ID (for persistence/sync).
    @discardableResult
    public func createEntity(with id: EntityId) -> EntityId {
        entities.insert(id)

        Task { [weak self] in
            await self?.notifyEntityCreated(id)
        }

        return id
    }

    /// Destroys an entity and removes all its components.
    public func destroyEntity(_ entity: EntityId) {
        guard entities.remove(entity) != nil else { return }

        // Remove from all component storages
        for key in componentStorages.keys {
            componentStorages[key]?.removeComponent(for: entity)
        }

        Task { [weak self] in
            await self?.notifyEntityDestroyed(entity)
        }
    }

    /// Checks if an entity exists in the world.
    public func entityExists(_ entity: EntityId) -> Bool {
        entities.contains(entity)
    }

    /// Returns all entity IDs currently in the world.
    public func allEntities() -> [EntityId] {
        Array(entities)
    }

    /// Returns the count of entities in the world.
    public func entityCount() -> Int {
        entities.count
    }

    // MARK: - Component Management

    /// Adds a component to an entity. Replaces existing component of same type.
    public func addComponent<C: Component>(_ entity: EntityId, _ component: C) {
        guard entities.contains(entity) else { return }

        let key = ObjectIdentifier(C.self)

        if var storage = componentStorages[key] as? ComponentStorage<C> {
            storage.set(entity, component)
            componentStorages[key] = storage
        } else {
            var storage = ComponentStorage<C>()
            storage.set(entity, component)
            componentStorages[key] = storage
        }

        Task { [weak self] in
            await self?.notifyComponentAdded(entity, component: component)
        }
    }

    /// Removes a component type from an entity.
    public func removeComponent<C: Component>(_ entity: EntityId, _: C.Type) {
        let key = ObjectIdentifier(C.self)

        guard var storage = componentStorages[key] as? ComponentStorage<C> else { return }
        guard storage.hasComponent(for: entity) else { return }

        storage.remove(entity)
        componentStorages[key] = storage

        Task { [weak self] in
            await self?.notifyComponentRemoved(entity, componentType: C.self)
        }
    }

    /// Gets a component from an entity.
    public func getComponent<C: Component>(_ entity: EntityId, _: C.Type) -> C? {
        let key = ObjectIdentifier(C.self)
        guard let storage = componentStorages[key] as? ComponentStorage<C> else { return nil }
        return storage.get(entity)
    }

    /// Checks if an entity has a specific component type.
    public func hasComponent<C: Component>(_ entity: EntityId, _: C.Type) -> Bool {
        let key = ObjectIdentifier(C.self)
        guard let storage = componentStorages[key] as? ComponentStorage<C> else { return false }
        return storage.get(entity) != nil
    }

    /// Gets all entities with a specific component type.
    public func entitiesWith<C: Component>(_: C.Type) -> [EntityId] {
        let key = ObjectIdentifier(C.self)
        guard let storage = componentStorages[key] as? ComponentStorage<C> else { return [] }
        return storage.entityIds()
    }

    // MARK: - Queries

    /// Query for entities with one component type.
    public func query<C: Component>(_: C.Type) -> [(EntityId, C)] {
        let key = ObjectIdentifier(C.self)
        guard let storage = componentStorages[key] as? ComponentStorage<C> else { return [] }
        return storage.all()
    }

    /// Query for entities with two component types.
    public func query<C1: Component, C2: Component>(
        _: C1.Type,
        _: C2.Type
    ) -> [(EntityId, C1, C2)] {
        let key1 = ObjectIdentifier(C1.self)
        let key2 = ObjectIdentifier(C2.self)

        guard let storage1 = componentStorages[key1] as? ComponentStorage<C1>,
              let storage2 = componentStorages[key2] as? ComponentStorage<C2> else {
            return []
        }

        var results: [(EntityId, C1, C2)] = []
        for entity in storage1.entityIds() {
            if let c1 = storage1.get(entity), let c2 = storage2.get(entity) {
                results.append((entity, c1, c2))
            }
        }
        return results
    }

    /// Query for entities with three component types.
    public func query<C1: Component, C2: Component, C3: Component>(
        _: C1.Type,
        _: C2.Type,
        _: C3.Type
    ) -> [(EntityId, C1, C2, C3)] {
        let key1 = ObjectIdentifier(C1.self)
        let key2 = ObjectIdentifier(C2.self)
        let key3 = ObjectIdentifier(C3.self)

        guard let storage1 = componentStorages[key1] as? ComponentStorage<C1>,
              let storage2 = componentStorages[key2] as? ComponentStorage<C2>,
              let storage3 = componentStorages[key3] as? ComponentStorage<C3> else {
            return []
        }

        var results: [(EntityId, C1, C2, C3)] = []
        for entity in storage1.entityIds() {
            if let c1 = storage1.get(entity),
               let c2 = storage2.get(entity),
               let c3 = storage3.get(entity) {
                results.append((entity, c1, c2, c3))
            }
        }
        return results
    }

    /// Query for entities with four component types.
    public func query<C1: Component, C2: Component, C3: Component, C4: Component>(
        _: C1.Type,
        _: C2.Type,
        _: C3.Type,
        _: C4.Type
    ) -> [(EntityId, C1, C2, C3, C4)] {
        let key1 = ObjectIdentifier(C1.self)
        let key2 = ObjectIdentifier(C2.self)
        let key3 = ObjectIdentifier(C3.self)
        let key4 = ObjectIdentifier(C4.self)

        guard let storage1 = componentStorages[key1] as? ComponentStorage<C1>,
              let storage2 = componentStorages[key2] as? ComponentStorage<C2>,
              let storage3 = componentStorages[key3] as? ComponentStorage<C3>,
              let storage4 = componentStorages[key4] as? ComponentStorage<C4> else {
            return []
        }

        var results: [(EntityId, C1, C2, C3, C4)] = []
        for entity in storage1.entityIds() {
            if let c1 = storage1.get(entity),
               let c2 = storage2.get(entity),
               let c3 = storage3.get(entity),
               let c4 = storage4.get(entity) {
                results.append((entity, c1, c2, c3, c4))
            }
        }
        return results
    }

    // MARK: - System Management

    /// Registers a minimal System.
    public func registerSystem(_ system: any System) {
        systems.append(AnySystem(system))

        Task { [weak self] in
            await self?.notifySystemRegistered(name: system.name)
        }
    }

    /// Registers an AsyncSystem with lifecycle support.
    public func registerSystem(_ system: any AsyncSystem) async throws {
        let wrapped = AnySystem(system)
        try await wrapped.setup(world: self)
        systems.append(wrapped)

        Task { [weak self] in
            await self?.notifySystemRegistered(name: system.name)
        }
    }

    /// Removes a system by name.
    public func removeSystem(named name: String) async throws {
        guard let index = systems.firstIndex(where: { $0.name == name }) else { return }
        let system = systems.remove(at: index)
        try await system.teardown(world: self)

        Task { [weak self] in
            await self?.notifySystemUnregistered(name: name)
        }
    }

    /// Runs all registered systems once.
    public func update() async {
        let updateStart = Date()
        tick += 1

        for system in systems {
            do {
                try await system.update(world: self)
            } catch {
                // Log error but continue with other systems
                print("[World] System '\(system.name)' failed: \(error)")
            }
        }

        let duration = Date().timeIntervalSince(updateStart)
        lastUpdateTime = Date()

        Task { [weak self] in
            await self?.notifyUpdateCycleCompleted(duration: duration)
        }
    }

    /// Runs a specific system (not part of the registered set).
    public func runSystem(_ system: any System) async {
        await system.update(world: self)
    }

    /// Returns names of all registered systems.
    public func registeredSystemNames() -> [String] {
        systems.map { $0.name }
    }

    /// Sets metadata value for a key.
    public func setMetadata(_ key: String, value: Any) {
        metadata[key] = value
    }

    /// Gets metadata value for a key.
    public func getMetadata(_ key: String) -> Any? {
        metadata[key]
    }

    /// Returns the current system context for timing information.
    public func context() -> SystemContext {
        SystemContext(
            deltaTime: Date().timeIntervalSince(lastUpdateTime),
            totalTime: Date().timeIntervalSince(startTime),
            tick: tick,
            isFirstUpdate: tick == 1
        )
    }

    // MARK: - Observer Management

    /// Adds an observer for world changes.
    public func addObserver(_ observer: any WorldObserver) {
        let key = ObjectIdentifier(observer)
        observers[key] = WeakObserver(observer: observer)
    }

    /// Removes an observer.
    public func removeObserver(_ observer: any WorldObserver) {
        let key = ObjectIdentifier(observer)
        observers[key] = nil
    }

    // MARK: - Observer Notifications

    private func notifyEntityCreated(_ entity: EntityId) async {
        cleanupObservers()
        for wrapper in observers.values {
            if let observer = wrapper.observer {
                await observer.entityCreated(entity)
            }
        }
    }

    private func notifyEntityDestroyed(_ entity: EntityId) async {
        cleanupObservers()
        for wrapper in observers.values {
            if let observer = wrapper.observer {
                await observer.entityDestroyed(entity)
            }
        }
    }

    private func notifyComponentAdded<C: Component>(_ entity: EntityId, component: C) async {
        cleanupObservers()
        for wrapper in observers.values {
            if let observer = wrapper.observer {
                await observer.componentAdded(entity, component: component)
            }
        }
    }

    private func notifyComponentRemoved<C: Component>(_ entity: EntityId, componentType: C.Type) async {
        cleanupObservers()
        for wrapper in observers.values {
            if let observer = wrapper.observer {
                await observer.componentRemoved(entity, componentType: componentType)
            }
        }
    }

    private func notifySystemRegistered(name: String) async {
        cleanupObservers()
        for wrapper in observers.values {
            if let observer = wrapper.observer {
                await observer.systemRegistered(name: name)
            }
        }
    }

    private func notifySystemUnregistered(name: String) async {
        cleanupObservers()
        for wrapper in observers.values {
            if let observer = wrapper.observer {
                await observer.systemUnregistered(name: name)
            }
        }
    }

    private func notifyUpdateCycleCompleted(duration: TimeInterval) async {
        cleanupObservers()
        for wrapper in observers.values {
            if let observer = wrapper.observer {
                await observer.updateCycleCompleted(duration: duration)
            }
        }
    }

    private func cleanupObservers() {
        observers = observers.filter { $0.value.observer != nil }
    }

    // MARK: - Snapshot

    /// Gets a snapshot of world statistics.
    public func snapshot() -> WorldSnapshot {
        var componentCounts: [String: Int] = [:]
        for (_, storage) in componentStorages {
            let count = storage.entityIds().count
            if count > 0 {
                // Use ObjectIdentifier description for now
                componentCounts["component"] = (componentCounts["component"] ?? 0) + count
            }
        }

        return WorldSnapshot(
            entityCount: entities.count,
            componentCounts: componentCounts,
            systemCount: systems.count,
            tick: tick
        )
    }
}

// MARK: - World Snapshot

/// A point-in-time snapshot of world statistics.
public struct WorldSnapshot: Sendable {
    public let entityCount: Int
    public let componentCounts: [String: Int]
    public let systemCount: Int
    public let tick: UInt64
    public let timestamp: Date

    public init(
        entityCount: Int,
        componentCounts: [String: Int],
        systemCount: Int,
        tick: UInt64 = 0,
        timestamp: Date = Date()
    ) {
        self.entityCount = entityCount
        self.componentCounts = componentCounts
        self.systemCount = systemCount
        self.tick = tick
        self.timestamp = timestamp
    }
}

// MARK: - Convenience Extensions

extension World {
    /// Creates an entity with the given components.
    public func spawn(_ components: any Component...) -> EntityId {
        let entity = createEntity()
        for component in components {
            addAnyComponent(entity, component)
        }
        return entity
    }

    /// Type-erased component addition helper.
    private func addAnyComponent(_ entity: EntityId, _ component: any Component) {
        func add<C: Component>(_ c: C) {
            addComponent(entity, c)
        }
        add(component)
    }
}

// MARK: - ECS Errors

/// Errors that can occur during ECS operations.
public enum ECSError: Error, LocalizedError, Sendable {
    case entityNotFound(EntityId)
    case componentNotFound(entityId: EntityId, componentType: String)
    case systemNotFound(name: String)
    case systemAlreadyRegistered(name: String)
    case cyclicDependency(systems: [String])

    public var errorDescription: String? {
        switch self {
        case .entityNotFound(let id):
            return "Entity not found: \(id)"
        case .componentNotFound(let entityId, let type):
            return "Component '\(type)' not found for entity \(entityId)"
        case .systemNotFound(let name):
            return "System not found: \(name)"
        case .systemAlreadyRegistered(let name):
            return "System already registered: \(name)"
        case .cyclicDependency(let systems):
            return "Cyclic dependency detected between systems: \(systems.joined(separator: " -> "))"
        }
    }
}

// MARK: - Query extensions for including/excluding labels
extension World {
    public func query<C: Component>(including componentType: C.Type) async -> [(EntityId, C)] {
        return query(C.self)
    }

    public func query<C1: Component, C2: Component>(
        including componentType: C1.Type,
        excluding excludedComponentType: C2.Type
    ) async -> [(EntityId, C1)] {
        let entities = query(C1.self)
        return entities.filter { !hasComponent($0.0, C2.self) }
    }

    public func query<C1: Component, C2: Component>(
        including firstComponentType: C1.Type,
        including secondComponentType: C2.Type
    ) async -> [(EntityId, C1, C2)] {
        return query(firstComponentType, secondComponentType)
    }

    public func addComponent<C: Component>(_ component: C, to entity: EntityId) async {
        addComponent(entity, component)
    }
}
