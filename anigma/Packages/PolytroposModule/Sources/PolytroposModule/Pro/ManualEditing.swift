//
//  ManualEditing.swift
//  PolytroposModule
//
//  Manual editing operations with full undo/redo support.
//  Phase 2 of Polytropos Pro roadmap.
//

import AnigmaCore
import AnigmaPrimitives
import Foundation

// MARK: - Edit Operations

/// Protocol for all edit operations.
public protocol EditOperation: Sendable {
    /// Operation type for history.
    var actionType: EditActionType { get }

    /// Human-readable description.
    var description: String { get }

    /// Execute the operation.
    func execute(on timeline: inout MultiTrackTimelineComponent) throws

    /// Reverse the operation.
    func undo(on timeline: inout MultiTrackTimelineComponent) throws
}

// MARK: - Clip Operations

/// Add a clip to the timeline.
public struct AddClipOperation: EditOperation {
    public let actionType: EditActionType = .addClip
    public let description: String

    public let clip: ProClipSegment
    public let trackIndex: Int
    public let isVideo: Bool

    public init(clip: ProClipSegment, trackIndex: Int, isVideo: Bool) {
        self.clip = clip
        self.trackIndex = trackIndex
        self.isVideo = isVideo
        self.description = "Add clip to \(isVideo ? "V" : "A")\(trackIndex + 1)"
    }

    public func execute(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            guard trackIndex < timeline.videoTracks.count else {
                throw EditError.invalidTrackIndex
            }
            timeline.videoTracks[trackIndex].segments.append(clip)
            timeline.videoTracks[trackIndex].segments.sort { $0.timelineIn < $1.timelineIn }
        } else {
            guard trackIndex < timeline.audioTracks.count else {
                throw EditError.invalidTrackIndex
            }
            // Convert to audio segment
            let audioSegment = ProAudioSegment(
                id: clip.id,
                sourceAssetId: clip.sourceAssetId,
                sourceIn: clip.sourceIn,
                sourceOut: clip.sourceOut,
                timelineIn: clip.timelineIn,
                timelineDuration: clip.timelineDuration
            )
            timeline.audioTracks[trackIndex].segments.append(audioSegment)
            timeline.audioTracks[trackIndex].segments.sort { $0.timelineIn < $1.timelineIn }
        }
    }

    public func undo(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            timeline.videoTracks[trackIndex].segments.removeAll { $0.id == clip.id }
        } else {
            timeline.audioTracks[trackIndex].segments.removeAll { $0.id == clip.id }
        }
    }
}

/// Remove a clip from the timeline.
public struct RemoveClipOperation: EditOperation {
    public let actionType: EditActionType = .removeClip
    public let description: String

    public let clipId: UUID
    public let trackIndex: Int
    public let isVideo: Bool
    private var removedClip: ProClipSegment?
    private var removedAudioClip: ProAudioSegment?

    public init(clipId: UUID, trackIndex: Int, isVideo: Bool) {
        self.clipId = clipId
        self.trackIndex = trackIndex
        self.isVideo = isVideo
        self.description = "Remove clip from \(isVideo ? "V" : "A")\(trackIndex + 1)"
    }

    public mutating func captureState(from timeline: MultiTrackTimelineComponent) {
        if isVideo {
            removedClip = timeline.videoTracks[trackIndex].segments.first { $0.id == clipId }
        } else {
            removedAudioClip = timeline.audioTracks[trackIndex].segments.first { $0.id == clipId }
        }
    }

    public func execute(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            timeline.videoTracks[trackIndex].segments.removeAll { $0.id == clipId }
        } else {
            timeline.audioTracks[trackIndex].segments.removeAll { $0.id == clipId }
        }
    }

    public func undo(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo, let clip = removedClip {
            timeline.videoTracks[trackIndex].segments.append(clip)
            timeline.videoTracks[trackIndex].segments.sort { $0.timelineIn < $1.timelineIn }
        } else if let clip = removedAudioClip {
            timeline.audioTracks[trackIndex].segments.append(clip)
            timeline.audioTracks[trackIndex].segments.sort { $0.timelineIn < $1.timelineIn }
        }
    }
}

