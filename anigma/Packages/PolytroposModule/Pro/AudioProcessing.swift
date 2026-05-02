import AnigmaPrimitives

import AnigmaPrimitives

//
//  AudioProcessing.swift
//  PolytroposModule
//
//  Professional audio processing components and services.
//  Phase 4 of Polytropos Pro roadmap.
//

import AnigmaCore
import AnigmaPrimitives
import Foundation

// MARK: - Audio Processing Chain

/// Audio processing chain applied to a clip or track.
public struct AudioProcessingComponent: Component, Codable {
    public let id: UUID

    /// Human-readable name.
    public var name: String

    /// Chain of audio effects in order.
    public var effects: [AudioEffect]

    /// Whether the chain is enabled.
    public var isEnabled: Bool

    /// Whether this is a track-level or clip-level chain.
    public var scope: AudioProcessingScope

    public init(
        id: UUID = UUID(),
        name: String = "Audio Processing",
        effects: [AudioEffect] = [],
        isEnabled: Bool = true,
        scope: AudioProcessingScope = .clip
    ) {
        self.id = id
        self.name = name
        self.effects = effects
        self.isEnabled = isEnabled
        self.scope = scope
    }
}

/// Scope of audio processing.
public enum AudioProcessingScope: String, Codable, Sendable {
    case clip       // Applied to single clip
    case track      // Applied to track
    case bus        // Applied to audio bus
    case master     // Applied to master output
}

// MARK: - Audio Effects

/// A single audio effect in the processing chain.
public struct AudioEffect: Codable, Sendable, Identifiable {
    public let id: UUID
    public var effectType: AudioEffectType
    public var parameters: AudioEffectParameters
    public var isEnabled: Bool
    public var isBypassed: Bool

    public init(
        id: UUID = UUID(),
        effectType: AudioEffectType,
        parameters: AudioEffectParameters,
        isEnabled: Bool = true,
        isBypassed: Bool = false
    ) {
        self.id = id
        self.effectType = effectType
        self.parameters = parameters
        self.isEnabled = isEnabled
        self.isBypassed = isBypassed
    }
}

/// Types of audio effects.
public enum AudioEffectType: String, Codable, Sendable {
    // Dynamics
    case compressor
    case limiter
    case gate
    case expander
    case deEsser

    // EQ
    case parametricEQ
    case graphicEQ
    case highPassFilter
    case lowPassFilter
    case bandPassFilter

    // Time-based
    case reverb
    case delay
    case chorus
    case flanger
    case phaser

    // Utility
    case gain
    case pan
    case stereoWidth
    case phaseInvert

    // Restoration
    case noiseReduction
    case deHum
    case deClick
    case deClip

    // Special
    case voiceEnhancer
    case loudnessNormalizer
    case sidechain
}

/// Parameters for audio effects.
public struct AudioEffectParameters: Codable, Sendable {
    /// Effect-specific parameters as key-value pairs.
    public var values: [String: Double]

    public init(values: [String: Double] = [:]) {
        self.values = values
    }

    public subscript(key: String) -> Double? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

// MARK: - Specific Effect Presets

/// Compressor effect preset factory.
public enum CompressorPresets {

    /// Voice/dialog compression.
    public static let dialog = AudioEffect(
        effectType: .compressor,
        parameters: AudioEffectParameters(values: [
            "threshold": -18.0,
            "ratio": 3.0,
            "attack": 10.0,     // ms
            "release": 100.0,   // ms
            "knee": 6.0,        // dB
            "makeupGain": 3.0   // dB
        ])
    )

    /// Gentle music compression.
    public static let gentleMusic = AudioEffect(
        effectType: .compressor,
        parameters: AudioEffectParameters(values: [
            "threshold": -12.0,
            "ratio": 2.0,
            "attack": 20.0,
            "release": 200.0,
            "knee": 10.0,
            "makeupGain": 2.0
        ])
    )

    /// Aggressive limiting.
    public static let broadcast = AudioEffect(
        effectType: .compressor,
        parameters: AudioEffectParameters(values: [
            "threshold": -6.0,
            "ratio": 8.0,
            "attack": 1.0,
            "release": 50.0,
            "knee": 3.0,
            "makeupGain": 4.0
        ])
    )
}

/// Limiter effect preset factory.
public enum LimiterPresets {

    /// Standard mastering limiter.
    public static let mastering = AudioEffect(
        effectType: .limiter,
        parameters: AudioEffectParameters(values: [
            "ceiling": -1.0,    // dB
            "release": 100.0,   // ms
            "lookahead": 5.0    // ms
        ])
    )

