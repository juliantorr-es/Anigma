//
//  PolytroposModuleTests.swift
//  PolytroposModuleTests
//
//  Tests for the Polytropos video processing module.
//

import XCTest
@testable import AnigmaCore
@testable import PolytroposModule

final class PolytroposModuleTests: XCTestCase {

    var world: World!
    var registry: WorkflowRegistry!
    var runner: WorkflowRunner!

    override func setUp() async throws {
        world = World()
        registry = WorkflowRegistry()
        runner = WorkflowRunner(registry: registry)

        try await PolytroposModule.register(
            world: world,
            registry: registry,
            runner: runner
        )
    }

    // MARK: - Project Tests

    func testProjectCreation() async {
        let entityId = await world.createEntity()

        let project = ProjectComponent(
            name: "Test Show",
            eventDate: Date(),
            venue: "The Venue",
            performers: ["Artist 1", "Artist 2"]
        )
        await world.addComponent(entityId, project)

        let retrieved = await world.getComponent(entityId, ProjectComponent.self)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Test Show")
        XCTAssertEqual(retrieved?.performers.count, 2)
        XCTAssertEqual(retrieved?.status, .created)
    }

    func testProjectReferences() async {
        let projectId = await world.createEntity()

        var refs = ProjectReferencesComponent()

        // Add some asset references
        let asset1 = await world.createEntity()
        let asset2 = await world.createEntity()
        refs.mediaAssetIds = [asset1, asset2]

        await world.addComponent(projectId, refs)

        let retrieved = await world.getComponent(projectId, ProjectReferencesComponent.self)
        XCTAssertEqual(retrieved?.mediaAssetIds.count, 2)
    }

    // MARK: - Media Asset Tests

