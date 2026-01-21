import Foundation
import HarmoniaModule
import DatabaseCore

/// CLI configuration management with provider keys and model settings
actor CLIConfiguration {
    private let configPath: URL
    private var config: ConfigData

    struct ConfigData: Codable {
        var providers: [String: ProviderConfig] = [:]
        var workspace: String?
        var preferences = CLIPreferences()
        var onboardingComplete: Bool = false
        var databasePath: String?
        var localModels: [String] = []
    }

    struct ProviderConfig: Codable {
        let provider: String
        let apiKey: String
        let baseURL: String
        var isActive: Bool = true
    }

    init(configPath: URL? = nil) {
        self.configPath = configPath ?? Self.defaultConfigPath()

        // Load existing config or create new
        if let data = try? Data(contentsOf: self.configPath),
           let decoded = try? JSONDecoder().decode(ConfigData.self, from: data) {
            self.config = decoded
        } else {
            self.config = ConfigData()
        }
    }

    // MARK: - Provider Management

    func setCloudProvider(_ provider: InferenceProvider, apiKey: String) async throws {
        let providerConfig = ProviderConfig(
            provider: provider.rawValue,
            apiKey: apiKey,
            baseURL: provider.baseURL
        )
        config.providers[provider.rawValue] = providerConfig
        try await save()
    }

    func hasProvider(_ provider: InferenceProvider) -> Bool {
        return config.providers[provider.rawValue] != nil
    }

    func getProvider(_ provider: InferenceProvider) -> ProviderConfig? {
        return config.providers[provider.rawValue]
    }

    func getAllProviders() -> [ProviderConfig] {
        return Array(config.providers.values)
    }

    // MARK: - Workspace & Preferences

    func setWorkspacePath(_ path: String) async throws {
        let expandedPath = NSString(string: path).expandingTildeInPath
        config.workspace = expandedPath

        // Create workspace directory if needed
        try FileManager.default.createDirectory(
            atPath: expandedPath,
            withIntermediateDirectories: true
        )

        try await save()
    }

    func getWorkspacePath() -> String? {
        return config.workspace
    }

    func setPreferences(_ prefs: CLIPreferences) async throws {
        config.preferences = prefs
        try await save()
    }

    func getPreferences() -> CLIPreferences {
        return config.preferences
    }

    // MARK: - Onboarding

    func setOnboardingComplete() async throws {
        config.onboardingComplete = true
        try await save()
    }

    func isOnboardingComplete() -> Bool {
        return config.onboardingComplete
    }

    // MARK: - Database

    func getDatabasePath() async throws -> String {
        if let existing = config.databasePath {
            return existing
        }

        // Create default database path
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())

        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        try FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)

        let dbPath = anigmaDir.appendingPathComponent("anigma-cli.sqlite").path
        config.databasePath = dbPath
        try await save()

        return dbPath
    }

    // MARK: - Model Management

    func addLocalModel(_ modelId: String) async throws {
        if !config.localModels.contains(modelId) {
            config.localModels.append(modelId)
            try await save()
        }
    }

    func getLocalModels() -> [String] {
        return config.localModels
    }

    func getEmbeddingModel() async throws -> EmbeddingModel? {
        // Return first available embedding model
        // In real implementation, would initialize from config
        return nil // Placeholder
    }

    func getCodeLLM() async throws -> CodeLLMModel? {
        // Return configured code LLM
        // In real implementation, would initialize from config/providers
        return nil // Placeholder
    }

    // MARK: - Persistence

    private func save() async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        // Ensure config directory exists
        let configDir = configPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        try data.write(to: configPath)
    }

    static func defaultConfigPath() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())

        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        return anigmaDir.appendingPathComponent("config.json")
    }
}

// MARK: - Model Protocol Placeholders

protocol EmbeddingModel {
    func embed(_ text: String) async throws -> [Float]
}

protocol CodeLLMModel {
    func prompt(_ text: String) async throws -> String
}
