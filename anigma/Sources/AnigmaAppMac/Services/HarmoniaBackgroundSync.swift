//
//  HarmoniaBackgroundSync.swift
//  AnigmaAppMac
//
//  Background synchronization service for Harmonia CLI data.
//

import Foundation
import AnigmaHostMac
import Combine

/// Manages background synchronization of Harmonia CLI data.
@MainActor
public final class HarmoniaBackgroundSync: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var lastDaemonCheck: Date?
    @Published public private(set) var lastVaultRefresh: Date?
    @Published public private(set) var lastPipelineRefresh: Date?

    // MARK: - Configuration

    public struct Configuration {
        var daemonCheckInterval: TimeInterval = 10.0  // Check daemon every 10s
        var vaultRefreshInterval: TimeInterval = 300.0  // Refresh vault every 5 minutes
        var pipelineRefreshInterval: TimeInterval = 30.0  // Refresh pipeline every 30s
        var enableToastNotifications: Bool = true

        public init() {}
    }

    public var configuration = Configuration()

    // MARK: - Private State

    private var daemonTask: Task<Void, Never>?
    private var vaultTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?

    private weak var appStore: AppStore?
    private var previousDaemonStatus: String?
    private var previousVaultArtifactCount: Int?
    private var previousPipelineJobCounts: (Int, Int, Int, Int)?

    // MARK: - Initialization

    init(appStore: AppStore) {
        self.appStore = appStore
    }

    deinit {
        Task { @MainActor in
            self.stop()
        }
    }

    // MARK: - Control

    /// Start background synchronization.
    public func start() {
        guard !isRunning else { return }

        isRunning = true

        // Start timers
        startDaemonMonitoring()
        startVaultRefresh()
        startPipelineRefresh()

        print("[HarmoniaBackgroundSync] Started background sync")
    }

    /// Stop background synchronization.
    public func stop() {
        guard isRunning else { return }

        isRunning = false

        // Cancel all background tasks
        daemonTask?.cancel()
        daemonTask = nil

        vaultTask?.cancel()
        vaultTask = nil

        pipelineTask?.cancel()
        pipelineTask = nil

        print("[HarmoniaBackgroundSync] Stopped background sync")
    }

    /// Restart background synchronization with current configuration.
    public func restart() {
        stop()
        start()
    }

    // MARK: - Daemon Monitoring

    private func startDaemonMonitoring() {
        daemonTask?.cancel()

        // Start async Task loop for periodic checks
        daemonTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Initial check
            await self.checkDaemonStatus()

            // Periodic checks
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.configuration.daemonCheckInterval))
                guard !Task.isCancelled else { break }
                await self.checkDaemonStatus()
            }
        }
    }

    private func checkDaemonStatus() async {
        guard let appStore = appStore else { return }

        let status = await appStore.getDaemonStatus()
        lastDaemonCheck = Date()

        // Detect status changes
        if let previous = previousDaemonStatus, previous != status {
            handleDaemonStatusChange(from: previous, to: status)
        }

        previousDaemonStatus = status
    }

    private func handleDaemonStatusChange(from oldStatus: String, to newStatus: String) {
        guard configuration.enableToastNotifications else { return }
        guard let appStore = appStore else { return }

        if newStatus.contains("Running") && !oldStatus.contains("Running") {
            appStore.showToast(
                title: "Daemon Started",
                subtitle: "Harmonia daemon is now online",
                icon: "checkmark.circle.fill"
            )
        } else if !newStatus.contains("Running") && oldStatus.contains("Running") {
            appStore.showToast(
                title: "Daemon Stopped",
                subtitle: "Harmonia daemon is offline",
                icon: "exclamationmark.triangle.fill"
            )
        }
    }

    // MARK: - Vault Refresh

    private func startVaultRefresh() {
        vaultTask?.cancel()

        // Start async Task loop for periodic refresh
        vaultTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Initial refresh
            await self.refreshVault()

            // Periodic refresh
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.configuration.vaultRefreshInterval))
                guard !Task.isCancelled else { break }
                await self.refreshVault()
            }
        }
    }

    private func refreshVault() async {
        guard let appStore = appStore else { return }

        await appStore.refreshVaultStatus()
        lastVaultRefresh = Date()

        // Detect changes
        if let vault = appStore.vaultStatus {
            if let previous = previousVaultArtifactCount,
               vault.totalArtifacts != previous,
               configuration.enableToastNotifications {
                let delta = vault.totalArtifacts - previous
                if delta > 0 {
                    appStore.showToast(
                        title: "Vault Updated",
                        subtitle: "+\(delta) new artifacts",
                        icon: "archivebox.fill"
                    )
                }
            }
            previousVaultArtifactCount = vault.totalArtifacts
        }
    }

    // MARK: - Pipeline Refresh

    private func startPipelineRefresh() {
        pipelineTask?.cancel()

        // Start async Task loop for periodic refresh
        pipelineTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Initial refresh
            await self.refreshPipeline()

            // Periodic refresh
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.configuration.pipelineRefreshInterval))
                guard !Task.isCancelled else { break }
                await self.refreshPipeline()
            }
        }
    }

    private func refreshPipeline() async {
        guard let appStore = appStore else { return }

        await appStore.refreshPipelineStatus()
        lastPipelineRefresh = Date()

        // Detect job changes
        if let pipeline = appStore.pipelineStatus {
            let current = (
                pipeline.pendingJobs,
                pipeline.runningJobs,
                pipeline.completedJobs,
                pipeline.failedJobs
            )

            if let previous = previousPipelineJobCounts,
               configuration.enableToastNotifications {

                // Detect completed jobs
                let newCompleted = current.2 - previous.2
                if newCompleted > 0 {
                    appStore.showToast(
                        title: "Jobs Completed",
                        subtitle: "\(newCompleted) job\(newCompleted == 1 ? "" : "s") finished",
                        icon: "checkmark.circle.fill"
                    )
                }

                // Detect failed jobs
                let newFailed = current.3 - previous.3
                if newFailed > 0 {
                    appStore.showToast(
                        title: "Jobs Failed",
                        subtitle: "\(newFailed) job\(newFailed == 1 ? "" : "s") failed",
                        icon: "xmark.circle.fill"
                    )
                }
            }

            previousPipelineJobCounts = current
        }
    }

    // MARK: - Manual Refresh

    /// Manually trigger all refreshes immediately.
    public func refreshAll() async {
        await checkDaemonStatus()
        await refreshVault()
        await refreshPipeline()
    }

    /// Manually trigger daemon status check.
    public func refreshDaemonStatus() async {
        await checkDaemonStatus()
    }

    /// Manually trigger vault refresh.
    public func refreshVaultStatus() async {
        await refreshVault()
    }

    /// Manually trigger pipeline refresh.
    public func refreshPipelineStatus() async {
        await refreshPipeline()
    }
}
