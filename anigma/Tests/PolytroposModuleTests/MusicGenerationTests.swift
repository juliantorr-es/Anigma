//
//  MusicGenerationTests.swift
//  PolytroposModuleTests
//
//  Tests for the public-domain-based music generation system.
//

import Testing
import Foundation
@testable import PolytroposModule
@testable import AnigmaCore

@Suite("Music Generation Tests")
struct MusicGenerationTests {

    // MARK: - Component Tests

    @Test("MusicCueComponent initializes with defaults")
    func testMusicCueDefaults() {
        let cue = MusicCueComponent(
            timeRange: TimeRange(start: 0, end: 30),
            vibeProfileId: .cinematicEpic
        )

        #expect(cue.intensity == 0.5)
        #expect(cue.complexity == 0.5)
        #expect(cue.autoDuck == true)
        #expect(cue.duckLevel == 0.3)
        #expect(cue.status == .pending)
        #expect(cue.generatedAssetId == nil)
    }

    @Test("MusicalKey displays correctly")
    func testMusicalKeyDisplay() {
        let cMajor = MusicalKey(root: .c, mode: .major)
        #expect(cMajor.displayName == "C major")

        let aMinor = MusicalKey(root: .a, mode: .minor)
        #expect(aMinor.displayName == "A minor")

        let dDorian = MusicalKey(root: .d, mode: .dorian)
        #expect(dDorian.displayName == "D dorian")
    }

    @Test("VibeProfileId built-in profiles exist")
    func testBuiltInVibeProfiles() {
        #expect(VibeProfileId.skaterPunk.raw == "skater_punk")
        #expect(VibeProfileId.emo.raw == "emo")
        #expect(VibeProfileId.cinematicEpic.raw == "cinematic_epic")
        #expect(VibeProfileId.novela.raw == "novela")
        #expect(VibeProfileId.lofiChill.raw == "lofi_chill")
    }

    @Test("TimeSignature common signatures")
    func testTimeSignatures() {
        #expect(TimeSignature.fourFour.numerator == 4)
        #expect(TimeSignature.fourFour.denominator == 4)
        #expect(TimeSignature.threeFour.numerator == 3)
        #expect(TimeSignature.sixEight.denominator == 8)
    }

    // MARK: - Vibe Profile Tests

    @Test("BuiltInVibeProfiles contains all expected profiles")
    func testBuiltInProfileCount() {
        let profiles = BuiltInVibeProfiles.all
        #expect(profiles.count == 15)
    }

    @Test("Skater punk profile has correct characteristics")
    func testSkaterPunkProfile() {
        let profile = BuiltInVibeProfiles.skaterPunk

        #expect(profile.id == .skaterPunk)
        #expect(profile.category == .rock)
        #expect(profile.tempoRange.lowerBound >= 160)
        #expect(profile.productionProfile.distortion >= 0.5)
        #expect(profile.harmonyProfile.simplification >= 0.7) // Power chords
        #expect(profile.moodTags.contains("energetic"))
    }

    @Test("Cinematic sad profile is appropriately melancholic")
    func testCinematicSadProfile() {
        let profile = BuiltInVibeProfiles.cinematicSad

        #expect(profile.category == .cinematic)
        #expect(profile.harmonyProfile.darkness >= 0.7)
        #expect(profile.tempoRange.upperBound <= 100)
        #expect(profile.instrumentation.drumStyle == .none)
        #expect(profile.moodTags.contains("melancholic"))
    }

    @Test("Novela profile has Latin characteristics")
    func testNovelaProfile() {
        let profile = BuiltInVibeProfiles.novela

        #expect(profile.category == .latin)
        #expect(profile.instrumentation.drumStyle == .latin)
        #expect(profile.instrumentation.leadInstruments.contains(.nylonGuitar))
        #expect(profile.rhythmProfile.syncopation >= 0.4)
    }

    @Test("Lo-fi chill profile has correct production settings")
    func testLofiChillProfile() {
        let profile = BuiltInVibeProfiles.lofiChill

        #expect(profile.productionProfile.lofi >= 0.5)
        #expect(profile.rhythmProfile.swing >= 0.3)
        #expect(profile.tempoRange.upperBound <= 100)
    }

    // MARK: - Registry Tests

    @Test("DefaultVibeProfileRegistry contains all built-in profiles")
    func testDefaultRegistry() async {
        let registry = DefaultVibeProfileRegistry()

        let allProfiles = await registry.allProfiles()
        #expect(allProfiles.count == 15)

        let skater = await registry.profile(for: .skaterPunk)
        #expect(skater != nil)
        #expect(skater?.name == "Skater Punk")
    }

