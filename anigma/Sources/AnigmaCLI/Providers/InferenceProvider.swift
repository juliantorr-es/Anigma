import Foundation

/// Protocol for all inference providers
public protocol InferenceProvider: Sendable {
    var name: String { get }
    var requiresAPIKey: Bool { get }

    func configure(apiKey: String?) async throws
    func validateConfiguration() async throws -> Bool
    func chat(messages: [ChatMessage], model: String?) async throws -> String
    func embed(text: String, model: String?) async throws -> [Float]
}

/// Chat message structure
public struct ChatMessage: Sendable, Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Provider configuration errors
public enum ProviderError: Error, CustomStringConvertible {
    case missingAPIKey(provider: String)
    case invalidAPIKey(provider: String)
    case networkError(Error)
    case invalidResponse(String)
    case modelNotAvailable(String)

    public var description: String {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider)"
        case .invalidAPIKey(let provider):
            return "Invalid API key for \(provider)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .modelNotAvailable(let model):
            return "Model not available: \(model)"
        }
    }
}
