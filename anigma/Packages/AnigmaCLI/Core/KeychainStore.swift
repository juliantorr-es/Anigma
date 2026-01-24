//
//  KeychainStore.swift
//  AnigmaCLICore
//
//  Utility for storing secure configuration (API keys) in the macOS Keychain with a
//  directory-based fallback for other platforms.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore

public enum KeychainStoreError: Error {
    case unexpected(status: Int32)
    case serializationFailure
}

public struct KeychainStore {
    private static let authority = CompositeSecretAuthority(service: "com.anigma.cli")

    public static func store(
        value: String,
        for key: String,
        fallbackDirectory: URL? = nil
    ) async throws {
        // Note: fallbackDirectory is now handled by CompositeSecretAuthority constructor
        // but we keep the parameter for source compatibility if needed, or ignore it.
        try await authority.store(password: value, for: key)
    }

    public static func retrieve(
        key: String,
        fallbackDirectory: URL? = nil
    ) async throws -> String? {
        try await authority.retrievePassword(for: key)
    }

    public static func delete(
        key: String,
        fallbackDirectory: URL? = nil
    ) async throws {
        try await authority.delete(for: key)
    }
}
