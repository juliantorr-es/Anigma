//
//  AntigravityService.swift
//  AnigmaDaemonCore
//
//  Service for interacting with Google Antigravity (Cloud Code) API.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor AntigravityService {
    private let authManager: AntigravityAuthManager
    private let session: URLSession
    
    public init(authManager: AntigravityAuthManager) {
        self.authManager = authManager
        self.session = URLSession(configuration: .default)
    }
    
    /// Lists available models (Simulated for now)
    public func listModels() async throws -> [AntigravityModelInfo] {
        // Check if authenticated
        _ = try await authManager.getActiveToken()
        
        return [
            AntigravityModelInfo(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", provider: "Google"),
            AntigravityModelInfo(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", provider: "Google"),
            AntigravityModelInfo(id: "claude-3-5-sonnet", name: "Claude 3.5 Sonnet", provider: "Anthropic (via Vertex)")
        ]
    }
    
    /// Streams content generation
    public func streamGenerateContent(
        model: String,
        messages: [AntigravityContent],
        config: AntigravityGenerationConfig? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let token = try await authManager.getActiveToken() else {
            throw AntigravityError.tokenExchangeFailed("No active session")
        }
        
        // Construct URL
        let modelName = mapModelName(model)
        let endpoint = AntigravityConstants.prodEndpoint
        let urlString = "\(endpoint)/v1/projects/\(token.projectId)/locations/global/publishers/google/models/\(modelName):streamGenerateContent?alt=sse"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Headers from inspiration repo to emulate valid client
        request.setValue("antigravity/1.11.5 windows/amd64", forHTTPHeaderField: "User-Agent")
        request.setValue("google-cloud-sdk vscode_cloudshelleditor/0.1", forHTTPHeaderField: "X-Goog-Api-Client")
        request.setValue("{\"ideType\":\"IDE_UNSPECIFIED\",\"platform\":\"PLATFORM_UNSPECIFIED\",\"pluginType\":\"GEMINI\"}", forHTTPHeaderField: "Client-Metadata")
        
        // Body
        let requestBody = AntigravityGenerateContentRequest(
            contents: messages,
            generationConfig: config
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // Use bytes(for:) if available (Swift 5.5+) for true streaming
        // Fallback to dataTask for older environments is acceptable, but here we assume modern Swift.
        if #available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
             return AsyncThrowingStream { continuation in
                Task {
                    do {
                        let (bytes, response) = try await session.bytes(for: request)
                        
                        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                            // Try to read error body
                            // Cannot easily read bytes if we fail here, so just throw
                            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                            continuation.finish(throwing: AntigravityError.tokenExchangeFailed("API Error \(statusCode)"))
                            return
                        }
                        
                        for try await line in bytes.lines {
                            if line.hasPrefix("data: ") {
                                let jsonPart = String(line.dropFirst(6))
                                if jsonPart.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                                    continue
                                }
                                
                                // Parse JSON to extract text
                                if let jsonData = jsonPart.data(using: .utf8),
                                   let responseObj = try? JSONDecoder().decode(AntigravityGenerateContentResponse.self, from: jsonData),
                                   let candidates = responseObj.candidates,
                                   let first = candidates.first,
                                   let content = first.content,
                                   let parts = content.parts.first,
                                   let text = parts.text {
                                    continuation.yield(text)
                                }
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        } else {
            // Fallback for older platforms (not expected in this env)
            throw AntigravityError.tokenExchangeFailed("Platform not supported for streaming")
        }
    }
    
    private func mapModelName(_ input: String) -> String {
        // Map common names to Antigravity internal names if needed
        // For now, pass through or default to gemini-1.5-pro-preview-0409
        if input.contains("gemini-1.5-pro") {
            return "gemini-1.5-pro-preview-0409"
        }
        if input.contains("gemini-1.5-flash") {
            return "gemini-1.5-flash-preview-0514"
        }
        if input.contains("claude") {
            return "claude-3-5-sonnet@20240620" // Vertex naming convention
        }
        return "gemini-1.5-pro-preview-0409"
    }
}

public struct AntigravityModelInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let provider: String
}
