//
//  ConcreteLawCompliancePack.swift
//  HarmoniaModule
//
//  Concrete Law/Compliance doctrine pack v0.
//  Actually binds to GDPR, NIST Privacy Framework, WCAG 2.1.
//  Not vibes - actual checklists and invariants.
//

@preconcurrency import CryptoKit
import DoctrineCore
@preconcurrency import Foundation

/// PII classification levels.
public enum PIILevel: String, Sendable, Codable {
    case nonPII = "non_pii"
    case pseudonymous = "pseudonymous"
    case identifiable = "identifiable"
    case sensitive = "sensitive"
}

/// Data classification annotation.
public struct DataClassification: Sendable, Codable {
    public let level: PIILevel
    public let category: String  // e.g., "contact", "financial", "health"
    public let retentionDays: Int?
    public let legalBasis: String?  // e.g., "consent", "contract", "legal_obligation"
    public let source: String  // e.g., "GDPR Article 6", "CCPA §1798.100"

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

/// Concrete Law/Compliance doctrine pack v0.
public struct ConcreteLawCompliancePack {
    // MARK: - Canonical Sources (Versioned)

    public static let sources: [String: String] = [
        "gdpr": "Regulation (EU) 2016/679 (GDPR) - Articles 5, 6, 17, 25, 32",
        "nist_privacy":
            "NIST Privacy Framework v1.0 - Core: Identify, Govern, Control, Communicate, Protect",
        "wcag": "Web Content Accessibility Guidelines (WCAG) 2.1 Level AA",
        "ada": "Americans with Disabilities Act (ADA) Title III",
        "ccpa": "California Consumer Privacy Act (CCPA) §1798.100-199"
    ]

    // MARK: - Principles (From Canon)

    public static let principles: [DoctrinePrinciple] = [
        // GDPR Article 5: Principles relating to processing of personal data
        DoctrinePrinciple(
            id: "gdpr_5_1_a",
            title: "Lawfulness, fairness and transparency",
            description:
                "Personal data shall be processed lawfully, fairly and in a transparent manner.",
            source: "GDPR Article 5(1)(a)",
            severity: DoctrineCore.DoctrineSeverity.critical
        ),

        DoctrinePrinciple(
            id: "gdpr_5_1_b",
            title: "Purpose limitation",
            description:
                "Personal data shall be collected for specified, explicit and legitimate purposes.",
            source: "GDPR Article 5(1)(b)",
            severity: DoctrineCore.DoctrineSeverity.critical
        ),

        DoctrinePrinciple(
            id: "gdpr_5_1_c",
            title: "Data minimisation",
            description:
                "Personal data shall be adequate, relevant and limited to what is necessary.",
            source: "GDPR Article 5(1)(c)",
            severity: DoctrineCore.DoctrineSeverity.error
        ),

        DoctrinePrinciple(
            id: "gdpr_5_1_e",
            title: "Storage limitation",
            description:
                "Personal data shall be kept in a form which permits identification for no longer than necessary.",
            source: "GDPR Article 5(1)(e)",
            severity: DoctrineCore.DoctrineSeverity.error
        ),

        // NIST Privacy Framework: Govern (GV)
        DoctrinePrinciple(
            id: "nist_gv_1",
            title: "Organizational privacy governance",
            description:
                "Organizational privacy values and risk management priorities are established and communicated.",
            source: "NIST Privacy Framework GV.1",
            severity: DoctrineCore.DoctrineSeverity.warning
        ),

        // WCAG 2.1: Perceivable
        DoctrinePrinciple(
            id: "wcag_1_1_1",
            title: "Non-text content",
            description:
                "All non-text content that is presented to the user has a text alternative.",
            source: "WCAG 2.1 Success Criterion 1.1.1",
            severity: DoctrineCore.DoctrineSeverity.error
        ),

        DoctrinePrinciple(
            id: "wcag_2_2_1",
            title: "Timing adjustable",
            description: "Users must have sufficient time to read and use content.",
            source: "WCAG 2.1 Success Criterion 2.2.1",
            severity: DoctrineCore.DoctrineSeverity.warning
        ),

        // ADA Title III
        DoctrinePrinciple(
            id: "ada_3",
            title: "Reasonable accommodation",
            description:
                "Services must provide reasonable accommodation for individuals with disabilities.",
            source: "ADA Title III",
            severity: DoctrineCore.DoctrineSeverity.error
        )
    ]

