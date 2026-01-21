//
//  MusicComponents.swift
//  PolytroposModule
//
//  ECS components for public-domain-based music generation.
//  These components model music cues, symbolic data, vibe profiles,
//  user instrument kits, and generation jobs.
//
//  Architecture:
//  - Symbolic material (MIDI/MusicXML from PD corpora like PDMX) serves as input
//  - Style/vibe profiles transform symbolic material into genre-specific arrangements
//  - Rendering produces new audio that is legally safe (no copyrighted recordings)
//  - User-recorded instruments can be integrated as custom sample kits
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Music Cue Component

/// A music cue attached to a scene or timeline.
/// Represents a request for generated background music.
public struct MusicCueComponent: Component, Codable {
    /// Unique identifier for this cue.
    public let id: UUID

    /// Target scene or timeline entity.
    public var targetEntityId: EntityId?

    /// Time range within the target entity.
    public var timeRange: TimeRange

    /// Selected vibe profile.
    public var vibeProfileId: VibeProfileId

    /// Intensity/energy level (0-1).
    public var intensity: Float

    /// Complexity level (0-1, where 0 = minimal, 1 = full arrangement).
    public var complexity: Float

    /// Target tempo override (nil = derive from scene analysis).
    public var tempoOverride: Double?

    /// Target key override (nil = derive from scene or random).
    public var keyOverride: MusicalKey?

    /// Whether to auto-duck under speech.
    public var autoDuck: Bool

    /// Duck level when speech detected (0-1, where 0 = mute, 1 = full volume).
    public var duckLevel: Float

    /// Cue status.
    public var status: MusicCueStatus

    /// Reference to generated music asset (if generated).
    public var generatedAssetId: EntityId?

    /// Generation metadata.
    public var generationInfo: MusicGenerationInfo?

    public init(
        id: UUID = UUID(),
        targetEntityId: EntityId? = nil,
        timeRange: TimeRange,
        vibeProfileId: VibeProfileId,
        intensity: Float = 0.5,
        complexity: Float = 0.5,
        tempoOverride: Double? = nil,
        keyOverride: MusicalKey? = nil,
        autoDuck: Bool = true,
        duckLevel: Float = 0.3,
        status: MusicCueStatus = .pending,
        generatedAssetId: EntityId? = nil,
        generationInfo: MusicGenerationInfo? = nil
    ) {
        self.id = id
        self.targetEntityId = targetEntityId
        self.timeRange = timeRange
        self.vibeProfileId = vibeProfileId
        self.intensity = intensity
        self.complexity = complexity
        self.tempoOverride = tempoOverride
        self.keyOverride = keyOverride
        self.autoDuck = autoDuck
        self.duckLevel = duckLevel
        self.status = status
        self.generatedAssetId = generatedAssetId
        self.generationInfo = generationInfo
    }
}

/// Status of a music cue.
public enum MusicCueStatus: String, Codable, Sendable {
    case pending
    case generating
    case generated
    case failed
    case userReplaced
}

/// Metadata about a music generation run.
public struct MusicGenerationInfo: Codable, Sendable {
    public var symbolicSourceId: String
    public var modelVersion: String
    public var renderPresetId: String
    public var generatedAt: Date
    public var durationSeconds: TimeInterval
    public var stemCount: Int

    public init(
        symbolicSourceId: String,
        modelVersion: String,
        renderPresetId: String,
        generatedAt: Date = Date(),
        durationSeconds: TimeInterval,
        stemCount: Int
    ) {
        self.symbolicSourceId = symbolicSourceId
        self.modelVersion = modelVersion
        self.renderPresetId = renderPresetId
        self.generatedAt = generatedAt
        self.durationSeconds = durationSeconds
        self.stemCount = stemCount
    }
}

// MARK: - Musical Types

/// Musical key representation.
public struct MusicalKey: Codable, Sendable, Equatable {
    public var root: NoteName
    public var mode: KeyMode

    public init(root: NoteName, mode: KeyMode) {
        self.root = root
        self.mode = mode
    }

    public var displayName: String {
        "\(root.rawValue) \(mode.rawValue)"
    }
}

/// Note names.
public enum NoteName: String, Codable, Sendable, CaseIterable {
    case c = "C"
    case cSharp = "C#"
    case d = "D"
    case dSharp = "D#"
    case e = "E"
    case f = "F"
    case fSharp = "F#"
    case g = "G"
    case gSharp = "G#"
    case a = "A"
    case aSharp = "A#"
    case b = "B"
}

