import Foundation

public struct AnalyticsRollupComponent: Codable, Hashable, Sendable {
    public let windowStart: Date
    public let windowEnd: Date
    public let groupKeyHash: String
    public let rollupSpecHash: String
    public let eventRangeStart: Int64
    public let eventRangeEnd: Int64
    public let eventCount: Int
    public let reportArtifactHash: String
    public let receiptID: String

    // Phase 5: Additional fields for recommendations
    public let agentID: String?
    public let taxonomy: String?
    public let repoSizeBand: String?
    public let totalRuns: Int
    public let successfulRuns: Int
    public let latencyP95: Double
    public let failureCodes: [String: Int]?

    public init(
        windowStart: Date,
        windowEnd: Date,
        groupKeyHash: String,
        rollupSpecHash: String,
        eventRangeStart: Int64,
        eventRangeEnd: Int64,
        eventCount: Int,
        reportArtifactHash: String,
        receiptID: String,
        agentID: String? = nil,
        taxonomy: String? = nil,
        repoSizeBand: String? = nil,
        totalRuns: Int = 0,
        successfulRuns: Int = 0,
        latencyP95: Double = 0.0,
        failureCodes: [String: Int]? = nil
    ) {
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.groupKeyHash = groupKeyHash
        self.rollupSpecHash = rollupSpecHash
        self.eventRangeStart = eventRangeStart
        self.eventRangeEnd = eventRangeEnd
        self.eventCount = eventCount
        self.reportArtifactHash = reportArtifactHash
        self.receiptID = receiptID
        self.agentID = agentID
        self.taxonomy = taxonomy
        self.repoSizeBand = repoSizeBand
        self.totalRuns = totalRuns
        self.successfulRuns = successfulRuns
        self.latencyP95 = latencyP95
        self.failureCodes = failureCodes
    }
}

public struct AnomalyComponent: Codable, Hashable, Sendable {
    public let detectorID: String
    public let windowStart: Date
    public let windowEnd: Date
    public let groupKeyHash: String
    public let anomalySpecHash: String
    public let subjectKey: String
    public let severity: Severity
    public let evidenceRollupIDs: [String]
    public let reportArtifactHash: String
    public let receiptID: String

    public enum Severity: String, Codable, Sendable {
        case info
        case warning
        case critical
    }

    public init(
        detectorID: String,
        windowStart: Date,
        windowEnd: Date,
        groupKeyHash: String,
        anomalySpecHash: String,
        subjectKey: String,
        severity: Severity,
        evidenceRollupIDs: [String],
        reportArtifactHash: String,
        receiptID: String
    ) {
        self.detectorID = detectorID
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.groupKeyHash = groupKeyHash
        self.anomalySpecHash = anomalySpecHash
        self.subjectKey = subjectKey
        self.severity = severity
        self.evidenceRollupIDs = evidenceRollupIDs
        self.reportArtifactHash = reportArtifactHash
        self.receiptID = receiptID
    }
}

public struct AgentMetricsSnapshot: Codable {
    public let agentID: String
    public let taxonomy: String
    public let repoSizeBand: String
    public let latencyP50Ms: Double
    public let latencyP95Ms: Double
    public let latencyP99Ms: Double
    public let successCount: Int
    public let failureCount: Int
    public let failureCodeDistribution: [String: Int]

    public init(
        agentID: String,
        taxonomy: String,
        repoSizeBand: String,
        latencyP50Ms: Double,
        latencyP95Ms: Double,
        latencyP99Ms: Double,
        successCount: Int,
        failureCount: Int,
        failureCodeDistribution: [String: Int]
    ) {
        self.agentID = agentID
        self.taxonomy = taxonomy
        self.repoSizeBand = repoSizeBand
        self.latencyP50Ms = latencyP50Ms
        self.latencyP95Ms = latencyP95Ms
        self.latencyP99Ms = latencyP99Ms
        self.successCount = successCount
        self.failureCount = failureCount
        self.failureCodeDistribution = failureCodeDistribution
    }
}

public struct IndexHealthSnapshot: Codable {
    public let artifactCommitCount: Int
    public let chunkedArtifactCount: Int
    public let embeddedChunkCount: Int
    public let indexLagP50Seconds: Double
    public let indexLagP95Seconds: Double
    public let pendingIngestJobs: Int
    public let pendingEmbedJobs: Int

    public init(
        artifactCommitCount: Int,
        chunkedArtifactCount: Int,
        embeddedChunkCount: Int,
        indexLagP50Seconds: Double,
        indexLagP95Seconds: Double,
        pendingIngestJobs: Int,
        pendingEmbedJobs: Int
    ) {
        self.artifactCommitCount = artifactCommitCount
        self.chunkedArtifactCount = chunkedArtifactCount
        self.embeddedChunkCount = embeddedChunkCount
        self.indexLagP50Seconds = indexLagP50Seconds
        self.indexLagP95Seconds = indexLagP95Seconds
        self.pendingIngestJobs = pendingIngestJobs
        self.pendingEmbedJobs = pendingEmbedJobs
    }
}

public struct SearchQualitySnapshot: Codable {
    public let totalSearches: Int
    public let emptyResultCount: Int
    public let avgResultCount: Double
    public let chunkReferenceRate: Double

    public init(
        totalSearches: Int,
        emptyResultCount: Int,
        avgResultCount: Double,
        chunkReferenceRate: Double
    ) {
        self.totalSearches = totalSearches
        self.emptyResultCount = emptyResultCount
        self.avgResultCount = avgResultCount
        self.chunkReferenceRate = chunkReferenceRate
    }
}
