import AnigmaPrimitives

import AnigmaPrimitives

//
//  MLConsentComponents.swift
//  PolytroposModule
//
//  Components for ML model consent management and provisioning.
//

import AnigmaCore
import Foundation

// MARK: - ML Model Consent Component

/// Tracks consent state for different ML model types.
public struct MLModelConsentComponent: Component, Codable {
    /// Unique consent record identifier.
    public let id: UUID

    /// Model type this consent applies to.
    public var modelType: MLModelType

    /// Current consent state.
    public var consentState: ConsentState

    /// Timestamp when consent was granted.
    public var grantedAt: Date?

    /// Timestamp when consent expires.
    public var expiresAt: Date?

    /// Privacy preferences for this model type.
    public var privacyPreferences: PrivacyPreferences

    /// Network usage permissions.
    public var networkPermissions: NetworkPermissions

    /// Approval metadata for audit trail.
    public var approvalRecord: ApprovalRecord?

    /// Version of consent terms agreed to.
    public var termsVersion: String

    /// Whether consent can be renewed automatically.
    public var autoRenewalEnabled: Bool

    public init(
        id: UUID = UUID(),
        modelType: MLModelType,
        consentState: ConsentState = .pending,
        grantedAt: Date? = nil,
        expiresAt: Date? = nil,
        privacyPreferences: PrivacyPreferences = PrivacyPreferences(),
        networkPermissions: NetworkPermissions = NetworkPermissions(),
        approvalRecord: ApprovalRecord? = nil,
        termsVersion: String = "1.0",
        autoRenewalEnabled: Bool = false
    ) {
        self.id = id
        self.modelType = modelType
        self.consentState = consentState
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.privacyPreferences = privacyPreferences
        self.networkPermissions = networkPermissions
        self.approvalRecord = approvalRecord
        self.termsVersion = termsVersion
        self.autoRenewalEnabled = autoRenewalEnabled
    }

    /// Check if consent is currently valid.
    public var isValid: Bool {
        return consentState == .granted && (expiresAt == nil || expiresAt! > Date())
    }

    /// Check if consent will expire within specified interval.
    public func expiresWithin(_ interval: TimeInterval) -> Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt.timeIntervalSinceNow <= interval
    }
}

// MARK: - Supporting Types

/// Types of ML models that require consent.
public enum MLModelType: String, Codable, CaseIterable, Sendable {
    case ocr = "ocr"
    case embedding = "embedding"
    case captioning = "captioning"
    case tts = "tts"
    case translation = "translation"
    case sentiment = "sentiment"
    case objectDetection = "objectDetection"
    case faceRecognition = "faceRecognition"
}

/// Consent state for model usage.
public enum ConsentState: String, Codable, Sendable {
    case pending = "pending"
    case granted = "granted"
    case denied = "denied"
    case expired = "expired"
    case revoked = "revoked"
}

/// Privacy preferences for model data handling.
public struct PrivacyPreferences: Codable, Sendable {
    public var dataRetentionDays: Int
    public var allowTelemetry: Bool
    public var allowLocalProcessingOnly: Bool
    public var allowModelSharing: Bool
    public var anonymizationLevel: AnonymizationLevel

    public init(
        dataRetentionDays: Int = 30,
        allowTelemetry: Bool = false,
        allowLocalProcessingOnly: Bool = true,
        allowModelSharing: Bool = false,
        anonymizationLevel: AnonymizationLevel = .full
    ) {
        self.dataRetentionDays = dataRetentionDays
        self.allowTelemetry = allowTelemetry
        self.allowLocalProcessingOnly = allowLocalProcessingOnly
        self.allowModelSharing = allowModelSharing
        self.anonymizationLevel = anonymizationLevel
    }
}

/// Network permissions for model operations.
public struct NetworkPermissions: Codable, Sendable {
    public var allowDownloads: Bool
    public var allowUpdates: Bool
    public var allowTelemetryUpload: Bool
    public var requireVPN: Bool
    public var allowedDomains: [String]

