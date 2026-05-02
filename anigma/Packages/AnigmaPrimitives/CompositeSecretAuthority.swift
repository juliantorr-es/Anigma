//
//  CompositeSecretAuthority.swift
//  AnigmaPrimitives
//
//  SecretAuthority implementation that falls back to file-based storage on non-Apple platforms.
//

import Foundation

/// A SecretAuthority that uses Keychain on macOS/iOS and a JSON file elsewhere.
public actor CompositeSecretAuthority: SecretAuthority {
    private let service: String
    private let fallbackDirectory: URL
    private let keychainAuthority: KeychainSecretAuthority
    
    public init(service: String = "com.anigma.secrets", fallbackDirectory: URL? = nil) {
        self.service = service
        self.keychainAuthority = KeychainSecretAuthority(service: service)
        
        if let fallback = fallbackDirectory {
            self.fallbackDirectory = fallback
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.fallbackDirectory = home.appendingPathComponent(".anigma/secrets")
        }
        
        // Ensure fallback directory exists
        try? FileManager.default.createDirectory(at: self.fallbackDirectory, withIntermediateDirectories: true)
    }
    
    public func store(secret: Data, for account: String) async throws {
        #if os(macOS) || os(iOS)
        try await keychainAuthority.store(secret: secret, for: account)
        #else
        var secrets = try await loadFallbackSecrets()
        secrets[account] = secret.base64EncodedString()
        try await saveFallbackSecrets(secrets)
        #endif
    }
    
    public func retrieve(for account: String) async throws -> Data? {
        #if os(macOS) || os(iOS)
        return try await keychainAuthority.retrieve(for: account)
        #else
        let secrets = try await loadFallbackSecrets()
        if let base64 = secrets[account] {
            return Data(base64Encoded: base64)
        }
        return nil
        #endif
    }
    
    public func delete(for account: String) async throws {
        #if os(macOS) || os(iOS)
        try await keychainAuthority.delete(for: account)
        #else
        var secrets = try await loadFallbackSecrets()
        secrets.removeValue(forKey: account)
        try await saveFallbackSecrets(secrets)
        #endif
    }
    
    // MARK: - Fallback Logic
    
    private var fallbackFileURL: URL {
        fallbackDirectory.appendingPathComponent("\(service).json")
    }
    
    private func loadFallbackSecrets() async throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: fallbackFileURL.path) else {
            return [:]
        }
        
        let data = try Data(contentsOf: fallbackFileURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw SecretAuthorityError.serializationFailure
        }
        return json
    }
    
    private func saveFallbackSecrets(_ secrets: [String: String]) async throws {
        let data = try JSONSerialization.data(withJSONObject: secrets, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: fallbackFileURL, options: .atomic)
    }
}
