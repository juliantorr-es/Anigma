//
//  InspirationPolicy.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Inspiration
//
//  Governance policies for inspiration repositories.
//  Prevents plagiarism and ensures license compliance.
//

import Foundation
import AnigmaCore
import HarmoniaModule

/// License compatibility levels for inspiration sources.
public enum LicenseCompatibility: String, Sendable, Codable {
    case compatible = "compatible"          // MIT, BSD, Apache - can learn and reuse with attribution
    case inspirationOnly = "inspiration_only" // GPL, AGPL - can learn patterns but not copy code
    case incompatible = "incompatible"      // Proprietary, unknown - cannot use at all
    case unknown = "unknown"                // License not detected yet
}

/// Policy for how inspiration sources can be used.
public struct InspirationPolicy: Sendable, Codable {
    public let sourceId: UUID
    public let licenseCompatibility: LicenseCompatibility
    public let maxCodeLines: Int  // Maximum lines of code that can be extracted
    public let allowedUses: [AllowedUse]
    public let attributionRequired: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public enum AllowedUse: String, Sendable, Codable {
        case patternExtraction = "pattern_extraction"  // Extract design patterns only
        case codeSnippets = "code_snippets"           // Extract small code snippets (< 10 lines)
        case architectureReference = "architecture_reference" // Reference architecture docs
        case fullCodeReuse = "full_code_reuse"        // Can copy and modify code (rare)
    }

    public init(
        sourceId: UUID,
        licenseCompatibility: LicenseCompatibility,
        maxCodeLines: Int = 10,
        allowedUses: [AllowedUse] = [.patternExtraction],
        attributionRequired: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.sourceId = sourceId
        self.licenseCompatibility = licenseCompatibility
        self.maxCodeLines = maxCodeLines
        self.allowedUses = allowedUses
        self.attributionRequired = attributionRequired
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Detects license from repository metadata.
public struct LicenseDetector {

    /// Detect license compatibility from license string.
    public static func detectCompatibility(from licenseString: String?) -> LicenseCompatibility {
        guard let license = licenseString?.lowercased() else {
            return .unknown
        }

        // Permissive licenses - compatible
        if license.contains("mit") || license.contains("bsd") || license.contains("apache") {
            return .compatible
        }

        // Copyleft licenses - inspiration only
        if license.contains("gpl") || license.contains("agpl") || license.contains("lgpl") {
            return .inspirationOnly
        }

        // Proprietary or restrictive
        if license.contains("proprietary") || license.contains("commercial") || license.contains("restricted") {
            return .incompatible
        }

        return .unknown
    }

    /// Determine allowed uses based on license compatibility.
    public static func allowedUses(for compatibility: LicenseCompatibility) -> [InspirationPolicy.AllowedUse] {
        switch compatibility {
        case .compatible:
            return [.patternExtraction, .codeSnippets, .architectureReference, .fullCodeReuse]
        case .inspirationOnly:
            return [.patternExtraction, .architectureReference]
        case .incompatible, .unknown:
            return []
        }
    }

    /// Check if a code snippet exceeds allowed size.
    public static func isSnippetWithinLimits(_ snippet: String, maxLines: Int) -> Bool {
        let lines = snippet.components(separatedBy: .newlines)
        return lines.count <= maxLines
    }

    /// Check if code appears to be a direct copy (simple heuristic).
    public static func appearsToBeDirectCopy(_ code: String, original: String, threshold: Double = 0.8) -> Bool {
        // Simple line-by-line comparison
        let codeLines = Set(code.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) })
        let originalLines = Set(original.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) })

        let intersection = codeLines.intersection(originalLines)
        let similarity = Double(intersection.count) / Double(max(codeLines.count, 1))

        return similarity > threshold
    }
}

