//
//  ArtifactRegistry.swift
//  ContractsCore
//
//  Database-backed registry for CoreML artifacts with lifecycle management,
//  versioning, and capsule mapping.
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import AnigmaPrimitives
import Foundation
import CryptoKit

// MARK: - Artifact Lifecycle

/// Artifact lifecycle states
public enum ArtifactLifecycleState: String, Sendable, Codable, CaseIterable {
    /// Draft - artifact is being created/uploaded
    case draft = "draft"
    /// Active - artifact is ready for use
    case active = "active"
    /// Deprecated - artifact should not be used for new deployments
    case deprecated = "deprecated"
    /// Archived - artifact is preserved but not accessible
    case archived = "archived"
    /// Deleted - artifact is marked for deletion
    case deleted = "deleted"
    
    /// Returns whether artifact can be used for execution
    public var isRunnable: Bool {
        switch self {
        case .active, .deprecated: return true
        case .draft, .archived, .deleted: return false
        }
    }
    
    /// Returns whether artifact can be modified
    public var isMutable: Bool {
        switch self {
        case .draft: return true
        case .active, .deprecated, .archived, .deleted: return false
        }
    }
    
    /// Returns valid state transitions
    public func canTransition(to newState: ArtifactLifecycleState) -> Bool {
        switch (self, newState) {
        case (.draft, .active), (.draft, .deleted):
            return true
        case (.active, .deprecated), (.active, .archived), (.active, .deleted):
            return true
        case (.deprecated, .archived), (.deprecated, .deleted):
            return true
        case (.archived, .deleted):
            return true
        case (.deleted, _):
            return false // Deleted is terminal
        default:
            return false
        }
    }
}

/// Artifact version with semantic versioning
public struct ArtifactVersion: Sendable, Codable, Hashable {
    /// Major version (breaking changes)
    public let major: Int
    /// Minor version (backward-compatible additions)
    public let minor: Int
    /// Patch version (bug fixes)
    public let patch: Int
    /// Build identifier
    public let build: String?
    /// Prerelease identifier
    public let prerelease: String?
    
    public init(major: Int, minor: Int, patch: Int, build: String? = nil, prerelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.build = build
        self.prerelease = prerelease
    }
    
    /// Creates version from semantic version string
    public init?(semanticVersion: String) {
        let components = semanticVersion.split(separator: ".")
        guard components.count >= 3 else { return nil }
        
        guard let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]) else {
            return nil
        }
        
        self.major = major
        self.minor = minor
        self.patch = patch
        
        // Parse prerelease and build metadata
        if components.count > 3 {
            let remaining = components[3...].joined(separator: ".")
            if let plusIndex = remaining.firstIndex(of: "+") {
                let prereleaseStr = String(remaining[..<plusIndex])
                let buildStr = String(remaining[remaining.index(after: plusIndex)...])
                self.prerelease = prereleaseStr.isEmpty ? nil : prereleaseStr
                self.build = buildStr.isEmpty ? nil : buildStr
            } else {
                self.prerelease = remaining.isEmpty ? nil : remaining
                self.build = nil
            }
        } else {
            self.prerelease = nil
            self.build = nil
        }
    }
    
    /// Returns semantic version string
    public var semanticString: String {
        var version = "\(major).\(minor).\(patch)"
        if let prerelease = prerelease {
            version += "-\(prerelease)"
        }
        if let build = build {
            version += "+\(build)"
        }
        return version
    }
    
    /// Compares versions for ordering
    public func compare(to other: ArtifactVersion) -> ComparisonResult {
        if major != other.major {
            return major > other.major ? .orderedDescending : .orderedAscending
        }
        if minor != other.minor {
            return minor > other.minor ? .orderedDescending : .orderedAscending
        }
        if patch != other.patch {
            return patch > other.patch ? .orderedDescending : .orderedAscending
        }
        
        // TODO: Compare prerelease and build identifiers
        // For now, treat as equal if major.minor.patch match
        return .orderedSame
    }
    
    /// Returns whether this version is compatible with another (same major version)
    public func isCompatible(with other: ArtifactVersion) -> Bool {
        return major == other.major
    }
}

// MARK: - Artifact Entry

/// Registry entry for CoreML artifact
public struct ArtifactRegistryEntry: Sendable, Codable {
    /// Unique artifact identifier
    public let artifactId: String
    /// Artifact contract
    public let artifact: CoreMLArtifact
    /// Current lifecycle state
    public let lifecycleState: ArtifactLifecycleState
    /// Artifact version
    public let version: ArtifactVersion
    /// Storage location
    public let storagePath: String
    /// Model file hash
    public let modelHash: String
    /// Creation timestamp
    public let createdAt: Date
    /// Last updated timestamp
    public let updatedAt: Date
    /// Last accessed timestamp
    public let lastAccessedAt: Date?
    /// Access count
    public let accessCount: Int
    /// Metadata
    public let metadata: [String: String]
    /// Deprecation information if applicable
    public let deprecationInfo: DeprecationInfo?
    
