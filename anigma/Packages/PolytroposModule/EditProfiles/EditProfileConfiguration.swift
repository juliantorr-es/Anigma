//
//  EditProfileConfiguration.swift
//  PolytroposModule
//
//  Configurable edit profiles that control auto-edit behavior.
//  These profiles encode "how to cut" decisions separately from
//  the auto-edit algorithm itself.
//

import AnigmaCore
import Foundation

// MARK: - Edit Profile

/// Complete configuration for auto-edit behavior.
/// This is the "recipe" that controls how the AutoEditSystem makes decisions.
public struct EditProfile: Codable, Sendable, Identifiable {
    public let id: UUID

    /// Human-readable profile name.
    public var name: String

    /// Profile description.
    public var description: String

    /// Event types this profile is suitable for.
    public var suitableEventTypes: [EventType]

    /// Cut timing configuration.
    public var timing: CutTimingProfile

    /// Camera selection configuration.
    public var cameraSelection: CameraSelectionProfile

    /// Beat and music alignment configuration.
    public var musicAlignment: MusicAlignmentProfile

    /// Crowd shot configuration.
    public var crowdBehavior: CrowdShotProfile

    /// Energy-based behavior adjustments.
    public var energyMapping: EnergyMappingProfile

    /// Transition configuration.
    public var transitions: TransitionProfile

    /// Scene boundary detection.
    public var sceneDetection: SceneDetectionProfile

    /// Whether this is a system-provided profile.
    public var isSystemProfile: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        suitableEventTypes: [EventType] = [.general],
        timing: CutTimingProfile = .default,
        cameraSelection: CameraSelectionProfile = .default,
        musicAlignment: MusicAlignmentProfile = .default,
        crowdBehavior: CrowdShotProfile = .default,
        energyMapping: EnergyMappingProfile = .default,
        transitions: TransitionProfile = .default,
        sceneDetection: SceneDetectionProfile = .default,
        isSystemProfile: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.suitableEventTypes = suitableEventTypes
        self.timing = timing
        self.cameraSelection = cameraSelection
        self.musicAlignment = musicAlignment
        self.crowdBehavior = crowdBehavior
        self.energyMapping = energyMapping
        self.transitions = transitions
        self.sceneDetection = sceneDetection
        self.isSystemProfile = isSystemProfile
    }
}

// MARK: - Cut Timing Profile

/// Controls the rhythm and pacing of cuts.
public struct CutTimingProfile: Codable, Sendable {
    /// Target average shot length in seconds.
    public var targetShotLength: TimeInterval

    /// Minimum allowed shot length.
    public var minimumShotLength: TimeInterval

    /// Maximum allowed shot length.
    public var maximumShotLength: TimeInterval

    /// Variance allowed around target (0-1).
    public var variance: Double

    /// Whether to avoid cutting during speech.
    public var avoidCuttingDuringSpeech: Bool

    /// Minimum time before allowing a cut after dialogue starts.
    public var speechProtectionWindow: TimeInterval

    public static let `default` = CutTimingProfile(
        targetShotLength: 4.0,
        minimumShotLength: 1.5,
        maximumShotLength: 12.0,
        variance: 0.3,
        avoidCuttingDuringSpeech: true,
        speechProtectionWindow: 2.0
    )

    public static let fast = CutTimingProfile(
        targetShotLength: 2.0,
        minimumShotLength: 0.75,
        maximumShotLength: 6.0,
        variance: 0.4,
        avoidCuttingDuringSpeech: false,
        speechProtectionWindow: 1.0
    )

    public static let slow = CutTimingProfile(
        targetShotLength: 8.0,
        minimumShotLength: 4.0,
        maximumShotLength: 20.0,
        variance: 0.2,
        avoidCuttingDuringSpeech: true,
        speechProtectionWindow: 3.0
    )

    public init(
        targetShotLength: TimeInterval,
        minimumShotLength: TimeInterval,
        maximumShotLength: TimeInterval,
        variance: Double,
        avoidCuttingDuringSpeech: Bool,
        speechProtectionWindow: TimeInterval
    ) {
        self.targetShotLength = targetShotLength
        self.minimumShotLength = minimumShotLength
        self.maximumShotLength = maximumShotLength
        self.variance = variance
        self.avoidCuttingDuringSpeech = avoidCuttingDuringSpeech
        self.speechProtectionWindow = speechProtectionWindow
    }
}

