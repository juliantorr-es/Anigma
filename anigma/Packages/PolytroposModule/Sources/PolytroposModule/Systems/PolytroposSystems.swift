//
//  PolytroposSystems.swift
//  PolytroposModule
//
//  ECS systems for the Polytropos video processing pipeline.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
import MediaContainerCapsule
import TelemetryCore

// MARK: - Media Ingest System

extension MediaIngestSystem {
    public typealias MediaContainerCapsuleWrapperAlias = MediaContainerCapsuleWrapper
}

/// Discovers, classifies, and normalizes media files.
public struct MediaIngestSystem: System {
    public let name = "MediaIngest"

    private let workDirectory: URL
    private let supportedVideoExtensions = ["mp4", "mov", "m4v", "mkv", "avi", "mxf", "mts"]
    private let supportedAudioExtensions = ["wav", "mp3", "m4a", "aac", "flac", "aiff"]
    private let containerCapsule: MediaContainerCapsuleWrapperAlias?
    private let telemetryEmitter: ((String, [String: TelemetryCore.TelemetryValue]) async -> Void)?

    public init(
        workDirectory: URL,
        containerCapsule: MediaContainerCapsuleWrapperAlias? = nil,
        telemetryEmitter: ((String, [String: TelemetryCore.TelemetryValue]) async -> Void)? = nil
    ) {
        self.workDirectory = workDirectory
        self.containerCapsule = containerCapsule
        self.telemetryEmitter = telemetryEmitter
    }

    public func update(world: World) async {
        // Query for project entities that need media discovery
        let projectEntities = await world.entitiesWith(ProjectComponent.self)

        for entityId in projectEntities {
            guard let project = await world.getComponent(entityId, ProjectComponent.self),
                project.status == .created
            else {
                continue
            }

            // Mark project as ingesting
            var updatedProject = project
            updatedProject.status = .ingesting
            updatedProject.modifiedAt = Date()
            await world.addComponent(entityId, updatedProject)

            await Logger.shared.info(
                "Starting media ingest for project: \(project.name)",
                category: "Polytropos"
            )
        }

        // Process pending media assets
        let assetEntities = await world.entitiesWith(MediaAssetComponent.self)

        for entityId in assetEntities {
            guard var asset = await world.getComponent(entityId, MediaAssetComponent.self),
                asset.status == .pending
            else {
                continue
            }

            asset.status = .analyzing
            await world.addComponent(entityId, asset)

            // Extract metadata
            await extractMediaMetadata(for: entityId, asset: asset, world: world)
        }
    }

    private func extractMediaMetadata(
        for entityId: EntityId,
        asset: MediaAssetComponent,
        world: World
    ) async {
        let fileURL = URL(fileURLWithPath: asset.originalPath)
        let startTime = Date()

        let (duration, frameRate, sampleRate, videoMetadata, audioMetadata) = await analyzeWithCapsule(
            fileURL: fileURL,
            mediaType: asset.mediaType
        )

        let analysisTime = Date().timeIntervalSince(startTime)

        await emitTelemetry(
            operation: "media_analysis",
            duration: analysisTime,
            success: videoMetadata != nil || audioMetadata != nil,
            mediaType: asset.mediaType.rawValue,
            capsuleUsed: containerCapsule != nil
        )

        let temporalMetadata = TemporalMetadataComponent(
            duration: duration,
            captureStartTime: nil,
            frameRate: asset.mediaType == .video ? frameRate : nil,
            sampleRate: Double(sampleRate)
        )
        await world.addComponent(entityId, temporalMetadata)

        if let videoMetadata = videoMetadata {
            await world.addComponent(entityId, videoMetadata)
        }

        if let audioMetadata = audioMetadata {
            await world.addComponent(entityId, audioMetadata)
        }

        var updatedAsset = asset
        updatedAsset.status = .ready
        await world.addComponent(entityId, updatedAsset)

        await Logger.shared.debug(
            "Extracted metadata for asset: \(asset.originalPath) (analysis time: \(String(format: "%.3f", analysisTime))s)",
            category: "Polytropos"
        )
    }