    // MARK: - Concrete Checks (Machine-Implementable)

    public static var checks: [DoctrineCheck] {
        ruleDefinitions.map(DoctrineBridge.makeCheck(rule:))
    }

    private static let ruleDefinitions: [DoctrineBridgeRule] = [
        DoctrineBridgeRule(
            id: "law_pii_unclassified",
            principleId: "gdpr_5_1_c",
            title: "Unclassified PII field",
            description:
                "Data model fields that appear to be PII must have explicit classification.",
            implementationHint: .astPattern,
            parameters: [
                "pii_patterns": "email,phone,ssn,address,name,dob,credit_card",
                "annotation": "@DataClassification"
            ],
            blocking: true
        ),
        DoctrineBridgeRule(
            id: "law_pii_logging",
            principleId: "gdpr_5_1_e",
            title: "PII logging without retention policy",
            description: "Logging of PII must include retention period annotation.",
            implementationHint: .filePattern,
            parameters: [
                "log_functions": "log,debug,info,error",
                "retention_annotation": "@RetentionPolicy"
            ],
            blocking: true
        ),
        DoctrineBridgeRule(
            id: "law_accessibility_missing_alt",
            principleId: "wcag_1_1_1",
            title: "Missing alternative text",
            description: "UI images and non-text content must have text alternatives.",
            implementationHint: .astPattern,
            parameters: [
                "ui_frameworks": "SwiftUI,UIKit,HTML",
                "alt_attributes": "accessibilityLabel,alt,aria-label"
            ]
        ),
        DoctrineBridgeRule(
            id: "law_processing_without_basis",
            principleId: "gdpr_5_1_a",
            title: "Data processing without legal basis",
            description:
                "Processing personal data requires declared legal basis (consent, contract, etc.).",
            implementationHint: .filePattern,
            parameters: [
                "processing_verbs": "process,collect,store,share,transfer",
                "basis_annotation": "@LegalBasis"
            ],
            blocking: true
        ),
        DoctrineBridgeRule(
            id: "law_accessibility_timeout",
            principleId: "wcag_2_2_1",
            title: "Insufficient timeout for accessibility",
            description: "User interactions must have sufficient time limits (minimum 5 seconds).",
            implementationHint: .astPattern,
            parameters: [
                "timeout_threshold": "5.0",
                "timeout_functions": "timeout,delay,sleep,Timer"
            ]
        )
    ]

    // MARK: - PII Field Patterns (From NIST/Industry Standards)

    public static let piiPatterns: [String: PIILevel] = [
        // Direct identifiers
        "email": .identifiable,
        "phone": .identifiable,
        "ssn": .sensitive,
        "social_security": .sensitive,
        "passport": .sensitive,
        "driver_license": .sensitive,

        // Contact information
        "address": .identifiable,
        "city": .pseudonymous,
        "state": .pseudonymous,
        "zip": .pseudonymous,
        "country": .pseudonymous,

        // Personal details
        "name": .identifiable,
        "first_name": .identifiable,
        "last_name": .identifiable,
        "dob": .identifiable,
        "birth_date": .identifiable,
        "age": .pseudonymous,

        // Financial
        "credit_card": .sensitive,
        "bank_account": .sensitive,
        "routing_number": .sensitive,

        // Health
        "medical": .sensitive,
        "health": .sensitive,
        "diagnosis": .sensitive,

        // Government
        "voter_id": .identifiable,
        "tax_id": .sensitive
    ]

    // MARK: - Helper Methods

    /// Check if a field name matches PII patterns.
    public static func classifyField(_ fieldName: String) -> PIILevel? {
        let lowercased = fieldName.lowercased()

        for (pattern, level) in piiPatterns {
            if lowercased.contains(pattern) {
                return level
            }
        }

        return nil
    }

    /// Get all checks for a principle.
    public static func checks(forPrinciple principleId: String) -> [DoctrineCheck] {
        checks.filter { $0.principleId == principleId }
    }