    /// Transparent limiter.
    public static let transparent = AudioEffect(
        effectType: .limiter,
        parameters: AudioEffectParameters(values: [
            "ceiling": -0.3,
            "release": 200.0,
            "lookahead": 10.0
        ])
    )
}

/// EQ effect preset factory.
public enum EQPresets {

    /// Voice clarity EQ.
    public static let voiceClarity = AudioEffect(
        effectType: .parametricEQ,
        parameters: AudioEffectParameters(values: [
            "band1_freq": 80.0,
            "band1_gain": -6.0,    // Cut rumble
            "band1_q": 0.7,
            "band1_type": 1.0,     // High-pass

            "band2_freq": 200.0,
            "band2_gain": -3.0,    // Reduce mud
            "band2_q": 1.5,
            "band2_type": 0.0,     // Bell

            "band3_freq": 3000.0,
            "band3_gain": 2.0,     // Presence
            "band3_q": 1.0,
            "band3_type": 0.0,

            "band4_freq": 8000.0,
            "band4_gain": 1.5,     // Air
            "band4_q": 0.8,
            "band4_type": 2.0      // High-shelf
        ])
    )

    /// Music sweetening EQ.
    public static let musicSweetening = AudioEffect(
        effectType: .parametricEQ,
        parameters: AudioEffectParameters(values: [
            "band1_freq": 60.0,
            "band1_gain": 2.0,
            "band1_q": 0.8,
            "band1_type": 3.0,     // Low-shelf

            "band2_freq": 400.0,
            "band2_gain": -1.0,
            "band2_q": 1.2,
            "band2_type": 0.0,

            "band3_freq": 12000.0,
            "band3_gain": 3.0,
            "band3_q": 0.7,
            "band3_type": 2.0
        ])
    )

    /// De-mud EQ (removes muddiness).
    public static let deMud = AudioEffect(
        effectType: .parametricEQ,
        parameters: AudioEffectParameters(values: [
            "band1_freq": 250.0,
            "band1_gain": -4.0,
            "band1_q": 1.0,
            "band1_type": 0.0
        ])
    )
}

/// Noise reduction presets.
public enum NoiseReductionPresets {

    /// Light noise reduction.
    public static let light = AudioEffect(
        effectType: .noiseReduction,
        parameters: AudioEffectParameters(values: [
            "amount": 0.3,
            "sensitivity": 0.5,
            "frequency_smoothing": 3.0,
            "attack": 5.0,
            "release": 50.0
        ])
    )

    /// Medium noise reduction.
    public static let medium = AudioEffect(
        effectType: .noiseReduction,
        parameters: AudioEffectParameters(values: [
            "amount": 0.6,
            "sensitivity": 0.6,
            "frequency_smoothing": 4.0,
            "attack": 3.0,
            "release": 30.0
        ])
    )

    /// Aggressive noise reduction.
    public static let aggressive = AudioEffect(
        effectType: .noiseReduction,
        parameters: AudioEffectParameters(values: [
            "amount": 0.9,
            "sensitivity": 0.8,
            "frequency_smoothing": 6.0,
            "attack": 1.0,
            "release": 20.0
        ])
    )
}

// MARK: - Audio Analysis Component

/// Audio analysis data for a clip or track.
public struct AssetAudioAnalysisComponent: Component, Codable {
    /// Asset entity reference.
    public var assetId: EntityId

    /// Waveform data (downsampled).
    public var waveformData: WaveformData?

    /// Loudness measurements.
    public var loudnessData: LoudnessData?

    /// Frequency analysis.
    public var frequencyData: FrequencyData?

    /// Speech/music classification.
    public var contentClassification: AudioContentClassification?

    public init(
        assetId: EntityId,
        waveformData: WaveformData? = nil,
        loudnessData: LoudnessData? = nil,
        frequencyData: FrequencyData? = nil,
        contentClassification: AudioContentClassification? = nil
    ) {
        self.assetId = assetId
        self.waveformData = waveformData
        self.loudnessData = loudnessData
        self.frequencyData = frequencyData
        self.contentClassification = contentClassification
    }
}

/// Waveform display data.
public struct WaveformData: Codable, Sendable {
    /// Samples per second (display resolution).
    public var samplesPerSecond: Int

    /// Min/max pairs for each sample.
    public var minMax: [(min: Float, max: Float)]

    /// Duration in seconds.
    public var duration: TimeInterval

    public init(samplesPerSecond: Int, minMax: [(min: Float, max: Float)], duration: TimeInterval) {
        self.samplesPerSecond = samplesPerSecond
        self.minMax = minMax
        self.duration = duration
    }

