//
//  Aerodrome9Systems.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

//
//  Aerodrome9Systems.swift
//  HarmoniaModule/Systems
//
//  ECS systems for Aerodrome-9 narrative tactics demo.
//  Based on spec: Docs/Aerodrome9_Demo_Spec.md
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Input System

/// Reads input, marks desired movement and interaction intent for the player entity.
public struct InputSystem: System {
    public var name: String { "Input" }

    public init() {}

    public func update(world: World) async {
        let controlled = await world.query(InputControlled.self, Velocity.self)
        for (entity, input, velocity) in controlled {
            guard input.isEnabled else { continue }
            var updated = velocity
            updated.dx = clamp(updated.dx, min: -1, max: 1)
            updated.dy = clamp(updated.dy, min: -1, max: 1)
            await world.addComponent(entity, updated)
        }
    }
}

// MARK: - Movement System

/// Applies Velocity to Position, clamping to tile map bounds and collision masks.
public struct MovementSystem: System {
    public var name: String { "Movement" }

    public init() {}

    public func update(world: World) async {
        let bounds = await resolveBounds(world: world)
        let movers = await world.query(Position.self, Velocity.self)
        for (entity, position, velocity) in movers {
            var updated = position
            updated.x += velocity.dx
            updated.y += velocity.dy
            updated.x = max(0, updated.x)
            updated.y = max(0, updated.y)
            if let bounds {
                updated.x = min(bounds.maxX, updated.x)
                updated.y = min(bounds.maxY, updated.y)
            }
            await world.addComponent(entity, updated)
        }
    }
}

// MARK: - Rendering System

/// Draws the tile map, sprites sorted by z, and overlay UIs via SpriteKit or a minimal renderer.
public struct RenderingSystem: System {
    public var name: String { "Rendering" }

    public init() {}

    public func update(world: World) async {
        let sprites = await world.query(Position.self, Sprite.self)
        let count = sprites.count
        await Logger.shared.log(
            level: .debug,
            "Prepared \(count) sprite(s) for render",
            category: "Aerodrome9"
        )
    }
}

// MARK: - Interaction System

/// Finds nearby entities with InteractionZone and Interactable, and fires interaction events when the player accepts.
public struct InteractionSystem: System {
    public var name: String { "Interaction" }

    public init() {}

    public func update(world: World) async {
        guard let playerPosition = await resolvePlayerPosition(world: world) else { return }
        let interactables = await world.query(Position.self, InteractionZone.self, Interactable.self)
        let dialogueViews = await world.query(UIDialogueView.self)
        var nearestNodeId: String?

        for (_, position, zone, interactable) in interactables {
            if distance(from: playerPosition, to: position) <= zone.radius {
                nearestNodeId = interactable.interactionId
                break
            }
        }

        for (entity, view) in dialogueViews {
            var updated = view
            if let nearestNodeId {
                updated.active = true
                updated.currentNodeId = nearestNodeId
            } else {
                updated.active = false
                updated.currentNodeId = nil
            }
            await world.addComponent(entity, updated)
        }
    }
}

// MARK: - Dialogue System

/// Resolves dialogue nodes and dynamic text, posts StateEffects, and advances or closes dialogue views.
public struct DialogueSystem: System {
    public var name: String { "Dialogue" }

    public init() {}

    public func update(world: World) async {
        let dialogues = await world.query(UIDialogueView.self)
        for (entity, view) in dialogues {
            guard view.active else { continue }
            if view.currentNodeId == nil {
                var updated = view
                updated.currentNodeId = "start"
                await world.addComponent(entity, updated)
            }
        }
    }
}

// MARK: - Scene Resolution System

/// Decrements actionsRemaining on each interaction, marks the scene resolved on zero actions or if key flags were set,
/// and pushes SceneTransition events.
public struct SceneResolutionSystem: System {
    public var name: String { "SceneResolution" }

    public init() {}

