//
//  KeychainSecretAuthority.swift
//  AnigmaPrimitives
//
//  Keychain-backed implementation of SecretAuthority for macOS.
//

import Foundation
#if canImport(Security)
import Security
#endif

/// A SecretAuthority implementation that uses the macOS Keychain.
public actor KeychainSecretAuthority: SecretAuthority {
    private let service: String
    
    public init(service: String = "com.anigma.secrets") {
        self.service = service
    }
    
    public func store(secret: Data, for account: String) async throws {
        #if os(macOS) || os(iOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: secret,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: secret
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw SecretAuthorityError.unhandledError(status: updateStatus)
            }
        } else if status != errSecSuccess {
            throw SecretAuthorityError.unhandledError(status: status)
        }
        #else
        throw SecretAuthorityError.platformUnsupported
        #endif
    }
    
    public func retrieve(for account: String) async throws -> Data? {
        #if os(macOS) || os(iOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        } else if status == errSecSuccess {
            return result as? Data
        }
        
        throw SecretAuthorityError.unhandledError(status: status)
        #else
        throw SecretAuthorityError.platformUnsupported
        #endif
    }
    
    public func delete(for account: String) async throws {
        #if os(macOS) || os(iOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw SecretAuthorityError.unhandledError(status: status)
        }
        #else
        throw SecretAuthorityError.platformUnsupported
        #endif
    }
}
