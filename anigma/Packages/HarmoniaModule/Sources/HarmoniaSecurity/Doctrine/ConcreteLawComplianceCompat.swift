//
//  ConcreteLawComplianceCompat.swift
//  HarmoniaModule
//
//  Minimal compatibility surface for law/compliance doctrine.
//  Keeps the old symbols available while avoiding the large legacy implementation.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import os.log
@preconcurrency import CryptoKit
import DoctrineCore
@preconcurrency import Foundation

private let log = Logger(subsystem: "com.anigma.harmonia", category: "enum")
public enum PIILevel: String, Sendable, Codable, CaseIterable {
    case nonPII = "non_pii"
    case pseudonymous = "pseudonymous"
    case identifiable = "identifiable"
    case sensitive = "sensitive"
}

public struct DataClassification: Sendable, Codable {
    public let level: PIILevel
    public let category: String
    public let retentionDays: Int?
    public let legalBasis: String?
    public let source: String

    public init(
        level: PIILevel,
        category: String,
        retentionDays: Int? = nil,
        legalBasis: String? = nil,
        source: String
    ) {
        self.level = level
        self.category = category
        self.retentionDays = retentionDays
        self.legalBasis = legalBasis
        self.source = source
    }
}

public struct DoctrinePrinciple: Sendable, Codable {
    public let id: String
    public let title: String
    public let description: String
    public let source: String
    public let severity: DoctrineSeverity

    public init(
        id: String,
        title: String,
        description: String,
        source: String,
        severity: DoctrineSeverity
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.source = source
        self.severity = severity
    }
}

private struct LawCompatCheckDescriptor: Sendable {
    let id: String
    let principleId: String
    let blocking: Bool
}

public struct ConcreteLawCompliancePack {
    public static let sources: [String: String] = [
        "gdpr": "Regulation (EU) 2016/679 (GDPR)",
        "wcag": "WCAG 2.1 Level AA",
        "ccpa": "California Consumer Privacy Act"
    ]

    public static let principles: [DoctrinePrinciple] = [
        DoctrinePrinciple(
            id: "gdpr_5_1_c",
            title: "Data minimisation",
            description: "PII fields must be classified and constrained.",
            source: "GDPR Article 5(1)(c)",
            severity: .error
        ),
        DoctrinePrinciple(
            id: "gdpr_5_1_e",
            title: "Storage limitation",
            description: "PII logging needs an explicit retention story.",
            source: "GDPR Article 5(1)(e)",
            severity: .error
        ),
        DoctrinePrinciple(
            id: "wcag_1_1_1",
            title: "Non-text content",
            description: "Images should have accessibility labels.",
            source: "WCAG 2.1 Success Criterion 1.1.1",
            severity: .warning
        ),
        DoctrinePrinciple(
            id: "gdpr_5_1_a",
            title: "Lawful basis",
            description: "Personal data processing needs a declared legal basis.",
            source: "GDPR Article 5(1)(a)",
            severity: .error
        ),
        DoctrinePrinciple(
            id: "wcag_2_2_1",
            title: "Timing adjustable",
            description: "Accessibility-sensitive timeouts should be at least 5 seconds.",
            source: "WCAG 2.1 Success Criterion 2.2.1",
            severity: .warning
        )
    ]

    private static let ruleDefinitions: [LawCompatCheckDescriptor] = [
        LawCompatCheckDescriptor(
            id: "law_pii_unclassified",
            principleId: "gdpr_5_1_c",
            blocking: true
        ),
        LawCompatCheckDescriptor(
            id: "law_pii_logging",
            principleId: "gdpr_5_1_e",
            blocking: true
        ),
        LawCompatCheckDescriptor(
            id: "law_accessibility_missing_alt",
            principleId: "wcag_1_1_1",
            blocking: false
        ),
        LawCompatCheckDescriptor(
            id: "law_processing_without_basis",
            principleId: "gdpr_5_1_a",
            blocking: true
        ),
        LawCompatCheckDescriptor(
            id: "law_accessibility_timeout",
            principleId: "wcag_2_2_1",
            blocking: false
        )
    ]

    private static var checkMetadataByID: [String: LawCompatCheckDescriptor] {
        Dictionary(uniqueKeysWithValues: ruleDefinitions.map { ($0.id, $0) })
    }

    public static var blockingCheckIDs: [String] {
        ruleDefinitions.filter(\.blocking).map(\.id)
    }

    public static let piiPatterns: [String: PIILevel] = [
        "email": .identifiable,
        "phone": .identifiable,
        "ssn": .sensitive,
        "social_security": .sensitive,
        "address": .identifiable,
        "dob": .sensitive,
        "birth": .sensitive,
        "name": .identifiable,
        "token": .sensitive,
        "password": .sensitive
    ]

    public static func classifyField(_ fieldName: String) -> PIILevel? {
        let lowered = fieldName.lowercased()
        for (pattern, level) in piiPatterns where lowered.contains(pattern) {
            return level
        }
        return nil
    }

    public static func principleID(forCheckID checkID: String) -> String? {
        checkMetadataByID[checkID]?.principleId
    }