    /// Get all blocking checks.
    public static var blockingChecks: [DoctrineCheck] {
        checks.filter { $0.blocking }
    }
}

/// Doctrine principle (from canonical source).
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

/// Concrete implementation of LawComplianceDoctrinalScout.
public actor ConcreteLawComplianceScout: DoctrinalScout {
    public let domain: DoctrineDomain = .lawCompliance
    private let piiConfig: PIIConfiguration

    public init(piiConfig: PIIConfiguration = .default) {
        self.piiConfig = piiConfig
    }

    public func scan(fileAt path: String) async throws -> [DoctrineViolation] {
        guard path.hasSuffix(".swift") else { return [] }

        let source = try String(contentsOfFile: path, encoding: .utf8)

        var violations: [DoctrineViolation] = []

        // Check 1: Unclassified PII fields
        violations.append(contentsOf: try checkUnclassifiedPII(source: source, filePath: path))

        // Check 2: PII logging without retention
        violations.append(contentsOf: try checkPIILogging(source: source, filePath: path))

        // Check 3: Missing accessibility markers
        violations.append(contentsOf: try checkAccessibility(source: source, filePath: path))

        // Check 4: Data processing without legal basis
        violations.append(contentsOf: try checkLegalBasis(source: source, filePath: path))

        // Check 5: Insufficient timeouts
        violations.append(contentsOf: try checkTimeouts(source: source, filePath: path))

        return violations
    }

    // MARK: - Concrete Check Implementations

    private func checkUnclassifiedPII(source: String, filePath: String) throws
        -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        // Look for struct/class definitions
        var inDataModel = false
        var currentModel: String?

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect data model start
            if trimmed.hasPrefix("struct ") || trimmed.hasPrefix("class ")
                || trimmed.hasPrefix("actor ") {
                inDataModel = true
                currentModel = extractModelName(from: trimmed)
            }

            // Detect data model end
            if trimmed.hasPrefix("}") && inDataModel {
                // Check if this is the closing brace of our model
                let remaining = lines[index...].joined()
                if !remaining.contains("struct ") && !remaining.contains("class ")
                    && !remaining.contains("actor ") {
                    inDataModel = false
                    currentModel = nil
                }
            }

            // Check for PII fields in data models
            if inDataModel {
                // Look for variable declarations
                if trimmed.hasPrefix("var ") || trimmed.hasPrefix("let ") {
                    let fieldName = extractFieldName(from: trimmed)

                    // Check if field looks like PII
                    if let piiLevel = ConcreteLawCompliancePack.classifyField(fieldName) {
                        // Check if field has @DataClassification annotation
                        if !hasDataClassificationAnnotation(
                            line: line, context: lines, index: index) {
                            let detail =
                                "Unclassified PII field '\(fieldName)' (\(piiLevel.rawValue)) in \(currentModel ?? "unknown model")"
                            let violation = lawViolation(
                                ruleId: "law_pii_unclassified",
                                severity: piiLevel == .sensitive ? .critical : .error,
                                filePath: filePath,
                                lineNumber: lineNumber,
                                message: detail,
                                context: detail
                            )
                            violations.append(violation)
                        }
                    }
                }
            }
        }