    private func analyzeWithCapsule(
        fileURL: URL,
        mediaType: MediaType
    ) async -> (
        duration: TimeInterval,
        frameRate: Double,
        sampleRate: UInt32,
        videoMetadata: VideoMetadataComponent?,
        audioMetadata: AudioMetadataComponent?
    ) {
        var duration: TimeInterval = 0
        var frameRate: Double = mediaType == .video ? 30.0 : 0
        var sampleRate: UInt32 = mediaType == .video ? 48000 : 44100
        var videoMeta: VideoMetadataComponent?
        var audioMeta: AudioMetadataComponent?

        if let capsule = containerCapsule {
            do {
                let report = try capsule.analyzeFile(at: fileURL)

                duration = Double(report.totalDurationUs) / 1_000_000.0

                for stream in report.streams where stream.type == .video {
                    if let videoInfo = try? capsule.getVideoStreamInfo(at: stream.index) {
                        frameRate = Double(videoInfo.frameRate.num) / Double(videoInfo.frameRate.den)
                        sampleRate = videoInfo.sampleRate

                        videoMeta = VideoMetadataComponent(
                            width: Int(videoInfo.width),
                            height: Int(videoInfo.height),
                            codec: videoCodecName(videoInfo.codec),
                            bitrate: Int(videoInfo.bitRate) > 0 ? Int(videoInfo.bitRate) : nil,
                            isHDR: false
                        )
                    }
                    break
                }

                for stream in report.streams where stream.type == .audio {
                    if let audioInfo = try? capsule.getAudioStreamInfo(at: stream.index) {
                        sampleRate = audioInfo.sampleRate

                        audioMeta = AudioMetadataComponent(
                            channelCount: Int(audioInfo.channels),
                            sampleRate: Double(audioInfo.sampleRate),
                            codec: audioCodecName(audioInfo.codec),
                            bitrate: Int(audioInfo.bitRate) > 0 ? Int(audioInfo.bitRate) : nil
                        )
                    }
                    break
                }

                if videoMeta == nil && mediaType == .video {
                    videoMeta = VideoMetadataComponent(
                        width: 1920,
                        height: 1080,
                        codec: "H.264",
                        isHDR: false
                    )
                }

                if audioMeta == nil {
                    audioMeta = AudioMetadataComponent(
                        channelCount: 2,
                        sampleRate: Double(sampleRate),
                        codec: "AAC"
                    )
                }

                return (duration, frameRate, sampleRate, videoMeta, audioMeta)

            } catch {
                await Logger.shared.warning(
                    "Capsule analysis failed for \(fileURL.path), using fallback: \(error.localizedDescription)",
                    category: "Polytropos"
                )
            }
        }

        return fallbackAnalysis(mediaType: mediaType, fileURL: fileURL)
    }

    private func fallbackAnalysis(
        mediaType: MediaType,
        fileURL: URL
    ) -> (
        duration: TimeInterval,
        frameRate: Double,
        sampleRate: UInt32,
        videoMetadata: VideoMetadataComponent?,
        audioMetadata: AudioMetadataComponent?
    ) {
        let durationEstimate = estimateDurationSeconds(for: mediaType, fileURL: fileURL)
        let sampleRateValue: UInt32 = mediaType == .video ? 48000 : 44100

        let videoMeta: VideoMetadataComponent? = mediaType == .video
            ? VideoMetadataComponent(
                width: 1920,
                height: 1080,
                codec: "H.264",
                isHDR: false
            )
            : nil

        let audioMeta = AudioMetadataComponent(
            channelCount: 2,
            sampleRate: Double(sampleRateValue),
            codec: "AAC"
        )

        return (durationEstimate, mediaType == .video ? 30.0 : 0, sampleRateValue, videoMeta, audioMeta)
    }

    private func videoCodecName(_ codec: VideoCodec) -> String {
        switch codec {
        case .h264: return "H.264"
        case .h265: return "HEVC"
        case .vp9: return "VP9"
        case .av1: return "AV1"
        case .mpeg2: return "MPEG-2"
        case .mpeg4: return "MPEG-4"
        case .vc1: return "VC-1"
        case .theora: return "Theora"
        case .unknown: return "Unknown"
        }
    }

    private func audioCodecName(_ codec: AudioCodec) -> String {
        switch codec {
        case .aac: return "AAC"
        case .mp3: return "MP3"
        case .opus: return "Opus"
        case .vorbis: return "Vorbis"
        case .flac: return "FLAC"
        case .pcmS16LE: return "PCM 16-bit"
        case .pcmF32LE: return "PCM 32-bit float"
        case .unknown: return "Unknown"
        }
    }

    private func emitTelemetry(
        operation: String,
        duration: TimeInterval,
        success: Bool,
        mediaType: String,
        capsuleUsed: Bool
    ) async {
        guard let emitter = telemetryEmitter else { return }
        await emitter(operation, [
            "duration_ms": .double(duration * 1000),
            "success": .boolean(success),
            "media_type": .string(mediaType),
            "capsule_used": .boolean(capsuleUsed)
        ])
    }

