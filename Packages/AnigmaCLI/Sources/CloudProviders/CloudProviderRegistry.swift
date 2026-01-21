import Foundation

public final class CloudProviderRegistry: @unchecked Sendable {
    public static let shared = CloudProviderRegistry()

    private var providers: [String: CloudProvider] = [:]
    private var activeProvider: CloudProvider?

    private init() {
        registerDefaultProviders()
    }

    private func registerDefaultProviders() {
        providers["deepseek"] = DeepSeekProvider()
        providers["openai"] = OpenAIProvider()
        providers["anthropic"] = AnthropicProvider()
        providers["google"] = GoogleProvider()
    }

    public func getProvider(name: String) -> CloudProvider? {
        return providers[name.lowercased()]
    }

    public func listProviders() -> [String] {
        return Array(providers.keys.sorted())
    }

    public func setActiveProvider(_ provider: CloudProvider) {
        self.activeProvider = provider
    }

    public func getActiveProvider() -> CloudProvider? {
        return activeProvider
    }

    public func configureProvider(name: String, apiKey: String) async throws {
        guard let provider = getProvider(name: name) else {
            throw CloudProviderError.apiError("Provider not found: \(name)")
        }

        try await provider.configure(apiKey: apiKey)

        guard try await provider.validateConnection() else {
            throw CloudProviderError.invalidAPIKey
        }

        setActiveProvider(provider)
    }
}