    public static func isBlocking(checkID: String) -> Bool {
        checkMetadataByID[checkID]?.blocking ?? false
    }
}

public struct PIIConfiguration: Sendable, Codable {
    public let customPatterns: [String: PIILevel]
    public let excludedFields: [String]
    public let retentionDefaults: [PIILevel: Int]

    public init(
        customPatterns: [String: PIILevel] = [:],
        excludedFields: [String] = [],
        retentionDefaults: [PIILevel: Int] = [
            .nonPII: 365,
            .pseudonymous: 90,
            .identifiable: 30,
            .sensitive: 7
        ]
    ) {
        self.customPatterns = customPatterns
        self.excludedFields = excludedFields
        self.retentionDefaults = retentionDefaults
    }

    public static let `default` = PIIConfiguration()
}

public struct ConcreteLawComplianceScout: DoctrinalScout {
    public let domain: DoctrineDomain = .lawCompliance
    private let piiConfig: PIIConfiguration

    public init(piiConfig: PIIConfiguration = .default) {
        self.piiConfig = piiConfig
    }

    public func scan(fileAt path: String) async throws -> [DoctrineViolation] {
        guard path.hasSuffix(".swift") else { return [] }

        let source = try String(contentsOfFile: path, encoding: .utf8)
        let lines = source.components(separatedBy: .newlines)
        var violations: [DoctrineViolation] = []

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let lower = line.lowercased()

            if let fieldName = extractDeclaredFieldName(from: line),
               let piiLevel = classifyField(fieldName),
               !line.contains("@DataClassification"),
               !precedingLineContainsAnnotation(lines: lines, index: index, annotation: "@DataClassification"),
               !piiConfig.excludedFields.contains(fieldName) {
                violations.append(
                    makeViolation(
                        ruleId: "law_pii_unclassified",
                        severity: piiLevel == .sensitive ? .critical : .error,
                        filePath: path,
                        lineNumber: lineNumber,
                        message: "Unclassified PII field '\(fieldName)'",
                        context: "Field '\(fieldName)' looks like \(piiLevel.rawValue) PII"
                    )
                )
            }

            if containsPIILogging(lower) && matchedPIIPattern(in: lower) != nil &&
               !nearbyContains(lines: lines, index: index, needle: "@RetentionPolicy", window: 2) {
                violations.append(
                    makeViolation(
                        ruleId: "law_pii_logging",
                        severity: .error,
                        filePath: path,
                        lineNumber: lineNumber,
                        message: "PII logging without retention policy",
                        context: "Log statement appears to include PII"
                    )
                )
            }

            if (line.contains("Image(") || line.contains("AsyncImage(")) &&
               !nearbyContains(lines: lines, index: index, needle: "accessibilityLabel", window: 3) {
                violations.append(
                    makeViolation(
                        ruleId: "law_accessibility_missing_alt",
                        severity: .warning,
                        filePath: path,
                        lineNumber: lineNumber,
                        message: "Image without accessibility label",
                        context: "Add an accessibility label near image content"
                    )
                )
            }

            if containsDataProcessing(lower) &&
               !nearbyContainsAny(lines: lines, index: index, needles: ["@LegalBasis", "@ConsentRequired", "@ContractBasis", "consent", "legal basis"], window: 4) {
                violations.append(
                    makeViolation(
                        ruleId: "law_processing_without_basis",
                        severity: .error,
                        filePath: path,
                        lineNumber: lineNumber,
                        message: "Data processing without declared legal basis",
                        context: "Processing-related code should identify legal basis"
                    )
                )
            }

            if let timeout = extractTimeout(from: line), timeout < 5.0 {
                violations.append(
                    makeViolation(
                        ruleId: "law_accessibility_timeout",
                        severity: .warning,
                        filePath: path,
                        lineNumber: lineNumber,
                        message: "Timeout too short for accessibility",
                        context: "Detected timeout \(timeout)s"
                    )
                )
            }
        }

