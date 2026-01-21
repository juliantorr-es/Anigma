//
//  MemorySessionSummary.swift
//  HarmoniaMemory
//
//  Summary of a session's activity for quick retrieval and analysis.
//

import Foundation
import AnigmaCore

/// Summary of a session's activity.
public struct MemorySessionSummary: Codable, Sendable, Identifiable {
    /// Unique summary identifier.
    public let id: UUID

    /// Session identifier.
    public let sessionId: String

    /// Tenant identifier.
    public let tenantId: String

    /// When the session started.
    public let sessionStart: Date

    /// When the session ended (nil if still active).
    public var sessionEnd: Date?

    /// Total number of observations in session.
    public var observationCount: Int

    /// Number of tool calls.
    public var toolCallCount: Int

    /// Number of successful tool results.
    public var toolSuccessCount: Int

    /// Number of tool errors.
    public var toolErrorCount: Int

    /// Number of decisions.
    public var decisionCount: Int

    /// Tags extracted from session observations.
    public var sessionTags: [String]

    /// User/agent associated with session.
    public var agentId: String?

    /// Mode (plan/build) of session.
    public var mode: String?

    /// Model used in session.
    public var model: String?

    /// Whether session is considered sensitive.
    public var isSensitive: Bool

    /// Summary text (AI-generated or extracted).
    public var summaryText: String?

    /// When summary was last updated.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sessionId: String,
        tenantId: String,
        sessionStart: Date = Date(),
        sessionEnd: Date? = nil,
        observationCount: Int = 0,
        toolCallCount: Int = 0,
        toolSuccessCount: Int = 0,
        toolErrorCount: Int = 0,
        decisionCount: Int = 0,
        sessionTags: [String] = [],
        agentId: String? = nil,
        mode: String? = nil,
        model: String? = nil,
        isSensitive: Bool = false,
        summaryText: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.tenantId = tenantId
        self.sessionStart = sessionStart
        self.sessionEnd = sessionEnd
        self.observationCount = observationCount
        self.toolCallCount = toolCallCount
        self.toolSuccessCount = toolSuccessCount
        self.toolErrorCount = toolErrorCount
        self.decisionCount = decisionCount
        self.sessionTags = sessionTags
        self.agentId = agentId
        self.mode = mode
        self.model = model
        self.isSensitive = isSensitive
        self.summaryText = summaryText
        self.updatedAt = updatedAt
    }

    /// Updates summary with a new observation.
    public mutating func update(with observation: MemoryObservation) {
        observationCount += 1
        updatedAt = Date()

        switch observation.observationType {
        case .toolCall:
            toolCallCount += 1
        case .toolResult:
            toolSuccessCount += 1
        case .toolError:
            toolErrorCount += 1
        case .decision:
            decisionCount += 1
        default:
            break
        }

        // Merge tags
        let newTags = Set(observation.tags)
        let existingTags = Set(sessionTags)
        sessionTags = Array(existingTags.union(newTags))

        // Update sensitivity
        if observation.isSensitive {
            isSensitive = true
        }
    }

    /// Ends the session.
    public mutating func endSession() {
        sessionEnd = Date()
        updatedAt = Date()
    }
}

// MARK: - ECS Component

extension MemorySessionSummary: Component {}

// MARK: - Convenience

extension MemorySessionSummary {
    /// Creates an initial summary for a new session.
    public static func initial(
        sessionId: String,
        tenantId: String,
        agentId: String? = nil,
        mode: String? = nil,
        model: String? = nil
    ) -> MemorySessionSummary {
        MemorySessionSummary(
            sessionId: sessionId,
            tenantId: tenantId,
            sessionStart: Date(),
            agentId: agentId,
            mode: mode,
            model: model
        )
    }

    /// Success rate for tool calls (0-100).
    public var toolSuccessRate: Double {
        guard toolCallCount > 0 else { return 0 }
        return Double(toolSuccessCount) / Double(toolCallCount) * 100.0
    }

    /// Error rate for tool calls (0-100).
    public var toolErrorRate: Double {
        guard toolCallCount > 0 else { return 0 }
        return Double(toolErrorCount) / Double(toolCallCount) * 100.0
    }

    /// Session duration in seconds (nil if session hasn't ended).
    public var sessionDurationSeconds: TimeInterval? {
        guard let end = sessionEnd else { return nil }
        return end.timeIntervalSince(sessionStart)
    }

    /// Whether session is active.
    public var isActive: Bool {
        sessionEnd == nil
    }
}