// MARK: - Camera Selection Profile

/// Controls how cameras are chosen for each segment.
public struct CameraSelectionProfile: Codable, Sendable {
    /// Weight for shot stability (0-1).
    public var stabilityWeight: Double

    /// Weight for image sharpness (0-1).
    public var sharpnessWeight: Double

    /// Weight for proper exposure (0-1).
    public var exposureWeight: Double

    /// Weight for subject presence (0-1).
    public var subjectPresenceWeight: Double

    /// Penalty for repeating same camera consecutively.
    public var repeatPenalty: Double

    /// Minimum time before using same camera again.
    public var minimumCameraInterval: TimeInterval

    /// Preferred angle type bias (nil = no preference).
    public var preferredAngleType: CameraAngleType?

    /// How strongly to prefer the preferred angle (0-1).
    public var anglePreferenceStrength: Double

    public static let `default` = CameraSelectionProfile(
        stabilityWeight: 0.25,
        sharpnessWeight: 0.3,
        exposureWeight: 0.25,
        subjectPresenceWeight: 0.2,
        repeatPenalty: 0.3,
        minimumCameraInterval: 3.0,
        preferredAngleType: nil,
        anglePreferenceStrength: 0.5
    )

    public init(
        stabilityWeight: Double,
        sharpnessWeight: Double,
        exposureWeight: Double,
        subjectPresenceWeight: Double,
        repeatPenalty: Double,
        minimumCameraInterval: TimeInterval,
        preferredAngleType: CameraAngleType?,
        anglePreferenceStrength: Double
    ) {
        self.stabilityWeight = stabilityWeight
        self.sharpnessWeight = sharpnessWeight
        self.exposureWeight = exposureWeight
        self.subjectPresenceWeight = subjectPresenceWeight
        self.repeatPenalty = repeatPenalty
        self.minimumCameraInterval = minimumCameraInterval
        self.preferredAngleType = preferredAngleType
        self.anglePreferenceStrength = anglePreferenceStrength
    }
}

// MARK: - Music Alignment Profile

/// Controls how cuts align with musical features.
public struct MusicAlignmentProfile: Codable, Sendable {
    /// Whether to align cuts to beat onsets.
    public var alignToBeats: Bool

    /// Maximum distance from a beat to still snap (seconds).
    public var beatSnapTolerance: TimeInterval

    /// Whether to prefer phrase boundaries over individual beats.
    public var preferPhraseBoundaries: Bool

    /// Whether to align cuts to downbeats specifically.
    public var preferDownbeats: Bool

    /// Strength of beat alignment (0 = ignore, 1 = strict).
    public var alignmentStrength: Double

    public static let `default` = MusicAlignmentProfile(
        alignToBeats: true,
        beatSnapTolerance: 0.15,
        preferPhraseBoundaries: true,
        preferDownbeats: true,
        alignmentStrength: 0.7
    )

    public static let strict = MusicAlignmentProfile(
        alignToBeats: true,
        beatSnapTolerance: 0.1,
        preferPhraseBoundaries: true,
        preferDownbeats: true,
        alignmentStrength: 0.95
    )

    public static let loose = MusicAlignmentProfile(
        alignToBeats: true,
        beatSnapTolerance: 0.3,
        preferPhraseBoundaries: false,
        preferDownbeats: false,
        alignmentStrength: 0.4
    )

    public init(
        alignToBeats: Bool,
        beatSnapTolerance: TimeInterval,
        preferPhraseBoundaries: Bool,
        preferDownbeats: Bool,
        alignmentStrength: Double
    ) {
        self.alignToBeats = alignToBeats
        self.beatSnapTolerance = beatSnapTolerance
        self.preferPhraseBoundaries = preferPhraseBoundaries
        self.preferDownbeats = preferDownbeats
        self.alignmentStrength = alignmentStrength
    }
}

// MARK: - Crowd Shot Profile

/// Controls when and how crowd shots are used.
public struct CrowdShotProfile: Codable, Sendable {
    /// Whether crowd shots are allowed at all.
    public var enabled: Bool

    /// Maximum percentage of timeline that can be crowd shots.
    public var maxCrowdPercentage: Double

    /// Maximum consecutive crowd shot duration.
    public var maxCrowdDuration: TimeInterval

    /// Minimum time between crowd shots.
    public var minIntervalBetweenCrowdShots: TimeInterval

    /// Whether to use crowd during applause.
    public var useDuringApplause: Bool

