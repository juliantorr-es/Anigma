//
//  UpdateCodexIntegration.swift
//  AnigmaCore
//
//  AnigmaCore - Update Documentation Integration
//
//  Connects releases to Codex pages for human-readable documentation.
//  Each release gets a canonical documentation page with notes,
//  migration impacts, and what-to-test instructions.
//

import AnigmaPrimitives
import ContractsCore
import Foundation

// MARK: - Release Documentation

/// Documentation for a release, stored in Codex.
public struct ReleaseDocumentation: Sendable, Codable {
    public let releaseVersion: SemanticVersion
    public let buildId: String
    public let codexSpaceId: String?
    public let codexPageId: String?

    public let title: String
    public let summary: String
    public let releaseDate: Date
    public let releaseType: ReleaseType

    public let whatChanged: [ChangeCategory: [ChangeItem]]
    public let migrationNotes: [MigrationNote]
    public let breakingChanges: [BreakingChange]
    public let knownIssues: [KnownIssue]
    public let testingInstructions: [TestingInstruction]
    public let rollbackProcedure: String?

    public let affectedModules: [String]
    public let affectedDepartments: [String]
    public let stakeholderNotes: [String: String]  // role -> notes

    public init(
        releaseVersion: SemanticVersion,
        buildId: String,
        codexSpaceId: String? = nil,
        codexPageId: String? = nil,
        title: String? = nil,
        summary: String = "",
        releaseDate: Date = Date(),
        releaseType: ReleaseType = .minor,
        whatChanged: [ChangeCategory: [ChangeItem]] = [:],
        migrationNotes: [MigrationNote] = [],
        breakingChanges: [BreakingChange] = [],
        knownIssues: [KnownIssue] = [],
        testingInstructions: [TestingInstruction] = [],
        rollbackProcedure: String? = nil,
        affectedModules: [String] = [],
        affectedDepartments: [String] = [],
        stakeholderNotes: [String: String] = [:]
    ) {
        self.releaseVersion = releaseVersion
        self.buildId = buildId
        self.codexSpaceId = codexSpaceId
        self.codexPageId = codexPageId
        self.title = title ?? "Release \(releaseVersion)"
        self.summary = summary
        self.releaseDate = releaseDate
        self.releaseType = releaseType
        self.whatChanged = whatChanged
        self.migrationNotes = migrationNotes
        self.breakingChanges = breakingChanges
        self.knownIssues = knownIssues
        self.testingInstructions = testingInstructions
        self.rollbackProcedure = rollbackProcedure
        self.affectedModules = affectedModules
        self.affectedDepartments = affectedDepartments
        self.stakeholderNotes = stakeholderNotes
    }
}

/// Type of release.
public enum ReleaseType: String, Sendable, Codable {
    case major          // Breaking changes, significant features
    case minor          // New features, non-breaking
    case patch          // Bug fixes
    case hotfix         // Emergency fix
    case security       // Security patch
}

/// Category of changes.
public enum ChangeCategory: String, Sendable, Codable, CaseIterable {
    case features = "Features"
    case improvements = "Improvements"
    case bugFixes = "Bug Fixes"
    case security = "Security"
    case performance = "Performance"
    case accessibility = "Accessibility"
    case documentation = "Documentation"
    case infrastructure = "Infrastructure"
}

/// A single change item.
public struct ChangeItem: Sendable, Codable {
    public let description: String
    public let module: String?
    public let issueId: String?
    public let contributor: String?

    public init(
        description: String,
        module: String? = nil,
        issueId: String? = nil,
        contributor: String? = nil
    ) {
        self.description = description
        self.module = module
        self.issueId = issueId
        self.contributor = contributor
    }
}

/// Migration note for a release.
public struct MigrationNote: Sendable, Codable {
    public let migrationId: String
    public let description: String
    public let affectedDomains: [String]
    public let isReversible: Bool
    public let estimatedDuration: TimeInterval
    public let dataImpact: DataImpact
    public let userAction: String?

    public init(
        migrationId: String,
        description: String,
        affectedDomains: [String] = [],
        isReversible: Bool = true,
        estimatedDuration: TimeInterval = 60,
        dataImpact: DataImpact = .none,
        userAction: String? = nil
    ) {
        self.migrationId = migrationId
        self.description = description
        self.affectedDomains = affectedDomains
        self.isReversible = isReversible
        self.estimatedDuration = estimatedDuration
        self.dataImpact = dataImpact
        self.userAction = userAction
    }
}