/// Key modes.
public enum KeyMode: String, Codable, Sendable {
    case major
    case minor
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case aeolian
    case locrian
}

// MARK: - Vibe Profile

/// Identifier for a vibe profile.
public struct VibeProfileId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }

    // Built-in vibe profiles
    public static let skaterPunk = VibeProfileId("skater_punk")
    public static let emo = VibeProfileId("emo")
    public static let postRock = VibeProfileId("post_rock")
    public static let cinematicEpic = VibeProfileId("cinematic_epic")
    public static let cinematicSad = VibeProfileId("cinematic_sad")
    public static let novela = VibeProfileId("novela")
    public static let lofiChill = VibeProfileId("lofi_chill")
    public static let synthwave = VibeProfileId("synthwave")
    public static let classicalStrings = VibeProfileId("classical_strings")
    public static let baroqueHarpsichord = VibeProfileId("baroque_harpsichord")
    public static let jazzLounge = VibeProfileId("jazz_lounge")
    public static let ambientPad = VibeProfileId("ambient_pad")
    public static let electronicMinimal = VibeProfileId("electronic_minimal")
    public static let rockDriving = VibeProfileId("rock_driving")
    public static let acousticFolk = VibeProfileId("acoustic_folk")
}

/// A vibe profile that defines how symbolic material gets transformed.
public struct VibeProfileComponent: Component, Codable {
    public let id: VibeProfileId

    /// Human-readable name.
    public var name: String

    /// Description for UI.
    public var description: String

    /// Category for organization.
    public var category: VibeCategory

    /// Instrumentation configuration.
    public var instrumentation: InstrumentationProfile

    /// Rhythmic behavior.
    public var rhythmProfile: RhythmProfile

    /// Harmonic treatment.
    public var harmonyProfile: HarmonyProfile

    /// Production/sound design.
    public var productionProfile: ProductionProfile

    /// Typical tempo range.
    public var tempoRange: ClosedRange<Double>

    /// Mood tags for search/discovery.
    public var moodTags: [String]

    /// Whether this is a built-in profile.
    public var isBuiltIn: Bool

    /// User who created this profile (nil for built-in).
    public var createdBy: String?

    public init(
        id: VibeProfileId,
        name: String,
        description: String,
        category: VibeCategory,
        instrumentation: InstrumentationProfile,
        rhythmProfile: RhythmProfile,
        harmonyProfile: HarmonyProfile,
        productionProfile: ProductionProfile,
        tempoRange: ClosedRange<Double> = 80...140,
        moodTags: [String] = [],
        isBuiltIn: Bool = true,
        createdBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.instrumentation = instrumentation
        self.rhythmProfile = rhythmProfile
        self.harmonyProfile = harmonyProfile
        self.productionProfile = productionProfile
        self.tempoRange = tempoRange
        self.moodTags = moodTags
        self.isBuiltIn = isBuiltIn
        self.createdBy = createdBy
    }
}

/// Category of vibe profile.
public enum VibeCategory: String, Codable, Sendable {
    case rock
    case electronic
    case cinematic
    case classical
    case jazz
    case ambient
    case latin
    case folk
    case experimental
    case custom
}

/// Instrumentation configuration for a vibe.
public struct InstrumentationProfile: Codable, Sendable {
    /// Drum kit style.
    public var drumStyle: DrumStyle

    /// Bass style.
    public var bassStyle: BassStyle

    /// Lead instrument(s).
    public var leadInstruments: [InstrumentType]

    /// Pad/harmony instruments.
    public var padInstruments: [InstrumentType]

    /// Whether to include percussion.
    public var includePercussion: Bool

    /// Maximum simultaneous instruments.
    public var maxSimultaneousInstruments: Int

    public init(
        drumStyle: DrumStyle = .standard,
        bassStyle: BassStyle = .electric,
        leadInstruments: [InstrumentType] = [.electricGuitar],
        padInstruments: [InstrumentType] = [.synth],
        includePercussion: Bool = false,
        maxSimultaneousInstruments: Int = 6
    ) {
        self.drumStyle = drumStyle
        self.bassStyle = bassStyle
        self.leadInstruments = leadInstruments
        self.padInstruments = padInstruments
        self.includePercussion = includePercussion
        self.maxSimultaneousInstruments = maxSimultaneousInstruments
    }
}