    /// Whether to use crowd during instrumental breaks.
    public var useDuringInstrumental: Bool

    /// Whether to use crowd during high energy moments.
    public var useDuringHighEnergy: Bool

    public static let `default` = CrowdShotProfile(
        enabled: true,
        maxCrowdPercentage: 0.15,
        maxCrowdDuration: 3.0,
        minIntervalBetweenCrowdShots: 20.0,
        useDuringApplause: true,
        useDuringInstrumental: true,
        useDuringHighEnergy: false
    )

    public static let disabled = CrowdShotProfile(
        enabled: false,
        maxCrowdPercentage: 0,
        maxCrowdDuration: 0,
        minIntervalBetweenCrowdShots: 0,
        useDuringApplause: false,
        useDuringInstrumental: false,
        useDuringHighEnergy: false
    )

    public static let aggressive = CrowdShotProfile(
        enabled: true,
        maxCrowdPercentage: 0.25,
        maxCrowdDuration: 5.0,
        minIntervalBetweenCrowdShots: 10.0,
        useDuringApplause: true,
        useDuringInstrumental: true,
        useDuringHighEnergy: true
    )

    public init(
        enabled: Bool,
        maxCrowdPercentage: Double,
        maxCrowdDuration: TimeInterval,
        minIntervalBetweenCrowdShots: TimeInterval,
        useDuringApplause: Bool,
        useDuringInstrumental: Bool,
        useDuringHighEnergy: Bool
    ) {
        self.enabled = enabled
        self.maxCrowdPercentage = maxCrowdPercentage
        self.maxCrowdDuration = maxCrowdDuration
        self.minIntervalBetweenCrowdShots = minIntervalBetweenCrowdShots
        self.useDuringApplause = useDuringApplause
        self.useDuringInstrumental = useDuringInstrumental
        self.useDuringHighEnergy = useDuringHighEnergy
    }
}

// MARK: - Energy Mapping Profile

/// Controls how audio energy affects edit behavior.
public struct EnergyMappingProfile: Codable, Sendable {
    /// Whether to adjust cut density based on energy.
    public var dynamicCutDensity: Bool

    /// Multiplier for shot length during low energy.
    public var lowEnergyMultiplier: Double

    /// Multiplier for shot length during high energy.
    public var highEnergyMultiplier: Double

    /// Energy threshold for "low" (0-1).
    public var lowEnergyThreshold: Double

    /// Energy threshold for "high" (0-1).
    public var highEnergyThreshold: Double

    /// Whether to use wide shots more during buildups.
    public var widesDuringBuildup: Bool

    /// Whether to use close shots more during drops.
    public var closesDuringDrop: Bool

    public static let `default` = EnergyMappingProfile(
        dynamicCutDensity: true,
        lowEnergyMultiplier: 1.5,
        highEnergyMultiplier: 0.6,
        lowEnergyThreshold: 0.3,
        highEnergyThreshold: 0.7,
        widesDuringBuildup: true,
        closesDuringDrop: true
    )

    public static let flat = EnergyMappingProfile(
        dynamicCutDensity: false,
        lowEnergyMultiplier: 1.0,
        highEnergyMultiplier: 1.0,
        lowEnergyThreshold: 0.3,
        highEnergyThreshold: 0.7,
        widesDuringBuildup: false,
        closesDuringDrop: false
    )

    public init(
        dynamicCutDensity: Bool,
        lowEnergyMultiplier: Double,
        highEnergyMultiplier: Double,
        lowEnergyThreshold: Double,
        highEnergyThreshold: Double,
        widesDuringBuildup: Bool,
        closesDuringDrop: Bool
    ) {
        self.dynamicCutDensity = dynamicCutDensity
        self.lowEnergyMultiplier = lowEnergyMultiplier
        self.highEnergyMultiplier = highEnergyMultiplier
        self.lowEnergyThreshold = lowEnergyThreshold
        self.highEnergyThreshold = highEnergyThreshold
        self.widesDuringBuildup = widesDuringBuildup
        self.closesDuringDrop = closesDuringDrop
    }
}

// MARK: - Transition Profile

/// Controls transition behavior between clips.
public struct TransitionProfile: Codable, Sendable {
    /// Default transition type.
    public var defaultTransition: TransitionType

    /// Whether to allow cross-dissolves.
    public var allowDissolves: Bool

