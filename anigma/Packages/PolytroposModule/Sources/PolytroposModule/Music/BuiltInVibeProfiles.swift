//
//  BuiltInVibeProfiles.swift
//  PolytroposModule
//
//  Pre-configured vibe profiles for common music styles.
//  All based on public-domain transformations of symbolic material.
//

import Foundation

// MARK: - Built-in Vibe Profile Factory

/// Factory for creating built-in vibe profiles.
public enum BuiltInVibeProfiles {

    /// All built-in vibe profiles.
    public static var all: [VibeProfileComponent] {
        [
            skaterPunk,
            emo,
            postRock,
            cinematicEpic,
            cinematicSad,
            novela,
            lofiChill,
            synthwave,
            classicalStrings,
            baroqueHarpsichord,
            jazzLounge,
            ambientPad,
            electronicMinimal,
            rockDriving,
            acousticFolk
        ]
    }

    // MARK: - Rock / Punk

    /// Skater punk: fast, distorted, energetic.
    public static var skaterPunk: VibeProfileComponent {
        VibeProfileComponent(
            id: .skaterPunk,
            name: "Skater Punk",
            description: "Fast, distorted, high-energy punk rock perfect for action clips",
            category: .rock,
            instrumentation: InstrumentationProfile(
                drumStyle: .standard,
                bassStyle: .electric,
                leadInstruments: [.electricGuitar],
                padInstruments: [],
                includePercussion: false,
                maxSimultaneousInstruments: 4
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0.4,
                complexity: 0.3,
                includeBreaks: true,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.8,  // Power chords mostly
                reharmonization: 0.1,
                darkness: 0.4,
                tension: 0.3,
                addSuspensions: false
            ),
            productionProfile: ProductionProfile(
                distortion: 0.7,
                reverb: 0.2,
                delay: 0.1,
                lofi: 0,
                compression: 0.7,
                stereoWidth: 0.6,
                brightness: 0.7
            ),
            tempoRange: 160...200,
            moodTags: ["energetic", "aggressive", "fun", "fast", "rebellious"]
        )
    }

    /// Emo: emotional, melodic, atmospheric.
    public static var emo: VibeProfileComponent {
        VibeProfileComponent(
            id: .emo,
            name: "Emo",
            description: "Emotional, melodic rock with atmospheric guitars",
            category: .rock,
            instrumentation: InstrumentationProfile(
                drumStyle: .standard,
                bassStyle: .electric,
                leadInstruments: [.electricGuitar],
                padInstruments: [.electricGuitar],  // Clean guitar pads
                includePercussion: false,
                maxSimultaneousInstruments: 5
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0.3,
                complexity: 0.4,
                includeBreaks: true,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.3,
                reharmonization: 0.4,
                darkness: 0.7,
                tension: 0.5,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0.4,
                reverb: 0.6,
                delay: 0.4,
                lofi: 0,
                compression: 0.5,
                stereoWidth: 0.8,
                brightness: 0.4
            ),
            tempoRange: 100...140,
            moodTags: ["emotional", "melancholic", "atmospheric", "introspective"]
        )
    }

    /// Post-rock: building, atmospheric, cinematic.
    public static var postRock: VibeProfileComponent {
        VibeProfileComponent(
            id: .postRock,
            name: "Post-Rock",
            description: "Building, atmospheric soundscapes with dynamic swells",
            category: .rock,
            instrumentation: InstrumentationProfile(
                drumStyle: .minimal,
                bassStyle: .electric,
                leadInstruments: [.electricGuitar],
                padInstruments: [.electricGuitar, .synth],
                includePercussion: false,
                maxSimultaneousInstruments: 6
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0.2,
                complexity: 0.3,
                includeBreaks: false,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.2,
                reharmonization: 0.5,
                darkness: 0.5,
                tension: 0.4,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0.2,
                reverb: 0.8,
                delay: 0.6,
                lofi: 0,
                compression: 0.4,
                stereoWidth: 0.9,
                brightness: 0.5
            ),
            tempoRange: 80...120,
            moodTags: ["atmospheric", "building", "cinematic", "expansive", "emotional"]
        )
    }