/// Drum style options.
public enum DrumStyle: String, Codable, Sendable {
    case none
    case minimal
    case standard
    case electronic
    case acoustic
    case orchestral
    case latin
    case lofi
}

/// Bass style options.
public enum BassStyle: String, Codable, Sendable {
    case none
    case electric
    case synth
    case acoustic
    case orchestral
    case slap
    case subBass
}

/// Instrument types.
public enum InstrumentType: String, Codable, Sendable {
    case electricGuitar
    case acousticGuitar
    case nylonGuitar
    case piano
    case electricPiano
    case organ
    case synth
    case strings
    case brass
    case woodwinds
    case violin
    case cello
    case harpsichord
    case flute
    case saxophone
    case trumpet
    case mallets
    case bells
    case voice
    case custom
}

/// Rhythmic behavior profile.
public struct RhythmProfile: Codable, Sendable {
    /// Straight vs swung feel.
    public var swing: Float  // 0 = straight, 1 = full swing

    /// Syncopation tendency.
    public var syncopation: Float  // 0-1

    /// Rhythmic complexity.
    public var complexity: Float  // 0-1

    /// Whether to include breaks/fills.
    public var includeBreaks: Bool

    /// Time signature.
    public var timeSignature: TimeSignature

    public init(
        swing: Float = 0,
        syncopation: Float = 0.3,
        complexity: Float = 0.5,
        includeBreaks: Bool = true,
        timeSignature: TimeSignature = .fourFour
    ) {
        self.swing = swing
        self.syncopation = syncopation
        self.complexity = complexity
        self.includeBreaks = includeBreaks
        self.timeSignature = timeSignature
    }
}

/// Time signature.
public struct TimeSignature: Codable, Sendable, Equatable {
    public var numerator: Int
    public var denominator: Int

    public static let fourFour = TimeSignature(numerator: 4, denominator: 4)
    public static let threeFour = TimeSignature(numerator: 3, denominator: 4)
    public static let sixEight = TimeSignature(numerator: 6, denominator: 8)

    public init(numerator: Int, denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }
}

/// Harmonic treatment profile.
public struct HarmonyProfile: Codable, Sendable {
    /// How much to simplify source harmonies.
    public var simplification: Float  // 0 = keep original, 1 = power chords only

    /// How much to reharmonize (add extensions, substitutions).
    public var reharmonization: Float  // 0-1

    /// Darkness/brightness bias.
    public var darkness: Float  // 0 = bright, 1 = dark

    /// Tension level (dissonance tolerance).
    public var tension: Float  // 0-1

    /// Whether to add suspensions.
    public var addSuspensions: Bool

    public init(
        simplification: Float = 0.3,
        reharmonization: Float = 0.2,
        darkness: Float = 0.5,
        tension: Float = 0.3,
        addSuspensions: Bool = true
    ) {
        self.simplification = simplification
        self.reharmonization = reharmonization
        self.darkness = darkness
        self.tension = tension
        self.addSuspensions = addSuspensions
    }
}

/// Production/sound design profile.
public struct ProductionProfile: Codable, Sendable {
    /// Distortion level.
    public var distortion: Float  // 0-1

    /// Reverb amount.
    public var reverb: Float  // 0-1

    /// Delay/echo.
    public var delay: Float  // 0-1

    /// Lo-fi/tape degradation.
    public var lofi: Float  // 0-1

    /// Compression amount.
    public var compression: Float  // 0-1

    /// Stereo width.
    public var stereoWidth: Float  // 0-1

    /// Master EQ brightness bias.
    public var brightness: Float  // 0 = dark, 1 = bright

    public init(
        distortion: Float = 0,
        reverb: Float = 0.3,
        delay: Float = 0.1,
        lofi: Float = 0,
        compression: Float = 0.5,
        stereoWidth: Float = 0.7,
        brightness: Float = 0.5
    ) {
        self.distortion = distortion
        self.reverb = reverb
        self.delay = delay
        self.lofi = lofi
        self.compression = compression
        self.stereoWidth = stereoWidth
        self.brightness = brightness
    }
}

// MARK: - Symbolic Source Component

/// A symbolic music source (MIDI, MusicXML, chord progression).
public struct SymbolicSourceComponent: Component, Codable {
    /// Unique identifier.
    public let id: String

    /// Source type.
    public var sourceType: SymbolicSourceType

