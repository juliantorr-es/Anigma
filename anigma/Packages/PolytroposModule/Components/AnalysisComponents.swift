import AnigmaPrimitives

import AnigmaPrimitives

//
//  AnalysisComponents.swift
//  PolytroposModule
//
//  Components for audio and video analysis features.
//

import AnigmaCore
import Foundation

// MARK: - Audio Analysis Component

/// Audio feature analysis results.
public struct AudioAnalysisComponent: Component, Codable {
    /// Detected tempo in BPM.
    public var tempo: Double?

    /// Beat onset times in seconds.
    public var beatOnsets: [TimeInterval]

    /// Structural segments (intro, verse, chorus, etc.).
    public var structuralSegments: [AudioSegment]

    /// Energy curve (RMS over time).
    public var energyCurve: [Float]

    /// Samples per second for energy curve.
    public var energySamplesPerSecond: Int

    /// Applause detection intervals.
    public var applauseIntervals: [TimeRange]

    /// Speech vs music classification per segment.
    public var contentClassification: [ContentSegment]

    /// Overall audio quality assessment.
    public var qualityAssessment: AudioQualityAssessment?

    public init(
        tempo: Double? = nil,
        beatOnsets: [TimeInterval] = [],
        structuralSegments: [AudioSegment] = [],
        energyCurve: [Float] = [],
        energySamplesPerSecond: Int = 10,
        applauseIntervals: [TimeRange] = [],
        contentClassification: [ContentSegment] = [],
        qualityAssessment: AudioQualityAssessment? = nil
    ) {
        self.tempo = tempo
        self.beatOnsets = beatOnsets
        self.structuralSegments = structuralSegments
        self.energyCurve = energyCurve
        self.energySamplesPerSecond = energySamplesPerSecond
        self.applauseIntervals = applauseIntervals
        self.contentClassification = contentClassification
        self.qualityAssessment = qualityAssessment
    }
}

/// A time range.
public struct TimeRange: Codable, Sendable, Equatable {
    public var start: TimeInterval
    public var end: TimeInterval

    public var duration: TimeInterval {
        end - start
    }

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }

    public func contains(_ time: TimeInterval) -> Bool {
        time >= start && time <= end
    }

    public func overlaps(_ other: TimeRange) -> Bool {
        start < other.end && end > other.start
    }
}

/// A structural segment in audio (verse, chorus, etc.).
public struct AudioSegment: Codable, Sendable {
    public var range: TimeRange
    public var segmentType: AudioSegmentType
    public var confidence: Double
    public var label: String?

    public init(
        range: TimeRange,
        segmentType: AudioSegmentType,
        confidence: Double = 0.5,
        label: String? = nil
    ) {
        self.range = range
        self.segmentType = segmentType
        self.confidence = confidence
        self.label = label
    }
}

/// Types of structural audio segments.
public enum AudioSegmentType: String, Codable, Sendable {
    case intro
    case verse
    case preChorus
    case chorus
    case bridge
    case solo
    case breakdown
    case buildup
    case drop
    case outro
    case applause
    case silence
    case speech
    case unknown
}

/// Content type classification.
public struct ContentSegment: Codable, Sendable {
    public var range: TimeRange
    public var contentType: ContentType
    public var confidence: Double

    public init(range: TimeRange, contentType: ContentType, confidence: Double = 0.5) {
        self.range = range
        self.contentType = contentType
        self.confidence = confidence
    }
}

/// Audio content classification.
public enum ContentType: String, Codable, Sendable {
    case music
    case speech
    case applause
    case ambient
    case silence
    case mixed
}

/// Audio quality assessment.
public struct AudioQualityAssessment: Codable, Sendable {
    public var overallScore: Double        // 0-1
    public var hasClipping: Bool
    public var noiseFloor: Double          // dB
    public var dynamicRange: Double        // dB
    public var consistentLevels: Bool

    public init(
        overallScore: Double,
        hasClipping: Bool = false,
        noiseFloor: Double = -60,
        dynamicRange: Double = 40,
        consistentLevels: Bool = true
    ) {
        self.overallScore = overallScore
        self.hasClipping = hasClipping
        self.noiseFloor = noiseFloor
        self.dynamicRange = dynamicRange
        self.consistentLevels = consistentLevels
    }
}

// MARK: - Video Analysis Component

/// Video feature analysis results.
public struct VideoAnalysisComponent: Component, Codable {
    /// Per-frame or per-window analysis data.
    public var frameAnalysis: [FrameAnalysis]

    /// Analysis window size in seconds.
    public var windowSizeSeconds: TimeInterval

    /// Detected shot boundaries.
    public var shotBoundaries: [TimeInterval]

    /// Subject/face detection results.
    public var subjectDetections: [SubjectDetection]

    /// Overall video quality assessment.
    public var qualityAssessment: VideoQualityAssessment?

    public init(
        frameAnalysis: [FrameAnalysis] = [],
        windowSizeSeconds: TimeInterval = 0.5,
        shotBoundaries: [TimeInterval] = [],
        subjectDetections: [SubjectDetection] = [],
        qualityAssessment: VideoQualityAssessment? = nil
    ) {
        self.frameAnalysis = frameAnalysis
        self.windowSizeSeconds = windowSizeSeconds
        self.shotBoundaries = shotBoundaries
        self.subjectDetections = subjectDetections
        self.qualityAssessment = qualityAssessment
    }
}

