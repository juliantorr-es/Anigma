//
//  HealthManager.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public struct RepairRecipe: Codable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let actionType: String // e.g. "reauth", "reset_cursor"
    public let requiresUserConsent: Bool
    public let requiresAdminConsent: Bool

    public init(
        id: String,
        title: String,
        description: String,
        actionType: String,
        requiresUserConsent: Bool = false,
        requiresAdminConsent: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.actionType = actionType
        self.requiresUserConsent = requiresUserConsent
        self.requiresAdminConsent = requiresAdminConsent
    }
}

public struct HealthSnapshot: Codable, Sendable {
    public let accountId: String
    public let health: IntegrationHealth
    public let syncStates: [SyncTrackType: SyncTrackState]
    public let availableRepairs: [RepairRecipe]

    public init(
        accountId: String,
        health: IntegrationHealth,
        syncStates: [SyncTrackType: SyncTrackState],
        availableRepairs: [RepairRecipe]
    ) {
        self.accountId = accountId
        self.health = health
        self.syncStates = syncStates
        self.availableRepairs = availableRepairs
    }
}

public actor HealthManager {
    private let syncManager: SyncManager

    public init(syncManager: SyncManager) {
        self.syncManager = syncManager
    }

    public func getSnapshot(accountId: String) async -> HealthSnapshot {
        let syncStates = await syncManager.getAllStates(accountId: accountId)

        // Determine overall health based on sync states
        var status: IntegrationHealthStatus = .ok
        var reason: String?
        var repairs: [RepairRecipe] = []

        for (_, state) in syncStates {
            if state.status == .failed {
                status = .requiresUserAction
                reason = state.error ?? "Sync failed"
                repairs.append(RepairRecipe(
                    id: "retry_sync",
                    title: "Retry Sync",
                    description: "Attempt to sync again.",
                    actionType: "retry"
                ))
            } else if state.status == .blocked {
                status = .blockedByPolicy
                reason = "Blocked by policy"
            }
        }

        let health = IntegrationHealth(status: status, reason: reason, lastChecked: Date())

        return HealthSnapshot(
            accountId: accountId,
            health: health,
            syncStates: syncStates,
            availableRepairs: repairs
        )
    }

    public func executeRepair(accountId: String, recipeId: String) async throws {
        // In a real implementation, this would dispatch a RepairJob via JobEngine
        // For now, we just simulate a reset
        if recipeId == "retry_sync" {
            // Reset failed states to idle so they can be picked up again
            let states = await syncManager.getAllStates(accountId: accountId)
            for (type, state) in states {
                if state.status == .failed {
                    await syncManager.transition(accountId: accountId, trackType: type, to: .idle)
                }
            }
        }
    }
}
