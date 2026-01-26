//
//  PolytroposModule.swift
//  PolytroposModule
//
//  Polytropos (from Greek "πολύτροπος" – "of many turns, versatile, resourceful"):
//  The live-event → social-video engine that transforms multicam footage of real-world
//  events into publishable, branded, captioned clips with minimal manual editing.
//
//  Target domains: concerts, drag shows, theater, talks, conferences, meetups,
//  DJ sets, live art, teaching sessions, and similar creator-focused content.
//
//  Components (in Components/):
//  - ProjectComponent: Top-level project containing all event data
//  - MediaAssetComponent: Individual media files (video, audio)
//  - MulticamClusterComponent: Synced group of cameras covering same take
//  - TimelineComponent: Sequence of clip segments and transitions
//  - SceneComponent: Semantically meaningful chunk (song, bit, segment)
//  - ClipSegmentComponent: One section of a MediaAsset used in timeline
//  - BrandingProfileComponent: Artist/series branding (colors, fonts, logos)
//  - ExportPresetComponent: Platform-specific export settings
//  - ExportJobComponent: Concrete render request
//  - TranscriptComponent: ASR output with timecodes
//
//  Systems (in Systems/):
//  - MediaIngestSystem: Discover, classify, normalize media files
//  - AudioSyncSystem: Align cameras by audio cross-correlation
//  - AudioAnalysisSystem: Beat detection, structure, applause detection
//  - VideoAnalysisSystem: Stability, sharpness, subject detection, framing
//  - AutoEditSystem: Generate timeline from analysis features
//  - CaptionSystem: ASR → subtitle segmentation
//  - BrandingSystem: Apply lower thirds, watermarks, intro/outro
//  - ReframeSystem: Multi-aspect safe region computation
//  - ExportSystem: Render timeline to target format
//
//  Services (in Services/):
//  - PolytroposService: High-level project orchestration
//  - SyncService: Audio-based multicam alignment
//  - AnalysisService: Coordinate audio/video feature extraction
//  - EditService: Auto-edit logic and cut decisions
//  - CaptionService: ASR and subtitle management
//  - ExportService: Render queue and format handling
//
//  Pipelines (in Pipelines/):
//  - FullEventWorkflow: Ingest → Sync → Analyze → AutoEdit → Caption → Export
//  - QuickClipWorkflow: Simplified mobile-friendly path
//  - ReExportWorkflow: Re-render existing timeline with new presets
//

import AnigmaCore
import Foundation
import MediaContainerCapsule

// MARK: - Module Info

/// PolytroposModule version information.
public enum PolytroposModuleVersion {
    public static let major = 0
    public static let minor = 1
    public static let patch = 0
    public static let string = "\(major).\(minor).\(patch)"
}

// MARK: - Module Registration

