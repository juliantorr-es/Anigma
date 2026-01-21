//
//  GCReport.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import Foundation

/// Report from garbage collection operation.
public struct GCReport: Sendable, Codable {
    public let startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval?
    public let policyHash: String
    public let dryRun: Bool
    public var sessionCleanup: SessionCleanupReport?
    public var artifactCleanup: ArtifactCleanupReport?
    public var masterLedgerCleanup: MasterLedgerCleanupReport?

    public init(
        startTime: Date,
        policyHash: String,
        dryRun: Bool
    ) {
        self.startTime = startTime
        self.policyHash = policyHash
        self.dryRun = dryRun
    }
}

/// Session database cleanup statistics.
public struct SessionCleanupReport: Sendable, Codable {
    public let sessionsScanned: Int
    public let sessionsDeleted: Int
    public let bytesFreed: Int64
    public let cutoffDate: Date

    public init(
        sessionsScanned: Int,
        sessionsDeleted: Int,
        bytesFreed: Int64,
        cutoffDate: Date
    ) {
        self.sessionsScanned = sessionsScanned
        self.sessionsDeleted = sessionsDeleted
        self.bytesFreed = bytesFreed
        self.cutoffDate = cutoffDate
    }
}

/// Content-addressed artifact cleanup statistics.
public struct ArtifactCleanupReport: Sendable, Codable {
    public let artifactsScanned: Int
    public let artifactsDeleted: Int
    public let bytesFreed: Int64
    public let deduplicationStats: DeduplicationStats?
    public let deletedHashes: [String]

    public init(
        artifactsScanned: Int,
        artifactsDeleted: Int,
        bytesFreed: Int64,
        deduplicationStats: DeduplicationStats? = nil,
        deletedHashes: [String] = []
    ) {
        self.artifactsScanned = artifactsScanned
        self.artifactsDeleted = artifactsDeleted
        self.bytesFreed = bytesFreed
        self.deduplicationStats = deduplicationStats
        self.deletedHashes = deletedHashes
    }
}

/// Master ledger cleanup statistics (segmentation).
public struct MasterLedgerCleanupReport: Sendable, Codable {
    public let segmentsScanned: Int
    public let segmentsRotated: Int
    public let bytesFreed: Int64
    public let retentionEventsRecorded: Int

    public init(
        segmentsScanned: Int,
        segmentsRotated: Int,
        bytesFreed: Int64,
        retentionEventsRecorded: Int
    ) {
        self.segmentsScanned = segmentsScanned
        self.segmentsRotated = segmentsRotated
        self.bytesFreed = bytesFreed
        self.retentionEventsRecorded = retentionEventsRecorded
    }
}

/// Deduplication statistics for content-addressed storage.
public struct DeduplicationStats: Sendable, Codable {
    public let totalArtifacts: Int
    public let totalReferences: Int
    public let averageReferences: Double
    public let spaceSavings: Int64

    public init(
        totalArtifacts: Int,
        totalReferences: Int,
        averageReferences: Double,
        spaceSavings: Int64
    ) {
        self.totalArtifacts = totalArtifacts
        self.totalReferences = totalReferences
        self.averageReferences = averageReferences
        self.spaceSavings = spaceSavings
    }
}

/// GC policy configuration.
public struct GCConfiguration: Sendable, Codable {
    public let maxDeletePerRun: Int
    public let minAgeHours: Int
    public let vacuumThresholdMb: Int
    public let checkpointWalMb: Int
    public let requirePolicyHashMatch: Bool

    public init(
        maxDeletePerRun: Int = 500,
        minAgeHours: Int = 24,
        vacuumThresholdMb: Int = 100,
        checkpointWalMb: Int = 10,
        requirePolicyHashMatch: Bool = true
    ) {
        self.maxDeletePerRun = maxDeletePerRun
        self.minAgeHours = minAgeHours
        self.vacuumThresholdMb = vacuumThresholdMb
        self.checkpointWalMb = checkpointWalMb
        self.requirePolicyHashMatch = requirePolicyHashMatch
    }
}

/// Update the GC report with completion details.
extension GCReport {
    mutating func complete() {
        endTime = Date()
        duration = endTime?.timeIntervalSince(startTime)
    }

    mutating func setSessionCleanup(_ report: SessionCleanupReport) {
        sessionCleanup = report
    }

    mutating func setArtifactCleanup(_ report: ArtifactCleanupReport) {
        artifactCleanup = report
    }

    mutating func setMasterLedgerCleanup(_ report: MasterLedgerCleanupReport) {
        masterLedgerCleanup = report
    }
}
