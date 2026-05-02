//
//  BoundedMemoryBenchmark.swift
//  AnigmaCore
//
//  Benchmarking suite for verifying bounded resident memory under sustained workloads.
//  Measures RSS, hot ECS footprint, and payload bytes across document ingestion, retrieval,
//  agent trace, and projection rebuild scenarios.
//

import Foundation
import os.log

/// Memory snapshot at a specific timestamp.
public struct MemorySnapshot: Codable, Sendable {
    /// Timestamp of measurement.
    public let timestamp: Date

    /// Resident set size in bytes (via mach_task_info or equivalent).
    public let residentSetBytes: Int

    /// Hot ECS footprint in bytes (tracked components).
    public let hotEcsBytes: Int

    /// Payload storage footprint in bytes.
    public let payloadBytes: Int

    /// Total memory budget utilization (percentage).
    public let budgetUtilizationPercent: Int

    /// Number of loaded payloads.
    public let loadedPayloadCount: Int

    /// Number of evicted payloads.
    public let evictedPayloadCount: Int

    public init(
        timestamp: Date,
        residentSetBytes: Int,
        hotEcsBytes: Int,
        payloadBytes: Int,
        budgetUtilizationPercent: Int,
        loadedPayloadCount: Int,
        evictedPayloadCount: Int
    ) {
        self.timestamp = timestamp
        self.residentSetBytes = residentSetBytes
        self.hotEcsBytes = hotEcsBytes
        self.payloadBytes = payloadBytes
        self.budgetUtilizationPercent = budgetUtilizationPercent
        self.loadedPayloadCount = loadedPayloadCount
        self.evictedPayloadCount = evictedPayloadCount
    }
}

/// Results of a single benchmark run.
public struct BenchmarkRunResult: Codable, Sendable {
    /// Name of the benchmark (e.g., "ingestion_10k_docs").
    public let name: String

    /// Workload description.
    public let workloadDescription: String

    /// Duration of the benchmark in seconds.
    public let durationSeconds: Double

    /// Memory snapshots taken during the run.
    public let snapshots: [MemorySnapshot]

    /// Peak RSS observed (bytes).
    public var peakRssBytes: Int {
        snapshots.map { $0.residentSetBytes }.max() ?? 0
    }

    /// Minimum RSS observed (bytes).
    public var minRssBytes: Int {
        snapshots.map { $0.residentSetBytes }.min() ?? 0
    }

    /// Growth in RSS from start to end (bytes).
    public var rssGrowthBytes: Int {
        guard let first = snapshots.first, let last = snapshots.last else { return 0 }
        return last.residentSetBytes - first.residentSetBytes
    }

    /// Average hot ECS footprint (bytes).
    public var avgHotEcsBytes: Int {
        guard !snapshots.isEmpty else { return 0 }
        let sum = snapshots.map { $0.hotEcsBytes }.reduce(0, +)
        return sum / snapshots.count
    }

    /// Peak hot ECS footprint (bytes).
    public var peakHotEcsBytes: Int {
        snapshots.map { $0.hotEcsBytes }.max() ?? 0
    }

    /// Peak payload footprint (bytes).
    public var peakPayloadBytes: Int {
        snapshots.map { $0.payloadBytes }.max() ?? 0
    }

    /// Payload eviction count.
    public var totalEvictionsCount: Int {
        snapshots.last?.evictedPayloadCount ?? 0
    }

    public init(
        name: String,
        workloadDescription: String,
        durationSeconds: Double,
        snapshots: [MemorySnapshot]
    ) {
        self.name = name
        self.workloadDescription = workloadDescription
        self.durationSeconds = durationSeconds
        self.snapshots = snapshots
    }
}

/// Benchmark report summarizing multiple runs.
public struct BenchmarkReport: Codable, Sendable {
    /// Report title.
    public let title: String

    /// Timestamp of report generation.
    public let generatedAt: Date

    /// Individual benchmark results.
    public let results: [BenchmarkRunResult]

    /// Analysis summary (e.g., "All runs stayed within budget").
    public let summary: String

    public init(
        title: String,
        generatedAt: Date = Date(),
        results: [BenchmarkRunResult],
        summary: String
    ) {
        self.title = title
        self.generatedAt = generatedAt
        self.results = results
        self.summary = summary
    }

    /// Export report as CSV for analysis.
    public func exportAsCSV() -> String {
        var csv = "Benchmark,RSS Peak (MB),RSS Growth (MB),Hot ECS Peak (MB),Payload Peak (MB),Duration (s),Evictions\n"

        for result in results {
            let rsspeak = Double(result.peakRssBytes) / (1024 * 1024)
            let rssgrowth = Double(result.rssGrowthBytes) / (1024 * 1024)
            let ecspeak = Double(result.peakHotEcsBytes) / (1024 * 1024)
            let payloadpeak = Double(result.peakPayloadBytes) / (1024 * 1024)
            let evictions = result.totalEvictionsCount

            csv += "\(result.name),\(String(format: "%.2f", rsspeak)),\(String(format: "%.2f", rssgrowth)),\(String(format: "%.2f", ecspeak)),\(String(format: "%.2f", payloadpeak)),\(String(format: "%.1f", result.durationSeconds)),\(evictions)\n"
        }

        return csv
    }
}