        return violations
    }

    private func checkPIILogging(source: String, filePath: String) throws -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        let logFunctions = ["log(", "debug(", "info(", "error(", "print("]

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1

            for logFunc in logFunctions {
                if line.contains(logFunc) {
                    // Check if line contains PII patterns
                    for (piiPattern, piiLevel) in ConcreteLawCompliancePack.piiPatterns {
                        if line.lowercased().contains(piiPattern) {
                            // Check for retention annotation in surrounding context
                            if !hasRetentionAnnotation(context: lines, index: index) {
                                let detail =
                                    "Logging \(piiLevel.rawValue) PII '\(piiPattern)' without retention policy (function \(logFunc))"
                                let violation = lawViolation(
                                    ruleId: "law_pii_logging",
                                    severity: piiLevel == .sensitive ? .critical : .error,
                                    filePath: filePath,
                                    lineNumber: lineNumber,
                                    message: detail,
                                    context: detail
                                )
                                violations.append(violation)
                            }
                        }
                    }
                }
            }
        }

        return violations
    }

    private func checkAccessibility(source: String, filePath: String) throws -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        // SwiftUI accessibility patterns
        let swiftuiImagePatterns = ["Image(", "AsyncImage(", "systemName:"]
        let accessibilityAttributes = [
            "accessibilityLabel", "accessibilityHint", "accessibilityValue"
        ]

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1

            // Check for SwiftUI images without accessibility labels
            for pattern in swiftuiImagePatterns {
                if line.contains(pattern) {
                    // Look ahead for accessibility attributes
                    let contextStart = max(0, index - 3)
                    let contextEnd = min(lines.count - 1, index + 3)
                    let context = lines[contextStart...contextEnd].joined(separator: "\n")

                    var hasAccessibility = false
                    for attr in accessibilityAttributes {
                        if context.contains(attr) {
                            hasAccessibility = true
                            break
                        }
                    }

                    if !hasAccessibility {
                        let detail = "Image without accessibility label (pattern '\(pattern)')"
                        let violation = lawViolation(
                            ruleId: "law_accessibility_missing_alt",
                            severity: DoctrineCore.DoctrineSeverity.warning,
                            filePath: filePath,
                            lineNumber: lineNumber,
                            message: detail,
                            context: detail
                        )
                        violations.append(violation)
                    }
                }
            }
        }

        return violations
    }

    private func checkLegalBasis(source: String, filePath: String) throws -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        let processingVerbs = ["process", "collect", "store", "share", "transfer"]
        let legalBasisAnnotations = ["@LegalBasis", "@ConsentRequired", "@ContractBasis"]

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1

            for verb in processingVerbs {
                if line.lowercased().contains(verb) {
                    // Check if this is data processing (not just any use of the word)
                    let contextStart = max(0, index - 5)
                    let contextEnd = min(lines.count - 1, index + 5)
                    let context = lines[contextStart...contextEnd].joined(separator: "\n")

                    // Look for data-related keywords
                    let dataKeywords = ["data", "personal", "user", "customer", "patient"]
                    var isDataProcessing = false

                    for keyword in dataKeywords {
                        if context.lowercased().contains(keyword) {
                            isDataProcessing = true
                            break
                        }
                    }

                    if isDataProcessing {
                        // Check for legal basis annotation
                        var hasLegalBasis = false
                        for annotation in legalBasisAnnotations {
                            if context.contains(annotation) {
                                hasLegalBasis = true
                                break
                            }
                        }

                        if !hasLegalBasis {
                            let detail =
                                "Data processing without declared legal basis (verb '\(verb)')"
                            let violation = lawViolation(
                                ruleId: "law_processing_without_basis",
                                severity: DoctrineCore.DoctrineSeverity.error,
                                filePath: filePath,
                                lineNumber: lineNumber,
                                message: detail,
                                context: detail
                            )
                            violations.append(violation)
                        }
                    }
                }
            }
        }

        return violations
    }

    private func checkTimeouts(source: String, filePath: String) throws -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        let timeoutPatterns = ["timeout:", "timeout =", "delay(", "sleep(", "Timer("]

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1

            for pattern in timeoutPatterns {
                if line.contains(pattern) {
                    // Try to extract timeout value
                    if let timeout = extractTimeout(from: line) {
                        if timeout < 5.0 {
                            let detail =
                                "Timeout too short for accessibility: \(timeout) seconds (pattern \(pattern))"
                            let violation = lawViolation(
                                ruleId: "law_accessibility_timeout",
                                severity: DoctrineCore.DoctrineSeverity.warning,
                                filePath: filePath,
                                lineNumber: lineNumber,
                                message: detail,
                                context: detail
                            )
                            violations.append(violation)
                        }
                    }
                }
            }
        }

        return violations
    }

    // MARK: - Helper Methods

    private func extractModelName(from line: String) -> String {
        let components = line.components(separatedBy: " ")
        guard components.count > 1 else { return "unknown" }

        // Remove any generics or inheritance
        let name = components[1]
        if let genericRange = name.range(of: "<") {
            return String(name[..<genericRange.lowerBound])
        }
        if let colonRange = name.range(of: ":") {
            return String(name[..<colonRange.lowerBound])
        }

        return name
    }

    private func extractFieldName(from line: String) -> String {
        let components = line.components(separatedBy: " ")
        guard components.count > 1 else { return "unknown" }

        var fieldName = components[1]

        // Remove type annotation
        if let colonRange = fieldName.range(of: ":") {
            fieldName = String(fieldName[..<colonRange.lowerBound])
        }

        // Remove any modifiers
        if let equalsRange = fieldName.range(of: "=") {
            fieldName = String(fieldName[..<equalsRange.lowerBound]).trimmingCharacters(
                in: .whitespaces)
        }

        return fieldName
    }

    private func hasDataClassificationAnnotation(line: String, context: [String], index: Int)
        -> Bool {
        // Check current line
        if line.contains("@DataClassification") {
            return true
        }

        // Check previous line (common pattern)
        if index > 0 && context[index - 1].contains("@DataClassification") {
            return true
        }

        return false
    }

    private func hasRetentionAnnotation(context: [String], index: Int) -> Bool {
        let checkRange = max(0, index - 3)...min(context.count - 1, index + 1)

        for i in checkRange {
            if context[i].contains("@RetentionPolicy") {
                return true
            }
        }

        return false
    }

    private func extractTimeout(from line: String) -> Double? {
        let patterns = [
            #"timeout\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)"#,
            #"delay\(([0-9]+(?:\.[0-9]+)?)"#,
            #"sleep\(([0-9]+(?:\.[0-9]+)?)"#,
            #"Timer\.scheduledTimer\(.*interval:\s*([0-9]+(?:\.[0-9]+)?)"#
        ]

        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            if let match = regex?.firstMatch(
                in: line, options: [], range: NSRange(location: 0, length: line.count)) {
                if let range = Range(match.range(at: 1), in: line) {
                    return Double(line[range])
                }
            }
        }

        return nil
    }

    private func lawViolation(
        ruleId: String,
        severity: DoctrineSeverity,
        filePath: String,
        lineNumber: Int,
        columnNumber: Int? = nil,
        message: String,
        context: String
    ) -> DoctrineViolation {
        DoctrineBridge.makeViolation(
            input: DoctrineBridgeViolationInput(
                ruleId: ruleId,
                domain: .lawCompliance,
                severity: severity,
                message: message,
                filePath: filePath,
                lineNumber: lineNumber,
                columnNumber: columnNumber,
                context: context
            )
        )
    }
}

