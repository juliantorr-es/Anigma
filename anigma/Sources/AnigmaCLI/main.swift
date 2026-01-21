import Foundation
import ArgumentParser

@main
struct AnigmaCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "anigma",
        abstract: "AI-powered development assistant",
        version: "1.0.0",
        subcommands: [Chat.self, Init.self, Models.self, Config.self],
        defaultSubcommand: Chat.self
    )
}

// MARK: - Chat Command

extension AnigmaCLI {
    struct Chat: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Start an interactive chat session"
        )

        @Flag(name: .long, help: "Skip onboarding check")
        var skipOnboarding = false

        func run() async throws {
            let config = try await CLIConfiguration.shared()
            let database = try await CLIDatabase.shared()
            let ui = TUIManager()

            // Check if onboarding is needed
            let isOnboarded = try await config.isOnboarded()

            if !isOnboarded && !skipOnboarding {
                let coordinator = OnboardingCoordinator(
                    config: config,
                    database: database,
                    ui: ui
                )
                try await coordinator.runOnboarding()
            }

            // Start chat session
            let chat = try await ChatInterface(
                config: config,
                database: database,
                ui: ui
            )

            try await chat.start()
        }
    }
}

// MARK: - Init Command

extension AnigmaCLI {
    struct Init: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Initialize or re-run onboarding"
        )

        @Flag(name: .long, help: "Force re-initialization")
        var force = false

        func run() async throws {
            let config = try await CLIConfiguration.shared()
            let database = try await CLIDatabase.shared()
            let ui = TUIManager()

            if !force {
                let isOnboarded = try await config.isOnboarded()
                if isOnboarded {
                    let confirm = try await ui.confirm(
                        "Anigma is already configured. Re-run onboarding?",
                        default: false
                    )
                    if !confirm {
                        await ui.showInfo("Cancelled")
                        return
                    }
                }
            }

            let coordinator = OnboardingCoordinator(
                config: config,
                database: database,
                ui: ui
            )

            try await coordinator.runOnboarding()
        }
    }
}

// MARK: - Models Command

extension AnigmaCLI {
    struct Models: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Manage local models",
            subcommands: [List.self, Install.self, Uninstall.self, Recommend.self]
        )

        struct List: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "List installed models"
            )

            func run() async throws {
                let config = try await CLIConfiguration.shared()
                let database = try await CLIDatabase.shared()
                let installer = ModelInstaller(config: config, database: database)

                let models = try await installer.listInstalled()

                if models.isEmpty {
                    print("No models installed")
                    return
                }

                print("\nInstalled Models:")
                print("─────────────────────────────────────────────────────")
                for model in models {
                    print("• \(model.name)")
                    print("  Type: \(model.type.rawValue)")
                    print("  Size: \(String(format: "%.1f", model.sizeGB)) GB")
                    print("  Quantization: \(model.quantization)")
                    print("  Installed: \(model.installedAt.formatted())")
                    print()
                }
            }
        }

        struct Install: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Install a model"
            )

            @Argument(help: "Model ID to install")
            var modelID: String

            func run() async throws {
                let config = try await CLIConfiguration.shared()
                let database = try await CLIDatabase.shared()
                let ui = TUIManager()

                // Run benchmark to get recommendations
                await ui.showSpinner("Running system benchmark...")
                let benchmark = try await SystemBenchmark().run()
                await ui.hideSpinner()

                let recommendations = ModelRecommender.recommend(for: benchmark)

                guard let model = recommendations.first(where: { $0.id == modelID }) else {
                    await ui.showError("Model not found: \(modelID)")
                    await ui.showInfo("\nAvailable models:")
                    for rec in recommendations {
                        await ui.showInfo("  \(rec.id) - \(rec.name)")
                    }
                    return
                }

                let installer = ModelInstaller(config: config, database: database)
                await ui.showProgress("Installing \(model.name)...", current: 0, total: 100)

                try await installer.install(model) { progress in
                    await ui.updateProgress(current: Int(progress * 100), total: 100)
                }

                await ui.showSuccess("Installed \(model.name)")
            }
        }

        struct Uninstall: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Uninstall a model"
            )

            @Argument(help: "Model ID to uninstall")
            var modelID: String

            func run() async throws {
                let config = try await CLIConfiguration.shared()
                let database = try await CLIDatabase.shared()
                let ui = TUIManager()

                let installer = ModelInstaller(config: config, database: database)
                try await installer.uninstall(modelID: modelID)

                await ui.showSuccess("Uninstalled model: \(modelID)")
            }
        }

        struct Recommend: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Show recommended models for this system"
            )

            func run() async throws {
                let ui = TUIManager()

                await ui.showSpinner("Running system benchmark...")
                let benchmark = try await SystemBenchmark().run()
                await ui.hideSpinner()

                await ui.showBenchmarkResults(benchmark)

                let recommendations = ModelRecommender.recommend(for: benchmark)

                print("\nRecommended Models:")
                print("─────────────────────────────────────────────────────")
                for model in recommendations {
                    print("• \(model.name) (\(model.id))")
                    print("  Type: \(model.type.rawValue)")
                    print("  Size: \(String(format: "%.1f", model.sizeGB)) GB")
                    print("  \(model.description)")
                    print()
                }
            }
        }
    }
}

// MARK: - Config Command

extension AnigmaCLI {
    struct Config: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Manage configuration",
            subcommands: [Show.self, SetProvider.self, SetWorkspace.self]
        )

        struct Show: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Show current configuration"
            )

            func run() async throws {
                let config = try await CLIConfiguration.shared()

                print("\nAnigma Configuration:")
                print("─────────────────────────────────────────────────────")

                if let provider = try? await config.getCurrentProvider() {
                    print("Provider: \(provider)")
                }

                if let workspace = try? await config.getWorkspacePath() {
                    print("Workspace: \(workspace)")
                }

                let configDir = try await config.configDirectory()
                print("Config Directory: \(configDir.path)")

                let modelsDir = try await config.modelsDirectory()
                print("Models Directory: \(modelsDir.path)")

                print()
            }
        }

        struct SetProvider: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Set active inference provider"
            )

            @Argument(help: "Provider name")
            var provider: String

            @Option(name: .long, help: "API key")
            var apiKey: String?

            func run() async throws {
                let config = try await CLIConfiguration.shared()
                let ui = TUIManager()

                if let apiKey = apiKey {
                    // Set provider with API key
                    guard let providerEnum = InferenceProvider(rawValue: provider.lowercased()) else {
                        await ui.showError("Unknown provider: \(provider)")
                        await ui.showInfo("Available providers: \(InferenceProvider.allCases.map { $0.rawValue }.joined(separator: ", "))")
                        return
                    }

                    try await config.setCloudProvider(providerEnum, apiKey: apiKey)
                    await ui.showSuccess("Configured \(providerEnum.displayName)")
                }

                try await config.setCurrentProvider(provider)
                await ui.showSuccess("Active provider: \(provider)")
            }
        }

        struct SetWorkspace: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Set workspace directory"
            )

            @Argument(help: "Workspace path")
            var path: String

            func run() async throws {
                let config = try await CLIConfiguration.shared()
                let ui = TUIManager()

                try await config.setWorkspacePath(path)
                await ui.showSuccess("Workspace set to: \(path)")
            }
        }
    }
}
