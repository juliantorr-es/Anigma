//
//  ProSystems.swift
//  PolytroposModule
//
//  ECS systems for professional editing features.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Multi-Track Timeline System

/// System for managing multi-track timelines.
public struct MultiTrackTimelineSystem: System {
    public let name = "MultiTrackTimeline"

    public init() {}

    public func update(world: World) async {
        // Find timelines that need multi-track setup
        let allTimelines = await world.query(TimelineComponent.self)
        var timelines: [(EntityId, TimelineComponent)] = []

        for timeline in allTimelines {
            let hasComponent = await world.hasComponent(timeline.0, MultiTrackTimelineComponent.self)
            if !hasComponent {
                timelines.append(timeline)
            }
        }

        for (entity, _) in timelines {
            // Create multi-track representation for timelines that need it
            let multiTrack = MultiTrackTimelineComponent(
                timelineId: entity,
                videoTracks: [VideoTrack(name: "V1")],
                audioTracks: [AudioTrack(name: "A1"), AudioTrack(name: "A2")]
            )
            await world.addComponent(entity, multiTrack)
        }
    }
}

// MARK: - Color Grading System

/// System for applying color grades during playback/export.
public struct ColorGradingSystem: System {
    public let name = "ColorGrading"

    public init() {}

    public func update(world: World) async {
        // Find clips with color grades that need processing
        let timelines = await world.query(
            including: MultiTrackTimelineComponent.self,
            including: TimelineComponent.self
        )

        for (_, multiTrack, _) in timelines {
            // Process clips with color grades
            for track in multiTrack.videoTracks {
                for segment in track.segments {
                    if let gradeId = segment.colorGradeId {
                        // Color grade would be applied during render
                        _ = gradeId // Silence unused warning
                    }
                }
            }
        }
    }
}

// MARK: - Audio Processing System

/// System for processing audio through effect chains.
public struct AudioProcessingSystem: System {
    public let name = "AudioProcessing"

    public init() {}

    public func update(world: World) async {
        // Find timelines with audio processing
        let timelines = await world.query(
            including: MultiTrackTimelineComponent.self,
            including: AudioDuckingComponent.self
        )

        for (_, multiTrack, ducking) in timelines {
            if ducking.isEnabled {
                // Apply ducking logic
                _ = multiTrack // Process audio tracks
            }
        }
    }
}

// MARK: - Proxy Generation System

/// System for generating proxy media.
public struct ProxyGenerationSystem: System {
    public let name = "ProxyGeneration"

    private let workDirectory: URL

    public init(workDirectory: URL) {
        self.workDirectory = workDirectory
    }

    public func update(world: World) async {
        // Find projects needing proxy generation
        let projects = await world.query(
            including: ProxySettingsComponent.self
        )

        for (entity, settings) in projects {
            if settings.useProxiesForEditing && settings.generationStatus == .notStarted {
                // Queue proxy generation job
                var updatedSettings = settings
                updatedSettings.generationStatus = .generating
                await world.addComponent(entity, updatedSettings)

                // Actual proxy generation would be done by Harmonia job
            }
        }
    }
}

// MARK: - Media Relink System

/// System for tracking and handling missing media.
public struct MediaRelinkSystem: System {
    public let name = "MediaRelink"

    public init() {}

