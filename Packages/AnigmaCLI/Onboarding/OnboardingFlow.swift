//
//  OnboardingFlow.swift
//  AnigmaCLI
//
//  First-run initialization flow with provider setup, benchmarking, and codebase analysis.
//

import Foundation
import AnigmaCLICore
import AnigmaCLIDatabase
import AnigmaCLIProviders
import AnigmaCLIML
import DatabaseCore
import ModelManagement

public actor OnboardingFlow {
    private let database: CLIDatabaseActor
    private let workspacePath: URL
    private let configPath: URL
    private let providerRegistry: ProviderRegistry
    private let digestor: CodebaseDigestor
    private var mlCoordinator: MLBackendCoordinator?

    public init(
        database: CLIDatabaseActor,
        workspacePath: URL,
        configPath: URL,
        providerRegistry: ProviderRegistry,
        digestor: CodebaseDigestor
    ) {
        self.database = database
        self.workspacePath = workspacePath
        self.configPath = configPath
        self.providerRegistry = providerRegistry
        self.digestor = digestor
    }

    public struct OnboardingResult {
        public let providersConfigured: [String]
        public let localModelsRecommended: [ModelRecommendation]
        public let benchmarkResults: BenchmarkResults
        public let codebaseAnalysis: CodebaseDigestor.AnalysisResult
        public let configSaved: Bool
        public let mlBackendStatus: BackendStatus?
    }

    public struct ModelRecommendation {
        public let modelID: String
        public let displayName: String
        public let purpose: ModelPurpose
        public let estimatedRAM: Int // MB
        public let downloadURL: String?
        public let shouldDownload: Bool

        public enum ModelPurpose: String {
            case chat = "Chat/Code Completion"
            case embeddings = "Semantic Search"
            case refactoring = "Code Refactoring"
        }
    }

    public struct BenchmarkResults {
        public let cpuCores: Int
        public let totalRAM: Int // GB
        public let availableRAM: Int // GB
        public let gpuAvailable: Bool
        public let gpuMemory: Int? // GB
        public let recommendTier: ModelTier

        public enum ModelTier: String {
            case heavy = "Heavy (70B+ models)"
            case medium = "Medium (13B-30B models)"
            case light = "Light (7B-8B models)"
            case minimal = "Minimal (3B models)"
        }
    }

    // MARK: - Main Flow

    public func run() async throws -> OnboardingResult {
        printBanner()

        // Step 1: System Benchmark
        print("\n🔍 Step 1: Benchmarking your system...")
        let benchmarkResults = await runSystemBenchmark()
        displayBenchmarkResults(benchmarkResults)

        // Step 2: Provider Setup
        print("\n🔑 Step 2: Configure inference providers")
        let providersConfigured = try await setupProviders()

        // Step 3: Local Model Recommendations
        print("\n🤖 Step 3: Recommending local models...")
        let recommendations = recommendModels(benchmark: benchmarkResults)
        let selectedModels = await selectModels(recommendations: recommendations)

        // Step 4: Codebase Analysis
        print("\n📊 Step 4: Analyzing your codebase...")
        let codebaseAnalysis = try await digestor.analyze()
        let explanation = await digestor.generateExplanation(result: codebaseAnalysis)
        print(explanation)

        // Step 5: Index Codebase (if user agrees)
        print("\n📇 Step 5: Index codebase for fast semantic search?")
        if await confirmAction("Index now? (recommended)") {
            print("⏳ Indexing codebase... running in the background.")
            await digestor.startBackgroundIndexing()
        } else {
            print("⏭️  Skipping background indexing for now")
        }

        // Step 6: Save Configuration
        print("\n💾 Step 6: Saving configuration...")
        let config = OnboardingConfiguration(
            providers: providersConfigured,
            localModels: selectedModels,
            benchmark: benchmarkResults,
            version: 1
        )
        let configSaved = try await saveConfiguration(config)

        // Step 7: Initialize ML Backend
        print("\n🤖 Step 7: Initializing ML backends...")
        let mlStatus = try await initializeMLBackend(
            providersConfigured: providersConfigured,
            selectedModels: selectedModels
        )

        print("\n✅ Onboarding complete! Run `anigma-cli chat` to start coding.")

        return OnboardingResult(
            providersConfigured: providersConfigured,
            localModelsRecommended: recommendations,
            benchmarkResults: benchmarkResults,
            codebaseAnalysis: codebaseAnalysis,
            configSaved: configSaved,
            mlBackendStatus: mlStatus
        )
    }

    // MARK: - System Benchmark

    private func runSystemBenchmark() async -> BenchmarkResults {
        let cpuCores = ProcessInfo.processInfo.processorCount
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let totalRAMGB = Int(physicalMemory / (1024 * 1024 * 1024))

        // Estimate available RAM (conservative: 50% of total)
        let availableRAMGB = max(1, totalRAMGB / 2)

        // GPU detection (simplified - would need Metal or platform-specific APIs)
        let gpuAvailable = checkGPUAvailability()
        let gpuMemory = gpuAvailable ? estimateGPUMemory() : nil

        // Determine tier based on resources
        let tier: BenchmarkResults.ModelTier
        if availableRAMGB >= 64 && gpuAvailable {
            tier = .heavy
        } else if availableRAMGB >= 32 {
            tier = .medium
        } else if availableRAMGB >= 16 {
            tier = .light
        } else {
            tier = .minimal
        }

        return BenchmarkResults(
            cpuCores: cpuCores,
            totalRAM: totalRAMGB,
            availableRAM: availableRAMGB,
            gpuAvailable: gpuAvailable,
            gpuMemory: gpuMemory,
            recommendTier: tier
        )
    }

    private func checkGPUAvailability() -> Bool {
        #if os(macOS)
        // On macOS, Metal is almost always available
        return true
        #else
        return false
        #endif
    }

    private func estimateGPUMemory() -> Int? {
        #if os(macOS)
        // Simplified: assume M-series Macs have unified memory
        // Real implementation would query Metal device
        return 16 // GB, conservative estimate
        #else
        return nil
        #endif
    }

    private func displayBenchmarkResults(_ results: BenchmarkResults) {
        print("""

        System Profile:
          • CPU Cores: \(results.cpuCores)
          • Total RAM: \(results.totalRAM) GB
          • Available RAM: \(results.availableRAM) GB
          • GPU: \(results.gpuAvailable ? "Available" : "Not available")
        """)

        if let gpuMem = results.gpuMemory {
            print("  • GPU Memory: ~\(gpuMem) GB")
        }

        print("\n  Recommended Model Tier: \(results.recommendTier.rawValue)")
    }

    // MARK: - Provider Setup

    private func setupProviders() async throws -> [String] {
        var configured: [String] = []
        let configDir = configPath.deletingLastPathComponent()

        print("\nYou can configure cloud providers for inference when local models are unavailable.")
        print("Providers: OpenAI, Anthropic, DeepSeek, Google Gemini, Vercel, Hugging Face, Ollama Cloud")
        print("\nPress Enter to skip, or paste your API key:")

        let providers = [
            ("OpenAI", "OPENAI_API_KEY", "sk-"),
            ("Anthropic", "ANTHROPIC_API_KEY", "sk-ant-"),
            ("DeepSeek", "DEEPSEEK_API_KEY", "sk-"),
            ("Google Gemini", "GOOGLE_API_KEY", "AI"),
            ("Vercel AI", "VERCEL_API_KEY", ""),
            ("Hugging Face", "HF_TOKEN", "hf_"),
            ("Ollama Cloud", "OLLAMA_API_KEY", "")
        ]

        for (name, envKey, prefix) in providers {
            // Check if already configured via environment or keychain
            if existingAPIKey(envKey, configDir: configDir) != nil {
                print("  ✓ \(name): Already configured")
                configured.append(name)
                continue
            }

            print("\n\(name) API Key (\(envKey)):")
            if let key = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
                if !prefix.isEmpty && !key.hasPrefix(prefix) {
                    print("  ⚠️  Warning: Key doesn't match expected prefix '\(prefix)'")
                }
                try await storeAPIKey(key: key, envKey: envKey, configDir: configDir)
                configured.append(name)
                print("  ✓ \(name) configured")
            } else {
                print("  ⏭️  Skipped")
            }
        }

        if configured.isEmpty {
            print("\n⚠️  No cloud providers configured. You'll rely on local inference only.")
        }

        return configured
    }

    private func storeAPIKey(key: String, envKey: String, configDir: URL) async throws {
        try KeychainStore.store(value: key, for: envKey, fallbackDirectory: configDir)
        print("  ℹ️  Stored \(envKey) securely")
    }

    private func existingAPIKey(_ envKey: String, configDir: URL) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[envKey], !envValue.isEmpty {
            return envValue
        }

        return try? KeychainStore.retrieve(key: envKey, fallbackDirectory: configDir)
    }

    // MARK: - Model Recommendations

    private func recommendModels(benchmark: BenchmarkResults) -> [ModelRecommendation] {
        var recommendations: [ModelRecommendation] = []

        switch benchmark.recommendTier {
        case .heavy:
            recommendations.append(ModelRecommendation(
                modelID: "llama-3.1-70b-instruct",
                displayName: "Llama 3.1 70B Instruct",
                purpose: .chat,
                estimatedRAM: 40000,
                downloadURL: "https://huggingface.co/meta-llama/Llama-3.1-70B-Instruct",
                shouldDownload: false // Too large for auto-download
            ))
            fallthrough

        case .medium:
            recommendations.append(ModelRecommendation(
                modelID: "deepseek-coder-33b",
                displayName: "DeepSeek Coder 33B",
                purpose: .chat,
                estimatedRAM: 20000,
                downloadURL: "https://huggingface.co/deepseek-ai/deepseek-coder-33b-instruct",
                shouldDownload: false
            ))
            fallthrough

        case .light:
            recommendations.append(ModelRecommendation(
                modelID: "llama-3.1-8b-instruct",
                displayName: "Llama 3.1 8B Instruct",
                purpose: .chat,
                estimatedRAM: 8000,
                downloadURL: "https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct",
                shouldDownload: true
            ))
            recommendations.append(ModelRecommendation(
                modelID: "qwen-2.5-7b-coder",
                displayName: "Qwen 2.5 7B Coder",
                purpose: .refactoring,
                estimatedRAM: 7000,
                downloadURL: "https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct",
                shouldDownload: true
            ))
            fallthrough

        case .minimal:
            recommendations.append(ModelRecommendation(
                modelID: "all-minilm-l6-v2",
                displayName: "All-MiniLM-L6-v2",
                purpose: .embeddings,
                estimatedRAM: 100,
                downloadURL: "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2",
                shouldDownload: true
            ))
            recommendations.append(ModelRecommendation(
                modelID: "phi-3.5-mini-instruct",
                displayName: "Phi 3.5 Mini Instruct",
                purpose: .chat,
                estimatedRAM: 3000,
                downloadURL: "https://huggingface.co/microsoft/Phi-3.5-mini-instruct",
                shouldDownload: benchmark.availableRAM >= 8
            ))
        }

        return recommendations
    }

    private func selectModels(recommendations: [ModelRecommendation]) async -> [String] {
        var selected: [String] = []

        print("\nRecommended models for your system:")
        for (idx, rec) in recommendations.enumerated() {
            let ramGB = rec.estimatedRAM / 1000
            let autoDownload = rec.shouldDownload ? " [AUTO]" : ""
            print("  \(idx + 1). \(rec.displayName) - \(rec.purpose.rawValue) (~\(ramGB) GB)\(autoDownload)")
        }

        print("\nModels marked [AUTO] will be downloaded automatically.")
        if await confirmAction("Proceed with recommended models?") {
            selected = recommendations.filter { $0.shouldDownload }.map { $0.modelID }

            if !selected.isEmpty {
                print("\n⏳ Downloading \(selected.count) model(s)... This may take several minutes.")

                let downloader = HuggingFaceModelDownloader()

                for modelID in selected {
                    guard let rec = recommendations.first(where: { $0.modelID == modelID }),
                          let urlString = rec.downloadURL,
                          let url = URL(string: urlString),
                          url.host == "huggingface.co" else {
                        print("⚠️  Skipping \(modelID): Invalid download URL")
                        continue
                    }

                    // Extract repo ID from URL: https://huggingface.co/user/repo -> user/repo
                    let pathComponents = url.pathComponents.filter { $0 != "/" }
                    guard pathComponents.count >= 2 else {
                        print("⚠️  Skipping \(modelID): Could not parse repo ID")
                        continue
                    }
                    let repo = "\(pathComponents[0])/\(pathComponents[1])"

                    print("\n⬇️  Downloading \(rec.displayName) (\(repo))...")

                    do {
                        let allFiles = try await downloader.listFiles(repo: repo)
                        let essentialPatterns = [
                            "config.json",
                            "tokenizer.json",
                            "tokenizer_config.json",
                            "special_tokens_map.json",
                            ".safetensors",
                            ".gguf",
                            ".mlmodel",
                            ".mlpackage"
                        ]

                        let filesToDownload = allFiles.filter { fileInfo in
                            fileInfo.isFile && essentialPatterns.contains { pattern in
                                fileInfo.path.hasSuffix(pattern) || fileInfo.path.contains(pattern)
                            }
                        }.map { $0.path }

                        guard !filesToDownload.isEmpty else {
                            print("❌ No essential files found for \(modelID)")
                            continue
                        }

                        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                            fatalError("Failed to unwrap appSupport")
                        }
                        let cacheDir = appSupport
                            .appendingPathComponent("Anigma/ModelCache", isDirectory: true)
                            .appendingPathComponent(repo.replacingOccurrences(of: "/", with: "_"), isDirectory: true)

                        final class DownloadProgressState: @unchecked Sendable {
                            var currentFile = ""
                            var lastPercentage = -1
                        }
                        let state = DownloadProgressState()

                        _ = try await downloader.download(
                            repo: repo,
                            files: filesToDownload,
                            destinationDirectory: cacheDir.path
                        ) { file, progress in
                            if file != state.currentFile {
                                state.currentFile = file
                                print("  📄 \(file)")
                                state.lastPercentage = -1
                            }

                            let percentage = Int(progress.percentage * 100)
                            if percentage % 10 == 0 && percentage != state.lastPercentage {
                                state.lastPercentage = percentage
                                print("     ... \(percentage)% \(progress.formattedSpeed)")
                            }
                        }
                        print("  ✅ Download complete")

                    } catch {
                        print("\n❌ Failed to download \(modelID): \(error)")
                    }
                }
            }
        }

        return selected
    }

    // MARK: - Configuration Persistence

    private func saveConfiguration(_ config: OnboardingConfiguration) async throws -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        let configDir = configPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        try data.write(to: configPath)
        print("  ✓ Configuration saved to \(configPath.path)")

        return true
    }

    // MARK: - Utilities

    private func printBanner() {
        print("""

        ╔══════════════════════════════════════════════════════════╗
        ║                                                          ║
        ║              Welcome to Anigma CLI! 🚀                  ║
        ║                                                          ║
        ║     Your AI-powered coding assistant with local-first   ║
        ║           inference and semantic code intelligence      ║
        ║                                                          ║
        ╚══════════════════════════════════════════════════════════╝

        Let's get you set up in a few quick steps...
        """)
    }

    private func confirmAction(_ prompt: String) async -> Bool {
        print("\(prompt) [Y/n]: ", terminator: "")
        let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "y"
        return input.isEmpty || input == "y" || input == "yes"
    }

    // MARK: - ML Backend Initialization

    private func initializeMLBackend(
        providersConfigured: [String],
        selectedModels: [String]
    ) async throws -> BackendStatus {
        let anigmaDir = configPath.deletingLastPathComponent()
        let mlxModelsDir = anigmaDir.appendingPathComponent("models/mlx")
        let llamaModelsDir = anigmaDir.appendingPathComponent("models/llama.cpp")

        // Build cloud API keys from stored configuration
        var cloudAPIKeys: [String: String] = [:]
        for provider in providersConfigured {
            if let key = try? KeychainStore.retrieve(key: "\(provider.uppercased())_API_KEY", fallbackDirectory: anigmaDir) {
                cloudAPIKeys[provider.lowercased()] = key
            }
        }

        let config = MLBackendCoordinator.BackendConfig(
            mlxModelsDir: mlxModelsDir,
            llamaCppModelsDir: llamaModelsDir,
            preferredChatBackend: nil, // Auto-detect
            preferredEmbeddingBackend: nil, // Auto-detect
            enableFallback: true,
            cloudAPIKeys: cloudAPIKeys
        )

        let coordinator = MLBackendCoordinator(config: config)
        try await coordinator.initialize()

        self.mlCoordinator = coordinator

        return await coordinator.getStatus()
    }
}

// MARK: - Configuration Types

public struct OnboardingConfiguration: Codable {
    let providers: [String]
    let localModels: [String]
    let benchmark: BenchmarkSummary
    let version: Int

    struct BenchmarkSummary: Codable {
        let cpuCores: Int
        let totalRAM: Int
        let availableRAM: Int
        let gpuAvailable: Bool
        let tier: String

        init(from results: OnboardingFlow.BenchmarkResults) {
            self.cpuCores = results.cpuCores
            self.totalRAM = results.totalRAM
            self.availableRAM = results.availableRAM
            self.gpuAvailable = results.gpuAvailable
            self.tier = results.recommendTier.rawValue
        }
    }

    init(
        providers: [String],
        localModels: [String],
        benchmark: OnboardingFlow.BenchmarkResults,
        version: Int
    ) {
        self.providers = providers
        self.localModels = localModels
        self.benchmark = BenchmarkSummary(from: benchmark)
        self.version = version
    }
}