    /// Rock driving: solid, driving rock beat.
    public static var rockDriving: VibeProfileComponent {
        VibeProfileComponent(
            id: .rockDriving,
            name: "Driving Rock",
            description: "Solid, driving rock with a strong beat",
            category: .rock,
            instrumentation: InstrumentationProfile(
                drumStyle: .standard,
                bassStyle: .electric,
                leadInstruments: [.electricGuitar],
                padInstruments: [.organ],
                includePercussion: false,
                maxSimultaneousInstruments: 5
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0.3,
                complexity: 0.4,
                includeBreaks: true,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.5,
                reharmonization: 0.2,
                darkness: 0.4,
                tension: 0.3,
                addSuspensions: false
            ),
            productionProfile: ProductionProfile(
                distortion: 0.5,
                reverb: 0.3,
                delay: 0.2,
                lofi: 0,
                compression: 0.6,
                stereoWidth: 0.7,
                brightness: 0.6
            ),
            tempoRange: 110...140,
            moodTags: ["energetic", "driving", "powerful", "classic"]
        )
    }

    // MARK: - Cinematic

    /// Cinematic epic: orchestral, dramatic, sweeping.
    public static var cinematicEpic: VibeProfileComponent {
        VibeProfileComponent(
            id: .cinematicEpic,
            name: "Cinematic Epic",
            description: "Orchestral, dramatic scoring for impactful moments",
            category: .cinematic,
            instrumentation: InstrumentationProfile(
                drumStyle: .orchestral,
                bassStyle: .orchestral,
                leadInstruments: [.strings, .brass],
                padInstruments: [.strings],
                includePercussion: true,
                maxSimultaneousInstruments: 8
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0.2,
                complexity: 0.5,
                includeBreaks: true,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.1,
                reharmonization: 0.4,
                darkness: 0.4,
                tension: 0.5,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0,
                reverb: 0.6,
                delay: 0.2,
                lofi: 0,
                compression: 0.4,
                stereoWidth: 0.9,
                brightness: 0.5
            ),
            tempoRange: 80...130,
            moodTags: ["epic", "dramatic", "powerful", "heroic", "inspiring"]
        )
    }

    /// Cinematic sad: emotional, melancholic orchestral.
    public static var cinematicSad: VibeProfileComponent {
        VibeProfileComponent(
            id: .cinematicSad,
            name: "Cinematic Sad",
            description: "Emotional, melancholic orchestral scoring",
            category: .cinematic,
            instrumentation: InstrumentationProfile(
                drumStyle: .none,
                bassStyle: .orchestral,
                leadInstruments: [.piano, .strings],
                padInstruments: [.strings],
                includePercussion: false,
                maxSimultaneousInstruments: 5
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0.1,
                complexity: 0.3,
                includeBreaks: false,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.1,
                reharmonization: 0.5,
                darkness: 0.8,
                tension: 0.4,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0,
                reverb: 0.7,
                delay: 0.3,
                lofi: 0,
                compression: 0.3,
                stereoWidth: 0.8,
                brightness: 0.3
            ),
            tempoRange: 60...90,
            moodTags: ["sad", "emotional", "melancholic", "touching", "reflective"]
        )
    }

    // MARK: - Latin / Drama

    /// Novela/telenovela: Latin, dramatic, passionate.
    public static var novela: VibeProfileComponent {
        VibeProfileComponent(
            id: .novela,
            name: "Novela",
            description: "Latin-influenced dramatic music for intense moments",
            category: .latin,
            instrumentation: InstrumentationProfile(
                drumStyle: .latin,
                bassStyle: .acoustic,
                leadInstruments: [.nylonGuitar, .strings],
                padInstruments: [.strings],
                includePercussion: true,
                maxSimultaneousInstruments: 6
            ),
            rhythmProfile: RhythmProfile(
                swing: 0.2,
                syncopation: 0.5,
                complexity: 0.4,
                includeBreaks: true,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.2,
                reharmonization: 0.4,
                darkness: 0.6,
                tension: 0.6,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0,
                reverb: 0.5,
                delay: 0.2,
                lofi: 0,
                compression: 0.4,
                stereoWidth: 0.7,
                brightness: 0.5
            ),
            tempoRange: 90...130,
            moodTags: ["dramatic", "passionate", "latin", "intense", "romantic"]
        )
    }

    // MARK: - Electronic

    /// Lo-fi chill: relaxed, vinyl-textured, nostalgic.
    public static var lofiChill: VibeProfileComponent {
        VibeProfileComponent(
            id: .lofiChill,
            name: "Lo-Fi Chill",
            description: "Relaxed, vinyl-textured beats for mellow vibes",
            category: .electronic,
            instrumentation: InstrumentationProfile(
                drumStyle: .lofi,
                bassStyle: .electric,
                leadInstruments: [.electricPiano, .piano],
                padInstruments: [.synth],
                includePercussion: false,
                maxSimultaneousInstruments: 4
            ),
            rhythmProfile: RhythmProfile(
                swing: 0.4,
                syncopation: 0.3,
                complexity: 0.3,
                includeBreaks: false,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.3,
                reharmonization: 0.5,
                darkness: 0.4,
                tension: 0.2,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0.1,
                reverb: 0.4,
                delay: 0.3,
                lofi: 0.7,
                compression: 0.5,
                stereoWidth: 0.6,
                brightness: 0.3
            ),
            tempoRange: 70...90,
            moodTags: ["chill", "relaxed", "nostalgic", "mellow", "study"]
        )
    }