/// PII configuration (user-maintained).
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

/// Doctrine violation as first-class task.
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

    /// Convert a doctrine violation to a debt task.
    public static func fromViolation(_ violation: DoctrineViolation) -> DoctrineDebtTask? {
        guard
            let check = ConcreteLawCompliancePack.checks.first(where: { $0.id == violation.ruleId })
        else {
            return nil
        }

        return DoctrineDebtTask(
            violationId: violationIdentifier(for: violation),
            checkId: violation.ruleId,
            principleId: check.principleId,
            filePath: violation.filePath,
            lineNumber: violation.lineNumber,
            description: violation.context ?? violation.message,
            severity: violation.severity,
            blocking: check.blocking,
            suggestedRemediation: extractRemediation(from: violation)
        )
    }

    private static func extractRemediation(from violation: DoctrineViolation) -> String {
        switch violation.ruleId {
        case "law_pii_unclassified":
            return "Add @DataClassification annotation to field"
        case "law_pii_logging":
            return "Add @RetentionPolicy annotation or remove PII from logs"
        case "law_accessibility_missing_alt":
            return "Add accessibility label to UI element"
        case "law_processing_without_basis":
            return "Add @LegalBasis annotation to data processing function"
        case "law_accessibility_timeout":
            return "Increase timeout to at least 5 seconds"
        default:
            return "Review and fix doctrine violation"
        }
    }

    private static func violationIdentifier(for violation: DoctrineViolation) -> UUID {
        let payloadComponents = [
            violation.ruleId,
            violation.filePath ?? "",
            "\(violation.lineNumber ?? -1)",
            "\(violation.columnNumber ?? -1)",
            violation.severity.rawValue,
            violation.context ?? ""
        ]
        let payload = payloadComponents.joined(separator: "|")
        let digest = Insecure.MD5.hash(data: Data(payload.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()

        let part1 = String(hex.prefix(8))
        let part2 = String(hex.dropFirst(8).prefix(4))
        let part3 = String(hex.dropFirst(12).prefix(4))
        let part4 = String(hex.dropFirst(16).prefix(4))
        let part5 = String(hex.dropFirst(20).prefix(12))

        let uuidString = "\(part1)-\(part2)-\(part3)-\(part4)-\(part5)"
        return UUID(uuidString: uuidString) ?? UUID()
    }
}
