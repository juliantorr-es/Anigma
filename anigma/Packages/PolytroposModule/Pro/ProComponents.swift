import AnigmaPrimitives

import AnigmaPrimitives

//
//  ProComponents.swift
//  PolytroposModule
//
//  Professional editing components for Polytropos Pro v1.
//  Covers: multi-track timeline, manual editing, color grading, audio processing.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Multi-Track Timeline

/// Extended timeline with multiple video and audio tracks for professional editing.
public struct MultiTrackTimelineComponent: Component, Codable {
    /// Timeline entity reference.
    public var timelineId: EntityId

    /// Video tracks (bottom to top layer order).
    public var videoTracks: [VideoTrack]

    /// Audio tracks.
    public var audioTracks: [AudioTrack]

    /// Master audio settings.
    public var masterAudio: MasterAudioSettings

    /// Timeline markers.
    public var markers: [TimelineMarker]

    /// Playhead position.
    public var playheadPosition: TimeInterval

    /// In/out points for selection.
    public var inPoint: TimeInterval?
    public var outPoint: TimeInterval?

    /// Snap settings.
    public var snapSettings: SnapSettings

    public init(
        timelineId: EntityId,
        videoTracks: [VideoTrack] = [],
        audioTracks: [AudioTrack] = [],
        masterAudio: MasterAudioSettings = .init(),
        markers: [TimelineMarker] = [],
        playheadPosition: TimeInterval = 0,
        inPoint: TimeInterval? = nil,
        outPoint: TimeInterval? = nil,
        snapSettings: SnapSettings = .init()
    ) {
        self.timelineId = timelineId
        self.videoTracks = videoTracks
        self.audioTracks = audioTracks
        self.masterAudio = masterAudio
        self.markers = markers
        self.playheadPosition = playheadPosition
        self.inPoint = inPoint
        self.outPoint = outPoint
        self.snapSettings = snapSettings
    }
}

/// A video track in the timeline.
public struct VideoTrack: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var segments: [ProClipSegment]
    public var isVisible: Bool
    public var isLocked: Bool
    public var blendMode: BlendMode
    public var opacity: Double

    public init(
        id: UUID = UUID(),
        name: String = "V1",
        segments: [ProClipSegment] = [],
        isVisible: Bool = true,
        isLocked: Bool = false,
        blendMode: BlendMode = .normal,
        opacity: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.segments = segments
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.blendMode = blendMode
        self.opacity = opacity
    }
}

/// An audio track in the timeline.
public struct AudioTrack: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var segments: [ProAudioSegment]
    public var isMuted: Bool
    public var isSolo: Bool
    public var isLocked: Bool
    public var volume: Double
    public var pan: Double // -1.0 (left) to 1.0 (right)
    public var routingBus: AudioBusType

    public init(
        id: UUID = UUID(),
        name: String = "A1",
        segments: [ProAudioSegment] = [],
        isMuted: Bool = false,
        isSolo: Bool = false,
        isLocked: Bool = false,
        volume: Double = 1.0,
        pan: Double = 0.0,
        routingBus: AudioBusType = .master
    ) {
        self.id = id
        self.name = name
        self.segments = segments
        self.isMuted = isMuted
        self.isSolo = isSolo
        self.isLocked = isLocked
        self.volume = volume
        self.pan = pan
        self.routingBus = routingBus
    }
}

/// Extended clip segment with professional features.
public struct ProClipSegment: Codable, Sendable, Identifiable {
    public let id: UUID

    /// Source asset reference.
    public var sourceAssetId: EntityId

    /// Source timing.
    public var sourceIn: TimeInterval
    public var sourceOut: TimeInterval

    /// Timeline timing.
    public var timelineIn: TimeInterval
    public var timelineDuration: TimeInterval

    /// Transform properties.
    public var transform: ClipTransform

    /// Speed/time properties.
    public var speed: Double
    public var reversePlayback: Bool

    /// Visual properties.
    public var opacity: Double
    public var blendMode: BlendMode

    /// Color grade reference (nil = no grade).
    public var colorGradeId: UUID?

    /// Linked audio segment ID (for A/V sync).
    public var linkedAudioId: UUID?

    /// Editing state.
    public var isSelected: Bool
    public var isLocked: Bool

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
        transform: ClipTransform = .identity,
        speed: Double = 1.0,
        reversePlayback: Bool = false,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal,
        colorGradeId: UUID? = nil,
        linkedAudioId: UUID? = nil,
        isSelected: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.sourceAssetId = sourceAssetId
        self.sourceIn = sourceIn
        self.sourceOut = sourceOut
        self.timelineIn = timelineIn
        self.timelineDuration = timelineDuration ?? (sourceOut - sourceIn)
        self.transform = transform
        self.speed = speed
        self.reversePlayback = reversePlayback
        self.opacity = opacity
        self.blendMode = blendMode
        self.colorGradeId = colorGradeId
        self.linkedAudioId = linkedAudioId
        self.isSelected = isSelected
        self.isLocked = isLocked
    }
}