    /// Original corpus/dataset.
    public var corpus: String  // e.g., "pdmx", "classical_midi", "user_created"

    /// Original composition title (for PD works).
    public var originalTitle: String?

    /// Original composer (for PD works).
    public var originalComposer: String?

    /// Year of composition (for PD verification).
    public var compositionYear: Int?

    /// License status.
    public var licenseStatus: LicenseStatus

    /// Duration in seconds.
    public var duration: TimeInterval

    /// Detected or annotated key.
    public var key: MusicalKey?

    /// Detected or annotated tempo.
    public var tempo: Double?

    /// Time signature.
    public var timeSignature: TimeSignature

    /// Mood/style tags.
    public var tags: [String]

    /// Storage reference for the actual data.
    public var dataStorageKey: String

    public init(
        id: String,
        sourceType: SymbolicSourceType,
        corpus: String,
        originalTitle: String? = nil,
        originalComposer: String? = nil,
        compositionYear: Int? = nil,
        licenseStatus: LicenseStatus = .publicDomain,
        duration: TimeInterval,
        key: MusicalKey? = nil,
        tempo: Double? = nil,
        timeSignature: TimeSignature = .fourFour,
        tags: [String] = [],
        dataStorageKey: String
    ) {
        self.id = id
        self.sourceType = sourceType
        self.corpus = corpus
        self.originalTitle = originalTitle
        self.originalComposer = originalComposer
        self.compositionYear = compositionYear
        self.licenseStatus = licenseStatus
        self.duration = duration
        self.key = key
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.tags = tags
        self.dataStorageKey = dataStorageKey
    }
}

/// Type of symbolic source.
public enum SymbolicSourceType: String, Codable, Sendable {
    case midi
    case musicXML
    case chordChart
    case leadSheet
    case generated
}

/// License status for symbolic material.
public enum LicenseStatus: String, Codable, Sendable {
    case publicDomain
    case cc0
    case ccBy
    case ccBySa
    case userCreated
    case unknown
}

// MARK: - User Instrument Kit Component

/// A user-created instrument kit from recorded samples.
public struct UserInstrumentKitComponent: Component, Codable {
    /// Kit identifier.
    public let id: UUID

    /// Human-readable name.
    public var name: String

    /// Kit category.
    public var category: InstrumentKitCategory

    /// Sample mappings.
    public var samples: [SampleMapping]

    /// Creation date.
    public var createdAt: Date

    /// Last modified date.
    public var modifiedAt: Date

    /// Whether this kit is complete (has all required samples).
    public var isComplete: Bool

    /// Notes from user.
    public var notes: String?

    public init(
        id: UUID = UUID(),
        name: String,
        category: InstrumentKitCategory,
        samples: [SampleMapping] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isComplete: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.samples = samples
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isComplete = isComplete
        self.notes = notes
    }
}

/// Category of user instrument kit.
public enum InstrumentKitCategory: String, Codable, Sendable {
    case drums
    case bass
    case guitar
    case keys
    case synth
    case vocals
    case percussion
    case other
}

/// A single sample mapping within a kit.
public struct SampleMapping: Codable, Sendable, Identifiable {
    public var id: UUID

    /// MIDI note number or trigger identifier.
    public var trigger: Int

    /// Human-readable label.
    public var label: String

    /// Reference to the audio asset.
    public var audioAssetId: EntityId

    /// Start time within the asset.
    public var startTime: TimeInterval

    /// End time within the asset.
    public var endTime: TimeInterval

    /// Root note (for pitched instruments).
    public var rootNote: Int?

    /// Velocity layers (if multiple samples for different velocities).
    public var velocityRange: ClosedRange<Int>

    public init(
        id: UUID = UUID(),
        trigger: Int,
        label: String,
        audioAssetId: EntityId,
        startTime: TimeInterval = 0,
        endTime: TimeInterval,
        rootNote: Int? = nil,
        velocityRange: ClosedRange<Int> = 1...127
    ) {
        self.id = id
        self.trigger = trigger
        self.label = label
        self.audioAssetId = audioAssetId
        self.startTime = startTime
        self.endTime = endTime
        self.rootNote = rootNote
        self.velocityRange = velocityRange
    }
}

// MARK: - Music Generation Job Component

/// A job to generate music for a cue.
public struct MusicGenerationJobComponent: Component, Codable {
    /// Job identifier.
    public let id: UUID

    /// Reference to the music cue.
    public var cueEntityId: EntityId