    private func estimateDurationSeconds(for mediaType: MediaType, fileURL: URL) -> TimeInterval {
        if let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size])
            as? NSNumber {
            let bytes = size.doubleValue
            let bytesPerSecond: Double = mediaType == .video ? 5_000_000 : 320_000
            return max(1, bytes / bytesPerSecond)
        }
        return mediaType == .video ? 30 : 10
    }
}

// MARK: - Audio Sync System

/// Aligns cameras by audio cross-correlation.
public struct AudioSyncSystem: System {
    public let name = "AudioSync"

    public init() {}

    public func update(world: World) async {
        // Query for clusters pending sync
        let clusterEntities = await world.entitiesWith(MulticamClusterComponent.self)

        for entityId in clusterEntities {
            guard var cluster = await world.getComponent(entityId, MulticamClusterComponent.self),
                cluster.status == .pending
            else {
                continue
            }

            cluster.status = .syncing
            await world.addComponent(entityId, cluster)

            await performSync(for: entityId, cluster: cluster, world: world)
        }
    }

    private func performSync(
        for clusterId: EntityId,
        cluster: MulticamClusterComponent,
        world: World
    ) async {
        // Stub implementation - actual would do audio cross-correlation

        guard let referenceId = cluster.referenceAssetId ?? cluster.assetIds.first else {
            return
        }

        for assetId in cluster.assetIds {
            let isReference = assetId == referenceId
            let syncData = SyncDataComponent(
                clusterId: cluster.id,
                offsetFromReference: isReference ? 0 : 0.0,  // Would be computed
                confidence: isReference ? 1.0 : 0.85,
                syncMethod: .audio,
                isReference: isReference
            )
            await world.addComponent(assetId, syncData)
        }

        var updatedCluster = cluster
        updatedCluster.status = .synced
        updatedCluster.referenceAssetId = referenceId
        await world.addComponent(clusterId, updatedCluster)

        await Logger.shared.info(
            "Synced cluster: \(cluster.name) with \(cluster.assetIds.count) assets",
            category: "Polytropos"
        )
    }
}

// MARK: - Audio Analysis System

/// Beat detection, structure analysis, applause detection.
public struct AudioAnalysisSystem: System {
    public let name = "AudioAnalysis"

    public init() {}

    public func update(world: World) async {
        // Query for synced clusters needing analysis
        let clusterEntities = await world.entitiesWith(MulticamClusterComponent.self)

        for entityId in clusterEntities {
            guard var cluster = await world.getComponent(entityId, MulticamClusterComponent.self),
                cluster.status == .synced
            else {
                continue
            }

            cluster.status = .analyzing
            await world.addComponent(entityId, cluster)

            // Analyze audio from reference asset
            if let referenceId = cluster.referenceAssetId {
                await analyzeAudio(for: referenceId, clusterId: entityId, world: world)
            }
        }
    }

    private func analyzeAudio(
        for assetId: EntityId,
        clusterId: EntityId,
        world: World
    ) async {
        // Stub implementation - actual would use audio analysis libraries

        let analysis = AudioAnalysisComponent(
            tempo: 120.0,
            beatOnsets: stride(from: 0.0, to: 180.0, by: 0.5).map { $0 },
            structuralSegments: [
                AudioSegment(
                    range: TimeRange(start: 0, end: 30),
                    segmentType: .intro,
                    confidence: 0.8
                ),
                AudioSegment(
                    range: TimeRange(start: 30, end: 90),
                    segmentType: .verse,
                    confidence: 0.85
                ),
                AudioSegment(
                    range: TimeRange(start: 90, end: 150),
                    segmentType: .chorus,
                    confidence: 0.9
                )
            ],
            energyCurve: (0..<1800).map { _ in Float.random(in: 0.3...0.9) },
            energySamplesPerSecond: 10,
            applauseIntervals: [
                TimeRange(start: 175, end: 180)
            ]
        )

        await world.addComponent(assetId, analysis)

        await Logger.shared.debug(
            "Completed audio analysis for asset",
            category: "Polytropos"
        )
    }
}

// MARK: - Video Analysis System

/// Stability, sharpness, subject detection, framing analysis.
public struct VideoAnalysisSystem: System {
    public let name = "VideoAnalysis"

    public init() {}

    public func update(world: World) async {
        // Query for video assets in analyzing clusters
        let assetEntities = await world.entitiesWith(MediaAssetComponent.self)

        for entityId in assetEntities {
            guard let asset = await world.getComponent(entityId, MediaAssetComponent.self),
                asset.mediaType == .video,
                asset.status == .ready,
                await world.getComponent(entityId, VideoAnalysisComponent.self) == nil
            else {
                continue
            }

            await analyzeVideo(for: entityId, world: world)
        }
    }