    // Custom Codable for tuple array
    enum CodingKeys: String, CodingKey {
        case samplesPerSecond, duration, minValues, maxValues
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        samplesPerSecond = try container.decode(Int.self, forKey: .samplesPerSecond)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        let minValues = try container.decode([Float].self, forKey: .minValues)
        let maxValues = try container.decode([Float].self, forKey: .maxValues)
        minMax = zip(minValues, maxValues).map { ($0, $1) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(samplesPerSecond, forKey: .samplesPerSecond)
        try container.encode(duration, forKey: .duration)
        try container.encode(minMax.map { $0.min }, forKey: .minValues)
        try container.encode(minMax.map { $0.max }, forKey: .maxValues)
    }
}

/// Loudness measurement data.
public struct LoudnessData: Codable, Sendable {
    /// Integrated loudness (LUFS).
    public var integratedLoudness: Double

    /// Short-term loudness max (LUFS).
    public var shortTermMax: Double

    /// Momentary loudness max (LUFS).
    public var momentaryMax: Double

    /// True peak (dBTP).
    public var truePeak: Double

    /// Loudness range (LU).
    public var loudnessRange: Double

    public init(
        integratedLoudness: Double,
        shortTermMax: Double,
        momentaryMax: Double,
        truePeak: Double,
        loudnessRange: Double
    ) {
        self.integratedLoudness = integratedLoudness
        self.shortTermMax = shortTermMax
        self.momentaryMax = momentaryMax
        self.truePeak = truePeak
        self.loudnessRange = loudnessRange
    }
}

/// Frequency analysis data.
public struct FrequencyData: Codable, Sendable {
    /// Dominant frequency bands.
    public var dominantBands: [FrequencyBand]

    /// Overall spectral balance.
    public var spectralBalance: SpectralBalance

    public init(dominantBands: [FrequencyBand], spectralBalance: SpectralBalance) {
        self.dominantBands = dominantBands
        self.spectralBalance = spectralBalance
    }
}

/// Frequency band energy.
public struct FrequencyBand: Codable, Sendable {
    public var lowFreq: Double
    public var highFreq: Double
    public var energy: Double // 0-1 normalized

    public init(lowFreq: Double, highFreq: Double, energy: Double) {
        self.lowFreq = lowFreq
        self.highFreq = highFreq
        self.energy = energy
    }
}

/// Spectral balance description.
public enum SpectralBalance: String, Codable, Sendable {
    case balanced
    case bassHeavy
    case trebleHeavy
    case midRangeHeavy
    case thin
    case muddy
}

/// Audio content classification.
public struct AudioContentClassification: Codable, Sendable {
    /// Speech presence (0-1).
    public var speechPresence: Double

    /// Music presence (0-1).
    public var musicPresence: Double

    /// Noise/ambient presence (0-1).
    public var noisePresence: Double

    /// Silence percentage.
    public var silencePercentage: Double

    /// Primary content type.
    public var primaryContent: AudioContentType

    public init(
        speechPresence: Double,
        musicPresence: Double,
        noisePresence: Double,
        silencePercentage: Double,
        primaryContent: AudioContentType
    ) {
        self.speechPresence = speechPresence
        self.musicPresence = musicPresence
        self.noisePresence = noisePresence
        self.silencePercentage = silencePercentage
        self.primaryContent = primaryContent
    }
}

/// Primary audio content type.
public enum AudioContentType: String, Codable, Sendable {
    case speech
    case music
    case mixed
    case ambient
    case silence
}

// MARK: - Audio Ducking

/// Audio ducking configuration.
public struct AudioDuckingComponent: Component, Codable {
    /// Timeline entity reference.
    public var timelineId: EntityId

    /// Ducking configuration.
    public var duckingConfig: DuckingConfig

    /// Whether ducking is enabled.
    public var isEnabled: Bool

    public init(
        timelineId: EntityId,
        duckingConfig: DuckingConfig = .standard,
        isEnabled: Bool = true
    ) {
        self.timelineId = timelineId
        self.duckingConfig = duckingConfig
        self.isEnabled = isEnabled
    }
}

/// Ducking configuration.
public struct DuckingConfig: Codable, Sendable {
    /// Which track types trigger ducking.
    public var triggerTracks: Set<AudioBusType>

    /// Which track types get ducked.
    public var targetTracks: Set<AudioBusType>

    /// Ducking amount in dB.
    public var duckAmount: Double

    /// Attack time in ms.
    public var attack: Double

    /// Release time in ms.
    public var release: Double

    /// Threshold for triggering.
    public var threshold: Double