    /// Reference to the project.
    public var projectEntityId: EntityId

    /// Job status.
    public var status: MusicJobStatus

    /// Progress (0-1).
    public var progress: Float

    /// Current stage.
    public var currentStage: MusicGenerationStage

    /// Queued timestamp.
    public var queuedAt: Date

    /// Started timestamp.
    public var startedAt: Date?

    /// Completed timestamp.
    public var completedAt: Date?

    /// Error info if failed.
    public var errorInfo: String?

    /// Selected symbolic source for this generation.
    public var symbolicSourceId: String?

    /// Output audio asset reference.
    public var outputAssetId: EntityId?

    /// Output stem asset references (if generating stems).
    public var stemAssetIds: [String: EntityId]

    public init(
        id: UUID = UUID(),
        cueEntityId: EntityId,
        projectEntityId: EntityId,
        status: MusicJobStatus = .queued,
        progress: Float = 0,
        currentStage: MusicGenerationStage = .queued,
        queuedAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        errorInfo: String? = nil,
        symbolicSourceId: String? = nil,
        outputAssetId: EntityId? = nil,
        stemAssetIds: [String: EntityId] = [:]
    ) {
        self.id = id
        self.cueEntityId = cueEntityId
        self.projectEntityId = projectEntityId
        self.status = status
        self.progress = progress
        self.currentStage = currentStage
        self.queuedAt = queuedAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.errorInfo = errorInfo
        self.symbolicSourceId = symbolicSourceId
        self.outputAssetId = outputAssetId
        self.stemAssetIds = stemAssetIds
    }
}

/// Status of a music generation job.
public enum MusicJobStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

/// Stage of music generation.
public enum MusicGenerationStage: String, Codable, Sendable {
    case queued
    case selectingSource
    case transformingSymbolic
    case generatingArrangement
    case renderingAudio
    case postProcessing
    case completed
    case failed
}

// MARK: - Generated Music Asset Component

/// Metadata for a generated music asset.
public struct GeneratedMusicAssetComponent: Component, Codable {
    /// Link to the base MediaAsset.
    public var mediaAssetId: EntityId

    /// Generation provenance.
    public var provenance: MusicProvenance

    /// Whether this is a stem (vs full mix).
    public var isStem: Bool

    /// Stem type (if applicable).
    public var stemType: StemType?

    /// Full mix reference (if this is a stem).
    public var fullMixAssetId: EntityId?

    public init(
        mediaAssetId: EntityId,
        provenance: MusicProvenance,
        isStem: Bool = false,
        stemType: StemType? = nil,
        fullMixAssetId: EntityId? = nil
    ) {
        self.mediaAssetId = mediaAssetId
        self.provenance = provenance
        self.isStem = isStem
        self.stemType = stemType
        self.fullMixAssetId = fullMixAssetId
    }
}

/// Provenance information for generated music.
public struct MusicProvenance: Codable, Sendable {
    /// Symbolic source used.
    public var symbolicSourceId: String

    /// Original composition info (for PD tracking).
    public var originalComposition: String?

    /// Vibe profile used.
    public var vibeProfileId: VibeProfileId

    /// User kit used (if any).
    public var userKitId: UUID?

    /// Model/generator version.
    public var generatorVersion: String

    /// Symbolic transformer version.
    public var transformerVersion: String

    /// Renderer version.
    public var rendererVersion: String

    /// Timestamp of generation.
    public var generatedAt: Date

    /// Parameters used.
    public var parameters: [String: String]

    public init(
        symbolicSourceId: String,
        originalComposition: String? = nil,
        vibeProfileId: VibeProfileId,
        userKitId: UUID? = nil,
        generatorVersion: String,
        transformerVersion: String,
        rendererVersion: String,
        generatedAt: Date = Date(),
        parameters: [String: String] = [:]
    ) {
        self.symbolicSourceId = symbolicSourceId
        self.originalComposition = originalComposition
        self.vibeProfileId = vibeProfileId
        self.userKitId = userKitId
        self.generatorVersion = generatorVersion
        self.transformerVersion = transformerVersion
        self.rendererVersion = rendererVersion
        self.generatedAt = generatedAt
        self.parameters = parameters
    }
}

/// Type of audio stem.
public enum StemType: String, Codable, Sendable {
    case drums
    case bass
    case lead
    case pad
    case percussion
    case vocals
    case other
}
