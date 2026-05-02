//
//  Aerodrome9Components.swift
//  HarmoniaModule
//
//  ECS components for Aerodrome-9 narrative tactics demo.
//

import Foundation
import AnigmaPrimitives

public struct Position: Component, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    
    public init(x: Double, y: Double, z: Double = 0) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct Velocity: Component, Codable, Sendable {
    public var dx: Double
    public var dy: Double
    public var dz: Double
    
    public init(dx: Double, dy: Double, dz: Double = 0) {
        self.dx = dx
        self.dy = dy
        self.dz = dz
    }
}

public struct Sprite: Component, Codable, Sendable {
    public var imageName: String
    public var scale: Double
    
    public init(imageName: String, scale: Double = 1.0) {
        self.imageName = imageName
        self.scale = scale
    }
}

public struct InputControlled: Component, Codable, Sendable {
    public var playerIndex: Int
    public var isEnabled: Bool
    
    public init(playerIndex: Int = 0, isEnabled: Bool = true) {
        self.playerIndex = playerIndex
        self.isEnabled = isEnabled
    }
}

public struct SceneTrigger: Component, Codable, Sendable {
    public var sceneId: String
    public var radius: Double
    public var conditions: [String]
    
    public init(sceneId: String, radius: Double, conditions: [String] = []) {
        self.sceneId = sceneId
        self.radius = radius
        self.conditions = conditions
    }
}

public struct AerodromeWorldState: Component, Codable, Sendable {
    public var time: TimeInterval
    public var paused: Bool
    public var metrics: [String: Double]
    public var crisisFlags: [String: Bool]
    
    public init(time: TimeInterval = 0, paused: Bool = false, metrics: [String: Double] = [:], crisisFlags: [String: Bool] = [:]) {
        self.time = time
        self.paused = paused
        self.metrics = metrics
        self.crisisFlags = crisisFlags
    }
}

public struct SceneState: Component, Codable, Sendable {
    public var sceneId: String
    public var resolved: Bool
    public var actionsRemaining: Int
    
    public init(sceneId: String, resolved: Bool = false, actionsRemaining: Int = 0) {
        self.sceneId = sceneId
        self.resolved = resolved
        self.actionsRemaining = actionsRemaining
    }
}

public struct UIDialogueView: Component, Codable, Sendable {
    public var active: Bool
    public var text: String
    public var currentNodeId: String?
    
    public init(active: Bool = false, text: String = "", currentNodeId: String? = nil) {
        self.active = active
        self.text = text
        self.currentNodeId = currentNodeId
    }
}

public struct UIFlowchartView: Component, Codable, Sendable {
    public var active: Bool
    public var nodes: [String]
    public var isVisible: Bool
    
    public init(active: Bool = false, nodes: [String] = [], isVisible: Bool = false) {
        self.active = active
        self.nodes = nodes
        self.isVisible = isVisible
    }
}
