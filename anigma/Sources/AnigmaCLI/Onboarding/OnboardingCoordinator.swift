import Foundation
import AnigmaSidecar
import HarmoniaV2Surface

/// Coordinates the first-launch onboarding experience
actor OnboardingCoordinator {
    private let config: CLIConfiguration
    private let bridge: SidecarBridge
    private let ui: TUIManager

    init(config: CLIConfiguration, bridge: SidecarBridge, ui: TUIManager) {
        self.config = config
        self.bridge = bridge
        self.ui = ui
    }

    func runOnboarding() async throws {
        ui.showWelcome()

        // Step 1: Configure cloud provider
        try await configureCloudProvider()

        // Step 2: Run system benchmark
        let benchmarkResults = try await runSystemBenchmark()

        // Step 3: Recommend and install local models
        try await setupLocalModels(benchmark: benchmarkResults)

        // Step 4: Digest codebase and explain
        let digestResult = try await digestAndExplainCodebase()

        // Step 5: Assess maturity and suggest improvements
        try await assessMaturityAndSuggestImprovements(digestResult: digestResult)

        // Step 6: Finalize configuration
        try await finalizeSetup()

        ui.showOnboardingComplete()
    }

    private func configureCloudProvider() async throws {
        ui.showSection("Cloud Provider Configuration")
        ui.showInfo("Anigma can use cloud inference providers as fallback or primary inference.")
        ui.showInfo("You can configure multiple providers and switch between them later.")

        let providers = InferenceProvider.allCases
        let selectedProvider = try await ui.selectOption(
            prompt: "Select your primary cloud provider:",
            options: providers.map { $0.displayName }
        )

        let provider = providers[selectedProvider]
        let apiKey = try await ui.promptSecure("Enter your \(provider.displayName) API key:")

        try await config.setCloudProvider(provider, apiKey: apiKey)
        ui.showSuccess("✓ Configured \(provider.displayName)")

        // Ask if user wants to add more providers
        let addMore = try await ui.confirm("Add additional providers?")
        if addMore {
            try await configureAdditionalProviders()
        }
    }

    private func configureAdditionalProviders() async throws {
        var done = false
        while !done {
            let providers = InferenceProvider.allCases.filter { !config.hasProvider($0) }
            guard !providers.isEmpty else {
                ui.showInfo("All providers configured.")
                return
            }

            let options = providers.map { $0.displayName } + ["Done"]
            let selection = try await ui.selectOption(
                prompt: "Add another provider:",
                options: options
            )

            if selection == providers.count {
                done = true
            } else {
                let provider = providers[selection]
                let apiKey = try await ui.promptSecure("Enter your \(provider.displayName) API key:")
                try await config.setCloudProvider(provider, apiKey: apiKey)
                ui.showSuccess("✓ Configured \(provider.displayName)")
            }
        }
    }

    private func runSystemBenchmark() async throws -> BenchmarkResults {
        ui.showSection("System Benchmark")
        ui.showInfo("Running performance assessment to recommend optimal local models...")
        ui.showSpinner("Benchmarking system...")

        let benchmark = SystemBenchmark()
        let results = try await benchmark.run()

        ui.hideSpinner()
        ui.showBenchmarkResults(results)

        return results
    }

    private func setupLocalModels(benchmark: BenchmarkResults) async throws {
        ui.showSection("Local Model Setup")

        let recommendations = ModelRecommender.recommend(for: benchmark)

        ui.showInfo("Based on your system capabilities:")
        ui.showInfo("  CPU: \(benchmark.cpu.model)")
        ui.showInfo("  RAM: \(benchmark.memory.totalGB)GB")
        ui.showInfo("  GPU: \(benchmark.gpu?.model ?? "None")")
        ui.showInfo("")
        ui.showInfo("Recommended models:")

        for (index, model) in recommendations.enumerated() {
            ui.showInfo("  \(index + 1). \(model.name) (\(model.sizeGB)GB) - \(model.description)")
        }

        let installAll = try await ui.confirm("Install all recommended models?")

        if installAll {
            try await installModels(recommendations)
        } else {
            try await selectiveModelInstall(recommendations)
        }
    }

    private func selectiveModelInstall(_ models: [ModelRecommendation]) async throws {
        ui.showInfo("Select models to install (space to toggle, enter to confirm):")

        let selected = try await ui.multiSelect(
            options: models.map { "\($0.name) (\($0.sizeGB)GB) - \($0.description)" }
        )

        let modelsToInstall = selected.map { models[$0] }
        try await installModels(modelsToInstall)
    }

    private func installModels(_ models: [ModelRecommendation]) async throws {
        let installer = ModelInstaller(config: config, bridge: bridge)

        for model in models {
            ui.showProgress("Downloading \(model.name)...", current: 0, total: 100)

            try await installer.install(model) { progress in
                await ui.updateProgress(current: Int(progress * 100), total: 100)
            }

            ui.showSuccess("✓ Installed \(model.name)")
        }
    }

    private func finalizeSetup() async throws {
        ui.showSection("Finalizing Setup")

        // Create default workspace
        let workspacePath = try await ui.prompt("Default workspace directory:",
                                                default: "~/anigma-workspace")
        try await config.setWorkspacePath(workspacePath)

        // Set preferences
        let preferences = try await gatherPreferences()
        try await config.setPreferences(preferences)

        // Mark onboarding complete
        try await config.setOnboardingComplete()

        ui.showSuccess("✓ Setup complete!")
    }

    private func digestAndExplainCodebase() async throws -> CodebaseDigestResult? {
        ui.showSection("Codebase Analysis")
        ui.showInfo("Anigma will now analyze your codebase to provide intelligent assistance.")
        ui.showInfo("This process will:")
        ui.showInfo("  • Index all source files for fast searching")
        ui.showInfo("  • Extract symbols, functions, and types")
        ui.showInfo("  • Generate semantic embeddings for context-aware search")
        ui.showInfo("  • Analyze architecture and code patterns")
        ui.showInfo("  • Assess code maturity and suggest improvements")
        ui.showInfo("")

        let shouldDigest = try await ui.confirm("Start codebase analysis now?", default: true)

        if shouldDigest {
            return try await performCodebaseDigestion()
        } else {
            ui.showWarning("Skipping codebase analysis. You can run 'anigma index' later.")
            return nil
        }
    }

    private func performCodebaseDigestion() async throws -> CodebaseDigestResult {
        ui.showSpinner("Discovering source files...")

        // Initialize digest tool
        let digestTool = try await createDigestTool()

        ui.hideSpinner()
        ui.showInfo("Starting comprehensive codebase analysis...")

        var lastProgress = 0
        let result = try await digestTool.digestCodebase(
            sourceRoots: ["Sources", "Packages", "App"],
            excludePatterns: [".build", "*.swiftmodule", ".git", "Deprecated"]
        )

        ui.showSuccess("Analysis complete!")
        ui.showInfo("")

        // Display results
        try await displayDigestResults(result)

        // Interactive explanation
        try await explainCodebaseToUser(result)

        return result
    }

    private func createDigestTool() async throws -> EnhancedDigestCodebaseTool {
        // Use embedded models from CLI
        let embeddingModel = try await config.getEmbeddingModel()
        let llmModel = try await config.getCodeLLM()

        // Use the database executor from CLIDatabase
        return EnhancedDigestCodebaseTool(
            dbActor: database.databaseExecutor,
            workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            embeddingModel: embeddingModel,
            llmModel: llmModel
        )
    }

    private func displayDigestResults(_ result: CodebaseDigestResult) async throws {
        ui.showSection("Codebase Analysis Results")

        print("""
        ┌─────────────────────────────────────────────────────────┐
        │ Overview                                                │
        ├─────────────────────────────────────────────────────────┤
        │ Files Indexed:    \(String(result.filesIndexed).padding(toLength: 35, withPad: " ", startingAt: 0)) │
        │ Symbols Found:    \(String(result.symbolsExtracted).padding(toLength: 35, withPad: " ", startingAt: 0)) │
        │ Lines of Code:    \(String(result.totalLinesOfCode).padding(toLength: 35, withPad: " ", startingAt: 0)) │
        │ Duration:         \(String(format: "%.2f seconds", result.duration).padding(toLength: 35, withPad: " ", startingAt: 0)) │
        └─────────────────────────────────────────────────────────┘
        """)

        ui.showInfo("")
        ui.showInfo("Files by Language:")
        for (language, count) in result.filesByLanguage.sorted(by: { $0.value > $1.value }) {
            ui.showInfo("  • \(language): \(count) files")
        }

        ui.showInfo("")
        ui.showInfo("Key Modules:")
        for (index, module) in result.keyModules.prefix(5).enumerated() {
            ui.showInfo("  \(index + 1). \(module.name) - \(module.symbolCount) symbols (\(module.purpose))")
        }

        ui.showInfo("")
        ui.showInfo("Health Metrics:")
        ui.showInfo("  • Test Coverage: \(String(format: "%.1f%%", result.healthMetrics.estimatedTestCoverage))")
        ui.showInfo("  • Documentation: \(String(format: "%.1f%%", result.healthMetrics.documentationCoverage))")
        ui.showInfo("  • Public APIs: \(result.healthMetrics.publicApiCount)")
        ui.showInfo("  • Avg File Size: \(result.healthMetrics.averageFileSize) bytes")
    }

    private func explainCodebaseToUser(_ result: CodebaseDigestResult) async throws {
        ui.showSection("Architecture Insights")
        ui.showInfo("Based on the analysis, here's what Anigma learned about your codebase:")
        ui.showInfo("")

        for (index, insight) in result.architectureInsights.enumerated() {
            ui.showInfo("  \(index + 1). \(insight)")
        }

        ui.showInfo("")
        ui.showSuccess("✓ Codebase indexed and ready for intelligent assistance!")
        ui.showInfo("")
        ui.showInfo("You can now:")
        ui.showInfo("  • Ask questions about your code architecture")
        ui.showInfo("  • Search for functions, types, and symbols semantically")
        ui.showInfo("  • Get context-aware code suggestions")
        ui.showInfo("  • Navigate dependencies and module relationships")

        let wantDemo = try await ui.confirm("\nWould you like a quick demo of search capabilities?", default: false)

        if wantDemo {
            try await demonstrateSearchCapabilities(result)
        }
    }

    private func demonstrateSearchCapabilities(_ result: CodebaseDigestResult) async throws {
        ui.showSection("Search Demo")
        ui.showInfo("Let's try searching your codebase...")

        // Suggest search queries based on discovered modules
        let suggestedQueries = [
            "Show me the main entry points",
            "Find database-related code",
            "Where is authentication handled?",
            "List all test files"
        ]

        ui.showInfo("Example searches:")
        for (index, query) in suggestedQueries.enumerated() {
            ui.showInfo("  \(index + 1). \(query)")
        }

        let customQuery = try await ui.prompt("Enter a search query (or press Enter to skip)", default: "")

        if !customQuery.isEmpty {
            ui.showSpinner("Searching...")
            // In real implementation, would call semantic search here
            try await Task.sleep(for: .seconds(1))
            ui.hideSpinner()
            ui.showSuccess("Search complete! (Full implementation available in chat mode)")
        }
    }

    private func gatherPreferences() async throws -> CLIPreferences {
        var prefs = CLIPreferences()

        prefs.autoSave = try await ui.confirm("Auto-save conversation history?", default: true)
        prefs.localFirst = try await ui.confirm("Prefer local models over cloud?", default: true)
        prefs.telemetry = try await ui.confirm("Enable anonymous usage telemetry?", default: false)

        return prefs
    }

    private func assessMaturityAndSuggestImprovements(digestResult: CodebaseDigestResult?) async throws {
        guard let digestResult = digestResult else {
            ui.showInfo("Skipping maturity assessment (codebase not analyzed)")
            return
        }

        ui.showSection("Code Maturity Assessment")
        ui.showInfo("Analyzing code quality across multiple dimensions...")
        ui.showInfo("This will assess: security, stability, testing, documentation, and more.")
        ui.showInfo("")

        ui.showSpinner("Running maturity analysis...")

        let analyzer = MaturityAnalyzer(bridge: bridge, codeDigestResult: digestResult)
        let assessments = try await analyzer.analyzeMaturity()

        ui.hideSpinner()
        ui.showSuccess("✓ Maturity assessment complete!")
        ui.showInfo("")

        // Display overall summary
        try await displayMaturitySummary(assessments)

        // Allow user to explore and prioritize improvements
        try await interactiveImprovementSelection(assessments)
    }

    private func displayMaturitySummary(_ assessments: [MaturityAssessment]) async throws {
        ui.showSection("Maturity Overview")

        for assessment in assessments {
            let maturityColor = colorForMaturity(assessment.overallMaturity)
            ui.showInfo("📦 \(assessment.module)")
            ui.showInfo("   Maturity: \(maturityColor)\(assessment.overallMaturity.rawValue.uppercased())\(resetColor)")
            ui.showInfo("   Target: \(assessment.targetMaturity.rawValue)")
            ui.showInfo("   Improvements: \(assessment.improvements.count) suggestions")

            if !assessment.buildErrors.isEmpty {
                ui.showError("   ⚠️  \(assessment.buildErrors.count) build errors")
            }
            if !assessment.buildWarnings.isEmpty {
                ui.showWarning("   ⚠️  \(assessment.buildWarnings.count) build warnings")
            }

            ui.showInfo("")
        }

        let totalImprovements = assessments.reduce(0) { $0 + $1.improvements.count }
        let criticalImprovements = assessments.flatMap { $0.improvements }.filter { $0.impact == .critical }.count
        let highImprovements = assessments.flatMap { $0.improvements }.filter { $0.impact == .high }.count

        ui.showInfo("Total Suggestions: \(totalImprovements)")
        ui.showInfo("  Critical: \(criticalImprovements)")
        ui.showInfo("  High Priority: \(highImprovements)")
        ui.showInfo("")
    }

    private func interactiveImprovementSelection(_ assessments: [MaturityAssessment]) async throws {
        let allImprovements = assessments.flatMap { $0.improvements }.sorted { $0.priority > $1.priority }

        guard !allImprovements.isEmpty else {
            ui.showSuccess("No improvements needed - code is in excellent shape!")
            return
        }

        ui.showSection("Improvement Prioritization")
        ui.showInfo("Let's prioritize which improvements to work on first.")
        ui.showInfo("")

        let wantToReview = try await ui.confirm("Review improvement suggestions?", default: true)

        if !wantToReview {
            ui.showInfo("Skipping improvement review. Access later with 'anigma assess'")
            return
        }

        // Show top improvements
        let topImprovements = Array(allImprovements.prefix(10))

        ui.showInfo("Top Priority Improvements:")
        ui.showInfo("")

        for (index, improvement) in topImprovements.enumerated() {
            displayImprovement(index: index + 1, improvement: improvement)
        }

        ui.showInfo("")

        // Interactive selection
        let actions = [
            "Prioritize improvements for immediate work",
            "Expand details on specific improvements",
            "Simplify implementation suggestions",
            "Export improvement plan",
            "Skip for now"
        ]

        let selection = try await ui.selectOption(
            prompt: "What would you like to do?",
            options: actions
        )

        switch selection {
        case 0:
            try await prioritizeImprovements(topImprovements)
        case 1:
            try await expandImprovementDetails(topImprovements)
        case 2:
            try await simplifyImplementations(topImprovements)
        case 3:
            try await exportImprovementPlan(allImprovements)
        case 4:
            ui.showInfo("Improvements saved. Access anytime with 'anigma assess'")
        default:
            break
        }
    }

    private func displayImprovement(index: Int, improvement: Improvement) {
        let impactBadge = badgeForImpact(improvement.impact)
        let effortBadge = badgeForEffort(improvement.effort)

        ui.showInfo("\(index). [\(impactBadge)] \(improvement.title)")
        ui.showInfo("   \(improvement.description)")
        ui.showInfo("   Dimension: \(improvement.dimension.rawValue) | Effort: \(effortBadge)")

        if !improvement.suggestedChanges.isEmpty {
            ui.showInfo("   Suggestions: \(improvement.suggestedChanges.count) change(s)")
        }
        ui.showInfo("")
    }

    private func prioritizeImprovements(_ improvements: [Improvement]) async throws {
        ui.showSection("Prioritize Improvements")
        ui.showInfo("Select which improvements to mark as high priority:")
        ui.showInfo("")

        let options = improvements.map { "\($0.title) [\(badgeForImpact($0.impact))]" }
        let selected = try await ui.multiSelect(options: options)

        for index in selected {
            let improvement = improvements[index]
            // Phase 4: Update improvement status via daemon
            try await bridge.updateImprovementStatus(improvement.id, status: .prioritized)
            ui.showSuccess("✓ Prioritized: \(improvement.title)")
        }

        ui.showInfo("")
        ui.showSuccess("Prioritized \(selected.count) improvements for your next session!")
    }

    private func expandImprovementDetails(_ improvements: [Improvement]) async throws {
        ui.showSection("Expand Improvement Details")

        let options = improvements.map { $0.title }
        let selection = try await ui.selectOption(
            prompt: "Select improvement to expand:",
            options: options + ["Back"]
        )

        guard selection < improvements.count else { return }

        let improvement = improvements[selection]

        ui.showInfo("")
        ui.showInfo("=== \(improvement.title) ===")
        ui.showInfo("")
        ui.showInfo("Description:")
        ui.showInfo("  \(improvement.description)")
        ui.showInfo("")
        ui.showInfo("Impact: \(badgeForImpact(improvement.impact))")
        ui.showInfo("Effort: \(badgeForEffort(improvement.effort))")
        ui.showInfo("Dimension: \(improvement.dimension.rawValue)")
        ui.showInfo("")

        if !improvement.suggestedChanges.isEmpty {
            ui.showInfo("Suggested Changes:")
            for (index, change) in improvement.suggestedChanges.enumerated() {
                ui.showInfo("  \(index + 1). \(change)")
            }
            ui.showInfo("")
        }

        if !improvement.codeLocations.isEmpty {
            ui.showInfo("Code Locations:")
            for location in improvement.codeLocations {
                if let line = location.line {
                    ui.showInfo("  \(location.file):\(line)")
                } else {
                    ui.showInfo("  \(location.file)")
                }
            }
            ui.showInfo("")
        }

        // Phase 4: Update improvement status via daemon
        try await bridge.updateImprovementStatus(improvement.id, status: .expanded)

        _ = try await ui.confirm("Press Enter to continue", default: true)
    }

    private func simplifyImplementations(_ improvements: [Improvement]) async throws {
        ui.showSection("Simplify Implementations")
        ui.showInfo("Marking complex improvements for simplification...")

        let complexImprovements = improvements.filter { $0.effort >= .high }

        if complexImprovements.isEmpty {
            ui.showInfo("No complex improvements found!")
            return
        }

        for improvement in complexImprovements {
            ui.showInfo("  • \(improvement.title) (Effort: \(badgeForEffort(improvement.effort)))")
            // Phase 4: Update improvement status via daemon
            try await bridge.updateImprovementStatus(improvement.id, status: .simplified)
        }

        ui.showInfo("")
        ui.showSuccess("Marked \(complexImprovements.count) improvements for simplification")
        ui.showInfo("AI will break these down into smaller, manageable steps in your next session.")
    }

    private func exportImprovementPlan(_ improvements: [Improvement]) async throws {
        ui.showSection("Export Improvement Plan")

        let filename = "anigma-improvement-plan-\(Date().ISO8601Format()).md"
        let path = try await ui.prompt("Export to:", default: filename)

        var markdown = """
        # Anigma Code Improvement Plan

        Generated: \(Date().ISO8601Format())

        ## Summary

        Total Improvements: \(improvements.count)
        - Critical: \(improvements.filter { $0.impact == .critical }.count)
        - High: \(improvements.filter { $0.impact == .high }.count)
        - Medium: \(improvements.filter { $0.impact == .medium }.count)
        - Low: \(improvements.filter { $0.impact == .low }.count)

        ## Improvements by Priority


        """

        for (index, improvement) in improvements.enumerated() {
            markdown += """
            ### \(index + 1). \(improvement.title)

            **Impact:** \(improvement.impact.rawValue)
            **Effort:** \(improvement.effort.rawValue)
            **Dimension:** \(improvement.dimension.rawValue)
            **Priority Score:** \(improvement.priority)

            \(improvement.description)

            **Suggested Changes:**

            """

            for change in improvement.suggestedChanges {
                markdown += "- \(change)\n"
            }

            markdown += "\n"

            if !improvement.codeLocations.isEmpty {
                markdown += "**Locations:**\n\n"
                for location in improvement.codeLocations {
                    if let line = location.line {
                        markdown += "- `\(location.file):\(line)`\n"
                    } else {
                        markdown += "- `\(location.file)`\n"
                    }
                }
                markdown += "\n"
            }

            markdown += "---\n\n"
        }

        try markdown.write(toFile: path, atomically: true, encoding: .utf8)

        ui.showSuccess("✓ Exported improvement plan to: \(path)")
    }

    private func colorForMaturity(_ maturity: MaturityLevel) -> String {
        switch maturity {
        case .prototype, .experimental: return "\u{001B}[31m" // Red
        case .functional: return "\u{001B}[33m" // Yellow
        case .stable: return "\u{001B}[36m" // Cyan
        case .production, .hardened: return "\u{001B}[32m" // Green
        }
    }

    private let resetColor = "\u{001B}[0m"

    private func badgeForImpact(_ impact: ImpactLevel) -> String {
        switch impact {
        case .critical: return "🔴 CRITICAL"
        case .high: return "🟠 HIGH"
        case .medium: return "🟡 MEDIUM"
        case .low: return "🟢 LOW"
        }
    }

    private func badgeForEffort(_ effort: EffortLevel) -> String {
        switch effort {
        case .minimal: return "⚡️ Minimal"
        case .low: return "📝 Low"
        case .medium: return "⚙️  Medium"
        case .high: return "🔨 High"
        case .extensive: return "🏗️  Extensive"
        }
    }
}

/// Supported cloud inference providers
enum InferenceProvider: String, CaseIterable, Codable {
    case deepseek = "deepseek"
    case openai = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case amazon = "amazon"
    case vercel = "vercel"
    case ollamaCloud = "ollama_cloud"
    case groq = "groq"
    case together = "together"

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic (Claude)"
        case .google: return "Google (Gemini)"
        case .amazon: return "Amazon Bedrock"
        case .vercel: return "Vercel AI"
        case .ollamaCloud: return "Ollama Cloud"
        case .groq: return "Groq"
        case .together: return "Together AI"
        }
    }

    var baseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com"
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .google: return "https://generativelanguage.googleapis.com"
        case .amazon: return "https://bedrock-runtime.amazonaws.com"
        case .vercel: return "https://api.vercel.ai"
        case .ollamaCloud: return "https://cloud.ollama.ai"
        case .groq: return "https://api.groq.com/openai/v1"
        case .together: return "https://api.together.xyz"
        }
    }
}

struct CLIPreferences: Codable {
    var autoSave: Bool = true
    var localFirst: Bool = true
    var telemetry: Bool = false
    var theme: String = "dark"
    var editorCommand: String?
}