/// Audio segment with professional audio features.
public struct ProAudioSegment: Codable, Sendable, Identifiable {
    public let id: UUID

    /// Source asset reference.
    public var sourceAssetId: EntityId

    /// Source timing.
    public var sourceIn: TimeInterval
    public var sourceOut: TimeInterval

    /// Timeline timing.
    public var timelineIn: TimeInterval
    public var timelineDuration: TimeInterval

    /// Audio properties.
    public var volume: Double
    public var pan: Double
    public var fadeIn: FadeDefinition?
    public var fadeOut: FadeDefinition?

    /// Volume automation keyframes.
    public var volumeAutomation: [AutomationKeyframe]

    /// Audio processing chain ID.
    public var audioProcessingId: UUID?

    /// Linked video segment ID.
    public var linkedVideoId: UUID?

    /// Editing state.
    public var isMuted: Bool
    public var isSelected: Bool
    public var isLocked: Bool

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
        volume: Double = 1.0,
        pan: Double = 0.0,
        fadeIn: FadeDefinition? = nil,
        fadeOut: FadeDefinition? = nil,
        volumeAutomation: [AutomationKeyframe] = [],
        audioProcessingId: UUID? = nil,
        linkedVideoId: UUID? = nil,
        isMuted: Bool = false,
        isSelected: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.sourceAssetId = sourceAssetId
        self.sourceIn = sourceIn
        self.sourceOut = sourceOut
        self.timelineIn = timelineIn
        self.timelineDuration = timelineDuration ?? (sourceOut - sourceIn)
        self.volume = volume
        self.pan = pan
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.volumeAutomation = volumeAutomation
        self.audioProcessingId = audioProcessingId
        self.linkedVideoId = linkedVideoId
        self.isMuted = isMuted
        self.isSelected = isSelected
        self.isLocked = isLocked
    }
}

// MARK: - Transform & Animation

/// Clip transform properties.
public struct ClipTransform: Codable, Sendable {
    /// Position offset (normalized -1 to 1).
    public var positionX: Double
    public var positionY: Double

    /// Scale (1.0 = 100%).
    public var scaleX: Double
    public var scaleY: Double
    public var uniformScale: Bool

    /// Rotation in degrees.
    public var rotation: Double

    /// Anchor point (normalized 0-1).
    public var anchorX: Double
    public var anchorY: Double

    /// Keyframes for animated transform.
    public var keyframes: [TransformKeyframe]

    public static let identity = ClipTransform()

    public init(
        positionX: Double = 0,
        positionY: Double = 0,
        scaleX: Double = 1.0,
        scaleY: Double = 1.0,
        uniformScale: Bool = true,
        rotation: Double = 0,
        anchorX: Double = 0.5,
        anchorY: Double = 0.5,
        keyframes: [TransformKeyframe] = []
    ) {
        self.positionX = positionX
        self.positionY = positionY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.uniformScale = uniformScale
        self.rotation = rotation
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.keyframes = keyframes
    }
}

/// Transform keyframe for animation.
public struct TransformKeyframe: Codable, Sendable, Identifiable {
    public let id: UUID
    public var time: TimeInterval
    public var positionX: Double
    public var positionY: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotation: Double
    public var easing: EasingCurve

    public init(
        id: UUID = UUID(),
        time: TimeInterval,
        positionX: Double = 0,
        positionY: Double = 0,
        scaleX: Double = 1.0,
        scaleY: Double = 1.0,
        rotation: Double = 0,
        easing: EasingCurve = .linear
    ) {
        self.id = id
        self.time = time
        self.positionX = positionX
        self.positionY = positionY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotation = rotation
        self.easing = easing
    }
}

/// Automation keyframe for audio volume/pan.
public struct AutomationKeyframe: Codable, Sendable, Identifiable {
    public let id: UUID
    public var time: TimeInterval
    public var value: Double
    public var easing: EasingCurve

    public init(
        id: UUID = UUID(),
        time: TimeInterval,
        value: Double,
        easing: EasingCurve = .linear
    ) {
        self.id = id
        self.time = time
        self.value = value
        self.easing = easing
    }
}

/// Easing curves for animation.
public enum EasingCurve: String, Codable, Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case bezier
    case hold // Step function
}

/// Fade definition.
public struct FadeDefinition: Codable, Sendable {
    public var duration: TimeInterval
    public var curve: EasingCurve

    public init(duration: TimeInterval, curve: EasingCurve = .linear) {
        self.duration = duration
        self.curve = curve
    }
}

