//
//  AntigravityAuthManager.swift
//  AnigmaDaemonCore
//
//  Manages Google Antigravity OAuth flow and session state.
//

import Foundation
import AnigmaPrimitives
import DatabaseCore
import CryptoKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Configuration constants for Antigravity OAuth
public enum AntigravityConstants {
    // Default credentials (from opencode-antigravity-auth)
    public static let clientId = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
    public static let clientSecret = "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"
    
    public static let scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/cclog",
        "https://www.googleapis.com/auth/experimentsandconfigs"
    ]
    
    public static let redirectPath = "/oauth/antigravity/callback"
    public static let dailyEndpoint = "https://daily-cloudcode-pa.sandbox.googleapis.com"
    public static let prodEndpoint = "https://cloudcode-pa.googleapis.com"
}

public struct AntigravityTokenSet: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let projectId: String
    public let email: String
    public let expiresAt: Date
    
    public init(accessToken: String, refreshToken: String, projectId: String, email: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.projectId = projectId
        self.email = email
        self.expiresAt = expiresAt
    }
}

public actor AntigravityAuthManager {
    private let database: DatabaseActor
    private let redirectBaseURL: String
    
    // In-memory state storage for PKCE flow (nonce -> verifier)
    private var pendingStates: [String: String] = [:]
    
    public init(database: DatabaseActor, redirectBaseURL: String = "http://localhost:50051") {
        self.database = database
        self.redirectBaseURL = redirectBaseURL
    }
    
    public func initialize() async throws {
        try await createTables()
    }
    
    private func createTables() async throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS antigravity_tokens (
            email TEXT PRIMARY KEY,
            access_token TEXT NOT NULL,
            refresh_token TEXT NOT NULL,
            project_id TEXT NOT NULL,
            expires_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        """
        try await database.executeAsync(sql)
    }
    
    // MARK: - Authorization Flow
    
    public func generateAuthorizationURL() -> String {
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(verifier: verifier)
        let state = UUID().uuidString
        
        // Store verifier for callback
        pendingStates[state] = verifier
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: AntigravityConstants.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectBaseURL + AntigravityConstants.redirectPath),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: AntigravityConstants.scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"), // Force refresh token
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        return components.url!.absoluteString
    }
    
    public func handleCallback(code: String, state: String) async throws -> AntigravityTokenSet {
        guard let verifier = pendingStates.removeValue(forKey: state) else {
            throw AntigravityError.invalidState
        }
        
        // 1. Exchange Code
        let tokens = try await exchangeCode(code: code, verifier: verifier)
        
        // 2. Get User Info (Email)
        let email = try await fetchUserEmail(accessToken: tokens.access_token)
        
        // 3. Resolve Project ID
        let projectId = try await resolveProjectID(accessToken: tokens.access_token)
        
        // 4. Store
        let tokenSet = AntigravityTokenSet(
            accessToken: tokens.access_token,
            refreshToken: tokens.refresh_token ?? "", // Should handle missing refresh token case appropriately
            projectId: projectId,
            email: email,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokens.expires_in))
        )
        
        try await storeTokens(tokenSet)
        return tokenSet
    }
    
    // MARK: - API Calls
    
    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String?
        let scope: String
    }
    
    private func exchangeCode(code: String, verifier: String) async throws -> TokenResponse {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "client_id": AntigravityConstants.clientId,
            "client_secret": AntigravityConstants.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectBaseURL + AntigravityConstants.redirectPath,
            "code_verifier": verifier
        ]
        
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AntigravityError.tokenExchangeFailed(body)
        }
        
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
    
    private func fetchUserEmail(accessToken: String) async throws -> String {
        let url = URL(string: "https://www.googleapis.com/oauth2/v1/userinfo?alt=json")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct UserInfo: Decodable {
            let email: String
        }
        
        let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
        return userInfo.email
    }
    
    private func resolveProjectID(accessToken: String) async throws -> String {
        // Try daily endpoint first (per plugin)
        let endpoints = [AntigravityConstants.prodEndpoint, AntigravityConstants.dailyEndpoint]
        
        for endpoint in endpoints {
            if let pid = try await attemptLoadCodeAssist(endpoint: endpoint, accessToken: accessToken) {
                return pid
            }
        }
        
        // Fallback
        return "rising-fact-p41fc"
    }
    
    private func attemptLoadCodeAssist(endpoint: String, accessToken: String) async throws -> String? {
        let url = URL(string: "\(endpoint)/v1internal:loadCodeAssist")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Plugin headers
        request.setValue("antigravity/1.11.5 windows/amd64", forHTTPHeaderField: "User-Agent")
        request.setValue("google-cloud-sdk vscode_cloudshelleditor/0.1", forHTTPHeaderField: "X-Goog-Api-Client")
        request.setValue("{\"ideType\":\"IDE_UNSPECIFIED\",\"platform\":\"PLATFORM_UNSPECIFIED\",\"pluginType\":\"GEMINI\"}", forHTTPHeaderField: "Client-Metadata")
        
        let body: [String: Any] = [
            "metadata": [
                "ideType": "IDE_UNSPECIFIED",
                "platform": "PLATFORM_UNSPECIFIED",
                "pluginType": "GEMINI"
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            // Parse response to find project ID
            // Structure: { "cloudaicompanionProject": { "id": "..." } } or { "cloudaicompanionProject": "..." }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            
            if let projectStr = json["cloudaicompanionProject"] as? String {
                return projectStr
            }
            
            if let projectObj = json["cloudaicompanionProject"] as? [String: Any],
               let id = projectObj["id"] as? String {
                return id
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    // MARK: - Storage
    
    private func storeTokens(_ tokens: AntigravityTokenSet) async throws {
        let sql = """
        INSERT OR REPLACE INTO antigravity_tokens (email, access_token, refresh_token, project_id, expires_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        try await database.executeAsync(sql, parameters: [
            .text(tokens.email),
            .text(tokens.accessToken),
            .text(tokens.refreshToken),
            .text(tokens.projectId),
            .int(Int(tokens.expiresAt.timeIntervalSince1970)),
            .int(Int(Date().timeIntervalSince1970))
        ])
    }
    
    public func getActiveToken() async throws -> AntigravityTokenSet? {
        // Just get the most recently updated one for now
        let sql = "SELECT * FROM antigravity_tokens ORDER BY updated_at DESC LIMIT 1"
        let rows = try await database.query(sql)
        
        guard let row = rows.first,
              let email = row.string(for: "email"),
              let access = row.string(for: "access_token"),
              let refresh = row.string(for: "refresh_token"),
              let project = row.string(for: "project_id"),
              let expires = row.int(for: "expires_at") else {
            return nil
        }
        
        // Check expiry and refresh if needed
        let expiresAt = Date(timeIntervalSince1970: TimeInterval(expires))
        if Date() > expiresAt {
            // Need to pass email and projectId to refresh logic if they are not stored with the refresh token on the server side
            // but refreshTokens method below asks for them to construct the result
            return try await refreshTokens(refreshToken: refresh, email: email, projectId: project)
        }
        
        return AntigravityTokenSet(accessToken: access, refreshToken: refresh, projectId: project, email: email, expiresAt: expiresAt)
    }
    
    private func refreshTokens(refreshToken: String, email: String, projectId: String) async throws -> AntigravityTokenSet {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "client_id": AntigravityConstants.clientId,
            "client_secret": AntigravityConstants.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
             let body = String(data: data, encoding: .utf8) ?? "Unknown error"
             throw AntigravityError.tokenExchangeFailed("Refresh failed: \(body)")
        }
        
        struct RefreshResponse: Decodable {
            let access_token: String
            let expires_in: Int
        }
        
        let newTokens = try JSONDecoder().decode(RefreshResponse.self, from: data)
        
        let tokenSet = AntigravityTokenSet(
            accessToken: newTokens.access_token,
            refreshToken: refreshToken, // Keep old refresh token
            projectId: projectId,
            email: email,
            expiresAt: Date().addingTimeInterval(TimeInterval(newTokens.expires_in))
        )
        
        try await storeTokens(tokenSet)
        return tokenSet
    }
    
    // MARK: - Utils
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge(verifier: String) -> String {
        let data = verifier.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public enum AntigravityError: Error {
    case invalidState
    case tokenExchangeFailed(String)
}
