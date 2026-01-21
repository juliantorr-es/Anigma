//
//  ArchitectureManifest.swift
//  HarmoniaModule
//
//  Canonical abstraction spine for Anigma/Harmonia.
//  Defines the core abstractions that must be reused, not reinvented.
//

import Foundation
import AnigmaPrimitives

// MARK: - Canonical Abstraction

/// A canonical abstraction that is central to Anigma's architecture.
/// Creating overlapping functionality is considered technical debt.
public struct CanonicalAbstraction: Sendable, Codable, Hashable {
    /// Architectural category.
    public enum Category: String, Codable, CaseIterable, Sendable {
        case ecs
        case memory
        case tools
        case governance
        case cli
    }

    /// Stable identifier (deterministic from module + name).
    public let id: UUID

    /// Name of the abstraction (e.g., "World", "HarmoniaMemory").
    public let name: String

    /// Architectural category.
    public let category: Category

    /// Module where the abstraction lives (e.g., "AnigmaCore", "HarmoniaMemory").
    public let module: String

    /// Brief purpose statement.
    public let purpose: String

    /// When this abstraction should be used.
    public let whenToUse: String

    /// Extension points (public methods/properties that can be overridden).
    public let extensionPoints: [String]

    /// Anti‑patterns to avoid.
    public let antiPatterns: [String]

    /// Canonical location in source (file:line).
    public let canonicalLocation: String

    /// SHA‑256 hash of the public interface (method signatures + property types).
    /// Used to detect breaking changes.
    public let interfaceHash: String

    public init(
        id: UUID,
        name: String,
        category: Category,
        module: String,
        purpose: String,
        whenToUse: String,
        extensionPoints: [String],
        antiPatterns: [String],
        canonicalLocation: String,
        interfaceHash: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.module = module
        self.purpose = purpose
        self.whenToUse = whenToUse
        self.extensionPoints = extensionPoints
        self.antiPatterns = antiPatterns
        self.canonicalLocation = canonicalLocation
        self.interfaceHash = interfaceHash
    }
}

// MARK: - Architecture Manifest

/// Central registry of canonical abstractions.
public enum ArchitectureManifest {

    // MARK: - Spine Abstractions (v1)