/// Analysis of a video frame or window.
public struct FrameAnalysis: Codable, Sendable {
    /// Time in video.
    public var time: TimeInterval

    /// Sharpness score (0-1).
    public var sharpness: Float

    /// Motion/stability score (0=stable, 1=very shaky).
    public var motionMagnitude: Float

    /// Exposure score (0=dark, 0.5=good, 1=bright).
    public var exposure: Float

    /// Contrast score (0-1).
    public var contrast: Float

    /// Saturation score (0-1).
    public var saturation: Float

    /// Number of faces/subjects detected.
    public var subjectCount: Int

    /// Primary subject bounding box (normalized 0-1).
    public var primarySubjectRect: NormalizedRect?

    /// Scene classification.
    public var frameSceneType: FrameSceneType

    /// Composite quality score.
    public var qualityScore: Float {
        let sharpnessWeight: Float = 0.3
        let stabilityWeight: Float = 0.25
        let exposureWeight: Float = 0.25
        let contrastWeight: Float = 0.2

        let stabilityScore = 1.0 - min(motionMagnitude, 1.0)
        let exposureScore = 1.0 - abs(exposure - 0.5) * 2

        return (sharpness * sharpnessWeight) +
               (stabilityScore * stabilityWeight) +
               (exposureScore * exposureWeight) +
               (contrast * contrastWeight)
    }

    public init(
        time: TimeInterval,
        sharpness: Float = 0.5,
        motionMagnitude: Float = 0,
        exposure: Float = 0.5,
        contrast: Float = 0.5,
        saturation: Float = 0.5,
        subjectCount: Int = 0,
        primarySubjectRect: NormalizedRect? = nil,
        frameSceneType: FrameSceneType = .unknown
    ) {
        self.time = time
        self.sharpness = sharpness
        self.motionMagnitude = motionMagnitude
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.subjectCount = subjectCount
        self.primarySubjectRect = primarySubjectRect
        self.frameSceneType = frameSceneType
    }
}

/// Normalized rectangle (0-1 coordinates).
public struct NormalizedRect: Codable, Sendable {
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float

    public var centerX: Float { x + width / 2 }
    public var centerY: Float { y + height / 2 }

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Scene type classification for frames.
public enum FrameSceneType: String, Codable, Sendable {
    case stage
    case crowd
    case closeup
    case wide
    case backstage
    case outdoor
    case indoor
    case unknown
}

/// Subject detection result.
public struct SubjectDetection: Codable, Sendable {
    public var range: TimeRange
    public var boundingBox: NormalizedRect
    public var subjectType: SubjectType
    public var confidence: Double
    public var trackingId: UUID?

    public init(
        range: TimeRange,
        boundingBox: NormalizedRect,
        subjectType: SubjectType = .person,
        confidence: Double = 0.5,
        trackingId: UUID? = nil
    ) {
        self.range = range
        self.boundingBox = boundingBox
        self.subjectType = subjectType
        self.confidence = confidence
        self.trackingId = trackingId
    }
}

/// Type of detected subject.
public enum SubjectType: String, Codable, Sendable {
    case person
    case face
    case instrument
    case screen
    case object
    case unknown
}

/// Video quality assessment.
public struct VideoQualityAssessment: Codable, Sendable {
    public var overallScore: Double          // 0-1
    public var averageSharpness: Double      // 0-1
    public var stabilityScore: Double        // 0-1
    public var exposureConsistency: Double   // 0-1
    public var usablePercentage: Double      // 0-1

    public init(
        overallScore: Double,
        averageSharpness: Double = 0.5,
        stabilityScore: Double = 0.5,
        exposureConsistency: Double = 0.5,
        usablePercentage: Double = 1.0
    ) {
        self.overallScore = overallScore
        self.averageSharpness = averageSharpness
        self.stabilityScore = stabilityScore
        self.exposureConsistency = exposureConsistency
        self.usablePercentage = usablePercentage
    }
}

// MARK: - Scene Boundary Component

/// Detected scene boundaries for auto-segmentation.
public struct SceneBoundaryComponent: Component, Codable {
    /// Detected scene boundaries.
    public var boundaries: [SceneBoundary]

    public init(boundaries: [SceneBoundary] = []) {
        self.boundaries = boundaries
    }
}

/// A single scene boundary.
public struct SceneBoundary: Codable, Sendable {
    public var time: TimeInterval
    public var boundaryType: SceneBoundaryType
    public var confidence: Double
    public var suggestedLabel: String?

    public init(
        time: TimeInterval,
        boundaryType: SceneBoundaryType,
        confidence: Double = 0.5,
        suggestedLabel: String? = nil
    ) {
        self.time = time
        self.boundaryType = boundaryType
        self.confidence = confidence
        self.suggestedLabel = suggestedLabel
    }
}

/// Type of scene boundary.
public enum SceneBoundaryType: String, Codable, Sendable {
    case songStart
    case songEnd
    case applause
    case silence
    case speakerChange
    case visualChange
    case manual
}