    @Test("Registry filters by category")
    func testRegistryCategoryFilter() async {
        let registry = DefaultVibeProfileRegistry()

        let rockProfiles = await registry.profilesInCategory(.rock)
        #expect(rockProfiles.count >= 3) // skater, emo, post-rock, driving

        let electronicProfiles = await registry.profilesInCategory(.electronic)
        #expect(electronicProfiles.count >= 2) // lofi, synthwave, minimal
    }

    @Test("Registry allows custom profile registration")
    func testCustomProfileRegistration() async {
        let registry = DefaultVibeProfileRegistry()

        let customProfile = VibeProfileComponent(
            id: VibeProfileId("custom_test"),
            name: "Custom Test",
            description: "A test profile",
            category: .custom,
            instrumentation: InstrumentationProfile(),
            rhythmProfile: RhythmProfile(),
            harmonyProfile: HarmonyProfile(),
            productionProfile: ProductionProfile(),
            isBuiltIn: false,
            createdBy: "test_user"
        )

        await registry.registerCustomProfile(customProfile)

        let retrieved = await registry.profile(for: VibeProfileId("custom_test"))
        #expect(retrieved != nil)
        #expect(retrieved?.isBuiltIn == false)
    }

    // MARK: - Symbolic Source Tests

    @Test("SymbolicSourceComponent tracks public domain status")
    func testSymbolicSourcePD() {
        let source = SymbolicSourceComponent(
            id: "bach_minuet_g",
            sourceType: .midi,
            corpus: "pdmx",
            originalTitle: "Minuet in G Major",
            originalComposer: "J.S. Bach",
            compositionYear: 1725,
            licenseStatus: .publicDomain,
            duration: 120,
            key: MusicalKey(root: .g, mode: .major),
            tempo: 120,
            timeSignature: TimeSignature.threeFour,
            tags: ["baroque", "dance", "classical"],
            dataStorageKey: "sources/bach/minuet_g.mid"
        )

        #expect(source.licenseStatus == .publicDomain)
        #expect(source.compositionYear! < 1930) // Definitely PD
        #expect(source.timeSignature == .threeFour)
    }

    // MARK: - User Instrument Kit Tests

    @Test("UserInstrumentKitComponent manages sample mappings")
    func testUserInstrumentKit() {
        var kit = UserInstrumentKitComponent(
            name: "My Drums",
            category: .drums
        )

        #expect(kit.isComplete == false)
        #expect(kit.samples.isEmpty)

        let kickMapping = SampleMapping(
            trigger: 36, // MIDI note for kick
            label: "Kick",
            audioAssetId: EntityId(),
            endTime: 0.5
        )

        kit.samples.append(kickMapping)
        #expect(kit.samples.count == 1)
    }

    // MARK: - Music Generation Job Tests

    @Test("MusicGenerationJobComponent lifecycle")
    func testJobLifecycle() {
        var job = MusicGenerationJobComponent(
            cueEntityId: EntityId(),
            projectEntityId: EntityId()
        )

        #expect(job.status == .queued)
        #expect(job.progress == 0)
        #expect(job.currentStage == .queued)

        // Simulate running
        job.status = .running
        job.startedAt = Date()
        job.currentStage = .selectingSource
        job.progress = 0.2

        #expect(job.status == .running)
        #expect(job.startedAt != nil)

        // Simulate completion
        job.status = .completed
        job.completedAt = Date()
        job.currentStage = .completed
        job.progress = 1.0
        job.outputAssetId = EntityId()

        #expect(job.status == .completed)
        #expect(job.outputAssetId != nil)
    }

    // MARK: - Provenance Tests

    @Test("MusicProvenance tracks generation details")
    func testProvenance() {
        let provenance = MusicProvenance(
            symbolicSourceId: "bach_minuet_g",
            originalComposition: "Minuet in G Major - J.S. Bach",
            vibeProfileId: .skaterPunk,
            userKitId: nil,
            generatorVersion: "1.0.0",
            transformerVersion: "1.0.0",
            rendererVersion: "1.0.0",
            parameters: [
                "tempo": "180",
                "key": "E minor"
            ]
        )

        #expect(provenance.symbolicSourceId == "bach_minuet_g")
        #expect(provenance.vibeProfileId == .skaterPunk)
        #expect(provenance.parameters["tempo"] == "180")
    }

    // MARK: - Learning Integration Tests

    @Test("MusicLearningObserver buffers interactions")
    func testLearningObserver() async {
        var flushedCount = 0

        let observer = MusicLearningObserver(maxBufferSize: 3) { interactions in
            flushedCount = interactions.count
        }

        let projectId = PolytroposProjectId()
        let context = MusicLearningObserver.MusicInteractionContext(
            vibeProfileId: .skaterPunk,
            symbolicSourceId: "test",
            tempo: 180,
            key: MusicalKey(root: .e, mode: .minor),
            intensity: 0.7,
            complexity: 0.5,
            sceneDuration: 30
        )

        // Record interactions (should buffer until 3)
        await observer.recordGeneration(projectId: projectId, cueId: UUID(), context: context)
        await observer.recordGeneration(projectId: projectId, cueId: UUID(), context: context)

        // Manual flush
        await observer.flush()
        #expect(flushedCount == 2)
    }

