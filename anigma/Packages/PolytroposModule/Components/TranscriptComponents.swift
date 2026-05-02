import AnigmaPrimitives

import AnigmaPrimitives

//
//  TranscriptComponents.swift
//  PolytroposModule
//
//  Components for ASR transcripts and captions.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Transcript Component

/// ASR output with word-level timing.
public struct TranscriptComponent: Component, Codable {
    /// Unique transcript identifier.
    public let id: UUID

    /// Source asset entity ID.
    public var sourceAssetId: EntityId?

    /// Language code (e.g., "en", "es").
    public var languageCode: String

    /// Transcript segments.
    public var segments: [TranscriptSegment]

    /// Overall confidence score (0-1).
    public var confidence: Double

    /// Whether transcript has been human-reviewed.
    public var isReviewed: Bool

    /// ASR model used.
    public var asrModel: String?

    /// Transcript generation timestamp.
    public let generatedAt: Date

    /// Full text (derived from segments).
    public var fullText: String {
        segments.map { $0.text }.joined(separator: " ")
    }

    /// Total duration covered.
    public var duration: TimeInterval {
        guard let last = segments.last else { return 0 }
        return last.endTime
    }

    public init(
        id: UUID = UUID(),
        sourceAssetId: EntityId? = nil,
        languageCode: String = "en",
        segments: [TranscriptSegment] = [],
        confidence: Double = 0,
        isReviewed: Bool = false,
        asrModel: String? = nil,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceAssetId = sourceAssetId
        self.languageCode = languageCode
        self.segments = segments
        self.confidence = confidence
        self.isReviewed = isReviewed
        self.asrModel = asrModel
        self.generatedAt = generatedAt
    }
}

/// A segment of transcript (sentence or phrase).
public struct TranscriptSegment: Codable, Sendable, Identifiable {
    public let id: UUID

    /// Start time in seconds.
    public var startTime: TimeInterval

    /// End time in seconds.
    public var endTime: TimeInterval

    /// Segment text.
    public var text: String

    /// Word-level timing.
    public var words: [TranscriptWord]

    /// Speaker identifier (if diarization available).
    public var speakerId: String?

    /// Confidence score for this segment.
    public var confidence: Double

    /// Duration.
    public var duration: TimeInterval {
        endTime - startTime
    }

    public init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        words: [TranscriptWord] = [],
        speakerId: String? = nil,
        confidence: Double = 0.5
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.words = words
        self.speakerId = speakerId
        self.confidence = confidence
    }
}

/// A single word with timing.
public struct TranscriptWord: Codable, Sendable {
    /// The word text.
    public var word: String

    /// Start time in seconds.
    public var startTime: TimeInterval

    /// End time in seconds.
    public var endTime: TimeInterval

    /// Confidence score.
    public var confidence: Double

    /// Duration.
    public var duration: TimeInterval {
        endTime - startTime
    }

    public init(
        word: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double = 0.5
    ) {
        self.word = word
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

// MARK: - Caption Track Component

/// Formatted captions ready for display/export.
public struct CaptionTrackComponent: Component, Codable {
    /// Unique track identifier.
    public let id: UUID

    /// Source transcript entity ID.
    public var transcriptId: EntityId?

    /// Caption entries.
    public var entries: [CaptionEntry]

    /// Caption style entity ID.
    public var styleId: EntityId?

    /// Whether captions have been edited.
    public var isEdited: Bool

    public init(
        id: UUID = UUID(),
        transcriptId: EntityId? = nil,
        entries: [CaptionEntry] = [],
        styleId: EntityId? = nil,
        isEdited: Bool = false
    ) {
        self.id = id
        self.transcriptId = transcriptId
        self.entries = entries
        self.styleId = styleId
        self.isEdited = isEdited
    }
}

/// A single caption entry for display.
public struct CaptionEntry: Codable, Sendable, Identifiable {
    public let id: UUID

    /// Start time in seconds.
    public var startTime: TimeInterval

    /// End time in seconds.
    public var endTime: TimeInterval

    /// Caption text (may include line breaks).
    public var text: String

    /// Word-level timing for highlighting.
    public var wordTimings: [WordTiming]?

    /// Speaker label (if showing).
    public var speakerLabel: String?

    /// Duration.
    public var duration: TimeInterval {
        endTime - startTime
    }

    public init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        wordTimings: [WordTiming]? = nil,
        speakerLabel: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.wordTimings = wordTimings
        self.speakerLabel = speakerLabel
    }
}

/// Word timing for karaoke-style highlighting.
public struct WordTiming: Codable, Sendable {
    /// Character range in the caption text.
    public var range: Range<Int>

    /// Start time relative to caption start.
    public var relativeStart: TimeInterval

    /// Duration.
    public var duration: TimeInterval

    public init(range: Range<Int>, relativeStart: TimeInterval, duration: TimeInterval) {
        self.range = range
        self.relativeStart = relativeStart
        self.duration = duration
    }

    enum CodingKeys: String, CodingKey {
        case lowerBound, upperBound, relativeStart, duration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lower = try container.decode(Int.self, forKey: .lowerBound)
        let upper = try container.decode(Int.self, forKey: .upperBound)
        self.range = lower..<upper
        self.relativeStart = try container.decode(TimeInterval.self, forKey: .relativeStart)
        self.duration = try container.decode(TimeInterval.self, forKey: .duration)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(range.lowerBound, forKey: .lowerBound)
        try container.encode(range.upperBound, forKey: .upperBound)
        try container.encode(relativeStart, forKey: .relativeStart)
        try container.encode(duration, forKey: .duration)
    }
}

// MARK: - Speaker Diarization Component

/// Speaker identification and diarization results.
public struct SpeakerDiarizationComponent: Component, Codable {
    /// Identified speakers.
    public var speakers: [SpeakerInfo]

    /// Speaker segments.
    public var segments: [SpeakerSegment]

    /// Whether diarization has been reviewed.
    public var isReviewed: Bool

    public init(
        speakers: [SpeakerInfo] = [],
        segments: [SpeakerSegment] = [],
        isReviewed: Bool = false
    ) {
        self.speakers = speakers
        self.segments = segments
        self.isReviewed = isReviewed
    }
}

/// Information about an identified speaker.
public struct SpeakerInfo: Codable, Sendable, Identifiable {
    public let id: String

    /// Display label.
    public var label: String

    /// Assigned color (hex).
    public var color: String?

    /// Total speaking time.
    public var totalDuration: TimeInterval

    public init(
        id: String,
        label: String,
        color: String? = nil,
        totalDuration: TimeInterval = 0
    ) {
        self.id = id
        self.label = label
        self.color = color
        self.totalDuration = totalDuration
    }
}

/// A segment of speech by a speaker.
public struct SpeakerSegment: Codable, Sendable {
    /// Speaker ID.
    public var speakerId: String

    /// Time range.
    public var range: TimeRange

    /// Confidence.
    public var confidence: Double

    public init(speakerId: String, range: TimeRange, confidence: Double = 0.5) {
        self.speakerId = speakerId
        self.range = range
        self.confidence = confidence
    }
}