    public init(
        artifactId: String,
        artifact: CoreMLArtifact,
        lifecycleState: ArtifactLifecycleState,
        version: ArtifactVersion,
        storagePath: String,
        modelHash: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastAccessedAt: Date? = nil,
        accessCount: Int = 0,
        metadata: [String: String] = [:],
        deprecationInfo: DeprecationInfo? = nil
    ) {
        self.artifactId = artifactId
        self.artifact = artifact
        self.lifecycleState = lifecycleState
        self.version = version
        self.storagePath = storagePath
        self.modelHash = modelHash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.metadata = metadata
        self.deprecationInfo = deprecationInfo
    }
}

/// Deprecation information for artifacts
public struct DeprecationInfo: Sendable, Codable {
    /// Reason for deprecation
    public let reason: String
    /// Recommended replacement artifact ID
    public let replacementArtifactId: String?
    /// Deprecation date
    public let deprecatedAt: Date
    /// Scheduled deletion date
    public let scheduledDeletionAt: Date?
    /// Migration instructions
    public let migrationInstructions: String?
    
    public init(
        reason: String,
        replacementArtifactId: String? = nil,
        deprecatedAt: Date = Date(),
        scheduledDeletionAt: Date? = nil,
        migrationInstructions: String? = nil
    ) {
        self.reason = reason
        self.replacementArtifactId = replacementArtifactId
        self.deprecatedAt = deprecatedAt
        self.scheduledDeletionAt = scheduledDeletionAt
        self.migrationInstructions = migrationInstructions
    }
}

// MARK: - Capsule Mapping

/// Mapping between artifact and capsule
public struct ArtifactCapsuleMapping: Sendable, Codable {
    /// Unique mapping identifier
    public let mappingId: String
    /// Artifact ID
    public let artifactId: String
    /// Capsule identifier
    public let capsuleId: String
    /// Capsule version
    public let capsuleVersion: String
    /// Mapping configuration
    public let configuration: [String: String]
    /// Creation timestamp
    public let createdAt: Date
    /// Last used timestamp
    public let lastUsedAt: Date?
    /// Usage count
    public let usageCount: Int
    
    public init(
        mappingId: String = UUID().uuidString,
        artifactId: String,
        capsuleId: String,
        capsuleVersion: String,
        configuration: [String: String] = [:],
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        usageCount: Int = 0
    ) {
        self.mappingId = mappingId
        self.artifactId = artifactId
        self.capsuleId = capsuleId
        self.capsuleVersion = capsuleVersion
        self.configuration = configuration
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
    }
}

// MARK: - Artifact Dependency

/// Dependency relationship between artifacts
public struct ArtifactDependency: Sendable, Codable {
    /// Unique dependency identifier
    public let dependencyId: String
    /// Source artifact ID
    public let sourceArtifactId: String
    /// Target artifact ID
    public let targetArtifactId: String
    /// Dependency type
    public let dependencyType: DependencyType
    /// Version constraint
    public let versionConstraint: String
    /// Optional description
    public let description: String?
    
    public enum DependencyType: String, Sendable, Codable, CaseIterable {
        /// Runtime dependency
        case runtime = "runtime"
        /// Build-time dependency
        case build = "build"
        /// Development dependency
        case development = "development"
        /// Optional dependency
        case optional = "optional"
        /// Peer dependency
        case peer = "peer"
    }
    
    public init(
        dependencyId: String = UUID().uuidString,
        sourceArtifactId: String,
        targetArtifactId: String,
        dependencyType: DependencyType,
        versionConstraint: String,
        description: String? = nil
    ) {
        self.dependencyId = dependencyId
        self.sourceArtifactId = sourceArtifactId
        self.targetArtifactId = targetArtifactId
        self.dependencyType = dependencyType
        self.versionConstraint = versionConstraint
        self.description = description
    }
}

// MARK: - Search and Query

