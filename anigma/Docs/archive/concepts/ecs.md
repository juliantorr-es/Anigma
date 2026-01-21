# Concepts: Entity-Component-System (ECS)

The Anigma ecosystem is built upon an **Entity-Component-System (ECS)** architectural pattern. This design choice is fundamental to achieving the modularity, scalability, and performance required for complex, data-driven applications. This document explains the core concepts of ECS as implemented in `AnigmaCore`.

## 1. Entities: The "Things"

An Entity is a unique identifier. It represents a single "thing" in the application but contains no data or logic itself. It is simply an ID.

*   **Analogy:** Think of an Entity as a blank ID card. It doesn't tell you anything about the person, just that they exist and can be identified.
*   **Implementation:** In Anigma, this is the `EntityId` struct, which wraps a standard `UUID` to ensure global uniqueness, making it suitable for persistence and distributed systems.

```swift
// An EntityId is a lightweight, unique identifier.
let documentEntity = EntityId()
print(documentEntity) // Prints: "Entity(A4B2C1D8...)"
```

## 2. Components: The "Data"

A Component is a container for pure data that describes an aspect of an Entity. Components have no behavior (methods); they are simple data structures. An Entity's capabilities are defined by the collection of Components attached to it.

*   **Analogy:** Components are like sticky notes you attach to the ID card. One note says "Name: John Doe," another says "Job: Engineer." The collection of notes defines the person.
*   **Implementation:** Anigma provides a hierarchy of protocols for components, allowing developers to opt into features as needed.

### Component Protocols

*   **`Component`:** The base protocol. A minimal marker (`protocol Component: Sendable {}`) for any component struct.
    ```swift
    struct NameComponent: Component {
        let name: String
    }
    ```
*   **`TypedComponent`:** A component that has a type identifier (e.g., `"name"`), useful for serialization and storage.
*   **`VersionedComponent`:** A component that includes a `version` and `modifiedAt` property for optimistic locking and audit trails.
*   **`CodableComponent`:** A component that conforms to Swift's `Codable` protocol, making it easy to persist to disk or send over a network.
*   **`PersistableComponent`:** A "kitchen sink" protocol combining all the above features for complex domain components that need to be fully managed and persisted.

This layered approach allows for lightweight, simple components where appropriate, and rich, feature-full components where needed, without unnecessary overhead.

## 3. Systems: The "Behavior"

A System contains the logic that operates on Entities possessing a specific set of Components. Systems are generally stateless; they query the `World` for entities that match their criteria and then perform actions.

*   **Analogy:** Systems are like specialized workers. The "OCR Processor" worker looks for all ID cards that have a `FileComponent` note and a `StatusComponent(state: .pendingOCR)` note. They perform their task, add an `OcrTextComponent` note, and update the `StatusComponent` note.
*   **Implementation:** Anigma provides two types of system protocols to accommodate different needs.

### System Protocols

*   **`System`:** A minimal protocol for straightforward, synchronous-like logic.
    ```swift
    struct PrintNameSystem: System {
        var name: String { "PrintNameSystem" }

        func update(world: World) async {
            // Query for all entities that have a NameComponent
            for (entity, name) in await world.query(NameComponent.self) {
                print("Entity \(entity) is named \(name.name)")
            }
        }
    }
    ```
*   **`AsyncSystem`:** A richer, `actor`-based protocol for complex, asynchronous tasks that may have dependencies on other systems. This protocol allows for explicit dependency ordering and declaration of which components are read or written, enabling advanced scheduling and optimization.
    ```swift
    actor OcrSystem: AsyncSystem {
        nonisolated var name: String { "OCR" }
        nonisolated var dependencies: [String] { ["FileImportSystem"] } // Must run after file import
        nonisolated var readComponents: [any Component.Type] { [FileComponent.self] }
        nonisolated var writeComponents: [any Component.Type] { [OcrResultComponent.self] }

        func update(world: World) async throws {
            // ... logic to perform OCR on documents ...
        }
    }
    ```

## 4. The World: The Central Hub

The `World` is the central container that manages the entire ECS state. It is implemented as a Swift `actor` to ensure all operations are thread-safe.

*   **Responsibilities:**
    *   Creating and destroying entities.
    *   Attaching, removing, and retrieving components for entities.
    *   Registering and running systems.
    *   Executing queries to find entities with specific combinations of components.
*   **Usage:**
    ```swift
    // Create a world
    let world = World()

    // Create an entity and give it components
    let myEntity = await world.createEntity()
    await world.addComponent(myEntity, NameComponent(name: "My Document"))
    await world.addComponent(myEntity, StatusComponent(state: .pending))

    // Register a system to act on the components
    await world.registerSystem(PrintNameSystem())

    // Run one update cycle
    await world.update() // "Entity ... is named My Document" will be printed
    ```

## Why ECS for Anigma?

*   **Modularity:** Features can be added by simply creating new Components and Systems.
*   **Flexibility:** An entity's behavior can be changed at runtime by adding or removing components.
*   **Clear Separation of Concerns:** It enforces a clean divide between data (Components) and logic (Systems).
*   **Performance:** The data-oriented design is highly efficient and allows for easy parallelization of work.

This powerful paradigm allows Anigma to handle a diverse range of complex tasks—from document processing and AI agent orchestration to work management and governance—in a unified, efficient, and extensible manner.
