//
//  PolytroposProTests.swift
//  PolytroposModuleTests
//
//  Tests/PolytroposModuleTests
//
//  Tests for Polytropos Pro v1 features.
//

import XCTest
import AnigmaTestSupport
@testable import AnigmaCore
@testable import PolytroposModule

final class PolytroposProTests: XCTestCase {

    // MARK: - Multi-Track Timeline Tests

    func testMultiTrackTimelineCreation() {
        let timeline = MultiTrackTimelineComponent(
            timelineId: EntityId(rawValue: 1),
            videoTracks: [VideoTrack(name: "V1"), VideoTrack(name: "V2")],
            audioTracks: [AudioTrack(name: "A1"), AudioTrack(name: "A2")]
        )

        XCTAssertEqual(timeline.videoTracks.count, 2)
        XCTAssertEqual(timeline.audioTracks.count, 2)
        XCTAssertEqual(timeline.videoTracks[0].name, "V1")
        XCTAssertEqual(timeline.audioTracks[1].name, "A2")
    }

    func testVideoTrackDefaults() {
        let track = VideoTrack()

        XCTAssertTrue(track.isVisible)
        XCTAssertFalse(track.isLocked)
        XCTAssertEqual(track.blendMode, .normal)
        XCTAssertEqual(track.opacity, 1.0)
        XCTAssertTrue(track.segments.isEmpty)
    }

    func testAudioTrackDefaults() {
        let track = AudioTrack()

        XCTAssertFalse(track.isMuted)
        XCTAssertFalse(track.isSolo)
        XCTAssertFalse(track.isLocked)
        XCTAssertEqual(track.volume, 1.0)
        XCTAssertEqual(track.pan, 0.0)
        XCTAssertEqual(track.routingBus, .master)
    }

    func testProClipSegmentTiming() {
        let clip = ProClipSegment(
            sourceAssetId: EntityId(rawValue: 1),
            sourceIn: 10.0,
            sourceOut: 20.0,
            timelineIn: 5.0,
            speed: 1.0
        )

        XCTAssertEqual(clip.timelineDuration, 10.0)
        XCTAssertEqual(clip.timelineOut, 15.0)
    }

    func testClipTransformIdentity() {
        let transform = ClipTransform.identity

        XCTAssertEqual(transform.positionX, 0)
        XCTAssertEqual(transform.positionY, 0)
        XCTAssertEqual(transform.scaleX, 1.0)
        XCTAssertEqual(transform.scaleY, 1.0)
        XCTAssertEqual(transform.rotation, 0)
    }

    // MARK: - Color Grading Tests

    func testColorGradeDefaults() {
        let grade = ColorGradeComponent()

        XCTAssertTrue(grade.isEnabled)
        XCTAssertEqual(grade.blendAmount, 1.0)
        XCTAssertNil(grade.lutReference)
        XCTAssertNil(grade.filmEmulation)
    }

    func testPrimaryColorCorrectionNeutral() {
        let correction = PrimaryColorCorrection.neutral

        XCTAssertEqual(correction.exposure, 0)
        XCTAssertEqual(correction.contrast, 0)
        XCTAssertEqual(correction.saturation, 0)
        XCTAssertEqual(correction.vibrance, 0)
    }

    func testColorWheelsNeutral() {
        let wheels = ColorWheelSettings.neutral

        XCTAssertEqual(wheels.lift.master, 0)
        XCTAssertEqual(wheels.gamma.master, 0)
        XCTAssertEqual(wheels.gain.master, 0)
        XCTAssertEqual(wheels.offset.master, 0)
    }

    func testCurvesLinear() {
        let curves = CurveSettings.linear

        XCTAssertEqual(curves.rgb.points.count, 2)
        XCTAssertEqual(curves.rgb.points[0].x, 0)
        XCTAssertEqual(curves.rgb.points[0].y, 0)
        XCTAssertEqual(curves.rgb.points[1].x, 1)
        XCTAssertEqual(curves.rgb.points[1].y, 1)
    }

