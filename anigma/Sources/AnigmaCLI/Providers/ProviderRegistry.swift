import Foundation

/// Registry for managing inference providers
public actor ProviderRegistry {
    private var providers: [String: InferenceProvider] = [:]
    private var activeProvider: InferenceProvider?

    public init() {
        // Register all available providers
        registerProvider(DeepSeekProvider())
        registerProvider(OpenAIProvider())
        registerProvider(AnthropicProvider())
        registerProvider(GoogleProvider())
        registerProvider(OllamaProvider())
    }

    public func registerProvider(_ provider: InferenceProvider) {
        providers[provider.name.lowercased()] = provider
    }

    public func availableProviders() -> [String] {
        Array(providers.keys).sorted()
    }

    public func getProvider(name: String) -> InferenceProvider? {
        providers[name.lowercased()]
    }

    public func configureProvider(name: String, apiKey: String?) async throws {
        guard let provider = providers[name.lowercased()] else {
            throw ProviderError.invalidResponse("Provider \(name) not found")
        }

        try await provider.configure(apiKey: apiKey)

        // Validate configuration
        let isValid = try await provider.validateConfiguration()
        if isValid {
            activeProvider = provider
        } else {
            throw ProviderError.invalidAPIKey(provider: name)
        }
    }

    public func getActiveProvider() -> InferenceProvider? {
        activeProvider
    }

    public func setActiveProvider(name: String) throws {
        guard let provider = providers[name.lowercased()] else {
            throw ProviderError.invalidResponse("Provider \(name) not found")
        }
        activeProvider = provider
    }
}