    public init(
        allowDownloads: Bool = false,
        allowUpdates: Bool = false,
        allowTelemetryUpload: Bool = false,
        requireVPN: Bool = false,
        allowedDomains: [String] = []
    ) {
        self.allowDownloads = allowDownloads
        self.allowUpdates = allowUpdates
        self.allowTelemetryUpload = allowTelemetryUpload
        self.requireVPN = requireVPN
        self.allowedDomains = allowedDomains
    }
}

/// Anonymization levels for data privacy.
public enum AnonymizationLevel: String, Codable, Sendable {
    case none = "none"
    case basic = "basic"
    case full = "full"
}

/// Approval record for consent audit trail.
public struct ApprovalRecord: Codable, Sendable {
    public var approvedBy: String
    public var approvedAt: Date
    public var approvalMethod: ApprovalMethod
    public var justification: String?
    public var ipAddress: String?
    public var deviceFingerprint: String?

    public init(
        approvedBy: String,
        approvedAt: Date = Date(),
        approvalMethod: ApprovalMethod,
        justification: String? = nil,
        ipAddress: String? = nil,
        deviceFingerprint: String? = nil
    ) {
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.approvalMethod = approvalMethod
        self.justification = justification
        self.ipAddress = ipAddress
        self.deviceFingerprint = deviceFingerprint
    }
}

/// Method of approval for consent.
public enum ApprovalMethod: String, Codable, Sendable {
    case explicit = "explicit"
    case implicit = "implicit"
    case delegated = "delegated"
    case bulk = "bulk"
}

// MARK: - Model Pack Registry Component

/// Registry entry for an ML model pack with version and metadata.
public struct ModelPackRegistryComponent: Component, Codable {
    /// Unique pack identifier.
    public let id: UUID

    /// Pack name and version.
    public var name: String
    public var version: String

    /// Model types included in this pack.
    public var modelTypes: [MLModelType]

    /// Download information.
    public var downloadInfo: ModelDownloadInfo

    /// Installation status.
    public var installationStatus: InstallationStatus

    /// Hash verification data.
    public var verification: ModelVerification

    /// Size and resource requirements.
    public var resourceRequirements: ResourceRequirements

    /// Pack metadata and description.
    public var metadata: ModelPackMetadata

    public init(
        id: UUID = UUID(),
        name: String,
        version: String,
        modelTypes: [MLModelType],
        downloadInfo: ModelDownloadInfo,
        installationStatus: InstallationStatus = .notInstalled,
        verification: ModelVerification,
        resourceRequirements: ResourceRequirements,
        metadata: ModelPackMetadata
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.modelTypes = modelTypes
        self.downloadInfo = downloadInfo
        self.installationStatus = installationStatus
        self.verification = verification
        self.resourceRequirements = resourceRequirements
        self.metadata = metadata
    }
}

// MARK: - Model Installation Record Component

/// Tracks installation history and approval records for models.
public struct ModelInstallationRecordComponent: Component, Codable {
    /// Unique record identifier.
    public let id: UUID

    /// Reference to the model pack.
    public var modelPackId: UUID

    /// Installation attempt history.
    public var installationAttempts: [InstallationAttempt]

    /// Current installation state.
    public var currentState: InstallationState

    /// Approval workflow status.
    public var approvalStatus: ApprovalStatus

    /// Installation metadata.
    public var installedAt: Date?
    public var installedBy: String?
    public var installationPath: String?

    /// Health and integrity status.
    public var healthStatus: ModelHealthStatus

    public init(
        id: UUID = UUID(),
        modelPackId: UUID,
        installationAttempts: [InstallationAttempt] = [],
        currentState: InstallationState = .notStarted,
        approvalStatus: ApprovalStatus = .pending,
        installedAt: Date? = nil,
        installedBy: String? = nil,
        installationPath: String? = nil,
        healthStatus: ModelHealthStatus = .unknown
    ) {
        self.id = id
        self.modelPackId = modelPackId
        self.installationAttempts = installationAttempts
        self.currentState = currentState
        self.approvalStatus = approvalStatus
        self.installedAt = installedAt
        self.installedBy = installedBy
        self.installationPath = installationPath
        self.healthStatus = healthStatus
    }
}

// MARK: - Consent Flow UI Component

/// UI state for consent flow interactions.
public struct ConsentFlowUIComponent: Component, Codable {
    /// Unique flow identifier.
    public let id: UUID

