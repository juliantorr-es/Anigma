import AnigmaPrimitives

import AnigmaPrimitives

//
//  MusicSystems.swift
//  PolytroposModule
//
//  ECS systems for music generation pipeline.
//  These systems integrate with Polytropos' existing workflow.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Music Generation System

/// System that processes music cues and generates background music.
public struct MusicGenerationSystem: System {
    public let name = "MusicGeneration"
    public let phase: SystemPhase = .processing

    private let generationService: MusicGenerationService
    private let workDirectory: URL

    public init(
        generationService: MusicGenerationService,
        workDirectory: URL
    ) {
        self.generationService = generationService
        self.workDirectory = workDirectory
    }

    public func update(world: World) async {
        // Find all pending music generation jobs
        let allJobs = await world.query(MusicGenerationJobComponent.self)
        var jobs: [(EntityId, MusicGenerationJobComponent)] = []

        for job in allJobs {
            if job.1.status == .queued {
                jobs.append(job)
            }
        }

        for (entity, job) in jobs {
            // Update status to running
            var updatedJob = job
            updatedJob.status = .running
            updatedJob.startedAt = Date()
            updatedJob.currentStage = .selectingSource
            await world.addComponent(entity, updatedJob)

            do {
                // Get the cue
                guard let cue = await world.getComponent(job.cueEntityId, MusicCueComponent.self) else {
                    throw MusicSystemError.cueNotFound(job.cueEntityId)
                }

                // Get scene analysis if available
                let sceneAnalysis: AudioAnalysisComponent?
                if let targetEntity = cue.targetEntityId {
                    sceneAnalysis = await world.getComponent(targetEntity, AudioAnalysisComponent.self)
                } else {
                    sceneAnalysis = nil
                }

                // Update progress
                updatedJob.currentStage = .generatingArrangement
                updatedJob.progress = 0.3
                await world.addComponent(entity, updatedJob)

                // Generate the music
                let result = try await generationService.generateMusic(
                    for: cue,
                    sceneAnalysis: sceneAnalysis,
                    userKitId: nil
                )

                // Update progress
                updatedJob.currentStage = .renderingAudio
                updatedJob.progress = 0.7
                await world.addComponent(entity, updatedJob)

                // Save audio to file
                let outputURL = workDirectory
                    .appendingPathComponent("generated")
                    .appendingPathComponent("\(job.id).wav")

                try FileManager.default.createDirectory(
                    at: outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try result.audioData.write(to: outputURL)

                let musicAssetEntity = await world.createEntity()
                let mediaAsset = MediaAssetComponent(
                    originalPath: outputURL.path,
                    mediaType: .audio,
                    importedAt: Date()
                )
                await world.addComponent(musicAssetEntity, mediaAsset)

                let generatedMusicAsset = GeneratedMusicAssetComponent(
                    mediaAssetId: musicAssetEntity,
                    provenance: result.provenance,
                    isStem: false
                )
                await world.addComponent(musicAssetEntity, generatedMusicAsset)

                // Save stems if generated
                var stemAssetIds: [String: EntityId] = [:]
                for (stemType, stemData) in result.stems {
                    let stemURL = workDirectory
                        .appendingPathComponent("generated")
                        .appendingPathComponent("\(job.id)_\(stemType.rawValue).wav")
                    try stemData.write(to: stemURL)

                    let stemEntity = await world.createEntity()
                    let stemMediaAsset = MediaAssetComponent(
                        originalPath: stemURL.path,
                        mediaType: .audio,
                        importedAt: Date()
                    )
                    await world.addComponent(stemEntity, stemMediaAsset)

                    let stemGenerated = GeneratedMusicAssetComponent(
                        mediaAssetId: stemEntity,
                        provenance: result.provenance,
                        isStem: true,
                        stemType: stemType,
                        fullMixAssetId: musicAssetEntity
                    )
                    await world.addComponent(stemEntity, stemGenerated)

                    stemAssetIds[stemType.rawValue] = stemEntity
                }

                // Update cue with generated asset
                var updatedCue = cue
                updatedCue.status = .generated
                updatedCue.generatedAssetId = musicAssetEntity
                updatedCue.generationInfo = MusicGenerationInfo(
                    symbolicSourceId: result.provenance.symbolicSourceId,
                    modelVersion: result.provenance.generatorVersion,
                    renderPresetId: result.provenance.vibeProfileId.raw,
                    durationSeconds: result.durationSeconds,
                    stemCount: result.stems.count
                )
                await world.addComponent(job.cueEntityId, updatedCue)

                // Complete the job
                updatedJob.status = .completed
                updatedJob.currentStage = .completed
                updatedJob.progress = 1.0
                updatedJob.completedAt = Date()
                updatedJob.outputAssetId = musicAssetEntity
                updatedJob.stemAssetIds = stemAssetIds
                updatedJob.symbolicSourceId = result.provenance.symbolicSourceId
                await world.addComponent(entity, updatedJob)

            } catch {
                // Mark job as failed
                updatedJob.status = .failed
                updatedJob.currentStage = .failed
                updatedJob.completedAt = Date()
                updatedJob.errorInfo = error.localizedDescription
                await world.addComponent(entity, updatedJob)

                // Update cue status
                if var cue = await world.getComponent(job.cueEntityId, MusicCueComponent.self) {
                    cue.status = .failed
                    await world.addComponent(job.cueEntityId, cue)
                }
            }
        }
    }
}

// MARK: - Music Cue Attachment System

/// System that auto-attaches music cues to scenes based on project settings.
public struct MusicCueAttachmentSystem: System {
    public let name = "MusicCueAttachment"
    public let phase: SystemPhase = .postProcessing

