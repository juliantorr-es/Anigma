import AnigmaPrimitives

import AnigmaPrimitives

//
//  ProjectComponents.swift
//  PolytroposModule
//
//  Top-level project and event management components.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives

// MARK: - Project Identifiers

/// Unique identifier for a Polytropos project.
public struct PolytroposProjectId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() {
        self.raw = UUID()
    }

    public init(raw: UUID) {
        self.raw = raw
    }

    public var description: String {
        "Project(\(raw.uuidString.prefix(8)))"
    }
}

// MARK: - Project Component

/// Top-level project containing all event data.
/// A project represents a single event or content project.
public struct ProjectComponent: Component, Codable {
    /// Unique project identifier.
    public let id: PolytroposProjectId

    /// Human-readable project name.
    public var name: String

    /// Event date (when the content was captured).
    public var eventDate: Date?

    /// Venue or location name.
    public var venue: String?

    /// Performer/artist names.
    public var performers: [String]

    /// Project creation timestamp.
    public let createdAt: Date

    /// Last modification timestamp.
    public var modifiedAt: Date

    /// Project status.
    public var status: ProjectStatus

    /// Associated branding profile ID.
    public var brandingProfileId: EntityId?

    /// Project-level metadata.
    public var metadata: [String: String]

    /// Tags for organization.
    public var tags: [String]

    public init(
        id: PolytroposProjectId = PolytroposProjectId(),
        name: String,
        eventDate: Date? = nil,
        venue: String? = nil,
        performers: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        status: ProjectStatus = .created,
        brandingProfileId: EntityId? = nil,
        metadata: [String: String] = [:],
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.eventDate = eventDate
        self.venue = venue
        self.performers = performers
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.status = status
        self.brandingProfileId = brandingProfileId
        self.metadata = metadata
        self.tags = tags
    }
}

/// Project lifecycle status.
public enum ProjectStatus: String, Codable, Sendable, CaseIterable {
    /// Just created, no media ingested.
    case created

    /// Media is being ingested.
    case ingesting

    /// Media ingested, analysis in progress.
    case analyzing

    /// Analysis complete, ready for review.
    case ready

    /// User is reviewing/editing.
    case editing

    /// Exports in progress.
    case exporting

    /// All work complete.
    case completed

    /// Project archived.
    case archived
}

// MARK: - Project References Component

/// Links a project to its child entities.
public struct ProjectReferencesComponent: Component, Codable {
    /// All media assets in this project.
    public var mediaAssetIds: [EntityId]

    /// All multicam clusters in this project.
    public var clusterIds: [EntityId]

    /// All timelines in this project.
    public var timelineIds: [EntityId]

    /// All export jobs for this project.
    public var exportJobIds: [EntityId]

    public init(
        mediaAssetIds: [EntityId] = [],
        clusterIds: [EntityId] = [],
        timelineIds: [EntityId] = [],
        exportJobIds: [EntityId] = []
    ) {
        self.mediaAssetIds = mediaAssetIds
        self.clusterIds = clusterIds
        self.timelineIds = timelineIds
        self.exportJobIds = exportJobIds
    }
}

// MARK: - Event Metadata Component

/// Rich metadata about the captured event.
public struct EventMetadataComponent: Component, Codable {
    /// Event type classification.
    public var eventType: EventType

    /// Approximate duration of the event.
    public var estimatedDuration: TimeInterval?

    /// Number of performers/participants.
    public var participantCount: Int?

    /// Social media handles for the event/performers.
    public var socialHandles: [String: String]

    /// Setlist or agenda items.
    public var setlistItems: [String]

    /// Special notes about the event.
    public var notes: String?

    public init(
        eventType: EventType = .general,
        estimatedDuration: TimeInterval? = nil,
        participantCount: Int? = nil,
        socialHandles: [String: String] = [:],
        setlistItems: [String] = [],
        notes: String? = nil
    ) {
        self.eventType = eventType
        self.estimatedDuration = estimatedDuration
        self.participantCount = participantCount
        self.socialHandles = socialHandles
        self.setlistItems = setlistItems
        self.notes = notes
    }
}

/// Classification of event types for auto-edit tuning.
public enum EventType: String, Codable, Sendable, CaseIterable {
    /// General/unclassified event.
    case general

    /// Live music performance.
    case concert

    /// DJ set / electronic music.
    case djSet

    /// Drag show / cabaret.
    case dragShow

    /// Theater / play / musical.
    case theater

    /// Stand-up comedy.
    case comedy

    /// Conference talk / keynote.
    case talk

    /// Panel discussion.
    case panel

    /// Workshop / teaching session.
    case workshop

    /// Religious service.
    case service

    /// Art performance / installation.
    case art

    /// Sports event.
    case sports

    /// Returns edit profile hints for this event type.
    public var editProfileHints: EditProfileHints {
        switch self {
        case .concert, .djSet:
            return EditProfileHints(
                preferredCutDensity: .high,
                beatAlignCuts: true,
                crowdShotsAllowed: true,
                applauseDetection: true
            )
        case .dragShow:
            return EditProfileHints(
                preferredCutDensity: .medium,
                beatAlignCuts: true,
                crowdShotsAllowed: true,
                applauseDetection: true
            )
        case .comedy:
            return EditProfileHints(
                preferredCutDensity: .low,
                beatAlignCuts: false,
                crowdShotsAllowed: true,
                applauseDetection: true
            )
        case .talk, .panel, .workshop:
            return EditProfileHints(
                preferredCutDensity: .low,
                beatAlignCuts: false,
                crowdShotsAllowed: false,
                applauseDetection: true
            )
        case .theater:
            return EditProfileHints(
                preferredCutDensity: .veryLow,
                beatAlignCuts: false,
                crowdShotsAllowed: false,
                applauseDetection: true
            )
        default:
            return EditProfileHints(
                preferredCutDensity: .medium,
                beatAlignCuts: false,
                crowdShotsAllowed: true,
                applauseDetection: true
            )
        }
    }
}

/// Hints for auto-edit behavior based on event type.
public struct EditProfileHints: Sendable {
    public let preferredCutDensity: CutDensity
    public let beatAlignCuts: Bool
    public let crowdShotsAllowed: Bool
    public let applauseDetection: Bool
}

/// Cut density preference for auto-editing.
public enum CutDensity: String, Codable, Sendable {
    case veryLow   // 8-15 seconds average
    case low       // 5-8 seconds average
    case medium    // 3-5 seconds average
    case high      // 1.5-3 seconds average
    case veryHigh  // 0.5-1.5 seconds average

    /// Target average shot length in seconds.
    public var targetShotLength: TimeInterval {
        switch self {
        case .veryLow: return 12.0
        case .low: return 6.5
        case .medium: return 4.0
        case .high: return 2.0
        case .veryHigh: return 1.0
        }
    }

    /// Minimum shot length in seconds.
    public var minimumShotLength: TimeInterval {
        switch self {
        case .veryLow: return 5.0
        case .low: return 3.0
        case .medium: return 1.5
        case .high: return 0.75
        case .veryHigh: return 0.33
        }
    }
}