/// Search criteria for artifacts
public struct ArtifactSearchCriteria: Sendable {
    /// Search by artifact ID
    public let artifactId: String?
    /// Search by model hash
    public let modelHash: String?
    /// Filter by lifecycle state
    public let lifecycleState: ArtifactLifecycleState?
    /// Filter by version
    public let version: ArtifactVersion?
    /// Filter by compatibility with version
    public let compatibleWithVersion: ArtifactVersion?
    /// Filter by capability hardware
    public let hardwareCapability: HardwareCapability?
    /// Filter by model type
    public let modelType: String?
    /// Filter by creation date range
    public let createdAfter: Date?
    public let createdBefore: Date?
    /// Filter by last accessed date
    public let lastAccessedAfter: Date?
    /// Search in metadata
    public let metadataKey: String?
    public let metadataValue: String?
    /// Limit results
    public let limit: Int?
    /// Offset for pagination
    public let offset: Int?
    /// Sort order
    public let sortBy: SortField?
    public let sortOrder: SortOrder?
    
    public enum SortField: String, Sendable {
        case artifactId = "artifactId"
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
        case lastAccessedAt = "lastAccessedAt"
        case accessCount = "accessCount"
        case version = "version"
    }
    
    public enum SortOrder: String, Sendable {
        case ascending = "ASC"
        case descending = "DESC"
    }
    
    public init(
        artifactId: String? = nil,
        modelHash: String? = nil,
        lifecycleState: ArtifactLifecycleState? = nil,
        version: ArtifactVersion? = nil,
        compatibleWithVersion: ArtifactVersion? = nil,
        hardwareCapability: HardwareCapability? = nil,
        modelType: String? = nil,
        createdAfter: Date? = nil,
        createdBefore: Date? = nil,
        lastAccessedAfter: Date? = nil,
        metadataKey: String? = nil,
        metadataValue: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
        sortBy: SortField? = .createdAt,
        sortOrder: SortOrder? = .descending
    ) {
        self.artifactId = artifactId
        self.modelHash = modelHash
        self.lifecycleState = lifecycleState
        self.version = version
        self.compatibleWithVersion = compatibleWithVersion
        self.hardwareCapability = hardwareCapability
        self.modelType = modelType
        self.createdAfter = createdAfter
        self.createdBefore = createdBefore
        self.lastAccessedAfter = lastAccessedAfter
        self.metadataKey = metadataKey
        self.metadataValue = metadataValue
        self.limit = limit
        self.offset = offset
        self.sortBy = sortBy
        self.sortOrder = sortOrder
    }
}

/// Search result with pagination info
public struct ArtifactSearchResult: Sendable {
    /// Matching artifacts
    public let artifacts: [ArtifactRegistryEntry]
    /// Total count (ignoring limit/offset)
    public let totalCount: Int
    /// Current page offset
    public let offset: Int
    /// Current page limit
    public let limit: Int
    /// Whether there are more results
    public let hasMore: Bool
    
    public init(
        artifacts: [ArtifactRegistryEntry],
        totalCount: Int,
        offset: Int,
        limit: Int
    ) {
        self.artifacts = artifacts
        self.totalCount = totalCount
        self.offset = offset
        self.limit = limit
        self.hasMore = (offset + artifacts.count) < totalCount
    }
}

// MARK: - Registry Protocol

/// Protocol for artifact registry operations
public protocol ArtifactRegistryProtocol: Sendable {
    /// Register a new artifact
    func registerArtifact(
        _ artifact: CoreMLArtifact,
        storagePath: String,
        modelHash: String,
        version: ArtifactVersion,
        metadata: [String: String]
    ) async throws -> ArtifactRegistryEntry
    
    /// Retrieve artifact by ID
    func getArtifact(_ artifactId: String) async throws -> ArtifactRegistryEntry?
    
    /// Update artifact lifecycle state
    func updateArtifactLifecycle(
        _ artifactId: String,
        newState: ArtifactLifecycleState,
        deprecationInfo: DeprecationInfo?
    ) async throws
    
    /// Record artifact access
    func recordArtifactAccess(_ artifactId: String) async throws
    
    /// Search artifacts
    func searchArtifacts(_ criteria: ArtifactSearchCriteria) async throws -> ArtifactSearchResult
    
    /// Delete artifact (soft delete)
    func deleteArtifact(_ artifactId: String) async throws
    
    /// Create artifact-capsule mapping
    func createCapsuleMapping(
        artifactId: String,
        capsuleId: String,
        capsuleVersion: String,
        configuration: [String: String]
    ) async throws -> ArtifactCapsuleMapping
    
    /// Get capsule mappings for artifact
    func getCapsuleMappings(for artifactId: String) async throws -> [ArtifactCapsuleMapping]
    
    /// Get artifact for capsule
    func getArtifactForCapsule(capsuleId: String, capsuleVersion: String) async throws -> ArtifactRegistryEntry?
    
    /// Add artifact dependency
    func addDependency(
        sourceArtifactId: String,
        targetArtifactId: String,
        dependencyType: ArtifactDependency.DependencyType,
        versionConstraint: String,
        description: String?
    ) async throws -> ArtifactDependency
    
