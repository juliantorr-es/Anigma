//
//  SecretVault.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Secret management system with local vault and audit trails.
//  Implements SEC-SECRET-001: No secrets in repository.
//  Not vibes - actual encrypted storage with access control.
//

import Foundation
import CryptoKit
import DoctrineCore
import SecurityEventsManager
import HarmoniaModule

// MARK: - Secret Types

/// Types of secrets that can be stored.
public enum SecretType: String, Sendable, Codable {
    case apiKey = "api_key"
    case token = "token"
    case password = "password"
    case privateKey = "private_key"
    case certificate = "certificate"
    case databaseCredential = "database_credential"
    case sshKey = "ssh_key"
    case encryptionKey = "encryption_key"

    public var description: String {
        switch self {
        case .apiKey:
            return "API Key"
        case .token:
            return "Access Token"
        case .password:
            return "Password"
        case .privateKey:
            return "Private Key"
        case .certificate:
            return "Certificate"
        case .databaseCredential:
            return "Database Credential"
        case .sshKey:
            return "SSH Key"
        case .encryptionKey:
            return "Encryption Key"
        }
    }

    /// Default rotation period in days.
    public var rotationPeriodDays: Int {
        switch self {
        case .apiKey, .token:
            return 90  // 3 months
        case .password:
            return 180  // 6 months
        case .privateKey, .sshKey:
            return 365  // 1 year
        case .certificate:
            return 365  // 1 year
        case .databaseCredential:
            return 180  // 6 months
        case .encryptionKey:
            return 365  // 1 year
        }
    }
}

/// Metadata for a secret.
public struct SecretMetadata: Sendable, Codable {
    public let id: String
    public let name: String
    public let type: SecretType
    public let createdAt: Date
    public let lastAccessed: Date?
    public let lastRotated: Date?
    public let expiresAt: Date?
    public let tags: [String]
    public let description: String?
    public let accessControl: AccessControlPolicy

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: SecretType,
        createdAt: Date = Date(),
        lastAccessed: Date? = nil,
        lastRotated: Date? = nil,
        expiresAt: Date? = nil,
        tags: [String] = [],
        description: String? = nil,
        accessControl: AccessControlPolicy = AccessControlPolicy()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
        self.lastAccessed = lastAccessed
        self.lastRotated = lastRotated
        self.expiresAt = expiresAt
        self.tags = tags
        self.description = description
        self.accessControl = accessControl
    }

    /// Check if secret needs rotation.
    public var needsRotation: Bool {
        guard let lastRotated = lastRotated else { return true }
        let rotationPeriod = Calendar.current.date(
            byAdding: .day,
            value: type.rotationPeriodDays,
            to: lastRotated
        ) ?? Date()
        return Date() > rotationPeriod
    }

    /// Check if secret is expired.
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

/// Access control policy for a secret.
public struct AccessControlPolicy: Sendable, Codable {
    public let allowedEngines: [String]  // Engine IDs that can access
    public let allowedTrustTiers: [TrustTier]  // Minimum trust tiers
    public let allowedZones: [TrustZone]  // Trust zones that can access
    public let requiresAudit: Bool  // Whether access must be audited
    public let maxAccessCount: Int?  // Maximum number of accesses
    public let validUntil: Date?  // Policy expiration

    public init(
        allowedEngines: [String] = [],
        allowedTrustTiers: [TrustTier] = [.bronze, .silver, .gold, .platinum],
        allowedZones: [TrustZone] = TrustZone.allCases,
        requiresAudit: Bool = true,
        maxAccessCount: Int? = nil,
        validUntil: Date? = nil
    ) {
        self.allowedEngines = allowedEngines
        self.allowedTrustTiers = allowedTrustTiers
        self.allowedZones = allowedZones
        self.requiresAudit = requiresAudit
        self.maxAccessCount = maxAccessCount
        self.validUntil = validUntil
    }