    public static let standard = DuckingConfig(
        triggerTracks: [.dialog],
        targetTracks: [.music],
        duckAmount: -12.0,
        attack: 50.0,
        release: 500.0,
        threshold: -30.0
    )

    public init(
        triggerTracks: Set<AudioBusType>,
        targetTracks: Set<AudioBusType>,
        duckAmount: Double,
        attack: Double,
        release: Double,
        threshold: Double
    ) {
        self.triggerTracks = triggerTracks
        self.targetTracks = targetTracks
        self.duckAmount = duckAmount
        self.attack = attack
        self.release = release
        self.threshold = threshold
    }
}

// MARK: - Audio Processing Service

/// Service for audio processing and analysis.
public actor AudioProcessingService {

    private let world: World

    public init(world: World) {
        self.world = world
    }

    /// Analyzes audio for a media asset.
    public func analyzeAudio(for assetId: EntityId) async throws -> AssetAudioAnalysisComponent {
        // Implementation would analyze the audio file
        await PlatformLogger.shared.info(
            "Analyzing audio for asset \(assetId)",
            category: "AudioProcessing"
        )

        return AssetAudioAnalysisComponent(
            assetId: assetId,
            loudnessData: LoudnessData(
                integratedLoudness: -14.0,
                shortTermMax: -10.0,
                momentaryMax: -6.0,
                truePeak: -1.0,
                loudnessRange: 8.0
            )
        )
    }

    /// Creates an audio processing chain.
    public func createProcessingChain(
        name: String,
        effects: [AudioEffect],
        scope: AudioProcessingScope
    ) async throws -> EntityId {
        let entity = await world.createEntity()
        let chain = AudioProcessingComponent(
            name: name,
            effects: effects,
            scope: scope
        )
        await world.addComponent(chain, to: entity)
        return entity
    }

    /// Applies auto-enhancement to dialog.
    public func autoEnhanceDialog(for segmentId: UUID) async throws -> [AudioEffect] {
        // Implementation would analyze and create appropriate effects
        return [
            EQPresets.voiceClarity,
            CompressorPresets.dialog,
            NoiseReductionPresets.light
        ]
    }

    /// Normalizes loudness for a timeline.
    public func normalizeLoudness(
        for timelineId: EntityId,
        target: LoudnessTarget
    ) async throws {
        await PlatformLogger.shared.info(
            "Normalizing loudness for timeline \(timelineId) to \(target.lufs) LUFS",
            category: "AudioProcessing"
        )
    }

    /// Generates ducking automation for a timeline.
    public func generateDuckingAutomation(
        for timelineId: EntityId,
        config: DuckingConfig
    ) async throws -> [AutomationKeyframe] {
        // Implementation would analyze and create automation
        return []
    }
}

// MARK: - Built-in Audio Presets

/// Built-in audio processing presets.
public enum BuiltInAudioPresets {

    /// Dialog enhancement preset.
    public static let dialogEnhancement = AudioProcessingComponent(
        name: "Dialog Enhancement",
        effects: [
            EQPresets.voiceClarity,
            CompressorPresets.dialog,
            LimiterPresets.transparent
        ],
        scope: .clip
    )

    /// Music mastering preset.
    public static let musicMastering = AudioProcessingComponent(
        name: "Music Mastering",
        effects: [
            EQPresets.musicSweetening,
            CompressorPresets.gentleMusic,
            LimiterPresets.mastering
        ],
        scope: .track
    )

    /// Broadcast ready preset.
    public static let broadcastReady = AudioProcessingComponent(
        name: "Broadcast Ready",
        effects: [
            CompressorPresets.broadcast,
            LimiterPresets.mastering,
            AudioEffect(
                effectType: .loudnessNormalizer,
                parameters: AudioEffectParameters(values: [
                    "target_lufs": -24.0
                ])
            )
        ],
        scope: .master
    )

    /// Podcast preset.
    public static let podcast = AudioProcessingComponent(
        name: "Podcast",
        effects: [
            AudioEffect(
                effectType: .highPassFilter,
                parameters: AudioEffectParameters(values: [
                    "frequency": 80.0,
                    "slope": 12.0
                ])
            ),
            EQPresets.voiceClarity,
            CompressorPresets.dialog,
            AudioEffect(
                effectType: .loudnessNormalizer,
                parameters: AudioEffectParameters(values: [
                    "target_lufs": -16.0
                ])
            )
        ],
        scope: .master
    )

    /// All built-in presets.
    public static let allPresets: [AudioProcessingComponent] = [
        dialogEnhancement,
        musicMastering,
        broadcastReady,
        podcast
    ]
}
