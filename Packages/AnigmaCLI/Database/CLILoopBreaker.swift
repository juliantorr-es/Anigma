//
//  CLILoopBreaker.swift
//  AnigmaCLIDatabase
//
//  Safety limits and loop breaker implementation.
//  Enforces maximum steps, time, tokens, and detects repeated/no-novelty patterns.
//

import Foundation

/// Configuration for loop breaker limits.
public struct LoopBreakerConfig: Sendable {
    public let maxSteps: Int
    public let maxToolCalls: Int
    public let maxWallTimeSeconds: TimeInterval
    public let maxTokens: Int?
    public let maxSpend: Double?
    public let repeatedCallThreshold: Int
    public let noNoveltyWindow: Int

    public init(
        maxSteps: Int = 50,
        maxToolCalls: Int = 100,
        maxWallTimeSeconds: TimeInterval = 1800, // 30 minutes
        maxTokens: Int? = nil,
        maxSpend: Double? = nil,
        repeatedCallThreshold: Int = 3,
        noNoveltyWindow: Int = 3
    ) {
        self.maxSteps = maxSteps
        self.maxToolCalls = maxToolCalls
        self.maxWallTimeSeconds = maxWallTimeSeconds
        self.maxTokens = maxTokens
        self.maxSpend = maxSpend
        self.repeatedCallThreshold = repeatedCallThreshold
        self.noNoveltyWindow = noNoveltyWindow
    }

    public static let `default` = LoopBreakerConfig()
}

/// Loop breaker that enforces safety limits during execution.
public actor CLILoopBreaker {
    private let config: LoopBreakerConfig
    private let runID: String
    private let startTime: Date

    // Counters
    private var stepCount: Int = 0
    private var toolCallCount: Int = 0
    private var tokenCount: Int = 0
    private var spendAmount: Double = 0.0

    // Pattern tracking
    private var recentToolCalls: [String] = []
    private var recentNoveltyHashes: [String] = []

    public init(runID: String, config: LoopBreakerConfig = .default) {
        self.runID = runID
        self.config = config
        self.startTime = Date()
    }

    // MARK: - Limit Checking

    /// Check if execution should stop based on current state.
    public func shouldStop() -> LoopBreakerResult? {
        // Check step limit
        if stepCount >= config.maxSteps {
            return LoopBreakerResult(
                reason: .maxStepsReached,
                message: "Maximum steps (\(config.maxSteps)) exceeded",
                counters: getCurrentCounters()
            )
        }

        // Check tool call limit
        if toolCallCount >= config.maxToolCalls {
            return LoopBreakerResult(
                reason: .maxToolCallsReached,
                message: "Maximum tool calls (\(config.maxToolCalls)) exceeded",
                counters: getCurrentCounters()
            )
        }

        // Check wall time
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed >= config.maxWallTimeSeconds {
            return LoopBreakerResult(
                reason: .maxTimeReached,
                message: "Maximum wall time (\(Int(config.maxWallTimeSeconds))s) exceeded",
                counters: getCurrentCounters()
            )
        }

        // Check token limit if configured
        if let maxTokens = config.maxTokens, tokenCount >= maxTokens {
            return LoopBreakerResult(
                reason: .maxTokensReached,
                message: "Maximum tokens (\(maxTokens)) exceeded",
                counters: getCurrentCounters()
            )
        }

        // Check spend limit if configured
        if let maxSpend = config.maxSpend, spendAmount >= maxSpend {
            return LoopBreakerResult(
                reason: .maxSpendReached,
                message: "Maximum spend ($\(maxSpend)) exceeded",
                counters: getCurrentCounters()
            )
        }

        // Check for repeated calls
        if let repeatedCall = detectRepeatedCall() {
            return LoopBreakerResult(
                reason: .repeatedCallsDetected,
                message: "Repeated call detected: \(repeatedCall) (\(config.repeatedCallThreshold)x)",
                counters: getCurrentCounters()
            )
        }

        // Check for no novelty
        if detectNoNovelty() {
            return LoopBreakerResult(
                reason: .noNoveltyDetected,
                message: "No novelty detected in last \(config.noNoveltyWindow) steps",
                counters: getCurrentCounters()
            )
        }

        return nil
    }

    // MARK: - Counter Updates

    /// Record a step execution.
    public func recordStep() {
        stepCount += 1
    }

    /// Record a tool call.
    public func recordToolCall(toolName: String, args: String) {
        toolCallCount += 1

        // Track for repeated call detection
        let callSignature = "\(toolName):\(args)"
        recentToolCalls.append(callSignature)

        // Keep only recent calls
        if recentToolCalls.count > config.repeatedCallThreshold * 2 {
            recentToolCalls.removeFirst()
        }
    }

    /// Record token usage.
    public func recordTokens(count: Int) {
        tokenCount += count
    }

    /// Record spending.
    public func recordSpend(amount: Double) {
        spendAmount += amount
    }

    /// Record novelty (file changes, new evidence).
    public func recordNovelty(hash: String) {
        recentNoveltyHashes.append(hash)

        // Keep only recent novelty
        if recentNoveltyHashes.count > config.noNoveltyWindow {
            recentNoveltyHashes.removeFirst()
        }
    }

    // MARK: - Pattern Detection

    private func detectRepeatedCall() -> String? {
        guard recentToolCalls.count >= config.repeatedCallThreshold else {
            return nil
        }

        // Check if the last N calls are identical
        let windowSize = config.repeatedCallThreshold
        let window = recentToolCalls.suffix(windowSize)

        if Set(window).count == 1 {
            return window.first
        }

        return nil
    }

    private func detectNoNovelty() -> Bool {
        guard stepCount >= config.noNoveltyWindow else {
            return false
        }

        // If we haven't recorded any novelty in the window, flag it
        return recentNoveltyHashes.count < config.noNoveltyWindow
    }

    // MARK: - State Inspection

    /// Get current counter values.
    public func getCurrentCounters() -> LoopBreakerCounters {
        let elapsed = Date().timeIntervalSince(startTime)

        return LoopBreakerCounters(
            steps: stepCount,
            toolCalls: toolCallCount,
            tokens: tokenCount,
            spend: spendAmount,
            wallTimeSeconds: elapsed,
            lastAction: recentToolCalls.last
        )
    }

    /// Get configuration.
    public func getConfig() -> LoopBreakerConfig {
        config
    }
}

