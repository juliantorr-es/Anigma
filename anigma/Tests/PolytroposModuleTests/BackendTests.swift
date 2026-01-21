//
//  BackendTests.swift
//  PolytroposModuleTests
//
//  Tests for the backend abstraction, MLT/FFmpeg integration, and project interchange.
//

import XCTest
import AnigmaTestSupport
@testable import PolytroposModule
@testable import AnigmaCore

final class BackendTests: XCTestCase {

    // MARK: - Backend Protocol Tests

    func testRendererBackendIdCreation() {
        let native = RendererBackendId.native
        let mlt = RendererBackendId.mlt
        let ffmpeg = RendererBackendId.ffmpeg
        let custom = RendererBackendId(rawValue: "custom_backend")

        XCTAssertEqual(native.rawValue, "native")
        XCTAssertEqual(mlt.rawValue, "mlt")
        XCTAssertEqual(ffmpeg.rawValue, "ffmpeg")
        XCTAssertEqual(custom.rawValue, "custom_backend")
    }

    func testRendererCapabilitiesInit() {
        let caps = RendererCapabilities(
            supportedVideoCodecs: [
                .h264,
                LegacyVideoCodec.h265.runtime ?? .hevc,
                .prores422
            ],
            supportedAudioCodecs: [.aac, .pcm],
            supportedContainers: [.mp4, .mov],
            gpuAcceleration: true,
            hardwareEncoding: true,
            maxResolution: .uhd4k,
            supportsColorGrading: true,
            supportsAudioEffects: true,
            supportsTransitions: true,
            supportsKeyframes: true
        )

        XCTAssertEqual(caps.supportedBackendVideoCodecs.count, 3)
        XCTAssertTrue(caps.gpuAcceleration)
        XCTAssertTrue(caps.hardwareEncoding)
        XCTAssertEqual(caps.maxResolution, .uhd4k)
    }

    func testResolutionPresets() {
        XCTAssertEqual(Resolution.hd720.width, 1280)
        XCTAssertEqual(Resolution.hd720.height, 720)
        XCTAssertEqual(Resolution.hd1080.width, 1920)
        XCTAssertEqual(Resolution.hd1080.height, 1080)
        XCTAssertEqual(Resolution.uhd4k.width, 3840)
        XCTAssertEqual(Resolution.uhd4k.height, 2160)
    }

    func testMediaAssetInfoCreation() {
        let entityId = EntityId()
        let info = MediaAssetInfo(
            entityId: entityId,
            filePath: "/path/to/video.mp4",
            duration: 120.0,
            resolution: .hd1080,
            frameRate: 24.0,
            audioChannels: 2,
            sampleRate: 48000,
            hasProxy: true,
            proxyPath: "/path/to/video_proxy.mp4"
        )

        XCTAssertEqual(info.entityId, entityId)
        XCTAssertEqual(info.duration, 120.0)
        XCTAssertEqual(info.resolution, .hd1080)
        XCTAssertEqual(info.frameRate, 24.0)
        XCTAssertTrue(info.hasProxy)
    }

    func testRenderProgressCreation() {
        let jobId = UUID()
        let progress = RenderProgress(
            jobId: jobId,
            phase: .rendering,
            progress: 0.5,
            currentFrame: 1200,
            totalFrames: 2400,
            estimatedTimeRemaining: 60.0,
            currentPassName: "Video encoding"
        )

        XCTAssertEqual(progress.jobId, jobId)
        XCTAssertEqual(progress.phase, .rendering)
        XCTAssertEqual(progress.progress, 0.5)
        XCTAssertEqual(progress.currentFrame, 1200)
    }