    /// Duration for dissolve transitions.
    public var dissolveDuration: TimeInterval

    /// When to use dissolves.
    public var dissolveCondition: DissolveCondition

    /// Whether to use transition on scene boundaries.
    public var transitionOnSceneBoundary: Bool

    public static let `default` = TransitionProfile(
        defaultTransition: .cut,
        allowDissolves: true,
        dissolveDuration: 0.5,
        dissolveCondition: .lowMotionOnly,
        transitionOnSceneBoundary: true
    )

    public static let cutsOnly = TransitionProfile(
        defaultTransition: .cut,
        allowDissolves: false,
        dissolveDuration: 0,
        dissolveCondition: .never,
        transitionOnSceneBoundary: false
    )

    public init(
        defaultTransition: TransitionType,
        allowDissolves: Bool,
        dissolveDuration: TimeInterval,
        dissolveCondition: DissolveCondition,
        transitionOnSceneBoundary: Bool
    ) {
        self.defaultTransition = defaultTransition
        self.allowDissolves = allowDissolves
        self.dissolveDuration = dissolveDuration
        self.dissolveCondition = dissolveCondition
        self.transitionOnSceneBoundary = transitionOnSceneBoundary
    }
}

/// Conditions for using dissolve transitions.
public enum DissolveCondition: String, Codable, Sendable {
    case never
    case always
    case lowMotionOnly
    case sceneBoundaryOnly
    case lowMotionOrSceneBoundary
}

// MARK: - Scene Detection Profile

/// Controls automatic scene boundary detection.
public struct SceneDetectionProfile: Codable, Sendable {
    /// Whether to auto-detect scenes.
    public var enabled: Bool

    /// Use applause as scene boundaries.
    public var useApplause: Bool

    /// Use long silence as scene boundaries.
    public var useSilence: Bool

    /// Minimum silence duration to trigger boundary.
    public var silenceThreshold: TimeInterval

    /// Use audio structure (verse/chorus) as boundaries.
    public var useAudioStructure: Bool

    /// Minimum scene duration.
    public var minimumSceneDuration: TimeInterval

    public static let `default` = SceneDetectionProfile(
        enabled: true,
        useApplause: true,
        useSilence: true,
        silenceThreshold: 2.0,
        useAudioStructure: true,
        minimumSceneDuration: 30.0
    )

    public init(
        enabled: Bool,
        useApplause: Bool,
        useSilence: Bool,
        silenceThreshold: TimeInterval,
        useAudioStructure: Bool,
        minimumSceneDuration: TimeInterval
    ) {
        self.enabled = enabled
        self.useApplause = useApplause
        self.useSilence = useSilence
        self.silenceThreshold = silenceThreshold
        self.useAudioStructure = useAudioStructure
        self.minimumSceneDuration = minimumSceneDuration
    }
}

// MARK: - System Profiles

/// Built-in edit profiles for common event types.
public enum SystemEditProfiles {

    public static let concert = EditProfile(
        name: "Concert / Music",
        description: "Fast cuts aligned to beats, crowd shots during applause, energy-responsive pacing",
        suitableEventTypes: [.concert, .djSet],
        timing: .fast,
        cameraSelection: .default,
        musicAlignment: .strict,
        crowdBehavior: .default,
        energyMapping: .default,
        transitions: .cutsOnly,
        sceneDetection: .default,
        isSystemProfile: true
    )

    public static let dragShow = EditProfile(
        name: "Drag / Cabaret",
        description: "Medium pacing, beat-aligned, crowd reactions welcome",
        suitableEventTypes: [.dragShow],
        timing: .default,
        cameraSelection: .default,
        musicAlignment: .default,
        crowdBehavior: .aggressive,
        energyMapping: .default,
        transitions: .default,
        sceneDetection: .default,
        isSystemProfile: true
    )

    public static let talk = EditProfile(
        name: "Talk / Keynote",
        description: "Slow pacing, avoid cutting during speech, minimal crowd",
        suitableEventTypes: [.talk, .panel, .workshop],
        timing: .slow,
        cameraSelection: CameraSelectionProfile(
            stabilityWeight: 0.3,
            sharpnessWeight: 0.3,
            exposureWeight: 0.2,
            subjectPresenceWeight: 0.2,
            repeatPenalty: 0.2,
            minimumCameraInterval: 8.0,
            preferredAngleType: .medium,
            anglePreferenceStrength: 0.6
        ),
        musicAlignment: .loose,
        crowdBehavior: .disabled,
        energyMapping: .flat,
        transitions: .default,
        sceneDetection: SceneDetectionProfile(
            enabled: true,
            useApplause: true,
            useSilence: true,
            silenceThreshold: 3.0,
            useAudioStructure: false,
            minimumSceneDuration: 60.0
        ),
        isSystemProfile: true
    )

