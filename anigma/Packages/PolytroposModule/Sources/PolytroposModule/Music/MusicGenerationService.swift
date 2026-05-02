//
//  MusicGenerationService.swift
//  PolytroposModule
//
//  High-level service for generating public-domain-based background music.
//  Coordinates between symbolic sources, vibe profiles, and rendering.
//
//  Pipeline:
//  1. Select symbolic source based on scene parameters
//  2. Transform symbolic material through vibe profile
//  3. Generate arrangement following scene energy curve
//  4. Render to audio using instruments (built-in or user kits)
//  5. Post-process with production profile
//

import AnigmaCore
import Foundation

// MARK: - Music Generation Service

/// High-level service for generating background music.
public actor MusicGenerationService {

    // MARK: - Dependencies

    private let symbolicLibrary: SymbolicLibrary
    private let vibeProfileRegistry: VibeProfileRegistry
    private let userKitRegistry: UserKitRegistry
    private let symbolicTransformer: SymbolicTransformer
    private let arrangementGenerator: ArrangementGenerator
    private let audioRenderer: MusicAudioRenderer
    private let logger: PlatformLogger

    // MARK: - Initialization

    public init(
        symbolicLibrary: SymbolicLibrary,
        vibeProfileRegistry: VibeProfileRegistry,
        userKitRegistry: UserKitRegistry,
        symbolicTransformer: SymbolicTransformer,
        arrangementGenerator: ArrangementGenerator,
        audioRenderer: MusicAudioRenderer,
        logger: PlatformLogger = .shared
    ) {
        self.symbolicLibrary = symbolicLibrary
        self.vibeProfileRegistry = vibeProfileRegistry
        self.userKitRegistry = userKitRegistry
        self.symbolicTransformer = symbolicTransformer
        self.arrangementGenerator = arrangementGenerator
        self.audioRenderer = audioRenderer
        self.logger = logger
    }

    // MARK: - Generation

    /// Generate music for a cue.
    /// - Parameters:
    ///   - cue: The music cue component describing what to generate.
    ///   - sceneAnalysis: Optional audio analysis from the scene for sync.
    ///   - userKitId: Optional user instrument kit to use.
    /// - Returns: Generated music result with audio data and provenance.
    public func generateMusic(
        for cue: MusicCueComponent,
        sceneAnalysis: AudioAnalysisComponent? = nil,
        userKitId: UUID? = nil
    ) async throws -> MusicGenerationResult {

        await logger.info("Starting music generation for cue \(cue.id)", category: "Music")

        // 1. Resolve vibe profile
        guard let vibeProfile = await vibeProfileRegistry.profile(for: cue.vibeProfileId) else {
            throw MusicGenerationError.vibeProfileNotFound(cue.vibeProfileId)
        }

        // 2. Determine target parameters from scene or cue
        let targetParams = resolveTargetParameters(
            cue: cue,
            vibeProfile: vibeProfile,
            sceneAnalysis: sceneAnalysis
        )

        // 3. Select appropriate symbolic source
        let symbolicSource = try await symbolicLibrary.selectSource(
            targetDuration: cue.timeRange.duration,
            targetTempo: targetParams.tempo,
            targetKey: targetParams.key,
            moodTags: vibeProfile.moodTags
        )

        await logger.debug(
            "Selected symbolic source: \(symbolicSource.id) (\(symbolicSource.originalTitle ?? "untitled"))",
            category: "Music"
        )

        // 4. Load and transform symbolic data
        let symbolicData = try await symbolicLibrary.loadSymbolicData(for: symbolicSource)

        let transformedSymbolic = try await symbolicTransformer.transform(
            symbolic: symbolicData,
            vibeProfile: vibeProfile,
            targetParams: targetParams
        )

        // 5. Generate arrangement following energy curve
        let energyCurve = sceneAnalysis?.energyCurve ?? generateDefaultEnergyCurve(
            duration: cue.timeRange.duration,
            intensity: cue.intensity
        )

        let arrangement = try await arrangementGenerator.generateArrangement(
            from: transformedSymbolic,
            vibeProfile: vibeProfile,
            energyCurve: energyCurve,
            complexity: cue.complexity,
            targetDuration: cue.timeRange.duration
        )

        // 6. Resolve instruments (built-in or user kit)
        let instrumentSet = try await resolveInstruments(
            vibeProfile: vibeProfile,
            userKitId: userKitId
        )

        // 7. Render to audio
        let renderResult = try await audioRenderer.render(
            arrangement: arrangement,
            instruments: instrumentSet,
            productionProfile: vibeProfile.productionProfile,
            targetDuration: cue.timeRange.duration,
            generateStems: true
        )

        // 8. Build provenance
        let provenance = MusicProvenance(
            symbolicSourceId: symbolicSource.id,
            originalComposition: symbolicSource.originalTitle,
            vibeProfileId: cue.vibeProfileId,
            userKitId: userKitId,
            generatorVersion: Self.generatorVersion,
            transformerVersion: symbolicTransformer.version,
            rendererVersion: audioRenderer.version,
            parameters: [
                "tempo": String(format: "%.1f", targetParams.tempo),
                "key": targetParams.key.displayName,
                "intensity": String(format: "%.2f", cue.intensity),
                "complexity": String(format: "%.2f", cue.complexity)
            ]
        )

        await logger.info(
            "Music generation complete: \(renderResult.durationSeconds)s at \(targetParams.tempo) BPM",
            category: "Music"
        )

        return MusicGenerationResult(
            audioData: renderResult.audioData,
            stems: renderResult.stems,
            durationSeconds: renderResult.durationSeconds,
            provenance: provenance,
            arrangement: arrangement
        )
    }

    /// Generate a quick preview (lower quality, faster).
    public func generatePreview(
        for cue: MusicCueComponent,
        maxDuration: TimeInterval = 15.0
    ) async throws -> MusicGenerationResult {

        // Use simplified pipeline for preview
        guard let vibeProfile = await vibeProfileRegistry.profile(for: cue.vibeProfileId) else {
            throw MusicGenerationError.vibeProfileNotFound(cue.vibeProfileId)
        }

        let previewDuration = min(cue.timeRange.duration, maxDuration)

        let targetParams = resolveTargetParameters(
            cue: cue,
            vibeProfile: vibeProfile,
            sceneAnalysis: nil
        )

        let symbolicSource = try await symbolicLibrary.selectSource(
            targetDuration: previewDuration,
            targetTempo: targetParams.tempo,
            targetKey: targetParams.key,
            moodTags: vibeProfile.moodTags
        )

        let symbolicData = try await symbolicLibrary.loadSymbolicData(for: symbolicSource)

        let transformedSymbolic = try await symbolicTransformer.transform(
            symbolic: symbolicData,
            vibeProfile: vibeProfile,
            targetParams: targetParams
        )

        // Simplified arrangement for preview
        let arrangement = try await arrangementGenerator.generateSimpleArrangement(
            from: transformedSymbolic,
            vibeProfile: vibeProfile,
            targetDuration: previewDuration
        )

        // Quick render without stems
        let renderResult = try await audioRenderer.render(
            arrangement: arrangement,
            instruments: InstrumentSet.builtIn(for: vibeProfile.instrumentation),
            productionProfile: vibeProfile.productionProfile,
            targetDuration: previewDuration,
            generateStems: false,
            quality: .preview
        )

        let provenance = MusicProvenance(
            symbolicSourceId: symbolicSource.id,
            originalComposition: symbolicSource.originalTitle,
            vibeProfileId: cue.vibeProfileId,
            userKitId: nil,
            generatorVersion: Self.generatorVersion,
            transformerVersion: symbolicTransformer.version,
            rendererVersion: audioRenderer.version,
            parameters: ["mode": "preview"]
        )

        return MusicGenerationResult(
            audioData: renderResult.audioData,
            stems: [:],
            durationSeconds: renderResult.durationSeconds,
            provenance: provenance,
            arrangement: arrangement
        )
    }

    // MARK: - Private Helpers

    private func resolveTargetParameters(
        cue: MusicCueComponent,
        vibeProfile: VibeProfileComponent,
        sceneAnalysis: AudioAnalysisComponent?
    ) -> TargetMusicParameters {

        // Tempo: use override, or scene analysis, or vibe profile midpoint
        let tempo: Double
        if let override = cue.tempoOverride {
            tempo = override
        } else if let sceneTempo = sceneAnalysis?.tempo {
            // Clamp to vibe profile's range
            tempo = min(max(sceneTempo, vibeProfile.tempoRange.lowerBound), vibeProfile.tempoRange.upperBound)
        } else {
            // Use midpoint of vibe range
            tempo = (vibeProfile.tempoRange.lowerBound + vibeProfile.tempoRange.upperBound) / 2
        }

        // Key: use override, or pick appropriate based on vibe
        let key: MusicalKey
        if let override = cue.keyOverride {
            key = override
        } else {
            key = selectKeyForVibe(vibeProfile)
        }

        return TargetMusicParameters(
            tempo: tempo,
            key: key,
            intensity: cue.intensity,
            complexity: cue.complexity
        )
    }

    private func selectKeyForVibe(_ vibeProfile: VibeProfileComponent) -> MusicalKey {
        // Pick key based on harmony profile darkness
        let preferMinor = vibeProfile.harmonyProfile.darkness > 0.5

        // Common keys by category
        switch vibeProfile.category {
        case .rock, .electronic:
            return preferMinor ? MusicalKey(root: .e, mode: .minor) : MusicalKey(root: .e, mode: .major)
        case .cinematic:
            return preferMinor ? MusicalKey(root: .d, mode: .minor) : MusicalKey(root: .c, mode: .major)
        case .classical:
            return preferMinor ? MusicalKey(root: .a, mode: .minor) : MusicalKey(root: .g, mode: .major)
        case .jazz:
            return preferMinor ? MusicalKey(root: .d, mode: .dorian) : MusicalKey(root: .f, mode: .major)
        case .ambient:
            return preferMinor ? MusicalKey(root: .c, mode: .minor) : MusicalKey(root: .c, mode: .major)
        case .latin:
            return preferMinor ? MusicalKey(root: .a, mode: .phrygian) : MusicalKey(root: .g, mode: .major)
        default:
            return preferMinor ? MusicalKey(root: .a, mode: .minor) : MusicalKey(root: .c, mode: .major)
        }
    }

    private func generateDefaultEnergyCurve(
        duration: TimeInterval,
        intensity: Float
    ) -> [Float] {
        // Generate a simple energy curve based on intensity
        let sampleCount = Int(duration * 10)  // 10 samples per second
        var curve = [Float](repeating: intensity, count: sampleCount)

        // Add slight variation
        for i in 0..<sampleCount {
            let position = Float(i) / Float(sampleCount)
            // Gentle arc shape
            let arc = 1.0 - Swift.abs(position - 0.5) * 0.3
            curve[i] = intensity * arc
        }

        return curve
    }

    private func resolveInstruments(
        vibeProfile: VibeProfileComponent,
        userKitId: UUID?
    ) async throws -> InstrumentSet {

        if let kitId = userKitId {
            guard let userKit = await userKitRegistry.kit(for: kitId) else {
                throw MusicGenerationError.userKitNotFound(kitId)
            }
            return .hybrid(
                builtIn: InstrumentSet.builtIn(for: vibeProfile.instrumentation),
                userKit: userKit
            )
        } else {
            return .builtIn(for: vibeProfile.instrumentation)
        }
    }

    // MARK: - Version

    public static let generatorVersion = "1.0.0"
}