    /// Synthwave: retro, 80s-inspired, neon.
    public static var synthwave: VibeProfileComponent {
        VibeProfileComponent(
            id: .synthwave,
            name: "Synthwave",
            description: "Retro 80s-inspired electronic with driving synths",
            category: .electronic,
            instrumentation: InstrumentationProfile(
                drumStyle: .electronic,
                bassStyle: .synth,
                leadInstruments: [.synth],
                padInstruments: [.synth],
                includePercussion: false,
                maxSimultaneousInstruments: 5
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0.3,
                complexity: 0.4,
                includeBreaks: true,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.4,
                reharmonization: 0.3,
                darkness: 0.5,
                tension: 0.4,
                addSuspensions: false
            ),
            productionProfile: ProductionProfile(
                distortion: 0.2,
                reverb: 0.5,
                delay: 0.4,
                lofi: 0,
                compression: 0.6,
                stereoWidth: 0.8,
                brightness: 0.6
            ),
            tempoRange: 100...130,
            moodTags: ["retro", "80s", "neon", "driving", "nostalgic"]
        )
    }

    /// Electronic minimal: clean, sparse, modern.
    public static var electronicMinimal: VibeProfileComponent {
        VibeProfileComponent(
            id: .electronicMinimal,
            name: "Electronic Minimal",
            description: "Clean, sparse electronic textures",
            category: .electronic,
            instrumentation: InstrumentationProfile(
                drumStyle: .electronic,
                bassStyle: .synth,
                leadInstruments: [.synth],
                padInstruments: [.synth],
                includePercussion: true,
                maxSimultaneousInstruments: 4
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0.4,
                complexity: 0.5,
                includeBreaks: true,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.6,
                reharmonization: 0.2,
                darkness: 0.5,
                tension: 0.3,
                addSuspensions: false
            ),
            productionProfile: ProductionProfile(
                distortion: 0,
                reverb: 0.3,
                delay: 0.3,
                lofi: 0,
                compression: 0.5,
                stereoWidth: 0.7,
                brightness: 0.6
            ),
            tempoRange: 110...130,
            moodTags: ["minimal", "clean", "modern", "sparse"]
        )
    }

    // MARK: - Classical

    /// Classical strings: orchestral, elegant, timeless.
    public static var classicalStrings: VibeProfileComponent {
        VibeProfileComponent(
            id: .classicalStrings,
            name: "Classical Strings",
            description: "Elegant string ensemble arrangements",
            category: .classical,
            instrumentation: InstrumentationProfile(
                drumStyle: .none,
                bassStyle: .orchestral,
                leadInstruments: [.violin, .cello],
                padInstruments: [.strings],
                includePercussion: false,
                maxSimultaneousInstruments: 6
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0.1,
                complexity: 0.5,
                includeBreaks: false,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0,
                reharmonization: 0.2,
                darkness: 0.4,
                tension: 0.4,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0,
                reverb: 0.6,
                delay: 0.1,
                lofi: 0,
                compression: 0.2,
                stereoWidth: 0.8,
                brightness: 0.5
            ),
            tempoRange: 60...120,
            moodTags: ["elegant", "classical", "timeless", "refined"]
        )
    }

    /// Baroque harpsichord: ornate, period-authentic, delicate.
    public static var baroqueHarpsichord: VibeProfileComponent {
        VibeProfileComponent(
            id: .baroqueHarpsichord,
            name: "Baroque Harpsichord",
            description: "Ornate baroque-style harpsichord arrangements",
            category: .classical,
            instrumentation: InstrumentationProfile(
                drumStyle: .none,
                bassStyle: .none,
                leadInstruments: [.harpsichord],
                padInstruments: [],
                includePercussion: false,
                maxSimultaneousInstruments: 2
            ),
            rhythmProfile: RhythmProfile(
                swing: 0.1,
                syncopation: 0.2,
                complexity: 0.6,
                includeBreaks: false,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0,
                reharmonization: 0.1,
                darkness: 0.3,
                tension: 0.3,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0,
                reverb: 0.5,
                delay: 0.1,
                lofi: 0,
                compression: 0.1,
                stereoWidth: 0.6,
                brightness: 0.6
            ),
            tempoRange: 80...130,
            moodTags: ["baroque", "ornate", "delicate", "historical"]
        )
    }