/// Data impact level.
public enum DataImpact: String, Sendable, Codable {
    case none           // No data changes
    case additive       // Only adds new data/fields
    case transformative // Transforms existing data
    case destructive    // May remove/change data (requires backup)
}

/// Breaking change documentation.
public struct BreakingChange: Sendable, Codable {
    public let description: String
    public let affectedFeature: String
    public let migrationPath: String
    public let deadline: Date?

    public init(
        description: String,
        affectedFeature: String,
        migrationPath: String,
        deadline: Date? = nil
    ) {
        self.description = description
        self.affectedFeature = affectedFeature
        self.migrationPath = migrationPath
        self.deadline = deadline
    }
}

/// Known issue documentation.
public struct KnownIssue: Sendable, Codable {
    public let description: String
    public let severity: IssueSeverity
    public let workaround: String?
    public let expectedFix: String?

    public init(
        description: String,
        severity: IssueSeverity = .minor,
        workaround: String? = nil,
        expectedFix: String? = nil
    ) {
        self.description = description
        self.severity = severity
        self.workaround = workaround
        self.expectedFix = expectedFix
    }
}

/// Issue severity.
public enum IssueSeverity: String, Sendable, Codable {
    case minor
    case moderate
    case major
    case critical
}

/// Testing instruction for QA.
public struct TestingInstruction: Sendable, Codable {
    public let area: String
    public let description: String
    public let steps: [String]
    public let expectedResult: String
    public let priority: TestPriority

    public init(
        area: String,
        description: String,
        steps: [String],
        expectedResult: String,
        priority: TestPriority = .normal
    ) {
        self.area = area
        self.description = description
        self.steps = steps
        self.expectedResult = expectedResult
        self.priority = priority
    }
}

/// Test priority.
public enum TestPriority: String, Sendable, Codable {
    case low
    case normal
    case high
    case critical
}

// MARK: - Release Documentation Generator

/// Generates release documentation in various formats.
public struct ReleaseDocumentationGenerator {

    // MARK: - Markdown Generation

    /// Generate Markdown documentation for a release.
    public static func generateMarkdown(
        from doc: ReleaseDocumentation
    ) -> String {
        var md = """
        # \(doc.title)

        **Version**: \(doc.releaseVersion)
        **Build**: \(doc.buildId)
        **Release Date**: \(formatDate(doc.releaseDate))
        **Type**: \(doc.releaseType.rawValue.capitalized)

        ## Summary

        \(doc.summary.isEmpty ? "_No summary provided._" : doc.summary)

        """

        // What Changed
        if !doc.whatChanged.isEmpty {
            md += "## What's Changed\n\n"

            for category in ChangeCategory.allCases {
                if let items = doc.whatChanged[category], !items.isEmpty {
                    md += "### \(category.rawValue)\n\n"
                    for item in items {
                        var line = "- \(item.description)"
                        if let module = item.module {
                            line += " _(\(module))_"
                        }
                        if let issue = item.issueId {
                            line += " [#\(issue)]"
                        }
                        md += line + "\n"
                    }
                    md += "\n"
                }
            }
        }

        // Breaking Changes
        if !doc.breakingChanges.isEmpty {
            md += "## ⚠️ Breaking Changes\n\n"
            for change in doc.breakingChanges {
                md += "### \(change.affectedFeature)\n\n"
                md += "\(change.description)\n\n"
                md += "**Migration Path**: \(change.migrationPath)\n\n"
                if let deadline = change.deadline {
                    md += "**Deadline**: \(formatDate(deadline))\n\n"
                }
            }
        }

        // Migration Notes
        if !doc.migrationNotes.isEmpty {
            md += "## Migration Notes\n\n"
            for note in doc.migrationNotes {
                md += "### \(note.migrationId)\n\n"
                md += "\(note.description)\n\n"
                if !note.affectedDomains.isEmpty {
                    md += "**Affected Domains**: \(note.affectedDomains.joined(separator: ", "))\n\n"
                }
                md += "**Estimated Duration**: \(formatDuration(note.estimatedDuration))\n"
                md += "**Reversible**: \(note.isReversible ? "Yes" : "No")\n"
                md += "**Data Impact**: \(note.dataImpact.rawValue.capitalized)\n\n"
                if let action = note.userAction {
                    md += "**User Action Required**: \(action)\n\n"
                }
            }
        }

        // Known Issues
        if !doc.knownIssues.isEmpty {
            md += "## Known Issues\n\n"
            for issue in doc.knownIssues {
                md += "- **[\(issue.severity.rawValue.uppercased())]** \(issue.description)"
                if let workaround = issue.workaround {
                    md += "\n  - _Workaround_: \(workaround)"
                }
                if let fix = issue.expectedFix {
                    md += "\n  - _Expected Fix_: \(fix)"
                }
                md += "\n"
            }
            md += "\n"
        }

        // Testing Instructions
        if !doc.testingInstructions.isEmpty {
            md += "## Testing Instructions\n\n"
            for test in doc.testingInstructions {
                md += "### \(test.area) [\(test.priority.rawValue.uppercased())]\n\n"
                md += "\(test.description)\n\n"
                md += "**Steps**:\n"
                for (i, step) in test.steps.enumerated() {
                    md += "\(i + 1). \(step)\n"
                }
                md += "\n**Expected Result**: \(test.expectedResult)\n\n"
            }
        }

        // Affected Modules
        if !doc.affectedModules.isEmpty {
            md += "## Affected Modules\n\n"
            for module in doc.affectedModules {
                md += "- \(module)\n"
            }
            md += "\n"
        }

        // Stakeholder Notes
        if !doc.stakeholderNotes.isEmpty {
            md += "## Stakeholder Notes\n\n"
            for (role, notes) in doc.stakeholderNotes.sorted(by: { $0.key < $1.key }) {
                md += "### For \(role)\n\n\(notes)\n\n"
            }
        }

        // Rollback Procedure
        if let rollback = doc.rollbackProcedure {
            md += "## Rollback Procedure\n\n\(rollback)\n\n"
        }

        return md
    }