/// Move a clip in the timeline.
public struct MoveClipOperation: EditOperation {
    public let actionType: EditActionType = .moveClip
    public let description = "Move clip"

    public let clipId: UUID
    public let sourceTrackIndex: Int
    public let targetTrackIndex: Int
    public let newTimelineIn: TimeInterval
    public let isVideo: Bool

    private var originalTimelineIn: TimeInterval = 0

    public init(
        clipId: UUID,
        sourceTrackIndex: Int,
        targetTrackIndex: Int,
        newTimelineIn: TimeInterval,
        isVideo: Bool
    ) {
        self.clipId = clipId
        self.sourceTrackIndex = sourceTrackIndex
        self.targetTrackIndex = targetTrackIndex
        self.newTimelineIn = newTimelineIn
        self.isVideo = isVideo
    }

    public mutating func captureState(from timeline: MultiTrackTimelineComponent) {
        if isVideo {
            if let clip = timeline.videoTracks[sourceTrackIndex].segments.first(where: { $0.id == clipId }) {
                originalTimelineIn = clip.timelineIn
            }
        } else {
            if let clip = timeline.audioTracks[sourceTrackIndex].segments.first(where: { $0.id == clipId }) {
                originalTimelineIn = clip.timelineIn
            }
        }
    }

    public func execute(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            guard let index = timeline.videoTracks[sourceTrackIndex].segments.firstIndex(where: { $0.id == clipId }) else {
                throw EditError.clipNotFound
            }

            var clip = timeline.videoTracks[sourceTrackIndex].segments.remove(at: index)
            clip.timelineIn = newTimelineIn

            if targetTrackIndex != sourceTrackIndex {
                timeline.videoTracks[targetTrackIndex].segments.append(clip)
            } else {
                timeline.videoTracks[sourceTrackIndex].segments.append(clip)
            }

            timeline.videoTracks[targetTrackIndex].segments.sort { $0.timelineIn < $1.timelineIn }
        } else {
            guard let index = timeline.audioTracks[sourceTrackIndex].segments.firstIndex(where: { $0.id == clipId }) else {
                throw EditError.clipNotFound
            }

            var clip = timeline.audioTracks[sourceTrackIndex].segments.remove(at: index)
            clip.timelineIn = newTimelineIn

            if targetTrackIndex != sourceTrackIndex {
                timeline.audioTracks[targetTrackIndex].segments.append(clip)
            } else {
                timeline.audioTracks[sourceTrackIndex].segments.append(clip)
            }

            timeline.audioTracks[targetTrackIndex].segments.sort { $0.timelineIn < $1.timelineIn }
        }
    }

    public func undo(on timeline: inout MultiTrackTimelineComponent) throws {
        // Reverse the move
        let reverseOp = MoveClipOperation(
            clipId: clipId,
            sourceTrackIndex: targetTrackIndex,
            targetTrackIndex: sourceTrackIndex,
            newTimelineIn: originalTimelineIn,
            isVideo: isVideo
        )
        try reverseOp.execute(on: &timeline)
    }
}

// MARK: - Trim Operations

/// Trim clip start.
public struct TrimClipStartOperation: EditOperation {
    public let actionType: EditActionType = .trimClipStart
    public let description = "Trim clip start"

    public let clipId: UUID
    public let trackIndex: Int
    public let isVideo: Bool
    public let newSourceIn: TimeInterval
    public let newTimelineIn: TimeInterval

    private var originalSourceIn: TimeInterval = 0
    private var originalTimelineIn: TimeInterval = 0
    private var originalDuration: TimeInterval = 0

