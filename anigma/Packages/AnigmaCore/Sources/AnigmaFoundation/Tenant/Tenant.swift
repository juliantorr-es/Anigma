import AnigmaPrimitives

import AnigmaPrimitives

//
//  Tenant.swift
//  AnigmaCore
//
//  Multi-tenant and environment management for the Anigma platform.
//  Supports multiple institutions, workspaces, and deployment environments
//  with clean logical isolation and governance.
//
//  Design principles:
//  - Each tenant is a complete logical isolation boundary
//  - Workspaces partition work within a tenant
//  - Environments (dev, staging, prod) have their own configurations
//  - All tenant operations are governed and audited
//

import AnigmaPrimitives
import ContractsCore
import Foundation

// MARK: - Tenant (Institution)

/// Represents an institution or organization using Anigma.
public struct TenantComponent: Component, Sendable, Codable {
    /// Unique tenant identifier.
    public let tenantId: UUID

    /// Short identifier/slug (e.g., "ccsf", "martys-place").
    public let slug: String

    /// Display name.
    public var name: String

    /// Description.
    public var description: String?

    /// Type of tenant.
    public var tenantType: TenantType

    /// Status of the tenant.
    public var status: TenantStatus

    /// When the tenant was created.
    public let createdAt: Date

    /// When the tenant was last modified.
    public var modifiedAt: Date

    /// Primary contact email.
    public var contactEmail: String?

    /// Timezone for the tenant.
    public var timezone: String?

    /// Locale/language preference.
    public var locale: String?

    /// Custom metadata.
    public var metadata: [String: String]

    /// Features enabled for this tenant.
    public var enabledFeatures: Set<String>

    /// Maximum users allowed (nil = unlimited).
    public var maxUsers: Int?

    /// Storage quota in bytes (nil = unlimited).
    public var storageQuota: Int64?

    public init(
        tenantId: UUID = UUID(),
        slug: String,
        name: String,
        description: String? = nil,
        tenantType: TenantType = .organization,
        contactEmail: String? = nil,
        timezone: String? = nil,
        locale: String? = nil,
        enabledFeatures: Set<String> = [],
        maxUsers: Int? = nil,
        storageQuota: Int64? = nil
    ) {
        self.tenantId = tenantId
        self.slug = slug
        self.name = name
        self.description = description
        self.tenantType = tenantType
        self.status = .active
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.contactEmail = contactEmail
        self.timezone = timezone
        self.locale = locale
        self.metadata = [:]
        self.enabledFeatures = enabledFeatures
        self.maxUsers = maxUsers
        self.storageQuota = storageQuota
    }
}

/// Types of tenants.
public enum TenantType: String, Sendable, Codable {
    /// Educational institution.
    case education = "education"

    /// Non-profit organization.
    case nonprofit = "nonprofit"

    /// Government entity.
    case government = "government"

    /// Healthcare organization.
    case healthcare = "healthcare"

    /// General organization.
    case organization = "organization"

    /// Personal/individual use.
    case personal = "personal"

    /// Development/testing tenant.
    case development = "development"
}

/// Status of a tenant.
public enum TenantStatus: String, Sendable, Codable {
    /// Tenant is active and operational.
    case active = "active"

    /// Tenant is being provisioned.
    case provisioning = "provisioning"

    /// Tenant is temporarily suspended.
    case suspended = "suspended"

    /// Tenant is being decommissioned.
    case decommissioning = "decommissioning"

    /// Tenant has been archived.
    case archived = "archived"
}

// MARK: - Workspace

/// A workspace within a tenant for logical partitioning of work.
public struct WorkspaceComponent: Component, Sendable, Codable {
    /// Unique workspace identifier.
    public let workspaceId: UUID

    /// The tenant this workspace belongs to.
    public let tenantId: UUID

    /// Short identifier/slug.
    public let slug: String

    /// Display name.
    public var name: String

    /// Description.
    public var description: String?

    /// Type of workspace.
    public var workspaceType: WorkspaceType

    /// Whether the workspace is active.
    public var isActive: Bool

    /// When the workspace was created.
    public let createdAt: Date

    /// Default operating mode for this workspace.
    public var defaultOperatingMode: OperatingMode

    /// Features specifically enabled/disabled for this workspace.
    public var featureOverrides: [String: Bool]

    /// Inherited roles for workspace members.
    public var defaultRoles: Set<String>

    /// Icon or color for UI.
    public var uiTheme: WorkspaceUITheme?

    public init(
        workspaceId: UUID = UUID(),
        tenantId: UUID,
        slug: String,
        name: String,
        description: String? = nil,
        workspaceType: WorkspaceType = .general,
        defaultOperatingMode: OperatingMode = .assistive,
        defaultRoles: Set<String> = []
    ) {
        self.workspaceId = workspaceId
        self.tenantId = tenantId
        self.slug = slug
        self.name = name
        self.description = description
        self.workspaceType = workspaceType
        self.isActive = true
        self.createdAt = Date()
        self.defaultOperatingMode = defaultOperatingMode
        self.featureOverrides = [:]
        self.defaultRoles = defaultRoles
        self.uiTheme = nil
    }
}

