//
//  KeychainStore.swift
//  AnigmaCLICore
//
//  Utility for storing secure configuration (API keys) in the macOS Keychain with a
//  directory-based fallback for other platforms.
//

import Foundation

#if os(macOS)
import Security
#endif

public enum KeychainStoreError: Error {
    case unexpected(status: OSStatus)
    case serializationFailure
}

public struct KeychainStore {
    private static let service = "com.anigma.cli"

    public static func store(
        value: String,
        for key: String,
        fallbackDirectory: URL
    ) throws {
        #if os(macOS)
        let encoded = Data(value.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: encoded
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            query = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            let attributes: [String: Any] = [kSecValueData as String: encoded]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainStoreError.unexpected(status: updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainStoreError.unexpected(status: status)
        }
        #else
        try ensureFallbackDirectoryExists(fallbackDirectory)
        let fallbackURL = fallbackFileURL(in: fallbackDirectory)
        var payload = try loadFallback(at: fallbackURL)
        payload[key] = value
        try saveFallback(payload, to: fallbackURL)
        #endif
    }

    public static func retrieve(
        key: String,
        fallbackDirectory: URL
    ) throws -> String? {
        #if os(macOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            if let data = result as? Data, let string = String(data: data, encoding: .utf8) {
                return string
            }
            return nil
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.unexpected(status: status)
        }
        #else
        try ensureFallbackDirectoryExists(fallbackDirectory)
        let fallbackURL = fallbackFileURL(in: fallbackDirectory)
        let payload = try loadFallback(at: fallbackURL)
        return payload[key]
        #endif
    }

    public static func delete(
        key: String,
        fallbackDirectory: URL
    ) throws {
        #if os(macOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainStoreError.unexpected(status: status)
        }
        #else
        try ensureFallbackDirectoryExists(fallbackDirectory)
        let fallbackURL = fallbackFileURL(in: fallbackDirectory)
        var payload = try loadFallback(at: fallbackURL)
        payload.removeValue(forKey: key)
        try saveFallback(payload, to: fallbackURL)
        #endif
    }

    // MARK: - Fallback Storage (non-macOS)

    private static func fallbackFileURL(in directory: URL) -> URL {
        return directory.appendingPathComponent("secure-keys.json")
    }

    private static func ensureFallbackDirectoryExists(_ directory: URL) throws {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDir) || !isDir.boolValue {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private static func loadFallback(at url: URL) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] else {
            throw KeychainStoreError.serializationFailure
        }
        return json
    }

    private static func saveFallback(_ dictionary: [String: String], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}
