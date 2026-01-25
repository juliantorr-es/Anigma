//
//  AutoEditEngine.swift
//  PolytroposModule
//
//  The brain of automatic editing: converts analysis features
//  into timeline decisions using configurable edit profiles.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Auto Edit Engine

/// Core engine for automatic multicam editing.
/// Uses analysis data and edit profiles to generate timeline decisions.
public actor AutoEditEngine {

    private let world: World

    public init(world: World) {
        self.world = world
    }

    // MARK: - Main Entry Point

    /// Generates an auto-edit timeline for a synced cluster.
    public func generateEdit(
        for clusterId: EntityId,
        profile: EditProfile
    ) async throws -> EntityId {
        guard let cluster = await world.getComponent(clusterId, MulticamClusterComponent.self) else {
            throw AutoEditError.clusterNotFound(clusterId)
        }

        guard cluster.status == .synced || cluster.status == .analyzing || cluster.status == .ready else {
            throw AutoEditError.clusterNotReady(cluster.status)
        }

        // Gather analysis data
        let analysisBundle = try await gatherAnalysis(for: cluster)

        // Generate edit decisions
        let decisions = generateEditDecisions(
            analysis: analysisBundle,
            profile: profile,
            duration: cluster.duration
        )

        // Create timeline entity
        let timelineId = await world.createEntity()

        let timeline = TimelineComponent(
            name: "Auto Edit - \(cluster.name)",
            sourceClusterId: cluster.id,
            duration: cluster.duration,
            status: .autoEdited,
            frameRate: 30,
            aspectRatio: .horizontal16x9,
            isPrimary: true
        )
        await world.addComponent(timelineId, timeline)

        // Convert decisions to clip segments
        let segments = decisionsToSegments(decisions, analysis: analysisBundle)

        let tracks = TimelineTracksComponent(
            videoSegments: segments,
            audioSegments: createAudioSegments(from: analysisBundle, duration: cluster.duration),
            overlaySegments: [],
            transitions: []
        )
        await world.addComponent(timelineId, tracks)

        // Generate scenes based on audio structure
        if profile.sceneDetection.enabled {
            await generateScenes(
                for: timelineId,
                analysis: analysisBundle,
                profile: profile.sceneDetection
            )
        }

        await Logger.shared.info(
            "Generated auto-edit: \(segments.count) segments, \(cluster.duration)s duration",
            category: "Polytropos"
        )

        return timelineId
    }

    // MARK: - Analysis Gathering

    private func gatherAnalysis(for cluster: MulticamClusterComponent) async throws -> AnalysisBundle {
        var cameraAnalyses: [EntityId: CameraAnalysis] = [:]
        var referenceAudio: AudioAnalysisComponent?

        for assetId in cluster.assetIds {
            guard let asset = await world.getComponent(assetId, MediaAssetComponent.self),
                  let sync = await world.getComponent(assetId, SyncDataComponent.self) else {
                continue
            }

            // Get audio analysis from reference
            if sync.isReference,
               let audioAnalysis = await world.getComponent(assetId, AudioAnalysisComponent.self) {
                referenceAudio = audioAnalysis
            }

            // Get video analysis for cameras
            if asset.mediaType == .video {
                let videoAnalysis = await world.getComponent(assetId, VideoAnalysisComponent.self)
                let classification = await world.getComponent(assetId, CameraClassificationComponent.self)

                cameraAnalyses[assetId] = CameraAnalysis(
                    assetId: assetId,
                    syncOffset: sync.effectiveOffset,
                    videoAnalysis: videoAnalysis,
                    classification: classification
                )
            }
        }

        guard !cameraAnalyses.isEmpty else {
            throw AutoEditError.noVideoAssets
        }

        return AnalysisBundle(
            cameras: cameraAnalyses,
            audio: referenceAudio,
            duration: cluster.duration
        )
    }

    // MARK: - Edit Decision Generation

    private func generateEditDecisions(
        analysis: AnalysisBundle,
        profile: EditProfile,
        duration: TimeInterval
    ) -> [EditDecision] {
        var decisions: [EditDecision] = []
        var currentTime: TimeInterval = 0
        var lastCameraId: EntityId?
        var lastCrowdTime: TimeInterval = -1000

        let _: TimeInterval = 0.25 // Decision granularity

        while currentTime < duration {
            // Determine target shot length based on energy
            let targetLength = computeTargetShotLength(
                at: currentTime,
                analysis: analysis,
                profile: profile
            )

            // Find best cut point near target
            let idealCutTime = currentTime + targetLength
            let cutPoint = findBestCutPoint(
                around: idealCutTime,
                analysis: analysis,
                profile: profile
            )

            let segmentEnd = min(cutPoint, duration)

            // Select camera for this segment
            let (cameraId, shouldUseCrowd) = selectCamera(
                from: currentTime,
                to: segmentEnd,
                analysis: analysis,
                profile: profile,
                lastCamera: lastCameraId,
                lastCrowdTime: lastCrowdTime
            )

            let decision = EditDecision(
                startTime: currentTime,
                endTime: segmentEnd,
                cameraId: cameraId,
                isCrowdShot: shouldUseCrowd,
                cutReason: determineCutReason(at: segmentEnd, analysis: analysis)
            )
            decisions.append(decision)

            lastCameraId = cameraId
            if shouldUseCrowd {
                lastCrowdTime = currentTime
            }
            currentTime = segmentEnd
        }

        return decisions
    }

    private func computeTargetShotLength(
        at time: TimeInterval,
        analysis: AnalysisBundle,
        profile: EditProfile
    ) -> TimeInterval {
        var target = profile.timing.targetShotLength

        if profile.energyMapping.dynamicCutDensity,
           let audio = analysis.audio {
            let energy = getEnergyAt(time: time, audio: audio)

            if energy < profile.energyMapping.lowEnergyThreshold {
                target *= profile.energyMapping.lowEnergyMultiplier
            } else if energy > profile.energyMapping.highEnergyThreshold {
                target *= profile.energyMapping.highEnergyMultiplier
            }
        }

        // Add variance
        let variance = profile.timing.variance * target
        let randomOffset = Double.random(in: -variance...variance)
        target += randomOffset

        // Clamp to bounds
        target = max(profile.timing.minimumShotLength, target)
        target = min(profile.timing.maximumShotLength, target)

        return target
    }

    private func findBestCutPoint(
        around idealTime: TimeInterval,
        analysis: AnalysisBundle,
        profile: EditProfile
    ) -> TimeInterval {
        guard profile.musicAlignment.alignToBeats,
              let audio = analysis.audio else {
            return idealTime
        }

        // Find nearest beat
        let tolerance = profile.musicAlignment.beatSnapTolerance
        var bestBeat: TimeInterval?
        var bestDistance: TimeInterval = .infinity

        for beat in audio.beatOnsets {
            let distance = Swift.abs(beat - idealTime)
            if distance < tolerance && distance < bestDistance {
                // Check if this is a phrase boundary or downbeat
                if profile.musicAlignment.preferPhraseBoundaries {
                    // Simplified: check if near a structural boundary
                    for segment in audio.structuralSegments {
                        if Swift.abs(segment.range.start - beat) < 0.1 || Swift.abs(segment.range.end - beat) < 0.1 {
                            bestDistance = distance * 0.5 // Prefer phrase boundaries
                            bestBeat = beat
                        }
                    }
                }

                if bestBeat == nil || distance < bestDistance {
                    bestDistance = distance
                    bestBeat = beat
                }
            }
        }

        if let beat = bestBeat {
            // Interpolate based on alignment strength
            let strength = profile.musicAlignment.alignmentStrength
            return idealTime * (1 - strength) + beat * strength
        }

        return idealTime
    }

    private func selectCamera(
        from startTime: TimeInterval,
        to endTime: TimeInterval,
        analysis: AnalysisBundle,
        profile: EditProfile,
        lastCamera: EntityId?,
        lastCrowdTime: TimeInterval
    ) -> (EntityId, Bool) {
        var scores: [EntityId: Double] = [:]
        var crowdCandidates: [EntityId] = []

        for (cameraId, camera) in analysis.cameras {
            var score = computeCameraScore(
                camera: camera,
                from: startTime,
                to: endTime,
                profile: profile.cameraSelection
            )

            // Apply repeat penalty
            if cameraId == lastCamera {
                score *= (1.0 - profile.cameraSelection.repeatPenalty)
            }

            // Track crowd cameras
            if camera.classification?.subjectCoverage == .crowd {
                crowdCandidates.append(cameraId)
            } else {
                scores[cameraId] = score
            }
        }

        // Check if we should use a crowd shot
        let shouldUseCrowd = shouldInsertCrowdShot(
            at: startTime,
            analysis: analysis,
            profile: profile.crowdBehavior,
            lastCrowdTime: lastCrowdTime
        ) && !crowdCandidates.isEmpty

        if shouldUseCrowd {
            // Score crowd cameras
            for crowdId in crowdCandidates {
                if let camera = analysis.cameras[crowdId] {
                    scores[crowdId] = computeCameraScore(
                        camera: camera,
                        from: startTime,
                        to: endTime,
                        profile: profile.cameraSelection
                    )
                }
            }
        }

        // Select highest scoring camera
        let bestCamera = scores.max { $0.value < $1.value }?.key
            ?? analysis.cameras.keys.first!

        let isCrowd = crowdCandidates.contains(bestCamera) && shouldUseCrowd

        return (bestCamera, isCrowd)
    }

    private func computeCameraScore(
        camera: CameraAnalysis,
        from startTime: TimeInterval,
        to endTime: TimeInterval,
        profile: CameraSelectionProfile
    ) -> Double {
        guard let videoAnalysis = camera.videoAnalysis else {
            return 0.5 // Default score if no analysis
        }

        // Get frame analyses in time range
        let frames = videoAnalysis.frameAnalysis.filter { frame in
            frame.time >= startTime && frame.time <= endTime
        }

        guard !frames.isEmpty else {
            return 0.5
        }

        // Compute average metrics
        let avgSharpness = frames.map { Double($0.sharpness) }.reduce(0, +) / Double(frames.count)
        let avgStability = frames.map { 1.0 - Double($0.motionMagnitude) }.reduce(0, +) / Double(frames.count)
        let avgExposure = frames.map { 1.0 - Swift.abs(Double($0.exposure) - 0.5) * 2 }.reduce(0, +) / Double(frames.count)
        let avgSubjectPresence = frames.map { Double($0.subjectCount) / 3.0 }.reduce(0, +) / Double(frames.count)

        var score = (
            avgSharpness * profile.sharpnessWeight +
            avgStability * profile.stabilityWeight +
            avgExposure * profile.exposureWeight +
            avgSubjectPresence * profile.subjectPresenceWeight
        )

        // Apply angle preference
        if let preferred = profile.preferredAngleType,
           camera.classification?.angleType == preferred {
            score *= (1.0 + profile.anglePreferenceStrength * 0.5)
        }

        return score
    }

    private func shouldInsertCrowdShot(
        at time: TimeInterval,
        analysis: AnalysisBundle,
        profile: CrowdShotProfile,
        lastCrowdTime: TimeInterval
    ) -> Bool {
        guard profile.enabled else { return false }

        // Check interval
        if time - lastCrowdTime < profile.minIntervalBetweenCrowdShots {
            return false
        }

        guard let audio = analysis.audio else { return false }

        // Check if in applause
        if profile.useDuringApplause {
            for applause in audio.applauseIntervals {
                if applause.contains(time) {
                    return true
                }
            }
        }

        // Check if in instrumental section
        if profile.useDuringInstrumental {
            for segment in audio.structuralSegments {
                if segment.range.contains(time) &&
                   (segment.segmentType == .solo || segment.segmentType == .breakdown) {
                    return true
                }
            }
        }

        // Check energy
        if profile.useDuringHighEnergy {
            let energy = getEnergyAt(time: time, audio: audio)
            if energy > 0.8 {
                return true
            }
        }

        return false
    }

    private func getEnergyAt(time: TimeInterval, audio: AudioAnalysisComponent) -> Double {
        guard audio.energySamplesPerSecond > 0, !audio.energyCurve.isEmpty else {
            return 0.5
        }

        let index = Int(time * Double(audio.energySamplesPerSecond))
        guard index >= 0, index < audio.energyCurve.count else {
            return 0.5
        }

        return Double(audio.energyCurve[index])
    }

    private func determineCutReason(at time: TimeInterval, analysis: AnalysisBundle) -> CutReason {
        guard let audio = analysis.audio else { return .timing }

        // Check if on beat
        for beat in audio.beatOnsets {
            if Swift.abs(beat - time) < 0.1 {
                return .beat
            }
        }

        // Check if at segment boundary
        for segment in audio.structuralSegments {
            if Swift.abs(segment.range.start - time) < 0.2 || Swift.abs(segment.range.end - time) < 0.2 {
                return .segmentBoundary
            }
        }

        return .timing
    }

    // MARK: - Segment Generation

    private func decisionsToSegments(_ decisions: [EditDecision], analysis: AnalysisBundle) -> [ClipSegment] {
        return decisions.map { decision in
            let syncOffset = analysis.cameras[decision.cameraId]?.syncOffset ?? 0

            return ClipSegment(
                sourceAssetId: decision.cameraId,
                sourceIn: decision.startTime + syncOffset,
                sourceOut: decision.endTime + syncOffset,
                timelineIn: decision.startTime
            )
        }
    }

    private func createAudioSegments(from analysis: AnalysisBundle, duration: TimeInterval) -> [ClipSegment] {
        // Use reference audio for the entire duration
        guard let referenceCamera = analysis.cameras.values.first(where: { _ in
            analysis.audio != nil // Has audio analysis means it's reference or has good audio
        }) else {
            return []
        }

        return [ClipSegment(
            sourceAssetId: referenceCamera.assetId,
            sourceIn: 0,
            sourceOut: duration,
            timelineIn: 0
        )]
    }

    // MARK: - Scene Generation

    private func generateScenes(
        for timelineId: EntityId,
        analysis: AnalysisBundle,
        profile: SceneDetectionProfile
    ) async {
        guard let audio = analysis.audio else { return }

        var boundaries: [TimeInterval] = [0]

        // Add boundaries from applause
        if profile.useApplause {
            for applause in audio.applauseIntervals {
                boundaries.append(applause.end)
            }
        }

        // Add boundaries from audio structure
        if profile.useAudioStructure {
            for segment in audio.structuralSegments {
                if segment.segmentType == .intro || segment.segmentType == .outro {
                    boundaries.append(segment.range.end)
                }
            }
        }

        boundaries.append(analysis.duration)
        boundaries.sort()

        // Remove duplicates and merge short segments
        var filteredBoundaries: [TimeInterval] = [0]
        for boundary in boundaries.dropFirst() {
            if boundary - filteredBoundaries.last! >= profile.minimumSceneDuration {
                filteredBoundaries.append(boundary)
            }
        }

        // Ensure we include the end
        if filteredBoundaries.last! < analysis.duration - 1 {
            filteredBoundaries.append(analysis.duration)
        }

        // Create scene entities
        for i in 0..<(filteredBoundaries.count - 1) {
            let sceneId = await world.createEntity()

            let scene = SceneComponent(
                name: "Scene \(i + 1)",
                sceneType: .song,
                sourceRange: TimeRange(
                    start: filteredBoundaries[i],
                    end: filteredBoundaries[i + 1]
                ),
                timelineId: timelineId,
                status: .detected
            )
            await world.addComponent(sceneId, scene)
        }
    }
}