    func testHSLSettingsNeutral() {
        let hsl = HSLSettings.neutral

        XCTAssertEqual(hsl.red.hue, 0)
        XCTAssertEqual(hsl.red.saturation, 0)
        XCTAssertEqual(hsl.red.luminance, 0)
    }

    func testBuiltInColorPresets() {
        XCTAssertFalse(BuiltInColorPresets.allPresets.isEmpty)

        let tealOrange = BuiltInColorPresets.cinematicTealOrange
        XCTAssertEqual(tealOrange.filmEmulation, .cinematic_teal_orange)
    }

    func testFilmEmulationPresetNames() {
        XCTAssertEqual(FilmEmulationPreset.kodakPortra400.displayName, "Kodak Portra 400")
        XCTAssertEqual(FilmEmulationPreset.vintage_vhs.displayName, "VHS")
    }

    // MARK: - Audio Processing Tests

    func testAudioProcessingChainDefaults() {
        let chain = AudioProcessingComponent()

        XCTAssertTrue(chain.isEnabled)
        XCTAssertTrue(chain.effects.isEmpty)
        XCTAssertEqual(chain.scope, .clip)
    }

    func testCompressorPresets() {
        let dialog = CompressorPresets.dialog

        XCTAssertEqual(dialog.effectType, .compressor)
        XCTAssertNotNil(dialog.parameters["threshold"])
        XCTAssertNotNil(dialog.parameters["ratio"])
    }

    func testEQPresets() {
        let voiceClarity = EQPresets.voiceClarity

        XCTAssertEqual(voiceClarity.effectType, .parametricEQ)
        XCTAssertNotNil(voiceClarity.parameters["band1_freq"])
    }

    func testNoiseReductionPresets() {
        let light = NoiseReductionPresets.light
        let aggressive = NoiseReductionPresets.aggressive

        XCTAssertEqual(light.effectType, .noiseReduction)
        XCTAssertLessThan(light.parameters["amount"] ?? 1, aggressive.parameters["amount"] ?? 0)
    }

    func testLoudnessTargets() {
        XCTAssertEqual(LoudnessTarget.streaming.lufs, -14.0)
        XCTAssertEqual(LoudnessTarget.broadcast.lufs, -24.0)
        XCTAssertEqual(LoudnessTarget.podcast.lufs, -16.0)
    }

    func testDuckingConfigDefaults() {
        let config = DuckingConfig.standard

        XCTAssertTrue(config.triggerTracks.contains(.dialog))
        XCTAssertTrue(config.targetTracks.contains(.music))
        XCTAssertLessThan(config.duckAmount, 0) // Should be negative dB
    }

    func testBuiltInAudioPresets() {
        XCTAssertFalse(BuiltInAudioPresets.allPresets.isEmpty)

        let dialog = BuiltInAudioPresets.dialogEnhancement
        XCTAssertFalse(dialog.effects.isEmpty)
    }

    // MARK: - Manual Editing Tests

    func testAddClipOperation() throws {
        var timeline = MultiTrackTimelineComponent(
            timelineId: EntityId(rawValue: 1),
            videoTracks: [VideoTrack()],
            audioTracks: []
        )

        let clip = ProClipSegment(
            sourceAssetId: EntityId(rawValue: 100),
            sourceIn: 0,
            sourceOut: 10,
            timelineIn: 0
        )

        let operation = AddClipOperation(clip: clip, trackIndex: 0, isVideo: true)
        try operation.execute(on: &timeline)

        XCTAssertEqual(timeline.videoTracks[0].segments.count, 1)
        XCTAssertEqual(timeline.videoTracks[0].segments[0].id, clip.id)
    }

