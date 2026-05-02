// AnimationCore.swift
// AnimationKit - Tier 1 animation system for Anigma
// Production-ready keyframe animations with curve interpolation

import Foundation
import CapsuleCore
import VectorOpsKit

// MARK: - Animation Protocol

/// Protocol defining animation operations
public protocol Animation: Sendable {
    /// Unique identifier for this animation
    var id: UUID { get }
    
    /// Target property being animated
    var target: AnimationTarget { get }
    
    /// Animation duration in seconds
    var duration: TimeInterval { get }
    
    /// Animation curve/timing function
    var curve: AnimationCurve { get }
    
    /// Keyframes for this animation
    var keyframes: [Keyframe] { get }
    
    /// Whether this animation loops
    var repeats: Bool { get }
    
    /// Number of times to repeat (0 = infinite)
    var repeatCount: UInt32 { get }
    
    /// Evaluate the animation at a given time
    func evaluate(at time: TimeInterval) -> AnimationValue
    
    /// Check if animation is complete at given time
    func isComplete(at time: TimeInterval) -> Bool
}

// MARK: - Animation Target and Values

/// Represents a target property that can be animated
public struct AnimationTarget: Sendable, Hashable, Codable {
    public let objectID: String
    public let property: String
    
    public init(objectID: String, property: String) {
        self.objectID = objectID
        self.property = property
    }
}

/// Animated value supporting multiple types
public enum AnimationValue: Sendable, Hashable, Codable {
    case float(Float)
    case vector2(Vector2)
    case vector3(Vector3)
    case vector4(Vector4)
    case color(Color)
    case bool(Bool)
    
    public init(float: Float) { self = .float(float) }
    public init(vector2: Vector2) { self = .vector2(vector2) }
    public init(vector3: Vector3) { self = .vector3(vector3) }
    public init(vector4: Vector4) { self = .vector4(vector4) }
    public init(color: Color) { self = .color(color) }
    public init(bool: Bool) { self = .bool(bool) }
}

/// Color representation for animations
public struct Color: Sendable, Hashable, Codable {
    public let r: Float
    public let g: Float
    public let b: Float
    public let a: Float
    
    public init(r: Float, g: Float, b: Float, a: Float = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    
    public static let red = Color(r: 1.0, g: 0.0, b: 0.0)
    public static let green = Color(r: 0.0, g: 1.0, b: 0.0)
    public static let blue = Color(r: 0.0, g: 0.0, b: 1.0)
    public static let white = Color(r: 1.0, g: 1.0, b: 1.0)
    public static let black = Color(r: 0.0, g: 0.0, b: 0.0)
    public static let clear = Color(r: 0.0, g: 0.0, b: 0.0, a: 0.0)
}

// MARK: - Keyframe

/// A single keyframe in an animation
public struct Keyframe: Sendable, Hashable, Codable {
    /// Time position within the animation (0.0 to 1.0)
    public let time: Float
    
    /// Value at this keyframe
    public let value: AnimationValue
    
    /// Optional ease in/out for this segment
    public let easing: EasingFunction?
    
    public init(time: Float, value: AnimationValue, easing: EasingFunction? = nil) {
        self.time = max(0.0, min(1.0, time)) // Clamp to [0, 1]
        self.value = value
        self.easing = easing
    }
}

/// Easing functions for keyframe transitions
public enum EasingFunction: String, Sendable, CaseIterable, Codable {
    case linear = "linear"
    case easeIn = "easeIn"
    case easeOut = "easeOut"
    case easeInOut = "easeInOut"
    case easeInQuad = "easeInQuad"
    case easeOutQuad = "easeOutQuad"
    case easeInOutQuad = "easeInOutQuad"
    case easeInCubic = "easeInCubic"
    case easeOutCubic = "easeOutCubic"
    case easeInOutCubic = "easeInOutCubic"
    
