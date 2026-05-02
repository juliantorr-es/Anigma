//
//  MusicLearningIntegration.swift
//  PolytroposModule
//
//  Integration with Anigma's self-tuning learning system.
//  Logs user interactions with music generation for improving:
//  - Vibe selection heuristics
//  - Symbolic source selection
//  - Cut density / energy mapping
//  - Instrument / production preferences
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Music Learning Observer

/// Observes user interactions with generated music for learning.
public actor MusicLearningObserver {

    // MARK: - Types

    /// An observed music interaction.
    public struct MusicInteraction: Codable, Sendable {
        public var timestamp: Date
        public var projectId: PolytroposProjectId
        public var cueId: UUID
        public var interactionType: MusicInteractionType
        public var context: MusicInteractionContext
        public var outcome: MusicInteractionOutcome
    }

    /// Type of interaction with music.
    public enum MusicInteractionType: String, Codable, Sendable {
        case generated
        case previewed
        case accepted
        case rejected
        case vibeChanged
        case intensityAdjusted
        case complexityAdjusted
        case replaced
        case stemMuted
        case volumeAdjusted
    }

    /// Context of the interaction.
    public struct MusicInteractionContext: Codable, Sendable {
        public var vibeProfileId: VibeProfileId
        public var symbolicSourceId: String?
        public var tempo: Double
        public var key: MusicalKey
        public var intensity: Float
        public var complexity: Float
        public var sceneDuration: TimeInterval
        public var sceneEnergyAverage: Float?
        public var eventType: EventType?
    }

    /// Outcome of the interaction.
    public struct MusicInteractionOutcome: Codable, Sendable {
        public var finalVibeProfileId: VibeProfileId?
        public var finalIntensity: Float?
        public var finalComplexity: Float?
        public var wasAccepted: Bool
        public var userRating: Int?  // 1-5 if provided
        public var replacementAssetId: EntityId?
    }

    // MARK: - State

    private var interactions: [MusicInteraction] = []
    private let maxBufferSize: Int
    private let flushHandler: @Sendable ([MusicInteraction]) async -> Void

    // MARK: - Initialization

    public init(
        maxBufferSize: Int = 100,
        flushHandler: @escaping @Sendable ([MusicInteraction]) async -> Void
    ) {
        self.maxBufferSize = maxBufferSize
        self.flushHandler = flushHandler
    }

    // MARK: - Recording

    /// Record a music generation event.
    public func recordGeneration(
        projectId: PolytroposProjectId,
        cueId: UUID,
        context: MusicInteractionContext
    ) async {
        let interaction = MusicInteraction(
            timestamp: Date(),
            projectId: projectId,
            cueId: cueId,
            interactionType: .generated,
            context: context,
            outcome: MusicInteractionOutcome(wasAccepted: false)
        )
        await addInteraction(interaction)
    }

    /// Record that user accepted the generated music.
    public func recordAcceptance(
        projectId: PolytroposProjectId,
        cueId: UUID,
        context: MusicInteractionContext,
        rating: Int? = nil
    ) async {
        let interaction = MusicInteraction(
            timestamp: Date(),
            projectId: projectId,
            cueId: cueId,
            interactionType: .accepted,
            context: context,
            outcome: MusicInteractionOutcome(
                finalVibeProfileId: context.vibeProfileId,
                finalIntensity: context.intensity,
                finalComplexity: context.complexity,
                wasAccepted: true,
                userRating: rating
            )
        )
        await addInteraction(interaction)
    }

    /// Record that user rejected the generated music.
    public func recordRejection(
        projectId: PolytroposProjectId,
        cueId: UUID,
        context: MusicInteractionContext,
        reason: RejectionReason? = nil
    ) async {
        let interaction = MusicInteraction(
            timestamp: Date(),
            projectId: projectId,
            cueId: cueId,
            interactionType: .rejected,
            context: context,
            outcome: MusicInteractionOutcome(wasAccepted: false)
        )
        await addInteraction(interaction)
    }

    /// Record that user changed the vibe.
    public func recordVibeChange(
        projectId: PolytroposProjectId,
        cueId: UUID,
        originalContext: MusicInteractionContext,
        newVibeId: VibeProfileId
    ) async {
        var outcome = MusicInteractionOutcome(wasAccepted: false)
        outcome.finalVibeProfileId = newVibeId

        let interaction = MusicInteraction(
            timestamp: Date(),
            projectId: projectId,
            cueId: cueId,
            interactionType: .vibeChanged,
            context: originalContext,
            outcome: outcome
        )
        await addInteraction(interaction)
    }

    /// Record that user adjusted intensity.
    public func recordIntensityAdjustment(
        projectId: PolytroposProjectId,
        cueId: UUID,
        context: MusicInteractionContext,
        newIntensity: Float
    ) async {
        var outcome = MusicInteractionOutcome(wasAccepted: false)
        outcome.finalIntensity = newIntensity

        let interaction = MusicInteraction(
            timestamp: Date(),
            projectId: projectId,
            cueId: cueId,
            interactionType: .intensityAdjusted,
            context: context,
            outcome: outcome
        )
        await addInteraction(interaction)
    }

    /// Record that user adjusted complexity.
    public func recordComplexityAdjustment(
        projectId: PolytroposProjectId,
        cueId: UUID,
        context: MusicInteractionContext,
        newComplexity: Float
    ) async {
        var outcome = MusicInteractionOutcome(wasAccepted: false)
        outcome.finalComplexity = newComplexity

        let interaction = MusicInteraction(
            timestamp: Date(),
            projectId: projectId,
            cueId: cueId,
            interactionType: .complexityAdjusted,
            context: context,
            outcome: outcome
        )
        await addInteraction(interaction)
    }

    /// Record that user replaced generated music with their own.
    public func recordReplacement(
        projectId: PolytroposProjectId,
        cueId: UUID,
        context: MusicInteractionContext,
        replacementAssetId: EntityId
    ) async {
        var outcome = MusicInteractionOutcome(wasAccepted: false)
        outcome.replacementAssetId = replacementAssetId

        let interaction = MusicInteraction(
            timestamp: Date(),
            projectId: projectId,
            cueId: cueId,
            interactionType: .replaced,
            context: context,
            outcome: outcome
        )
        await addInteraction(interaction)
    }

    // MARK: - Flushing

    private func addInteraction(_ interaction: MusicInteraction) async {
        interactions.append(interaction)

        if interactions.count >= maxBufferSize {
            await flush()
        }
    }

    /// Flush buffered interactions to the learning system.
    public func flush() async {
        guard !interactions.isEmpty else { return }

        let toFlush = interactions
        interactions = []

        await flushHandler(toFlush)
    }
}