    // MARK: - Jazz

    /// Jazz lounge: smooth, sophisticated, relaxed.
    public static var jazzLounge: VibeProfileComponent {
        VibeProfileComponent(
            id: .jazzLounge,
            name: "Jazz Lounge",
            description: "Smooth, sophisticated jazz for relaxed atmospheres",
            category: .jazz,
            instrumentation: InstrumentationProfile(
                drumStyle: .acoustic,
                bassStyle: .acoustic,
                leadInstruments: [.piano, .saxophone],
                padInstruments: [],
                includePercussion: false,
                maxSimultaneousInstruments: 4
            ),
            rhythmProfile: RhythmProfile(
                swing: 0.6,
                syncopation: 0.5,
                complexity: 0.5,
                includeBreaks: true,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0,
                reharmonization: 0.7,
                darkness: 0.4,
                tension: 0.5,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0,
                reverb: 0.4,
                delay: 0.1,
                lofi: 0.1,
                compression: 0.3,
                stereoWidth: 0.7,
                brightness: 0.4
            ),
            tempoRange: 80...130,
            moodTags: ["smooth", "sophisticated", "relaxed", "classy"]
        )
    }

    // MARK: - Ambient

    /// Ambient pad: atmospheric, floating, meditative.
    public static var ambientPad: VibeProfileComponent {
        VibeProfileComponent(
            id: .ambientPad,
            name: "Ambient Pad",
            description: "Floating, atmospheric textures for background ambiance",
            category: .ambient,
            instrumentation: InstrumentationProfile(
                drumStyle: .none,
                bassStyle: .none,
                leadInstruments: [],
                padInstruments: [.synth, .strings],
                includePercussion: false,
                maxSimultaneousInstruments: 3
            ),
            rhythmProfile: RhythmProfile(
                swing: 0,
                syncopation: 0,
                complexity: 0.1,
                includeBreaks: false,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.4,
                reharmonization: 0.3,
                darkness: 0.5,
                tension: 0.2,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0,
                reverb: 0.9,
                delay: 0.5,
                lofi: 0,
                compression: 0.2,
                stereoWidth: 1.0,
                brightness: 0.4
            ),
            tempoRange: 60...80,
            moodTags: ["atmospheric", "floating", "meditative", "calm", "spacious"]
        )
    }

    // MARK: - Folk

    /// Acoustic folk: organic, warm, intimate.
    public static var acousticFolk: VibeProfileComponent {
        VibeProfileComponent(
            id: .acousticFolk,
            name: "Acoustic Folk",
            description: "Organic, warm acoustic arrangements",
            category: .folk,
            instrumentation: InstrumentationProfile(
                drumStyle: .acoustic,
                bassStyle: .acoustic,
                leadInstruments: [.acousticGuitar],
                padInstruments: [],
                includePercussion: true,
                maxSimultaneousInstruments: 4
            ),
            rhythmProfile: RhythmProfile(
                swing: 0.2,
                syncopation: 0.2,
                complexity: 0.3,
                includeBreaks: true,
                timeSignature: .fourFour
            ),
            harmonyProfile: HarmonyProfile(
                simplification: 0.3,
                reharmonization: 0.2,
                darkness: 0.3,
                tension: 0.2,
                addSuspensions: true
            ),
            productionProfile: ProductionProfile(
                distortion: 0,
                reverb: 0.3,
                delay: 0.1,
                lofi: 0,
                compression: 0.3,
                stereoWidth: 0.6,
                brightness: 0.5
            ),
            tempoRange: 90...130,
            moodTags: ["organic", "warm", "intimate", "natural", "heartfelt"]
        )
    }
}

// MARK: - Vibe Profile Registry Implementation

/// Default implementation of VibeProfileRegistry using built-in profiles.
public actor DefaultVibeProfileRegistry: VibeProfileRegistry {
    private var profiles: [VibeProfileId: VibeProfileComponent]

    public init() {
        var map: [VibeProfileId: VibeProfileComponent] = [:]
        for profile in BuiltInVibeProfiles.all {
            map[profile.id] = profile
        }
        self.profiles = map
    }

    public func profile(for id: VibeProfileId) async -> VibeProfileComponent? {
        profiles[id]
    }

    public func allProfiles() async -> [VibeProfileComponent] {
        Array(profiles.values)
    }

    public func profilesInCategory(_ category: VibeCategory) async -> [VibeProfileComponent] {
        profiles.values.filter { $0.category == category }
    }

    public func registerCustomProfile(_ profile: VibeProfileComponent) {
        profiles[profile.id] = profile
    }
}