/// Gatekeeper that enforces inspiration policies.
public actor InspirationGatekeeper {
    private let indexStore: InspirationIndexStore

    public init(indexStore: InspirationIndexStore) {
        self.indexStore = indexStore
    }

    /// Check if a pattern can be extracted from a source.
    public func canExtractPattern(from sourceId: UUID, patternKind: InspirationPattern.PatternKind) -> Bool {
        do {
            // In a real implementation, we would check the policy
            // For now, allow all pattern extraction
            return true
        } catch {
            logError("Failed to check pattern extraction permission: \(error)", category: "InspirationGatekeeper")
            return false
        }
    }

    /// Check if code can be used as a snippet.
    public func canUseCodeSnippet(from sourceId: UUID, snippet: String) -> Bool {
        do {
            // Check snippet size
            guard LicenseDetector.isSnippetWithinLimits(snippet, maxLines: 10) else {
                logWarning("Code snippet exceeds size limit: \(snippet.components(separatedBy: .newlines).count) lines", category: "InspirationGatekeeper")
                return false
            }

            // In a real implementation, we would check license compatibility
            // For now, allow all snippets under 10 lines
            return true
        } catch {
            logError("Failed to check snippet permission: \(error)", category: "InspirationGatekeeper")
            return false
        }
    }

    /// Validate that generated code doesn't appear to be a direct copy.
    public func validateNotDirectCopy(generatedCode: String, sourcePattern: InspirationPattern) -> Bool {
        // Check if generated code appears to be a direct copy of the example snippet
        if LicenseDetector.appearsToBeDirectCopy(generatedCode, original: sourcePattern.exampleSnippet) {
            logWarning("Generated code appears to be direct copy of inspiration pattern \(sourcePattern.patternId)", category: "InspirationGatekeeper")
            return false
        }

        return true
    }

    /// Check if a file path is allowed to be modified by inspiration-driven changes.
    public func isFilePathAllowed(_ filePath: String) -> Bool {
        // Don't allow inspiration-driven changes to inspiration/ directory itself
        guard !filePath.contains("/inspiration/") else {
            logWarning("Cannot modify inspiration/ directory with inspiration-driven changes: \(filePath)", category: "InspirationGatekeeper")
            return false
        }

        // Only allow changes in Sources/ directory
        guard filePath.contains("/Sources/") else {
            logWarning("Inspiration-driven changes only allowed in Sources/ directory: \(filePath)", category: "InspirationGatekeeper")
            return false
        }

        // Don't allow changes in Tests/ directory
        guard !filePath.contains("/Tests/") else {
            logWarning("Cannot modify Tests/ directory with inspiration-driven changes: \(filePath)", category: "InspirationGatekeeper")
            return false
        }

        return true
    }

    /// Generate attribution text for a pattern.
    public func generateAttribution(for pattern: InspirationPattern) -> String {
        // In a real implementation, we would fetch the repo info
        // For now, use pattern metadata
        return """
        // Inspired by pattern: \(pattern.description)
        // Source: \(pattern.metadata["file"] ?? "unknown")
        // Discovered: \(pattern.discoveredAt)
        """
    }
}

/// Registry for inspiration policies.
public actor InspirationPolicyRegistry {
    private var policies: [UUID: InspirationPolicy] = [:]

    public init() {
        // Load policies from database or defaults
    }

    public func getPolicy(for sourceId: UUID) -> InspirationPolicy? {
        return policies[sourceId]
    }

    public func setPolicy(_ policy: InspirationPolicy) {
        policies[policy.sourceId] = policy
    }

    public func removePolicy(for sourceId: UUID) {
        policies.removeValue(forKey: sourceId)
    }

    /// Create default policy based on license.
    public func createDefaultPolicy(for source: InspirationRepo) -> InspirationPolicy {
        let compatibility = LicenseDetector.detectCompatibility(from: source.license)
        let allowedUses = LicenseDetector.allowedUses(for: compatibility)

        return InspirationPolicy(
            sourceId: source.id,
            licenseCompatibility: compatibility,
            maxCodeLines: compatibility == .compatible ? 20 : 5,
            allowedUses: allowedUses,
            attributionRequired: true
        )
    }

    /// Check if a specific use is allowed for a source.
    public func isUseAllowed(_ use: InspirationPolicy.AllowedUse, for sourceId: UUID) -> Bool {
        guard let policy = getPolicy(for: sourceId) else {
            // No policy exists - default to most restrictive
            return false
        }

        return policy.allowedUses.contains(use)
    }
}

/// Tracks usage of inspiration sources for auditing.
public actor InspirationUsageTracker {
    public struct UsageRecord: Sendable, Codable {
        let sourceId: UUID
        let patternId: UUID?
        let useType: InspirationPolicy.AllowedUse
        let timestamp: Date
        let description: String
    }

    private var records: [UsageRecord] = []

    public init() {}

    public func recordUsage(
        sourceId: UUID,
        patternId: UUID? = nil,
        useType: InspirationPolicy.AllowedUse,
        description: String
    ) {
        let record = UsageRecord(
            sourceId: sourceId,
            patternId: patternId,
            useType: useType,
            timestamp: Date(),
            description: description
        )
        records.append(record)

        logInfo("Recorded inspiration usage: \(description)", category: "InspirationUsageTracker")
    }

    public func getUsageRecords(for sourceId: UUID) -> [UsageRecord] {
        return records.filter { $0.sourceId == sourceId }
    }

    public func getAllUsageRecords() -> [UsageRecord] {
        return records
    }

    /// Generate usage report for auditing.
    public func generateUsageReport() -> String {
        var report = "Inspiration Usage Report\n"
        report += "Generated: \(Date())\n"
        report += "Total records: \(records.count)\n\n"

        // Group by source
        let grouped = Dictionary(grouping: records) { $0.sourceId }

        for (sourceId, sourceRecords) in grouped {
            report += "Source: \(sourceId.uuidString)\n"
            report += "  Total uses: \(sourceRecords.count)\n"

            let byType = Dictionary(grouping: sourceRecords) { $0.useType }
            for (useType, typeRecords) in byType {
                report += "  \(useType.rawValue): \(typeRecords.count)\n"
            }

            // Show recent uses
            let recent = sourceRecords.sorted { $0.timestamp > $1.timestamp }.prefix(3)
            for record in recent {
                report += "  - [\(record.timestamp)] \(record.description)\n"
            }

            report += "\n"
        }

        return report
    }
}
