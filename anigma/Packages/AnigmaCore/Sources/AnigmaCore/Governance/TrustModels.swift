//
//  TrustModels.swift
//  AnigmaCore
//

import Foundation
import AnigmaPrimitives

/// Subject kind for trust state.
public enum TrustSubjectKind: String, Sendable, Codable {
    case engineType = "engine_type"
    case engineInstance = "engine_instance"
    case project = "project"
    case user = "user"
    case system = "system"
    case externalTool = "external_tool"
}

/// Trust state record.
public struct TrustStateRecord: Sendable, Codable {
    public let subjectId: String
    public let subjectKind: TrustSubjectKind
    public let currentTrustTier: TrustTier
    public let lastChangedAt: String
    public let changedBy: String?
    public let reason: String?
    public let signature: String?

    public init(
        subjectId: String,
        subjectKind: TrustSubjectKind,
        currentTrustTier: TrustTier,
        lastChangedAt: String,
        changedBy: String? = nil,
        reason: String? = nil,
        signature: String? = nil
    ) {
        self.subjectId = subjectId
        self.subjectKind = subjectKind
        self.currentTrustTier = currentTrustTier
        self.lastChangedAt = lastChangedAt
        self.changedBy = changedBy
        self.reason = reason
        self.signature = signature
    }
}

/// Trust statistics for observability.
public struct TrustStats: Sendable, Codable {
    public var totalSubjects: Int = 0
    public var recentChanges7d: Int = 0
    public var recentHistoryEntries: Int = 0
    public var subjectsByKind: [String: Int] = [:]
    public var subjectsByTier: [String: Int] = [:]
    public var scoreDistribution: [String: Int] = [:]
    public var averageScore: Double = 0.0
    public var minScore: Int = 0
    public var maxScore: Int = 0

    public init() {}

    public var averageTrust: Double {
        guard totalSubjects > 0 else { return 0.0 }

        let tierValues: [String: Double] = [
            "bronze": 0.25,
            "silver": 0.5,
            "gold": 0.75,
            "platinum": 1.0
        ]

        var totalValue = 0.0
        for (tier, count) in subjectsByTier {
            totalValue += (tierValues[tier] ?? 0.0) * Double(count)
        }

        return totalValue / Double(totalSubjects)
    }

    public var highTrustPercentage: Double {
        guard totalSubjects > 0 else { return 0.0 }
        let highTrustCount = subjectsByTier["gold", default: 0] + subjectsByTier["platinum", default: 0]
        return Double(highTrustCount) / Double(totalSubjects) * 100.0
    }

    public var scoreHealth: String {
        guard totalSubjects > 0 else { return "unknown" }

        if averageScore >= 70 {
            return "healthy"
        } else if averageScore >= 50 {
            return "moderate"
        } else if averageScore >= 30 {
            return "concerning"
        } else {
            return "critical"
        }
    }
}