/// Benchmark harness for measuring bounded memory.
public final class BoundedMemoryBenchmarkHarness: Sendable {
    private let log = Logger(subsystem: "com.anigma.core", category: "memory-benchmark")

    /// Interval between memory snapshots (seconds).
    private let snapshotIntervalSeconds: TimeInterval = 0.1

    /// Maximum duration for a single benchmark (seconds).
    private let maxDurationSeconds: TimeInterval = 600 // 10 minutes

    public init() {}

    /// Run a benchmark with periodic memory snapshots.
    public func runBenchmark(
        name: String,
        workloadDescription: String,
        workload: () async throws -> Void
    ) async throws -> BenchmarkRunResult {
        let startTime = Date()
        var snapshots: [MemorySnapshot] = []

        // Start background snapshot collection
        let snapshotTask = Task {
            while !Task.isCancelled {
                let snapshot = captureMemorySnapshot()
                snapshots.append(snapshot)
                try? await Task.sleep(nanoseconds: UInt64(snapshotIntervalSeconds * 1_000_000_000))
            }
        }

        defer {
            snapshotTask.cancel()
        }

        try await workload()

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        let result = BenchmarkRunResult(
            name: name,
            workloadDescription: workloadDescription,
            durationSeconds: duration,
            snapshots: snapshots
        )

        log.info("Benchmark '\(name)' complete: RSS peak=\(result.peakRssBytes)B, growth=\(result.rssGrowthBytes)B, duration=\(duration)s")

        return result
    }

    /// Simulate document ingestion workload.
    public func ingestDocumentsWorkload(documentCount: Int) async throws -> Void {
        for i in 0..<documentCount {
            // Simulate document ingestion: load, process, store reference
            let docData = Data(repeating: 0x42, count: 1024 * 64) // 64 KB per doc
            _ = docData // Use to prevent optimization

            // Record access pattern
            recordPayloadAccess(
                hotPathName: "ingestion",
                accessType: "reference",
                payloadId: "doc-\(i)",
                sizeBytes: 64 * 1024
            )

            // Yield to allow snapshot collection
            try? await Task.sleep(nanoseconds: 1_000_000) // 1 ms
        }
    }

    /// Simulate retrieval workload.
    public func retrievalWorkload(queryCount: Int) async throws -> Void {
        for i in 0..<queryCount {
            // Simulate hybrid search: query, retrieve snippets, build results
            _ = Data(repeating: 0x43, count: 1024 * 32) // 32 KB per result set

            recordPayloadAccess(
                hotPathName: "retrieval",
                accessType: "reference",
                payloadId: "query-\(i)",
                sizeBytes: 32 * 1024
            )

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    /// Simulate agent context trace workload.
    public func agentTraceWorkload(stepCount: Int) async throws -> Void {
        for i in 0..<stepCount {
            // Simulate trace collection: record step, metadata, evidence
            _ = Data(repeating: 0x44, count: 1024 * 16) // 16 KB per step

            recordPayloadAccess(
                hotPathName: "agent-trace",
                accessType: "reference",
                payloadId: "step-\(i)",
                sizeBytes: 16 * 1024
            )

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    /// Simulate projection rebuild workload.
    public func projectionRebuildWorkload(projectionCount: Int) async throws -> Void {
        for i in 0..<projectionCount {
            // Simulate projection rebuild: materialize, compute, store
            _ = Data(repeating: 0x45, count: 1024 * 48) // 48 KB per projection

            recordPayloadAccess(
                hotPathName: "projection",
                accessType: "reference",
                payloadId: "proj-\(i)",
                sizeBytes: 48 * 1024
            )

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    /// Capture a memory snapshot.
    private func captureMemorySnapshot() -> MemorySnapshot {
        let residentSetBytes = currentResidentMemoryBytes()
        let hotEcsBytes = MemoryBudgetTelemetryCollector.shared.getPeakUtilization() * 1024 // Mock: use peak utilization
        let payloadBytes = 0 // Will be tracked by residency system
        let budgetUtilizationPercent = min(100, (hotEcsBytes + payloadBytes) / (256 * 1024 * 1024) * 100) // Assume 256 MB budget
        let loadedPayloadCount = 0 // Will be tracked
        let evictedPayloadCount = 0 // Will be tracked

        return MemorySnapshot(
            timestamp: Date(),
            residentSetBytes: residentSetBytes,
            hotEcsBytes: hotEcsBytes,
            payloadBytes: payloadBytes,
            budgetUtilizationPercent: budgetUtilizationPercent,
            loadedPayloadCount: loadedPayloadCount,
            evictedPayloadCount: evictedPayloadCount
        )
    }

    /// Get current resident memory in bytes.
    private func currentResidentMemoryBytes() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { ptr in
            task_info(
                mach_task_self_,
                task_flavor_t(TASK_VM_INFO),
                UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: integer_t.self),
                &count
            )
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.resident_size)
    }
}

// Import mach headers for memory info
import Darwin