    private func analyzeVideo(for assetId: EntityId, world: World) async {
        // Stub implementation - actual would use Vision framework

        let frameAnalysis: [FrameAnalysis] = stride(from: 0.0, to: 180.0, by: 0.5).map { time in
            FrameAnalysis(
                time: time,
                sharpness: Float.random(in: 0.6...0.95),
                motionMagnitude: Float.random(in: 0...0.3),
                exposure: Float.random(in: 0.4...0.6),
                contrast: Float.random(in: 0.5...0.8),
                saturation: Float.random(in: 0.4...0.7),
                subjectCount: Int.random(in: 0...3),
                frameSceneType: .stage
            )
        }

        let analysis = VideoAnalysisComponent(
            frameAnalysis: frameAnalysis,
            windowSizeSeconds: 0.5,
            qualityAssessment: VideoQualityAssessment(
                overallScore: 0.8,
                averageSharpness: 0.75,
                stabilityScore: 0.85,
                exposureConsistency: 0.9,
                usablePercentage: 0.95
            )
        )

        await world.addComponent(assetId, analysis)

        // Add camera classification
        let classification = CameraClassificationComponent(
            angleType: [.wide, .medium, .close].randomElement()!,
            subjectCoverage: .stage,
            stabilityRating: .stable,
            qualityScore: 0.8,
            classificationConfidence: 0.85
        )
        await world.addComponent(assetId, classification)

        await Logger.shared.debug(
            "Completed video analysis for asset",
            category: "Polytropos"
        )
    }
}

// MARK: - Auto Edit System

/// Generates timeline from analysis features.
public struct AutoEditSystem: System {
    public let name = "AutoEdit"

    public init() {}

    public func update(world: World) async {
        // Query for analyzed clusters ready for auto-edit
        let clusterEntities = await world.entitiesWith(MulticamClusterComponent.self)

        for entityId in clusterEntities {
            guard var cluster = await world.getComponent(entityId, MulticamClusterComponent.self),
                cluster.status == .analyzing
            else {
                continue
            }

            // Check if all assets have been analyzed
            let allAnalyzed = await checkAllAssetsAnalyzed(cluster: cluster, world: world)

            if allAnalyzed {
                await generateAutoEdit(for: entityId, cluster: cluster, world: world)

                cluster.status = .ready
                await world.addComponent(entityId, cluster)
            }
        }
    }

    private func checkAllAssetsAnalyzed(cluster: MulticamClusterComponent, world: World) async
        -> Bool {
        for assetId in cluster.assetIds {
            if await world.getComponent(assetId, VideoAnalysisComponent.self) == nil {
                return false
            }
        }
        return true
    }

    private func generateAutoEdit(
        for clusterId: EntityId,
        cluster: MulticamClusterComponent,
        world: World
    ) async {
        // Create timeline entity
        let timelineEntity = await world.createEntity()

        let timeline = TimelineComponent(
            name: "Auto Edit - \(cluster.name)",
            sourceClusterId: cluster.id,
            duration: cluster.duration,
            status: .autoEdited,
            frameRate: 30,
            aspectRatio: .horizontal16x9,
            isPrimary: true
        )
        await world.addComponent(timelineEntity, timeline)

        // Generate simple edit
        var segments: [ClipSegment] = []
        var currentTime: TimeInterval = 0
        let segmentDuration: TimeInterval = 4.0
        var assetIndex = 0

        while currentTime < cluster.duration {
            let assetId = cluster.assetIds[assetIndex % cluster.assetIds.count]

            let segment = ClipSegment(
                sourceAssetId: assetId,
                sourceIn: currentTime,
                sourceOut: min(currentTime + segmentDuration, cluster.duration),
                timelineIn: currentTime
            )
            segments.append(segment)

            currentTime += segmentDuration
            assetIndex += 1
        }

        let tracks = TimelineTracksComponent(
            videoSegments: segments,
            audioSegments: [],  // Would reference audio from reference asset
            overlaySegments: [],
            transitions: []
        )
        await world.addComponent(timelineEntity, tracks)

        await Logger.shared.info(
            "Generated auto-edit timeline with \(segments.count) segments",
            category: "Polytropos"
        )
    }
}

// MARK: - Caption System

/// ASR and subtitle management.
public struct CaptionSystem: System {
    public let name = "Caption"

    public init() {}

    public func update(world: World) async {
        // Query for timelines needing captions
        let timelineEntities = await world.entitiesWith(TimelineComponent.self)

        for entityId in timelineEntities {
            guard let timeline = await world.getComponent(entityId, TimelineComponent.self),
                timeline.status == .autoEdited,
                await world.getComponent(entityId, TranscriptComponent.self) == nil
            else {
                continue
            }

            await generateCaptions(for: entityId, world: world)
        }
    }