    // MARK: - Codex Page Generation

    /// Generate Codex page content structure.
    public static func generateCodexPageContent(
        from doc: ReleaseDocumentation
    ) -> CodexPageContent {
        let markdown = generateMarkdown(from: doc)

        return CodexPageContent(
            title: doc.title,
            content: markdown,
            contentType: .markdown,
            metadata: CodexPageMetadata(
                releaseVersion: doc.releaseVersion.description,
                buildId: doc.buildId,
                releaseType: doc.releaseType.rawValue,
                affectedModules: doc.affectedModules,
                hasBreakingChanges: !doc.breakingChanges.isEmpty,
                hasMigrations: !doc.migrationNotes.isEmpty
            )
        )
    }

    // MARK: - Stakeholder Summaries

    /// Generate a summary for a specific stakeholder group.
    public static func generateStakeholderSummary(
        from doc: ReleaseDocumentation,
        for role: String
    ) -> String {
        var summary = """
        # Release \(doc.releaseVersion) - Summary for \(role)

        **Release Date**: \(formatDate(doc.releaseDate))

        ## Overview

        \(doc.summary)

        """

        // Add role-specific notes if available
        if let roleNotes = doc.stakeholderNotes[role] {
            summary += """

            ## Specific Notes for \(role)

            \(roleNotes)

            """
        }

        // Add relevant breaking changes
        if !doc.breakingChanges.isEmpty {
            summary += """

            ## Action Required

            This release includes breaking changes that may affect your work:

            """
            for change in doc.breakingChanges {
                summary += "- \(change.description)\n"
            }
        }

        // Add known issues
        let relevantIssues = doc.knownIssues.filter { $0.severity == .major || $0.severity == .critical }
        if !relevantIssues.isEmpty {
            summary += """

            ## Known Issues to Be Aware Of

            """
            for issue in relevantIssues {
                summary += "- \(issue.description)"
                if let workaround = issue.workaround {
                    summary += " (Workaround: \(workaround))"
                }
                summary += "\n"
            }
        }

        return summary
    }

    // MARK: - Helpers

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds)) seconds"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60)) minutes"
        } else {
            return String(format: "%.1f hours", seconds / 3600)
        }
    }
}

// MARK: - Codex Page Content

/// Content for a Codex page.
public struct CodexPageContent: Sendable {
    public let title: String
    public let content: String
    public let contentType: ContentType
    public let metadata: CodexPageMetadata

    public enum ContentType: String, Sendable {
        case markdown
        case html
        case plainText
    }