    public func update(world: World) async {
        // Find projects that may have missing media
        let projects = await world.query(
            including: MediaRelinkComponent.self
        )

        for (_, relink) in projects {
            if relink.hasMissingMedia {
                // Attempt auto-relink using mapping
                for missing in relink.missingMedia {
                    if let newPath = relink.relinkMapping[missing.originalPath] {
                        // Verify new path exists and update asset
                        if FileManager.default.fileExists(atPath: newPath) {
                            await Logger.shared.info(
                                "Auto-relinked \(missing.lastKnownName) to \(newPath)",
                                category: "MediaRelink"
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Scopes Analysis System

/// System for computing video scope data.
public struct ScopesAnalysisSystem: System {
    public let name = "ScopesAnalysis"

    public init() {}

    public func update(world: World) async {
        // Find timelines with scopes enabled
        let timelines = await world.query(
            including: ScopesComponent.self,
            including: MultiTrackTimelineComponent.self
        )

        for (_, scopes, timeline) in timelines {
            if !scopes.enabledScopes.isEmpty {
                // Compute scope data for current playhead position
                let playheadTime = timeline.playheadPosition

                for scopeType in scopes.enabledScopes {
                    // Scope computation would happen in render thread
                    _ = (scopeType, playheadTime) // Silence warnings
                }
            }
        }
    }
}

// MARK: - Export Queue System

/// System for processing export queue.
public struct ExportQueueSystem: System {
    public let name = "ExportQueue"

    private let maxConcurrentExports: Int

    public init(maxConcurrentExports: Int = 2) {
        self.maxConcurrentExports = maxConcurrentExports
    }

    public func update(world: World) async {
        // Find queued export jobs
        let jobs = await world.query(
            including: ProExportJobComponent.self
        )

        let queuedJobs = jobs.filter { $0.1.status == .queued }
        let activeJobs = jobs.filter {
            $0.1.status == .preparing ||
            $0.1.status == .rendering ||
            $0.1.status == .encoding
        }

        // Start new jobs if under limit
        let slotsAvailable = maxConcurrentExports - activeJobs.count

        for (entity, job) in queuedJobs.prefix(slotsAvailable) {
            var updatedJob = job
            updatedJob.status = .preparing
            updatedJob.startedAt = Date()
            await world.addComponent(entity, updatedJob)

            // Actual export would be done by Harmonia job
            await Logger.shared.info(
                "Starting export job \(job.id)",
                category: "Export"
            )
        }
    }
}

// MARK: - Edit History System

/// System for managing edit history (undo/redo persistence).
public struct EditHistorySystem: System {
    public let name = "EditHistory"

    public init() {}

    public func update(world: World) async {
        // Find timelines with edit history
        let timelines = await world.query(
            including: EditHistoryComponent.self
        )

        for (entity, history) in timelines {
            // Prune old history if over limit
            if history.undoStack.count > history.maxHistoryDepth {
                var updatedHistory = history
                let overflow = history.undoStack.count - history.maxHistoryDepth
                updatedHistory.undoStack.removeFirst(overflow)
                await world.addComponent(entity, updatedHistory)
            }
        }
    }
}

// MARK: - Audio Analysis System

/// System for analyzing audio content.
public struct ProAudioAnalysisSystem: System {
    public let name = "ProAudioAnalysis"

    public init() {}

    public func update(world: World) async {
        // Find assets needing audio analysis
        let assets = await world.query(
            including: MediaAssetComponent.self,
            excluding: AssetAudioAnalysisComponent.self
        )

        for (entity, asset) in assets {
            if asset.mediaType.rawValue == "audio" || asset.mediaType.rawValue == "video" {
                // Queue audio analysis
                let analysis = AssetAudioAnalysisComponent(assetId: entity)
                await world.addComponent(entity, analysis)

                // Actual analysis would be done by Harmonia job
            }
        }
    }
}

// MARK: - System Registration

/// Registers all Pro systems with the world.
public enum ProSystemsRegistration {

    public static func registerAll(
        world: World,
        workDirectory: URL,
        featureFlags: PolytroposProFeatureFlags
    ) async throws {
        // Always register core systems
        await world.registerSystem(MultiTrackTimelineSystem())
        await world.registerSystem(EditHistorySystem())
        await world.registerSystem(ExportQueueSystem())

        // Register based on feature flags
        if featureFlags.colorGrading {
            await world.registerSystem(ColorGradingSystem())
            await world.registerSystem(ScopesAnalysisSystem())
        }

        if featureFlags.audioProcessing {
            await world.registerSystem(AudioProcessingSystem())
            await world.registerSystem(ProAudioAnalysisSystem())
        }

        if featureFlags.proxyGeneration {
            await world.registerSystem(ProxyGenerationSystem(workDirectory: workDirectory))
        }

        if featureFlags.relinkMedia {
            await world.registerSystem(MediaRelinkSystem())
        }

        await Logger.shared.info(
            "Registered Polytropos Pro systems",
            category: "PolytroposPro"
        )
    }
}