/// Registers Polytropos-specific systems and workflows with the ECS.
public enum PolytroposModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        let world = await runtime.getWorld()
        let registry = await runtime.getWorkflowRegistry()
        let runner = await runtime.getWorkflowRunner()
        try await register(world: world, registry: registry, runner: runner)
    }

    /// Register all Polytropos systems and workflows with the world.
    ///
    /// Call this during app startup to enable live-event video processing.
    ///
    /// - Parameters:
    ///   - world: The ECS world to register systems with.
    ///   - registry: The workflow registry to register workflows with.
    ///   - runner: Optional workflow runner to register systems for execution.
    ///   - workDirectory: Base directory for Polytropos outputs (defaults to temp).
    ///   - enableLegacyBackends: Whether to register MLT/FFmpeg fallback backends.
    ///   - mediaContainerCapsule: Optional pre-configured MediaContainerCapsuleWrapper for media analysis.
    public static func register(
        world: World,
        registry: WorkflowRegistry,
        runner: WorkflowRunner? = nil,
        workDirectory: URL? = nil,
        enableLegacyBackends: Bool = true,
        mediaContainerCapsule: MediaContainerCapsuleWrapper? = nil
    ) async throws {
        let workDir = workDirectory ?? defaultWorkDirectory()

        let ingestSystem = MediaIngestSystem(
            workDirectory: workDir.appendingPathComponent("ingest"),
            containerCapsule: mediaContainerCapsule
        )
        await world.registerSystem(ingestSystem)
        await world.registerSystem(AudioSyncSystem())
        await world.registerSystem(AudioAnalysisSystem())
        await world.registerSystem(VideoAnalysisSystem())
        await world.registerSystem(AutoEditSystem())
        await world.registerSystem(CaptionSystem())
        await world.registerSystem(BrandingSystem())
        await world.registerSystem(ReframeSystem())
        await world.registerSystem(ExportSystem(workDirectory: workDir.appendingPathComponent("exports")))
        await world.registerSystem(MLModelProvisioningSystem(workDirectory: workDir.appendingPathComponent("models")))

        if let runner = runner {
            await runner.registerSystem(MediaIngestSystem(
                workDirectory: workDir.appendingPathComponent("ingest"),
                containerCapsule: mediaContainerCapsule
            ))
            await runner.registerSystem(AudioSyncSystem())
            await runner.registerSystem(AudioAnalysisSystem())
            await runner.registerSystem(VideoAnalysisSystem())
            await runner.registerSystem(AutoEditSystem())
            await runner.registerSystem(CaptionSystem())
            await runner.registerSystem(BrandingSystem())
            await runner.registerSystem(ReframeSystem())
            await runner.registerSystem(ExportSystem(workDirectory: workDir.appendingPathComponent("exports")))
            await runner.registerSystem(MLModelProvisioningSystem(workDirectory: workDir.appendingPathComponent("models")))
        }

        // Register workflows
        await registry.register(FullEventWorkflow())
        await registry.register(QuickClipWorkflow())
        await registry.register(ReExportWorkflow())

        // Register renderer backends
        if enableLegacyBackends {
            await registerLegacyBackends()
        }

        await Logger.shared.info(
            "PolytroposModule v\(PolytroposModuleVersion.string) registered (legacy backends: \(enableLegacyBackends))",
            category: "Polytropos"
        )
    }

    /// Register MLT and FFmpeg fallback backends.
    private static func registerLegacyBackends() async {
        let registry = RendererBackendRegistry.shared

        // Register MLT backend
        let mltBackend = MLTBackend()
        if await mltBackend.isAvailable() {
            await registry.register(mltBackend)
            await Logger.shared.info("MLT backend registered", category: "Polytropos")
        }

        // Register FFmpeg backend
        let ffmpegBackend = FFmpegBackend()
        if await ffmpegBackend.isAvailable() {
            await registry.register(ffmpegBackend)
            await Logger.shared.info("FFmpeg backend registered", category: "Polytropos")
        }
    }

    /// Default work directory for Polytropos outputs.
    public static func defaultWorkDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("polytropos", isDirectory: true)
    }

    /// Creates a pre-configured pipeline for quick mobile clips.
    /// - Parameters:
    ///   - workDirectory: Base directory for outputs.
    ///   - mediaContainerCapsule: Optional pre-configured MediaContainerCapsuleWrapper for media analysis.
    public static func createQuickClipPipeline(
        workDirectory: URL? = nil,
        mediaContainerCapsule: MediaContainerCapsuleWrapper? = nil
    ) -> [any System] {
        let workDir = workDirectory ?? defaultWorkDirectory()
        return [
            MediaIngestSystem(workDirectory: workDir.appendingPathComponent("ingest"), containerCapsule: mediaContainerCapsule),
            AudioSyncSystem(),
            AudioAnalysisSystem(),
            AutoEditSystem(),
            ExportSystem(workDirectory: workDir.appendingPathComponent("exports"))
        ]
    }
}

// MARK: - Job Types

/// Job types for Polytropos video processing pipelines.
public enum PolytroposJobType {
    public static let fullEvent = "polytropos.full_event"
    public static let quickClip = "polytropos.quick_clip"
    public static let reExport = "polytropos.re_export"
    public static let mediaIngest = "polytropos.media_ingest"
    public static let audioSync = "polytropos.audio_sync"
    public static let audioAnalysis = "polytropos.audio_analysis"
    public static let videoAnalysis = "polytropos.video_analysis"
    public static let autoEdit = "polytropos.auto_edit"
    public static let captioning = "polytropos.captioning"
    public static let branding = "polytropos.branding"
    public static let reframe = "polytropos.reframe"
    public static let export = "polytropos.export"
    public static let musicGeneration = "polytropos.music_generation"
    public static let musicMixing = "polytropos.music_mixing"
}

