//
//  ValidationSkipGovernor.swift
//  HarmoniaModule
//
//  Governance for skip_validation requests.
//  Ensures agents can only skip validation with valid justification.
//

import Foundation
import AnigmaPrimitives
import DatabaseCore

/// Result of evaluating a validation skip request
public struct ValidationSkipDecision: Sendable, Codable {
    /// Whether skip is allowed
    public let allowed: Bool

    /// Reason for allowing/denying
    public let reason: String

    /// Justification provided by requester
    public let justification: String?

    /// Valid justification categories that were matched (if any)
    public let matchedCategories: [SkipJustificationCategory]

    /// Remedial actions required if denied
    public let remediations: [String]

    public init(
        allowed: Bool,
        reason: String,
        justification: String?,
        matchedCategories: [SkipJustificationCategory],
        remediations: [String]
    ) {
        self.allowed = allowed
        self.reason = reason
        self.justification = justification
        self.matchedCategories = matchedCategories
        self.remediations = remediations
    }
}

/// Valid categories for skipping validation
public enum SkipJustificationCategory: String, Sendable, Codable {
    case nonSwiftFiles = "non_swift_files"           // Patching non-Swift files only
    case emergencyHotfix = "emergency_hotfix"        // Critical production issue
    case knownCompilerBug = "known_compiler_bug"     // Working around known Swift compiler bug
    case experimentalFeature = "experimental_feature" // Testing experimental Swift features
    case vendorCode = "vendor_code"                  // Third-party code we don't control
    case generatedCode = "generated_code"            // Machine-generated code
    case documentationOnly = "documentation_only"    // Only changing comments/docs

    var description: String {
        switch self {
        case .nonSwiftFiles:
            return "Patch only affects non-Swift files (e.g., markdown, JSON, config files)"
        case .emergencyHotfix:
            return "Emergency hotfix for critical production issue - validation will be done post-merge"
        case .knownCompilerBug:
            return "Known Swift compiler bug prevents compilation - workaround required"
        case .experimentalFeature:
            return "Testing experimental Swift feature not yet supported by stable compiler"
        case .vendorCode:
            return "Third-party vendor code that we don't control and can't modify"
        case .generatedCode:
            return "Machine-generated code (protobuf, SwiftGen, etc.) that doesn't need validation"
        case .documentationOnly:
            return "Changes are documentation-only (comments, markdown) with no code impact"
        }
    }

    var requiresEvidence: Bool {
        switch self {
        case .nonSwiftFiles, .documentationOnly:
            return false // Can be verified automatically
        case .emergencyHotfix, .knownCompilerBug, .experimentalFeature, .vendorCode, .generatedCode:
            return true // Requires human justification
        }
    }
}

