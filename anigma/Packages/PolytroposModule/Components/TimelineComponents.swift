//
//  TimelineComponents.swift
//  PolytroposModule
//
//  Components for timelines, clips, and scenes.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives

// MARK: - Timeline Component

/// A sequence of clip segments defining the program.
public struct TimelineComponent: Component, Codable {
    /// Unique timeline identifier.
    public let id: UUID

    /// Human-readable timeline name.
    public var name: String

    /// Source cluster ID.
    public var sourceClusterId: UUID?

    /// Timeline duration.
    public var duration: TimeInterval

    /// Timeline status.
    public var status: TimelineStatus

    /// Frame rate for the timeline.
    public var frameRate: Double

    /// Target aspect ratio.
    public var aspectRatio: AspectRatio

    /// Whether this is the primary timeline for export.
    public var isPrimary: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        sourceClusterId: UUID? = nil,
        duration: TimeInterval = 0,
        status: TimelineStatus = .draft,
        frameRate: Double = 30,
        aspectRatio: AspectRatio = .horizontal16x9,
        isPrimary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sourceClusterId = sourceClusterId
        self.duration = duration
        self.status = status
        self.frameRate = frameRate
        self.aspectRatio = aspectRatio
        self.isPrimary = isPrimary
    }
}

/// Timeline status.
public enum TimelineStatus: String, Codable, Sendable {
    case draft
    case autoEdited
    case reviewed
    case approved
    case exported
}

/// Common aspect ratios.
public enum AspectRatio: String, Codable, Sendable {
    case horizontal16x9   // 1.778:1 - YouTube
    case horizontal4x3    // 1.333:1 - Classic
    case vertical9x16     // 0.5625:1 - TikTok/Reels/Shorts
    case vertical4x5      // 0.8:1 - Instagram
    case square1x1        // 1:1 - Instagram legacy
    case cinema21x9       // 2.333:1 - Cinematic

    public var ratio: Double {
        switch self {
        case .horizontal16x9: return 16.0 / 9.0
        case .horizontal4x3: return 4.0 / 3.0
        case .vertical9x16: return 9.0 / 16.0
        case .vertical4x5: return 4.0 / 5.0
        case .square1x1: return 1.0
        case .cinema21x9: return 21.0 / 9.0
        }
    }

    public var isVertical: Bool {
        ratio < 1.0
    }
}

// MARK: - Timeline Tracks Component

/// Track structure for a timeline.
public struct TimelineTracksComponent: Component, Codable {
    /// Primary video track segments.
    public var videoSegments: [ClipSegment]

    /// Primary audio track segments.
    public var audioSegments: [ClipSegment]

    /// Overlay track segments (graphics, titles).
    public var overlaySegments: [OverlaySegment]

    /// Transition definitions.
    public var transitions: [TransitionDefinition]

    public init(
        videoSegments: [ClipSegment] = [],
        audioSegments: [ClipSegment] = [],
        overlaySegments: [OverlaySegment] = [],
        transitions: [TransitionDefinition] = []
    ) {
        self.videoSegments = videoSegments
        self.audioSegments = audioSegments
        self.overlaySegments = overlaySegments
        self.transitions = transitions
    }
}

/// A single clip segment in the timeline.
public struct ClipSegment: Codable, Sendable, Identifiable {
    public let id: UUID

    /// Source asset entity ID.
    public var sourceAssetId: EntityId

    /// Start time in source asset.
    public var sourceIn: TimeInterval

    /// End time in source asset.
    public var sourceOut: TimeInterval

    /// Start time in timeline.
    public var timelineIn: TimeInterval

    /// Duration in timeline (may differ from source if speed adjusted).
    public var timelineDuration: TimeInterval

    /// Speed multiplier (1.0 = normal).
    public var speed: Double

    /// Volume adjustment (1.0 = normal).
    public var volume: Double

    /// Opacity (1.0 = fully visible).
    public var opacity: Double

    /// Whether this segment is muted.
    public var isMuted: Bool

    /// Whether this segment is locked from editing.
    public var isLocked: Bool

    /// Source duration.
    public var sourceDuration: TimeInterval {
        sourceOut - sourceIn
    }

    /// Timeline end time.
    public var timelineOut: TimeInterval {
        timelineIn + timelineDuration
    }

    public init(
        id: UUID = UUID(),
        sourceAssetId: EntityId,
        sourceIn: TimeInterval,
        sourceOut: TimeInterval,
        timelineIn: TimeInterval,
        timelineDuration: TimeInterval? = nil,
        speed: Double = 1.0,
        volume: Double = 1.0,
        opacity: Double = 1.0,
        isMuted: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.sourceAssetId = sourceAssetId
        self.sourceIn = sourceIn
        self.sourceOut = sourceOut
        self.timelineIn = timelineIn
        self.timelineDuration = timelineDuration ?? (sourceOut - sourceIn)
        self.speed = speed
        self.volume = volume
        self.opacity = opacity
        self.isMuted = isMuted
        self.isLocked = isLocked
    }
}

