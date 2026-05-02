import Foundation

/// Maturity levels for code and architectural components
public enum MaturityLevel: String, Codable, CaseIterable, Comparable {
    case prototype = "prototype"
    case experimental = "experimental"
    case functional = "functional"
    case stable = "stable"
    case production = "production"
    case hardened = "hardened"

    public static func < (lhs: MaturityLevel, rhs: MaturityLevel) -> Bool {
        let order: [MaturityLevel] = [.prototype, .experimental, .functional, .stable, .production, .hardened]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }

    public var description: String {
        switch self {
        case .prototype: return "Prototype - Basic implementation, many gaps"
        case .experimental: return "Experimental - Core features work, unstable"
        case .functional: return "Functional - Works but needs refinement"
        case .stable: return "Stable - Reliable, some improvements needed"
        case .production: return "Production - Ready for real-world use"
        case .hardened: return "Hardened - Battle-tested, highly secure"
        }
    }
}

/// Dimensions of code quality to assess
public enum QualityDimension: String, Codable, CaseIterable {
    case security
    case debuggability
    case auditability
    case stability
    case concurrency
    case errorHandling
    case testCoverage
    case documentation
    case performance
    case maintainability

    public var weight: Double {
        switch self {
        case .security: return 1.5
        case .stability: return 1.3
        case .errorHandling: return 1.2
        case .testCoverage: return 1.0
        case .auditability: return 1.0
        case .debuggability: return 0.9
        case .concurrency: return 0.8
        case .documentation: return 0.7
        case .performance: return 0.7
        case .maintainability: return 0.8
        }
    }
}

public struct DimensionAssessment: Codable {
    public let dimension: QualityDimension
    public let score: Double
    public let currentLevel: MaturityLevel
    public let targetLevel: MaturityLevel
    public let findings: [String]
    public let improvements: [Improvement]
}

public struct Improvement: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let dimension: QualityDimension
    public let impact: ImpactLevel
    public let effort: EffortLevel
    public let priority: Int
    public let codeLocations: [CodeLocation]
    public let suggestedChanges: [String]
    public let dependencies: [UUID]
    public let status: ImprovementStatus
}

public enum ImpactLevel: String, Codable, Comparable {
    case low, medium, high, critical

    public static func < (lhs: ImpactLevel, rhs: ImpactLevel) -> Bool {
        let order: [ImpactLevel] = [.low, .medium, .high, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

public enum EffortLevel: String, Codable, Comparable {
    case minimal, low, medium, high, extensive

    public static func < (lhs: EffortLevel, rhs: EffortLevel) -> Bool {
        let order: [EffortLevel] = [.minimal, .low, .medium, .high, .extensive]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

public enum ImprovementStatus: String, Codable {
    case suggested, prioritized, expanded, simplified
    case inProgress, completed, deferred, rejected
}

public struct CodeLocation: Codable {
    public let file: String
    public let line: Int?
    public let column: Int?
    public let snippet: String?
}

public struct MaturityAssessment: Codable {
    public let module: String
    public let timestamp: Date
    public let overallMaturity: MaturityLevel
    public let targetMaturity: MaturityLevel
    public let dimensions: [DimensionAssessment]
    public let improvements: [Improvement]
    public let buildWarnings: [BuildWarning]
    public let buildErrors: [BuildError]
    public let summary: String
}

public struct BuildWarning: Codable {
    public let message: String
    public let file: String?
    public let line: Int?
    public let suggestedFix: String?
}

public struct BuildError: Codable {
    public let message: String
    public let file: String?
    public let line: Int?
    public let suggestedFix: String?
}