        return violations
    }

    private func classifyField(_ fieldName: String) -> PIILevel? {
        if let custom = piiConfig.customPatterns.first(where: { fieldName.lowercased().contains($0.key.lowercased()) }) {
            return custom.value
        }
        return ConcreteLawCompliancePack.classifyField(fieldName)
    }

    private func extractDeclaredFieldName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("let ") || trimmed.hasPrefix("var ") else { return nil }

        let withoutKeyword = trimmed.dropFirst(4)
        let separators = [":", "=", " "]
        let rawName = separators.reduce(String(withoutKeyword)) { partial, separator in
            partial.components(separatedBy: separator).first ?? partial
        }
        let fieldName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return fieldName.isEmpty ? nil : fieldName
    }

    private func precedingLineContainsAnnotation(lines: [String], index: Int, annotation: String) -> Bool {
        guard index > 0 else { return false }
        return lines[index - 1].contains(annotation)
    }

    private func nearbyContains(lines: [String], index: Int, needle: String, window: Int) -> Bool {
        nearbyContainsAny(lines: lines, index: index, needles: [needle], window: window)
    }

    private func nearbyContainsAny(lines: [String], index: Int, needles: [String], window: Int) -> Bool {
        let lowerBound = max(0, index - window)
        let upperBound = min(lines.count - 1, index + window)
        let context = lines[lowerBound...upperBound].joined(separator: "\n").lowercased()
        return needles.contains { context.contains($0.lowercased()) }
    }

    private func matchedPIIPattern(in line: String) -> String? {
        let allPatterns = Set(ConcreteLawCompliancePack.piiPatterns.keys).union(piiConfig.customPatterns.keys)
        return allPatterns.first { line.contains($0.lowercased()) }
    }

    private func containsPIILogging(_ line: String) -> Bool {
        ["log(", "debug(", "info(", "error(", "print("].contains { line.contains($0) }
    }

    private func containsDataProcessing(_ line: String) -> Bool {
        ["process", "collect", "store", "share", "transfer"].contains { line.contains($0) }
    }

    private func extractTimeout(from line: String) -> Double? {
        let patterns = [
            #"timeout\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)"#,
            #"delay\(([0-9]+(?:\.[0-9]+)?)"#,
            #"sleep\(([0-9]+(?:\.[0-9]+)?)"#
        ]

        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = regex?.firstMatch(in: line, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: line) {
                return Double(line[valueRange])
            }
        }

        return nil
    }

    private func makeViolation(
        ruleId: String,
        severity: DoctrineSeverity,
        filePath: String,
        lineNumber: Int,
        message: String,
        context: String
    ) -> DoctrineViolation {
        DoctrineViolation(
            ruleId: ruleId,
            severity: severity,
            message: message,
            filePath: filePath,
            lineNumber: lineNumber,
            context: context
        )
    }
}

public struct DoctrineDebtTask: Sendable, Codable {
    public let id: UUID
    public let violationId: UUID
    public let checkId: String
    public let principleId: String
    public let filePath: String?
    public let lineNumber: Int?
    public let description: String
    public let severity: DoctrineSeverity
    public let blocking: Bool
    public let suggestedRemediation: String
    public let createdAt: Date
    public let status: TaskStatus

    public enum TaskStatus: String, Sendable, Codable {
        case pending = "pending"
        case inProgress = "in_progress"
        case completed = "completed"
        case blocked = "blocked"
        case waived = "waived"
    }

    public init(
        id: UUID = UUID(),
        violationId: UUID,
        checkId: String,
        principleId: String,
        filePath: String? = nil,
        lineNumber: Int? = nil,
        description: String,
        severity: DoctrineSeverity,
        blocking: Bool,
        suggestedRemediation: String,
        createdAt: Date = Date(),
        status: TaskStatus = .pending
    ) {
        self.id = id
        self.violationId = violationId
        self.checkId = checkId
        self.principleId = principleId
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.description = description
        self.severity = severity
        self.blocking = blocking
        self.suggestedRemediation = suggestedRemediation
        self.createdAt = createdAt
        self.status = status
    }

    public static func fromViolation(_ violation: DoctrineViolation) -> DoctrineDebtTask? {
        let principleID = ConcreteLawCompliancePack.principleID(forCheckID: violation.ruleId) ?? "law_compat"
        let blocking = ConcreteLawCompliancePack.isBlocking(checkID: violation.ruleId) || violation.severity == .critical
        return DoctrineDebtTask(
            violationId: violationIdentifier(for: violation),
            checkId: violation.ruleId,
            principleId: principleID,
            filePath: violation.filePath,
            lineNumber: violation.lineNumber,
            description: violation.context ?? violation.message,
            severity: violation.severity,
            blocking: blocking,
            suggestedRemediation: remediation(for: violation.ruleId)
        )
    }

    private static func remediation(for ruleId: String) -> String {
        switch ruleId {
        case "law_pii_unclassified":
            return "Add @DataClassification to the field or rename it to avoid PII semantics."
        case "law_pii_logging":
            return "Avoid logging PII or annotate the retention policy."
        case "law_accessibility_missing_alt":
            return "Add an accessibility label near the image content."
        case "law_processing_without_basis":
            return "Document legal basis or consent for the processing step."
        case "law_accessibility_timeout":
            return "Increase the timeout to at least five seconds."
        default:
            return "Review and resolve the doctrine violation."
        }
    }

    private static func violationIdentifier(for violation: DoctrineViolation) -> UUID {
        let payload = [
            violation.ruleId,
            violation.filePath ?? "",
            "\(violation.lineNumber ?? -1)",
            "\(violation.columnNumber ?? -1)",
            violation.severity.rawValue,
            violation.context ?? ""
        ].joined(separator: "|")
        let digest = Insecure.MD5.hash(data: Data(payload.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let part1 = String(hex.prefix(8))
        let part2 = String(hex.dropFirst(8).prefix(4))
        let part3 = String(hex.dropFirst(12).prefix(4))
        let part4 = String(hex.dropFirst(16).prefix(4))
        let part5 = String(hex.dropFirst(20).prefix(12))
        let uuidString = [part1, part2, part3, part4, part5].joined(separator: "-")
        return UUID(uuidString: uuidString) ?? UUID()
    }
}
