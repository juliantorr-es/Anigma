import Foundation
import AnigmaSidecar

// MARK: - Cloud Provider Protocol

public protocol CloudProvider: Sendable {
    var name: String { get }
    var supportsChat: Bool { get }
    var supportsEmbeddings: Bool { get }
    
    var bridge: SidecarBridge? { get set }

    func configure(apiKey: String) async throws
    func validateConnection() async throws -> Bool
    func chat(messages: [ChatMessage], model: String?, temperature: Double) async throws -> String
    func embeddings(texts: [String], model: String?) async throws -> [[Float]]
}

public struct ChatMessage: Sendable, Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public enum CloudProviderError: Error, CustomStringConvertible {
    case notConfigured
    case invalidAPIKey
    case networkError(String)
    case apiError(String)
    case unsupportedOperation
    case invalidResponse

    public var description: String {
        switch self {
        case .notConfigured: return "Provider not configured"
        case .invalidAPIKey: return "Invalid API key"
        case .networkError(let msg): return "Network error: \(msg)"
        case .apiError(let msg): return "API error: \(msg)"
        case .unsupportedOperation: return "Operation not supported"
        case .invalidResponse: return "Invalid API response"
        }
    }
}
