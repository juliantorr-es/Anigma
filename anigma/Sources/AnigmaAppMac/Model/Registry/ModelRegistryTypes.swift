//
//  ModelRegistryTypes.swift
//  AnigmaAppMac
//
//  Enhanced model registry types with full metadata tracking.
//  Fixes 15 TODOs in UI components by providing runtime status, storage, and usage data.
//

import Foundation

// MARK: - Model Status

/// Runtime status of a registered model
public enum ModelStatus: String, Codable, Sendable, Hashable {
    case ready          // Verified and runnable
    case downloading    // Actively downloading
    case verifying      // Hash verification in progress
    case converting     // Format conversion (e.g., to MLX)
    case degraded       // Files missing or corrupted
    case quarantined    // Policy violation or security issue
}

// MARK: - License Info

/// Structured license information with policy decision
public struct LicenseInfo: Codable, Sendable, Hashable {
    public let declared: String?      // SPDX identifier or license name
    public let allowed: Bool          // Policy decision: is this license allowed?
    public let reason: String?        // Why allowed/denied
    public let reviewedAt: Date?      // When policy was applied

    public init(declared: String?, allowed: Bool, reason: String? = nil, reviewedAt: Date? = nil) {
        self.declared = declared
        self.allowed = allowed
        self.reason = reason
        self.reviewedAt = reviewedAt
    }
}

// MARK: - Enhanced Model Registry Entry

/// Enhanced entry in the model registry with full metadata tracking
public struct ModelRegistryEntry: Identifiable, Codable, Sendable, Hashable {
    // Core identity (immutable)
    public let id: String
    public let modelId: String
    public let sourceType: String
    public let sourceLocation: String
    public let sourceRevision: String?

    // Runtime status
    public let status: ModelStatus
    public let isRunnable: Bool

    // Model specification (for UI display and filtering)
    public let taskKind: String        // e.g., "llm.inference", "text.embedding"
    public let backendFormat: String    // e.g., "mlx", "gguf", "coreml"
    public let dimension: Int?          // Model dimension (for embeddings) or context length

    // Storage tracking
    public let installPath: String?
    public let storageBytes: Int64
    public let artifactHash: String
    public let tokenizerHash: String?
    public let artifactHashes: [String: String]  // "model", "tokenizer", "config"

    // Timestamps
    public let registeredAt: Date          // Renamed from importedAt for clarity
    public let lastVerified: Date
    public var lastUsed: Date?

    // Usage analytics
    public var usageCount: Int

    // License (structured)
    public let license: LicenseInfo

    // Backend compatibility
    public let backendCompatibility: ModelBackendCompatibility

    // Trust tier
    public let trustTier: String

    // Conversion receipt
    public let conversionReceiptId: String?

    public init(
        modelId: String,
        sourceType: String,
        sourceLocation: String,
        sourceRevision: String? = nil,
        status: ModelStatus = .ready,
        isRunnable: Bool = true,
        taskKind: String,
        backendFormat: String,
        dimension: Int? = nil,
        installPath: String? = nil,
        storageBytes: Int64 = 0,
        artifactHash: String,
        tokenizerHash: String? = nil,
        artifactHashes: [String: String] = [:],
        registeredAt: Date = Date(),
        lastVerified: Date = Date(),
        lastUsed: Date? = nil,
        usageCount: Int = 0,
        license: LicenseInfo,
        backendCompatibility: ModelBackendCompatibility,
        trustTier: String,
        conversionReceiptId: String? = nil
    ) {
        self.id = modelId
        self.modelId = modelId
        self.sourceType = sourceType
        self.sourceLocation = sourceLocation
        self.sourceRevision = sourceRevision
        self.status = status
        self.isRunnable = isRunnable
        self.taskKind = taskKind
        self.backendFormat = backendFormat
        self.dimension = dimension
        self.installPath = installPath
        self.storageBytes = storageBytes
        self.artifactHash = artifactHash
        self.tokenizerHash = tokenizerHash
        self.artifactHashes = artifactHashes
        self.registeredAt = registeredAt
        self.lastVerified = lastVerified
        self.lastUsed = lastUsed
        self.usageCount = usageCount
        self.license = license
        self.backendCompatibility = backendCompatibility
        self.trustTier = trustTier
        self.conversionReceiptId = conversionReceiptId
    }
}

// MARK: - Backend Compatibility

/// Backend compatibility matrix for a model
public struct ModelBackendCompatibility: Codable, Sendable, Hashable {
    public let supportedBackends: [String]
    public let preferredBackend: String?

    public init(supportedBackends: [String], preferredBackend: String?) {
        self.supportedBackends = supportedBackends
        self.preferredBackend = preferredBackend
    }
}
public struct FromLegacyConfiguration: Sendable {
    public let modelId: String
    public let sourceType: String
    public let sourceLocation: String
    public let sourceRevision: String
    public let licenseDeclared: String
    public let licenseDecision: String
    public let artifactHash: String
    public let tokenizerHash: String?
    public let conversionReceiptId: String?
    public let backendCompatibility: ModelBackendCompatibility
    public let importedAt: Date
    public let trustTier: ModelTrustTier
    public let taskKind: ModelTaskKind
    public let backendFormat: ModelBackendFormat
    public let dimension: Int?
    