// MARK: - Supporting Types

public struct LoopBreakerResult: Sendable {
    public let reason: LoopBreakerReason
    public let message: String
    public let counters: LoopBreakerCounters

    public init(reason: LoopBreakerReason, message: String, counters: LoopBreakerCounters) {
        self.reason = reason
        self.message = message
        self.counters = counters
    }
}

public enum LoopBreakerReason: String, Sendable {
    case maxStepsReached = "max_steps"
    case maxToolCallsReached = "max_tool_calls"
    case maxTimeReached = "max_time"
    case maxTokensReached = "max_tokens"
    case maxSpendReached = "max_spend"
    case repeatedCallsDetected = "repeated_calls"
    case noNoveltyDetected = "no_novelty"
}

public struct LoopBreakerCounters: Sendable, Codable {
    public let steps: Int
    public let toolCalls: Int
    public let tokens: Int
    public let spend: Double
    public let wallTimeSeconds: TimeInterval
    public let lastAction: String?

    public init(
        steps: Int,
        toolCalls: Int,
        tokens: Int,
        spend: Double,
        wallTimeSeconds: TimeInterval,
        lastAction: String?
    ) {
        self.steps = steps
        self.toolCalls = toolCalls
        self.tokens = tokens
        self.spend = spend
        self.wallTimeSeconds = wallTimeSeconds
        self.lastAction = lastAction
    }
}

// MARK: - Receipt Integration

extension CLIReceiptManager {
    /// Generate a loop breaker stop receipt.
    public func recordLoopBreaker(
        runID: String,
        result: LoopBreakerResult
    ) async throws -> Receipt {
        let receiptID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        // Encode counters as metadata
        let encoder = JSONEncoder()
        let countersData = try encoder.encode(result.counters)
        _ = String(data: countersData, encoding: .utf8) ?? "{}"

        var metadata: [String: String] = [
            "reason": result.reason.rawValue,
            "message": result.message,
            "steps": String(result.counters.steps),
            "tool_calls": String(result.counters.toolCalls),
            "tokens": String(result.counters.tokens),
            "spend": String(result.counters.spend),
            "wall_time": String(format: "%.2f", result.counters.wallTimeSeconds)
        ]

        if let lastAction = result.counters.lastAction {
            metadata["last_action"] = lastAction
        }

        try await storeReceipt(
            receiptID: receiptID,
            runID: runID,
            stepID: nil,
            type: ReceiptType.loopBreaker,
            requestHash: hash(result.reason.rawValue),
            responseHash: hash(result.message),
            metadata: metadata,
            timestamp: now
        )

        return Receipt(
            receiptID: receiptID,
            runID: runID,
            stepID: nil,
            type: .loopBreaker,
            requestHash: hash(result.reason.rawValue),
            responseHash: hash(result.message),
            metadata: metadata,
            timestamp: now
        )
    }

    private func hash(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// Import for SHA256
import Crypto
