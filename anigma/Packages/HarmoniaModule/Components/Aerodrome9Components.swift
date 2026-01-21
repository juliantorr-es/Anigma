//
//  Aerodrome9Components.swift
//  HarmoniaModule
//
//  ECS components for Aerodrome-9 narrative tactics demo.
//  Based on spec: Docs/Aerodrome9_Demo_Spec.md
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Core Components

/// Position on a 2D tile grid.
public struct Position: Component, Codable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// Velocity for movement.
public struct Velocity: Component, Codable {
    public var dx: Int
    public var dy: Int

    public init(dx: Int, dy: Int) {
        self.dx = dx
        self.dy = dy
    }
}

/// Sprite identifier and render layer.
public struct Sprite: Component, Codable {
    public var spriteId: String
    public var z: Int

    public init(spriteId: String, z: Int = 0) {
        self.spriteId = spriteId
        self.z = z
    }
}

/// Marks entity as player-controlled.
public struct InputControlled: Component, Codable {
    public var isEnabled: Bool

    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}

// MARK: - Narrative Identity Components

/// Actor role (point of view).
public struct ActorRole: Component, Codable {
    public enum Role: String, Codable, Sendable {
        case archive   // Archive field theoretician
        case officer   // Imperial officer
        case guild     // Frontier guild engineer
    }

    public var role: Role

    public init(role: Role) {
        self.role = role
    }
}

/// Faction alignment and trust meter.
public struct FactionAlignment: Component, Codable {
    public enum Faction: String, Codable, Sendable {
        case archive
        case empire
        case guild
    }

    public var faction: Faction
    public var trust: Int   // range -100 ... 100

    public init(faction: Faction, trust: Int = 0) {
        self.faction = faction
        self.trust = trust
    }
}

/// Dyadic relationship between two entities.
public struct RelationshipMeter: Component, Codable {
    public var targetId: EntityId
    public var value: Int   // simple dyadic score

    public init(targetId: EntityId, value: Int = 0) {
        self.targetId = targetId
        self.value = value
    }
}

// MARK: - Interaction Components

/// Interactive object kind and identifier.
public struct Interactable: Component, Codable {
    public enum InteractionKind: String, Codable, Sendable {
        case talk
        case examine
        case use
        case choice
    }

    public var interactionId: String
    public var kind: InteractionKind

    public init(interactionId: String, kind: InteractionKind) {
        self.interactionId = interactionId
        self.kind = kind
    }
}

/// Proximity radius for interaction detection.
public struct InteractionZone: Component, Codable {
    public var radius: Int

    public init(radius: Int = 1) {
        self.radius = radius
    }
}

/// Dialogue node reference.
public struct DialogueNode: Component, Codable {
    public var nodeId: String

    public init(nodeId: String) {
        self.nodeId = nodeId
    }
}

/// Scene transition trigger with conditions.
public struct SceneTrigger: Component, Codable {
    public var triggerId: String
    public var conditions: [String]  // flag names that must be true

    public init(triggerId: String, conditions: [String] = []) {
        self.triggerId = triggerId
        self.conditions = conditions
    }
}

// MARK: - Scene and Global Progression Components

/// Tracks scene-specific state.
public struct SceneState: Component, Codable {
    public var sceneId: String
    public var actionsRemaining: Int
    public var resolved: Bool

    public init(sceneId: String, actionsRemaining: Int, resolved: Bool = false) {
        self.sceneId = sceneId
        self.actionsRemaining = actionsRemaining
        self.resolved = resolved
    }
}

/// Global crisis flags and metrics.
public struct WorldState: Component, Codable {
    public var crisisFlags: [String: Bool]
    public var metrics: [String: Double]   // relayAccess, guildAnger, archiveConfidence

    public init(crisisFlags: [String: Bool] = [:], metrics: [String: Double] = [:]) {
        self.crisisFlags = crisisFlags
        self.metrics = metrics
    }
}

