//
//  VersionManagement.swift
//  AnigmaCore
//
//  AnigmaCore - Update Management Domain
//
//  First-class version tracking, release manifests, and client state management.
//  Treats versions as governed domain data, not afterthoughts.
//

import Foundation

// MARK: - Semantic Version

/// Semantic version with comparison support
public struct SemanticVersion: Sendable, Hashable, Codable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?
    public let build: String?

    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil, build: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.build = build
    }

    public init?(string: String) {
        // Parse "1.2.3-beta+build123" format
        let buildSplit = string.split(separator: "+", maxSplits: 1)
        let build = buildSplit.count > 1 ? String(buildSplit[1]) : nil

        let prereleaseSplit = String(buildSplit[0]).split(separator: "-", maxSplits: 1)
        let prerelease = prereleaseSplit.count > 1 ? String(prereleaseSplit[1]) : nil

        let versionParts = String(prereleaseSplit[0]).split(separator: ".")
        guard versionParts.count >= 3,
              let major = Int(versionParts[0]),
              let minor = Int(versionParts[1]),
              let patch = Int(versionParts[2]) else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.build = build
    }

    public var description: String {
        var result = "\(major).\(minor).\(patch)"
        if let pre = prerelease { result += "-\(pre)" }
        if let b = build { result += "+\(b)" }
        return result
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        // Prerelease versions have lower precedence
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil): return false
        case (nil, _): return false  // Release > prerelease
        case (_, nil): return true   // Prerelease < release
        case (let l?, let r?): return l < r
        }
    }

    /// Check if this version satisfies a minimum requirement
    public func satisfies(minimum: SemanticVersion) -> Bool {
        return self >= minimum
    }

    /// Check if this is a breaking change from another version
    public func isBreakingFrom(_ other: SemanticVersion) -> Bool {
        return self.major > other.major
    }
}

// MARK: - Platform Version

/// Current platform version state
public struct PlatformVersion: Sendable, Codable {
    public let current: SemanticVersion
    public let minimumClient: SemanticVersion
    public let pendingRollout: SemanticVersion?
    public let lastUpdated: Date
    public let environment: DeploymentEnvironment

    public init(
        current: SemanticVersion,
        minimumClient: SemanticVersion,
        pendingRollout: SemanticVersion? = nil,
        lastUpdated: Date = Date(),
        environment: DeploymentEnvironment = .development
    ) {
        self.current = current
        self.minimumClient = minimumClient
        self.pendingRollout = pendingRollout
        self.lastUpdated = lastUpdated
        self.environment = environment
    }
}

/// Deployment environment
public enum DeploymentEnvironment: String, Sendable, Codable, CaseIterable {
    case development
    case staging
    case pilot
    case production

    public var allowsQuickUpdates: Bool {
        switch self {
        case .development, .staging: return true
        case .pilot, .production: return false
        }
    }

    public var defaultGracePeriodHours: Int {
        switch self {
        case .development: return 0
        case .staging: return 1
        case .pilot: return 24
        case .production: return 72
        }
    }
}

// MARK: - Release Manifest

/// Complete release information
public struct ReleaseManifest: Sendable, Codable, Identifiable {
    public let id: UUID
    public let version: SemanticVersion
    public let buildId: String
    public let releaseDate: Date
    public let mandatoryDate: Date?
    public let migrations: [MigrationInfo]
    public let moduleVersions: [String: SemanticVersion]
    public let flags: ReleaseFlags
    public let notes: String
    public let signature: Data?

    public init(
        id: UUID = UUID(),
        version: SemanticVersion,
        buildId: String,
        releaseDate: Date = Date(),
        mandatoryDate: Date? = nil,
        migrations: [MigrationInfo] = [],
        moduleVersions: [String: SemanticVersion] = [:],
        flags: ReleaseFlags = ReleaseFlags(),
        notes: String = "",
        signature: Data? = nil
    ) {
        self.id = id
        self.version = version
        self.buildId = buildId
        self.releaseDate = releaseDate
        self.mandatoryDate = mandatoryDate
        self.migrations = migrations
        self.moduleVersions = moduleVersions
        self.flags = flags
        self.notes = notes
        self.signature = signature
    }