    /// Get artifact dependencies
    func getDependencies(for artifactId: String) async throws -> [ArtifactDependency]
    
    /// Get dependent artifacts
    func getDependents(for artifactId: String) async throws -> [ArtifactDependency]
    
    /// Validate artifact integrity
    func validateArtifactIntegrity(_ artifactId: String) async throws -> Bool
    
    /// Get artifact statistics
    func getArtifactStatistics() async throws -> ArtifactStatistics
}

/// Artifact registry statistics
public struct ArtifactStatistics: Sendable, Codable {
    /// Total artifact count
    public let totalArtifacts: Int
    /// Count by lifecycle state
    public let countByLifecycleState: [ArtifactLifecycleState: Int]
    /// Count by hardware capability
    public let countByHardwareCapability: [HardwareCapability: Int]
    /// Storage usage in bytes
    public let totalStorageBytes: Int64
    /// Average artifact size
    public let averageArtifactSizeBytes: Int64
    /// Most accessed artifacts
    public let mostAccessedArtifacts: [(artifactId: String, accessCount: Int)]
    /// Recent artifacts
    public let recentArtifacts: [(artifactId: String, createdAt: Date)]
    
    private enum CodingKeys: String, CodingKey {
        case totalArtifacts
        case countByLifecycleState
        case countByHardwareCapability
        case totalStorageBytes
        case averageArtifactSizeBytes
        case mostAccessedArtifacts
        case recentArtifacts
    }
    
    private struct AccessedArtifact: Codable {
        let artifactId: String
        let accessCount: Int
    }
    
    private struct RecentArtifact: Codable {
        let artifactId: String
        let createdAt: Date
    }
    
    public init(
        totalArtifacts: Int,
        countByLifecycleState: [ArtifactLifecycleState: Int],
        countByHardwareCapability: [HardwareCapability: Int],
        totalStorageBytes: Int64,
        averageArtifactSizeBytes: Int64,
        mostAccessedArtifacts: [(artifactId: String, accessCount: Int)],
        recentArtifacts: [(artifactId: String, createdAt: Date)]
    ) {
        self.totalArtifacts = totalArtifacts
        self.countByLifecycleState = countByLifecycleState
        self.countByHardwareCapability = countByHardwareCapability
        self.totalStorageBytes = totalStorageBytes
        self.averageArtifactSizeBytes = averageArtifactSizeBytes
        self.mostAccessedArtifacts = mostAccessedArtifacts
        self.recentArtifacts = recentArtifacts
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalArtifacts = try container.decode(Int.self, forKey: .totalArtifacts)
        countByLifecycleState = try container.decode([ArtifactLifecycleState: Int].self, forKey: .countByLifecycleState)
        countByHardwareCapability = try container.decode([HardwareCapability: Int].self, forKey: .countByHardwareCapability)
        totalStorageBytes = try container.decode(Int64.self, forKey: .totalStorageBytes)
        averageArtifactSizeBytes = try container.decode(Int64.self, forKey: .averageArtifactSizeBytes)
        
        let accessed = try container.decode([AccessedArtifact].self, forKey: .mostAccessedArtifacts)
        mostAccessedArtifacts = accessed.map { (artifactId: $0.artifactId, accessCount: $0.accessCount) }
        
        let recent = try container.decode([RecentArtifact].self, forKey: .recentArtifacts)
        recentArtifacts = recent.map { (artifactId: $0.artifactId, createdAt: $0.createdAt) }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalArtifacts, forKey: .totalArtifacts)
        try container.encode(countByLifecycleState, forKey: .countByLifecycleState)
        try container.encode(countByHardwareCapability, forKey: .countByHardwareCapability)
        try container.encode(totalStorageBytes, forKey: .totalStorageBytes)
        try container.encode(averageArtifactSizeBytes, forKey: .averageArtifactSizeBytes)
        try container.encode(
            mostAccessedArtifacts.map { AccessedArtifact(artifactId: $0.artifactId, accessCount: $0.accessCount) },
            forKey: .mostAccessedArtifacts
        )
        try container.encode(
            recentArtifacts.map { RecentArtifact(artifactId: $0.artifactId, createdAt: $0.createdAt) },
            forKey: .recentArtifacts
        )
    }
}

// MARK: - Registry Errors

public enum ArtifactRegistryError: Error, Sendable {
    case databaseError(String)
    case artifactNotFound(String)
    case invalidArtifact(String)
    case invalidLifecycleTransition(String)
    case duplicateArtifact(String)
    case dependencyCycle(String)
    case storageError(String)
    case validationError(String)
}