/// Types of workspaces.
public enum WorkspaceType: String, Sendable, Codable {
    /// General purpose workspace.
    case general = "general"

    /// DSPS/accessibility services.
    case dsps = "dsps"

    /// IT/technology services.
    case it = "it"

    /// Academic department.
    case academic = "academic"

    /// Administrative services.
    case administrative = "administrative"

    /// Student services.
    case studentServices = "student_services"

    /// Research workspace.
    case research = "research"

    /// Project-specific workspace.
    case project = "project"
}

/// UI theme for a workspace.
public struct WorkspaceUITheme: Sendable, Codable {
    public var primaryColor: String?
    public var icon: String?
    public var logoUrl: String?

    public init(primaryColor: String? = nil, icon: String? = nil, logoUrl: String? = nil) {
        self.primaryColor = primaryColor
        self.icon = icon
        self.logoUrl = logoUrl
    }
}

// MARK: - Environment

/// Represents a deployment environment.
public struct EnvironmentComponent: Component, Sendable, Codable {
    /// Unique environment identifier.
    public let environmentId: UUID

    /// The tenant this environment belongs to (nil = platform-wide).
    public let tenantId: UUID?

    /// Environment name (e.g., "development", "staging", "production").
    public let name: String

    /// Environment type.
    public var environmentType: EnvironmentType

    /// Whether this is the default environment for the tenant.
    public var isDefault: Bool

    /// Whether the environment is active.
    public var isActive: Bool

    /// Current platform version in this environment.
    public var platformVersion: String?

    /// When the environment was created.
    public let createdAt: Date

    /// Base URL for this environment.
    public var baseUrl: String?

    /// Environment-specific configuration.
    public var configuration: EnvironmentConfiguration

    public init(
        environmentId: UUID = UUID(),
        tenantId: UUID? = nil,
        name: String,
        environmentType: EnvironmentType,
        isDefault: Bool = false,
        platformVersion: String? = nil,
        baseUrl: String? = nil,
        configuration: EnvironmentConfiguration = EnvironmentConfiguration()
    ) {
        self.environmentId = environmentId
        self.tenantId = tenantId
        self.name = name
        self.environmentType = environmentType
        self.isDefault = isDefault
        self.isActive = true
        self.platformVersion = platformVersion
        self.createdAt = Date()
        self.baseUrl = baseUrl
        self.configuration = configuration
    }
}

/// Types of environments.
public enum EnvironmentType: String, Sendable, Codable {
    /// Local development.
    case development = "development"

    /// Integration testing.
    case integration = "integration"

    /// Pre-production staging.
    case staging = "staging"

    /// Production.
    case production = "production"

    /// Disaster recovery.
    case disasterRecovery = "disaster_recovery"
}

/// Environment-specific configuration.
public struct EnvironmentConfiguration: Sendable, Codable {
    /// Debug mode enabled.
    public var debugEnabled: Bool

    /// Verbose logging enabled.
    public var verboseLogging: Bool

    /// Strict security mode.
    public var strictSecurityMode: Bool

    /// Allow test data.
    public var allowTestData: Bool

    /// Maximum concurrent jobs.
    public var maxConcurrentJobs: Int

    /// Session timeout in seconds.
    public var sessionTimeoutSeconds: Int

    /// Backup frequency in hours.
    public var backupFrequencyHours: Int

    /// Retention days for logs.
    public var logRetentionDays: Int

    /// Feature flags.
    public var featureFlags: [String: Bool]

    public init(
        debugEnabled: Bool = false,
        verboseLogging: Bool = false,
        strictSecurityMode: Bool = true,
        allowTestData: Bool = false,
        maxConcurrentJobs: Int = 10,
        sessionTimeoutSeconds: Int = 3600,
        backupFrequencyHours: Int = 24,
        logRetentionDays: Int = 90,
        featureFlags: [String: Bool] = [:]
    ) {
        self.debugEnabled = debugEnabled
        self.verboseLogging = verboseLogging
        self.strictSecurityMode = strictSecurityMode
        self.allowTestData = allowTestData
        self.maxConcurrentJobs = maxConcurrentJobs
        self.sessionTimeoutSeconds = sessionTimeoutSeconds
        self.backupFrequencyHours = backupFrequencyHours
        self.logRetentionDays = logRetentionDays
        self.featureFlags = featureFlags
    }

    /// Creates a development configuration.
    public static func development() -> EnvironmentConfiguration {
        EnvironmentConfiguration(
            debugEnabled: true,
            verboseLogging: true,
            strictSecurityMode: false,
            allowTestData: true,
            maxConcurrentJobs: 5,
            sessionTimeoutSeconds: 86400, // 24 hours
            backupFrequencyHours: 168, // Weekly
            logRetentionDays: 7
        )
    }