/// Single choice entry in history.
public struct ChoiceEntry: Codable, Sendable {
    public var sceneId: String
    public var choiceId: String
    public var effects: [StateEffect]

    public init(sceneId: String, choiceId: String, effects: [StateEffect] = []) {
        self.sceneId = sceneId
        self.choiceId = choiceId
        self.effects = effects
    }
}

/// History of player choices.
public struct ChoiceHistory: Component, Codable {
    public var entries: [ChoiceEntry]

    public init(entries: [ChoiceEntry] = []) {
        self.entries = entries
    }
}

// MARK: - UI Overlay Components

/// Controls visibility of psychohistory flowchart.
public struct UIFlowchartView: Component, Codable {
    public var isVisible: Bool

    public init(isVisible: Bool = false) {
        self.isVisible = isVisible
    }
}

/// Active dialogue view state.
public struct UIDialogueView: Component, Codable {
    public var active: Bool
    public var currentNodeId: String?

    public init(active: Bool = false, currentNodeId: String? = nil) {
        self.active = active
        self.currentNodeId = currentNodeId
    }
}

// MARK: - Data Definitions (used by components)

/// Effect on world state (flag set/clear, metric delta, etc.)
public struct StateEffect: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case flagSet
        case flagClear
        case metricDelta
        case relationshipDelta
    }

    public let kind: Kind
    public let key: String
    public let value: Double

    public init(kind: Kind, key: String, value: Double) {
        self.kind = kind
        self.key = key
        self.value = value
    }
}

/// Scene transition rule.
public struct SceneTransition: Codable, Sendable {
    public let sceneId: String
    public let conditionFlags: [String: Bool]

    public init(sceneId: String, conditionFlags: [String: Bool] = [:]) {
        self.sceneId = sceneId
        self.conditionFlags = conditionFlags
    }
}

/// Blueprint for spawning NPCs and interactables.
public struct EntityBlueprint: Codable, Sendable {
    public let entityId: String
    public let components: [String: AnyCodableValue]  // simplified; real implementation would be type-safe

    public init(entityId: String, components: [String: AnyCodableValue] = [:]) {
        self.entityId = entityId
        self.components = components
    }
}

/// Scene definition (data-driven).
public struct SceneDefinition: Codable, Sendable {
    public let id: String
    public let pov: ActorRole.Role
    public let mapId: String
    public let npcs: [EntityBlueprint]
    public let interactables: [EntityBlueprint]
    public let entryConditions: [String: Bool]
    public let actionsBudget: Int
    public let choices: [ChoiceDefinition]
    public let resolutionEffects: [StateEffect]
    public let nextSceneCandidates: [SceneTransition]

    public init(
        id: String,
        pov: ActorRole.Role,
        mapId: String,
        npcs: [EntityBlueprint] = [],
        interactables: [EntityBlueprint] = [],
        entryConditions: [String: Bool] = [:],
        actionsBudget: Int = 10,
        choices: [ChoiceDefinition] = [],
        resolutionEffects: [StateEffect] = [],
        nextSceneCandidates: [SceneTransition] = []
    ) {
        self.id = id
        self.pov = pov
        self.mapId = mapId
        self.npcs = npcs
        self.interactables = interactables
        self.entryConditions = entryConditions
        self.actionsBudget = actionsBudget
        self.choices = choices
        self.resolutionEffects = resolutionEffects
        self.nextSceneCandidates = nextSceneCandidates
    }
}

/// Player choice definition.
public struct ChoiceDefinition: Codable, Sendable {
    public let id: String
    public let prompt: String
    public let requirements: [String: Bool]
    public let costs: Int
    public let effects: [StateEffect]
    public let nextSceneOverrides: [SceneTransition]?

    public init(
        id: String,
        prompt: String,
        requirements: [String: Bool] = [:],
        costs: Int = 1,
        effects: [StateEffect] = [],
        nextSceneOverrides: [SceneTransition]? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.requirements = requirements
        self.costs = costs
        self.effects = effects
        self.nextSceneOverrides = nextSceneOverrides
    }
}
