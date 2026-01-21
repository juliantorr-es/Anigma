//
//  CapabilityToken.swift
//  AnigmaDaemonCore
//
//  Capability token minting and validation.
//

import CryptoKit
import Foundation

/// Capability token for scoped access
public struct CapabilityToken: Codable, Sendable {
    public let clientId: String
    public let scopes: [String]
    public let expiresAt: Date
    public let nonce: String

    public init(clientId: String, scopes: [String], expiresAt: Date) {
        self.clientId = clientId
        self.scopes = scopes
        self.expiresAt = expiresAt
        self.nonce = UUID().uuidString
    }

    /// Check if token is expired
    public func isExpired() -> Bool {
        return Date() > expiresAt
    }

    /// Check if token has required scope
    public func hasScope(_ scope: String) -> Bool {
        return scopes.contains(scope) || scopes.contains("*")
    }

    /// Encode token to bytes
    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Decode token from bytes
    public static func decode(from data: Data) throws -> CapabilityToken {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CapabilityToken.self, from: data)
    }
}

/// Capability token manager
public actor CapabilityTokenManager {
    private var activeSessions: [String: CapabilityToken] = [:]

    public init() {}

    /// Mint a new capability token
    public func mintToken(
        clientName: String,
        requestedScopes: [String]
    ) -> CapabilityToken {
        let clientId = UUID().uuidString

        // Grant requested scopes (in production, apply policy here)
        let grantedScopes = requestedScopes

        // Token expires in 1 hour
        let expiresAt = Date().addingTimeInterval(3600)

        let token = CapabilityToken(
            clientId: clientId,
            scopes: grantedScopes,
            expiresAt: expiresAt
        )

        activeSessions[clientId] = token
        return token
    }

    /// Validate a capability token
    public func validateToken(_ tokenData: Data, requiredScope: String) throws -> CapabilityToken {
        let token = try CapabilityToken.decode(from: tokenData)

        // Check expiry
        guard !token.isExpired() else {
            throw TokenError.expired
        }

        // Check scope
        guard token.hasScope(requiredScope) else {
            throw TokenError.insufficientScope(required: requiredScope, granted: token.scopes)
        }

        // Check active session
        guard activeSessions[token.clientId] != nil else {
            throw TokenError.invalidSession
        }

        return token
    }

    /// Revoke a session
    public func revokeSession(clientId: String) {
        activeSessions.removeValue(forKey: clientId)
    }
}

/// Token errors
public enum TokenError: Error, LocalizedError {
    case expired
    case insufficientScope(required: String, granted: [String])
    case invalidSession
    case invalidToken

    public var errorDescription: String? {
        switch self {
        case .expired:
            return "Token has expired"
        case .insufficientScope(let required, let granted):
            return "Insufficient scope: required '\(required)', granted \(granted)"
        case .invalidSession:
            return "Invalid session"
        case .invalidToken:
            return "Invalid token"
        }
    }
}