    func testAddClipOperationUndo() throws {
        var timeline = MultiTrackTimelineComponent(
            timelineId: EntityId(rawValue: 1),
            videoTracks: [VideoTrack()],
            audioTracks: []
        )

        let clip = ProClipSegment(
            sourceAssetId: EntityId(rawValue: 100),
            sourceIn: 0,
            sourceOut: 10,
            timelineIn: 0
        )

        let operation = AddClipOperation(clip: clip, trackIndex: 0, isVideo: true)
        try operation.execute(on: &timeline)
        XCTAssertEqual(timeline.videoTracks[0].segments.count, 1)

        try operation.undo(on: &timeline)
        XCTAssertEqual(timeline.videoTracks[0].segments.count, 0)
    }

    func testSplitClipOperation() throws {
        var timeline = MultiTrackTimelineComponent(
            timelineId: EntityId(rawValue: 1),
            videoTracks: [VideoTrack()],
            audioTracks: []
        )

        let clip = ProClipSegment(
            sourceAssetId: EntityId(rawValue: 100),
            sourceIn: 0,
            sourceOut: 10,
            timelineIn: 0
        )

        timeline.videoTracks[0].segments.append(clip)

        let operation = SplitClipOperation(
            clipId: clip.id,
            trackIndex: 0,
            isVideo: true,
            splitTime: 5.0
        )

        try operation.execute(on: &timeline)

        XCTAssertEqual(timeline.videoTracks[0].segments.count, 2)
        XCTAssertEqual(timeline.videoTracks[0].segments[0].timelineDuration, 5.0)
        XCTAssertEqual(timeline.videoTracks[0].segments[1].timelineIn, 5.0)
    }

    func testAddTrackOperation() throws {
        var timeline = MultiTrackTimelineComponent(
            timelineId: EntityId(rawValue: 1),
            videoTracks: [VideoTrack()],
            audioTracks: []
        )

        let operation = AddTrackOperation(isVideo: true)
        try operation.execute(on: &timeline)

        XCTAssertEqual(timeline.videoTracks.count, 2)
    }

    // MARK: - Export Tests

    func testExportPresetSettings() {
        let youtube = ProExportPreset.youtube1080p
        let settings = youtube.settings

        XCTAssertEqual(settings.resolution.width, 1920)
        XCTAssertEqual(settings.resolution.height, 1080)
        XCTAssertEqual(settings.codec, .h264)
        XCTAssertEqual(settings.frameRate, 30)
    }

    func testVerticalExportPresets() {
        let tiktok = ProExportPreset.tiktokVertical
        let settings = tiktok.settings

        XCTAssertEqual(settings.resolution.width, 1080)
        XCTAssertEqual(settings.resolution.height, 1920)
        XCTAssertTrue(settings.aspectRatio.isVertical)
    }

    func testProResPresets() {
        let prores422 = ProExportPreset.prores422

        XCTAssertTrue(prores422.isProResFormat)
        XCTAssertEqual(prores422.fileExtension, "mov")
        XCTAssertEqual(prores422.settings.codec, .prores422)
    }

    func testExportConfigurationDefaults() {
        let config = ProExportConfiguration()

        XCTAssertTrue(config.includeAudio)
        XCTAssertFalse(config.burnInCaptions)
        XCTAssertTrue(config.applyColorGrades)
        XCTAssertEqual(config.hardwareAcceleration, .auto)
    }

