import Foundation

public enum EvaluationMatrixDimension: String, Codable, Sendable, CaseIterable {
    case performance
    case safety
    case compliance
    case reliability
}

public enum EvaluationMatrixLabel: String, Codable, Sendable, CaseIterable {
    case pass
    case warn
    case fail
}

public struct EvaluationMatrixThreshold: Codable, Sendable, Equatable {
    public let dimension: EvaluationMatrixDimension
    public let minimumScore: Int
    public let label: EvaluationMatrixLabel

    public init(dimension: EvaluationMatrixDimension, minimumScore: Int, label: EvaluationMatrixLabel) {
        self.dimension = dimension
        self.minimumScore = minimumScore
        self.label = label
    }
}

public enum EvaluationMatrixSchema {
    public static let thresholds: [EvaluationMatrixThreshold] = [
        .init(dimension: .performance, minimumScore: 90, label: .pass),
        .init(dimension: .safety, minimumScore: 65, label: .warn),
        .init(dimension: .compliance, minimumScore: 90, label: .pass),
        .init(dimension: .reliability, minimumScore: 90, label: .pass)
    ]

    public static func label(for score: Int) -> EvaluationMatrixLabel {
        if score >= 90 {
            return .pass
        }
        if score >= 65 {
            return .warn
        }
        return .fail
    }

    public static func threshold(for dimension: EvaluationMatrixDimension) -> EvaluationMatrixThreshold {
        guard let threshold = thresholds.first(where: { $0.dimension == dimension }) else {
            return .init(dimension: dimension, minimumScore: 0, label: .fail)
        }
        return threshold
    }
}

public struct EvaluationMatrixFinding: Codable, Sendable, Equatable {
    public let name: EvaluationMatrixDimension
    public let status: EvaluationMatrixLabel
    public let score: Int
    public let evidence: [String]
    public let notes: [String]

    public init(
        name: EvaluationMatrixDimension,
        status: EvaluationMatrixLabel,
        score: Int,
        evidence: [String],
        notes: [String]
    ) {
        self.name = name
        self.status = status
        self.score = score
        self.evidence = evidence
        self.notes = notes
    }
}

public extension EvaluationMatrixFinding {
    var dimension: EvaluationMatrixDimension { name }
    var label: EvaluationMatrixLabel { status }
}

public typealias VerifierLaneMatrixDimension = EvaluationMatrixFinding