    public init(
        modelId: String,
        sourceType: String,
        sourceLocation: String,
        sourceRevision: String,
        licenseDeclared: String,
        licenseDecision: String,
        artifactHash: String,
        tokenizerHash: String?,
        conversionReceiptId: String?,
        backendCompatibility: ModelBackendCompatibility,
        importedAt: Date,
        trustTier: ModelTrustTier,
        taskKind: ModelTaskKind,
        backendFormat: ModelBackendFormat,
        dimension: Int?
    ) {
        self.modelId = modelId
        self.sourceType = sourceType
        self.sourceLocation = sourceLocation
        self.sourceRevision = sourceRevision
        self.licenseDeclared = licenseDeclared
        self.licenseDecision = licenseDecision
        self.artifactHash = artifactHash
        self.tokenizerHash = tokenizerHash
        self.conversionReceiptId = conversionReceiptId
        self.backendCompatibility = backendCompatibility
        self.importedAt = importedAt
        self.trustTier = trustTier
        self.taskKind = taskKind
        self.backendFormat = backendFormat
        self.dimension = dimension
    }
}
    public let importedAt: Date
    public let trustTier: String
    public let taskKind: String
    public let backendFormat: String
    public let dimension: Int?
    
    public init(
        modelId: String,
        sourceType: String,
        sourceLocation: String,
        sourceRevision: String,
        licenseDeclared: String,
        licenseDecision: String,
        artifactHash: String,
        tokenizerHash: String?,
        conversionReceiptId: String?,
        backendCompatibility: ModelBackendCompatibility,
        importedAt: Date,
        trustTier: String,
        taskKind: String,
        backendFormat: String,
        dimension: Int?
    ) {
        self.modelId = modelId
        self.sourceType = sourceType
        self.sourceLocation = sourceLocation
        self.sourceRevision = sourceRevision
        self.licenseDeclared = licenseDeclared
        self.licenseDecision = licenseDecision
        self.artifactHash = artifactHash
        self.tokenizerHash = tokenizerHash
        self.conversionReceiptId = conversionReceiptId
        self.backendCompatibility = backendCompatibility
        self.importedAt = importedAt
        self.trustTier = trustTier
        self.taskKind = taskKind
        self.backendFormat = backendFormat
        self.dimension = dimension
    }
}
    public init(
        modelId: String,
        sourceType: String,
        sourceLocation: String,
        sourceRevision: String? = nil,
        licenseDeclared: String?,
        licenseDecision: String,
        artifactHash: String,
        tokenizerHash: String? = nil,
        conversionReceiptId: String? = nil,
        backendCompatibility: ModelBackendCompatibility,
        importedAt: Date,
        trustTier: String,
        taskKind: String = "llm.inference",
        backendFormat: String = "unknown",
        dimension: Int? = nil
    ) {
        self.modelId = modelId
        self.sourceType = sourceType
        self.sourceLocation = sourceLocation
        self.sourceRevision = sourceRevision
        self.licenseDeclared = licenseDeclared
        self.licenseDecision = licenseDecision
        self.artifactHash = artifactHash
        self.tokenizerHash = tokenizerHash
        self.conversionReceiptId = conversionReceiptId
        self.backendCompatibility = backendCompatibility
        self.importedAt = importedAt
        self.trustTier = trustTier
        self.taskKind = taskKind
        self.backendFormat = backendFormat
        self.dimension = dimension
    }
}

// MARK: - Convenience Extensions

extension ModelRegistryEntry {
    /// Create entry from legacy format (for migration)
    public static func fromLegacy(config: LegacyImportConfig) -> ModelRegistryEntry {
        let licenseAllowed = config.licenseDecision.lowercased() == "allowed"
        let licenseInfo = LicenseInfo(
            declared: config.licenseDeclared,
            allowed: licenseAllowed,
            reason: config.licenseDecision,
            reviewedAt: config.importedAt
        )

        return ModelRegistryEntry(
            modelId: config.modelId,
            sourceType: config.sourceType,
            sourceLocation: config.sourceLocation,
            sourceRevision: config.sourceRevision,
            status: .ready,
            isRunnable: true,
            taskKind: config.taskKind,
            backendFormat: config.backendFormat,
            dimension: config.dimension,
            installPath: nil,
            storageBytes: 0,
            artifactHash: config.artifactHash,
            tokenizerHash: config.tokenizerHash,
            artifactHashes: [:],
            registeredAt: config.importedAt,
            lastVerified: config.importedAt,
            lastUsed: nil,
            usageCount: 0,
            license: licenseInfo,
            backendCompatibility: config.backendCompatibility,
            trustTier: config.trustTier,
            conversionReceiptId: config.conversionReceiptId
        )
    }
}

// MARK: - Helpers

extension ModelRegistryEntry {
    /// Human-readable storage size
    public var formattedStorageSize: String {
        ByteCountFormatter.string(fromByteCount: storageBytes, countStyle: .file)
    }

    /// Is this model currently usable?
    public var isAvailable: Bool {
        isRunnable && (status == .ready || status == .converting)
    }

    /// Should show a warning indicator?
    public var needsAttention: Bool {
        status == .degraded || status == .quarantined || !license.allowed
    }
}