    private func generateCaptions(for timelineId: EntityId, world: World) async {
        // Stub implementation - actual would call ASR service

        let transcript = TranscriptComponent(
            languageCode: "en",
            segments: [
                TranscriptSegment(
                    startTime: 0,
                    endTime: 5,
                    text: "Welcome to the show!",
                    confidence: 0.95
                )
            ],
            confidence: 0.9,
            asrModel: "whisper-large-v3"
        )

        await world.addComponent(timelineId, transcript)

        // Generate caption track
        let captionTrack = CaptionTrackComponent(
            entries: [
                CaptionEntry(
                    startTime: 0,
                    endTime: 5,
                    text: "Welcome to the show!"
                )
            ]
        )
        await world.addComponent(timelineId, captionTrack)

        await Logger.shared.debug(
            "Generated captions for timeline",
            category: "Polytropos"
        )
    }
}

// MARK: - Branding System

/// Applies lower thirds, watermarks, intro/outro.
public struct BrandingSystem: System {
    public let name = "Branding"

    public init() {}

    public func update(world: World) async {
        // Query for timelines with branding profiles
        let timelineEntities = await world.entitiesWith(TimelineComponent.self)

        for entityId in timelineEntities {
            guard let timeline = await world.getComponent(entityId, TimelineComponent.self),
                var tracks = await world.getComponent(entityId, TimelineTracksComponent.self)
            else {
                continue
            }

            // Check if branding already applied
            if !tracks.overlaySegments.isEmpty {
                continue
            }

            // Add watermark overlay
            let watermark = OverlaySegment(
                overlayType: .watermark,
                timelineIn: 0,
                duration: timeline.duration,
                position: NormalizedRect(x: 0.85, y: 0.85, width: 0.1, height: 0.1),
                opacity: 0.6,
                content: OverlayContent(templateId: "watermark"),
                animation: .none
            )

            tracks.overlaySegments.append(watermark)
            await world.addComponent(entityId, tracks)
        }
    }
}

// MARK: - Reframe System

/// Multi-aspect safe region computation.
public struct ReframeSystem: System {
    public let name = "Reframe"

    public init() {}

    public func update(world: World) async {
        // Query for timelines needing reframe data
        let timelineEntities = await world.entitiesWith(TimelineComponent.self)

        for entityId in timelineEntities {
            guard await world.getComponent(entityId, TimelineComponent.self) != nil,
                await world.getComponent(entityId, ReframeInstructionsComponent.self) == nil
            else {
                continue
            }

            // Generate reframe instructions for vertical export
            let reframe = ReframeInstructionsComponent(
                instructions: [
                    .vertical9x16: [
                        ReframeKeyframe(time: 0, centerX: 0.5, centerY: 0.5, scale: 1.2)
                    ]
                ],
                autoReframeMode: .subjectTracking
            )

            await world.addComponent(entityId, reframe)
        }
    }
}

// MARK: - Export System

/// Renders timeline to target format.
public struct ExportSystem: System {
    public let name = "Export"

    private let workDirectory: URL

    public init(workDirectory: URL) {
        self.workDirectory = workDirectory
    }

    public func update(world: World) async {
        // Query for pending export jobs
        let jobEntities = await world.entitiesWith(ExportJobComponent.self)

        for entityId in jobEntities {
            guard var job = await world.getComponent(entityId, ExportJobComponent.self),
                job.status == .pending
            else {
                continue
            }

            job.status = .preparing
            job.startedAt = Date()
            await world.addComponent(entityId, job)

            await performExport(for: entityId, job: job, world: world)
        }
    }

    private func performExport(
        for jobId: EntityId,
        job: ExportJobComponent,
        world: World
    ) async {
        // Stub implementation - actual would use AVAssetExportSession

        var updatedJob = job
        updatedJob.status = .rendering
        updatedJob.progress = 0.5
        await world.addComponent(jobId, updatedJob)

        // Simulate render completion
        updatedJob.status = .completed
        updatedJob.progress = 1.0
        updatedJob.completedAt = Date()
        updatedJob.outputPath =
            workDirectory
            .appendingPathComponent("\(job.id.uuidString).mp4")
            .path
        updatedJob.outputSize = 50_000_000
        updatedJob.renderDuration = 10.0
        await world.addComponent(jobId, updatedJob)

        await Logger.shared.info(
            "Export completed: \(updatedJob.outputPath ?? "unknown")",
            category: "Polytropos"
        )
    }
}
