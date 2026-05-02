//
//  CapabilityTokenManager.swift
//  AnigmaDaemonCore
//

import Foundation

struct CapabilityToken: Codable, Sendable {
    let clientId: String
    let clientName: String
    let scopes: [String]
    let issuedAt: Date
    let expiresAt: Date
    let tokenId: String

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

actor CapabilityTokenManager {
    private let tokenLifetime: TimeInterval = 3600

    func mintToken(clientName: String, requestedScopes: [String]) -> CapabilityToken {
        let now = Date()
        return CapabilityToken(
            clientId: UUID().uuidString,
            clientName: clientName,
            scopes: Array(Set(requestedScopes)).sorted(),
            issuedAt: now,
            expiresAt: now.addingTimeInterval(tokenLifetime),
            tokenId: UUID().uuidString
        )
    }

    func validateToken(_ tokenData: Data, requiredScope: String) throws -> CapabilityToken {
        let token = try JSONDecoder().decode(CapabilityToken.self, from: tokenData)

        guard token.expiresAt > Date() else {
            throw DaemonError.configurationError("Capability token expired")
        }

        guard token.scopes.contains(requiredScope) else {
            throw DaemonError.configurationError("Missing required scope: \(requiredScope)")
        }

        return token
    }
}
