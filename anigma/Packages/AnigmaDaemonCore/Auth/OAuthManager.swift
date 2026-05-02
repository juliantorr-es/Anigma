//
//  OAuthManager.swift
//  AnigmaDaemonCore
//
//  OAuth 2.0 and JWT implementation using CryptoKit.
//

import Foundation
import CryptoKit
import DatabaseCore

// MARK: - Models

public struct OAuthUser: Codable, Sendable {
    public let id: String
    public let username: String
    public let roles: [String]
    public let createdAt: Date
}

public struct TokenResponse: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String = "Bearer"
    public let expiresIn: Int
    public let refreshToken: String?
    public let scope: String
}

struct JWTHeader: Codable {
    let alg: String = "ES256"
    let typ: String = "JWT"
    let kid: String?
}

struct JWTPayload: Codable {
    let iss: String
    let sub: String
    let exp: Int
    let iat: Int
    let scope: String
    let roles: [String]?
}

// MARK: - OAuth Manager

public actor OAuthManager {
    private let database: any DatabaseExecutor
    private let issuer: String = "anigma-daemon"
    private let tokenExpirationInterval: TimeInterval = 3600 // 1 hour
    private let refreshTokenExpirationInterval: TimeInterval = 86400 * 30 // 30 days
    
    // Signing Key
    private var privateKey: P256.Signing.PrivateKey?
    private var publicKey: P256.Signing.PublicKey?
    private var keyId: String = "key-1"
    
    public init(database: any DatabaseExecutor) {
        self.database = database
    }
    
    public func initialize() async throws {
        try await createTables()
        try await loadOrGenerateKeys()
        
        // Ensure default admin user exists
        if try await getUser(username: "admin") == nil {
            _ = try await createUser(username: "admin", roles: ["admin"])
        }
    }
    
    // MARK: - Database Setup
    
    private func createTables() async throws {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS oauth_users (
                id TEXT PRIMARY KEY,
                username TEXT NOT NULL UNIQUE,
                roles TEXT NOT NULL, -- JSON array
                created_at INTEGER NOT NULL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS refresh_tokens (
                token_hash TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                client_id TEXT NOT NULL,
                scopes TEXT NOT NULL,
                expires_at INTEGER NOT NULL,
                revoked INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(user_id) REFERENCES oauth_users(id)
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS signing_keys (
                kid TEXT PRIMARY KEY,
                private_key BLOB NOT NULL,
                created_at INTEGER NOT NULL
            )
            """
        ]
        for statement in statements {
            try await database.executeAsync(statement)
        }
    }
    
    // MARK: - Key Management
    
    private func loadOrGenerateKeys() async throws {
        let query = "SELECT private_key FROM signing_keys WHERE kid = ?"
        let rows = try await database.query(query, parameters: [.text(keyId)])
        
        if let row = rows.first, let keyData = row["private_key"]?.dataValue {
            self.privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
            self.publicKey = privateKey?.publicKey
        } else {
            // Generate new key
            let key = P256.Signing.PrivateKey()
            self.privateKey = key
            self.publicKey = key.publicKey
            
            let keyData = key.rawRepresentation
            let insert = "INSERT INTO signing_keys (kid, private_key, created_at) VALUES (?, ?, ?)"
            try await database.execute(insert, parameters: [
                .text(keyId),
                .blob(keyData),
                .int(Int(Date().timeIntervalSince1970))
            ])
        }
    }
    
    // MARK: - User Management
    
    public func createUser(username: String, roles: [String]) async throws -> OAuthUser {
        let user = OAuthUser(
            id: UUID().uuidString,
            username: username,
            roles: roles,
            createdAt: Date()
        )
        
        let rolesJson = try JSONEncoder().encode(roles)
        let rolesString = String(data: rolesJson, encoding: .utf8) ?? "[]"
        
        let sql = "INSERT INTO oauth_users (id, username, roles, created_at) VALUES (?, ?, ?, ?)"
        try await database.execute(sql, parameters: [
            .text(user.id),
            .text(user.username),
            .text(rolesString),
            .int(Int(user.createdAt.timeIntervalSince1970))
        ])
        
        return user
    }
    
    public func getUser(username: String) async throws -> OAuthUser? {
        let sql = "SELECT id, roles, created_at FROM oauth_users WHERE username = ?"
        let rows = try await database.query(sql, parameters: [.text(username)])
        
        guard let row = rows.first,
              let id = row["id"]?.stringValue,
              let rolesString = row["roles"]?.stringValue,
              let createdAtInt = row["created_at"]?.intValue else {
            return nil
        }
        
        let rolesData = Data(rolesString.utf8)
        let roles = (try? JSONDecoder().decode([String].self, from: rolesData)) ?? []
        let createdAt = Date(timeIntervalSince1970: TimeInterval(createdAtInt))
        
        return OAuthUser(id: id, username: username, roles: roles, createdAt: createdAt)
    }
    
    // MARK: - Token Issuance
    
    public func authorize(username: String, clientId: String, scopes: [String]) async throws -> TokenResponse {
        guard let user = try await getUser(username: username) else {
            throw OAuthError.invalidUser
        }
        
        return try await issueTokens(user: user, clientId: clientId, scopes: scopes)
    }
    
    public func refreshToken(token: String) async throws -> TokenResponse {
        let tokenHash = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
        
        let sql = """
        SELECT user_id, client_id, scopes, expires_at, revoked 
        FROM refresh_tokens WHERE token_hash = ?
        """
        
        let rows = try await database.query(sql, parameters: [.text(tokenHash)])
        guard let row = rows.first,
              let userId = row["user_id"]?.stringValue,
              let clientId = row["client_id"]?.stringValue,
              let scopesString = row["scopes"]?.stringValue,
              let expiresAtInt = row["expires_at"]?.intValue,
              let revoked = row["revoked"]?.intValue else {
            throw OAuthError.invalidToken
        }
        
        if revoked != 0 { throw OAuthError.revoked }
        if Date().timeIntervalSince1970 > Double(expiresAtInt) { throw OAuthError.expired }
        
        let scopes = scopesString.split(separator: " ").map(String.init)
        
        // Revoke old refresh token (Rotate)
        try await revokeRefreshToken(hash: tokenHash)
        
        // Get user details
        guard let user = try await getUserById(id: userId) else {
            throw OAuthError.invalidUser
        }
        
        return try await issueTokens(user: user, clientId: clientId, scopes: scopes)
    }
    
    private func getUserById(id: String) async throws -> OAuthUser? {
        let sql = "SELECT username, roles, created_at FROM oauth_users WHERE id = ?"
        let rows = try await database.query(sql, parameters: [.text(id)])
        
        guard let row = rows.first,
              let username = row["username"]?.stringValue,
              let rolesString = row["roles"]?.stringValue,
              let createdAtInt = row["created_at"]?.intValue else {
            return nil
        }
        
        let rolesData = Data(rolesString.utf8)
        let roles = (try? JSONDecoder().decode([String].self, from: rolesData)) ?? []
        let createdAt = Date(timeIntervalSince1970: TimeInterval(createdAtInt))
        
        return OAuthUser(id: id, username: username, roles: roles, createdAt: createdAt)
    }
    
    private func issueTokens(user: OAuthUser, clientId: String, scopes: [String]) async throws -> TokenResponse {
        // Generate Access Token (JWT)
        let accessToken = try createJWT(user: user, scopes: scopes)
        
        // Generate Refresh Token (Opaque)
        let refreshToken = UUID().uuidString
        let refreshTokenHash = SHA256.hash(data: Data(refreshToken.utf8)).map { String(format: "%02x", $0) }.joined()
        let expiresAt = Int(Date().addingTimeInterval(refreshTokenExpirationInterval).timeIntervalSince1970)
        
        let sql = """
        INSERT INTO refresh_tokens (token_hash, user_id, client_id, scopes, expires_at, revoked)
        VALUES (?, ?, ?, ?, ?, 0)
        """
        
        try await database.execute(sql, parameters: [
            .text(refreshTokenHash),
            .text(user.id),
            .text(clientId),
            .text(scopes.joined(separator: " ")),
            .int(expiresAt)
        ])
        
        return TokenResponse(
            accessToken: accessToken,
            expiresIn: Int(tokenExpirationInterval),
            refreshToken: refreshToken,
            scope: scopes.joined(separator: " ")
        )
    }
    
    private func revokeRefreshToken(hash: String) async throws {
        let sql = "UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ?"
        try await database.execute(sql, parameters: [.text(hash)])
    }
    
    // MARK: - JWT Logic
    
    private func createJWT(user: OAuthUser, scopes: [String]) throws -> String {
        guard let privateKey = privateKey else { throw OAuthError.serverError("Keys not initialized") }
        
        let header = JWTHeader(kid: keyId)
        let now = Int(Date().timeIntervalSince1970)
        let payload = JWTPayload(
            iss: issuer,
            sub: user.id,
            exp: now + Int(tokenExpirationInterval),
            iat: now,
            scope: scopes.joined(separator: " "),
            roles: user.roles
        )
        
        let encoder = JSONEncoder()
        let headerData = try encoder.encode(header)
        let payloadData = try encoder.encode(payload)
        
        let headerB64 = base64UrlEncode(headerData)
        let payloadB64 = base64UrlEncode(payloadData)
        let input = "\(headerB64).\(payloadB64)"
        
        let signature = try privateKey.signature(for: Data(input.utf8))
        let signatureB64 = base64UrlEncode(signature.rawRepresentation)
        
        return "\(input).\(signatureB64)"
    }
    
    func validateJWT(_ token: String) throws -> JWTPayload {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { throw OAuthError.invalidToken }
        
        let headerB64 = String(parts[0])
        let payloadB64 = String(parts[1])
        let signatureB64 = String(parts[2])
        
        guard let signature = base64UrlDecode(signatureB64),
              let publicKey = publicKey else {
            throw OAuthError.invalidToken
        }
        
        let input = "\(headerB64).\(payloadB64)"
        let valid = publicKey.isValidSignature(
            try P256.Signing.ECDSASignature(rawRepresentation: signature),
            for: Data(input.utf8)
        )
        
        guard valid else { throw OAuthError.invalidToken }
        
        guard let payloadData = base64UrlDecode(payloadB64) else { throw OAuthError.invalidToken }
        let payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
        
        if Date().timeIntervalSince1970 > Double(payload.exp) {
            throw OAuthError.expired
        }
        
        if payload.iss != issuer {
            throw OAuthError.invalidToken
        }
        
        return payload
    }
    
    // MARK: - Helpers
    
    private func base64UrlEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func base64UrlDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        return Data(base64Encoded: base64)
    }
}

public enum OAuthError: Error, LocalizedError {
    case invalidUser
    case invalidToken
    case expired
    case revoked
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidUser: return "Invalid user"
        case .invalidToken: return "Invalid token"
        case .expired: return "Token expired"
        case .revoked: return "Token revoked"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}
