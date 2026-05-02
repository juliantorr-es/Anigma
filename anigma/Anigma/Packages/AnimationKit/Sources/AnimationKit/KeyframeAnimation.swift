// KeyframeAnimation.swift
// AnimationKit - Production-ready keyframe animation implementation

import Foundation
import CapsuleCore
import VectorOpsKit

// MARK: - Keyframe Animation Implementation

/// Concrete keyframe-based animation
public struct KeyframeAnimation: Animation, Sendable {
    public let id: UUID
    public let target: AnimationTarget
    public let duration: TimeInterval
    public let curve: AnimationCurve
    public let keyframes: [Keyframe]
    public let repeats: Bool
    public let repeatCount: UInt32
    public let interpolator: ValueInterpolator
    
    public init(
        target: AnimationTarget,
        duration: TimeInterval,
        keyframes: [Keyframe],
        curve: AnimationCurve = AnimationCurve(),
        repeats: Bool = false,
        repeatCount: UInt32 = 1,
        interpolator: ValueInterpolator = DefaultValueInterpolator()
    ) {
        self.id = UUID()
        self.target = target
        self.duration = max(duration, 0.016) // Minimum 1ms
        self.curve = curve
        self.keyframes = keyframes.sorted { $0.time < $1.time } // Ensure sorted
        self.repeats = repeats
        self.repeatCount = repeatCount
        self.interpolator = interpolator
    }
    
    public func evaluate(at time: TimeInterval) -> AnimationValue {
        let normalizedTime = normalizeTime(time)
        
        guard !keyframes.isEmpty else {
            return .float(0.0) // Default value
        }
        
        // Apply overall animation curve
        let curvedTime = curve.apply(to: Float(normalizedTime))
        
        // Find the keyframes to interpolate between
        let keyframeTime = Float(curvedTime) * Float(keyframes.count - 1)
        let keyframeIndex = Int(keyframeTime)
        let keyframeFraction = keyframeTime - Float(keyframeIndex)
        
        // Handle edge cases
        if keyframeIndex >= keyframes.count - 1 {
            return keyframes.last?.value ?? .float(0.0)
        }
        
        if keyframeIndex < 0 {
            return keyframes.first?.value ?? .float(0.0)
        }
        
        let keyframe1 = keyframes[keyframeIndex]
        let keyframe2 = keyframes[keyframeIndex + 1]
        
        // Apply easing if specified
        let easedFraction: Float
        if let easing = keyframe1.easing {
            easedFraction = easing.apply(to: keyframeFraction)
        } else {
            easedFraction = keyframeFraction
        }
        
        // Interpolate between keyframes
        return interpolator.interpolate(
            from: keyframe1.value,
            to: keyframe2.value,
            t: easedFraction
        )
    }
    
    public func isComplete(at time: TimeInterval) -> Bool {
        if repeats && repeatCount == 0 {
            return false // Infinite loop
        }
        
        let cycles = time / duration
        if repeats {
            return cycles >= Double(repeatCount)
        } else {
            return time >= duration
        }
    }
    
    private func normalizeTime(_ time: TimeInterval) -> Double {
        if time <= 0 {
            return 0.0
        }
        
        if time >= duration {
            if repeats {
                let cycles = time / duration
                if repeatCount == 0 || cycles < Double(repeatCount) {
                    let fractionalCycle = cycles.truncatingRemainder(dividingBy: 1.0)
                    return fractionalCycle
                } else {
                    return 1.0 // Animation completed
                }
            } else {
                return 1.0
            }
        }
        
        return time / duration
    }
}

// MARK: - Animation Timeline