    public static let comedy = EditProfile(
        name: "Comedy / Stand-up",
        description: "Slow pacing for delivery, crowd reactions on laughs",
        suitableEventTypes: [.comedy],
        timing: CutTimingProfile(
            targetShotLength: 6.0,
            minimumShotLength: 3.0,
            maximumShotLength: 15.0,
            variance: 0.3,
            avoidCuttingDuringSpeech: true,
            speechProtectionWindow: 4.0
        ),
        cameraSelection: .default,
        musicAlignment: .loose,
        crowdBehavior: CrowdShotProfile(
            enabled: true,
            maxCrowdPercentage: 0.1,
            maxCrowdDuration: 2.0,
            minIntervalBetweenCrowdShots: 30.0,
            useDuringApplause: true,
            useDuringInstrumental: false,
            useDuringHighEnergy: false
        ),
        energyMapping: .flat,
        transitions: .cutsOnly,
        sceneDetection: .default,
        isSystemProfile: true
    )

    public static let theater = EditProfile(
        name: "Theater / Performance",
        description: "Very slow, deliberate cuts to preserve theatrical pacing",
        suitableEventTypes: [.theater],
        timing: CutTimingProfile(
            targetShotLength: 12.0,
            minimumShotLength: 6.0,
            maximumShotLength: 30.0,
            variance: 0.2,
            avoidCuttingDuringSpeech: true,
            speechProtectionWindow: 5.0
        ),
        cameraSelection: CameraSelectionProfile(
            stabilityWeight: 0.35,
            sharpnessWeight: 0.25,
            exposureWeight: 0.2,
            subjectPresenceWeight: 0.2,
            repeatPenalty: 0.15,
            minimumCameraInterval: 10.0,
            preferredAngleType: .wide,
            anglePreferenceStrength: 0.4
        ),
        musicAlignment: .loose,
        crowdBehavior: .disabled,
        energyMapping: .flat,
        transitions: .default,
        sceneDetection: SceneDetectionProfile(
            enabled: true,
            useApplause: true,
            useSilence: false,
            silenceThreshold: 5.0,
            useAudioStructure: false,
            minimumSceneDuration: 120.0
        ),
        isSystemProfile: true
    )

    public static var allProfiles: [EditProfile] {
        [concert, dragShow, talk, comedy, theater]
    }

    /// Returns the best matching profile for an event type.
    public static func profileFor(eventType: EventType) -> EditProfile {
        switch eventType {
        case .concert, .djSet:
            return concert
        case .dragShow:
            return dragShow
        case .talk, .panel, .workshop:
            return talk
        case .comedy:
            return comedy
        case .theater:
            return theater
        default:
            return concert // Default to concert as it's most versatile
        }
    }
}

// MARK: - Edit Profile Component

/// Component to attach an edit profile to a project or cluster.
public struct EditProfileComponent: Component, Codable {
    /// The edit profile configuration.
    public var profile: EditProfile

    /// User overrides on top of the profile.
    public var overrides: EditProfileOverrides?

    public init(profile: EditProfile, overrides: EditProfileOverrides? = nil) {
        self.profile = profile
        self.overrides = overrides
    }
}

/// User-specified overrides to a base profile.
public struct EditProfileOverrides: Codable, Sendable {
    /// Override for target shot length.
    public var targetShotLength: TimeInterval?

    /// Override for camera angle preference.
    public var preferredAngleType: CameraAngleType?

    /// Override for crowd shot behavior.
    public var crowdEnabled: Bool?

    /// Override for beat alignment.
    public var beatAlignmentStrength: Double?

    public init(
        targetShotLength: TimeInterval? = nil,
        preferredAngleType: CameraAngleType? = nil,
        crowdEnabled: Bool? = nil,
        beatAlignmentStrength: Double? = nil
    ) {
        self.targetShotLength = targetShotLength
        self.preferredAngleType = preferredAngleType
        self.crowdEnabled = crowdEnabled
        self.beatAlignmentStrength = beatAlignmentStrength
    }
}
