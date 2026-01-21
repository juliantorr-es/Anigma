//
//  ResearchTaskValidator.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  Validates research requirements before creating migration tasks.
//

import Foundation
import SQLite3
import AnigmaCore
import HarmoniaModule

/// Validates research requirements before creating migration tasks.
public struct ResearchTaskValidator: Sendable {

    private let researchGate: ResearchGate
    private let researchRegistry: ResearchRegistry

    public init(
        researchGate: ResearchGate = ResearchGate(),
        researchRegistry: ResearchRegistry = ResearchRegistry()
    ) {
        self.researchGate = researchGate
        self.researchRegistry = researchRegistry
    }

    /// Create a migration task with research validation.
    /// Returns the task ID if created, nil if blocked by research requirements.
    public func createMigrationTaskWithResearchValidation(
        from finding: ScoutFinding,
        db: OpaquePointer?,
        featureCategory: String? = nil
    ) async throws -> String? {
        logInfo("Creating migration task with research validation for finding \(finding.id)", category: "ResearchTaskValidator")

        // Check if this finding represents a module creation task
        guard isModuleCreationFinding(finding) else {
            // Not a module creation task - create without research validation
            logInfo("Finding \(finding.id) is not a module creation task, creating without research validation", category: "ResearchTaskValidator")
            return createMigrationTask(
                from: finding,
                db: db,
                featureCategory: featureCategory,
                researchBundleId: nil
            )
        }

        // Extract module proposal from finding
        guard let moduleProposal = extractModuleProposal(from: finding) else {
            logWarning("Cannot extract module proposal from finding \(finding.id), creating task without research", category: "ResearchTaskValidator")
            return createMigrationTask(
                from: finding,
                db: db,
                featureCategory: featureCategory,
                researchBundleId: nil
            )
        }

        // Check research requirements
        do {
            let researchBundle = try await researchGate.checkModuleProposal(moduleProposal)

            if let bundle = researchBundle {
                // Research is adequate - create task with research bundle reference
                logInfo("Research adequate for module '\(moduleProposal.name)', creating task with research bundle \(bundle.id)", category: "ResearchTaskValidator")
                return createMigrationTask(
                    from: finding,
                    db: db,
                    featureCategory: featureCategory,
                    researchBundleId: bundle.id
                )
            } else {
                // Research is inadequate - research task was scheduled
                logInfo("Research inadequate for module '\(moduleProposal.name)', research task scheduled", category: "ResearchTaskValidator")
                return nil  // Task creation blocked
            }
        } catch {
            logError("Failed to check research for module '\(moduleProposal.name)': \(error)", category: "ResearchTaskValidator")
            // On error, allow task creation without research (fail open for now)
            return createMigrationTask(
                from: finding,
                db: db,
                featureCategory: featureCategory,
                researchBundleId: nil
            )
        }
    }

    /// Check if a scout finding represents a module creation task.
    private func isModuleCreationFinding(_ finding: ScoutFinding) -> Bool {
        // Module creation findings typically have specific problem kinds
        let moduleCreationKinds = [
            "NewModule",
            "ModuleCreation",
            "ArchitectureChange",
            "MajorRefactor",
            "SecurityFeature",
            "AccessibilityFeature"
        ]

        return moduleCreationKinds.contains(finding.problemKind) ||
               finding.description.lowercased().contains("module") ||
               finding.description.lowercased().contains("architecture") ||
               finding.description.lowercased().contains("security") ||
               finding.description.lowercased().contains("accessibility")
    }

    /// Extract a module proposal from a scout finding.
    private func extractModuleProposal(from finding: ScoutFinding) -> ModuleProposal? {
        // Parse finding description to extract module information
        let description = finding.description

        // Extract module name (simplified parsing)
        let moduleName = extractModuleName(from: description) ?? "Unknown Module"

        // Extract keywords from description
        let keywords = extractKeywords(from: description)

        // Determine if research is required
        let requiresResearch = requiresResearch(for: finding)

        // Map problem kind to module type
        let moduleType = mapProblemKindToModuleType(finding.problemKind)

        // Map to doctrine domains
        let doctrineDomains = mapToDoctrineDomains(finding: finding)

        return ModuleProposal(
            name: moduleName,
            description: description,
            moduleType: moduleType,
            scope: extractScope(from: description),
            doctrineTags: doctrineDomains,
            constraints: extractConstraints(from: description),
            keywords: keywords,
            changes: extractChanges(from: description),
            requiresRecentResearch: requiresResearch
        )
    }