// MARK: - Supporting Types

/// Target parameters for music generation.
public struct TargetMusicParameters: Sendable {
    public var tempo: Double
    public var key: MusicalKey
    public var intensity: Float
    public var complexity: Float
}

/// Result of music generation.
public struct MusicGenerationResult: Sendable {
    public var audioData: Data
    public var stems: [StemType: Data]
    public var durationSeconds: TimeInterval
    public var provenance: MusicProvenance
    public var arrangement: ArrangementData
}

/// Errors during music generation.
public enum MusicGenerationError: Error, LocalizedError {
    case vibeProfileNotFound(VibeProfileId)
    case userKitNotFound(UUID)
    case noSuitableSource
    case transformationFailed(String)
    case renderingFailed(String)
    case invalidParameters(String)

    public var errorDescription: String? {
        switch self {
        case .vibeProfileNotFound(let id):
            return "Vibe profile not found: \(id)"
        case .userKitNotFound(let id):
            return "User instrument kit not found: \(id)"
        case .noSuitableSource:
            return "No suitable symbolic source found for the requested parameters"
        case .transformationFailed(let reason):
            return "Symbolic transformation failed: \(reason)"
        case .renderingFailed(let reason):
            return "Audio rendering failed: \(reason)"
        case .invalidParameters(let reason):
            return "Invalid parameters: \(reason)"
        }
    }
}