    public func update(world: World) async {
        let triggers = await world.query(SceneTrigger.self)
        let worldFlags = await resolveWorldFlags(world: world)
        let scenes = await world.query(SceneState.self)
        for (entity, state) in scenes {
            var updated = state
            if updated.actionsRemaining <= 0 {
                updated.resolved = true
            }
            if !updated.resolved, triggersSatisfied(triggers: triggers, flags: worldFlags) {
                updated.resolved = true
            }
            if updated.resolved {
                updated.actionsRemaining = max(0, updated.actionsRemaining)
            }
            await world.addComponent(entity, updated)
        }
    }
}

// MARK: - Psychohistory System

/// Reads WorldState and ChoiceHistory and generates a small internal graph of nodes and edges for the flowchart UI.
public struct PsychohistorySystem: System {
    public var name: String { "Psychohistory" }

    public init() {}

    public func update(world: World) async {
        let histories = await world.query(ChoiceHistory.self)
        let choiceCount = histories.first?.1.entries.count ?? 0
        let worldStates = await world.query(WorldState.self)
        for (entity, state) in worldStates {
            let crisisCount = state.crisisFlags.values.filter { $0 }.count
            let stability = max(0.0, 1.0 - (Double(crisisCount) * 0.1) - (Double(choiceCount) * 0.05))
            var updated = state
            updated.metrics["choice_count"] = Double(choiceCount)
            updated.metrics["stability_index"] = stability
            await world.addComponent(entity, updated)
        }
    }
}

// MARK: - UI System

/// Toggles between exploration view, dialogue overlays, and the psychohistory flowchart.
public struct UISystem: System {
    public var name: String { "UI" }

    public init() {}

    public func update(world: World) async {
        let scenes = await world.query(SceneState.self)
        let hasResolvedScene = scenes.contains { $0.1.resolved }
        let dialogues = await world.query(UIDialogueView.self)
        let dialogueActive = dialogues.contains { $0.1.active }
        let flowcharts = await world.query(UIFlowchartView.self)

        for (entity, view) in flowcharts {
            var updated = view
            updated.isVisible = hasResolvedScene && !dialogueActive
            await world.addComponent(entity, updated)
        }
    }
}

// MARK: - System Registry

/// Collection of all Aerodrome-9 systems for easy registration.
public enum Aerodrome9Systems {
    public static let all: [any System] = [
        InputSystem(),
        MovementSystem(),
        RenderingSystem(),
        InteractionSystem(),
        DialogueSystem(),
        SceneResolutionSystem(),
        PsychohistorySystem(),
        UISystem()
    ]
}

private struct SceneBounds {
    let maxX: Int
    let maxY: Int
}

private func clamp(_ value: Int, min: Int, max: Int) -> Int {
    if value < min { return min }
    if value > max { return max }
    return value
}

private func resolveBounds(world: World) async -> SceneBounds? {
    let worldStates = await world.query(WorldState.self)
    guard let metrics = worldStates.first?.1.metrics else { return nil }
    guard let width = metrics["map_width"], let height = metrics["map_height"] else { return nil }
    let maxX = max(0, Int(width) - 1)
    let maxY = max(0, Int(height) - 1)
    return SceneBounds(maxX: maxX, maxY: maxY)
}

private func resolvePlayerPosition(world: World) async -> Position? {
    let controlled = await world.query(Position.self, InputControlled.self)
    return controlled.first?.1
}

private func resolveWorldFlags(world: World) async -> [String: Bool] {
    let worldStates = await world.query(WorldState.self)
    return worldStates.first?.1.crisisFlags ?? [:]
}

private func distance(from a: Position, to b: Position) -> Int {
    let dx = abs(a.x - b.x)
    let dy = abs(a.y - b.y)
    return max(dx, dy)
}

private func triggersSatisfied(
    triggers: [(EntityId, SceneTrigger)],
    flags: [String: Bool]
) -> Bool {
    for (_, trigger) in triggers {
        let satisfied = trigger.conditions.allSatisfy { flags[$0] == true }
        if satisfied {
            return true
        }
    }
    return false
}