/// Timeline for managing multiple animations
public actor AnimationTimeline {
    private var animations: [UUID: ActiveAnimation] = [:]
    private var globalTime: TimeInterval = 0.0
    private var isPlaying: Bool = true
    
    public init() {}
    
    /// Add an animation to the timeline
    public func add(_ animation: any Animation, startTime: TimeInterval = 0.0) {
        let activeAnimation = ActiveAnimation(
            animation: animation,
            startTime: startTime,
            isPaused: false
        )
        animations[animation.id] = activeAnimation
    }
    
    /// Remove an animation from the timeline
    public func remove(animationID: UUID) {
        animations.removeValue(forKey: animationID)
    }
    
    /// Pause all animations
    public func pause() {
        isPlaying = false
    }
    
    /// Resume all animations
    public func resume() {
        isPlaying = true
    }
    
    /// Pause a specific animation
    public func pause(animationID: UUID) {
        animations[animationID]?.isPaused = true
    }
    
    /// Resume a specific animation
    public func resume(animationID: UUID) {
        animations[animationID]?.isPaused = false
    }
    
    /// Update timeline and evaluate animations
    public func update(deltaTime: TimeInterval) -> [AnimationUpdate] {
        guard isPlaying else { return [] }
        
        globalTime += deltaTime
        var updates: [AnimationUpdate] = []
        
        var completedAnimations: [UUID] = []
        
        for (id, activeAnimation) in animations {
            if activeAnimation.isPaused { continue }
            
            let elapsedTime = globalTime - activeAnimation.startTime
            let animation = activeAnimation.animation
            
            if animation.isComplete(at: elapsedTime) {
                completedAnimations.append(id)
            } else {
                let value = animation.evaluate(at: elapsedTime)
                let update = AnimationUpdate(
                    animationID: id,
                    target: animation.target,
                    value: value,
                    time: elapsedTime,
                    isComplete: false
                )
                updates.append(update)
            }
        }
        
        // Remove completed animations (unless they loop)
        for id in completedAnimations {
            if let activeAnimation = animations[id],
               !activeAnimation.animation.repeats {
                animations.removeValue(forKey: id)
            }
        }
        
        return updates
    }
    
    /// Get all current animation values
    public func getCurrentValues() -> [AnimationTarget: AnimationValue] {
        var currentValues: [AnimationTarget: AnimationValue] = [:]
        
        for activeAnimation in animations.values {
            if activeAnimation.isPaused { continue }
            
            let elapsedTime = globalTime - activeAnimation.startTime
            let animation = activeAnimation.animation
            
            if !animation.isComplete(at: elapsedTime) {
                let value = animation.evaluate(at: elapsedTime)
                currentValues[animation.target] = value
            }
        }
        
        return currentValues
    }
    
    /// Reset timeline
    public func reset() {
        globalTime = 0.0
        animations.removeAll()
    }
    
    /// Get animation statistics
    public func getStatistics() -> TimelineStatistics {
        let activeCount = animations.values.filter { !$0.isPaused }.count
        let pausedCount = animations.values.filter { $0.isPaused }.count
        
        return TimelineStatistics(
            totalAnimations: animations.count,
            activeAnimations: activeCount,
            pausedAnimations: pausedCount,
            globalTime: globalTime,
            isPlaying: isPlaying
        )
    }
}

/// Active animation tracking
private struct ActiveAnimation: Sendable {
    let animation: any Animation
    let startTime: TimeInterval
    var isPaused: Bool
}

/// Animation update event
public struct AnimationUpdate: Sendable {
    public let animationID: UUID
    public let target: AnimationTarget
    public let value: AnimationValue
    public let time: TimeInterval
    public let isComplete: Bool
}

/// Timeline statistics
public struct TimelineStatistics: Sendable {
    public let totalAnimations: Int
    public let activeAnimations: Int
    public let pausedAnimations: Int
    public let globalTime: TimeInterval
    public let isPlaying: Bool
}

// MARK: - Animation Builder

/// Builder for creating animations with fluent interface
public class AnimationBuilder {
    private var target: AnimationTarget?
    private var duration: TimeInterval = 1.0
    private var keyframes: [Keyframe] = []
    private var curve: AnimationCurve = AnimationCurve()
    private var repeats: Bool = false
    private var repeatCount: UInt32 = 1
    private var interpolator: ValueInterpolator = DefaultValueInterpolator()
    
    public init() {}
    
    public func target(_ target: AnimationTarget) -> AnimationBuilder {
        self.target = target
        return self
    }
    
    public func duration(_ duration: TimeInterval) -> AnimationBuilder {
        self.duration = max(duration, 0.016) // Minimum 1ms
        return self
    }
    
    public func keyframe(_ time: Float, _ value: AnimationValue, easing: EasingFunction? = nil) -> AnimationBuilder {
        let keyframe = Keyframe(time: time, value: value, easing: easing)
        keyframes.append(keyframe)
        return self
    }
    
    public func curve(_ curve: AnimationCurve) -> AnimationBuilder {
        self.curve = curve
        return self
    }
    
    public func linear() -> AnimationBuilder {
        self.curve = AnimationCurve(type: .linear)
        return self
    }
    
    public func easeIn() -> AnimationBuilder {
        self.curve = AnimationCurve(type: .easeIn)
        return self
    }
    
    public func easeOut() -> AnimationBuilder {
        self.curve = AnimationCurve(type: .easeOut)
        return self
    }
    
    public func easeInOut() -> AnimationBuilder {
        self.curve = AnimationCurve(type: .easeInOut)
        return self
    }
    
    public func repeatCount(_ count: UInt32 = 0) -> AnimationBuilder {
        self.repeats = true
        self.repeatCount = count
        return self
    }
    
    public func interpolator(_ interpolator: ValueInterpolator) -> AnimationBuilder {
        self.interpolator = interpolator
        return self
    }
    
    public func build() throws -> KeyframeAnimation {
        guard let target = target else {
            throw CapsuleError.invalidConfiguration(
                reason: "Animation target is required"
            )
        }
        
        guard !keyframes.isEmpty else {
            throw CapsuleError.invalidConfiguration(
                reason: "At least one keyframe is required"
            )
        }
        
        // Ensure we have keyframes at start and end
        if keyframes.first?.time != 0.0 {
            let firstKeyframe = keyframes.first!
            keyframes.insert(Keyframe(time: 0.0, value: firstKeyframe.value), at: 0)
        }
        
        if keyframes.last?.time != 1.0 {
            let lastKeyframe = keyframes.last!
            keyframes.append(Keyframe(time: 1.0, value: lastKeyframe.value))
        }
        
        return KeyframeAnimation(
            target: target,
            duration: duration,
            keyframes: keyframes,
            curve: curve,
            repeats: repeats,
            repeatCount: repeatCount,
            interpolator: interpolator
        )
    }
}