    public init() {}

    public func update(world: World) async {
        // Find projects with auto-music enabled
        let projects = await world.query(ProjectComponent.self)

        for (projectEntityId, _) in projects {
            // Check if auto-music is enabled via project settings
            guard let settings = await world.getComponent(projectEntityId, ProjectMusicSettingsComponent.self),
                  settings.autoGenerateMusic else {
                continue
            }

            // Get project references
            guard let refs = await world.getComponent(projectEntityId, ProjectReferencesComponent.self) else {
                continue
            }

            // Find timelines that need music
            for timelineId in refs.timelineIds {
                guard let timeline = await world.getComponent(timelineId, TimelineComponent.self) else {
                    continue
                }

                // Check if timeline already has music cues
                let existingCues = await world.query(MusicCueComponent.self)

                var hasCue = false
                for (_, cue) in existingCues {
                    if cue.targetEntityId == timelineId {
                        hasCue = true
                        break
                    }
                }

                if !hasCue {
                    // Create music cue for the timeline
                    let cueEntity = await world.createEntity()

                    let cue = MusicCueComponent(
                        targetEntityId: timelineId,
                        timeRange: TimeRange(start: 0, end: timeline.duration),
                        vibeProfileId: settings.defaultVibeProfile,
                        intensity: settings.defaultIntensity,
                        complexity: settings.defaultComplexity,
                        autoDuck: settings.autoDuck,
                        duckLevel: settings.duckLevel
                    )
                    await world.addComponent(cueEntity, cue)

                    // Queue generation job
                    let job = MusicGenerationJobComponent(
                        cueEntityId: cueEntity,
                        projectEntityId: projectEntityId
                    )
                    let jobEntity = await world.createEntity()
                    await world.addComponent(jobEntity, job)
                }
            }
        }
    }
}

// MARK: - Music Mixing System

/// System that mixes generated music into timeline audio.
public struct MusicMixingSystem: System {
    public let name = "MusicMixing"
    public let phase: SystemPhase = .postProcessing

    public init() {}

