//
//  AccessumFlowStore.swift
//  AnigmaAppMac
//
//  Manages access control policies, permission checking, and audit logging.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaHostMac

@MainActor
@Observable
final class AccessumFlowStore {

    // MARK: - Properties

    /// Accessum Flow client for access control and flow management
    private let accessumFlowClient: AccessumFlowClient

    /// Current access policies
    var accessPolicies: [PolicyInfo] = []

    /// Access audit log
    var accessAuditLog: [AuditEntry] = []

    /// Flow control status
    var flowStatus: FlowStatusResponse?

    // MARK: - Dependencies (Injected)

    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }

    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }

    // MARK: - Initialization

    init(accessumFlowClient: AccessumFlowClient) {
        self.accessumFlowClient = accessumFlowClient
    }

    // MARK: - Policy Operations

    /// Load all access policies
    func loadPolicies() async {
        do {
            let response = try await accessumFlowClient.listPolicies()
            accessPolicies = response.policies
        } catch {
            showError("Failed to load access policies: \(error)")
        }
    }

    /// Create a new access policy
    func createPolicy(name: String, rules: [AccessRule]) async {
        do {
            _ = try await accessumFlowClient.createPolicy(name: name, rules: rules)
            await loadPolicies()
            showToast("Policy Created", name, "shield.checkmark")
        } catch {
            showError("Failed to create policy: \(error)")
        }
    }

    /// Update an existing policy
    func updatePolicy(id: String, rules: [AccessRule]) async {
        do {
            _ = try await accessumFlowClient.updatePolicy(id: id, rules: rules)
            await loadPolicies()
            showToast("Policy Updated", id, "shield.checkmark")
        } catch {
            showError("Failed to update policy: \(error)")
        }
    }

    /// Delete a policy
    func deletePolicy(id: String) async {
        do {
            _ = try await accessumFlowClient.deletePolicy(id: id)
            await loadPolicies()
            showToast("Policy Deleted", id, "trash")
        } catch {
            showError("Failed to delete policy: \(error)")
        }
    }

    // MARK: - Permission Checking

    /// Check if an action is permitted
    func checkAccess(actor: String, resource: String, action: String) async -> Bool {
        do {
            let response = try await accessumFlowClient.checkPermission(
                actor: actor,
                resource: resource,
                action: action
            )
            return response.permitted
        } catch {
            showError("Access check failed: \(error)")
            return false
        }
    }

    /// Evaluate multiple permissions at once
    func batchCheckAccess(checks: [PermissionCheck]) async -> [PermissionCheckResponse] {
        do {
            let response = try await accessumFlowClient.batchCheck(checks: checks)
            return response.results
        } catch {
            showError("Batch access check failed: \(error)")
            return []
        }
    }

    // MARK: - Audit Operations

    /// Load access audit log
    func loadAuditLog(limit: Int = 100, offset: Int = 0) async {
        do {
            let response = try await accessumFlowClient.getAuditLog(limit: limit, offset: offset)
            accessAuditLog = response.entries
        } catch {
            showError("Failed to load audit log: \(error)")
        }
    }

    /// Search audit log by criteria
    func searchAudit(
        actor: String? = nil,
        resource: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async {
        do {
            let response = try await accessumFlowClient.searchAudit(
                actor: actor,
                resource: resource,
                startDate: startDate,
                endDate: endDate
            )
            accessAuditLog = response.entries
            showToast(
                "Audit Search Complete",
                "\(response.total) entries found",
                "magnifyingglass"
            )
        } catch {
            showError("Audit search failed: \(error)")
        }
    }

    // MARK: - Flow Control Operations

    /// Refresh flow control status
    func refreshFlowStatus() async {
        do {
            flowStatus = try await accessumFlowClient.getFlowStatus()
        } catch {
            print("Failed to refresh flow status: \(error)")
        }
    }

    /// Enable a flow control rule
    func enableFlowRule(ruleId: String) async {
        do {
            _ = try await accessumFlowClient.enableFlow(ruleId: ruleId)
            await refreshFlowStatus()
            showToast("Flow Rule Enabled", ruleId, "play.circle")
        } catch {
            showError("Failed to enable flow rule: \(error)")
        }
    }

    /// Disable a flow control rule
    func disableFlowRule(ruleId: String) async {
        do {
            _ = try await accessumFlowClient.disableFlow(ruleId: ruleId)
            await refreshFlowStatus()
            showToast("Flow Rule Disabled", ruleId, "pause.circle")
        } catch {
            showError("Failed to disable flow rule: \(error)")
        }
    }
}