    /// Current step in the consent flow.
    public var currentStep: ConsentFlowStep

    /// Model types pending consent.
    public var pendingConsents: [MLModelType]

    /// User interaction state.
    public var interactionState: InteractionState

    /// UI preferences and customization.
    public var uiPreferences: UIPreferences

    /// Flow context and metadata.
    public var flowContext: FlowContext

    public init(
        id: UUID = UUID(),
        currentStep: ConsentFlowStep = .introduction,
        pendingConsents: [MLModelType] = [],
        interactionState: InteractionState = InteractionState(),
        uiPreferences: UIPreferences = UIPreferences(),
        flowContext: FlowContext = FlowContext()
    ) {
        self.id = id
        self.currentStep = currentStep
        self.pendingConsents = pendingConsents
        self.interactionState = interactionState
        self.uiPreferences = uiPreferences
        self.flowContext = flowContext
    }
}

// MARK: - Model Management Types

/// Download information for model packs.
public struct ModelDownloadInfo: Codable, Sendable {
    public var url: URL
    public var checksum: String
    public var checksumAlgorithm: String
    public var sizeBytes: Int64
    public var mirrors: [URL]
    public var requiresAuth: Bool
    public var authMethod: AuthMethod?

    public init(
        url: URL,
        checksum: String,
        checksumAlgorithm: String = "blake3",
        sizeBytes: Int64,
        mirrors: [URL] = [],
        requiresAuth: Bool = false,
        authMethod: AuthMethod? = nil
    ) {
        self.url = url
        self.checksum = checksum
        self.checksumAlgorithm = checksumAlgorithm
        self.sizeBytes = sizeBytes
        self.mirrors = mirrors
        self.requiresAuth = requiresAuth
        self.authMethod = authMethod
    }
}

/// Authentication method for model downloads.
public enum AuthMethod: String, Codable, Sendable {
    case none = "none"
    case apiKey = "apiKey"
    case oauth = "oauth"
    case certificate = "certificate"
}

/// Installation status for model packs.
public enum InstallationStatus: String, Codable, Sendable {
    case notInstalled = "notInstalled"
    case downloading = "downloading"
    case verifying = "verifying"
    case installing = "installing"
    case installed = "installed"
    case failed = "failed"
    case corrupted = "corrupted"
    case updating = "updating"
}

/// Verification data for model integrity.
public struct ModelVerification: Codable, Sendable {
    public var expectedHash: String
    public var algorithm: String
    public var signature: String?
    public var publicKey: String?
    public var verifiedAt: Date?
    public var verificationResult: VerificationResult?

    public init(
        expectedHash: String,
        algorithm: String = "blake3",
        signature: String? = nil,
        publicKey: String? = nil
    ) {
        self.expectedHash = expectedHash
        self.algorithm = algorithm
        self.signature = signature
        self.publicKey = publicKey
    }
}

/// Result of model verification.
public enum VerificationResult: String, Codable, Sendable {
    case pending = "pending"
    case passed = "passed"
    case failed = "failed"
    case corrupted = "corrupted"
    case signatureInvalid = "signatureInvalid"
}

/// Resource requirements for model packs.
public struct ResourceRequirements: Codable, Sendable {
    public var diskSpaceMB: Int
    public var memoryMB: Int
    public var cpuCores: Int
    public var gpuRequired: Bool
    public var gpuMemoryMB: Int
    public var osRequirements: OSRequirements

    public init(
        diskSpaceMB: Int,
        memoryMB: Int,
        cpuCores: Int = 2,
        gpuRequired: Bool = false,
        gpuMemoryMB: Int = 0,
        osRequirements: OSRequirements = OSRequirements()
    ) {
        self.diskSpaceMB = diskSpaceMB
        self.memoryMB = memoryMB
        self.cpuCores = cpuCores
        self.gpuRequired = gpuRequired
        self.gpuMemoryMB = gpuMemoryMB
        self.osRequirements = osRequirements
    }
}

/// Operating system requirements.
public struct OSRequirements: Codable, Sendable {
    public var minVersion: String
    public var maxVersion: String?
    public var platforms: [String]

    public init(
        minVersion: String = "10.15",
        maxVersion: String? = nil,
        platforms: [String] = ["macOS"]
    ) {
        self.minVersion = minVersion
        self.maxVersion = maxVersion
        self.platforms = platforms
    }
}