    public func update(world: World) async {
        // Find completed music cues that need mixing
        let cues = await world.query(MusicCueComponent.self)

        for (_, cue) in cues {
            guard cue.status == .generated && cue.generatedAssetId != nil,
                  let targetEntityId = cue.targetEntityId else {
                continue
            }

            // Check if this cue is already mixed into timeline
            if let mixInfo = await world.getComponent(targetEntityId, MusicMixInfoComponent.self),
               mixInfo.mixedCueIds.contains(cue.id) {
                continue
            }

            // Create or update mix info
            var mixInfo = await world.getComponent(targetEntityId, MusicMixInfoComponent.self)
                ?? MusicMixInfoComponent()

            // Add cue to the mix list
            mixInfo.musicCueIds.append(cue.id)
            mixInfo.mixedCueIds.insert(cue.id)

            // Store mixing parameters
            if cue.autoDuck {
                mixInfo.duckingEnabled = true
                mixInfo.duckLevel = cue.duckLevel
            }

            await world.addComponent(targetEntityId, mixInfo)
        }
    }
}

// MARK: - Supporting Components

/// Project-level music settings.
public struct ProjectMusicSettingsComponent: Component, Codable {
    /// Whether to auto-generate music for new scenes/timelines.
    public var autoGenerateMusic: Bool

    /// Default vibe profile for auto-generated music.
    public var defaultVibeProfile: VibeProfileId

    /// Default intensity.
    public var defaultIntensity: Float

    /// Default complexity.
    public var defaultComplexity: Float

    /// Whether to auto-duck under speech.
    public var autoDuck: Bool

    /// Duck level.
    public var duckLevel: Float

    /// User's preferred instrument kit (if any).
    public var preferredKitId: UUID?

    public init(
        autoGenerateMusic: Bool = false,
        defaultVibeProfile: VibeProfileId = .cinematicEpic,
        defaultIntensity: Float = 0.5,
        defaultComplexity: Float = 0.5,
        autoDuck: Bool = true,
        duckLevel: Float = 0.3,
        preferredKitId: UUID? = nil
    ) {
        self.autoGenerateMusic = autoGenerateMusic
        self.defaultVibeProfile = defaultVibeProfile
        self.defaultIntensity = defaultIntensity
        self.defaultComplexity = defaultComplexity
        self.autoDuck = autoDuck
        self.duckLevel = duckLevel
        self.preferredKitId = preferredKitId
    }
}

/// Information about music mixed into a timeline/scene.
public struct MusicMixInfoComponent: Component, Codable {
    /// Music cue IDs attached to this entity.
    public var musicCueIds: [UUID]

    /// Cue IDs that have been mixed.
    public var mixedCueIds: Set<UUID>

    /// Whether ducking is enabled.
    public var duckingEnabled: Bool

    /// Duck level when speech detected.
    public var duckLevel: Float

    /// Overall music volume.
    public var musicVolume: Float

    public init(
        musicCueIds: [UUID] = [],
        mixedCueIds: Set<UUID> = [],
        duckingEnabled: Bool = true,
        duckLevel: Float = 0.3,
        musicVolume: Float = 0.7
    ) {
        self.musicCueIds = musicCueIds
        self.mixedCueIds = mixedCueIds
        self.duckingEnabled = duckingEnabled
        self.duckLevel = duckLevel
        self.musicVolume = musicVolume
    }
}

// MARK: - Errors

/// Errors from music systems.
public enum MusicSystemError: Error, LocalizedError {
    case cueNotFound(EntityId)
    case projectNotFound(EntityId)
    case timelineNotFound(EntityId)
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cueNotFound(let id):
            return "Music cue not found: \(id)"
        case .projectNotFound(let id):
            return "Project not found: \(id)"
        case .timelineNotFound(let id):
            return "Timeline not found: \(id)"
        case .generationFailed(let reason):
            return "Music generation failed: \(reason)"
        }
    }
}