    /// The architectural spine – abstractions that must never be duplicated.
    /// These are conceptually central and their duplication causes systemic debt.
    public static let spine: [CanonicalAbstraction] = [
        // ECS Core
        CanonicalAbstraction(
            id: UUID(uuidString: "C9E7A1F0-8B4A-4A7D-9C3D-2E1F0B5A6C7D")!,
            name: "World",
            category: .ecs,
            module: "AnigmaCore",
            purpose: "ECS container – manages entities, components, and systems.",
            whenToUse: "Managing entity‑component‑system architecture; coordinating systems.",
            extensionPoints: ["registerSystem", "registerSingleton", "entities", "components"],
            antiPatterns: ["Creating multiple worlds per module", "Direct data access bypassing ECS"],
            canonicalLocation: "Sources/AnigmaCore/ECS/World.swift:42",
            interfaceHash: "b62aef6976b58a602c3ba81c76ea23e791cd6430e0f7e023eb46a21f43903c1a"
        ),
        CanonicalAbstraction(
            id: UUID(uuidString: "D8F6B2E1-9C5B-5B8E-0D4E-3F2G1C6B7D8E")!,
            name: "EntityId",
            category: .ecs,
            module: "AnigmaCore",
            purpose: "Entity identifier – unique reference to an entity in the World.",
            whenToUse: "Referencing entities across systems; storing entity references.",
            extensionPoints: ["rawValue", "description"],
            antiPatterns: ["Using integers/strings directly as entity IDs", "Assuming entity IDs are stable across saves"],
            canonicalLocation: "Sources/AnigmaCore/ECS/Entity.swift:27",
            interfaceHash: "ecs_entityid_v1"
        ),
        CanonicalAbstraction(
            id: UUID(uuidString: "E7G5C3D2-A6D9-6C9F-1E5F-4G3H2D7E8F9A")!,
            name: "Component",
            category: .ecs,
            module: "AnigmaCore",
            purpose: "ECS component protocol – data attached to entities.",
            whenToUse: "Defining data that entities can carry; implementing pure data types.",
            extensionPoints: ["Component protocol conformance"],
            antiPatterns: ["Putting logic in components", "Using classes instead of structs for components"],
            canonicalLocation: "Sources/AnigmaCore/ECS/Component.swift:15",
            interfaceHash: "ecs_component_v1"
        ),
        CanonicalAbstraction(
            id: UUID(uuidString: "F6H4D3E2-B7E0-7D0A-2F6A-5H4I3E8F0A1B")!,
            name: "System",
            category: .ecs,
            module: "AnigmaCore",
            purpose: "ECS system protocol – logic that processes components.",
            whenToUse: "Implementing game/application logic; processing entities with specific components.",
            extensionPoints: ["update", "requirements", "dependencies"],
            antiPatterns: ["Putting data in systems", "Directly accessing external resources without dependency injection"],
            canonicalLocation: "Sources/AnigmaCore/ECS/System.swift:33",
            interfaceHash: "ecs_system_v1"
        ),
        CanonicalAbstraction(
            id: UUID(uuidString: "G5I4E3F2-C8F1-8E1B-3G7B-6I5J4F9A1B2C")!,
            name: "Scheduler",
            category: .ecs,
            module: "AnigmaCore",
            purpose: "ECS scheduler – coordinates system execution order.",
            whenToUse: "Managing system dependencies and execution order; parallelizing systems.",
            extensionPoints: ["schedule", "run", "addSystem"],
            antiPatterns: ["Manual system ordering", "Blocking systems that could run in parallel"],
            canonicalLocation: "Sources/AnigmaCore/ECS/Scheduler.swift:58",
            interfaceHash: "ecs_scheduler_v1"
        ),

        // Memory Core
        CanonicalAbstraction(
            id: UUID(uuidString: "H6J5F4G3-D9G2-9F2C-4H8C-7J6K5G0B2C3D")!,
            name: "TriMemoryArchitecture",
            category: .memory,
            module: "AnigmaCore",
            purpose: "Triple‑memory architecture – ephemeral, working, and archival memory.",
            whenToUse: "Designing memory‑intensive components; separating caching, persistence, and archival.",
            extensionPoints: ["ephemeral", "working", "archival"],
            antiPatterns: ["Single‑store persistence", "Mixing caching and archival in same layer"],
            canonicalLocation: "Sources/AnigmaCore/Memory/TriMemoryArchitecture.swift:21",
            interfaceHash: "memory_trimemory_v1"
        ),
        CanonicalAbstraction(
            id: UUID(uuidString: "I7K6G5H4-E0H3-0G3D-5I9D-8K7L6H1C3D4E")!,
            name: "HarmoniaMemory",
            category: .memory,
            module: "HarmoniaMemory",
            purpose: "SQLite‑backed memory persistence for tri‑memory architecture.",
            whenToUse: "Storing agent observations, session summaries, and structured memory.",
            extensionPoints: ["SQLiteMemoryStore", "MemoryService", "storeObservation", "searchObservations"],
            antiPatterns: ["Direct file I/O for memory", "Rolling your own SQLite wrapper"],
            canonicalLocation: "Sources/HarmoniaMemory/HarmoniaMemory.swift:29",
            interfaceHash: "memory_harmoniamemory_v1"
        ),
        CanonicalAbstraction(
            id: UUID(uuidString: "J8L7H6I5-F1I4-1H4E-6J0E-9L8M7I2D4E5F")!,
            name: "SQLiteMemoryStore",
            category: .memory,
            module: "HarmoniaMemory",
            purpose: "GRDB‑based SQLite storage implementation.",
            whenToUse: "Needing robust, queryable persistence with FTS5 support.",
            extensionPoints: ["DatabasePool", "migrate", "storeObservation"],
            antiPatterns: ["Direct SQL string interpolation", "Bypassing transaction safety"],
            canonicalLocation: "Sources/HarmoniaMemory/SQLite/SQLiteMemoryStore.swift:14",
            interfaceHash: "memory_sqlitememorystore_v1"
        ),

        // Tool Core
        CanonicalAbstraction(
            id: UUID(uuidString: "K9M8I7J6-G2J5-2I5F-7K1F-0M9N8J3E5F6G")!,
            name: "ToolOrchestrator",
            category: .tools,
            module: "HarmoniaModule",
            purpose: "Single‑provider orchestrator loop for agent tool calling.",
            whenToUse: "Coordinating multi‑step tool use; implementing Plan→Execute→Observe→Reflect→Respond loops.",
            extensionPoints: ["process", "state", "toolRegistry", "behaviorGovernor"],
            antiPatterns: ["Ad‑hoc tool calling", "Bypassing the orchestrator loop"],
            canonicalLocation: "Sources/HarmoniaModule/Orchestrator/ToolOrchestrator.swift:81",
            interfaceHash: "tools_toolorchestrator_v1"
        ),
        CanonicalAbstraction(
            id: UUID(uuidString: "L0N9J8K7-H3K6-3J6G-8L2G-1N0O9K4F6G7H")!,
            name: "ToolRegistry",
            category: .tools,
            module: "HarmoniaModule",
            purpose: "Central registry for tool descriptors and handlers.",
            whenToUse: "Registering new tools; looking up tool descriptors; validating tool calls.",
            extensionPoints: ["register", "execute", "allDescriptors"],
            antiPatterns: ["Direct tool‑handler wiring", "Global mutable tool state"],
            canonicalLocation: "Sources/HarmoniaModule/Tools/ToolRegistry.swift:17",
            interfaceHash: "tools_toolregistry_v1"
        ),
        CanonicalAbstraction(
            id: UUID(uuidString: "M1O0K9L8-I4L7-4K7H-9M3H-2O1P0L5G7H8I")!,
            name: "FileToolRuntime",
            category: .tools,
            module: "HarmoniaModule",
            purpose: "File system tool runtime – read, write, list, stat operations.",
            whenToUse: "File I/O within agent sessions; need governed file access.",
            extensionPoints: ["readFile", "writeFile", "listDirectory", "fileStats"],
            antiPatterns: ["Direct FileManager usage", "Unconstrained file writes"],
            canonicalLocation: "Sources/HarmoniaModule/Tools/FileToolRuntime.swift:19",
            interfaceHash: "tools_filetoolruntime_v1"
        )
    ]

