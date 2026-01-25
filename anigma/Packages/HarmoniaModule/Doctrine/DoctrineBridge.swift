//
//  DoctrineBridge.swift
//  HarmoniaModule
//
//  Small adapter layer that keeps doctrine packs and scouts insulated from
//  DoctrineCore API churn while still exposing a stable rule/violation DSL.
//

@preconcurrency import Foundation
import DoctrineCore

public struct DoctrineBridgeRule: Sendable, Codable {
    public let id: String
    public let principleId: String
    public let title: String
    public let description: String
    public let implementationHint: CheckType?
    public let parameters: [String: String]
    public let blocking: Bool

    public init(
        id: String,
        principleId: String,
        title: String,
        description: String,
        implementationHint: CheckType? = nil,
        parameters: [String: String] = [:],
        blocking: Bool = false
    ) {
        self.id = id
        self.principleId = principleId
        self.title = title
        self.description = description
        self.implementationHint = implementationHint
        self.parameters = parameters
        self.blocking = blocking
    }
}

public struct DoctrineBridgeViolationInput: Sendable, Codable {
    public let id: UUID
    public let ruleId: String
    public let domain: DoctrineDomain
    public let severity: DoctrineSeverity
    public let message: String
    public let filePath: String?
    public let lineNumber: Int?
    public let columnNumber: Int?
    public let context: String?
    public let detectedAt: Date
    public let metadata: [String: String]
    public let parameters: [String: String]?

    public init(
        id: UUID = UUID(),
        ruleId: String,
        domain: DoctrineDomain,
        severity: DoctrineSeverity,
        message: String,
        filePath: String?,
        lineNumber: Int? = nil,
        columnNumber: Int? = nil,
        context: String? = nil,
        detectedAt: Date = Date(),
        metadata: [String: String] = [:],
        parameters: [String: String]? = nil
    ) {
        self.id = id
        self.ruleId = ruleId
        self.domain = domain
        self.severity = severity
        self.message = message
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.context = context
        self.detectedAt = detectedAt
        self.metadata = metadata
        self.parameters = parameters
    }
}

public struct DoctrineCheck: Sendable, Codable {
    public let id: String
    public let principleId: String
    public let title: String
    public let description: String
    public let implementation: DoctrineCheck.CheckImplementation
    public let parameters: [String: String]
    public let blocking: Bool

    public enum CheckImplementation: String, Sendable, Codable {
        case astPattern = "ast_pattern"
        case filePattern = "file_pattern"
        case testCoverage = "test_coverage"
        case dataFlow = "data_flow"
        case configuration = "configuration"
    }

    public init(
        id: String,
        principleId: String,
        title: String,
        description: String,
        implementation: DoctrineCheck.CheckImplementation,
        parameters: [String: String] = [:],
        blocking: Bool = false
    ) {
        self.id = id
        self.principleId = principleId
        self.title = title
        self.description = description
        self.implementation = implementation
        self.parameters = parameters
        self.blocking = blocking
    }
}

public enum DoctrineBridge {
    public static func makeCheck(rule: DoctrineBridgeRule) -> DoctrineCheck {
        let implementation = mapImplementation(rule.implementationHint)
        return DoctrineCheck(
            id: rule.id,
            principleId: rule.principleId,
            title: rule.title,
            description: rule.description,
            implementation: implementation,
            parameters: rule.parameters,
            blocking: rule.blocking
        )
    }

    public static func makeViolation(input: DoctrineBridgeViolationInput) -> DoctrineViolation {
        DoctrineViolation(
            id: input.id,
            ruleId: input.ruleId,
            severity: input.severity,
            message: input.message,
            filePath: input.filePath,
            lineNumber: input.lineNumber,
            columnNumber: input.columnNumber,
            context: input.context,
            detectedAt: input.detectedAt,
            metadata: input.metadata
        )
    }

    private static func mapImplementation(_ hint: CheckType?) -> DoctrineCheck.CheckImplementation {
        guard let hint = hint else {
            return .configuration
        }

        switch hint {
        case .astPattern:
            return .astPattern
        case .filePattern:
            return .filePattern
        case .testCoverage:
            return .testCoverage
        case .dataFlow:
            return .dataFlow
        case .configuration:
            return .configuration
        }
    }
}
