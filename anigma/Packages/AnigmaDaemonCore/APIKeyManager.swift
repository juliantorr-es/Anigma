//
//  APIKeyManager.swift
//  AnigmaDaemonCore
//
//  API key management for web/mobile access.
//

import CryptoKit
import DatabaseCore
import Foundation

/// API key metadata (stored in database)
public struct APIKeyRecord: Codable, Sendable {
    public let id: String
    public let name: String
    public let keyHash: String  // SHA-256 hash of the API key
    public let scopes: [String]
    public let createdAt: Date
    public let lastUsedAt: Date?
    public let expiresAt: Date?
    public let revoked: Bool
    
    public init(
        id: String,
        name: String,
        keyHash: String,
        scopes: [String],
        createdAt: Date,
        lastUsedAt: Date? = nil,
        expiresAt: Date? = nil,
        revoked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.keyHash = keyHash
        self.scopes = scopes
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.expiresAt = expiresAt
        self.revoked = revoked
    }
}

/// API key manager actor
public actor APIKeyManager {
    private let database: DatabaseActor
    private let tokenManager: CapabilityTokenManager
    
    public init(database: DatabaseActor, tokenManager: CapabilityTokenManager) {
        self.database = database
        self.tokenManager = tokenManager
    }
    
    /// Initialize API key storage (create table if needed)
    public func initializeStorage() async throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS api_keys (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            key_hash TEXT NOT NULL UNIQUE,
            scopes TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            last_used_at INTEGER,
            expires_at INTEGER,
            revoked INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);
        CREATE INDEX IF NOT EXISTS idx_api_keys_revoked ON api_keys(revoked);
        """
        
        try await database.execute(createTableSQL)
    }
    
    /// Generate a new API key
    public func createKey(
        name: String,
        scopes: [String],
        expiresInDays: Int = 90
    ) async throws -> (id: String, key: String) {
        // Generate random API key (format: ak_xxxxxxxx)
        let keyId = UUID().uuidString
        let keySecret = Self.generateAPIKeySecret()
        let fullKey = "ak_\(keyId)_\(keySecret)"
        
        // Hash the key for storage
        let keyHash = Self.hashAPIKey(fullKey)
        
        // Calculate expiry
        let expiresAt: Date?
        if expiresInDays > 0 {
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresInDays) * 86400)
        } else {
            expiresAt = nil
        }
        
        let record = APIKeyRecord(
            id: keyId,
            name: name,
            keyHash: keyHash,
            scopes: scopes,
            createdAt: Date(),
            expiresAt: expiresAt
        )
        
        // Store in database
        let insertSQL = """
        INSERT INTO api_keys (id, name, key_hash, scopes, created_at, expires_at, revoked)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        let scopesJSON = try JSONEncoder().encode(scopes)
        let scopesString = String(data: scopesJSON, encoding: .utf8) ?? "[]"
        
        try await database.execute(
            insertSQL,
            parameters: [
                .text(record.id),
                .text(record.name),
                .text(record.keyHash),
                .text(scopesString),
                .integer(Int(record.createdAt.timeIntervalSince1970)),
                record.expiresAt.map { .integer(Int($0.timeIntervalSince1970)) } ?? .null,
                .integer(0)
            ]
        )
        
        return (id: keyId, key: fullKey)
    }
    
    /// Validate API key and return scopes if valid
    public func validateKey(_ apiKey: String) async throws -> (keyId: String, scopes: [String]) {
        // Extract key ID from format: ak_<id>_<secret>
        let components = apiKey.split(separator: "_")
        guard components.count == 3, components[0] == "ak" else {
            throw APIKeyError.invalidFormat
        }
        
        let keyId = String(components[1])
        let keyHash = Self.hashAPIKey(apiKey)
        
        // Query database
        let querySQL = """
        SELECT id, scopes, expires_at, revoked FROM api_keys 
        WHERE key_hash = ? LIMIT 1
        """
        
        let rows = try await database.query(
            querySQL,
            parameters: [.text(keyHash)]
        )
        
        guard let row = rows.first else {
            throw APIKeyError.notFound
        }
        
        guard let id = row["id"]?.textValue,
              let scopesJSON = row["scopes"]?.textValue,
              let revoked = row["revoked"]?.integerValue,
              id == keyId else {
            throw APIKeyError.notFound
        }
        
        // Check if revoked
        if revoked != 0 {
            throw APIKeyError.revoked
        }
        
        // Check expiry
        if let expiresAtUnix = row["expires_at"]?.integerValue {
            let expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtUnix))
            if Date() > expiresAt {
                throw APIKeyError.expired
            }
        }
        
        // Parse scopes
        let scopesData = Data(scopesJSON.utf8)
        let scopes = try JSONDecoder().decode([String].self, from: scopesData)
        
        // Update last used timestamp
        try await updateLastUsed(keyId: keyId)
        
        return (keyId: keyId, scopes: scopes)
    }
    
    /// Exchange API key for capability token
    public func exchangeForKeyToken(_ apiKey: String, clientName: String) async throws -> CapabilityToken {
        let validation = try await validateKey(apiKey)
        
        // Mint capability token with scopes from API key
        let token = await tokenManager.mintToken(
            clientName: "\(clientName) (api-key:\(validation.keyId))",
            requestedScopes: validation.scopes
        )
        
        return token
    }
    
    /// List all API keys (excluding hashes)
    public func listKeys() async throws -> [APIKeyRecord] {
        let querySQL = """
        SELECT id, name, scopes, created_at, last_used_at, expires_at, revoked
        FROM api_keys
        ORDER BY created_at DESC
        """
        
        let rows = try await database.query(querySQL)
        var records: [APIKeyRecord] = []
        
        for row in rows {
            guard let id = row["id"]?.textValue,
                  let name = row["name"]?.textValue,
                  let scopesJSON = row["scopes"]?.textValue,
                  let createdAtUnix = row["created_at"]?.integerValue,
                  let revoked = row["revoked"]?.integerValue else {
                continue
            }
            
            let scopesData = Data(scopesJSON.utf8)
            let scopes = try JSONDecoder().decode([String].self, from: scopesData)
            
            let createdAt = Date(timeIntervalSince1970: TimeInterval(createdAtUnix))
            let lastUsedAt = row["last_used_at"]?.integerValue.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            }
            let expiresAt = row["expires_at"]?.integerValue.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            }
            
            let record = APIKeyRecord(
                id: id,
                name: name,
                keyHash: "",  // Don't expose hash
                scopes: scopes,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                expiresAt: expiresAt,
                revoked: revoked != 0
            )
            
            records.append(record)
        }
        
        return records
    }
    
    /// Revoke an API key
    public func revokeKey(keyId: String) async throws {
        let updateSQL = "UPDATE api_keys SET revoked = 1 WHERE id = ?"
        try await database.execute(updateSQL, parameters: [.text(keyId)])
    }
    
    /// Delete an API key (permanently)
    public func deleteKey(keyId: String) async throws {
        let deleteSQL = "DELETE FROM api_keys WHERE id = ?"
        try await database.execute(deleteSQL, parameters: [.text(keyId)])
    }
    
    /// Update last used timestamp
    private func updateLastUsed(keyId: String) async throws {
        let updateSQL = "UPDATE api_keys SET last_used_at = ? WHERE id = ?"
        let now = Int(Date().timeIntervalSince1970)
        try await database.execute(
            updateSQL,
            parameters: [.integer(now), .text(keyId)]
        )
    }
    
    // MARK: - Static Helpers
    
    private static func generateAPIKeySecret() -> String {
        let bytesCount = 32
        var bytes = [UInt8](repeating: 0, count: bytesCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private static func hashAPIKey(_ apiKey: String) -> String {
        let data = Data(apiKey.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

/// API key errors
public enum APIKeyError: Error, LocalizedError {
    case invalidFormat
    case notFound
    case expired
    case revoked
    case insufficientScope
    case storageError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid API key format"
        case .notFound:
            return "API key not found"
        case .expired:
            return "API key has expired"
        case .revoked:
            return "API key has been revoked"
        case .insufficientScope:
            return "Insufficient scope for requested operation"
        case .storageError(let message):
            return "API key storage error: \(message)"
        }
    }
}