    /// Check if this release is now mandatory
    public func isMandatory(at date: Date = Date()) -> Bool {
        guard let mandatory = mandatoryDate else { return false }
        return date >= mandatory
    }

    /// Time until mandatory, if any
    public func timeUntilMandatory(from date: Date = Date()) -> TimeInterval? {
        guard let mandatory = mandatoryDate else { return nil }
        let interval = mandatory.timeIntervalSince(date)
        return interval > 0 ? interval : nil
    }
}

/// Release flags
public struct ReleaseFlags: Sendable, Codable {
    public var requiresRestart: Bool
    public var breakingChange: Bool
    public var maintenanceModeNeeded: Bool
    public var dataBackupRequired: Bool
    public var emergencyHotfix: Bool

    public init(
        requiresRestart: Bool = true,
        breakingChange: Bool = false,
        maintenanceModeNeeded: Bool = false,
        dataBackupRequired: Bool = false,
        emergencyHotfix: Bool = false
    ) {
        self.requiresRestart = requiresRestart
        self.breakingChange = breakingChange
        self.maintenanceModeNeeded = maintenanceModeNeeded
        self.dataBackupRequired = dataBackupRequired
        self.emergencyHotfix = emergencyHotfix
    }
}

/// Migration information
public struct MigrationInfo: Sendable, Codable, Identifiable {
    public let id: String
    public let description: String
    public let affectedDomains: [String]
    public let isReversible: Bool
    public let estimatedDuration: TimeInterval
    public let preconditions: [String]

    public init(
        id: String,
        description: String,
        affectedDomains: [String] = [],
        isReversible: Bool = true,
        estimatedDuration: TimeInterval = 60,
        preconditions: [String] = []
    ) {
        self.id = id
        self.description = description
        self.affectedDomains = affectedDomains
        self.isReversible = isReversible
        self.estimatedDuration = estimatedDuration
        self.preconditions = preconditions
    }
}

// MARK: - Client State

/// Client version and session state
public struct ClientVersionState: Sendable, Codable, Identifiable {
    public let id: UUID
    public let clientVersion: SemanticVersion
    public let serverVersion: SemanticVersion
    public let principalId: String
    public let deviceId: String?
    public let sessionStart: Date
    public let lastActivity: Date
    public let capabilities: ClientCapabilities
    public let updateStatus: ClientUpdateStatus

    public init(
        id: UUID = UUID(),
        clientVersion: SemanticVersion,
        serverVersion: SemanticVersion,
        principalId: String,
        deviceId: String? = nil,
        sessionStart: Date = Date(),
        lastActivity: Date = Date(),
        capabilities: ClientCapabilities = ClientCapabilities(),
        updateStatus: ClientUpdateStatus = .current
    ) {
        self.id = id
        self.clientVersion = clientVersion
        self.serverVersion = serverVersion
        self.principalId = principalId
        self.deviceId = deviceId
        self.sessionStart = sessionStart
        self.lastActivity = lastActivity
        self.capabilities = capabilities
        self.updateStatus = updateStatus
    }

    /// Check if client version is acceptable
    public func isVersionAcceptable(minimum: SemanticVersion) -> Bool {
        return clientVersion.satisfies(minimum: minimum)
    }
}

/// Client capabilities
public struct ClientCapabilities: Sendable, Codable {
    public var supportedModules: Set<String>
    public var offlineCapable: Bool
    public var backgroundSync: Bool
    public var autoUpdate: Bool

    public init(
        supportedModules: Set<String> = [],
        offlineCapable: Bool = false,
        backgroundSync: Bool = false,
        autoUpdate: Bool = false
    ) {
        self.supportedModules = supportedModules
        self.offlineCapable = offlineCapable
        self.backgroundSync = backgroundSync
        self.autoUpdate = autoUpdate
    }
}

