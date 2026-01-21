//
//  RefactoringTypes.swift
//  HarmoniaModule
//
//  Created by Anigma Agent on 2026-01-12.
//

import Foundation

/// Status of a refactoring task.
public enum RefactoringStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
    case validationFailed
    case reassigned
    case repairQueued
}

/// A refactoring task for an agent.
public struct RefactoringTask: Identifiable, Codable, Sendable {
    public let id: String
    public let type: String
    public let file: String
    public let line: Int
    public let description: String
    public let originalCode: String
    public let proposedCode: String
    public let metadata: [String: String]
    
    // Execution tracking
    public var status: RefactoringStatus = .pending
    public var assignedAgentId: Int?
    public var attemptCount: Int = 0
    public var maxAttempts: Int = 3
    
    // Results
    public var appliedCode: String?
    public var agentReasoning: String?
    public var errorMessage: String?
    public var validationError: String?
    
    // Failure history
    public var failureHistory: [RefactoringFailure] = []
    
    // Timestamps
    public var assignedAt: Date?
    public var completedAt: Date?
    
    // Repair specifics
    public var isRepairTask: Bool = false
    public var repairErrorMessage: String?
    
    public init(
        id: String,
        type: String,
        file: String,
        line: Int,
        description: String,
        originalCode: String,
        proposedCode: String = "",
        metadata: [String: String] = [:],
        status: RefactoringStatus = .pending,
        maxAttempts: Int = 3,
        isRepairTask: Bool = false,
        repairErrorMessage: String? = nil
    ) {
        self.id = id
        self.type = type
        self.file = file
        self.line = line
        self.description = description
        self.originalCode = originalCode
        self.proposedCode = proposedCode
        self.metadata = metadata
        self.status = status
        self.maxAttempts = maxAttempts
        self.isRepairTask = isRepairTask
        self.repairErrorMessage = repairErrorMessage
    }
}

/// Record of a failed refactoring attempt.
public struct RefactoringFailure: Codable, Sendable {
    public let attempt: Int
    public let attemptedCode: String
    public let error: String
    public let reasoning: String
    public let timestamp: Date
}

/// Results from a batch of refactorings.
public struct BatchResult: Codable, Sendable {
    public let batchId: Int
    public let tasksAttempted: Int
    public let tasksCompleted: Int
    public let tasksFailed: Int
    public let buildSuccessful: Bool
    public let buildOutput: String
    public let durationSeconds: TimeInterval
    public let timestamp: Date
}