/// An overlay segment (graphics, titles).
public struct OverlaySegment: Codable, Sendable, Identifiable {
    public let id: UUID

    /// Overlay type.
    public var overlayType: OverlayType

    /// Start time in timeline.
    public var timelineIn: TimeInterval

    /// Duration in timeline.
    public var duration: TimeInterval

    /// Position (normalized 0-1).
    public var position: NormalizedRect

    /// Opacity.
    public var opacity: Double

    /// Content reference or inline data.
    public var content: OverlayContent

    /// Animation preset.
    public var animation: OverlayAnimation

    public init(
        id: UUID = UUID(),
        overlayType: OverlayType,
        timelineIn: TimeInterval,
        duration: TimeInterval,
        position: NormalizedRect,
        opacity: Double = 1.0,
        content: OverlayContent,
        animation: OverlayAnimation = .none
    ) {
        self.id = id
        self.overlayType = overlayType
        self.timelineIn = timelineIn
        self.duration = duration
        self.position = position
        self.opacity = opacity
        self.content = content
        self.animation = animation
    }
}

/// Type of overlay.
public enum OverlayType: String, Codable, Sendable {
    case lowerThird
    case title
    case watermark
    case logo
    case caption
    case custom
}

/// Overlay content.
public struct OverlayContent: Codable, Sendable {
    /// Text content (if applicable).
    public var text: String?

    /// Image asset path (if applicable).
    public var imagePath: String?

    /// Template ID (if using branding template).
    public var templateId: String?

    /// Dynamic fields for template.
    public var fields: [String: String]

    public init(
        text: String? = nil,
        imagePath: String? = nil,
        templateId: String? = nil,
        fields: [String: String] = [:]
    ) {
        self.text = text
        self.imagePath = imagePath
        self.templateId = templateId
        self.fields = fields
    }
}

/// Overlay animation preset.
public enum OverlayAnimation: String, Codable, Sendable {
    case none
    case fadeIn
    case fadeOut
    case fadeInOut
    case slideIn
    case slideOut
    case pop
    case typewriter
}

/// Transition between clips.
public struct TransitionDefinition: Codable, Sendable, Identifiable {
    public let id: UUID

    /// Position in timeline where transition occurs.
    public var timelinePosition: TimeInterval

    /// Transition type.
    public var transitionType: TransitionType

    /// Duration of transition.
    public var duration: TimeInterval

    public init(
        id: UUID = UUID(),
        timelinePosition: TimeInterval,
        transitionType: TransitionType = .cut,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.timelinePosition = timelinePosition
        self.transitionType = transitionType
        self.duration = duration
    }
}

/// Transition types.
public enum TransitionType: String, Codable, Sendable {
    case cut
    case crossDissolve
    case dip
    case wipe
    case push
}

// MARK: - Scene Component

/// A semantically meaningful chunk of the timeline.
public struct SceneComponent: Component, Codable {
    /// Unique scene identifier.
    public let id: UUID

    /// Human-readable scene name.
    public var name: String

    /// Scene type.
    public var sceneType: PolytroposSceneType

    /// Time range in the source cluster.
    public var sourceRange: TimeRange

    /// Timeline entity ID (if scene has its own timeline).
    public var timelineId: EntityId?

    /// Scene status.
    public var status: SceneStatus

    /// User rating (0-5 stars, nil = unrated).
    public var userRating: Int?

    /// Tags for organization.
    public var tags: [String]

    /// Whether this scene is marked for export.
    public var includeInExport: Bool

    /// Notes from user.
    public var notes: String?

    public init(
        id: UUID = UUID(),
        name: String,
        sceneType: PolytroposSceneType = .unknown,
        sourceRange: TimeRange,
        timelineId: EntityId? = nil,
        status: SceneStatus = .detected,
        userRating: Int? = nil,
        tags: [String] = [],
        includeInExport: Bool = true,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sceneType = sceneType
        self.sourceRange = sourceRange
        self.timelineId = timelineId
        self.status = status
        self.userRating = userRating
        self.tags = tags
        self.includeInExport = includeInExport
        self.notes = notes
    }
}

/// Scene types matching event content.
public enum PolytroposSceneType: String, Codable, Sendable {
    case song
    case bit           // Comedy bit or segment
    case number        // Dance/performance number
    case speech        // Talk/speech
    case qa            // Q&A session
    case intro
    case outro
    case transition
    case unknown
}

/// Scene processing/review status.
public enum SceneStatus: String, Codable, Sendable {
    case detected       // Auto-detected, not reviewed
    case needsWork      // User marked for revision
    case approved       // User approved
    case discarded      // User chose not to use
    case exported       // Successfully exported
}
