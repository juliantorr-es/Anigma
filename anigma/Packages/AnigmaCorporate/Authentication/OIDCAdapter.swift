//
//  OIDCAdapter.swift
//  AnigmaCorporate
//
//  Implements OIDC Authorization Code Flow with PKCE.
//

import Foundation
import AnigmaCore
import CryptoKit

public struct OIDCConfiguration: Sendable {
    public let issuer: URL
    public let clientId: String
    public let redirectUri: URL
    public let scopes: [String]

    public init(issuer: URL, clientId: String, redirectUri: URL, scopes: [String]) {
        self.issuer = issuer
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.scopes = scopes
    }
}

public struct OIDCTokenResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let idToken: String?
    public let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresIn = "expires_in"
    }
}

public actor OIDCAdapter {
    private let config: OIDCConfiguration
    private var codeVerifier: String?

    public init(configuration: OIDCConfiguration) {
        self.config = configuration
    }

    public func createAuthorizationURL() -> URL {
        let verifier = generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = generateCodeChallenge(verifier: verifier)

        guard let components = URLComponents(url: config.issuer.appendingPathComponent("authorize"), resolvingAgainstBaseURL: true) else {
            fatalError("Failed to unwrap components")
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri.absoluteString),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components.url!
    }

    public func exchangeCodeForToken(code: String) async throws -> OIDCTokenResponse {
        guard let verifier = codeVerifier else {
            throw CorporateError.authenticationFailed("Missing code verifier")
        }

        let url = config.issuer.appendingPathComponent("token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": config.redirectUri.absoluteString,
            "code_verifier": verifier
        ]

        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CorporateError.authenticationFailed("Token exchange failed")
        }

        return try JSONDecoder().decode(OIDCTokenResponse.self, from: data)
    }

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            fatalError("Failed to unwrap data")
        }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