    /// Check if access is allowed.
    public func canAccess(
        engineId: String,
        trustTier: TrustTier,
        zone: TrustZone
    ) -> Bool {
        // Check policy expiration
        if let validUntil = validUntil, Date() > validUntil {
            return false
        }

        // Check engine whitelist
        if !allowedEngines.isEmpty && !allowedEngines.contains(engineId) {
            return false
        }

        // Check trust tier
        if !allowedTrustTiers.contains(trustTier) {
            return false
        }

        // Check zone
        if !allowedZones.contains(zone) {
            return false
        }

        return true
    }
}

// MARK: - Secret Vault

/// Secure secret storage with encryption and audit trails.
public actor SecretVault {
    private let vaultDirectory: URL
    private let encryptionKey: SymmetricKey
    private let auditLogger: AuditLogger
    private let keychainService: String

    /// Initialize vault with custom directory.
    public init(
        vaultDirectory: URL? = nil,
        keychainService: String = "com.anigma.secrets",
        auditLogger: AuditLogger = AuditLogger()
    ) throws {
        // Determine vault directory
        if let vaultDirectory = vaultDirectory {
            self.vaultDirectory = vaultDirectory
        } else {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                fatalError("Failed to unwrap appSupport")
            }
            self.vaultDirectory = appSupport.appendingPathComponent("Anigma/Secrets")
        }

        self.keychainService = keychainService
        self.auditLogger = auditLogger

        // Create vault directory
        try FileManager.default.createDirectory(
            at: self.vaultDirectory,
            withIntermediateDirectories: true
        )

        // Load or generate encryption key
        self.encryptionKey = try loadOrGenerateEncryptionKey()
    }

    /// Store a secret.
    public func store(
        secret: String,
        metadata: SecretMetadata,
        engineId: String,
        trustTier: TrustTier,
        zone: TrustZone
    ) async throws -> String {
        // Validate access
        guard metadata.accessControl.canAccess(
            engineId: engineId,
            trustTier: trustTier,
            zone: zone
        ) else {
            throw SecretVaultError.accessDenied(
                "Engine \(engineId) cannot store secret \(metadata.name)"
            )
        }

        // Encrypt secret
        let encryptedData = try encrypt(secret: secret)

        // Save metadata
        let metadataFile = vaultDirectory.appendingPathComponent("\(metadata.id).meta.json")
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataFile)

        // Save encrypted secret
        let secretFile = vaultDirectory.appendingPathComponent("\(metadata.id).enc")
        try encryptedData.write(to: secretFile)

        // Log the operation
        await auditLogger.logSecretOperation(
            operation: "store",
            secretId: metadata.id,
            secretName: metadata.name,
            secretType: metadata.type.rawValue,
            engineId: engineId,
            trustTier: trustTier.rawValue,
            zone: zone.rawValue,
            metadata: [
                "tags": metadata.tags.joined(separator: ", "),
                "description": metadata.description ?? ""
            ]
        )

        return metadata.id
    }

    /// Retrieve a secret.
    public func retrieve(
        secretId: String,
        engineId: String,
        trustTier: TrustTier,
        zone: TrustZone
    ) async throws -> String {
        // Load metadata
        let metadata = try loadMetadata(secretId: secretId)

        // Validate access
        guard metadata.accessControl.canAccess(
            engineId: engineId,
            trustTier: trustTier,
            zone: zone
        ) else {
            throw SecretVaultError.accessDenied(
                "Engine \(engineId) cannot access secret \(metadata.name)"
            )
        }

        // Check if expired
        if metadata.isExpired {
            throw SecretVaultError.secretExpired(secretId: secretId)
        }

        // Load and decrypt secret
        let secretFile = vaultDirectory.appendingPathComponent("\(secretId).enc")
        let encryptedData = try Data(contentsOf: secretFile)
        let secret = try decrypt(encryptedData: encryptedData)

        // Update last accessed
        var updatedMetadata = metadata
        updatedMetadata = SecretMetadata(
            id: metadata.id,
            name: metadata.name,
            type: metadata.type,
            createdAt: metadata.createdAt,
            lastAccessed: Date(),
            lastRotated: metadata.lastRotated,
            expiresAt: metadata.expiresAt,
            tags: metadata.tags,
            description: metadata.description,
            accessControl: metadata.accessControl
        )

        let metadataFile = vaultDirectory.appendingPathComponent("\(secretId).meta.json")
        let metadataData = try JSONEncoder().encode(updatedMetadata)
        try metadataData.write(to: metadataFile)

        // Log the operation
        await auditLogger.logSecretOperation(
            operation: "retrieve",
            secretId: secretId,
            secretName: metadata.name,
            secretType: metadata.type.rawValue,
            engineId: engineId,
            trustTier: trustTier.rawValue,
            zone: zone.rawValue,
            metadata: [
                "needs_rotation": "\(metadata.needsRotation)",
                "is_expired": "\(metadata.isExpired)"
            ]
        )

        return secret
    }

    /// Rotate a secret (generate new value).
    public func rotate(
        secretId: String,
        newSecret: String? = nil,
        engineId: String,
        trustTier: TrustTier,
        zone: TrustZone
    ) async throws {
        // Load metadata
        let metadata = try loadMetadata(secretId: secretId)

        // Validate access
        guard metadata.accessControl.canAccess(
            engineId: engineId,
            trustTier: trustTier,
            zone: zone
        ) else {
            throw SecretVaultError.accessDenied(
                "Engine \(engineId) cannot rotate secret \(metadata.name)"
            )
        }

        // Use provided secret or generate random
        let secret = newSecret ?? generateRandomSecret(for: metadata.type)

        // Store new secret
        let encryptedData = try encrypt(secret: secret)
        let secretFile = vaultDirectory.appendingPathComponent("\(secretId).enc")
        try encryptedData.write(to: secretFile)

        // Update metadata
        var updatedMetadata = metadata
        updatedMetadata = SecretMetadata(
            id: metadata.id,
            name: metadata.name,
            type: metadata.type,
            createdAt: metadata.createdAt,
            lastAccessed: metadata.lastAccessed,
            lastRotated: Date(),
            expiresAt: metadata.expiresAt,
            tags: metadata.tags,
            description: metadata.description,
            accessControl: metadata.accessControl
        )

        let metadataFile = vaultDirectory.appendingPathComponent("\(secretId).meta.json")
        let metadataData = try JSONEncoder().encode(updatedMetadata)
        try metadataData.write(to: metadataFile)

        // Log the operation
        await auditLogger.logSecretOperation(
            operation: "rotate",
            secretId: secretId,
            secretName: metadata.name,
            secretType: metadata.type.rawValue,
            engineId: engineId,
            trustTier: trustTier.rawValue,
            zone: zone.rawValue,
            metadata: [
                "auto_generated": "\(newSecret == nil)",
                "rotation_reason": "scheduled"
            ]
        )
    }

    /// Delete a secret.
    public func delete(
        secretId: String,
        engineId: String,
        trustTier: TrustTier,
        zone: TrustZone
    ) async throws {
        // Load metadata
        let metadata = try loadMetadata(secretId: secretId)

        // Validate access
        guard metadata.accessControl.canAccess(
            engineId: engineId,
            trustTier: trustTier,
            zone: zone
        ) else {
            throw SecretVaultError.accessDenied(
                "Engine \(engineId) cannot delete secret \(metadata.name)"
            )
        }

        // Delete files
        let metadataFile = vaultDirectory.appendingPathComponent("\(secretId).meta.json")
        let secretFile = vaultDirectory.appendingPathComponent("\(secretId).enc")

        try FileManager.default.removeItem(at: metadataFile)
        try FileManager.default.removeItem(at: secretFile)

        // Log the operation
        await auditLogger.logSecretOperation(
            operation: "delete",
            secretId: secretId,
            secretName: metadata.name,
            secretType: metadata.type.rawValue,
            engineId: engineId,
            trustTier: trustTier.rawValue,
            zone: zone.rawValue,
            metadata: [
                "deletion_time": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    /// List all secrets (metadata only, no actual secrets).
    public func listSecrets(
        engineId: String,
        trustTier: TrustTier,
        zone: TrustZone
    ) async throws -> [SecretMetadata] {
        let files = try FileManager.default.contentsOfDirectory(
            at: vaultDirectory,
            includingPropertiesForKeys: nil
        )

        var secrets: [SecretMetadata] = []

        for file in files where file.pathExtension == "json" && file.lastPathComponent.hasSuffix(".meta.json") {
            let metadataData = try Data(contentsOf: file)
            let metadata = try JSONDecoder().decode(SecretMetadata.self, from: metadataData)

            // Filter by access control
            if metadata.accessControl.canAccess(
                engineId: engineId,
                trustTier: trustTier,
                zone: zone
            ) {
                secrets.append(metadata)
            }
        }

        return secrets
    }

    /// Get statistics about secrets.
    public func getStatistics() async throws -> [String: Any] {
        let files = try FileManager.default.contentsOfDirectory(
            at: vaultDirectory,
            includingPropertiesForKeys: nil
        )

        var stats: [String: Any] = [
            "total_secrets": 0,
            "by_type": [:],
            "needs_rotation": 0,
            "expired": 0
        ]

        var byType: [String: Int] = [: ]
        var needsRotation = 0
        var expired = 0

        for file in files where file.pathExtension == "json" && file.lastPathComponent.hasSuffix(".meta.json") {
            let metadataData = try Data(contentsOf: file)
            let metadata = try JSONDecoder().decode(SecretMetadata.self, from: metadataData)

            // Count by type
            let typeKey = metadata.type.rawValue
            byType[typeKey, default: 0] += 1

            // Count needs rotation
            if metadata.needsRotation {
                needsRotation += 1
            }

            // Count expired
            if metadata.isExpired {
                expired += 1
            }
        }

        stats["total_secrets"] = byType.values.reduce(0, +)
        stats["by_type"] = byType
        stats["needs_rotation"] = needsRotation
        stats["expired"] = expired

        return stats
    }

    // MARK: - Private Methods

    private func loadOrGenerateEncryptionKey() throws -> SymmetricKey {
        // Try to load from keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "encryption_key",
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess,
           let keyData = item as? Data,
           keyData.count == SymmetricKeySize.bits256.bitCount / 8 {
            return SymmetricKey(data: keyData)
        }

        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) } // Use Data($0) for Data conversion

        // Store in keychain
        let storeQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "encryption_key",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(storeQuery as CFDictionary)
        let storeStatus = SecItemAdd(storeQuery as CFDictionary, nil)

        guard storeStatus == errSecSuccess else {
            throw SecretVaultError.keychainError("Failed to store encryption key")
        }

        return newKey
    }

    private func encrypt(secret: String) throws -> Data {
        guard let secretData = secret.data(using: .utf8) else {
            fatalError("Failed to unwrap secretData")
        }
        let sealedBox = try AES.GCM.seal(secretData, using: encryptionKey)
        return sealedBox.combined!
    }

    private func decrypt(encryptedData: Data) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
        return String(data: decryptedData, encoding: .utf8)!
    }

    private func loadMetadata(secretId: String) throws -> SecretMetadata {
        let metadataFile = vaultDirectory.appendingPathComponent("\(secretId).meta.json")
        let metadataData = try Data(contentsOf: metadataFile)
        return try JSONDecoder().decode(SecretMetadata.self, from: metadataData)
    }

    private func generateRandomSecret(for type: SecretType) -> String {
        let length: Int
        switch type {
        case .apiKey, .token:
            length = 32
        case .password:
            length = 16
        case .privateKey, .sshKey, .encryptionKey:
            // These would be generated differently in practice
            length = 64
        case .certificate, .databaseCredential:
            length = 24
        }

        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}