    // MARK: - Query Methods

    /// Finds canonical abstractions matching a concept.
    /// - Parameters:
    ///   - concept: Search term (e.g., "memory", "scheduler", "World").
    ///   - category: Optional category filter.
    /// - Returns: Matching abstractions, sorted by relevance.
    public static func findMatches(
        for concept: String,
        category: CanonicalAbstraction.Category? = nil
    ) -> [CanonicalAbstraction] {
        let lowercasedConcept = concept.lowercased()

        return spine.filter { abstraction in
            // Category filter
            if let category, abstraction.category != category {
                return false
            }

            // Match name or purpose
            let matchesName = abstraction.name.lowercased().contains(lowercasedConcept)
            let matchesPurpose = abstraction.purpose.lowercased().contains(lowercasedConcept)
            let matchesModule = abstraction.module.lowercased().contains(lowercasedConcept)

            // Match extension points or anti-patterns
            let matchesExtensions = abstraction.extensionPoints.contains {
                $0.lowercased().contains(lowercasedConcept)
            }
            let matchesAntiPatterns = abstraction.antiPatterns.contains {
                $0.lowercased().contains(lowercasedConcept)
            }

            return matchesName || matchesPurpose || matchesModule ||
                   matchesExtensions || matchesAntiPatterns
        }
        .sorted { a, b in
            // Prioritize name matches
            let aNameMatch = a.name.lowercased().contains(lowercasedConcept)
            let bNameMatch = b.name.lowercased().contains(lowercasedConcept)
            if aNameMatch != bNameMatch {
                return aNameMatch && !bNameMatch
            }

            // Then module matches
            let aModuleMatch = a.module.lowercased().contains(lowercasedConcept)
            let bModuleMatch = b.module.lowercased().contains(lowercasedConcept)
            if aModuleMatch != bModuleMatch {
                return aModuleMatch && !bModuleMatch
            }

            // Alphabetical fallback
            return a.name < b.name
        }
    }

    /// Gets all abstractions in a category.
    public static func abstractions(in category: CanonicalAbstraction.Category) -> [CanonicalAbstraction] {
        spine.filter { $0.category == category }
    }

    /// Gets an abstraction by its stable ID.
    public static func abstraction(withId id: UUID) -> CanonicalAbstraction? {
        spine.first { $0.id == id }
    }

    /// Gets an abstraction by name (case‑insensitive).
    public static func abstraction(named name: String) -> CanonicalAbstraction? {
        let lowercased = name.lowercased()
        return spine.first { $0.name.lowercased() == lowercased }
    }
}