// MARK: - Outline Job Type (for registration)

public struct FullEventJobType: JobType {
    public static let identifier = PolytroposJobType.fullEvent
    public static let displayName = "Full Event Processing"
}

public struct QuickClipJobType: JobType {
    public static let identifier = PolytroposJobType.quickClip
    public static let displayName = "Quick Clip Generation"
}

public struct ExportJobType: JobType {
    public static let identifier = PolytroposJobType.export
    public static let displayName = "Video Export"
}

public struct MusicGenerationJobType: JobType {
    public static let identifier = PolytroposJobType.musicGeneration
    public static let displayName = "Music Generation"
}

public struct MusicMixingJobType: JobType {
    public static let identifier = PolytroposJobType.musicMixing
    public static let displayName = "Music Mixing"
}

// MARK: - Backend Job Types

public struct ProxyGenerationJobType: JobType {
    public static let identifier = "polytropos.proxy_generation"
    public static let displayName = "Proxy Generation"
}

public struct MLTRenderJobType: JobType {
    public static let identifier = "polytropos.mlt_render"
    public static let displayName = "MLT Render"
}

public struct FFmpegTranscodeJobType: JobType {
    public static let identifier = "polytropos.ffmpeg_transcode"
    public static let displayName = "FFmpeg Transcode"
}

public struct ProjectInterchangeJobType: JobType {
    public static let identifier = "polytropos.project_interchange"
    public static let displayName = "Project Import/Export"
}

// MARK: - Video Ingestion Job Types

public struct VideoIngestionJobType: JobType {
    public static let identifier = "polytropos.video_ingestion"
    public static let displayName = "Video Ingestion"
}

public struct FrameExtractionJobType: JobType {
    public static let identifier = "polytropos.frame_extraction"
    public static let displayName = "Frame Extraction"
}

public struct FingerprintGenerationJobType: JobType {
    public static let identifier = "polytropos.fingerprint_generation"
    public static let displayName = "Fingerprint Generation"
}

// MARK: - Module Extensions

extension PolytroposModule {
    /// Creates a fully configured PolytroposCoordinator with optional artifact store integration.
    ///
    /// - Parameters:
    ///   - configuration: Coordinator configuration.
    ///   - containerCapsule: Optional pre-configured MediaContainerCapsuleWrapper.
    ///   - artifactStoreAdapter: Optional adapter for ArtifactStoreModule integration.
    /// - Returns: A configured PolytroposCoordinator.
    public static func createCoordinator(
        configuration: PolytroposCoordinatorConfiguration = .default,
        containerCapsule: MediaContainerCapsuleWrapper? = nil,
        artifactStoreAdapter: ArtifactStoreAdapter? = nil
    ) -> PolytroposCoordinator {
        if let capsule = containerCapsule {
            return PolytroposCoordinator(
                configuration: configuration,
                containerCapsule: capsule,
                artifactStoreAdapter: artifactStoreAdapter
            )
        } else {
            return PolytroposCoordinator(
                configuration: configuration,
                artifactStoreAdapter: artifactStoreAdapter
            )
        }
    }

    /// Creates a VideoIngestionService with the given configuration.
    ///
    /// - Parameters:
    ///   - configuration: Ingestion configuration.
    ///   - containerCapsule: Optional pre-configured MediaContainerCapsuleWrapper.
    ///   - workDirectory: Optional work directory.
    /// - Returns: A configured VideoIngestionService.
    public static func createIngestionService(
        configuration: VideoIngestionConfiguration = .default,
        containerCapsule: MediaContainerCapsuleWrapper? = nil,
        workDirectory: URL? = nil
    ) -> VideoIngestionService {
        VideoIngestionService(
            configuration: configuration,
            containerCapsule: containerCapsule,
            workDirectory: workDirectory
        )
    }
}