    public init(
        title: String,
        content: String,
        contentType: ContentType = .markdown,
        metadata: CodexPageMetadata = CodexPageMetadata()
    ) {
        self.title = title
        self.content = content
        self.contentType = contentType
        self.metadata = metadata
    }
}

/// Metadata for Codex pages.
public struct CodexPageMetadata: Sendable, Codable {
    public var releaseVersion: String?
    public var buildId: String?
    public var releaseType: String?
    public var affectedModules: [String]
    public var hasBreakingChanges: Bool
    public var hasMigrations: Bool
    public var tags: [String]

    public init(
        releaseVersion: String? = nil,
        buildId: String? = nil,
        releaseType: String? = nil,
        affectedModules: [String] = [],
        hasBreakingChanges: Bool = false,
        hasMigrations: Bool = false,
        tags: [String] = []
    ) {
        self.releaseVersion = releaseVersion
        self.buildId = buildId
        self.releaseType = releaseType
        self.affectedModules = affectedModules
        self.hasBreakingChanges = hasBreakingChanges
        self.hasMigrations = hasMigrations
        self.tags = tags
    }
}

// MARK: - Release Documentation Builder

/// Builder for creating release documentation.
public class ReleaseDocumentationBuilder {
    private var doc: ReleaseDocumentation

    public init(version: SemanticVersion, buildId: String) {
        self.doc = ReleaseDocumentation(
            releaseVersion: version,
            buildId: buildId
        )
    }

    public func summary(_ text: String) -> Self {
        doc = ReleaseDocumentation(
            releaseVersion: doc.releaseVersion,
            buildId: doc.buildId,
            codexSpaceId: doc.codexSpaceId,
            codexPageId: doc.codexPageId,
            title: doc.title,
            summary: text,
            releaseDate: doc.releaseDate,
            releaseType: doc.releaseType,
            whatChanged: doc.whatChanged,
            migrationNotes: doc.migrationNotes,
            breakingChanges: doc.breakingChanges,
            knownIssues: doc.knownIssues,
            testingInstructions: doc.testingInstructions,
            rollbackProcedure: doc.rollbackProcedure,
            affectedModules: doc.affectedModules,
            affectedDepartments: doc.affectedDepartments,
            stakeholderNotes: doc.stakeholderNotes
        )
        return self
    }

    public func releaseType(_ type: ReleaseType) -> Self {
        doc = ReleaseDocumentation(
            releaseVersion: doc.releaseVersion,
            buildId: doc.buildId,
            codexSpaceId: doc.codexSpaceId,
            codexPageId: doc.codexPageId,
            title: doc.title,
            summary: doc.summary,
            releaseDate: doc.releaseDate,
            releaseType: type,
            whatChanged: doc.whatChanged,
            migrationNotes: doc.migrationNotes,
            breakingChanges: doc.breakingChanges,
            knownIssues: doc.knownIssues,
            testingInstructions: doc.testingInstructions,
            rollbackProcedure: doc.rollbackProcedure,
            affectedModules: doc.affectedModules,
            affectedDepartments: doc.affectedDepartments,
            stakeholderNotes: doc.stakeholderNotes
        )
        return self
    }

    public func addChange(category: ChangeCategory, _ item: ChangeItem) -> Self {
        var changes = doc.whatChanged
        if changes[category] == nil {
            changes[category] = []
        }
        changes[category]?.append(item)

        doc = ReleaseDocumentation(
            releaseVersion: doc.releaseVersion,
            buildId: doc.buildId,
            codexSpaceId: doc.codexSpaceId,
            codexPageId: doc.codexPageId,
            title: doc.title,
            summary: doc.summary,
            releaseDate: doc.releaseDate,
            releaseType: doc.releaseType,
            whatChanged: changes,
            migrationNotes: doc.migrationNotes,
            breakingChanges: doc.breakingChanges,
            knownIssues: doc.knownIssues,
            testingInstructions: doc.testingInstructions,
            rollbackProcedure: doc.rollbackProcedure,
            affectedModules: doc.affectedModules,
            affectedDepartments: doc.affectedDepartments,
            stakeholderNotes: doc.stakeholderNotes
        )
        return self
    }

