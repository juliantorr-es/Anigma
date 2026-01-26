import Foundation

/// Maturity assessment TUI view
public actor MaturityAssessmentView {
    private let engine: TUIEngine

    public struct Assessment: Sendable {
        public let module: String
        public let category: String
        public let currentLevel: Int
        public let targetLevel: Int
        public let issues: [Issue]
        public let suggestions: [Suggestion]

        public init(module: String, category: String, currentLevel: Int, targetLevel: Int, issues: [Issue], suggestions: [Suggestion]) {
            self.module = module
            self.category = category
            self.currentLevel = currentLevel
            self.targetLevel = targetLevel
            self.issues = issues
            self.suggestions = suggestions
        }
    }

    public struct Issue: Sendable {
        public let severity: Severity
        public let message: String

        public enum Severity: Sendable {
            case error, warning, info
        }

        public init(severity: Severity, message: String) {
            self.severity = severity
            self.message = message
        }
    }

    public struct Suggestion: Sendable {
        public let priority: Priority
        public let title: String
        public let description: String
        public let selected: Bool

        public enum Priority: Sendable {
            case high, medium, low
        }

        public init(priority: Priority, title: String, description: String, selected: Bool = false) {
            self.priority = priority
            self.title = title
            self.description = description
            self.selected = selected
        }
    }

    public init(engine: TUIEngine) {
        self.engine = engine
    }

    public func render(assessments: [Assessment], selectedModule: Int = 0, selectedSuggestion: Int = 0) async {
        await engine.clearScreen()
        let size = await engine.getTerminalSize()

        // Title
        let title = engine.styled("🔍 Maturity Assessment", color: .blue, style: .bold)
        await engine.renderText(row: 2, col: (size.cols - 25) / 2, text: title)

        guard !assessments.isEmpty, selectedModule < assessments.count else {
            await engine.renderText(row: 4, col: 5, text: "No assessments available")
            return
        }

        let assessment = assessments[selectedModule]

        // Module header
        let moduleHeader = engine.styled(assessment.module, color: .cyan, style: .bold)
        await engine.renderText(row: 4, col: 5, text: "Module: \(moduleHeader)")

        // Maturity level indicator
        let levelBar = renderLevelBar(current: assessment.currentLevel, target: assessment.targetLevel)
        await engine.renderText(row: 5, col: 5, text: "Maturity: \(levelBar)")

        // Issues box
        let issuesHeight = min(10, assessment.issues.count + 3)
        await engine.drawBox(
            row: 7,
            col: 3,
            width: size.cols - 6,
            height: issuesHeight,
            title: "Issues (\(assessment.issues.count))"
        )

        var row = 8
        for issue in assessment.issues.prefix(issuesHeight - 2) {
            let icon: String
            let color: TUIEngine.Color

            switch issue.severity {
            case .error:
                icon = "✗"
                color = .red
            case .warning:
                icon = "⚠"
                color = .yellow
            case .info:
                icon = "ℹ"
                color = .blue
            }

            let styledIcon = engine.styled(icon, color: color)
            await engine.renderText(row: row, col: 5, text: "\(styledIcon) \(issue.message)")
            row += 1
        }

        // Suggestions box
        let suggestionsStartRow = 7 + issuesHeight + 1
        let suggestionsHeight = size.rows - suggestionsStartRow - 3

        await engine.drawBox(
            row: suggestionsStartRow,
            col: 3,
            width: size.cols - 6,
            height: suggestionsHeight,
            title: "Improvement Suggestions"
        )

        row = suggestionsStartRow + 1
        for (index, suggestion) in assessment.suggestions.enumerated() {
            let isSelected = index == selectedSuggestion
            let checkbox = suggestion.selected ? "[✓]" : "[ ]"
            let prefix = isSelected ? "→ " : "  "

            let priorityIcon: String

            switch suggestion.priority {
            case .high:
                priorityIcon = "🔴"
            case .medium:
                priorityIcon = "🟡"
            case .low:
                priorityIcon = "🟢"
            }

            let titleText = isSelected ? engine.styled(suggestion.title, style: .bold) : suggestion.title
            await engine.renderText(
                row: row,
                col: 5,
                text: "\(prefix)\(checkbox) \(priorityIcon) \(titleText)"
            )
            row += 1

            if isSelected {
                let desc = engine.styled(suggestion.description, color: .brightBlack, style: .dim)
                await engine.renderText(row: row, col: 8, text: desc)
                row += 1
            }

            row += 1
            if row >= suggestionsStartRow + suggestionsHeight - 2 { break }
        }

        // Footer
        let controls = "↑/↓: Navigate  •  Space: Toggle  •  Enter: Apply Selected  •  Q: Quit"
        let footer = engine.styled(controls, color: .black, bg: .white)
        await engine.renderText(row: size.rows, col: 1, text: footer)
    }

    private func renderLevelBar(current: Int, target: Int) -> String {
        let levels = ["⬜️", "🟦", "🟨", "🟩", "🟢"]
        var bar = ""
        for i in 0..<5 {
            if i < current {
                bar += levels[min(i, levels.count - 1)]
            } else if i < target {
                bar += "⬛️"
            } else {
                bar += "⬜️"
            }
        }
        return bar + " \(current)/\(target)"
    }
}
