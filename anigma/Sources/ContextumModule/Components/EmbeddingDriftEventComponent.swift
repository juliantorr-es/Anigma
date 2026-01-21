import Foundation

/// Embedding drift detection event.
/// Phase 5: Drift detection using immutable model identity and declared comparison sets.
public struct EmbeddingDriftEventComponent: Codable, Hashable, Sendable {
    public let driftID: UUID
    public let modelFromHash: String
    public let modelToHash: String
    public let corpusSnapshotHash: String
    public let querySetHash: String
    public let driftSpecHash: String
    public let detectedAt: Date
    public let metrics: DriftMetrics

    public struct DriftMetrics: Codable, Hashable, Sendable {
        public let samplesCompared: Int
        public let meanCosineDelta: Double
        public let maxCosineDelta: Double
        public let retrievalOverlapRatio: Double
        public let rankCorrelation: Double?

        public init(
            samplesCompared: Int,
            meanCosineDelta: Double,
            maxCosineDelta: Double,
            retrievalOverlapRatio: Double,
            rankCorrelation: Double? = nil
        ) {
            self.samplesCompared = samplesCompared
            self.meanCosineDelta = meanCosineDelta
            self.maxCosineDelta = maxCosineDelta
            self.retrievalOverlapRatio = retrievalOverlapRatio
            self.rankCorrelation = rankCorrelation
        }
    }

    public init(
        driftID: UUID = UUID(),
        modelFromHash: String,
        modelToHash: String,
        corpusSnapshotHash: String,
        querySetHash: String,
        driftSpecHash: String,
        detectedAt: Date = Date(),
        metrics: DriftMetrics
    ) {
        self.driftID = driftID
        self.modelFromHash = modelFromHash
        self.modelToHash = modelToHash
        self.corpusSnapshotHash = corpusSnapshotHash
        self.querySetHash = querySetHash
        self.driftSpecHash = driftSpecHash
        self.detectedAt = detectedAt
        self.metrics = metrics
    }
}
