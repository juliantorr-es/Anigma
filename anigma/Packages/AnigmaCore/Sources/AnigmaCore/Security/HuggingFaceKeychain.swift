//
//  HuggingFaceKeychain.swift
//  AnigmaCore
//
//  Keychain integration for HuggingFace authentication tokens.
//

import Foundation
import AnigmaPrimitives

public enum HFAuthError: Error, LocalizedError {
    case keychainError(Int32)
    case tokenNotFound
    case tokenInvalid
    case encodingFailed
    case deletionFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .tokenNotFound:
            return "No HuggingFace token found in keychain"
        case .tokenInvalid:
            return "Invalid token format in keychain"
        case .encodingFailed:
            return "Failed to encode token data"
        case .deletionFailed(let status):
            return "Failed to delete token: \(status)"
        }
    }
}

public actor HuggingFaceKeychain {
    private let authority: KeychainSecretAuthority
    private static let tokenAccount = "huggingface_token"
    public static let tokenService = "ai.anigma.huggingface"

    public init(service: String = tokenService) {
        self.authority = KeychainSecretAuthority(service: service)
    }

    public func storeToken(_ token: String) async throws {
        do {
            try await authority.store(password: token, for: Self.tokenAccount)
        } catch let error as SecretAuthorityError {
            if case .unhandledError(let status) = error {
                throw HFAuthError.keychainError(status)
            }
            throw error
        }
    }

    public func getToken() async -> String? {
        return try? await authority.retrievePassword(for: Self.tokenAccount)
    }

    public func deleteToken() async throws {
        do {
            try await authority.delete(for: Self.tokenAccount)
        } catch let error as SecretAuthorityError {
            if case .unhandledError(let status) = error {
                throw HFAuthError.deletionFailed(status)
            }
            throw error
        }
    }

    public var hasToken: Bool {
        get async {
            await getToken() != nil
        }
    }

    public func updateToken(_ token: String) async throws {
        try await storeToken(token)
    }
}
