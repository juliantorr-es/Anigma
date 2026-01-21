//
//  TrustSchedulerBootstrapper.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Bootstraps trust recalculation scheduler based on governance mode.
//  Only starts in governed/paranoid modes, stays off in personal mode.
//

import Foundation
import SQLite3
import AnigmaCore
import HarmoniaModule

/// Bootstrapper for trust recalculation scheduler.
public actor TrustSchedulerBootstrapper {

    private var scheduler: TrustRecalcScheduler?
    private let dbPath: String

    public init(dbPath: String = "harmonia_harness.sqlite") {
        self.dbPath = dbPath
    }

    /// Start scheduler if governance mode requires it.
    /// Returns true if scheduler was started, false if not needed.
    public func startIfNeeded(currentMode: GovernanceMode) async -> Bool {
        let mode = currentMode

        switch mode {
        case .governed, .paranoid:
            logInfo("[TRUST] Starting scheduler for \(mode.rawValue) mode", category: "TrustSchedulerBootstrapper")
            await startScheduler()
            return true

        case .personal:
            logInfo("[TRUST] Skipping scheduler in personal mode", category: "TrustSchedulerBootstrapper")
            return false
        }
    }

    /// Stop scheduler if running.
    public func stop() async {
        guard let scheduler = scheduler else { return }
        scheduler.stop()
        self.scheduler = nil
        logInfo("[TRUST] Scheduler stopped", category: "TrustSchedulerBootstrapper")
    }

    /// Get scheduler statistics if running.
    public func getStats() async -> SchedulerStats? {
        return await scheduler?.getStats()
    }

    /// Manually trigger recalculation.
    public func triggerRecalculation() async {
        guard let scheduler = scheduler else {
            logInfo("[TRUST] Scheduler not running, cannot trigger recalculation", category: "TrustSchedulerBootstrapper")
            return
        }

        await scheduler.runRecalculation()
    }

    // MARK: - Private Methods

    private func startScheduler() async {
        guard scheduler == nil else {
            logInfo("[TRUST] Scheduler already running", category: "TrustSchedulerBootstrapper")
            return
        }

        let newScheduler = TrustRecalcScheduler(dbPath: dbPath)
        scheduler = newScheduler

        // Start in background
        Task {
            await newScheduler.start()
        }

        logInfo("[TRUST] Scheduler started in background", category: "TrustSchedulerBootstrapper")
    }
}

// MARK: - CLI Integration

/// CLI command to manage trust scheduler.
public struct TrustSchedulerCLI {
    private let dbPath: String

    public init(dbPath: String = "./harmonia_harness.sqlite") {
        self.dbPath = dbPath
    }

    /// Show scheduler status.
    public func status() async throws {
        print("🔄 Trust Scheduler Status")
        print("========================")

        let bootstrapper = TrustSchedulerBootstrapper(dbPath: dbPath)
        let mode = GovernanceMode.current(dbPath: dbPath)

        print("Governance mode: \(mode.rawValue)")

        if let stats = await bootstrapper.getStats() {
            print("Scheduler: ✅ Running")
            print("  • Last run: \(stats.lastRun?.description ?? "never")")
            print("  • Total processed: \(stats.totalProcessed)")
            print("  • Total errors: \(stats.totalErrors)")
            print("  • Success rate: \(String(format: "%.1f", stats.successRate))%")

            if let timeSince = stats.timeSinceLastRun {
                print("  • Time since last run: \(String(format: "%.1f", timeSince / 60)) minutes")
            }
        } else {
            print("Scheduler: ❌ Not running")

            let shouldRun = mode == .governed || mode == .paranoid
            if shouldRun {
                print("⚠️  Scheduler should be running in \(mode.rawValue) mode")
                print("   Run 'harmonia trust scheduler start' to start it")
            } else {
                print("✓ Scheduler correctly off in \(mode.rawValue) mode")
            }
        }
    }

    /// Start scheduler if governance mode requires it.
    public func start() async throws {
        print("🚀 Starting trust scheduler...")

        let bootstrapper = TrustSchedulerBootstrapper(dbPath: dbPath)
        let mode = GovernanceMode.current(dbPath: dbPath) // Get current mode
        let started = await bootstrapper.startIfNeeded(currentMode: mode)

        if started {
            print("✅ Scheduler started")
            try await status()
        } else {
            print("⏸️  Scheduler not needed in current governance mode")
        }
    }

    /// Stop scheduler.
    public func stop() async throws {
        print("🛑 Stopping trust scheduler...")

        let bootstrapper = TrustSchedulerBootstrapper(dbPath: dbPath)
        await bootstrapper.stop()

        print("✅ Scheduler stopped")
        try await status()
    }

    /// Trigger manual recalculation.
    public func trigger() async throws {
        print("⚡ Triggering manual trust recalculation...")

        let bootstrapper = TrustSchedulerBootstrapper(dbPath: dbPath)
        await bootstrapper.triggerRecalculation()

        print("✅ Recalculation triggered")
        try await status()
    }
}

// MARK: - Logging Helper

private func logInfo(_ message: String, category: String) {
    print("[INFO][\(category)] \(message)")
}
