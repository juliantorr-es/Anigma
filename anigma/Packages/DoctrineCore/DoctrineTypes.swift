//
//  DoctrineTypes.swift
//  DoctrineCore
//
//  HarmoniaModule/Doctrine
//
//  Shared doctrine type definitions that must be available
//  in GOVERNED_CORE mode for Phase 6+ integration.
//

import Foundation

/// Domain for doctrine packs.
public enum DoctrineDomain: String, Sendable, Codable, CaseIterable {
    case computerScience = "cs"
    case statistics = "stats"
    case lawCompliance = "law"
    case softwareEngineering = "swe"
    case accessibility = "a11y"
    case privacy = "privacy"
    case security = "security"
    case architecture = "architecture"
    case quality = "quality"
}

/// Severity level for doctrine violations.
public enum DoctrineViolationSeverity: String, Sendable, Codable, Comparable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"

    public static func < (lhs: DoctrineViolationSeverity, rhs: DoctrineViolationSeverity) -> Bool {
        let order: [DoctrineViolationSeverity] = [.info, .warning, .error, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }

}

public typealias DoctrineSeverity = DoctrineViolationSeverity

/// Check type for doctrine rules.
public enum CheckType: String, Sendable, Codable {
    case astPattern = "ast_pattern"
    case filePattern = "file_pattern"
    case testCoverage = "test_coverage"
    case dataFlow = "data_flow"
    case configuration = "configuration"
}

/// A doctrine violation found during scanning.
public struct DoctrineViolation: Sendable, Codable {
    public let id: UUID
    public let ruleId: String
    public let severity: DoctrineSeverity
    public let message: String
    public let filePath: String?
    public let lineNumber: Int?
    public let columnNumber: Int?
    public let context: String?
    public let detectedAt: Date
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        ruleId: String,
        severity: DoctrineSeverity,
        message: String,
        filePath: String?,
        lineNumber: Int? = nil,
        columnNumber: Int? = nil,
        context: String? = nil,
        detectedAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.ruleId = ruleId
        self.severity = severity
        self.message = message
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.context = context
        self.detectedAt = detectedAt
        self.metadata = metadata
    }
}

/// A static doctrine rule for legacy packs.
/// NOTE: Use `DoctrineRule` from VersionedDoctrinePacks.swift for governance logic.
public struct StaticDoctrineRule: Sendable, Codable {
    public let id: String
    public let domain: DoctrineDomain
    public let severity: DoctrineSeverity
    public let title: String
    public let description: String
    public let canonicalSource: String  // e.g., "ACM/IEEE-CS SWEBOK v3", "ASA Ethical Guidelines"
    public let checkType: CheckType
    public let parameters: [String: String]

    public init(
        id: String,
        domain: DoctrineDomain,
        severity: DoctrineSeverity,
        title: String,
        description: String,
        canonicalSource: String,
        checkType: CheckType,
        parameters: [String: String] = [:]
    ) {
        self.id = id
        self.domain = domain
        self.severity = severity
        self.title = title
        self.description = description
        self.canonicalSource = canonicalSource
        self.checkType = checkType
        self.parameters = parameters
    }
}

public protocol DoctrinePack: Sendable {
    func evaluate(for fileURL: URL) async throws -> [DoctrineViolation]
}

public final class DoctrineViolationStore: @unchecked Sendable {
    private var violationsByFile: [String: [DoctrineViolation]] = [:]

    public init() throws {}

    public func getViolations(inFile filePath: String) throws -> [DoctrineViolation] {
        violationsByFile[filePath] ?? []
    }

    public func recordViolation(_ violation: DoctrineViolation) throws {
        var list = violationsByFile[violation.filePath ?? ""] ?? []
        list.append(violation)
        violationsByFile[violation.filePath ?? ""] = list
    }

    public func clearViolations() {
        violationsByFile.removeAll()
    }

    public func saveViolation(_ violation: DoctrineViolation) throws {
        try recordViolation(violation)
    }

    public func getUnresolvedViolations() throws -> [DoctrineViolation] {
        return violationsByFile.values.flatMap { $0 }
    }
}

public enum DoctrineRegistry {
    public static func rule(withId id: String) -> StaticDoctrineRule? {
        nil
    }

    public static func domains(for filePath: String) -> [DoctrineDomain] {
        var domains: [DoctrineDomain] = [.computerScience, .softwareEngineering]

        let normalizedPath = filePath.lowercased()
        if normalizedPath.contains("data") || normalizedPath.contains("model") ||
            normalizedPath.contains("metric") || normalizedPath.contains("evaluation") {
            domains.append(.statistics)
        }

        if normalizedPath.contains("privacy") || normalizedPath.contains("consent") ||
            normalizedPath.contains("gdpr") || normalizedPath.contains("ccpa") {
            domains.append(.lawCompliance)
            domains.append(.privacy)
        }

        if normalizedPath.contains("accessibility") || normalizedPath.contains("a11y") {
            domains.append(.accessibility)
        }

        return Array(Set(domains))
    }
}