    func testMediaAssetComponent() async {
        let entityId = await world.createEntity()

        let asset = MediaAssetComponent(
            originalPath: "/path/to/video.mp4",
            mediaType: .video,
            deviceLabel: "Camera A"
        )
        await world.addComponent(entityId, asset)

        let retrieved = await world.getComponent(entityId, MediaAssetComponent.self)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.mediaType, .video)
        XCTAssertEqual(retrieved?.status, .pending)
    }

    func testVideoMetadata() async {
        let entityId = await world.createEntity()

        let metadata = VideoMetadataComponent(
            width: 1920,
            height: 1080,
            codec: "H.264",
            isHDR: false
        )
        await world.addComponent(entityId, metadata)

        let retrieved = await world.getComponent(entityId, VideoMetadataComponent.self)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved!.aspectRatio, 16.0 / 9.0, accuracy: 0.001)
        XCTAssertFalse(retrieved?.isVertical ?? true)
    }

    func testVerticalVideoDetection() {
        let vertical = VideoMetadataComponent(width: 1080, height: 1920, isHDR: false)
        XCTAssertTrue(vertical.isVertical)

        let horizontal = VideoMetadataComponent(width: 1920, height: 1080, isHDR: false)
        XCTAssertFalse(horizontal.isVertical)
    }

    // MARK: - Multicam Tests

    func testMulticamCluster() async {
        let asset1 = await world.createEntity()
        let asset2 = await world.createEntity()
        let clusterId = await world.createEntity()

        let cluster = MulticamClusterComponent(
            name: "Song 1",
            assetIds: [asset1, asset2],
            referenceAssetId: asset1,
            clusterStartTime: 0,
            clusterEndTime: 180
        )
        await world.addComponent(clusterId, cluster)

        let retrieved = await world.getComponent(clusterId, MulticamClusterComponent.self)
        XCTAssertEqual(retrieved?.duration, 180)
        XCTAssertEqual(retrieved?.assetIds.count, 2)
    }

    func testSyncData() async {
        let assetId = await world.createEntity()

        let sync = SyncDataComponent(
            clusterId: UUID(),
            offsetFromReference: 0.5,
            confidence: 0.95,
            syncMethod: .audio,
            manualAdjustment: -0.1
        )
        await world.addComponent(assetId, sync)

        let retrieved = await world.getComponent(assetId, SyncDataComponent.self)
        XCTAssertEqual(retrieved!.effectiveOffset, 0.4, accuracy: 0.001)
    }

    // MARK: - Analysis Tests

    func testTimeRange() {
        let range = TimeRange(start: 10, end: 20)

        XCTAssertEqual(range.duration, 10)
        XCTAssertTrue(range.contains(15))
        XCTAssertFalse(range.contains(5))
        XCTAssertFalse(range.contains(25))
    }

    func testTimeRangeOverlap() {
        let range1 = TimeRange(start: 0, end: 10)
        let range2 = TimeRange(start: 5, end: 15)
        let range3 = TimeRange(start: 20, end: 30)

        XCTAssertTrue(range1.overlaps(range2))
        XCTAssertFalse(range1.overlaps(range3))
    }

    func testFrameAnalysisQualityScore() {
        let goodFrame = FrameAnalysis(
            time: 0,
            sharpness: 0.9,
            motionMagnitude: 0.1,
            exposure: 0.5,
            contrast: 0.8,
            frameSceneType: .stage
        )

        let badFrame = FrameAnalysis(
            time: 1,
            sharpness: 0.3,
            motionMagnitude: 0.8,
            exposure: 0.9,
            contrast: 0.3,
            frameSceneType: .unknown
        )

        XCTAssertGreaterThan(goodFrame.qualityScore, badFrame.qualityScore)
    }

    // MARK: - Timeline Tests

    func testTimelineCreation() async {
        let timelineId = await world.createEntity()

        let timeline = TimelineComponent(
            name: "Main Edit",
            duration: 180,
            frameRate: 30,
            aspectRatio: .horizontal16x9
        )
        await world.addComponent(timelineId, timeline)

        let retrieved = await world.getComponent(timelineId, TimelineComponent.self)
        XCTAssertEqual(retrieved!.aspectRatio.ratio, 16.0 / 9.0, accuracy: 0.001)
    }

    func testClipSegment() async {
        let assetId = await world.createEntity()

        let segment = ClipSegment(
            sourceAssetId: assetId,
            sourceIn: 10,
            sourceOut: 20,
            timelineIn: 0
        )

        XCTAssertEqual(segment.sourceDuration, 10)
        XCTAssertEqual(segment.timelineDuration, 10)
        XCTAssertEqual(segment.timelineOut, 10)
    }

    func testAspectRatios() {
        XCTAssertEqual(AspectRatio.horizontal16x9.ratio, 16.0 / 9.0, accuracy: 0.001)
        XCTAssertEqual(AspectRatio.vertical9x16.ratio, 9.0 / 16.0, accuracy: 0.001)
        XCTAssertEqual(AspectRatio.square1x1.ratio, 1.0)

        XCTAssertFalse(AspectRatio.horizontal16x9.isVertical)
        XCTAssertTrue(AspectRatio.vertical9x16.isVertical)
    }

    // MARK: - Scene Tests

    func testSceneComponent() async {
        let sceneId = await world.createEntity()

        let scene = SceneComponent(
            name: "Opening Number",
            sceneType: .number,
            sourceRange: TimeRange(start: 0, end: 180),
            status: .detected,
            includeInExport: true
        )
        await world.addComponent(sceneId, scene)

        let retrieved = await world.getComponent(sceneId, SceneComponent.self)
        XCTAssertEqual(retrieved?.sceneType, .number)
        XCTAssertEqual(retrieved?.sourceRange.duration, 180)
    }

    // MARK: - Branding Tests

    func testBrandingProfile() async {
        let brandingId = await world.createEntity()

        let branding = BrandingProfileComponent(
            name: "Artist Brand",
            primaryColor: "#FF0000",
            secondaryColor: "#00FF00"
        )
        await world.addComponent(brandingId, branding)

        let retrieved = await world.getComponent(brandingId, BrandingProfileComponent.self)
        XCTAssertEqual(retrieved?.primaryColor, "#FF0000")
    }

    func testCaptionStyle() async {
        let styleId = await world.createEntity()

        let style = CaptionStyleComponent(
            style: .modern,
            fontSize: 48,
            textColor: "#FFFFFF"
        )
        await world.addComponent(styleId, style)

        let retrieved = await world.getComponent(styleId, CaptionStyleComponent.self)
        XCTAssertEqual(retrieved?.style, .modern)
    }

    // MARK: - Export Tests

    func testExportPreset() async {
        let presetId = await world.createEntity()

        let preset = ExportPresetComponent(
            name: "TikTok",
            platform: .tiktok,
            resolution: .vertical1080,
            videoCodec: .h264
        )
        await world.addComponent(presetId, preset)

        let retrieved = await world.getComponent(presetId, ExportPresetComponent.self)
        XCTAssertEqual(retrieved?.platform, .tiktok)
        XCTAssertEqual(retrieved?.resolution.width, 1080)
        XCTAssertEqual(retrieved?.resolution.height, 1920)
    }

    func testSystemPresets() {
        let presets = SystemExportPresets.allPresets

        XCTAssertGreaterThan(presets.count, 0)
        XCTAssertTrue(presets.allSatisfy { $0.isSystemPreset })

        // Check TikTok preset
        let tiktok = SystemExportPresets.tiktokVertical
        XCTAssertEqual(tiktok.platform, .tiktok)
        XCTAssertEqual(tiktok.resolution.width, 1080)
        XCTAssertEqual(tiktok.resolution.height, 1920)
    }

    func testExportPlatformDefaults() {
        XCTAssertEqual(ExportPlatform.youtube.defaultAspectRatio, .horizontal16x9)
        XCTAssertEqual(ExportPlatform.tiktok.defaultAspectRatio, .vertical9x16)
        XCTAssertEqual(ExportPlatform.instagram.defaultAspectRatio, .square1x1)

        XCTAssertNil(ExportPlatform.youtube.maxDuration)
        XCTAssertEqual(ExportPlatform.youtubeShorts.maxDuration, 60)
        XCTAssertEqual(ExportPlatform.tiktok.maxDuration, 180)
    }

    // MARK: - Transcript Tests

    func testTranscriptComponent() async {
        let transcriptId = await world.createEntity()

        let transcript = TranscriptComponent(
            languageCode: "en",
            segments: [
                TranscriptSegment(
                    startTime: 0,
                    endTime: 5,
                    text: "Hello world",
                    confidence: 0.95
                )
            ],
            confidence: 0.9
        )
        await world.addComponent(transcriptId, transcript)

        let retrieved = await world.getComponent(transcriptId, TranscriptComponent.self)
        XCTAssertEqual(retrieved?.fullText, "Hello world")
        XCTAssertEqual(retrieved?.duration, 5)
    }

    // MARK: - Event Type Tests

    func testEventTypeHints() {
        let concertHints = EventType.concert.editProfileHints
        XCTAssertEqual(concertHints.preferredCutDensity, .high)
        XCTAssertTrue(concertHints.beatAlignCuts)

        let talkHints = EventType.talk.editProfileHints
        XCTAssertEqual(talkHints.preferredCutDensity, .low)
        XCTAssertFalse(talkHints.beatAlignCuts)
    }

    func testCutDensitySettings() {
        XCTAssertGreaterThan(CutDensity.veryLow.targetShotLength, CutDensity.low.targetShotLength)
        XCTAssertGreaterThan(CutDensity.low.targetShotLength, CutDensity.medium.targetShotLength)
        XCTAssertGreaterThan(CutDensity.medium.targetShotLength, CutDensity.high.targetShotLength)

        XCTAssertGreaterThan(CutDensity.veryLow.minimumShotLength, CutDensity.veryHigh.minimumShotLength)
    }

    // MARK: - Workflow Registration Tests

    func testWorkflowRegistration() async {
        let fullEvent = await registry.workflow(for: PolytroposJobType.fullEvent)
        XCTAssertNotNil(fullEvent)
        XCTAssertEqual(fullEvent?.name, "Full Event Processing")

        let quickClip = await registry.workflow(for: PolytroposJobType.quickClip)
        XCTAssertNotNil(quickClip)

        let reExport = await registry.workflow(for: PolytroposJobType.reExport)
        XCTAssertNotNil(reExport)
    }

    func testFullEventWorkflowSystems() async {
        let workflow = await registry.workflow(for: PolytroposJobType.fullEvent)

        XCTAssertTrue(workflow?.systemNames.contains("MediaIngest") ?? false)
        XCTAssertTrue(workflow?.systemNames.contains("AudioSync") ?? false)
        XCTAssertTrue(workflow?.systemNames.contains("AutoEdit") ?? false)
        XCTAssertTrue(workflow?.systemNames.contains("Caption") ?? false)
        XCTAssertTrue(workflow?.systemNames.contains("Reframe") ?? false)
    }

    // MARK: - Reframe Tests

    func testReframeKeyframe() {
        let keyframe = ReframeKeyframe(
            time: 0,
            centerX: 0.6,
            centerY: 0.4,
            scale: 1.5,
            easing: .smooth
        )

        XCTAssertEqual(keyframe.centerX, 0.6)
        XCTAssertEqual(keyframe.scale, 1.5)
    }

    // MARK: - Camera Classification Tests

    func testCameraClassification() async {
        let assetId = await world.createEntity()

        let classification = CameraClassificationComponent(
            angleType: .close,
            subjectCoverage: .performer,
            stabilityRating: .veryStable,
            qualityScore: 0.9,
            classificationConfidence: 0.85
        )
        await world.addComponent(assetId, classification)

        let retrieved = await world.getComponent(assetId, CameraClassificationComponent.self)
        XCTAssertEqual(retrieved?.angleType, .close)
        XCTAssertEqual(retrieved?.stabilityRating, .veryStable)
    }

    // MARK: - Edit Profile Tests

    func testEditProfileCreation() {
        let profile = EditProfile(
            name: "Test Profile",
            description: "A test profile",
            suitableEventTypes: [.concert, .djSet],
            timing: .fast,
            musicAlignment: .strict
        )

        XCTAssertEqual(profile.name, "Test Profile")
        XCTAssertEqual(profile.suitableEventTypes.count, 2)
        XCTAssertEqual(profile.timing.targetShotLength, 2.0)
        XCTAssertTrue(profile.musicAlignment.alignToBeats)
    }

    func testSystemEditProfiles() {
        let profiles = SystemEditProfiles.allProfiles
        XCTAssertGreaterThan(profiles.count, 0)

        // Concert profile
        let concert = SystemEditProfiles.concert
        XCTAssertEqual(concert.timing.targetShotLength, 2.0)
        XCTAssertTrue(concert.musicAlignment.alignToBeats)
        XCTAssertTrue(concert.crowdBehavior.enabled)

        // Talk profile should be slower
        let talk = SystemEditProfiles.talk
        XCTAssertEqual(talk.timing.targetShotLength, 8.0)
        XCTAssertFalse(talk.crowdBehavior.enabled)

        // Theater should be even slower
        let theater = SystemEditProfiles.theater
        XCTAssertGreaterThan(theater.timing.targetShotLength, talk.timing.targetShotLength)
    }

    func testEditProfileForEventType() {
        XCTAssertEqual(SystemEditProfiles.profileFor(eventType: .concert).name, "Concert / Music")
        XCTAssertEqual(SystemEditProfiles.profileFor(eventType: .talk).name, "Talk / Keynote")
        XCTAssertEqual(SystemEditProfiles.profileFor(eventType: .comedy).name, "Comedy / Stand-up")
    }

    func testCutTimingProfiles() {
        // Fast should have shorter shots than slow
        XCTAssertLessThan(CutTimingProfile.fast.targetShotLength, CutTimingProfile.slow.targetShotLength)
        XCTAssertLessThan(CutTimingProfile.fast.minimumShotLength, CutTimingProfile.slow.minimumShotLength)

        // Default should be in between
        XCTAssertGreaterThan(CutTimingProfile.default.targetShotLength, CutTimingProfile.fast.targetShotLength)
        XCTAssertLessThan(CutTimingProfile.default.targetShotLength, CutTimingProfile.slow.targetShotLength)
    }

    func testMusicAlignmentProfiles() {
        XCTAssertTrue(MusicAlignmentProfile.strict.alignToBeats)
        XCTAssertGreaterThan(MusicAlignmentProfile.strict.alignmentStrength, MusicAlignmentProfile.loose.alignmentStrength)
        XCTAssertLessThan(MusicAlignmentProfile.strict.beatSnapTolerance, MusicAlignmentProfile.loose.beatSnapTolerance)
    }

    func testCrowdShotProfiles() {
        XCTAssertTrue(CrowdShotProfile.default.enabled)
        XCTAssertFalse(CrowdShotProfile.disabled.enabled)
        XCTAssertGreaterThan(
            CrowdShotProfile.aggressive.maxCrowdPercentage,
            CrowdShotProfile.default.maxCrowdPercentage
        )
    }

    func testEnergyMappingProfiles() {
        // Flat profile should have no dynamic adjustments
        XCTAssertFalse(EnergyMappingProfile.flat.dynamicCutDensity)
        XCTAssertEqual(EnergyMappingProfile.flat.lowEnergyMultiplier, 1.0)
        XCTAssertEqual(EnergyMappingProfile.flat.highEnergyMultiplier, 1.0)

        // Default should have dynamic adjustments
        XCTAssertTrue(EnergyMappingProfile.default.dynamicCutDensity)
        XCTAssertGreaterThan(EnergyMappingProfile.default.lowEnergyMultiplier, 1.0)
        XCTAssertLessThan(EnergyMappingProfile.default.highEnergyMultiplier, 1.0)
    }

    func testTransitionProfiles() {
        XCTAssertEqual(TransitionProfile.cutsOnly.defaultTransition, .cut)
        XCTAssertFalse(TransitionProfile.cutsOnly.allowDissolves)

        XCTAssertTrue(TransitionProfile.default.allowDissolves)
        XCTAssertGreaterThan(TransitionProfile.default.dissolveDuration, 0)
    }

    func testEditProfileComponent() async {
        let entityId = await world.createEntity()

        let profile = EditProfile(
            name: "Custom",
            timing: .fast
        )
        let overrides = EditProfileOverrides(
            targetShotLength: 1.5,
            crowdEnabled: false
        )

        let component = EditProfileComponent(
            profile: profile,
            overrides: overrides
        )
        await world.addComponent(entityId, component)

        let retrieved = await world.getComponent(entityId, EditProfileComponent.self)
        XCTAssertEqual(retrieved?.profile.name, "Custom")
        XCTAssertEqual(retrieved?.overrides?.targetShotLength, 1.5)
        XCTAssertEqual(retrieved?.overrides?.crowdEnabled, false)
    }

    // MARK: - Audio Analysis Tests

    func testAudioAnalysisComponent() async {
        let assetId = await world.createEntity()

        let analysis = AudioAnalysisComponent(
            tempo: 120.0,
            beatOnsets: [0, 0.5, 1.0, 1.5, 2.0],
            structuralSegments: [
                AudioSegment(
                    range: TimeRange(start: 0, end: 30),
                    segmentType: .intro,
                    confidence: 0.85
                ),
                AudioSegment(
                    range: TimeRange(start: 30, end: 90),
                    segmentType: .verse,
                    confidence: 0.9
                )
            ],
            applauseIntervals: [
                TimeRange(start: 175, end: 180)
            ]
        )
        await world.addComponent(assetId, analysis)

        let retrieved = await world.getComponent(assetId, AudioAnalysisComponent.self)
        XCTAssertEqual(retrieved?.tempo, 120.0)
        XCTAssertEqual(retrieved?.beatOnsets.count, 5)
        XCTAssertEqual(retrieved?.structuralSegments.count, 2)
    }

    func testAudioSegmentTypes() {
        let segments: [AudioSegmentType] = [.intro, .verse, .chorus, .bridge, .outro]
        XCTAssertEqual(segments.count, 5)
    }

    // MARK: - Video Analysis Tests

    func testVideoAnalysisComponent() async {
        let assetId = await world.createEntity()

        let frames = (0..<10).map { i in
            FrameAnalysis(
                time: Double(i) * 0.5,
                sharpness: Float.random(in: 0.6...0.9),
                motionMagnitude: Float.random(in: 0...0.3),
                exposure: Float.random(in: 0.4...0.6),
                contrast: 0.7,
                saturation: 0.6,
                subjectCount: 1,
                frameSceneType: .stage
            )
        }

        let analysis = VideoAnalysisComponent(
            frameAnalysis: frames,
            windowSizeSeconds: 0.5,
            qualityAssessment: VideoQualityAssessment(
                overallScore: 0.85,
                averageSharpness: 0.75,
                stabilityScore: 0.9,
                exposureConsistency: 0.8,
                usablePercentage: 0.95
            )
        )
        await world.addComponent(assetId, analysis)

        let retrieved = await world.getComponent(assetId, VideoAnalysisComponent.self)
        XCTAssertEqual(retrieved?.frameAnalysis.count, 10)
        XCTAssertNotNil(retrieved?.qualityAssessment)
    }

    // MARK: - Waveform Tests

    func testWaveformComponent() async {
        let assetId = await world.createEntity()

        let samples = Array(repeating: Float(0.5), count: 1000)
        let waveform = WaveformComponent(
            samples: samples,
            samplesPerSecond: 100,
            peaks: samples,
            rmsValues: samples
        )
        await world.addComponent(assetId, waveform)

        let retrieved = await world.getComponent(assetId, WaveformComponent.self)
        XCTAssertEqual(retrieved?.legacyDuration ?? 0, 10.0, accuracy: 0.01)
        XCTAssertEqual(retrieved?.samples.count, 1000)
    }

    // MARK: - Speaker Diarization Tests

    func testSpeakerDiarization() async {
        let assetId = await world.createEntity()

        let diarization = SpeakerDiarizationComponent(
            speakers: [
                SpeakerInfo(id: "spk1", label: "Speaker 1", totalDuration: 60),
                SpeakerInfo(id: "spk2", label: "Speaker 2", totalDuration: 45)
            ],
            segments: [
                SpeakerSegment(speakerId: "spk1", range: TimeRange(start: 0, end: 30), confidence: 0.9),
                SpeakerSegment(speakerId: "spk2", range: TimeRange(start: 30, end: 60), confidence: 0.85)
            ]
        )
        await world.addComponent(assetId, diarization)

        let retrieved = await world.getComponent(assetId, SpeakerDiarizationComponent.self)
        XCTAssertEqual(retrieved?.speakers.count, 2)
        XCTAssertEqual(retrieved?.segments.count, 2)
    }
}