    // MARK: - Extraction Helpers

    private func extractModuleName(from description: String) -> String? {
        // Look for patterns like "Create module X", "Add module Y", "Implement module Z"
        let patterns = [
            "create module ([A-Za-z0-9_]+)",
            "add module ([A-Za-z0-9_]+)",
            "implement module ([A-Za-z0-9_]+)",
            "module ([A-Za-z0-9_]+) creation",
            "new module ([A-Za-z0-9_]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(description.startIndex..., in: description)
                if let match = regex.firstMatch(in: description, options: [], range: range) {
                    if let moduleRange = Range(match.range(at: 1), in: description) {
                        return String(description[moduleRange])
                    }
                }
            }
        }

        return nil
    }

    private func extractKeywords(from description: String) -> [String] {
        // Simple keyword extraction
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"])
        let words = description.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !stopWords.contains($0) && $0.count > 3 }

        return Array(Set(words)).sorted()
    }

    private func requiresResearch(for finding: ScoutFinding) -> Bool {
        // Research is required for:
        // 1. Security-related findings
        // 2. Accessibility-related findings  
        // 3. Architecture changes
        // 4. New modules
        let researchRequiredKinds = [
            "SecurityFeature",
            "AccessibilityFeature",
            "ArchitectureChange",
            "NewModule",
            "MajorRefactor"
        ]

        let description = finding.description.lowercased()
        let requiresByKind = researchRequiredKinds.contains(finding.problemKind)
        let requiresByDescription = description.contains("security") ||
                                   description.contains("accessibility") ||
                                   description.contains("architecture") ||
                                   description.contains("new module")

        return requiresByKind || requiresByDescription
    }

    private func mapProblemKindToModuleType(_ problemKind: String) -> String {
        switch problemKind {
        case "SecurityFeature":
            return "security"
        case "AccessibilityFeature":
            return "accessibility"
        case "ArchitectureChange":
            return "architecture"
        case "NewModule":
            return "module"
        case "MajorRefactor":
            return "refactor"
        default:
            return "general"
        }
    }

    private func mapToDoctrineDomains(finding: ScoutFinding) -> [DoctrineDomain] {
        var domains: Set<DoctrineDomain> = []

        let description = finding.description.lowercased()

        if description.contains("security") || finding.problemKind == "SecurityFeature" {
            domains.insert(.security)
        }

        if description.contains("accessibility") || finding.problemKind == "AccessibilityFeature" {
            domains.insert(.accessibility)
        }

        if description.contains("performance") {
            domains.insert(.performance)
        }

        if description.contains("maintain") || description.contains("readability") {
            domains.insert(.maintainability)
        }

        if description.contains("reliable") || description.contains("robust") {
            domains.insert(.reliability)
        }

        if description.contains("usability") || description.contains("user experience") {
            domains.insert(.usability)
        }

        if description.contains("scalable") || description.contains("concurrent") {
            domains.insert(.scalability)
        }

        return Array(domains)
    }

    private func extractScope(from description: String) -> [String] {
        // Simplified scope extraction
        var scope: [String] = []

        if description.contains("frontend") || description.contains("UI") {
            scope.append("frontend")
        }

        if description.contains("backend") || description.contains("API") {
            scope.append("backend")
        }

        if description.contains("database") || description.contains("storage") {
            scope.append("database")
        }

        if description.contains("network") || description.contains("API") {
            scope.append("network")
        }

        return scope
    }

    private func extractConstraints(from description: String) -> [String] {
        // Extract constraints like "must be secure", "needs to be accessible"
        var constraints: [String] = []

        if description.contains("secure") || description.contains("security") {
            constraints.append("Must implement security best practices")
        }

        if description.contains("accessible") || description.contains("accessibility") {
            constraints.append("Must meet accessibility standards")
        }

        if description.contains("performant") || description.contains("performance") {
            constraints.append("Must meet performance requirements")
        }

        return constraints
    }

    private func extractChanges(from description: String) -> [String] {
        // Extract changes from description
        var changes: [String] = []

        // Look for change indicators
        let changeMarkers = ["add", "create", "implement", "change", "modify", "update", "refactor"]

        for marker in changeMarkers {
            if description.lowercased().contains(marker) {
                // Extract the sentence containing the marker
                let sentences = description.components(separatedBy: ". ")
                for sentence in sentences {
                    if sentence.lowercased().contains(marker) {
                        changes.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        }

        return changes.isEmpty ? [description] : changes
    }
}