    public init(
        clipId: UUID,
        trackIndex: Int,
        isVideo: Bool,
        newSourceIn: TimeInterval,
        newTimelineIn: TimeInterval
    ) {
        self.clipId = clipId
        self.trackIndex = trackIndex
        self.isVideo = isVideo
        self.newSourceIn = newSourceIn
        self.newTimelineIn = newTimelineIn
    }

    public mutating func captureState(from timeline: MultiTrackTimelineComponent) {
        if isVideo {
            if let clip = timeline.videoTracks[trackIndex].segments.first(where: { $0.id == clipId }) {
                originalSourceIn = clip.sourceIn
                originalTimelineIn = clip.timelineIn
                originalDuration = clip.timelineDuration
            }
        }
    }

    public func execute(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            guard let index = timeline.videoTracks[trackIndex].segments.firstIndex(where: { $0.id == clipId }) else {
                throw EditError.clipNotFound
            }

            let durationChange = newTimelineIn - timeline.videoTracks[trackIndex].segments[index].timelineIn
            timeline.videoTracks[trackIndex].segments[index].sourceIn = newSourceIn
            timeline.videoTracks[trackIndex].segments[index].timelineIn = newTimelineIn
            timeline.videoTracks[trackIndex].segments[index].timelineDuration -= durationChange
        }
    }

    public func undo(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            guard let index = timeline.videoTracks[trackIndex].segments.firstIndex(where: { $0.id == clipId }) else {
                throw EditError.clipNotFound
            }

            timeline.videoTracks[trackIndex].segments[index].sourceIn = originalSourceIn
            timeline.videoTracks[trackIndex].segments[index].timelineIn = originalTimelineIn
            timeline.videoTracks[trackIndex].segments[index].timelineDuration = originalDuration
        }
    }
}

/// Trim clip end.
public struct TrimClipEndOperation: EditOperation {
    public let actionType: EditActionType = .trimClipEnd
    public let description = "Trim clip end"

    public let clipId: UUID
    public let trackIndex: Int
    public let isVideo: Bool
    public let newSourceOut: TimeInterval
    public let newDuration: TimeInterval

    private var originalSourceOut: TimeInterval = 0
    private var originalDuration: TimeInterval = 0

    public init(
        clipId: UUID,
        trackIndex: Int,
        isVideo: Bool,
        newSourceOut: TimeInterval,
        newDuration: TimeInterval
    ) {
        self.clipId = clipId
        self.trackIndex = trackIndex
        self.isVideo = isVideo
        self.newSourceOut = newSourceOut
        self.newDuration = newDuration
    }

    public mutating func captureState(from timeline: MultiTrackTimelineComponent) {
        if isVideo {
            if let clip = timeline.videoTracks[trackIndex].segments.first(where: { $0.id == clipId }) {
                originalSourceOut = clip.sourceOut
                originalDuration = clip.timelineDuration
            }
        }
    }

    public func execute(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            guard let index = timeline.videoTracks[trackIndex].segments.firstIndex(where: { $0.id == clipId }) else {
                throw EditError.clipNotFound
            }

            timeline.videoTracks[trackIndex].segments[index].sourceOut = newSourceOut
            timeline.videoTracks[trackIndex].segments[index].timelineDuration = newDuration
        }
    }

    public func undo(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            guard let index = timeline.videoTracks[trackIndex].segments.firstIndex(where: { $0.id == clipId }) else {
                throw EditError.clipNotFound
            }

            timeline.videoTracks[trackIndex].segments[index].sourceOut = originalSourceOut
            timeline.videoTracks[trackIndex].segments[index].timelineDuration = originalDuration
        }
    }
}

/// Split clip at playhead.
public struct SplitClipOperation: EditOperation {
    public let actionType: EditActionType = .splitClip
    public let description = "Split clip"

    public let clipId: UUID
    public let trackIndex: Int
    public let isVideo: Bool
    public let splitTime: TimeInterval