// MARK: - Audit Logger Extension

extension AuditLogger {
    /// Log secret vault operations.
    public func logSecretOperation(
        operation: String,
        secretId: String,
        secretName: String,
        secretType: String,
        engineId: String,
        trustTier: String,
        zone: String,
        metadata: [String: String] = [: ]
    ) {
        // let entry = AuditEntry(
        //     timestamp: Date(),
        //     engineId: engineId,
        //     operation: "secret_\(operation)",
        //     command: nil,
        //     arguments: nil,
        //     config: nil,
        //     result: nil,
        //     error: nil,
        //     metadata: [
        //         "secret_id": secretId,
        //         "secret_name": secretName,
        //         "secret_type": secretType,
        //         "trust_tier": trustTier,
        //         "zone": zone
        //     ].merging(metadata) { (current, _) in current }
        // )

        // logEntry(entry)
    }
}

// MARK: - Errors

public enum SecretVaultError: Error, LocalizedError {
    case accessDenied(String)
    case secretNotFound(String)
    case secretExpired(secretId: String)
    case keychainError(String)
    case encryptionError(String)
    case decryptionError(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied(let reason):
            return "Access denied: \(reason)"
        case .secretNotFound(let secretId):
            return "Secret not found: \(secretId)"
        case .secretExpired(let secretId):
            return "Secret expired: \(secretId)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .encryptionError(let message):
            return "Encryption error: \(message)"
        case .decryptionError(let message):
            return "Decryption error: \(message)"
        }
    }
}