    func testBatchExportConfiguration() {
        let batch = BatchExportConfiguration(
            sceneIds: [EntityId(rawValue: 1), EntityId(rawValue: 2)],
            presets: [.youtube1080p, .tiktokVertical],
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertEqual(batch.totalExports, 4) // 2 scenes × 2 presets
    }

    // MARK: - Roadmap Tests

    func testRoadmapPhases() {
        XCTAssertEqual(RoadmapPhase.allCases.count, 8)
        XCTAssertEqual(RoadmapPhase.phase1_stability.rawValue, 1)
        XCTAssertEqual(RoadmapPhase.phase8_uxPolish.rawValue, 8)
    }

    func testRoadmapFeaturePriorities() {
        XCTAssertEqual(RoadmapFeature.undoRedoSystem.priority, .critical)
        XCTAssertEqual(RoadmapFeature.colorWheels.priority, .high)
        XCTAssertEqual(RoadmapFeature.advancedMediaIngest.priority, .medium)
    }

    func testRoadmapStatus() {
        let status = RoadmapStatus.initial

        XCTAssertGreaterThan(status.overallCompletion, 0)
        XCTAssertLessThan(status.overallCompletion, 1.0)
    }

    func testFeatureFlags() {
        let v1Flags = PolytroposProFeatureFlags.v1Default

        XCTAssertTrue(v1Flags.undoRedo)
        XCTAssertTrue(v1Flags.multiTrackTimeline)
        XCTAssertTrue(v1Flags.colorGrading)
        XCTAssertTrue(v1Flags.aiAutoEdit)
        XCTAssertFalse(v1Flags.pluginSystem) // Post-v1
    }

    func testMinimalFeatureFlags() {
        let minimal = PolytroposProFeatureFlags.minimal

        XCTAssertTrue(minimal.undoRedo)
        XCTAssertTrue(minimal.multiTrackTimeline)
        XCTAssertFalse(minimal.colorGrading)
        XCTAssertFalse(minimal.audioProcessing)
    }

    // MARK: - Component Encoding Tests

    func testColorGradeEncodeDecode() throws {
        let original = ColorGradeComponent(
            name: "Test Grade",
            primaryCorrection: PrimaryColorCorrection(exposure: 0.5, contrast: 10),
            filmEmulation: .kodakPortra400
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorGradeComponent.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.primaryCorrection.exposure, 0.5)
        XCTAssertEqual(decoded.filmEmulation, .kodakPortra400)
    }

    func testExportPresetEncodeDecode() throws {
        let original = ProExportConfiguration(
            preset: .youtube4k,
            burnInCaptions: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProExportConfiguration.self, from: data)

        XCTAssertEqual(decoded.preset, .youtube4k)
        XCTAssertTrue(decoded.burnInCaptions)
    }

    func testAudioProcessingEncodeDecode() throws {
        let original = AudioProcessingComponent(
            name: "Dialog Chain",
            effects: [EQPresets.voiceClarity, CompressorPresets.dialog],
            scope: .clip
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioProcessingComponent.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.effects.count, 2)
    }

    // MARK: - Timeline Marker Tests

    func testTimelineMarkers() {
        let marker = TimelineMarker(
            time: 30.0,
            name: "Chapter 1",
            color: .blue,
            markerType: .chapter
        )

        XCTAssertEqual(marker.time, 30.0)
        XCTAssertEqual(marker.markerType, .chapter)
    }

    func testSnapSettings() {
        let settings = SnapSettings()

        XCTAssertTrue(settings.enabled)
        XCTAssertTrue(settings.snapToPlayhead)
        XCTAssertTrue(settings.snapToClipEdges)
        XCTAssertFalse(settings.snapToBeats)
    }

    // MARK: - Proxy Tests

    func testProxyResolutionScale() {
        XCTAssertEqual(ProxyResolution.half.scale, 0.5)
        XCTAssertEqual(ProxyResolution.quarter.scale, 0.25)
        XCTAssertEqual(ProxyResolution.eighth.scale, 0.125)
    }

    func testProxySettingsDefaults() {
        let settings = ProxySettingsComponent(projectId: EntityId(rawValue: 1))

        XCTAssertTrue(settings.useProxiesForEditing)
        XCTAssertEqual(settings.proxyResolution, .quarter)
        XCTAssertEqual(settings.generationStatus, .notStarted)
    }

    // MARK: - Edit History Tests

    func testEditHistoryComponent() {
        let history = EditHistoryComponent(timelineId: EntityId(rawValue: 1))

        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertFalse(history.hasUnsavedChanges)
    }

    func testEditActionTypes() {
        let action = EditAction(
            actionType: .splitClip,
            description: "Split clip at 5.0s",
            affectedSegmentIds: [UUID()]
        )

        XCTAssertEqual(action.actionType, .splitClip)
        XCTAssertEqual(action.affectedSegmentIds.count, 1)
    }
}