    private var newClipId = UUID()

    public init(
        clipId: UUID,
        trackIndex: Int,
        isVideo: Bool,
        splitTime: TimeInterval
    ) {
        self.clipId = clipId
        self.trackIndex = trackIndex
        self.isVideo = isVideo
        self.splitTime = splitTime
    }

    public func execute(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            guard let index = timeline.videoTracks[trackIndex].segments.firstIndex(where: { $0.id == clipId }) else {
                throw EditError.clipNotFound
            }

            let originalClip = timeline.videoTracks[trackIndex].segments[index]
            let splitOffset = splitTime - originalClip.timelineIn

            guard splitOffset > 0 && splitOffset < originalClip.timelineDuration else {
                throw EditError.invalidSplitPoint
            }

            // Modify first clip
            timeline.videoTracks[trackIndex].segments[index].timelineDuration = splitOffset
            timeline.videoTracks[trackIndex].segments[index].sourceOut = originalClip.sourceIn + splitOffset

            // Create second clip
            let secondClip = ProClipSegment(
                id: newClipId,
                sourceAssetId: originalClip.sourceAssetId,
                sourceIn: originalClip.sourceIn + splitOffset,
                sourceOut: originalClip.sourceOut,
                timelineIn: splitTime,
                timelineDuration: originalClip.timelineDuration - splitOffset,
                transform: originalClip.transform,
                speed: originalClip.speed,
                reversePlayback: originalClip.reversePlayback,
                opacity: originalClip.opacity,
                blendMode: originalClip.blendMode,
                colorGradeId: originalClip.colorGradeId,
                linkedAudioId: originalClip.linkedAudioId,
                isSelected: false,
                isLocked: originalClip.isLocked
            )

            timeline.videoTracks[trackIndex].segments.insert(secondClip, at: index + 1)
        }
    }

    public func undo(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            // Remove second clip
            timeline.videoTracks[trackIndex].segments.removeAll { $0.id == newClipId }

            // Restore first clip to original
            guard let index = timeline.videoTracks[trackIndex].segments.firstIndex(where: { $0.id == clipId }) else {
                throw EditError.clipNotFound
            }

            if let secondClip = timeline.videoTracks[trackIndex].segments.first(where: { $0.id == newClipId }) {
                timeline.videoTracks[trackIndex].segments[index].timelineDuration += secondClip.timelineDuration
                timeline.videoTracks[trackIndex].segments[index].sourceOut = secondClip.sourceOut
            }
        }
    }
}

// MARK: - Ripple Edit

/// Ripple delete operation (removes clip and closes gap).
public struct RippleDeleteOperation: EditOperation {
    public let actionType: EditActionType = .rippleEdit
    public let description = "Ripple delete"

    public let clipId: UUID
    public let trackIndex: Int
    public let isVideo: Bool

    private var removedClip: ProClipSegment?
    private var affectedClips: [(UUID, TimeInterval)] = [] // (clipId, originalTimelineIn)

    public init(clipId: UUID, trackIndex: Int, isVideo: Bool) {
        self.clipId = clipId
        self.trackIndex = trackIndex
        self.isVideo = isVideo
    }

    public mutating func captureState(from timeline: MultiTrackTimelineComponent) {
        if isVideo {
            removedClip = timeline.videoTracks[trackIndex].segments.first { $0.id == clipId }

            if let clip = removedClip {
                // Capture all clips that will be shifted
                affectedClips = timeline.videoTracks[trackIndex].segments
                    .filter { $0.timelineIn > clip.timelineOut }
                    .map { ($0.id, $0.timelineIn) }
            }
        }
    }