// MARK: - Protocol Stubs

/// Protocol for symbolic music library access.
public protocol SymbolicLibrary: Sendable {
    func selectSource(
        targetDuration: TimeInterval,
        targetTempo: Double?,
        targetKey: MusicalKey?,
        moodTags: [String]
    ) async throws -> SymbolicSourceComponent

    func loadSymbolicData(for source: SymbolicSourceComponent) async throws -> SymbolicData
}

/// Protocol for vibe profile registry.
public protocol VibeProfileRegistry: Sendable {
    func profile(for id: VibeProfileId) async -> VibeProfileComponent?
    func allProfiles() async -> [VibeProfileComponent]
    func profilesInCategory(_ category: VibeCategory) async -> [VibeProfileComponent]
}

/// Protocol for user kit registry.
public protocol UserKitRegistry: Sendable {
    func kit(for id: UUID) async -> UserInstrumentKitComponent?
    func allKits() async -> [UserInstrumentKitComponent]
    func kitsInCategory(_ category: InstrumentKitCategory) async -> [UserInstrumentKitComponent]
}

/// Protocol for symbolic transformation.
public protocol SymbolicTransformer: Sendable {
    var version: String { get }

    func transform(
        symbolic: SymbolicData,
        vibeProfile: VibeProfileComponent,
        targetParams: TargetMusicParameters
    ) async throws -> TransformedSymbolicData
}

