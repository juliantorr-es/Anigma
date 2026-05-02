//
//  MemoryBudgetTelemetry.swift
//  AnigmaCore
//
//  Telemetry and monitoring for memory budget consumption and pressure states.
//  Records snapshots and pressure transitions without requiring actor management.
//

import Foundation
import os.log

/// Snapshot of memory budget metrics at a specific time.
public struct MemoryBudgetSnapshot: Codable, Sendable {
    /// Timestamp of this snapshot.
    public let timestamp: Date

    /// Category of budget (e.g., "hotEcs", "retrieval", "agentContext").
    public let category: String

    /// Bytes currently used.
    public let bytesUsed: Int

    /// Total budget in bytes.
    public let budgetBytes: Int

    /// Percentage utilization (0-100).
    public var utilizationPercent: Int {
        budgetBytes > 0 ? (bytesUsed * 100) / budgetBytes : 0
    }

    /// Whether this snapshot represents soft pressure (80-95%).
    public var isSoftPressure: Bool {
        let pct = utilizationPercent
        return pct >= 80 && pct < 95
    }

    /// Whether this snapshot represents hard pressure (95-100%).
    public var isHardPressure: Bool {
        let pct = utilizationPercent
        return pct >= 95
    }

    /// Whether this snapshot represents critical pressure (>=100%).
    public var isCriticalPressure: Bool {
        utilizationPercent >= 100
    }

    public init(timestamp: Date, category: String, bytesUsed: Int, budgetBytes: Int) {
        self.timestamp = timestamp
        self.category = category
        self.bytesUsed = bytesUsed
        self.budgetBytes = budgetBytes
    }
}

/// Event published when memory pressure transitions.
public struct MemoryPressureTransitionEvent: Codable, Sendable {
    /// Time of the transition.
    public let timestamp: Date

    /// Category affected (e.g., "hotEcs", "refinement", etc.).
    public let category: String

    /// Previous pressure state.
    public let fromPressure: MemoryPressure

    /// New pressure state.
    public let toPressure: MemoryPressure

    /// Bytes used at transition time.
    public let bytesUsed: Int

    /// Budget at transition time.
    public let budgetBytes: Int

    /// Named budget owner (e.g., "refinement-pass-v1").
    public let budgetOwner: String

    public init(
        timestamp: Date,
        category: String,
        fromPressure: MemoryPressure,
        toPressure: MemoryPressure,
        bytesUsed: Int,
        budgetBytes: Int,
        budgetOwner: String
    ) {
        self.timestamp = timestamp
        self.category = category
        self.fromPressure = fromPressure
        self.toPressure = toPressure
        self.bytesUsed = bytesUsed
        self.budgetBytes = budgetBytes
        self.budgetOwner = budgetOwner
    }
}

/// Global telemetry collector for memory budget metrics.
/// Thread-safe registry for recording snapshots and transitions.
public final class MemoryBudgetTelemetryCollector {
    private let log = Logger(subsystem: "com.anigma.core", category: "memory-telemetry")

    /// Shared global instance.
    public static let shared = MemoryBudgetTelemetryCollector()

    private let lock = NSLock()

    /// Recent snapshots per budget owner (ring buffer, max 1000 per owner).
    private var snapshotsByOwner: [String: [MemoryBudgetSnapshot]] = [:]

    /// Pressure transition events (ring buffer, max 500).
    private var transitionEvents: [MemoryPressureTransitionEvent] = []

    /// Peak utilization percentage seen.
    private var peakUtilizationPercent: Int = 0

    private init() {}

    /// Record a memory budget snapshot.
    public func recordSnapshot(_ snapshot: MemoryBudgetSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        var snapshots = snapshotsByOwner[snapshot.category] ?? []
        snapshots.append(snapshot)

        // Keep only last 1000 snapshots per category
        if snapshots.count > 1000 {
            snapshots.removeFirst(snapshots.count - 1000)
        }

        snapshotsByOwner[snapshot.category] = snapshots

        // Update peak utilization
        peakUtilizationPercent = max(peakUtilizationPercent, snapshot.utilizationPercent)
    }

    /// Record a pressure transition event.
    public func recordTransition(_ event: MemoryPressureTransitionEvent) {
        lock.lock()
        defer { lock.unlock() }

        transitionEvents.append(event)

        // Keep only last 500 events
        if transitionEvents.count > 500 {
            transitionEvents.removeFirst(transitionEvents.count - 500)
        }

        log.info("MemoryBudgetTelemetry: Pressure transition for \(event.budgetOwner): \(event.fromPressure.rawValue) → \(event.toPressure.rawValue)")
    }

    /// Get recent snapshots for a budget owner.
    public func getSnapshots(for owner: String) -> [MemoryBudgetSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return snapshotsByOwner[owner] ?? []
    }

    /// Get all transition events.
    public func getTransitionEvents() -> [MemoryPressureTransitionEvent] {
        lock.lock()
        defer { lock.unlock() }
        return transitionEvents
    }

    /// Get peak utilization percent observed.
    public func getPeakUtilization() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return peakUtilizationPercent
    }

    /// Clear all collected metrics (useful for testing).
    public func clearMetrics() {
        lock.lock()
        defer { lock.unlock() }
        snapshotsByOwner.removeAll()
        transitionEvents.removeAll()
        peakUtilizationPercent = 0
    }
}

/// Helper function to record a memory budget snapshot.
public func recordMemoryBudgetSnapshot(
    category: String,
    bytesUsed: Int,
    budgetBytes: Int
) {
    let snapshot = MemoryBudgetSnapshot(
        timestamp: Date(),
        category: category,
        bytesUsed: bytesUsed,
        budgetBytes: budgetBytes
    )
    MemoryBudgetTelemetryCollector.shared.recordSnapshot(snapshot)
}

/// Helper function to record a pressure transition.
public func recordMemoryPressureTransition(
    category: String,
    fromPressure: MemoryPressure,
    toPressure: MemoryPressure,
    bytesUsed: Int,
    budgetBytes: Int,
    budgetOwner: String
) {
    let event = MemoryPressureTransitionEvent(
        timestamp: Date(),
        category: category,
        fromPressure: fromPressure,
        toPressure: toPressure,
        bytesUsed: bytesUsed,
        budgetBytes: budgetBytes,
        budgetOwner: budgetOwner
    )
    MemoryBudgetTelemetryCollector.shared.recordTransition(event)
}