    public func execute(on timeline: inout MultiTrackTimelineComponent) throws {
        guard let clip = removedClip else {
            throw EditError.clipNotFound
        }

        if isVideo {
            let clipDuration = clip.timelineDuration

            // Remove the clip
            timeline.videoTracks[trackIndex].segments.removeAll { $0.id == clipId }

            // Shift all subsequent clips left
            for i in 0..<timeline.videoTracks[trackIndex].segments.count {
                if timeline.videoTracks[trackIndex].segments[i].timelineIn > clip.timelineIn {
                    timeline.videoTracks[trackIndex].segments[i].timelineIn -= clipDuration
                }
            }
        }
    }

    public func undo(on timeline: inout MultiTrackTimelineComponent) throws {
        guard let clip = removedClip else { return }

        if isVideo {
            // Restore clip positions
            for (id, originalTime) in affectedClips {
                if let index = timeline.videoTracks[trackIndex].segments.firstIndex(where: { $0.id == id }) {
                    timeline.videoTracks[trackIndex].segments[index].timelineIn = originalTime
                }
            }

            // Re-add the removed clip
            timeline.videoTracks[trackIndex].segments.append(clip)
            timeline.videoTracks[trackIndex].segments.sort { $0.timelineIn < $1.timelineIn }
        }
    }
}

// MARK: - Track Operations

/// Add a new track.
public struct AddTrackOperation: EditOperation {
    public let actionType: EditActionType = .addTrack
    public let description: String

    public let isVideo: Bool
    public let trackName: String
    private var addedTrackId = UUID()

    public init(isVideo: Bool, trackName: String? = nil) {
        self.isVideo = isVideo
        self.trackName = trackName ?? (isVideo ? "V" : "A")
        self.description = "Add \(isVideo ? "video" : "audio") track"
    }

    public func execute(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            let trackNumber = timeline.videoTracks.count + 1
            let track = VideoTrack(id: addedTrackId, name: "\(trackName)\(trackNumber)")
            timeline.videoTracks.append(track)
        } else {
            let trackNumber = timeline.audioTracks.count + 1
            let track = AudioTrack(id: addedTrackId, name: "\(trackName)\(trackNumber)")
            timeline.audioTracks.append(track)
        }
    }

    public func undo(on timeline: inout MultiTrackTimelineComponent) throws {
        if isVideo {
            timeline.videoTracks.removeAll { $0.id == addedTrackId }
        } else {
            timeline.audioTracks.removeAll { $0.id == addedTrackId }
        }
    }
}

// MARK: - Edit Errors

/// Errors that can occur during editing.
public enum EditError: Error, LocalizedError {
    case invalidTrackIndex
    case clipNotFound
    case invalidSplitPoint
    case trackNotEmpty
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTrackIndex:
            return "Invalid track index"
        case .clipNotFound:
            return "Clip not found in timeline"
        case .invalidSplitPoint:
            return "Invalid split point - must be within clip bounds"
        case .trackNotEmpty:
            return "Cannot remove track that contains clips"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        }
    }
}

// MARK: - Edit History Manager

/// Manages undo/redo history for a timeline.
public actor EditHistoryManager {

    private var undoStack: [any EditOperation] = []
    private var redoStack: [any EditOperation] = []
    private let maxHistoryDepth: Int

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public init(maxHistoryDepth: Int = 100) {
        self.maxHistoryDepth = maxHistoryDepth
    }

    /// Executes an operation and adds it to history.
    public func execute(
        _ operation: any EditOperation,
        on timeline: inout MultiTrackTimelineComponent
    ) throws {
        try operation.execute(on: &timeline)

        undoStack.append(operation)
        redoStack.removeAll()

        // Limit history depth
        if undoStack.count > maxHistoryDepth {
            undoStack.removeFirst()
        }
    }

    /// Undoes the last operation.
    public func undo(on timeline: inout MultiTrackTimelineComponent) throws {
        guard let operation = undoStack.popLast() else { return }

        try operation.undo(on: &timeline)
        redoStack.append(operation)
    }

    /// Redoes the last undone operation.
    public func redo(on timeline: inout MultiTrackTimelineComponent) throws {
        guard let operation = redoStack.popLast() else { return }

        try operation.execute(on: &timeline)
        undoStack.append(operation)
    }

    /// Clears all history.
    public func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Returns description of the next undo operation.
    public func undoDescription() -> String? {
        undoStack.last?.description
    }

    /// Returns description of the next redo operation.
    public func redoDescription() -> String? {
        redoStack.last?.description
    }
}