// MARK: - Blend Modes

/// Video blend modes.
public enum BlendMode: String, Codable, Sendable {
    case normal
    case multiply
    case screen
    case overlay
    case softLight
    case hardLight
    case colorDodge
    case colorBurn
    case difference
    case exclusion
    case hue
    case saturation
    case color
    case luminosity
}

// MARK: - Audio Bus Types

/// Audio routing bus types.
public enum AudioBusType: String, Codable, Sendable {
    case master
    case dialog
    case music
    case effects
    case submix1
    case submix2
}

// MARK: - Master Audio Settings

/// Master audio output settings.
public struct MasterAudioSettings: Codable, Sendable {
    public var volume: Double
    public var loudnessTarget: LoudnessTarget
    public var limiterEnabled: Bool
    public var limiterThreshold: Double

    public init(
        volume: Double = 1.0,
        loudnessTarget: LoudnessTarget = .streaming,
        limiterEnabled: Bool = true,
        limiterThreshold: Double = -1.0
    ) {
        self.volume = volume
        self.loudnessTarget = loudnessTarget
        self.limiterEnabled = limiterEnabled
        self.limiterThreshold = limiterThreshold
    }
}

/// Loudness normalization targets.
public enum LoudnessTarget: String, Codable, Sendable {
    case streaming     // -14 LUFS (YouTube, Spotify)
    case broadcast     // -24 LUFS (TV/Radio)
    case theatrical    // -27 LUFS (Cinema)
    case podcast       // -16 LUFS
    case none          // No normalization

    public var lufs: Double {
        switch self {
        case .streaming: return -14.0
        case .broadcast: return -24.0
        case .theatrical: return -27.0
        case .podcast: return -16.0
        case .none: return 0.0
        }
    }
}

// MARK: - Timeline Markers

/// Timeline marker for navigation and notes.
public struct TimelineMarker: Codable, Sendable, Identifiable {
    public let id: UUID
    public var time: TimeInterval
    public var name: String
    public var color: MarkerColor
    public var markerType: MarkerType
    public var notes: String?

    public init(
        id: UUID = UUID(),
        time: TimeInterval,
        name: String,
        color: MarkerColor = .blue,
        markerType: MarkerType = .standard,
        notes: String? = nil
    ) {
        self.id = id
        self.time = time
        self.name = name
        self.color = color
        self.markerType = markerType
        self.notes = notes
    }
}

/// Marker colors.
public enum MarkerColor: String, Codable, Sendable {
    case red, orange, yellow, green, cyan, blue, purple, pink, white, gray
}

/// Marker types.
public enum MarkerType: String, Codable, Sendable {
    case standard
    case chapter        // For chapter markers in export
    case todo           // Work to be done
    case review         // Needs review
    case approved       // Approved content
}

// MARK: - Snap Settings

/// Timeline snap/magnet behavior settings.
public struct SnapSettings: Codable, Sendable {
    public var enabled: Bool
    public var snapToPlayhead: Bool
    public var snapToClipEdges: Bool
    public var snapToMarkers: Bool
    public var snapToBeats: Bool
    public var magnetStrength: Double // 0-1

    public init(
        enabled: Bool = true,
        snapToPlayhead: Bool = true,
        snapToClipEdges: Bool = true,
        snapToMarkers: Bool = true,
        snapToBeats: Bool = false,
        magnetStrength: Double = 0.5
    ) {
        self.enabled = enabled
        self.snapToPlayhead = snapToPlayhead
        self.snapToClipEdges = snapToClipEdges
        self.snapToMarkers = snapToMarkers
        self.snapToBeats = snapToBeats
        self.magnetStrength = magnetStrength
    }
}

// MARK: - Undo/Redo History

/// Edit history for undo/redo.
public struct EditHistoryComponent: Component, Codable {
    /// Timeline entity reference.
    public var timelineId: EntityId

    /// Undo stack.
    public var undoStack: [EditAction]

    /// Redo stack.
    public var redoStack: [EditAction]

    /// Maximum history depth.
    public var maxHistoryDepth: Int

    /// Last saved action index.
    public var lastSavedIndex: Int

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var hasUnsavedChanges: Bool { undoStack.count != lastSavedIndex }

    public init(
        timelineId: EntityId,
        undoStack: [EditAction] = [],
        redoStack: [EditAction] = [],
        maxHistoryDepth: Int = 100,
        lastSavedIndex: Int = 0
    ) {
        self.timelineId = timelineId
        self.undoStack = undoStack
        self.redoStack = redoStack
        self.maxHistoryDepth = maxHistoryDepth
        self.lastSavedIndex = lastSavedIndex
    }
}

