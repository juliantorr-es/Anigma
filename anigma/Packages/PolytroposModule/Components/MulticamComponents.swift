import AnigmaPrimitives

import AnigmaPrimitives

//
//  MulticamComponents.swift
//  PolytroposModule
//
//  Components for multicam clustering and synchronization.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Multicam Cluster Component

/// A group of media assets covering the same take, synced in time.
public struct MulticamClusterComponent: Component, Codable {
    /// Unique cluster identifier.
    public let id: UUID

    /// Human-readable cluster name (e.g., "Song 1", "Set 2").
    public var name: String

    /// Asset entity IDs in this cluster.
    public var assetIds: [EntityId]

    /// Reference asset ID (the "master" for sync).
    public var referenceAssetId: EntityId?

    /// Cluster status.
    public var status: ClusterStatus

    /// Whether sync has been manually verified.
    public var syncVerified: Bool

    /// Cluster start time (earliest aligned point).
    public var clusterStartTime: TimeInterval

    /// Cluster end time (latest aligned point).
    public var clusterEndTime: TimeInterval

    /// Cluster duration.
    public var duration: TimeInterval {
        clusterEndTime - clusterStartTime
    }

    public init(
        id: UUID = UUID(),
        name: String,
        assetIds: [EntityId] = [],
        referenceAssetId: EntityId? = nil,
        status: ClusterStatus = .pending,
        syncVerified: Bool = false,
        clusterStartTime: TimeInterval = 0,
        clusterEndTime: TimeInterval = 0
    ) {
        self.id = id
        self.name = name
        self.assetIds = assetIds
        self.referenceAssetId = referenceAssetId
        self.status = status
        self.syncVerified = syncVerified
        self.clusterStartTime = clusterStartTime
        self.clusterEndTime = clusterEndTime
    }
}

/// Cluster processing status.
public enum ClusterStatus: String, Codable, Sendable {
    case pending
    case syncing
    case synced
    case analyzing
    case ready
    case error
}

// MARK: - Sync Data Component

/// Per-asset synchronization data within a cluster.
public struct SyncDataComponent: Component, Codable {
    /// The cluster this asset is synced to.
    public var clusterId: UUID

    /// Offset from reference asset in seconds.
    /// Positive = this asset starts after reference.
    /// Negative = this asset starts before reference.
    public var offsetFromReference: TimeInterval

    /// Sync confidence score (0-1).
    public var confidence: Double

    /// Sync method used.
    public var syncMethod: SyncMethod

    /// Manual offset adjustment by user.
    public var manualAdjustment: TimeInterval

    /// Whether this asset is the reference.
    public var isReference: Bool

    /// Effective offset (computed + manual).
    public var effectiveOffset: TimeInterval {
        offsetFromReference + manualAdjustment
    }

    public init(
        clusterId: UUID,
        offsetFromReference: TimeInterval = 0,
        confidence: Double = 0,
        syncMethod: SyncMethod = .audio,
        manualAdjustment: TimeInterval = 0,
        isReference: Bool = false
    ) {
        self.clusterId = clusterId
        self.offsetFromReference = offsetFromReference
        self.confidence = confidence
        self.syncMethod = syncMethod
        self.manualAdjustment = manualAdjustment
        self.isReference = isReference
    }
}

/// Method used for synchronization.
public enum SyncMethod: String, Codable, Sendable {
    /// Cross-correlation of audio waveforms.
    case audio

    /// Timecode embedded in file.
    case timecode

    /// File creation timestamps.
    case timestamp

    /// User-placed sync markers.
    case manual

    /// Combination of methods.
    case hybrid
}

// MARK: - Camera Classification Component

/// Classification of camera angle/type.
public struct CameraClassificationComponent: Component, Codable {
    /// Camera angle type.
    public var angleType: CameraAngleType

    /// Primary subject coverage.
    public var subjectCoverage: SubjectCoverage

    /// Stability assessment.
    public var stabilityRating: StabilityRating

    /// Overall quality score (0-1).
    public var qualityScore: Double

    /// Confidence in classification.
    public var classificationConfidence: Double

    public init(
        angleType: CameraAngleType = .unknown,
        subjectCoverage: SubjectCoverage = .mixed,
        stabilityRating: StabilityRating = .moderate,
        qualityScore: Double = 0.5,
        classificationConfidence: Double = 0
    ) {
        self.angleType = angleType
        self.subjectCoverage = subjectCoverage
        self.stabilityRating = stabilityRating
        self.qualityScore = qualityScore
        self.classificationConfidence = classificationConfidence
    }
}

/// Camera angle classification.
public enum CameraAngleType: String, Codable, Sendable {
    case wide      // Full stage/scene
    case medium    // Half-body or small group
    case close     // Face/detail
    case crowd     // Audience shots
    case overhead  // Bird's eye
    case pov       // First-person / handheld audience
    case detail    // Extreme close-up on objects
    case unknown
}

/// What the camera is primarily capturing.
public enum SubjectCoverage: String, Codable, Sendable {
    case stage        // Main performance area
    case performer    // Specific performer focus
    case crowd        // Audience
    case environment  // Venue/atmosphere
    case mixed        // Combination
}

/// Camera stability assessment.
public enum StabilityRating: String, Codable, Sendable {
    case veryStable   // Tripod/gimbal
    case stable       // Light handheld with IS
    case moderate     // Noticeable but acceptable
    case shaky        // Distracting movement
    case veryShaky    // Hard to watch
}

// MARK: - Sync Marker Component

/// Manual sync points for user-assisted alignment.
public struct SyncMarkerComponent: Component, Codable {
    /// Markers placed by user or system.
    public var markers: [SyncMarker]

    public init(markers: [SyncMarker] = []) {
        self.markers = markers
    }
}

/// A single sync point (clap, flash, etc.).
public struct SyncMarker: Codable, Sendable {
    /// Unique marker ID.
    public let id: UUID

    /// Time in the asset.
    public var timeInAsset: TimeInterval

    /// Marker type.
    public var markerType: SyncMarkerType

    /// Optional label.
    public var label: String?

    /// Corresponding markers in other assets (by asset entity ID).
    public var linkedMarkers: [EntityId: UUID]

    public init(
        id: UUID = UUID(),
        timeInAsset: TimeInterval,
        markerType: SyncMarkerType = .clap,
        label: String? = nil,
        linkedMarkers: [EntityId: UUID] = [:]
    ) {
        self.id = id
        self.timeInAsset = timeInAsset
        self.markerType = markerType
        self.label = label
        self.linkedMarkers = linkedMarkers
    }
}

/// Types of sync markers.
public enum SyncMarkerType: String, Codable, Sendable {
    case clap       // Hand clap
    case slate      // Clapperboard
    case flash      // Camera flash
    case beep       // Audio tone
    case visual     // Visual cue
    case custom     // User-defined
}