/// Governs validation skip requests
public actor ValidationSkipGovernor {
    private let dbActor: DatabaseActor?

    public init(dbActor: DatabaseActor? = nil) {
        self.dbActor = dbActor
    }

    /// Evaluate whether a validation skip request should be allowed
    public func evaluateSkipRequest(
        justification: String?,
        affectedFiles: [String],
        patchContent: String,
        sessionId: String,
        agentId: String
    ) async -> ValidationSkipDecision {
        // RULE 1: No justification provided = DENY
        guard let justification = justification, !justification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ValidationSkipDecision(
                allowed: false,
                reason: "Validation skip denied: No justification provided",
                justification: nil,
                matchedCategories: [],
                remediations: [
                    "Provide a detailed justification explaining why validation must be skipped",
                    "Valid reasons: emergency hotfix, known compiler bug, experimental feature, etc.",
                    "If this is routine code, validation should NOT be skipped"
                ]
            )
        }

        // RULE 2: Check if automatically verifiable (non-Swift files, docs only)
        let autoVerifiable = checkAutoVerifiableConditions(affectedFiles: affectedFiles, patchContent: patchContent)
        if !autoVerifiable.isEmpty {
            // Automatically allow for these cases
            return ValidationSkipDecision(
                allowed: true,
                reason: "Validation skip allowed: \(autoVerifiable.map { $0.description }.joined(separator: ", "))",
                justification: justification,
                matchedCategories: autoVerifiable,
                remediations: []
            )
        }

        // RULE 3: Parse and validate justification
        let parsedCategories = parseJustification(justification)

        // RULE 4: If no valid categories detected = DENY
        guard !parsedCategories.isEmpty else {
            return ValidationSkipDecision(
                allowed: false,
                reason: "Validation skip denied: Justification does not match any valid category",
                justification: justification,
                matchedCategories: [],
                remediations: [
                    "Your justification must clearly state ONE of these valid reasons:",
                    "  - Emergency hotfix for production issue",
                    "  - Known Swift compiler bug (specify bug ID)",
                    "  - Experimental feature testing (specify feature)",
                    "  - Third-party vendor code (specify vendor/library)",
                    "  - Machine-generated code (specify generator)",
                    "Generic reasons like 'testing' or 'WIP' are NOT sufficient"
                ]
            )
        }

        // RULE 5: Validate evidence for categories that require it
        for category in parsedCategories {
            if category.requiresEvidence {
                let hasEvidence = validateEvidence(category: category, justification: justification)
                if !hasEvidence {
                    return ValidationSkipDecision(
                        allowed: false,
                        reason: "Validation skip denied: Insufficient evidence for '\(category.rawValue)'",
                        justification: justification,
                        matchedCategories: parsedCategories,
                        remediations: remediationsForCategory(category)
                    )
                }
            }
        }

        // RULE 6: Check skip history (prevent abuse)
        let recentSkips = await getRecentSkipCount(sessionId: sessionId, agentId: agentId)
        if recentSkips >= 3 {
            return ValidationSkipDecision(
                allowed: false,
                reason: "Validation skip denied: Too many recent skips (\(recentSkips) in current session)",
                justification: justification,
                matchedCategories: parsedCategories,
                remediations: [
                    "You have skipped validation \(recentSkips) times already in this session",
                    "This suggests a pattern of avoiding validation rather than legitimate exceptions",
                    "Fix the underlying validation issues instead of repeatedly skipping",
                    "Validation skip will be re-enabled after you successfully apply a patch WITH validation"
                ]
            )
        }

        // RULE 7: All checks passed - ALLOW with logging
        await logSkipDecision(
            sessionId: sessionId,
            agentId: agentId,
            justification: justification,
            categories: parsedCategories,
            allowed: true
        )

        return ValidationSkipDecision(
            allowed: true,
            reason: "Validation skip allowed: \(parsedCategories.map { $0.description }.joined(separator: ", "))",
            justification: justification,
            matchedCategories: parsedCategories,
            remediations: []
        )
    }

    /// Reset skip counter after successful validated patch
    public func recordSuccessfulValidation(sessionId: String, agentId: String) async {
        // Reset the skip counter when agent successfully applies a patch WITH validation
        await resetSkipCounter(sessionId: sessionId, agentId: agentId)
    }

    // MARK: - Auto-Verifiable Conditions

    private func checkAutoVerifiableConditions(affectedFiles: [String], patchContent: String) -> [SkipJustificationCategory] {
        var categories: [SkipJustificationCategory] = []

        // Check if all files are non-Swift
        let hasSwiftFiles = affectedFiles.contains { $0.hasSuffix(".swift") }
        if !hasSwiftFiles && !affectedFiles.isEmpty {
            categories.append(.nonSwiftFiles)
        }

        // Check if patch only modifies comments
        if isDocumentationOnly(patchContent: patchContent) {
            categories.append(.documentationOnly)
        }

        return categories
    }

    private func isDocumentationOnly(patchContent: String) -> Bool {
        let lines = patchContent.split(separator: "\n").map(String.init)

        var hasCodeChanges = false
        var hasDocChanges = false

        for line in lines {
            // Skip diff metadata
            if line.hasPrefix("diff ") || line.hasPrefix("index ") ||
               line.hasPrefix("--- ") || line.hasPrefix("+++ ") ||
               line.hasPrefix("@@ ") {
                continue
            }

            // Check added/removed lines
            if line.hasPrefix("+") || line.hasPrefix("-") {
                let content = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)

                // Is it a comment?
                if content.hasPrefix("//") || content.hasPrefix("/*") || content.hasPrefix("*") || content.isEmpty {
                    hasDocChanges = true
                } else {
                    // Real code change
                    hasCodeChanges = true
                }
            }
        }

        return hasDocChanges && !hasCodeChanges
    }

    // MARK: - Justification Parsing

    private func parseJustification(_ justification: String) -> [SkipJustificationCategory] {
        let lower = justification.lowercased()
        var categories: [SkipJustificationCategory] = []

        // Emergency hotfix
        if (lower.contains("emergency") || lower.contains("hotfix") || lower.contains("critical")) &&
           (lower.contains("production") || lower.contains("prod") || lower.contains("outage")) {
            categories.append(.emergencyHotfix)
        }

        // Known compiler bug
        if (lower.contains("compiler bug") || lower.contains("swift bug")) &&
           (lower.contains("sr-") || lower.contains("rdar://") || lower.contains("github.com/apple/swift/issues")) {
            categories.append(.knownCompilerBug)
        }

        // Experimental feature
        if (lower.contains("experimental") || lower.contains("preview")) &&
           (lower.contains("feature") || lower.contains("swift 6") || lower.contains("upcoming")) {
            categories.append(.experimentalFeature)
        }

        // Vendor code
        if (lower.contains("vendor") || lower.contains("third-party") || lower.contains("3rd party")) &&
           (lower.contains("code") || lower.contains("library") || lower.contains("dependency")) {
            categories.append(.vendorCode)
        }

        // Generated code
        if (lower.contains("generated") || lower.contains("auto-generated")) &&
           (lower.contains("code") || lower.contains("protobuf") || lower.contains("swiftgen") || lower.contains("sourcery")) {
            categories.append(.generatedCode)
        }

        return categories
    }

    // MARK: - Evidence Validation

    private func validateEvidence(category: SkipJustificationCategory, justification: String) -> Bool {
        let lower = justification.lowercased()

        switch category {
        case .emergencyHotfix:
            // Must mention specific incident/ticket
            return lower.contains("incident") || lower.contains("ticket") ||
                   lower.contains("issue #") || lower.contains("jira") ||
                   lower.contains("outage") || lower.contains("sev-")

        case .knownCompilerBug:
            // Must reference specific bug ID
            return lower.contains("sr-") || lower.contains("rdar://") ||
                   lower.contains("github.com/apple/swift/issues/")

        case .experimentalFeature:
            // Must name specific feature
            return lower.contains("strict concurrency") || lower.contains("sendable") ||
                   lower.contains("isolated") || lower.contains("nonisolated") ||
                   lower.contains("swift 6")

        case .vendorCode:
            // Must name vendor/library
            let hasVendorName = lower.range(of: #"\b[a-z]{3,}\s+(library|framework|sdk|package)\b"#, options: .regularExpression) != nil
            return hasVendorName || lower.contains("pod ") || lower.contains("spm package")

        case .generatedCode:
            // Must name generator tool
            return lower.contains("protoc") || lower.contains("swiftgen") ||
                   lower.contains("sourcery") || lower.contains("grpc") ||
                   lower.contains("swagger") || lower.contains("openapi")

        case .nonSwiftFiles, .documentationOnly:
            // Auto-verified, no evidence needed
            return true
        }
    }

    private func remediationsForCategory(_ category: SkipJustificationCategory) -> [String] {
        switch category {
        case .emergencyHotfix:
            return [
                "Provide incident ID or ticket number",
                "Example: 'Emergency hotfix for production outage INCIDENT-1234'",
                "Explain the specific production impact and why validation can't wait"
            ]

        case .knownCompilerBug:
            return [
                "Provide Swift bug tracker ID (SR-XXXX) or radar number",
                "Example: 'Known compiler bug SR-12345 prevents compilation with strict concurrency'",
                "Link to bug report: https://github.com/apple/swift/issues/XXXX"
            ]

        case .experimentalFeature:
            return [
                "Name the specific experimental feature being tested",
                "Example: 'Testing upcoming Swift 6 strict concurrency feature'",
                "Explain why stable compiler doesn't support this yet"
            ]

        case .vendorCode:
            return [
                "Name the third-party library/vendor",
                "Example: 'Vendor code from Alamofire library that we cannot modify'",
                "Explain why we can't fix the vendor code ourselves"
            ]

        case .generatedCode:
            return [
                "Name the code generation tool",
                "Example: 'Generated by protoc from .proto files'",
                "Explain why regenerating doesn't help"
            ]

        case .nonSwiftFiles, .documentationOnly:
            return [] // Auto-verified
        }
    }

    // MARK: - Skip History Tracking

    private func getRecentSkipCount(sessionId: String, agentId: String) async -> Int {
        // In-memory tracking per session
        // TODO: Persist to database for cross-session tracking
        return 0 // Placeholder - implement with database
    }

    private func resetSkipCounter(sessionId: String, agentId: String) async {
        // Reset counter after successful validated patch
        // TODO: Implement with database
    }

    private func logSkipDecision(
        sessionId: String,
        agentId: String,
        justification: String,
        categories: [SkipJustificationCategory],
        allowed: Bool
    ) async {
        guard let dbActor = dbActor else { return }

        // Log to audit trail
        let sql = """
        INSERT INTO validation_skip_decisions (
            session_id, agent_id, justification, categories, allowed, timestamp
        ) VALUES (?, ?, ?, ?, ?, ?)
        """

        let categoriesJson = categories.map { $0.rawValue }.joined(separator: ",")

        _ = try? await dbActor.execute(
            sql,
            parameters: [
                .text(sessionId),
                .text(agentId),
                .text(justification),
                .text(categoriesJson),
                .int(allowed ? 1 : 0),
                .double(Date().timeIntervalSince1970)
            ]
        )
    }
}

/// Extended validation result with skip decision
public struct ValidationSkipAwareResult: Sendable, Codable {
    /// The validation result (if validation ran)
    public let validationResult: SwiftValidationResult?

    /// The skip decision (if skip was requested)
    public let skipDecision: ValidationSkipDecision?

    /// Whether validation was skipped
    public let skipped: Bool

    /// Final decision: allow patch or rollback
    public let allowed: Bool

    public init(
        validationResult: SwiftValidationResult?,
        skipDecision: ValidationSkipDecision?,
        skipped: Bool,
        allowed: Bool
    ) {
        self.validationResult = validationResult
        self.skipDecision = skipDecision
        self.skipped = skipped
        self.allowed = allowed
    }
}
