//
//  SecretAuthority.swift
//  AnigmaPrimitives
//
//  Protocol for secure secret storage across the Anigma ecosystem.
//

import Foundation

/// Errors that can occur during secret storage operations.
public enum SecretAuthorityError: Error, LocalizedError, Sendable {
    case unhandledError(status: Int32)
    case itemNotFound
    case duplicateItem
    case serializationFailure
    case platformUnsupported
    case accessDenied
    
    public var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            return "Secret authority error: \(status)"
        case .itemNotFound:
            return "Secret not found"
        case .duplicateItem:
            return "Secret already exists"
        case .serializationFailure:
            return "Failed to serialize/deserialize secret"
        case .platformUnsupported:
            return "Secure storage not supported on this platform"
        case .accessDenied:
            return "Access to secure storage denied"
        }
    }
}

/// Protocol for components that provide secure secret storage.
public protocol SecretAuthority: Sendable {
    /// Stores a secret for a given account.
    /// - Parameters:
    ///   - secret: The secret data to store.
    ///   - account: The account name to associate with the secret.
    func store(secret: Data, for account: String) async throws
    
    /// Retrieves a secret for a given account.
    /// - Parameter account: The account name.
    /// - Returns: The secret data, or nil if not found.
    func retrieve(for account: String) async throws -> Data?
    
    /// Deletes a secret for a given account.
    /// - Parameter account: The account name.
    func delete(for account: String) async throws
}

/// Convenience extensions for String secrets.
extension SecretAuthority {
    public func store(password: String, for account: String) async throws {
        guard let data = password.data(using: .utf8) else {
            throw SecretAuthorityError.serializationFailure
        }
        try await store(secret: data, for: account)
    }
    
    public func retrievePassword(for account: String) async throws -> String? {
        guard let data = try await retrieve(for: account) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
