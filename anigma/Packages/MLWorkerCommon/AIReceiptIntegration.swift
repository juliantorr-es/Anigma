//
//  AIReceiptIntegration.swift
//  MLWorkerCommon
//
//  Integration layer for AI operation receipt generation and transparency.
//  Hooks into MLWorker and tool execution to capture comprehensive AI operation data.
//

import Foundation

// MARK: - AI Receipt Integration Manager

/// Central manager for AI operation receipt integration
/// Coordinates receipt generation across different AI systems
public actor AIReceiptIntegration {
    
    /// Shared instance for global access
    public static let shared = AIReceiptIntegration()
    
    /// Flag to enable/disable AI receipt generation
    private var isEnabled: Bool = true
    
    /// Current session identifier for correlating operations
    private var currentSessionID: String?
    
    /// Statistics for the current session
    private var sessionStats: SessionStats = SessionStats()
    
    private init() {}
    
    /// Configure the integration with session ID
    public func configure(sessionID: String? = nil) {
        self.currentSessionID = sessionID ?? UUID().uuidString
    }
    
    /// Enable or disable AI receipt generation
    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }
    
    /// Record an AI operation start
    public func recordAIOperationStart(
        operationID: String,
        modelID: String,
        taskType: String, // Using String instead of enum for compatibility
        inputs: [String: Any],
        provider: String = "unknown"
    ) async -> AIOperationContext? {
        
        guard isEnabled else {
            return nil
        }
        
        let startTime = Date()
        
        // Create operation context
        let context = AIOperationContext(
            operationID: operationID,
            modelID: modelID,
            taskType: taskType,
            inputs: inputs,
            provider: provider,
            startTime: startTime,
            sessionID: currentSessionID ?? "default-session"
        )
        
        // Emit start telemetry
        await emitOperationStartTelemetry(context: context)
        
        return context
    }
    
    /// Record an AI operation completion
    public func recordAIOperationCompletion(
        context: AIOperationContext,
        outputs: [String: Any]? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        error: Error? = nil
    ) async {
        
        guard isEnabled else {
            return
        }
        
        let endTime = Date()
        let inferenceTimeMs = Int64(endTime.timeIntervalSince(context.startTime) * 1000)
        
        // Update session statistics
        sessionStats.recordOperation(
            taskType: context.taskType,
            provider: context.provider,
            modelID: context.modelID,
            inferenceTimeMs: inferenceTimeMs,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            success: error == nil
        )
        
        // Emit completion telemetry
        await emitOperationCompletionTelemetry(
            context: context,
            inferenceTimeMs: inferenceTimeMs,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            error: error
        )
    }
    
    /// Record a tool execution
    public func recordToolExecution(
        toolName: String,
        toolType: String,
        inputs: [String: Any],
        outputs: [String: Any]? = nil,
        executionTimeMs: Int64,
        exitCode: Int32? = nil,
        workflowID: String? = nil
    ) async {
        
        guard isEnabled else {
            return
        }
        
        sessionStats.recordToolExecution(
            toolName: toolName,
            toolType: toolType,
            executionTimeMs: executionTimeMs,
            success: exitCode == 0 || exitCode == nil
        )
    }
    
    /// Get current session statistics
    public func getSessionStats() -> SessionStats {
        return sessionStats
    }
    
    /// Reset session statistics
    public func resetSessionStats() {
        sessionStats = SessionStats()
    }
    
    // MARK: - Private Methods
    
    private func emitOperationStartTelemetry(context: AIOperationContext) async {
        print("🤖 AI Operation Started: \(context.operationID) (\(context.taskType))")
    }
    
    private func emitOperationCompletionTelemetry(
        context: AIOperationContext,
        inferenceTimeMs: Int64,
        inputTokens: Int?,
        outputTokens: Int?,
        error: Error?
    ) async {
        if let error = error {
            print("❌ AI Operation Failed: \(context.operationID) - \(error.localizedDescription)")
        } else {
            let totalTokens = (inputTokens ?? 0) + (outputTokens ?? 0)
            let tokensStr = totalTokens > 0 ? "(\(totalTokens) tokens)" : ""
            print("✅ AI Operation Completed: \(context.operationID) \(tokensStr) in \(inferenceTimeMs)ms")
        }
    }
}

// MARK: - AI Operation Context

/// Context for tracking an AI operation from start to completion
public struct AIOperationContext: Sendable {
    public let operationID: String
    public let modelID: String
    public let taskType: String
    public let inputs: [String: String] // Changed from Any to String for Sendable compliance
    public let provider: String
    public let startTime: Date
    public let sessionID: String
    
    public init(
        operationID: String,
        modelID: String,
        taskType: String,
        inputs: [String: Any],
        provider: String,
        startTime: Date,
        sessionID: String
    ) {
        self.operationID = operationID
        self.modelID = modelID
        self.taskType = taskType
        // Convert inputs to strings for Sendable compliance
        self.inputs = inputs.mapValues { "\($0)" }
        self.provider = provider
        self.startTime = startTime
        self.sessionID = sessionID
    }
}

// MARK: - Session Statistics

/// Statistics for AI operations in the current session
public struct SessionStats: Codable, Sendable {
    public private(set) var totalOperations: Int = 0
    public private(set) var totalToolExecutions: Int = 0
    public private(set) var successfulOperations: Int = 0
    public private(set) var failedOperations: Int = 0
    public private(set) var totalInferenceTimeMs: Int64 = 0
    public private(set) var totalInputTokens: Int = 0
    public private(set) var totalOutputTokens: Int = 0
    public var providerStats: [String: Int] = [:]
    public var taskTypeStats: [String: Int] = [:]
    public var modelStats: [String: Int] = [:]
    public var toolStats: [String: Int] = [:]
    
    public init() {}
    
    mutating func recordOperation(
        taskType: String,
        provider: String,
        modelID: String,
        inferenceTimeMs: Int64,
        inputTokens: Int?,
        outputTokens: Int?,
        success: Bool
    ) {
        totalOperations += 1
        totalInferenceTimeMs += inferenceTimeMs
        
        if success {
            successfulOperations += 1
        } else {
            failedOperations += 1
        }
        
        providerStats[provider, default: 0] += 1
        taskTypeStats[taskType, default: 0] += 1
        modelStats[modelID, default: 0] += 1
        
        if let inputTokens = inputTokens {
            totalInputTokens += inputTokens
        }
        if let outputTokens = outputTokens {
            totalOutputTokens += outputTokens
        }
    }
    
    mutating func recordToolExecution(
        toolName: String,
        toolType: String,
        executionTimeMs: Int64,
        success: Bool
    ) {
        totalToolExecutions += 1
        toolStats[toolName, default: 0] += 1
    }
    
    public var successRate: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(successfulOperations) / Double(totalOperations)
    }
    
    public var averageInferenceTimeMs: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(totalInferenceTimeMs) / Double(totalOperations)
    }
    
    public var totalTokens: Int {
        return totalInputTokens + totalOutputTokens
    }
}