    public func addMigration(_ note: MigrationNote) -> Self {
        var notes = doc.migrationNotes
        notes.append(note)

        doc = ReleaseDocumentation(
            releaseVersion: doc.releaseVersion,
            buildId: doc.buildId,
            codexSpaceId: doc.codexSpaceId,
            codexPageId: doc.codexPageId,
            title: doc.title,
            summary: doc.summary,
            releaseDate: doc.releaseDate,
            releaseType: doc.releaseType,
            whatChanged: doc.whatChanged,
            migrationNotes: notes,
            breakingChanges: doc.breakingChanges,
            knownIssues: doc.knownIssues,
            testingInstructions: doc.testingInstructions,
            rollbackProcedure: doc.rollbackProcedure,
            affectedModules: doc.affectedModules,
            affectedDepartments: doc.affectedDepartments,
            stakeholderNotes: doc.stakeholderNotes
        )
        return self
    }

    public func addBreakingChange(_ change: BreakingChange) -> Self {
        var changes = doc.breakingChanges
        changes.append(change)

        doc = ReleaseDocumentation(
            releaseVersion: doc.releaseVersion,
            buildId: doc.buildId,
            codexSpaceId: doc.codexSpaceId,
            codexPageId: doc.codexPageId,
            title: doc.title,
            summary: doc.summary,
            releaseDate: doc.releaseDate,
            releaseType: doc.releaseType,
            whatChanged: doc.whatChanged,
            migrationNotes: doc.migrationNotes,
            breakingChanges: changes,
            knownIssues: doc.knownIssues,
            testingInstructions: doc.testingInstructions,
            rollbackProcedure: doc.rollbackProcedure,
            affectedModules: doc.affectedModules,
            affectedDepartments: doc.affectedDepartments,
            stakeholderNotes: doc.stakeholderNotes
        )
        return self
    }

    public func addKnownIssue(_ issue: KnownIssue) -> Self {
        var issues = doc.knownIssues
        issues.append(issue)

        doc = ReleaseDocumentation(
            releaseVersion: doc.releaseVersion,
            buildId: doc.buildId,
            codexSpaceId: doc.codexSpaceId,
            codexPageId: doc.codexPageId,
            title: doc.title,
            summary: doc.summary,
            releaseDate: doc.releaseDate,
            releaseType: doc.releaseType,
            whatChanged: doc.whatChanged,
            migrationNotes: doc.migrationNotes,
            breakingChanges: doc.breakingChanges,
            knownIssues: issues,
            testingInstructions: doc.testingInstructions,
            rollbackProcedure: doc.rollbackProcedure,
            affectedModules: doc.affectedModules,
            affectedDepartments: doc.affectedDepartments,
            stakeholderNotes: doc.stakeholderNotes
        )
        return self
    }

    public func addStakeholderNote(role: String, note: String) -> Self {
        var notes = doc.stakeholderNotes
        notes[role] = note

        doc = ReleaseDocumentation(
            releaseVersion: doc.releaseVersion,
            buildId: doc.buildId,
            codexSpaceId: doc.codexSpaceId,
            codexPageId: doc.codexPageId,
            title: doc.title,
            summary: doc.summary,
            releaseDate: doc.releaseDate,
            releaseType: doc.releaseType,
            whatChanged: doc.whatChanged,
            migrationNotes: doc.migrationNotes,
            breakingChanges: doc.breakingChanges,
            knownIssues: doc.knownIssues,
            testingInstructions: doc.testingInstructions,
            rollbackProcedure: doc.rollbackProcedure,
            affectedModules: doc.affectedModules,
            affectedDepartments: doc.affectedDepartments,
            stakeholderNotes: notes
        )
        return self
    }

    public func affectedModules(_ modules: [String]) -> Self {
        doc = ReleaseDocumentation(
            releaseVersion: doc.releaseVersion,
            buildId: doc.buildId,
            codexSpaceId: doc.codexSpaceId,
            codexPageId: doc.codexPageId,
            title: doc.title,
            summary: doc.summary,
            releaseDate: doc.releaseDate,
            releaseType: doc.releaseType,
            whatChanged: doc.whatChanged,
            migrationNotes: doc.migrationNotes,
            breakingChanges: doc.breakingChanges,
            knownIssues: doc.knownIssues,
            testingInstructions: doc.testingInstructions,
            rollbackProcedure: doc.rollbackProcedure,
            affectedModules: modules,
            affectedDepartments: doc.affectedDepartments,
            stakeholderNotes: doc.stakeholderNotes
        )
        return self
    }

    public func build() -> ReleaseDocumentation {
        return doc
    }
}
