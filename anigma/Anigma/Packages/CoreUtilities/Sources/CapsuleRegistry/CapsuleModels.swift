import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - Capsule Metadata

/// Metadata describing a capsule's capabilities and configuration
public struct CapsuleMetadata: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let version: SemanticVersion
    public let description: String
    public let capabilities: [String]
    public let dependencies: [CapsuleDependency]
    public let author: String
    public let license: String
    public let homepage: String?
    public let repository: String?
    public let keywords: [String]
    public let entryPoint: String
    public let configurationSchema: String?
    public let healthCheckEndpoint: String?
    public let supportedPlatforms: [String]
    
    public init(
        id: String,
        name: String,
        version: SemanticVersion,
        description: String,
        capabilities: [String] = [],
        dependencies: [CapsuleDependency] = [],
        author: String,
        license: String = "MIT",
        homepage: String? = nil,
        repository: String? = nil,
        keywords: [String] = [],
        entryPoint: String,
        configurationSchema: String? = nil,
        healthCheckEndpoint: String? = nil,
        supportedPlatforms: [String] = ["macOS", "iOS"]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.capabilities = capabilities
        self.dependencies = dependencies
        self.author = author
        self.license = license
        self.homepage = homepage
        self.repository = repository
        self.keywords = keywords
        self.entryPoint = entryPoint
        self.configurationSchema = configurationSchema
        self.healthCheckEndpoint = healthCheckEndpoint
        self.supportedPlatforms = supportedPlatforms
    }
}

/// Semantic version for capsule versioning
public struct SemanticVersion: Codable, Sendable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let preRelease: String?
    public let build: String?
    
    public init(major: Int, minor: Int, patch: Int, preRelease: String? = nil, build: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.preRelease = preRelease
        self.build = build
    }
    
    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        
        switch (lhs.preRelease, rhs.preRelease) {
        case (nil, nil): return false
        case (nil, _): return false // release > pre-release
        case (_, nil): return true  // pre-release < release
        case (let l?, let r?): return l < r
        }
    }
    
    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.patch == rhs.patch &&
               lhs.preRelease == rhs.preRelease
    }
}

/// Dependency specification for capsules
public struct CapsuleDependency: Codable, Sendable {
    public let name: String
    public let versionRequirement: VersionRequirement
    public let optional: Bool
    public let reason: String?
    
    public init(name: String, versionRequirement: VersionRequirement, optional: Bool = false, reason: String? = nil) {
        self.name = name
        self.versionRequirement = versionRequirement
        self.optional = optional
        self.reason = reason
    }
}

/// Version requirement specification
public enum VersionRequirement: Codable, Sendable {
    case exact(SemanticVersion)
    case greaterThan(SemanticVersion)
    case greaterThanOrEqual(SemanticVersion)
    case lessThan(SemanticVersion)
    case lessThanOrEqual(SemanticVersion)
    case range(SemanticVersion, SemanticVersion)
    case compatibleWith(SemanticVersion) // ^1.2.3 means >=1.2.3 <2.0.0
    
    public func satisfies(_ version: SemanticVersion) -> Bool {
        switch self {
        case .exact(let required):
            return version == required
        case .greaterThan(let required):
            return version > required
        case .greaterThanOrEqual(let required):
            return version >= required
        case .lessThan(let required):
            return version < required
        case .lessThanOrEqual(let required):
            return version <= required
        case .range(let lower, let upper):
            return version >= lower && version <= upper
        case .compatibleWith(let required):
            // ^1.2.3 means >=1.2.3 <2.0.0
            if version < required { return false }
            if version.major != required.major { return false }
            return true
        }
    }
}

// MARK: - Capsule State

/// Runtime state of a capsule
public enum CapsuleState: String, Codable, Sendable {
    case unknown
    case loading
    case active
    case idle
    case error
    case unloading
    case unloaded
}

/// Health status of a capsule
public struct CapsuleHealth: Codable, Sendable {
    public let status: HealthStatus
    public let lastCheck: Date
    public let message: String?
    public let metrics: [String: String]
    
    public init(status: HealthStatus, lastCheck: Date = Date(), message: String? = nil, metrics: [String: String] = [:]) {
        self.status = status
        self.lastCheck = lastCheck
        self.message = message
        self.metrics = metrics
    }
}

/// Health status enumeration
public enum HealthStatus: String, Codable, Sendable {
    case healthy
    case degraded
    case unhealthy
    case unknown
}

// MARK: - Capsule Instance

/// Runtime representation of a loaded capsule
public final class CapsuleInstance: @unchecked Sendable {
    public let metadata: CapsuleMetadata
    private let lock = NSLock()
    private nonisolated(unsafe) var _state: CapsuleState = .unknown
    private nonisolated(unsafe) var _health: CapsuleHealth
    private nonisolated(unsafe) var _loadTime: Date?
    private nonisolated(unsafe) var _error: CapsuleError?
    
    public var state: CapsuleState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }
    
    public var health: CapsuleHealth {
        lock.lock()
        defer { lock.unlock() }
        return _health
    }
    
    public var loadTime: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _loadTime
    }
    
    public var lastError: CapsuleError? {
        lock.lock()
        defer { lock.unlock() }
        return _error
    }
    
    public init(metadata: CapsuleMetadata) {
        self.metadata = metadata
        self._health = CapsuleHealth(status: .unknown)
    }
    
    internal func updateState(_ newState: CapsuleState, error: CapsuleError? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        _state = newState
        _error = error
        
        if newState == .active && _loadTime == nil {
            _loadTime = Date()
        }
    }
    
    internal func updateHealth(_ newHealth: CapsuleHealth) {
        lock.lock()
        defer { lock.unlock() }
        _health = newHealth
    }
}