// MARK: - Supporting Types

/// Bundle of analysis data for edit decisions.
struct AnalysisBundle {
    let cameras: [EntityId: CameraAnalysis]
    let audio: AudioAnalysisComponent?
    let duration: TimeInterval
}

/// Analysis data for a single camera.
struct CameraAnalysis {
    let assetId: EntityId
    let syncOffset: TimeInterval
    let videoAnalysis: VideoAnalysisComponent?
    let classification: CameraClassificationComponent?
}

/// A single edit decision.
struct EditDecision {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let cameraId: EntityId
    let isCrowdShot: Bool
    let cutReason: CutReason
}

/// Reason for making a cut at a particular point.
enum CutReason {
    case beat
    case segmentBoundary
    case timing
    case energy
    case manual
}

/// Errors from auto-edit operations.
public enum AutoEditError: Error, LocalizedError {
    case clusterNotFound(EntityId)
    case clusterNotReady(ClusterStatus)
    case noVideoAssets
    case analysisIncomplete(String)

    public var errorDescription: String? {
        switch self {
        case .clusterNotFound(let id):
            return "Cluster not found: \(id)"
        case .clusterNotReady(let status):
            return "Cluster not ready for editing: \(status.rawValue)"
        case .noVideoAssets:
            return "No video assets found in cluster"
        case .analysisIncomplete(let reason):
            return "Analysis incomplete: \(reason)"
        }
    }
}
