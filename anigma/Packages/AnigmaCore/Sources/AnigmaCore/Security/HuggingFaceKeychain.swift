//
//  HuggingFaceKeychain.swift
//  AnigmaCore
//
//  Keychain integration for HuggingFace authentication tokens.
//

import Foundation
import Security

public enum HFAuthError: Error, LocalizedError {
    case keychainError(OSStatus)
    case tokenNotFound
    case tokenInvalid
    case encodingFailed
    case deletionFailed(OSStatus)

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
    private let service: String
    private let accessGroup: String?
    private let accessControl: SecAccessControl?

    private static let tokenAccount = "huggingface_token"
    private static let tokenService = "ai.anigma.huggingface"

    public init(
        service: String = tokenService,
        accessGroup: String? = nil,
        accessControl: SecAccessControl? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup

        if let accessControl = accessControl {
            self.accessControl = accessControl
        } else {
            var access: SecAccessControl?
            let accessControlFlags: SecAccessControlCreateFlags = .privateKeyUsage

            if #available(macOS 12.3, *) {
                access = SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    accessControlFlags,
                    nil
                )
            } else {
                access = SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    accessControlFlags,
                    nil
                )
            }
            self.accessControl = access
        }
    }

    public func storeToken(_ token: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw HFAuthError.encodingFailed
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.tokenAccount,
            kSecValueData as String: tokenData
        ]

        if #available(macOS 12.3, *), let accessControl = accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.tokenAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw HFAuthError.keychainError(status)
        }
    }

    public func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token.isEmpty ? nil : token
    }

    public func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.tokenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HFAuthError.deletionFailed(status)
        }
    }

    public var hasToken: Bool {
        getToken() != nil
    }

    public func updateToken(_ token: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw HFAuthError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.tokenAccount
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: tokenData
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            try storeToken(token)
        } else if status != errSecSuccess {
            throw HFAuthError.keychainError(status)
        }
    }
}