    /// Creates a staging configuration.
    public static func staging() -> EnvironmentConfiguration {
        EnvironmentConfiguration(
            debugEnabled: true,
            verboseLogging: true,
            strictSecurityMode: true,
            allowTestData: true,
            maxConcurrentJobs: 10,
            sessionTimeoutSeconds: 7200, // 2 hours
            backupFrequencyHours: 24,
            logRetentionDays: 30
        )
    }

    /// Creates a production configuration.
    public static func production() -> EnvironmentConfiguration {
        EnvironmentConfiguration(
            debugEnabled: false,
            verboseLogging: false,
            strictSecurityMode: true,
            allowTestData: false,
            maxConcurrentJobs: 50,
            sessionTimeoutSeconds: 3600, // 1 hour
            backupFrequencyHours: 4,
            logRetentionDays: 365
        )
    }
}

// MARK: - Workspace Membership

/// Links a principal to a workspace.
public struct WorkspaceMembershipComponent: Component, Sendable, Codable {
    /// Unique membership ID.
    public let membershipId: UUID

    /// The principal.
    public let principalId: UUID

    /// The workspace.
    public let workspaceId: UUID

    /// Role within the workspace.
    public var workspaceRole: WorkspaceRole

    /// Whether membership is active.
    public var isActive: Bool

    /// When membership was created.
    public let joinedAt: Date

    /// Who added this member.
    public let addedBy: UUID

    public init(
        membershipId: UUID = UUID(),
        principalId: UUID,
        workspaceId: UUID,
        workspaceRole: WorkspaceRole = .member,
        addedBy: UUID
    ) {
        self.membershipId = membershipId
        self.principalId = principalId
        self.workspaceId = workspaceId
        self.workspaceRole = workspaceRole
        self.isActive = true
        self.joinedAt = Date()
        self.addedBy = addedBy
    }
}

/// Roles within a workspace.
public enum WorkspaceRole: String, Sendable, Codable {
    /// Regular member.
    case member = "member"

    /// Can manage workspace content.
    case editor = "editor"

    /// Can manage workspace settings and members.
    case admin = "admin"

    /// Workspace owner with full control.
    case owner = "owner"
}

// MARK: - Tenant Context

/// Runtime context for a tenant operation.
public struct TenantContext: Sendable {
    /// The current tenant.
    public let tenantId: UUID

    /// The current workspace (if any).
    public let workspaceId: UUID?

    /// The current environment.
    public let environmentId: UUID

    /// The acting principal.
    public let principalId: UUID

    /// Current operating mode.
    public let operatingMode: OperatingMode

    /// Effective configuration.
    public let configuration: EnvironmentConfiguration

    /// Enabled features.
    public let enabledFeatures: Set<String>

    public init(
        tenantId: UUID,
        workspaceId: UUID? = nil,
        environmentId: UUID,
        principalId: UUID,
        operatingMode: OperatingMode,
        configuration: EnvironmentConfiguration,
        enabledFeatures: Set<String> = []
    ) {
        self.tenantId = tenantId
        self.workspaceId = workspaceId
        self.environmentId = environmentId
        self.principalId = principalId
        self.operatingMode = operatingMode
        self.configuration = configuration
        self.enabledFeatures = enabledFeatures
    }

    /// Checks if a feature is enabled.
    public func isFeatureEnabled(_ feature: String) -> Bool {
        enabledFeatures.contains(feature) ||
        configuration.featureFlags[feature] == true
    }
}

// MARK: - Standard Features

/// Standard feature flags.
public enum StandardFeatures {
    // Core features
    public static let governance = "governance"
    public static let audit = "audit"
    public static let encryption = "encryption"

    // Domain features
    public static let pragma = "pragma"
    public static let conexus = "conexus"
    public static let codex = "codex"
    public static let transcriptum = "transcriptum"
    public static let diaplasion = "diaplasion"
    public static let observatorium = "observatorium"

    // DSPS features
    public static let dsps = "dsps"
    public static let altMedia = "alt_media"
    public static let accommodations = "accommodations"

    // Advanced features
    public static let mlx = "mlx"
    public static let agents = "agents"
    public static let autopilot = "autopilot"

    // Integration features
    public static let sisIntegration = "sis_integration"
    public static let lmsIntegration = "lms_integration"
    public static let ssoIntegration = "sso_integration"

    /// All standard features.
    public static let all: Set<String> = [
        governance, audit, encryption,
        pragma, conexus, codex, transcriptum, diaplasion, observatorium,
        dsps, altMedia, accommodations,
        mlx, agents, autopilot,
        sisIntegration, lmsIntegration, ssoIntegration
    ]
}
