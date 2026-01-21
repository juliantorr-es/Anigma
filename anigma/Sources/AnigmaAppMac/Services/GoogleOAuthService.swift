import CryptoKit
import Foundation
import Security

struct GoogleOAuthToken: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let scope: String?
    let expiresAt: Date?
}

struct GoogleOAuthAuthRequest {
    let url: URL
    let state: String
    let codeVerifier: String
}

enum GoogleOAuthError: LocalizedError {
    case invalidConfiguration
    case invalidCallback
    case stateMismatch
    case missingCode
    case authorizationFailed(String)
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "OAuth configuration is invalid."
        case .invalidCallback:
            return "Invalid OAuth callback URL."
        case .stateMismatch:
            return "OAuth state mismatch. Please try again."
        case .missingCode:
            return "OAuth code missing from callback."
        case .authorizationFailed(let message):
            return "Authorization failed: \(message)"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        }
    }
}

struct GoogleOAuthService {
    // Configured URLSession with timeout for OAuth operations
    private static var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 30s for OAuth requests
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    static func makeAuthRequest(
        clientId: String,
        redirectURI: String,
        scopes: [String]
    ) throws -> GoogleOAuthAuthRequest {
        let trimmed = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GoogleOAuthError.invalidConfiguration }

        let state = randomBase64URL(bytes: 16)
        let verifier = randomBase64URL(bytes: 32)
        let challenge = codeChallenge(for: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: trimmed),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]

        guard let url = components?.url else { throw GoogleOAuthError.invalidConfiguration }
        return GoogleOAuthAuthRequest(url: url, state: state, codeVerifier: verifier)
    }

    static func extractCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw GoogleOAuthError.invalidCallback
        }
        let items = components.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            let description = items.first { $0.name == "error_description" }?.value
            throw GoogleOAuthError.authorizationFailed(description ?? error)
        }
        let state = items.first { $0.name == "state" }?.value
        if let state, state != expectedState {
            throw GoogleOAuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw GoogleOAuthError.missingCode
        }
        return code
    }

    static func exchangeCode(
        _ code: String,
        clientId: String,
        redirectURI: String,
        codeVerifier: String
    ) async throws -> GoogleOAuthToken {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded([
            "code": code,
            "client_id": clientId,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ])

        // Execute with retry and timeout
        let (data, response) = try await withRetry(maxAttempts: 3, initialDelay: 1.0) {
            try await urlSession.data(for: request)
        }
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GoogleOAuthError.tokenExchangeFailed(message)
        }

        if let errorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) {
            throw GoogleOAuthError.tokenExchangeFailed(errorResponse.errorDescription ?? errorResponse.error)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiresAt = tokenResponse.expiresIn.map {
            Date().addingTimeInterval(TimeInterval($0))
        }

        return GoogleOAuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            tokenType: tokenResponse.tokenType,
            scope: tokenResponse.scope,
            expiresAt: expiresAt
        )
    }

    static func refreshAccessToken(
        refreshToken: String,
        clientId: String
    ) async throws -> GoogleOAuthToken {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded([
            "client_id": clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ])

        // Execute with retry and timeout
        let (data, response) = try await withRetry(maxAttempts: 3, initialDelay: 1.0) {
            try await urlSession.data(for: request)
        }
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GoogleOAuthError.tokenRefreshFailed(message)
        }

        if let errorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) {
            throw GoogleOAuthError.tokenRefreshFailed(errorResponse.errorDescription ?? errorResponse.error)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiresAt = tokenResponse.expiresIn.map {
            Date().addingTimeInterval(TimeInterval($0))
        }

        return GoogleOAuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            tokenType: tokenResponse.tokenType,
            scope: tokenResponse.scope,
            expiresAt: expiresAt
        )
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    private static func randomBase64URL(bytes: Int) -> String {
        var buffer = [UInt8](repeating: 0, count: bytes)
        let status = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        if status != errSecSuccess {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return base64URL(Data(buffer))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formURLEncoded(_ params: [String: String]) -> Data? {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let encoded: String = params.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        .joined(separator: "&")
        return Data(encoded.utf8)
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int?
        let scope: String?
        let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case scope
            case tokenType = "token_type"
        }
    }

    private struct TokenErrorResponse: Decodable {
        let error: String
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
        }
    }
}
