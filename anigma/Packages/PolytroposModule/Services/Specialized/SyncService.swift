//
//  SyncService.swift
//  PolytroposModule
//
//  Handles audio-based multicam synchronization.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Sync Service

/// Specialized service for audio-based multicam synchronization.
public actor SyncService {

    private let world: World

    /// Configuration for sync behavior.
    public struct Configuration: Sendable {
        /// Sample rate for cross-correlation (samples per second).
        public var correlationSampleRate: Int

        /// Maximum offset to search (seconds).
        public var maxSearchOffset: TimeInterval

        /// Minimum confidence to accept automatic sync.
        public var minimumConfidence: Double

        /// Whether to use GPU acceleration when available.
        public var useGPU: Bool

        public static let `default` = Configuration(
            correlationSampleRate: 8000,
            maxSearchOffset: 60.0,
            minimumConfidence: 0.7,
            useGPU: true
        )

        public init(
            correlationSampleRate: Int,
            maxSearchOffset: TimeInterval,
            minimumConfidence: Double,
            useGPU: Bool
        ) {
            self.correlationSampleRate = correlationSampleRate
            self.maxSearchOffset = maxSearchOffset
            self.minimumConfidence = minimumConfidence
            self.useGPU = useGPU
        }
    }

    private let configuration: Configuration

    public init(world: World, configuration: Configuration = .default) {
        self.world = world
        self.configuration = configuration
    }

    // MARK: - Sync Operations

    /// Syncs a cluster using audio cross-correlation.
    public func syncCluster(_ clusterId: EntityId) async throws -> SyncResult {
        guard var cluster = await world.getComponent(clusterId, MulticamClusterComponent.self) else {
            throw SyncError.clusterNotFound(clusterId)
        }

        guard cluster.assetIds.count >= 2 else {
            throw SyncError.insufficientAssets(cluster.assetIds.count)
        }

        // Select reference asset (prefer dedicated audio recorder or highest quality audio)
        let referenceId = try await selectReferenceAsset(from: cluster.assetIds)

        guard let referenceWaveform = await world.getComponent(referenceId, WaveformComponent.self) else {
            throw SyncError.missingWaveform(referenceId)
        }

        // Update cluster status
        cluster.status = .syncing
        cluster.referenceAssetId = referenceId
        await world.addComponent(clusterId, cluster)

        // Sync each asset to reference
        var syncResults: [EntityId: AssetSyncResult] = [:]

        for assetId in cluster.assetIds {
            if assetId == referenceId {
                // Reference asset has zero offset
                let syncData = SyncDataComponent(
                    clusterId: cluster.id,
                    offsetFromReference: 0,
                    confidence: 1.0,
                    syncMethod: .audio,
                    isReference: true
                )
                await world.addComponent(assetId, syncData)
                syncResults[assetId] = AssetSyncResult(
                    assetId: assetId,
                    offset: 0,
                    confidence: 1.0,
                    method: .audio,
                    isReference: true
                )
                continue
            }

            guard let assetWaveform = await world.getComponent(assetId, WaveformComponent.self) else {
                syncResults[assetId] = AssetSyncResult(
                    assetId: assetId,
                    offset: 0,
                    confidence: 0,
                    method: .audio,
                    isReference: false,
                    error: "Missing waveform"
                )
                continue
            }

            // Compute cross-correlation
            let (offset, confidence) = computeCrossCorrelation(
                reference: referenceWaveform,
                target: assetWaveform
            )

            let syncData = SyncDataComponent(
                clusterId: cluster.id,
                offsetFromReference: offset,
                confidence: confidence,
                syncMethod: .audio,
                isReference: false
            )
            await world.addComponent(assetId, syncData)

            syncResults[assetId] = AssetSyncResult(
                assetId: assetId,
                offset: offset,
                confidence: confidence,
                method: .audio,
                isReference: false
            )
        }

        // Update cluster with sync results
        let allConfident = syncResults.values.allSatisfy {
            $0.confidence >= configuration.minimumConfidence
        }

        cluster.status = allConfident ? .synced : .pending
        cluster.syncVerified = false
        await world.addComponent(clusterId, cluster)

        // Compute cluster time bounds
        await updateClusterTimeBounds(clusterId)

        return SyncResult(
            clusterId: clusterId,
            referenceAssetId: referenceId,
            assetResults: syncResults,
            success: allConfident,
            requiresManualReview: !allConfident
        )
    }

    /// Applies manual sync markers to refine sync.
    public func applyManualSync(
        clusterId: EntityId,
        assetId: EntityId,
        offset: TimeInterval
    ) async throws {
        guard var syncData = await world.getComponent(assetId, SyncDataComponent.self) else {
            throw SyncError.assetNotSynced(assetId)
        }

        syncData.manualAdjustment = offset - syncData.offsetFromReference
        syncData.syncMethod = .manual
        syncData.confidence = 1.0
        await world.addComponent(assetId, syncData)

        // Mark cluster as needing time bounds update
        await updateClusterTimeBounds(clusterId)
    }

    /// Verifies sync for a cluster (marks as user-reviewed).
    public func verifySync(_ clusterId: EntityId) async throws {
        guard var cluster = await world.getComponent(clusterId, MulticamClusterComponent.self) else {
            throw SyncError.clusterNotFound(clusterId)
        }

        cluster.syncVerified = true
        cluster.status = .synced
        await world.addComponent(clusterId, cluster)
    }

    // MARK: - Private Helpers

    private func selectReferenceAsset(from assetIds: [EntityId]) async throws -> EntityId {
        var bestAsset: EntityId?
        var bestScore: Double = 0

        for assetId in assetIds {
            guard let asset = await world.getComponent(assetId, MediaAssetComponent.self) else {
                continue
            }

            var score: Double = 0

            // Prefer dedicated audio recorders
            if asset.mediaType == .audio {
                score += 100
            }

            // Prefer devices labeled as audio recorders
            if let label = asset.deviceLabel?.lowercased(),
               label.contains("zoom") || label.contains("tascam") || label.contains("recorder") {
                score += 50
            }

            // Consider audio quality if available
            if let audioMeta = await world.getComponent(assetId, AudioMetadataComponent.self) {
                // Higher sample rate is better
                score += audioMeta.sampleRate / 10000
                // More channels might be better
                score += Double(audioMeta.channelCount)
            }

            if score > bestScore {
                bestScore = score
                bestAsset = assetId
            }
        }

        guard let reference = bestAsset ?? assetIds.first else {
            throw SyncError.noValidAssets
        }

        return reference
    }

    private func computeCrossCorrelation(
        reference: WaveformComponent,
        target: WaveformComponent
    ) -> (offset: TimeInterval, confidence: Double) {
        let refSamples = reference.rmsValues ?? reference.samples
        let targetSamples = target.rmsValues ?? target.samples

        guard !refSamples.isEmpty, !targetSamples.isEmpty else {
            return (0, 0)
        }

        let sampleRate = min(reference.samplesPerSecond, target.samplesPerSecond)
        guard sampleRate > 0 else {
            return (0, 0)
        }

        let minCount = min(refSamples.count, targetSamples.count)
        let maxLag = min(Int(Double(sampleRate) * 5.0), minCount / 2)
        let step = max(1, minCount / 1000)

        var bestLag = 0
        var bestScore = -Double.infinity

        for lag in stride(from: -maxLag, through: maxLag, by: step) {
            let score = normalizedCorrelation(
                refSamples: refSamples,
                targetSamples: targetSamples,
                lag: lag,
                step: step
            )
            if score > bestScore {
                bestScore = score
                bestLag = lag
            }
        }

        let offset = TimeInterval(Double(bestLag) / Double(sampleRate))
        let confidence = max(0, min(1, (bestScore + 1.0) / 2.0))
        return (offset, confidence)
    }

    private func normalizedCorrelation(
        refSamples: [Float],
        targetSamples: [Float],
        lag: Int,
        step: Int
    ) -> Double {
        let startRef = max(0, lag)
        let startTarget = max(0, -lag)
        let length = min(refSamples.count - startRef, targetSamples.count - startTarget)
        guard length > 0 else { return 0 }

        var sumRef = 0.0
        var sumTarget = 0.0
        var sumRefSq = 0.0
        var sumTargetSq = 0.0
        var sumProd = 0.0
        var count = 0.0

        for i in stride(from: 0, to: length, by: step) {
            let r = Double(refSamples[startRef + i])
            let t = Double(targetSamples[startTarget + i])
            sumRef += r
            sumTarget += t
            sumRefSq += r * r
            sumTargetSq += t * t
            sumProd += r * t
            count += 1
        }

        guard count > 0 else { return 0 }
        let meanRef = sumRef / count
        let meanTarget = sumTarget / count
        let numerator = sumProd - count * meanRef * meanTarget
        let denomLeft = sumRefSq - count * meanRef * meanRef
        let denomRight = sumTargetSq - count * meanTarget * meanTarget
        let denominator = sqrt(max(denomLeft * denomRight, 0.0))
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    private func updateClusterTimeBounds(_ clusterId: EntityId) async {
        guard var cluster = await world.getComponent(clusterId, MulticamClusterComponent.self) else {
            return
        }

        var earliestStart: TimeInterval = .infinity
        var latestEnd: TimeInterval = 0

        for assetId in cluster.assetIds {
            guard let temporal = await world.getComponent(assetId, TemporalMetadataComponent.self),
                  let sync = await world.getComponent(assetId, SyncDataComponent.self) else {
                continue
            }

            let effectiveStart = sync.effectiveOffset
            let effectiveEnd = sync.effectiveOffset + temporal.duration

            earliestStart = min(earliestStart, effectiveStart)
            latestEnd = max(latestEnd, effectiveEnd)
        }

        if earliestStart != .infinity {
            // Normalize to start at 0
            cluster.clusterStartTime = 0
            cluster.clusterEndTime = latestEnd - earliestStart

            await world.addComponent(clusterId, cluster)
        }
    }
}

// MARK: - Types

/// Result of syncing a cluster.
public struct SyncResult: Sendable {
    public let clusterId: EntityId
    public let referenceAssetId: EntityId
    public let assetResults: [EntityId: AssetSyncResult]
    public let success: Bool
    public let requiresManualReview: Bool
}

/// Result of syncing a single asset.
public struct AssetSyncResult: Sendable {
    public let assetId: EntityId
    public let offset: TimeInterval
    public let confidence: Double
    public let method: SyncMethod
    public let isReference: Bool
    public var error: String?

    public init(
        assetId: EntityId,
        offset: TimeInterval,
        confidence: Double,
        method: SyncMethod,
        isReference: Bool,
        error: String? = nil
    ) {
        self.assetId = assetId
        self.offset = offset
        self.confidence = confidence
        self.method = method
        self.isReference = isReference
        self.error = error
    }
}

/// Errors from sync operations.
public enum SyncError: Error, LocalizedError {
    case clusterNotFound(EntityId)
    case insufficientAssets(Int)
    case missingWaveform(EntityId)
    case assetNotSynced(EntityId)
    case noValidAssets
    case correlationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .clusterNotFound(let id):
            return "Cluster not found: \(id)"
        case .insufficientAssets(let count):
            return "Need at least 2 assets to sync, got \(count)"
        case .missingWaveform(let id):
            return "Missing waveform for asset: \(id)"
        case .assetNotSynced(let id):
            return "Asset not synced: \(id)"
        case .noValidAssets:
            return "No valid assets found in cluster"
        case .correlationFailed(let reason):
            return "Cross-correlation failed: \(reason)"
        }
    }
}