    func testRenderResultSuccess() {
        let jobId = UUID()
        let result = RenderResult(
            jobId: jobId,
            success: true,
            outputPath: "/output/video.mp4",
            outputSize: 1024 * 1024 * 100, // 100MB
            duration: 120.0,
            renderTime: 45.0,
            warnings: []
        )

        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.outputPath)
        XCTAssertNil(result.error)
    }

    func testRenderResultFailure() {
        let jobId = UUID()
        let result = RenderResult(
            jobId: jobId,
            success: false,
            renderTime: 5.0,
            error: RenderError(
                code: "CODEC_ERROR",
                message: "Unsupported codec",
                underlyingError: "libx264 not found"
            )
        )

        XCTAssertFalse(result.success)
        XCTAssertNil(result.outputPath)
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.error?.code, "CODEC_ERROR")
    }

    // MARK: - Backend Registry Tests

    func testBackendRegistrySharedInstance() async {
        let registry = RendererBackendRegistry.shared
        XCTAssertNotNil(registry)
    }

    func testBackendRequirementEquality() {
        let req1 = BackendRequirement.gpuAcceleration
        let req2 = BackendRequirement.gpuAcceleration
        let req3 = BackendRequirement.codec(.h264)
        let req4 = BackendRequirement.codec(.h264)
        let req5 = BackendRequirement.codec(LegacyVideoCodec.h265.backend!)

        XCTAssertEqual(req1, req2)
        XCTAssertEqual(req3, req4)
        XCTAssertNotEqual(req3, req5)
    }

    // MARK: - MLT Bridge Tests

    func testMLTBackendCapabilities() {
        let backend = MLTBackend()

        XCTAssertEqual(backend.backendId, .mlt)
        XCTAssertEqual(backend.displayName, "MLT Framework (Legacy)")
        XCTAssertTrue(backend.capabilities.supportsColorGrading)
        XCTAssertTrue(backend.capabilities.supportsTransitions)
        XCTAssertFalse(backend.capabilities.gpuAcceleration)
    }

    func testMLTProjectAdapterConvert() throws {
        let timelineId = EntityId()
        let assetId = EntityId()

        let timeline = MultiTrackTimelineComponent(
            timelineId: timelineId,
            videoTracks: [
                VideoTrack(
                    name: "V1",
                    segments: [
                        ProClipSegment(
                            sourceAssetId: assetId,
                            sourceIn: 0,
                            sourceOut: 10,
                            timelineIn: 0
                        )
                    ]
                )
            ]
        )

        let assets: [EntityId: MediaAssetInfo] = [
            assetId: MediaAssetInfo(
                entityId: assetId,
                filePath: "/path/to/video.mp4",
                duration: 60.0
            )
        ]

        let config = ProExportConfiguration()

        let xml = try MLTProjectAdapter.convert(
            timeline: timeline,
            assets: assets,
            configuration: config
        )

        XCTAssertTrue(xml.contains("<?xml"))
        XCTAssertTrue(xml.contains("<mlt"))
        XCTAssertTrue(xml.contains("producer"))
        XCTAssertTrue(xml.contains("/path/to/video.mp4"))
    }

    func testMLTClipAdapterToProducer() {
        let assetId = EntityId()
        let segment = ProClipSegment(
            sourceAssetId: assetId,
            sourceIn: 5.0,
            sourceOut: 15.0,
            timelineIn: 0
        )
        let asset = MediaAssetInfo(
            entityId: assetId,
            filePath: "/path/to/clip.mov",
            duration: 30.0
        )

        let producer = MLTClipAdapter.toProducer(
            segment: segment,
            asset: asset,
            producerId: "producer0"
        )

        XCTAssertTrue(producer.contains("producer0"))
        XCTAssertTrue(producer.contains("/path/to/clip.mov"))
        XCTAssertTrue(producer.contains("avformat"))
    }

    func testEDLAdapterExport() {
        let timelineId = EntityId()
        let assetId = EntityId()

        let timeline = MultiTrackTimelineComponent(
            timelineId: timelineId,
            videoTracks: [
                VideoTrack(
                    name: "V1",
                    segments: [
                        ProClipSegment(
                            sourceAssetId: assetId,
                            sourceIn: 0,
                            sourceOut: 10,
                            timelineIn: 0
                        )
                    ]
                )
            ]
        )

        let assets: [EntityId: MediaAssetInfo] = [
            assetId: MediaAssetInfo(
                entityId: assetId,
                filePath: "/path/to/clip.mov",
                duration: 30.0
            )
        ]

        let edl = EDLAdapter.exportCMX3600(timeline: timeline, assets: assets)

        XCTAssertTrue(edl.contains("TITLE:"))
        XCTAssertTrue(edl.contains("FCM: NON-DROP FRAME"))
        XCTAssertTrue(edl.contains("001"))
        XCTAssertTrue(edl.contains("clip.mov"))
    }

    // MARK: - FFmpeg Utils Tests

    func testFFmpegBackendCapabilities() {
        let backend = FFmpegBackend()

        XCTAssertEqual(backend.backendId, .ffmpeg)
        XCTAssertEqual(backend.displayName, "FFmpeg (Universal)")
        XCTAssertTrue(backend.capabilities.gpuAcceleration)
        XCTAssertTrue(backend.capabilities.hardwareEncoding)
        XCTAssertEqual(backend.capabilities.supportedBackendVideoCodecs.count, BackendVideoCodec.allCases.count)
    }

    func testFFmpegResultSuccess() {
        let result = FFmpegResult(
            exitCode: 0,
            stdout: "ffmpeg version 6.0",
            stderr: ""
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.exitCode, 0)
    }

    func testFFmpegResultFailure() {
        let result = FFmpegResult(
            exitCode: 1,
            stdout: "",
            stderr: "Error: codec not found"
        )

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.exitCode, 1)
    }

    func testTranscodeSettingsInit() {
        let settings = TranscodeSettings(
            videoCodec: .h264,
            videoBitrate: "5M",
            resolution: .hd1080,
            frameRate: 30.0,
            audioCodec: .aac,
            audioBitrate: "192k",
            sampleRate: 48000
        )

        XCTAssertEqual(settings.videoCodec, .h264)
        XCTAssertEqual(settings.videoBitrate, "5M")
        XCTAssertEqual(settings.resolution, .hd1080)
        XCTAssertEqual(settings.audioCodec, .aac)
    }

    func testFFmpegConcatBuilderFile() {
        let clips: [(path: String, inPoint: TimeInterval, outPoint: TimeInterval)] = [
            ("/path/to/clip1.mp4", 0, 10),
            ("/path/to/clip2.mp4", 5, 20),
            ("/path/to/clip3.mp4", 0, 15)
        ]

        let concatFile = FFmpegConcatBuilder.buildConcatFile(clips: clips)

        XCTAssertTrue(concatFile.contains("ffconcat version 1.0"))
        XCTAssertTrue(concatFile.contains("file '/path/to/clip1.mp4'"))
        XCTAssertTrue(concatFile.contains("inpoint 0.0"))
        XCTAssertTrue(concatFile.contains("outpoint 10.0"))
    }

    func testFFmpegConcatBuilderFilterGraph() {
        let timelineId = EntityId()
        let asset1Id = EntityId()
        let asset2Id = EntityId()

        let timeline = MultiTrackTimelineComponent(
            timelineId: timelineId,
            videoTracks: [
                VideoTrack(
                    name: "V1",
                    segments: [
                        ProClipSegment(sourceAssetId: asset1Id, sourceIn: 0, sourceOut: 10, timelineIn: 0),
                        ProClipSegment(sourceAssetId: asset2Id, sourceIn: 5, sourceOut: 15, timelineIn: 10)
                    ]
                )
            ]
        )

        let assets: [EntityId: MediaAssetInfo] = [
            asset1Id: MediaAssetInfo(entityId: asset1Id, filePath: "/clip1.mp4", duration: 30),
            asset2Id: MediaAssetInfo(entityId: asset2Id, filePath: "/clip2.mp4", duration: 30)
        ]

        let (inputs, filterComplex) = FFmpegConcatBuilder.buildFilterGraph(
            timeline: timeline,
            assets: assets
        )

        XCTAssertEqual(inputs.count, 2)
        XCTAssertTrue(filterComplex.contains("trim"))
        XCTAssertTrue(filterComplex.contains("concat"))
    }

    // MARK: - Project Interchange Tests

    func testInterchangeFormatIds() {
        XCTAssertEqual(InterchangeFormatId.mltXML.rawValue, "mlt_xml")
        XCTAssertEqual(InterchangeFormatId.edl.rawValue, "edl")
        XCTAssertEqual(InterchangeFormatId.fcpxml.rawValue, "fcpxml")
        XCTAssertEqual(InterchangeFormatId.otio.rawValue, "otio")
    }

    func testProjectMetadataInit() {
        let metadata = ProjectMetadata(
            projectName: "My Project",
            frameRate: 24,
            resolution: .hd1080,
            author: "Test Author"
        )

        XCTAssertEqual(metadata.projectName, "My Project")
        XCTAssertEqual(metadata.frameRate, 24)
        XCTAssertEqual(metadata.resolution, .hd1080)
        XCTAssertEqual(metadata.author, "Test Author")
    }

    func testInterchangeImportResultSuccess() {
        let timelineId = EntityId()
        let result = InterchangeImportResult(
            timeline: MultiTrackTimelineComponent(timelineId: timelineId),
            assets: [],
            warnings: [],
            errors: []
        )

        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.timeline)
    }

    func testInterchangeImportResultFailure() {
        let result = InterchangeImportResult(
            timeline: nil,
            assets: [],
            errors: [ImportError(code: "PARSE_ERROR", message: "Invalid XML")]
        )

        XCTAssertFalse(result.success)
        XCTAssertNil(result.timeline)
    }

    func testMLTXMLFormatExport() throws {
        let timelineId = EntityId()
        let assetId = EntityId()

        let timeline = MultiTrackTimelineComponent(
            timelineId: timelineId,
            videoTracks: [
                VideoTrack(
                    name: "V1",
                    segments: [
                        ProClipSegment(sourceAssetId: assetId, sourceIn: 0, sourceOut: 10, timelineIn: 0)
                    ]
                )
            ]
        )

        let assets: [EntityId: MediaAssetInfo] = [
            assetId: MediaAssetInfo(entityId: assetId, filePath: "/video.mp4", duration: 30)
        ]

        let metadata = ProjectMetadata(
            projectName: "Test Export",
            frameRate: 24,
            resolution: .hd1080
        )

        let data = try MLTXMLFormat.export(timeline: timeline, assets: assets, metadata: metadata)
        guard let xml = String(data: data, encoding: .utf8) else {
            fatalError("Failed to unwrap xml")
        }

        XCTAssertTrue(xml.contains("<?xml"))
        XCTAssertTrue(xml.contains("title=\"Test Export\""))
        XCTAssertTrue(xml.contains("width=\"1920\""))
        XCTAssertTrue(xml.contains("height=\"1080\""))
    }

    func testEDLFormatExport() throws {
        let timelineId = EntityId()
        let assetId = EntityId()

        let timeline = MultiTrackTimelineComponent(
            timelineId: timelineId,
            videoTracks: [
                VideoTrack(
                    name: "V1",
                    segments: [
                        ProClipSegment(sourceAssetId: assetId, sourceIn: 0, sourceOut: 10, timelineIn: 0)
                    ]
                )
            ]
        )

        let assets: [EntityId: MediaAssetInfo] = [
            assetId: MediaAssetInfo(entityId: assetId, filePath: "/clip.mov", duration: 30)
        ]

        let metadata = ProjectMetadata(projectName: "EDL Test")

        let data = try EDLFormat.export(timeline: timeline, assets: assets, metadata: metadata)
        guard let edl = String(data: data, encoding: .utf8) else {
            fatalError("Failed to unwrap edl")
        }

        XCTAssertTrue(edl.contains("TITLE: EDL Test"))
        XCTAssertTrue(edl.contains("FCM: NON-DROP FRAME"))
        XCTAssertTrue(edl.contains("001"))
    }

    func testFCPXMLFormatExport() throws {
        let timelineId = EntityId()
        let assetId = EntityId()

        let timeline = MultiTrackTimelineComponent(
            timelineId: timelineId,
            videoTracks: [
                VideoTrack(
                    name: "V1",
                    segments: [
                        ProClipSegment(sourceAssetId: assetId, sourceIn: 0, sourceOut: 10, timelineIn: 0)
                    ]
                )
            ]
        )

        let assets: [EntityId: MediaAssetInfo] = [
            assetId: MediaAssetInfo(entityId: assetId, filePath: "/clip.mov", duration: 30)
        ]

        let metadata = ProjectMetadata(projectName: "FCPXML Test", frameRate: 24, resolution: .hd1080)

        let data = try FCPXMLFormat.export(timeline: timeline, assets: assets, metadata: metadata)
        guard let xml = String(data: data, encoding: .utf8) else {
            fatalError("Failed to unwrap xml")
        }

        XCTAssertTrue(xml.contains("<!DOCTYPE fcpxml>"))
        XCTAssertTrue(xml.contains("fcpxml version=\"1.10\""))
        XCTAssertTrue(xml.contains("FCPXML Test"))
    }

    func testOTIOFormatExport() throws {
        let timelineId = EntityId()
        let assetId = EntityId()

        let timeline = MultiTrackTimelineComponent(
            timelineId: timelineId,
            videoTracks: [
                VideoTrack(
                    name: "V1",
                    segments: [
                        ProClipSegment(sourceAssetId: assetId, sourceIn: 0, sourceOut: 10, timelineIn: 0)
                    ]
                )
            ]
        )

        let assets: [EntityId: MediaAssetInfo] = [
            assetId: MediaAssetInfo(entityId: assetId, filePath: "/clip.mov", duration: 30)
        ]

        let metadata = ProjectMetadata(projectName: "OTIO Test")

        let data = try OTIOFormat.export(timeline: timeline, assets: assets, metadata: metadata)

        // Parse as JSON to verify structure
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["OTIO_SCHEMA"] as? String, "Timeline.1")
        XCTAssertEqual(json["name"] as? String, "OTIO Test")
    }

    func testProjectInterchangeServiceAvailableFormats() async {
        let service = ProjectInterchangeService()
        let formats = await service.availableFormats()

        XCTAssertEqual(formats.count, 4)
        XCTAssertTrue(formats.contains { $0.id == .mltXML })
        XCTAssertTrue(formats.contains { $0.id == .edl })
        XCTAssertTrue(formats.contains { $0.id == .fcpxml })
        XCTAssertTrue(formats.contains { $0.id == .otio })
    }

    // MARK: - Video Codec Tests

    func testVideoCodecAllCases() {
        let legacyCodecs = LegacyVideoCodec.allCases

        XCTAssertTrue(legacyCodecs.contains(.h264))
        XCTAssertTrue(legacyCodecs.contains(.h265))
        XCTAssertTrue(legacyCodecs.contains(.vp9))
        XCTAssertEqual(legacyCodecs.compactMap { $0.runtime }.count, 2)
        XCTAssertNil(LegacyVideoCodec.vp9.runtime)
    }

    func testAudioCodecAllCases() {
        let allCodecs = AudioCodec.allCases

        XCTAssertTrue(allCodecs.contains(.aac))
        XCTAssertTrue(allCodecs.contains(.mp3))
        XCTAssertTrue(allCodecs.contains(.pcm))
        XCTAssertTrue(allCodecs.contains(.opus))
    }

    func testContainerFormatAllCases() {
        let allFormats = ContainerFormat.allCases

        XCTAssertTrue(allFormats.contains(.mp4))
        XCTAssertTrue(allFormats.contains(.mov))
        XCTAssertTrue(allFormats.contains(.mkv))
        XCTAssertTrue(allFormats.contains(.webm))
    }

    // MARK: - Render Phase Tests

    func testRenderPhaseValues() {
        XCTAssertEqual(RenderPhase.preparing.rawValue, "preparing")
        XCTAssertEqual(RenderPhase.rendering.rawValue, "rendering")
        XCTAssertEqual(RenderPhase.encoding.rawValue, "encoding")
        XCTAssertEqual(RenderPhase.completed.rawValue, "completed")
        XCTAssertEqual(RenderPhase.failed.rawValue, "failed")
    }

    // MARK: - Preview Tests

    func testPreviewResolutionCases() {
        let thumbnail = PreviewResolution.thumbnail(maxDimension: 256)
        let preview = PreviewResolution.preview(width: 1280, height: 720)
        let full = PreviewResolution.full

        // Just verify they can be created
        switch thumbnail {
        case .thumbnail(let maxDim):
            XCTAssertEqual(maxDim, 256)
        default:
            XCTFail("Expected thumbnail")
        }

        switch preview {
        case .preview(let w, let h):
            XCTAssertEqual(w, 1280)
            XCTAssertEqual(h, 720)
        default:
            XCTFail("Expected preview")
        }

        switch full {
        case .full:
            break // OK
        default:
            XCTFail("Expected full")
        }
    }

    func testPreviewFrameCreation() {
        let frame = PreviewFrame(
            time: 5.0,
            width: 1920,
            height: 1080,
            pixelData: Data(repeating: 0, count: 100),
            pixelFormat: .rgba8
        )

        XCTAssertEqual(frame.time, 5.0)
        XCTAssertEqual(frame.width, 1920)
        XCTAssertEqual(frame.height, 1080)
        XCTAssertEqual(frame.pixelFormat, .rgba8)
    }
}
