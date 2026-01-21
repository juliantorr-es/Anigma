//
//  InitCommand.swift
//  AnigmaCLIExecutable
//
//  Initialize anigma-cli: create database, download models, set up environment.
//

import Foundation
import ArgumentParser
import AnigmaCLIDatabase
import AnigmaCLIOnboarding
import AnigmaCLIProviders
import AnigmaCLICore
import AnigmaCore
import AnigmaCLITUI
import DatabaseCore

private typealias MaturityReport = MaturityAssessor.MaturityReport
private typealias MaturityCategory = MaturityAssessor.MaturityCategory
private typealias MaturitySuggestion = MaturityAssessor.MaturitySuggestion

struct AnigmaInitCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "init",
            abstract: "Initialize anigma-cli with full onboarding (providers, models, codebase analysis)."
        )
    }

    @Flag(name: .long, help: "Skip model download.")
    var skipModels: Bool = false

    @Flag(name: .long, help: "Skip codebase analysis.")
    var skipAnalysis: Bool = false

    @Flag(name: .long, help: "Skip provider setup.")
    var skipProviders: Bool = false

    @Flag(name: .long, help: "Force re-initialization.")
    var force: Bool = false

    @Flag(name: .long, help: "Non-interactive mode (use defaults).")
    var nonInteractive: Bool = false

    mutating func run() async throws {
        if nonInteractive {
            try await runNonInteractive()
        } else {
            try await runInteractive()
        }
    }

    // MARK: - Interactive Mode

    private func runInteractive() async throws {
        let engine = TUIEngine()
        let view = OnboardingView(engine: engine)
        let inputHandler = InputHandler()

        try await engine.enableRawMode()

        // Ensure cleanup
        await engine.clearScreen()

        // Step 1: Welcome
        await view.render(step: .welcome, progress: 0.1)
        _ = await waitForEnter(inputHandler)

        // 1. Create directory structure
        let anigmaDir = CLIEnvironment.defaultBaseDirectory()

        try createDirectoryStructure(anigmaDir: anigmaDir, force: force)

        // 2. Initialize database
        let dbPath = anigmaDir.appendingPathComponent("cli.db").path
        let db = try await initializeDatabase(dbPath: dbPath, force: force)

        // Step 2: Provider Setup
        if !skipProviders {
            var selectedProvider: String?
            while selectedProvider == nil {
                await view.render(step: .providerSetup, progress: 0.2)
                if let choice = await inputHandler.readLine() {
                     let provider = getProviderName(choice: choice)
                     if provider == "local" {
                         selectedProvider = "local"
                     } else {
                         // Need API key
                         await view.render(step: .providerSetup, progress: 0.2, message: "Enter API Key for \(provider):")
                         if let apiKey = await inputHandler.readLine(), !apiKey.isEmpty {
                             try saveProviderConfig(anigmaDir: anigmaDir, provider: provider, apiKey: apiKey)
                             selectedProvider = provider
                         }
                     }
                }
            }
        }

        // Step 3: Benchmarking
        if !skipModels {
            await view.render(step: .benchmarking, progress: 0.4, message: "Analyzing system capabilities...")
            let results = await SystemBenchmark().run()
            await view.render(step: .benchmarking, progress: 0.5, message: "System: \(results.cpuCores) cores, \(results.memoryGB)GB RAM. \(results.hasMetalSupport ? "Metal GPU" : "CPU only")")
            try await Task.sleep(nanoseconds: 1_000_000_000)

            // Step 4: Models
            await view.render(step: .modelDownload, progress: 0.6, message: "Selected models:\n" + results.recommendations.map { "  • \($0.name)" }.joined(separator: "\n"))
            _ = await waitForEnter(inputHandler)
            // Note: Actual download skipped in interactive init for speed, just like original
        }

        // Step 5: Indexing
        if !skipAnalysis {
             await view.render(step: .indexing, progress: 0.8, message: "Scanning codebase...")
             try await analyzeCodebase(database: db)
             await view.render(step: .indexing, progress: 0.9, message: "Codebase analysis complete.")
             try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // Complete
        await view.render(step: .complete, progress: 1.0)
        _ = await waitForEnter(inputHandler)

        await engine.disableRawMode()
        await engine.clearScreen()

        print("Setup complete. Run 'anigma chat' to start.")
    }

    private func waitForEnter(_ inputHandler: InputHandler) async -> Bool {
        while true {
            guard let key = await inputHandler.readKey() else { continue }
            switch key {
            case .enter: return true
            case .ctrlC: return false // Should handle exit better
            default: break
            }
        }
    }

    // MARK: - Non-Interactive Mode (Original Logic)

    private func runNonInteractive() async throws {
        print("🚀 Welcome to Anigma CLI - Intelligent Coding Assistant")
        print("═══════════════════════════════════════════════════════\n")

        // 1. Create directory structure
        let anigmaDir = CLIEnvironment.defaultBaseDirectory()

        try createDirectoryStructure(anigmaDir: anigmaDir, force: force)

        // 2. Initialize database
        let dbPath = anigmaDir.appendingPathComponent("cli.db").path
        let db = try await initializeDatabase(dbPath: dbPath, force: force)

        // 3. Provider setup
        if !skipProviders {
            print("\n📡 STEP 1: Provider Configuration")
            print("───────────────────────────────────")
            try await setupProviders(anigmaDir: anigmaDir)
        }

        // 4. System benchmark
        if !skipModels {
            print("\n⚡ STEP 2: System Benchmarking")
            print("───────────────────────────────")
            try await runSystemBenchmark()
        }

        // 5. Model recommendations
        if !skipModels {
            print("\n🧠 STEP 3: Model Setup")
            print("───────────────────────")
            let modelsDir = anigmaDir.appendingPathComponent("models")
            try await setupModels(modelsDir: modelsDir, interactive: false)
        }

        // 6. Codebase analysis
        if !skipAnalysis {
            print("\n📚 STEP 4: Codebase Analysis")
            print("─────────────────────────────")
            try await analyzeCodebase(database: db)
        }

        // 7. Maturity assessment
        if !skipAnalysis {
            print("\n🔍 STEP 5: Maturity Assessment")
            print("────────────────────────────────")
            try await runMaturityAssessment(database: db, interactive: false)
        }

        print("\n✨ Initialization Complete!")
    }

    // MARK: - Helper Methods

    private func createDirectoryStructure(anigmaDir: URL, force: Bool) throws {
        let dirs = [
            anigmaDir,
            anigmaDir.appendingPathComponent("models"),
            anigmaDir.appendingPathComponent("artifacts"),
            anigmaDir.appendingPathComponent("cache"),
            anigmaDir.appendingPathComponent("logs")
        ]

        for dir in dirs {
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                // print("✅ Created \(dir.lastPathComponent)/ directory")
            }
        }
    }

    private func initializeDatabase(dbPath: String, force: Bool) async throws -> CLIDatabaseActor {
        if force && FileManager.default.fileExists(atPath: dbPath) {
            try FileManager.default.removeItem(atPath: dbPath)
        }

        let config = CLIDatabaseConfig(databasePath: dbPath)
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        return db
    }

    private func setupProviders(anigmaDir: URL) async throws {
        // Simple non-interactive fallback
        print("Using local-only mode by default for non-interactive setup.")
    }

    private func saveProviderConfig(anigmaDir: URL, provider: String, apiKey: String) throws {
        let providersPath = anigmaDir.appendingPathComponent("providers.json")
        let config = ["provider": provider, "apiKey": apiKey]
        let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try data.write(to: providersPath)
    }

    private func getProviderName(choice: String) -> String {
        switch choice {
        case "1": return "deepseek"
        case "2": return "openai"
        case "3": return "anthropic"
        case "4": return "google"
        case "5": return "ollama"
        case "6": return "aws-bedrock"
        case "7": return "azure-openai"
        default: return "local"
        }
    }

    private func runSystemBenchmark() async throws {
        let benchmark = SystemBenchmark()
        _ = await benchmark.run()
        // No output in non-interactive unless necessary
    }

    private func setupModels(modelsDir: URL, interactive: Bool) async throws {
        print("Models will auto-download on first use")
    }

    private func analyzeCodebase(database: CLIDatabaseActor) async throws {
        let workspacePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let digestor = CodebaseDigestor(database: database, workspacePath: workspacePath)
        let result = try await digestor.analyze()
        _ = await digestor.generateExplanation(result: result)
    }

    private func runMaturityAssessment(database: CLIDatabaseActor, interactive: Bool) async throws {
        let assessor = makeMaturityAssessor(database: database)
        _ = try await assessor.assess()
    }

    private func prioritizeSuggestions(suggestions: [MaturitySuggestion], database: CLIDatabaseActor) async throws {
        // No-op for now
    }
}

// MARK: - Supporting Types

private struct SystemBenchmark {
    struct Results {
        let cpuCores: Int
        let memoryGB: Int
        let hasGPU: Bool
        let gpuName: String?
        let hasMetalSupport: Bool
        let recommendations: [ModelRecommendation]
    }

    struct ModelRecommendation {
        let name: String
        let reason: String
    }

    func run() async -> Results {
        let cores = ProcessInfo.processInfo.processorCount
        let memory = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) // GB

        #if os(macOS)
        let hasMetal = true
        let gpuName = "Apple Silicon"
        #else
        let hasMetal = false
        let gpuName: String? = nil
        #endif

        var recommendations: [ModelRecommendation] = []

        if memory >= 16 {
            recommendations.append(ModelRecommendation(
                name: "llama-3.1-8b-instruct-4bit",
                reason: "Balanced performance"
            ))
        } else {
            recommendations.append(ModelRecommendation(
                name: "phi-3.5-mini-instruct-4bit",
                reason: "Lightweight"
            ))
        }

        return Results(
            cpuCores: cores,
            memoryGB: memory,
            hasGPU: hasMetal,
            gpuName: gpuName,
            hasMetalSupport: hasMetal,
            recommendations: recommendations
        )
    }
}
