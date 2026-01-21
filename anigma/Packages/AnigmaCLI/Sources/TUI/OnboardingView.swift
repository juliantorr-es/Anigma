import Foundation

/// Onboarding flow TUI view
public actor OnboardingView {
    private let engine: TUIEngine
    private var currentStep = 0
    private var totalSteps = 5

    public enum Step {
        case welcome
        case providerSetup
        case benchmarking
        case modelDownload
        case indexing
        case complete
    }

    public init(engine: TUIEngine) {
        self.engine = engine
    }

    public func render(step: Step, progress: Double = 0.0, message: String = "") async {
        await engine.clearScreen()
        let size = await engine.getTerminalSize()

        // Title
        let title = engine.styled("🚀 Anigma CLI Setup", color: .cyan, style: .bold)
        await engine.renderText(row: 2, col: (size.cols - 20) / 2, text: title)

        // Progress indicator
        let stepNum = stepNumber(for: step)
        let progressText = "Step \(stepNum)/\(totalSteps)"
        await engine.renderText(row: 4, col: (size.cols - progressText.count) / 2, text: progressText)

        // Progress bar
        await engine.renderProgressBar(
            row: 5,
            col: (size.cols - 50) / 2,
            width: 50,
            progress: progress
        )

        // Main content box
        await engine.drawBox(
            row: 7,
            col: 5,
            width: size.cols - 10,
            height: size.rows - 12,
            title: stepTitle(for: step)
        )

        // Step-specific content
        await renderStepContent(step: step, message: message, startRow: 9, col: 7, maxWidth: size.cols - 14)

        // Footer
        let footer = engine.styled("Press Ctrl+C to cancel setup", color: .brightBlack, style: .dim)
        await engine.renderText(row: size.rows - 1, col: (size.cols - 30) / 2, text: footer)
    }

    private func stepNumber(for step: Step) -> Int {
        switch step {
        case .welcome: return 1
        case .providerSetup: return 2
        case .benchmarking: return 3
        case .modelDownload: return 4
        case .indexing: return 5
        case .complete: return 5
        }
    }

    private func stepTitle(for step: Step) -> String {
        switch step {
        case .welcome: return "Welcome"
        case .providerSetup: return "Provider Configuration"
        case .benchmarking: return "System Benchmark"
        case .modelDownload: return "Model Installation"
        case .indexing: return "Codebase Indexing"
        case .complete: return "Setup Complete"
        }
    }

    private func renderStepContent(step: Step, message: String, startRow: Int, col: Int, maxWidth: Int) async {
        let row = startRow

        switch step {
        case .welcome:
            let lines = [
                "Welcome to Anigma CLI!",
                "",
                "This setup will configure:",
                "  • Cloud AI provider (optional)",
                "  • Local ML models",
                "  • Codebase indexing",
                "  • Vector embeddings",
                "",
                "Press Enter to continue..."
            ]
            await engine.renderMultiline(startRow: row, col: col, lines: lines, maxWidth: maxWidth)

        case .providerSetup:
            let lines = [
                "Select your preferred AI provider:",
                "",
                "  1. OpenAI (GPT-4, GPT-3.5)",
                "  2. Anthropic (Claude)",
                "  3. DeepSeek",
                "  4. Google AI",
                "  5. Amazon Bedrock",
                "  6. Vercel AI",
                "  7. Skip (local-only)",
                "",
                message.isEmpty ? "Enter selection (1-7):" : message
            ]
            await engine.renderMultiline(startRow: row, col: col, lines: lines, maxWidth: maxWidth)

        case .benchmarking:
            let spinner = engine.styled("⠋", color: .cyan)
            await engine.renderText(row: row, col: col, text: "\(spinner) \(message)")

        case .modelDownload:
            let lines = [
                "Recommended models for your system:",
                "",
                message
            ]
            await engine.renderMultiline(startRow: row, col: col, lines: lines, maxWidth: maxWidth)

        case .indexing:
            let spinner = engine.styled("⠋", color: .green)
            await engine.renderText(row: row, col: col, text: "\(spinner) \(message)")

        case .complete:
            let checkmark = engine.styled("✓", color: .green, style: .bold)
            let lines = [
                "\(checkmark) Setup complete!",
                "",
                "Your Anigma CLI is ready to use.",
                "",
                "Try these commands:",
                "  • anigma chat         - Start interactive chat",
                "  • anigma ask <query>  - Ask a question",
                "  • anigma scan         - Analyze codebase",
                "",
                message
            ]
            await engine.renderMultiline(startRow: row, col: col, lines: lines, maxWidth: maxWidth)
        }
    }
}
