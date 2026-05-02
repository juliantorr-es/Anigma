//
//  HarmoniaStore.swift
//  AnigmaAppMac
//
//  Manages Harmonia CLI operations including vault status, tech debt analysis, and ledger search.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaHostMac

@MainActor
@Observable
final class HarmoniaStore {

    // MARK: - Properties

    /// Harmonia CLI client (from DaemonHostCapability)
    private let harmoniaClient: HarmoniaClient

    /// Vault status from Harmonia CLI
    var vaultStatus: HarmoniaClient.VaultStatusResponse?

    /// Pipeline status from Harmonia CLI
    var pipelineStatus: HarmoniaClient.PipelineStatusResponse?

    /// Tech debt analysis report
    var techDebtReport: HarmoniaClient.TechDebtAuditResponse?

    /// Search results from ledger
    var searchResults: HarmoniaClient.SearchResponse?

    /// Projection callback for ledger search UI state (injected from AppStore)
    var projectLedgerSearch: (LedgerSearchProjection) -> Void = { _ in }

    /// Last time vault status was refreshed
    private var lastVaultRefresh: Date?

    /// Last time pipeline status was refreshed
    private var lastPipelineRefresh: Date?

    // MARK: - Dependencies (Injected)

    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }

    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }

    struct LedgerSearchProjection {
        let query: String
        let results: [HarmoniaClient.SearchResult]
        let totalMatches: Int
        let isSearching: Bool
        let errorMessage: String?
    }

    // MARK: - Initialization

    init(harmoniaClient: HarmoniaClient) {
        self.harmoniaClient = harmoniaClient
    }

    // MARK: - Vault Operations

    /// Refresh vault status from Harmonia CLI
    func refreshVaultStatus() async {
        do {
            vaultStatus = try await harmoniaClient.vaultStatus()
            lastVaultRefresh = Date()
        } catch {
            print("Failed to refresh vault status: \(error)")
        }
    }

    /// Verify vault integrity
    func verifyVault() async throws -> HarmoniaClient.VaultVerificationResponse {
        let result = try await harmoniaClient.vaultVerify()
        showToast("Vault Verified", "Integrity check complete", "shield.checkmark")
        return result
    }

    /// Run vault garbage collection
    func runVaultGC(dryRun: Bool = false) async throws -> HarmoniaClient.VaultGCResponse {
        let result = try await harmoniaClient.vaultGC(dryRun: dryRun)
        // Refresh vault status after GC
        await refreshVaultStatus()
        showToast(
            "Vault GC Complete",
            dryRun ? "Dry run finished" : "Cleanup complete",
            "trash.circle"
        )
        return result
    }

    /// Check if vault status needs refresh (5 minute cache)
    var vaultNeedsRefresh: Bool {
        guard let lastRefresh = lastVaultRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > 300 // 5 minutes
    }

    // MARK: - Pipeline Status Operations

    /// Refresh pipeline status from Harmonia CLI
    func refreshPipelineStatus(workspace: String) async {
        do {
            pipelineStatus = try await harmoniaClient.pipelineStatus(workspace: workspace)
            lastPipelineRefresh = Date()
        } catch {
            print("Failed to refresh pipeline status: \(error)")
        }
    }

    /// Check if pipeline status needs refresh (30 second cache)
    var pipelineNeedsRefresh: Bool {
        guard let lastRefresh = lastPipelineRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > 30 // 30 seconds
    }

    // MARK: - Tech Debt Operations

    /// Run tech debt audit on a path
    func runTechDebtAudit(path: String) async {
        do {
            techDebtReport = try await harmoniaClient.techDebtAudit(path: path).response
            if let report = techDebtReport {
                showToast(
                    "Tech Debt Audit Complete",
                    "\(report.totalIssues) issues found",
                    "chart.bar.doc.horizontal"
                )
            }
        } catch {
            showError("Failed to run tech debt audit: \(error)")
        }
    }

    // MARK: - Ledger Search Operations

    /// Run tech debt audit on a path
    func techDebtAudit(path: String) async -> (HarmoniaClient.TechDebtAuditResponse?, TimeInterval) {
        do {
            let result = try await harmoniaClient.techDebtAudit(path: path)
            self.techDebtReport = result.response
            return (result.response, result.latency)
        } catch {
            showError("Tech debt audit failed: \(error.localizedDescription)")
            return (nil, 0)
        }
    }

    /// Search the ledger.
    func searchLedger(query: String, limit: Int = 10) async {

        projectLedgerSearch(
            LedgerSearchProjection(
                query: query,
                results: searchResults?.results ?? [],
                totalMatches: searchResults?.totalMatches ?? 0,
                isSearching: true,
                errorMessage: nil
            )
        )

        do {
            searchResults = try await harmoniaClient.search(query: query, limit: limit)
            if let results = searchResults {
                projectLedgerSearch(
                    LedgerSearchProjection(
                        query: query,
                        results: results.results,
                        totalMatches: results.totalMatches,
                        isSearching: false,
                        errorMessage: nil
                    )
                )
                showToast(
                    "Search Complete",
                    "\(results.results.count) results found",
                    "magnifyingglass"
                )
            }
        } catch {
            searchResults = nil
            let message = "Failed to search ledger: \(error)"
            projectLedgerSearch(
                LedgerSearchProjection(
                    query: query,
                    results: [],
                    totalMatches: 0,
                    isSearching: false,
                    errorMessage: message
                )
            )
            showError(message)
        }
    }

    // MARK: - Daemon Operations

    /// Start daemon via Harmonia CLI
    func startDaemon() async throws {
        try await harmoniaClient.daemonStart()
        showToast("Daemon Started", "Anigmad is now running", "power")
    }

    /// Stop daemon via Harmonia CLI
    func stopDaemon() async throws {
        try await harmoniaClient.daemonStop()
        showToast("Daemon Stopped", "Anigmad has been stopped", "power.circle")
    }
}