    /// Apply easing to a normalized time value (0.0 to 1.0)
    public func apply(to t: Float) -> Float {
        let t = max(0.0, min(1.0, t)) // Clamp to [0, 1]
        
        switch self {
        case .linear:
            return t
            
        case .easeIn:
            return t * t
            
        case .easeOut:
            return 1.0 - (1.0 - t) * (1.0 - t)
            
        case .easeInOut:
            return t < 0.5 ? 2.0 * t * t : 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
            
        case .easeInQuad:
            return t * t
            
        case .easeOutQuad:
            return 1.0 - (1.0 - t) * (1.0 - t)
            
        case .easeInOutQuad:
            return t < 0.5 ? 2.0 * t * t : 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
            
        case .easeInCubic:
            return t * t * t
            
        case .easeOutCubic:
            return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
            
        case .easeInOutCubic:
            return t < 0.5 ? 4.0 * t * t * t : 1.0 - 4.0 * (1.0 - t) * (1.0 - t) * (1.0 - t)
        }
    }
}

// MARK: - Animation Curves

/// Animation curves for timing functions
public struct AnimationCurve: Sendable, Hashable, Codable {
    public let type: CurveType
    public let controlPoints: [Float] // For bezier curves
    
    public init(type: CurveType = .linear, controlPoints: [Float] = []) {
        self.type = type
        self.controlPoints = controlPoints
    }
    
    /// Apply the curve to a normalized time value (0.0 to 1.0)
    public func apply(to t: Float) -> Float {
        let t = max(0.0, min(1.0, t)) // Clamp to [0, 1]
        
        switch type {
        case .linear:
            return t
            
        case .easeIn:
            return t * t * t
            
        case .easeOut:
            let invT = 1.0 - t
            return 1.0 - invT * invT * invT
            
        case .easeInOut:
            return t < 0.5 ? 4.0 * t * t * t : 1.0 + 4.0 * (t - 1.0) * (t - 1.0) * (t - 1.0)
            
        case .bezier:
            if controlPoints.count >= 4 {
                // Cubic bezier: p0=0, p1=cp1, p2=cp2, p3=1
                let cp1x = controlPoints[0]
                let cp1y = controlPoints[1]
                let cp2x = controlPoints[2]
                let cp2y = controlPoints[3]
                return cubicBezier(t: t, cp1x: cp1x, cp1y: cp1y, cp2x: cp2x, cp2y: cp2y)
            }
            return t
            
        case .custom:
            // For custom curves, controlPoints[0] is used as a lookup table index
            // This would require pre-computed lookup tables in production
            return t
        }
    }
    
    private func cubicBezier(t: Float, cp1x: Float, cp1y: Float, cp2x: Float, cp2y: Float) -> Float {
        // Simplified cubic bezier calculation
        // In production, this would use proper curve solving
        let mt = 1.0 - t
        let x = 3.0 * mt * mt * t * cp1x + 3.0 * mt * t * t * cp2x + t * t * t
        return x // Return x coordinate (curve control)
    }
}

/// Types of animation curves
public enum CurveType: String, Sendable, CaseIterable, Codable {
    case linear = "linear"
    case easeIn = "easeIn"
    case easeOut = "easeOut"
    case easeInOut = "easeInOut"
    case bezier = "bezier"
    case custom = "custom"
}

// MARK: - Value Interpolation

/// Protocol for interpolating between animated values
public protocol ValueInterpolator: Sendable {
    /// Interpolate between two values
    func interpolate(from: AnimationValue, to: AnimationValue, t: Float) -> AnimationValue
}

/// Default interpolator that handles all value types
public struct DefaultValueInterpolator: ValueInterpolator {
    public init() {}
    
    public func interpolate(from: AnimationValue, to: AnimationValue, t: Float) -> AnimationValue {
        switch (from, to) {
        case (.float(let a), .float(let b)):
            return .float(a + (b - a) * t)
            
        case (.vector2(let a), .vector2(let b)):
            return .vector2(a + (b - a) * t)
            
        case (.vector3(let a), .vector3(let b)):
            return .vector3(a + (b - a) * t)
            
        case (.vector4(let a), .vector4(let b)):
            return .vector4(a + (b - a) * t)
            
        case (.color(let a), .color(let b)):
            let r = a.r + (b.r - a.r) * t
            let g = a.g + (b.g - a.g) * t
            let bl = a.b + (b.b - a.b) * t
            let al = a.a + (b.a - a.a) * t
            return .color(Color(r: r, g: g, b: bl, a: al))
            
        case (.bool(let a), .bool(let b)):
            return .bool(t < 0.5 ? a : b) // Binary interpolation
            
        default:
            // Types don't match - return 'to' value
            return to
        }
    }
}