/// Protocol for arrangement generation.
public protocol ArrangementGenerator: Sendable {
    func generateArrangement(
        from symbolic: TransformedSymbolicData,
        vibeProfile: VibeProfileComponent,
        energyCurve: [Float],
        complexity: Float,
        targetDuration: TimeInterval
    ) async throws -> ArrangementData

    func generateSimpleArrangement(
        from symbolic: TransformedSymbolicData,
        vibeProfile: VibeProfileComponent,
        targetDuration: TimeInterval
    ) async throws -> ArrangementData
}

/// Protocol for audio rendering.
public protocol MusicAudioRenderer: Sendable {
    var version: String { get }

    func render(
        arrangement: ArrangementData,
        instruments: InstrumentSet,
        productionProfile: ProductionProfile,
        targetDuration: TimeInterval,
        generateStems: Bool,
        quality: RenderQuality
    ) async throws -> MusicRenderResult
}

extension MusicAudioRenderer {
    public func render(
        arrangement: ArrangementData,
        instruments: InstrumentSet,
        productionProfile: ProductionProfile,
        targetDuration: TimeInterval,
        generateStems: Bool
    ) async throws -> MusicRenderResult {
        try await render(
            arrangement: arrangement,
            instruments: instruments,
            productionProfile: productionProfile,
            targetDuration: targetDuration,
            generateStems: generateStems,
            quality: .full
        )
    }
}

/// Render quality level.
public enum RenderQuality: String, Sendable {
    case preview
    case draft
    case full
}

/// Result from rendering.
public struct MusicRenderResult: Sendable {
    public var audioData: Data
    public var stems: [StemType: Data]
    public var durationSeconds: TimeInterval