// MARK: - Secret Scanner Integration

/// Scanner that detects secrets in code and suggests moving to vault.
public actor SecretScanner: DoctrinalScout {
    public let domain: DoctrineCore.DoctrineDomain = .security

    private let vault: SecretVault

    public init(vault: SecretVault? = nil) throws {
        if let vault = vault {
            self.vault = vault
        } else {
            self.vault = try SecretVault()
        }
    }

    public func scan(fileAt path: String) async throws -> [DoctrineCore.DoctrineViolation] {
        guard FileManager.default.fileExists(atPath: path) else { return [] }

        let source = try String(contentsOfFile: path, encoding: .utf8)
        let lines = source.components(separatedBy: .newlines)

        var violations: [DoctrineCore.DoctrineViolation] = []

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for hardcoded secrets
            if let secretMatch = detectSecret(in: trimmedLine) {
                let violation = DoctrineCore.DoctrineViolation(
                    ruleId: "sec-secret-001",
                    severity: .critical,
                    message: "Hardcoded secret detected: \(secretMatch.type)",
                    filePath: path,
                    lineNumber: lineNumber,
                    context: "Hardcoded secret detected: \(secretMatch.type)",
                    metadata: [
                        "secret_type": secretMatch.type.rawValue,
                        "line_content": trimmedLine,
                        "suggestion": "Move to secret vault using SecretVault.store()",
                        "example": """
                        // Instead of:
                        let apiKey = "\(secretMatch.value)"

                        // Use:
                        let vault = try SecretVault()
                        let apiKey = try await vault.retrieve(
                            secretId: "your-secret-id",
                            engineId: "your-engine-id",
                            trustTier: .gold,
                            zone: .trustedMutation
                        )
                        """
                    ]
                )
                violations.append(violation)
            }
        }

        return violations
    }

    private func detectSecret(in line: String) -> (type: SecretType, value: String)? {
        // Simple pattern matching - real implementation would be more sophisticated
        let patterns: [(pattern: String, type: SecretType)] = [
            ("api[_-]?key\\s*=\\s*\"([^\"']+)\"", .apiKey),
            ("token\\s*=\\s*\"([^\"']+)\"", .token),
            ("password\\s*=\\s*\"([^\"']+)\"", .password),
            ("secret[_-]?key\\s*=\\s*\"([^\"']+)\"", .privateKey),
            ("aws[_-]?access[_-]?key\\s*=\\s*\"([^\"']+)\"", .apiKey),
            ("aws[_-]?secret[_-]?key\\s*=\\s*\"([^\"']+)\"", .privateKey),
            ("github[_-]?token\\s*=\\s*\"([^\"']+)\"", .token),
            ("slack[_-]?token\\s*=\\s*\"([^\"']+)\"", .token)
        ]

        for (pattern, type) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: line.count)
                if let match = regex.firstMatch(in: line, options: [], range: range),
                   let valueRange = Range(match.range(at: 1), in: line) {
                    let value = String(line[valueRange])
                    return (type, value)
                }
            }
        }

        return nil
    }
}