/// Metadata for model packs.
public struct ModelPackMetadata: Codable, Sendable {
    public var description: String
    public var vendor: String
    public var license: String
    public var version: String
    public var releaseDate: Date
    public var tags: [String]
    public var documentation: String?
    public var changelog: String?

    public init(
        description: String,
        vendor: String,
        license: String,
        version: String,
        releaseDate: Date = Date(),
        tags: [String] = [],
        documentation: String? = nil,
        changelog: String? = nil
    ) {
        self.description = description
        self.vendor = vendor
        self.license = license
        self.version = version
        self.releaseDate = releaseDate
        self.tags = tags
        self.documentation = documentation
        self.changelog = changelog
    }
}

/// Installation attempt record.
public struct InstallationAttempt: Codable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var status: InstallationState
    public var error: String?
    public var progress: Double
    public var log: [String]
    public var initiatedBy: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        status: InstallationState,
        error: String? = nil,
        progress: Double = 0.0,
        log: [String] = [],
        initiatedBy: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.status = status
        self.error = error
        self.progress = progress
        self.log = log
        self.initiatedBy = initiatedBy
    }
}

/// Installation state for models.
public enum InstallationState: String, Codable, Sendable {
    case notStarted = "notStarted"
    case downloading = "downloading"
    case verifying = "verifying"
    case installing = "installing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

/// Approval status for workflows.
public enum ApprovalStatus: String, Codable, Sendable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case requiresReview = "requiresReview"
}

/// Health status for installed models.
public enum ModelHealthStatus: String, Codable, Sendable {
    case unknown = "unknown"
    case healthy = "healthy"
    case corrupted = "corrupted"
    case outdated = "outdated"
    case incompatible = "incompatible"
}

/// Steps in the consent flow.
public enum ConsentFlowStep: String, Codable, Sendable {
    case introduction = "introduction"
    case privacyPolicy = "privacyPolicy"
    case modelSelection = "modelSelection"
    case networkPermissions = "networkPermissions"
    case dataRetention = "dataRetention"
    case confirmation = "confirmation"
    case completed = "completed"
}

/// User interaction state for consent flow.
public struct InteractionState: Codable, Sendable {
    public var timeSpent: TimeInterval
    public var actions: [UserAction]
    public var abandoned: Bool
    public var abandonmentReason: String?

    public init(
        timeSpent: TimeInterval = 0.0,
        actions: [UserAction] = [],
        abandoned: Bool = false,
        abandonmentReason: String? = nil
    ) {
        self.timeSpent = timeSpent
        self.actions = actions
        self.abandoned = abandoned
        self.abandonmentReason = abandonmentReason
    }
}

/// User action in consent flow.
public struct UserAction: Codable, Sendable {
    public var action: String
    public var timestamp: Date
    public var details: [String: String]?

    public init(action: String, timestamp: Date = Date(), details: [String: String]? = nil) {
        self.action = action
        self.timestamp = timestamp
        self.details = details
    }
}

/// UI preferences for consent flow.
public struct UIPreferences: Codable, Sendable {
    public var language: String
    public var theme: String
    public var showAdvancedOptions: Bool
    public var condensedView: Bool

    public init(
        language: String = "en",
        theme: String = "system",
        showAdvancedOptions: Bool = false,
        condensedView: Bool = false
    ) {
        self.language = language
        self.theme = theme
        self.showAdvancedOptions = showAdvancedOptions
        self.condensedView = condensedView
    }
}

/// Flow context for consent flow.
public struct FlowContext: Codable, Sendable {
    public var sessionId: String
    public var userId: String?
    public var deviceId: String?
    public var initiatingFeature: String?
    public var urgency: FlowUrgency

    public init(
        sessionId: String = UUID().uuidString,
        userId: String? = nil,
        deviceId: String? = nil,
        initiatingFeature: String? = nil,
        urgency: FlowUrgency = .normal
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.deviceId = deviceId
        self.initiatingFeature = initiatingFeature
        self.urgency = urgency
    }
}

/// Urgency level for consent flow.
public enum FlowUrgency: String, Codable, Sendable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
}