/// A single edit action that can be undone/redone.
public struct EditAction: Codable, Sendable, Identifiable {
    public let id: UUID
    public var actionType: EditActionType
    public var description: String
    public var timestamp: Date
    public var affectedSegmentIds: [UUID]
    public var previousState: Data? // Serialized previous state
    public var newState: Data?      // Serialized new state

    public init(
        id: UUID = UUID(),
        actionType: EditActionType,
        description: String,
        timestamp: Date = Date(),
        affectedSegmentIds: [UUID] = [],
        previousState: Data? = nil,
        newState: Data? = nil
    ) {
        self.id = id
        self.actionType = actionType
        self.description = description
        self.timestamp = timestamp
        self.affectedSegmentIds = affectedSegmentIds
        self.previousState = previousState
        self.newState = newState
    }
}

/// Types of edit actions.
public enum EditActionType: String, Codable, Sendable {
    // Clip operations
    case addClip
    case removeClip
    case moveClip
    case trimClipStart
    case trimClipEnd
    case splitClip
    case joinClips

    // Track operations
    case addTrack
    case removeTrack
    case reorderTracks

    // Property changes
    case changeSpeed
    case changeVolume
    case changeOpacity
    case changeTransform
    case changeBlendMode

    // Transitions
    case addTransition
    case removeTransition
    case changeTransition

    // Color
    case applyColorGrade
    case removeColorGrade
    case modifyColorGrade

    // Audio
    case applyAudioEffect
    case removeAudioEffect
    case modifyAudioEffect

    // Compound
    case rippleEdit
    case slipEdit
    case slideEdit
    case rollEdit

    // Markers
    case addMarker
    case removeMarker
    case moveMarker
}

// MARK: - Proxy Media

/// Proxy media settings for performance.
public struct ProxySettingsComponent: Component, Codable {
    /// Project entity reference.
    public var projectId: EntityId

    /// Whether to use proxies during editing.
    public var useProxiesForEditing: Bool

    /// Proxy resolution.
    public var proxyResolution: ProxyResolution

    /// Proxy codec.
    public var proxyCodec: ProxyCodec

    /// Proxy generation status.
    public var generationStatus: ProxyGenerationStatus

    /// Percentage of proxies generated.
    public var generationProgress: Double

    public init(
        projectId: EntityId,
        useProxiesForEditing: Bool = true,
        proxyResolution: ProxyResolution = .quarter,
        proxyCodec: ProxyCodec = .h264,
        generationStatus: ProxyGenerationStatus = .notStarted,
        generationProgress: Double = 0
    ) {
        self.projectId = projectId
        self.useProxiesForEditing = useProxiesForEditing
        self.proxyResolution = proxyResolution
        self.proxyCodec = proxyCodec
        self.generationStatus = generationStatus
        self.generationProgress = generationProgress
    }
}

/// Proxy resolution options.
public enum ProxyResolution: String, Codable, Sendable {
    case half       // 1/2 resolution
    case quarter    // 1/4 resolution
    case eighth     // 1/8 resolution

    public var scale: Double {
        switch self {
        case .half: return 0.5
        case .quarter: return 0.25
        case .eighth: return 0.125
        }
    }
}

/// Proxy codec options.
public enum ProxyCodec: String, Codable, Sendable {
    case h264
    case hevc
    case proresProxy
}

/// Proxy generation status.
public enum ProxyGenerationStatus: String, Codable, Sendable {
    case notStarted
    case generating
    case completed
    case failed
    case partial
}

// MARK: - Media Relink

/// Missing media tracking for relink.
public struct MediaRelinkComponent: Component, Codable {
    /// Project entity reference.
    public var projectId: EntityId

    /// Missing media entries.
    public var missingMedia: [MissingMediaEntry]

    /// Relink mapping (old path -> new path).
    public var relinkMapping: [String: String]

    public var hasMissingMedia: Bool { !missingMedia.isEmpty }

    public init(
        projectId: EntityId,
        missingMedia: [MissingMediaEntry] = [],
        relinkMapping: [String: String] = [:]
    ) {
        self.projectId = projectId
        self.missingMedia = missingMedia
        self.relinkMapping = relinkMapping
    }
}

/// Entry for missing media.
public struct MissingMediaEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public var assetId: EntityId
    public var originalPath: String
    public var lastKnownName: String
    public var mediaType: MediaType
    public var usageCount: Int // How many clips reference this

    public init(
        id: UUID = UUID(),
        assetId: EntityId,
        originalPath: String,
        lastKnownName: String,
        mediaType: MediaType,
        usageCount: Int
    ) {
        self.id = id
        self.assetId = assetId
        self.originalPath = originalPath
        self.lastKnownName = lastKnownName
        self.mediaType = mediaType
        self.usageCount = usageCount
    }
}