    @Test("MusicLearningTrainer computes preferences")
    func testLearningTrainer() async {
        let trainer = MusicLearningTrainer()

        let projectId = PolytroposProjectId()
        let context = MusicLearningObserver.MusicInteractionContext(
            vibeProfileId: .skaterPunk,
            symbolicSourceId: "test",
            tempo: 180,
            key: MusicalKey(root: .e, mode: .minor),
            intensity: 0.5,
            complexity: 0.5,
            sceneDuration: 30,
            eventType: .concert
        )

        // Simulate some interactions
        let interactions: [MusicLearningObserver.MusicInteraction] = [
            MusicLearningObserver.MusicInteraction(
                timestamp: Date(),
                projectId: projectId,
                cueId: UUID(),
                interactionType: .accepted,
                context: context,
                outcome: MusicLearningObserver.MusicInteractionOutcome(wasAccepted: true)
            ),
            MusicLearningObserver.MusicInteraction(
                timestamp: Date(),
                projectId: projectId,
                cueId: UUID(),
                interactionType: .accepted,
                context: context,
                outcome: MusicLearningObserver.MusicInteractionOutcome(wasAccepted: true)
            ),
            MusicLearningObserver.MusicInteraction(
                timestamp: Date(),
                projectId: projectId,
                cueId: UUID(),
                interactionType: .rejected,
                context: context,
                outcome: MusicLearningObserver.MusicInteractionOutcome(wasAccepted: false)
            )
        ]

        await trainer.processBatch(interactions)

        let prefs = await trainer.preferences(for: .skaterPunk)
        #expect(prefs != nil)
        // 2 accepted, 1 rejected = 66.7% acceptance
        #expect(prefs!.acceptanceRate > 0.6)
        #expect(prefs!.sampleCount == 3)
    }

    @Test("Trainer recommends vibes for event types")
    func testVibeRecommendations() async {
        let trainer = MusicLearningTrainer()

        let projectId = PolytroposProjectId()

        // Train with concert events preferring skater punk
        let skaterContext = MusicLearningObserver.MusicInteractionContext(
            vibeProfileId: .skaterPunk,
            symbolicSourceId: "test",
            tempo: 180,
            key: MusicalKey(root: .e, mode: .minor),
            intensity: 0.7,
            complexity: 0.5,
            sceneDuration: 30,
            eventType: .concert
        )

        let interactions = (0..<5).map { _ in
            MusicLearningObserver.MusicInteraction(
                timestamp: Date(),
                projectId: projectId,
                cueId: UUID(),
                interactionType: .accepted,
                context: skaterContext,
                outcome: MusicLearningObserver.MusicInteractionOutcome(wasAccepted: true)
            )
        }

        await trainer.processBatch(interactions)

        let recommendations = await trainer.recommendedVibes(for: .concert, limit: 3)
        #expect(recommendations.contains(.skaterPunk))
    }

    // MARK: - Project Settings Tests

    @Test("ProjectMusicSettingsComponent defaults")
    func testProjectMusicSettings() {
        let settings = ProjectMusicSettingsComponent()

        #expect(settings.autoGenerateMusic == false)
        #expect(settings.autoDuck == true)
        #expect(settings.duckLevel == 0.3)
        #expect(settings.defaultVibeProfile == .cinematicEpic)
    }

    // MARK: - Data Type Tests

    @Test("SymbolicNote represents MIDI data")
    func testSymbolicNote() {
        let note = SymbolicNote(
            pitch: 60, // Middle C
            velocity: 100,
            startTime: 0,
            duration: 0.5,
            channel: 0
        )

        #expect(note.pitch == 60)
        #expect(note.velocity == 100)
        #expect(note.duration == 0.5)
    }

    @Test("ArrangementData structures arrangement")
    func testArrangementData() {
        var arrangement = ArrangementData(
            tempo: 120,
            timeSignature: .fourFour,
            duration: 60
        )

        let drumTrack = ArrangementTrack(
            name: "Drums",
            instrumentType: .custom,
            stemType: .drums,
            events: [
                ArrangementEvent(
                    type: .drumHit(trigger: 36, velocity: 100),
                    time: 0,
                    duration: 0.1
                )
            ]
        )

        arrangement.tracks.append(drumTrack)

        #expect(arrangement.tracks.count == 1)
        #expect(arrangement.tracks[0].stemType == .drums)
    }
}
