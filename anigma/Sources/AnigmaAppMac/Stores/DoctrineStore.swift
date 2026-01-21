//
//  DoctrineStore.swift
//  AnigmaAppMac
//
//  Manages Doctrine rule checking, violation tracking, and pack management.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaHostMac

@MainActor
@Observable
final class DoctrineStore {

    // MARK: - Properties

    /// Doctrine CLI client for rule checking and violation management
    private let doctrineClient: DoctrineClient

    /// Current doctrine scan results
    var scanResults: DoctrineClient.ScanResponse?

    /// Doctrine violation statistics
    var stats: DoctrineClient.ViolationStatsResponse?

    /// Available doctrine rules
    var rules: DoctrineClient.RulesResponse?

    /// Available doctrine packs
    var packs: DoctrineClient.PacksResponse?

    /// Violation records list
    var violations: [DoctrineClient.ViolationsResponse.ViolationRecord] = []

    // MARK: - Dependencies (Injected)

    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }

    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }

    // MARK: - Initialization

    init(doctrineClient: DoctrineClient) {
        self.doctrineClient = doctrineClient
    }

    // MARK: - Scan Operations

    /// Scan a path for doctrine violations
    func scan(path: String, domains: [String]? = nil) async {
        do {
            scanResults = try await doctrineClient.scan(path: path, domains: domains)
            if let results = scanResults {
                showToast(
                    "Doctrine Scan Complete",
                    "\(results.totalViolations) violations found",
                    "shield.checkmark"
                )
            }
        } catch {
            showError("Failed to scan doctrine: \(error)")
        }
    }

    /// Scan a path with specific severity filter
    func scan(path: String, severity: String) async {
        do {
            scanResults = try await doctrineClient.scan(path: path, severity: severity)
            if let results = scanResults {
                showToast(
                    "Doctrine Scan Complete",
                    "\(results.totalViolations) \(severity) violations",
                    "shield.checkmark"
                )
            }
        } catch {
            showError("Failed to scan doctrine: \(error)")
        }
    }

    // MARK: - Statistics Operations

    /// Load doctrine violation statistics
    func loadStats() async {
        do {
            stats = try await doctrineClient.violationStats()
        } catch {
            showError("Failed to load doctrine stats: \(error)")
        }
    }

    // MARK: - Rule Operations

    /// Load available doctrine rules
    func loadRules(domain: String? = nil) async {
        do {
            rules = try await doctrineClient.listRules(domain: domain)
        } catch {
            showError("Failed to load doctrine rules: \(error)")
        }
    }

    /// Get details for a specific rule
    func getRuleDetails(id: String) async -> DoctrineClient.RuleDetailResponse? {
        do {
            return try await doctrineClient.getRule(id: id)
        } catch {
            showError("Failed to get rule details: \(error)")
            return nil
        }
    }

    // MARK: - Violation Operations

    /// List violations with optional filters
    func listViolations(
        severity: String? = nil,
        domain: String? = nil,
        resolved: Bool? = nil,
        limit: Int = 100
    ) async {
        do {
            let response = try await doctrineClient.listViolations(
                severity: severity,
                domain: domain,
                resolved: resolved,
                limit: limit
            )
            violations = response.violations
        } catch {
            showError("Failed to list violations: \(error)")
        }
    }

    /// Resolve a doctrine violation
    func resolveViolation(id: String, note: String? = nil) async throws {
        _ = try await doctrineClient.resolveViolation(id: id, note: note)
        showToast("Violation Resolved", id, "checkmark.circle")
        await loadStats()
    }

    // MARK: - Pack Operations

    /// Load available doctrine packs
    func loadPacks() async {
        do {
            packs = try await doctrineClient.listPacks()
        } catch {
            showError("Failed to load doctrine packs: \(error)")
        }
    }

    /// Get details for a specific pack
    func getPackDetails(id: String) async -> DoctrineClient.PackDetailResponse? {
        do {
            return try await doctrineClient.getPack(id: id)
        } catch {
            showError("Failed to get pack details: \(error)")
            return nil
        }
    }

    /// Enable a doctrine pack
    func enablePack(id: String) async throws {
        _ = try await doctrineClient.enablePack(id: id)
        showToast("Pack Enabled", id, "checkmark.square")
        await loadPacks()
    }

    /// Disable a doctrine pack
    func disablePack(id: String) async throws {
        _ = try await doctrineClient.disablePack(id: id)
        showToast("Pack Disabled", id, "xmark.square")
        await loadPacks()
    }
}
