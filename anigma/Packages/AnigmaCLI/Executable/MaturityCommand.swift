//
//  MaturityCommand.swift
//  AnigmaCLIExecutable
//
//  Display and manage maturity assessment reports.
//

import Foundation
import ArgumentParser
import AnigmaCLIDatabase
import AnigmaCore
import AnigmaCLITUI

private typealias MaturityReport = MaturityAssessor.MaturityReport
private typealias MaturityCategory = MaturityAssessor.MaturityCategory
private typealias MaturitySuggestion = MaturityAssessor.MaturitySuggestion

struct AnigmaMaturityCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "maturity-report",
            abstract: "View detailed maturity assessment and improvement suggestions."
        )
    }

    @Flag(name: .long, help: "Show only high-priority suggestions.")
    var highPriorityOnly: Bool = false

    @Option(name: .long, help: "Filter by category (security|quality|testing|docs|performance).")
    var category: String?

    @Flag(name: .long, help: "Generate new assessment (re-analyze codebase).")
    var refresh: Bool = false

    @Flag(name: .long, help: "Use plain text output instead of TUI.")
    var text: Bool = false

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()

        if refresh {
            print("♻️  Re-analyzing codebase...")
            let assessor = makeMaturityAssessor(database: db)
            _ = try await assessor.assess()
            // In a real implementation, we would store this
        }

        // Load stored report (mock logic for now as database storage for reports isn't fully spec'd in this snippet)
        let assessor = makeMaturityAssessor(database: db)
        let report = try await assessor.assess()

        if text {
            displayReportText(report)
        } else {
            try await runInteractive(report: report, database: db)
        }
    }

    // MARK: - Interactive TUI

    private func runInteractive(report: MaturityReport, database: CLIDatabaseActor) async throws {
        let engine = TUIEngine()
        let view = MaturityAssessmentView(engine: engine)
        let inputHandler = InputHandler()

        try await engine.enableRawMode()
        defer {
            Task {
                await engine.disableRawMode()
                await engine.clearScreen()
            }
        }

        // Convert report to view model
        // Assuming one module for now
        let assessment = mapReportToAssessment(report: report)
        var assessments = [assessment]
        let selectedModule = 0
        var selectedSuggestion = 0

        while true {
            await view.render(assessments: assessments, selectedModule: selectedModule, selectedSuggestion: selectedSuggestion)

            guard let key = await inputHandler.readKey() else { continue }

            switch key {
            case .char("q"), .char("Q"), .ctrlC:
                await engine.disableRawMode()
                await engine.clearScreen()
                return

            case .up:
                if selectedSuggestion > 0 {
                    selectedSuggestion -= 1
                }

            case .down:
                if selectedSuggestion < assessments[selectedModule].suggestions.count - 1 {
                    selectedSuggestion += 1
                }

            case .space:
                // Toggle selection
                var currentSuggestions = assessments[selectedModule].suggestions
                if !currentSuggestions.isEmpty {
                    let current = currentSuggestions[selectedSuggestion]
                    let updated = MaturityAssessmentView.Suggestion(
                        priority: current.priority,
                        title: current.title,
                        description: current.description,
                        selected: !current.selected
                    )
                    currentSuggestions[selectedSuggestion] = updated

                    // Rebuild assessments array (struct copy)
                    let old = assessments[selectedModule]
                    let newAssessment = MaturityAssessmentView.Assessment(
                        module: old.module,
                        category: old.category,
                        currentLevel: old.currentLevel,
                        targetLevel: old.targetLevel,
                        issues: old.issues,
                        suggestions: currentSuggestions
                    )
                    assessments[selectedModule] = newAssessment
                }

            case .enter:
                // Apply logic (mock)
                await engine.disableRawMode()
                await engine.clearScreen()
                print("Applied selected suggestions (mock).")
                return

            default:
                break
            }
        }
    }

    private func mapReportToAssessment(report: MaturityReport) -> MaturityAssessmentView.Assessment {
        let suggestions = report.suggestions.map {
            MaturityAssessmentView.Suggestion(
                priority: mapPriority($0.priority),
                title: $0.title,
                description: $0.description,
                selected: false
            )
        }

        // Mock issues based on low scoring categories
        let issues = report.categories.filter { $0.score < 80 }.map {
            MaturityAssessmentView.Issue(
                severity: $0.score < 60 ? .error : .warning,
                message: "Low score in \($0.name): \($0.score)/100"
            )
        }

        return MaturityAssessmentView.Assessment(
            module: "Project Root",
            category: "Overall",
            currentLevel: report.overallScore / 20, // 0-5 scale
            targetLevel: 5,
            issues: issues,
            suggestions: suggestions
        )
    }

    private func mapPriority(_ priority: String) -> MaturityAssessmentView.Suggestion.Priority {
        switch priority.uppercased() {
        case "HIGH": return .high
        case "MEDIUM": return .medium
        default: return .low
        }
    }

    // MARK: - Text Mode (Legacy)

    private func displayReportText(_ report: MaturityAssessor.MaturityReport) {
        print("Overall Maturity Score: \(report.overallScore)/100\n")

        print("Category Breakdown:")
        for category in report.categories {
            let bar = progressBar(score: category.score)
            let emoji = category.score >= 80 ? "✅" : category.score >= 60 ? "⚠️" : "❌"
            print("  \(emoji) \(category.name.padding(toLength: 20, withPad: " ", startingAt: 0)) \(bar) \(category.score)/100")
        }

        print("\n🔧 Improvement Suggestions:")
        let filtered = filterSuggestions(report.suggestions)

        for (index, suggestion) in filtered.enumerated() {
            let icon = suggestion.priority == "HIGH" ? "🔴" : suggestion.priority == "MEDIUM" ? "🟡" : "🟢"
            print("\n  \(index + 1). \(icon) [\(suggestion.priority)] \(suggestion.title)")
            print("     → \(suggestion.description)")
        }

        if filtered.isEmpty {
            print("  No suggestions found matching your filters.")
        }
    }

    private func filterSuggestions(_ suggestions: [MaturityAssessor.MaturitySuggestion]) -> [MaturityAssessor.MaturitySuggestion] {
        var filtered = suggestions

        if highPriorityOnly {
            filtered = filtered.filter { $0.priority == "HIGH" }
        }

        if self.category != nil {
            // In real implementation, suggestions would have category tags
            // For now, just show all
        }

        return filtered
    }

    private func progressBar(score: Int) -> String {
        let filled = score / 10
        let empty = 10 - filled
        return "[\(String(repeating: "█", count: filled))\(String(repeating: "░", count: empty))]"
    }
}