    public init(audioData: Data, stems: [StemType: Data] = [:], durationSeconds: TimeInterval) {
        self.audioData = audioData
        self.stems = stems
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Data Types (Stubs)

/// Raw symbolic data (MIDI events, notes, chords).
public struct SymbolicData: Sendable {
    public var notes: [SymbolicNote]
    public var chords: [SymbolicChord]
    public var tempo: Double
    public var timeSignature: TimeSignature
    public var duration: TimeInterval

    public init(
        notes: [SymbolicNote] = [],
        chords: [SymbolicChord] = [],
        tempo: Double = 120,
        timeSignature: TimeSignature = .fourFour,
        duration: TimeInterval = 0
    ) {
        self.notes = notes
        self.chords = chords
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.duration = duration
    }
}

/// A symbolic note.
public struct SymbolicNote: Sendable {
    public var pitch: Int  // MIDI note number
    public var velocity: Int
    public var startTime: TimeInterval
    public var duration: TimeInterval
    public var channel: Int

    public init(pitch: Int, velocity: Int, startTime: TimeInterval, duration: TimeInterval, channel: Int = 0) {
        self.pitch = pitch
        self.velocity = velocity
        self.startTime = startTime
        self.duration = duration
        self.channel = channel
    }
}

/// A symbolic chord.
public struct SymbolicChord: Sendable {
    public var root: NoteName
    public var quality: ChordQuality
    public var startTime: TimeInterval
    public var duration: TimeInterval

    public init(root: NoteName, quality: ChordQuality, startTime: TimeInterval, duration: TimeInterval) {
        self.root = root
        self.quality = quality
        self.startTime = startTime
        self.duration = duration
    }
}

/// Chord quality.
public enum ChordQuality: String, Sendable {
    case major
    case minor
    case diminished
    case augmented
    case dominant7
    case major7
    case minor7
    case sus2
    case sus4
}

/// Transformed symbolic data (after style processing).
public struct TransformedSymbolicData: Sendable {
    public var tracks: [SymbolicTrack]
    public var tempo: Double
    public var key: MusicalKey
    public var duration: TimeInterval

    public init(tracks: [SymbolicTrack] = [], tempo: Double = 120, key: MusicalKey = MusicalKey(root: .c, mode: .major), duration: TimeInterval = 0) {
        self.tracks = tracks
        self.tempo = tempo
        self.key = key
        self.duration = duration
    }
}

/// A track of symbolic events.
public struct SymbolicTrack: Sendable {
    public var name: String
    public var instrumentType: InstrumentType
    public var notes: [SymbolicNote]

    public init(name: String, instrumentType: InstrumentType, notes: [SymbolicNote] = []) {
        self.name = name
        self.instrumentType = instrumentType
        self.notes = notes
    }
}

/// Arrangement data ready for rendering.
public struct ArrangementData: Sendable {
    public var tracks: [ArrangementTrack]
    public var tempo: Double
    public var timeSignature: TimeSignature
    public var duration: TimeInterval
    public var sections: [ArrangementSection]

    public init(
        tracks: [ArrangementTrack] = [],
        tempo: Double = 120,
        timeSignature: TimeSignature = .fourFour,
        duration: TimeInterval = 0,
        sections: [ArrangementSection] = []
    ) {
        self.tracks = tracks
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.duration = duration
        self.sections = sections
    }
}

/// A track in an arrangement.
public struct ArrangementTrack: Sendable {
    public var name: String
    public var instrumentType: InstrumentType
    public var stemType: StemType
    public var events: [ArrangementEvent]
    public var volume: Float
    public var pan: Float

    public init(
        name: String,
        instrumentType: InstrumentType,
        stemType: StemType,
        events: [ArrangementEvent] = [],
        volume: Float = 1.0,
        pan: Float = 0.0
    ) {
        self.name = name
        self.instrumentType = instrumentType
        self.stemType = stemType
        self.events = events
        self.volume = volume
        self.pan = pan
    }
}

/// An event in an arrangement track.
public struct ArrangementEvent: Sendable {
    public var type: ArrangementEventType
    public var time: TimeInterval
    public var duration: TimeInterval
    public var parameters: [String: Float]

    public init(type: ArrangementEventType, time: TimeInterval, duration: TimeInterval = 0, parameters: [String: Float] = [:]) {
        self.type = type
        self.time = time
        self.duration = duration
        self.parameters = parameters
    }
}

/// Types of arrangement events.
public enum ArrangementEventType: Sendable {
    case note(pitch: Int, velocity: Int)
    case chord(root: NoteName, quality: ChordQuality)
    case drumHit(trigger: Int, velocity: Int)
    case controlChange(controller: Int, value: Int)
    case programChange(program: Int)
}

/// A section within an arrangement.
public struct ArrangementSection: Sendable {
    public var name: String
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var energy: Float

    public init(name: String, startTime: TimeInterval, endTime: TimeInterval, energy: Float = 0.5) {
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.energy = energy
    }
}

/// Instrument set for rendering.
public indirect enum InstrumentSet: Sendable {
    case builtIn(for: InstrumentationProfile)
    case userOnly(UserInstrumentKitComponent)
    case hybrid(builtIn: InstrumentSet, userKit: UserInstrumentKitComponent)

}