// MARK: - Manual Editing Service

/// High-level service for manual editing operations.
public actor ManualEditingService {

    private let world: World
    private var historyManagers: [EntityId: EditHistoryManager] = [:]

    public init(world: World) {
        self.world = world
    }

    /// Gets or creates a history manager for a timeline.
    private func historyManager(for timelineId: EntityId) -> EditHistoryManager {
        if let manager = historyManagers[timelineId] {
            return manager
        }
        let manager = EditHistoryManager()
        historyManagers[timelineId] = manager
        return manager
    }

    /// Adds a clip to the timeline.
    public func addClip(
        to timelineId: EntityId,
        clip: ProClipSegment,
        trackIndex: Int,
        isVideo: Bool
    ) async throws {
        guard var timeline = await world.getComponent(timelineId, MultiTrackTimelineComponent.self) else {
            throw EditError.operationFailed("Timeline not found")
        }

        let operation = AddClipOperation(clip: clip, trackIndex: trackIndex, isVideo: isVideo)
        try await historyManager(for: timelineId).execute(operation, on: &timeline)

        await world.addComponent(timelineId, timeline)
    }

    /// Removes a clip from the timeline.
    public func removeClip(
        from timelineId: EntityId,
        clipId: UUID,
        trackIndex: Int,
        isVideo: Bool
    ) async throws {
        guard var timeline = await world.getComponent(timelineId, MultiTrackTimelineComponent.self) else {
            throw EditError.operationFailed("Timeline not found")
        }

        var operation = RemoveClipOperation(clipId: clipId, trackIndex: trackIndex, isVideo: isVideo)
        operation.captureState(from: timeline)
        try await historyManager(for: timelineId).execute(operation, on: &timeline)

        await world.addComponent(timelineId, timeline)
    }

    /// Splits a clip at the specified time.
    public func splitClip(
        in timelineId: EntityId,
        clipId: UUID,
        trackIndex: Int,
        isVideo: Bool,
        at time: TimeInterval
    ) async throws {
        guard var timeline = await world.getComponent(timelineId, MultiTrackTimelineComponent.self) else {
            throw EditError.operationFailed("Timeline not found")
        }

        let operation = SplitClipOperation(clipId: clipId, trackIndex: trackIndex, isVideo: isVideo, splitTime: time)
        try await historyManager(for: timelineId).execute(operation, on: &timeline)

        await world.addComponent(timelineId, timeline)
    }

    /// Undoes the last operation.
    public func undo(timelineId: EntityId) async throws {
        guard var timeline = await world.getComponent(timelineId, MultiTrackTimelineComponent.self) else {
            throw EditError.operationFailed("Timeline not found")
        }

        try await historyManager(for: timelineId).undo(on: &timeline)
        await world.addComponent(timelineId, timeline)
    }

    /// Redoes the last undone operation.
    public func redo(timelineId: EntityId) async throws {
        guard var timeline = await world.getComponent(timelineId, MultiTrackTimelineComponent.self) else {
            throw EditError.operationFailed("Timeline not found")
        }

        try await historyManager(for: timelineId).redo(on: &timeline)
        await world.addComponent(timelineId, timeline)
    }

    /// Returns whether undo is available.
    public func canUndo(timelineId: EntityId) async -> Bool {
        await historyManager(for: timelineId).canUndo
    }

    /// Returns whether redo is available.
    public func canRedo(timelineId: EntityId) async -> Bool {
        await historyManager(for: timelineId).canRedo
    }
}