/// Reason for rejecting generated music.
public enum RejectionReason: String, Codable, Sendable {
    case wrongVibe
    case tooBusy
    case tooSimple
    case wrongTempo
    case wrongEnergy
    case poorQuality
    case other
}

// MARK: - Music Learning Trainer

/// Trainer that processes music interactions to improve generation.
public actor MusicLearningTrainer {

    // MARK: - Types

    /// Learned preferences for a vibe profile.
    public struct LearnedVibePreferences: Codable {
        public var vibeProfileId: VibeProfileId
        public var acceptanceRate: Float
        public var averageIntensityDelta: Float
        public var averageComplexityDelta: Float
        public var commonEventTypes: [EventType: Int]
        public var sampleCount: Int
    }

    /// Per-user or per-project preferences.
    public struct UserMusicPreferences: Codable {
        public var preferredVibes: [VibeProfileId]
        public var averageIntensity: Float
        public var averageComplexity: Float
        public var rejectionPatterns: [RejectionReason: Int]
    }

    // MARK: - State

    private var vibePreferences: [VibeProfileId: LearnedVibePreferences] = [:]
    private var interactionHistory: [MusicLearningObserver.MusicInteraction] = []

    // MARK: - Training

    /// Process a batch of interactions for learning.
    public func processBatch(_ interactions: [MusicLearningObserver.MusicInteraction]) async {
        for interaction in interactions {
            await processInteraction(interaction)
        }

        // Periodically compute updated preferences
        if interactionHistory.count % 50 == 0 {
            await recomputePreferences()
        }
    }

    private func processInteraction(_ interaction: MusicLearningObserver.MusicInteraction) async {
        interactionHistory.append(interaction)

        let vibeId = interaction.context.vibeProfileId

        // Update or create vibe preferences
        var prefs = vibePreferences[vibeId] ?? LearnedVibePreferences(
            vibeProfileId: vibeId,
            acceptanceRate: 0.5,
            averageIntensityDelta: 0,
            averageComplexityDelta: 0,
            commonEventTypes: [:],
            sampleCount: 0
        )

        prefs.sampleCount += 1

        switch interaction.interactionType {
        case .accepted:
            // Update acceptance rate
            let oldTotal = Float(prefs.sampleCount - 1)
            let newRate = (prefs.acceptanceRate * oldTotal + 1.0) / Float(prefs.sampleCount)
            prefs.acceptanceRate = newRate

        case .rejected:
            let oldTotal = Float(prefs.sampleCount - 1)
            let newRate = (prefs.acceptanceRate * oldTotal) / Float(prefs.sampleCount)
            prefs.acceptanceRate = newRate

        case .intensityAdjusted:
            if let newIntensity = interaction.outcome.finalIntensity {
                let delta = newIntensity - interaction.context.intensity
                prefs.averageIntensityDelta = updateRunningAverage(
                    current: prefs.averageIntensityDelta,
                    new: delta,
                    count: prefs.sampleCount
                )
            }

        case .complexityAdjusted:
            if let newComplexity = interaction.outcome.finalComplexity {
                let delta = newComplexity - interaction.context.complexity
                prefs.averageComplexityDelta = updateRunningAverage(
                    current: prefs.averageComplexityDelta,
                    new: delta,
                    count: prefs.sampleCount
                )
            }

        default:
            break
        }

        // Track event type associations
        if let eventType = interaction.context.eventType {
            prefs.commonEventTypes[eventType, default: 0] += 1
        }

        vibePreferences[vibeId] = prefs
    }

    private func recomputePreferences() async {
        // Recompute all preferences from history
        // This ensures consistency and handles edge cases

        var newPrefs: [VibeProfileId: LearnedVibePreferences] = [:]

        // Group by vibe
        let grouped = Dictionary(grouping: interactionHistory) { $0.context.vibeProfileId }

        for (vibeId, interactions) in grouped {
            let acceptances = interactions.filter { $0.interactionType == .accepted }.count
            let rejections = interactions.filter { $0.interactionType == .rejected }.count
            let total = acceptances + rejections

            let acceptanceRate: Float = total > 0 ? Float(acceptances) / Float(total) : 0.5

            // Compute intensity deltas
            let intensityDeltas = interactions
                .filter { $0.interactionType == .intensityAdjusted }
                .compactMap { interaction -> Float? in
                    guard let newIntensity = interaction.outcome.finalIntensity else { return nil }
                    return newIntensity - interaction.context.intensity
                }
            let avgIntensityDelta = intensityDeltas.isEmpty ? 0 : intensityDeltas.reduce(0, +) / Float(intensityDeltas.count)

            // Compute complexity deltas
            let complexityDeltas = interactions
                .filter { $0.interactionType == .complexityAdjusted }
                .compactMap { interaction -> Float? in
                    guard let newComplexity = interaction.outcome.finalComplexity else { return nil }
                    return newComplexity - interaction.context.complexity
                }
            let avgComplexityDelta = complexityDeltas.isEmpty ? 0 : complexityDeltas.reduce(0, +) / Float(complexityDeltas.count)

            // Count event types
            var eventTypeCounts: [EventType: Int] = [:]
            for interaction in interactions {
                if let eventType = interaction.context.eventType {
                    eventTypeCounts[eventType, default: 0] += 1
                }
            }

            newPrefs[vibeId] = LearnedVibePreferences(
                vibeProfileId: vibeId,
                acceptanceRate: acceptanceRate,
                averageIntensityDelta: avgIntensityDelta,
                averageComplexityDelta: avgComplexityDelta,
                commonEventTypes: eventTypeCounts,
                sampleCount: interactions.count
            )
        }

        vibePreferences = newPrefs
    }

    private func updateRunningAverage(current: Float, new: Float, count: Int) -> Float {
        let oldTotal = Float(count - 1)
        return (current * oldTotal + new) / Float(count)
    }

    // MARK: - Queries

    /// Get learned preferences for a vibe profile.
    public func preferences(for vibeId: VibeProfileId) async -> LearnedVibePreferences? {
        vibePreferences[vibeId]
    }

    /// Get recommended vibe profiles for an event type.
    public func recommendedVibes(for eventType: EventType, limit: Int = 5) async -> [VibeProfileId] {
        // Score vibes by their association with this event type and acceptance rate
        var scores: [(VibeProfileId, Float)] = []

        for (vibeId, prefs) in vibePreferences {
            let eventScore = Float(prefs.commonEventTypes[eventType] ?? 0) / Float(max(prefs.sampleCount, 1))
            let acceptanceScore = prefs.acceptanceRate
            let combinedScore = eventScore * 0.4 + acceptanceScore * 0.6
            scores.append((vibeId, combinedScore))
        }

        return scores
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    /// Get adjusted parameters based on learned preferences.
    public func adjustedParameters(
        vibeId: VibeProfileId,
        baseIntensity: Float,
        baseComplexity: Float
    ) async -> (intensity: Float, complexity: Float) {
        guard let prefs = vibePreferences[vibeId] else {
            return (baseIntensity, baseComplexity)
        }

        let adjustedIntensity = max(0, min(1, baseIntensity + prefs.averageIntensityDelta))
        let adjustedComplexity = max(0, min(1, baseComplexity + prefs.averageComplexityDelta))

        return (adjustedIntensity, adjustedComplexity)
    }

    /// Export learned preferences for persistence.
    public func exportPreferences() async -> [LearnedVibePreferences] {
        Array(vibePreferences.values)
    }

    /// Import previously learned preferences.
    public func importPreferences(_ preferences: [LearnedVibePreferences]) async {
        for pref in preferences {
            vibePreferences[pref.vibeProfileId] = pref
        }
    }
}

// MARK: - Integration with Anigma Learning

/// Bridges Polytropos music learning with Anigma's broader learning infrastructure.
public struct MusicLearningBridge {

    /// Create a music learning observer that integrates with Anigma.
    public static func createObserver(
        learningService: Any,  // Would be AnigmaLearningService
        tenantId: String
    ) -> MusicLearningObserver {
        MusicLearningObserver(maxBufferSize: 100) { interactions in
            // Convert to Anigma learning format and submit
            // This would integrate with the institutional learning system

            // For now, just log
            await PlatformLogger.shared.debug(
                "Flushing \(interactions.count) music interactions for learning",
                category: "MusicLearning"
            )
        }
    }

    /// Create a trainer that can be used for offline learning.
    public static func createTrainer() -> MusicLearningTrainer {
        MusicLearningTrainer()
    }
}
