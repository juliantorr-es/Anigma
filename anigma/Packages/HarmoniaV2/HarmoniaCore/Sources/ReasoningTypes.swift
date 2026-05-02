//
//  ReasoningTypes.swift
//  HarmoniaCore
//
//  Core types for structured reasoning and two-tier reasoning.
//  Migrated from HarmoniaModule - Pure value types with zero side effects.
//

import Foundation

// MARK: - Reasoning Models

/// Result from two-tier reasoning combining symbolic and neural approaches.
public struct TwoTierResult: Sendable, Codable {
    public let symbolicResult: SymbolicResult?
    public let neuralResult: NeuralResult?
    public let confidence: Double
    public let timestamp: Date
    
    public init(
        symbolicResult: SymbolicResult? = nil,
        neuralResult: NeuralResult? = nil,
        confidence: Double = 0.5,
        timestamp: Date = Date()
    ) {
        self.symbolicResult = symbolicResult
        self.neuralResult = neuralResult
        self.confidence = confidence
        self.timestamp = timestamp
    }
    
    /// Returns true if both tiers produced results
    public var isHybrid: Bool {
        symbolicResult != nil && neuralResult != nil
    }
    
    /// Returns the tier with highest confidence
    public var dominantTier: ReasoningTier {
        guard let symbolic = symbolicResult, let neural = neuralResult else {
            if symbolicResult != nil { return .symbolic }
            if neuralResult != nil { return .neural }
            return .hybrid
        }
        
        // Symbolic tier gets bonus for zero violations
        let symbolicConfidence = symbolic.violatedConstraints.isEmpty ? 0.9 : 0.3
        return symbolicConfidence > neural.confidence ? .symbolic : .neural
    }
}

/// Result from symbolic (TRM) tier - rule-based reasoning with constraints.
public struct SymbolicResult: Sendable, Codable {
    public let solution: String?
    public let violatedConstraints: [String]
    public let satisfiedConstraints: [String]
    public let reasoningTrace: [String]
    
    public init(
        solution: String? = nil,
        violatedConstraints: [String] = [],
        satisfiedConstraints: [String] = [],
        reasoningTrace: [String] = []
    ) {
        self.solution = solution
        self.violatedConstraints = violatedConstraints
        self.satisfiedConstraints = satisfiedConstraints
        self.reasoningTrace = reasoningTrace
    }
    
    /// Returns true if all constraints were satisfied
    public var isValid: Bool {
        violatedConstraints.isEmpty
    }
}

/// Result from neural tier - learned pattern matching with confidence.
public struct NeuralResult: Sendable, Codable {
    public let output: String
    public let confidence: Double
    public let modelUsed: String?
    
    public init(output: String, confidence: Double = 0.5, modelUsed: String? = nil) {
        self.output = output
        self.confidence = confidence
        self.modelUsed = modelUsed
    }
}

// MARK: - Puzzle Types

/// A reasoning puzzle for structured reasoning.
public struct ReasoningPuzzle: Sendable, Codable {
    public let id: String
    public let description: String
    public let constraints: [String]
    public let metadata: [String: String]
    public let difficulty: DifficultyLevel
    
    public init(
        id: String,
        description: String,
        constraints: [String] = [],
        metadata: [String: String] = [:],
        difficulty: DifficultyLevel = .medium
    ) {
        self.id = id
        self.description = description
        self.constraints = constraints
        self.metadata = metadata
        self.difficulty = difficulty
    }
}

/// Difficulty level for reasoning tasks.
public enum DifficultyLevel: String, Sendable, Codable {
    case trivial
    case easy
    case medium
    case hard
    case expert
}

/// A structured subproblem in a reasoning hierarchy.
public struct StructuredSubproblem: Sendable, Codable {
    public let id: String
    public let description: String
    public let parentId: String?
    public let dependencies: [String]
    
    public init(
        id: String,
        description: String,
        parentId: String? = nil,
        dependencies: [String] = []
    ) {
        self.id = id
        self.description = description
        self.parentId = parentId
        self.dependencies = dependencies
    }
}

// MARK: - TRM Config

/// Configuration for Temporal Reasoning Models.
public struct TRMConfig: Sendable, Codable {
    public let scratchpadSize: Int
    public let canvasSize: Int
    public let slowUpdateInterval: Int
    public let maxIterations: Int
    
    public init(
        scratchpadSize: Int = 256,
        canvasSize: Int = 256,
        slowUpdateInterval: Int = 3,
        maxIterations: Int = 100
    ) {
        self.scratchpadSize = scratchpadSize
        self.canvasSize = canvasSize
        self.slowUpdateInterval = slowUpdateInterval
        self.maxIterations = maxIterations
    }
    
    public static let `default` = TRMConfig()
}

// MARK: - Reasoning Tier

/// Reasoning tier classification for hybrid systems.
public enum ReasoningTier: String, Sendable, Codable, CaseIterable {
    case symbolic  // Fast, rule-based, deterministic
    case neural    // Learned patterns, probabilistic
    case hybrid    // Combined approach with fallback
}

// MARK: - Structured Reasoning Input

/// Structured input for reasoning tasks with context.
public struct StructuredReasoningInput: Sendable, Codable {
    public let query: String
    public let context: [String: String]
    public let requiredConstraints: [String]
    public let optionalHints: [String]
    
    public init(
        query: String,
        context: [String: String] = [:],
        requiredConstraints: [String] = [],
        optionalHints: [String] = []
    ) {
        self.query = query
        self.context = context
        self.requiredConstraints = requiredConstraints
        self.optionalHints = optionalHints
    }
}