/// Client update status
public enum ClientUpdateStatus: String, Sendable, Codable {
    case current           // On latest version
    case updateAvailable   // Update available but not required
    case drainMode         // Finishing work, no new operations
    case blocked           // Must update before any operations
    case updating          // Currently updating
}

// MARK: - Version Policy

/// Version policy for enforcement
public struct VersionPolicy: Sendable, Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let minimumVersion: SemanticVersion
    public let effectiveDate: Date
    public let gracePeriodHours: Int
    public let scope: PolicyScope
    public let enforcementLevel: EnforcementLevel

    public init(
        id: UUID = UUID(),
        name: String,
        minimumVersion: SemanticVersion,
        effectiveDate: Date = Date(),
        gracePeriodHours: Int = 72,
        scope: PolicyScope = .global,
        enforcementLevel: EnforcementLevel = .hard
    ) {
        self.id = id
        self.name = name
        self.minimumVersion = minimumVersion
        self.effectiveDate = effectiveDate
        self.gracePeriodHours = gracePeriodHours
        self.scope = scope
        self.enforcementLevel = enforcementLevel
    }

    /// Check if policy is in grace period
    public func isInGracePeriod(at date: Date = Date()) -> Bool {
        let graceEnd = effectiveDate.addingTimeInterval(TimeInterval(gracePeriodHours * 3600))
        return date >= effectiveDate && date < graceEnd
    }

    /// Check if policy is fully enforced
    public func isFullyEnforced(at date: Date = Date()) -> Bool {
        let graceEnd = effectiveDate.addingTimeInterval(TimeInterval(gracePeriodHours * 3600))
        return date >= graceEnd
    }
}

/// Policy scope
public enum PolicyScope: Sendable, Codable {
    case global
    case environment(DeploymentEnvironment)
    case tenant(String)
    case module(String)
}

/// Enforcement level
public enum EnforcementLevel: String, Sendable, Codable {
    case soft    // Warn but allow
    case medium  // Drain mode after grace
    case hard    // Block after grace
}

// MARK: - Version Components (ECS)

/// ECS Component for platform version
public struct PlatformVersionComponent: Component {
    public var version: PlatformVersion
    public var activePolicy: VersionPolicy?
    public var releaseManifest: ReleaseManifest?

    public init(version: PlatformVersion, activePolicy: VersionPolicy? = nil, releaseManifest: ReleaseManifest? = nil) {
        self.version = version
        self.activePolicy = activePolicy
        self.releaseManifest = releaseManifest
    }
}

/// ECS Component for client state tracking
public struct ClientStateComponent: Component {
    public var state: ClientVersionState
    public var pendingDrafts: Int
    public var activeOperations: Int
    public var lastCheckpointTime: Date?

    public init(state: ClientVersionState, pendingDrafts: Int = 0, activeOperations: Int = 0, lastCheckpointTime: Date? = nil) {
        self.state = state
        self.pendingDrafts = pendingDrafts
        self.activeOperations = activeOperations
        self.lastCheckpointTime = lastCheckpointTime
    }
}

/// ECS Component for release manifest storage
public struct ReleaseManifestComponent: Component {
    public var manifest: ReleaseManifest
    public var deploymentStatus: DeploymentStatus
    public var deployedAt: Date?
    public var rollbackAvailable: Bool

    public init(manifest: ReleaseManifest, deploymentStatus: DeploymentStatus = .pending, deployedAt: Date? = nil, rollbackAvailable: Bool = true) {
        self.manifest = manifest
        self.deploymentStatus = deploymentStatus
        self.deployedAt = deployedAt
        self.rollbackAvailable = rollbackAvailable
    }
}

/// Deployment status
public enum DeploymentStatus: String, Sendable, Codable {
    case pending
    case deploying
    case deployed
    case rollingBack
    case rolledBack
    case failed
}
