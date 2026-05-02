//
//  PermissionLifecycleManager.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public struct ScopeGrant: Codable, Sendable {
    public let scope: String
    public let grantedAt: Date
    public let expiresAt: Date?
    public let lastUsedAt: Date?

    public init(scope: String, grantedAt: Date = Date(), expiresAt: Date? = nil, lastUsedAt: Date? = nil) {
        self.scope = scope
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.lastUsedAt = lastUsedAt
    }
}

public struct PermissionState: Codable, Sendable {
    public let accountId: String
    public let grants: [ScopeGrant]
    public let tokenExpiresAt: Date?
    public let lastConsentAt: Date?
    public let refreshFailedCount: Int

    public init(
        accountId: String,
        grants: [ScopeGrant] = [],
        tokenExpiresAt: Date? = nil,
        lastConsentAt: Date? = nil,
        refreshFailedCount: Int = 0
    ) {
        self.accountId = accountId
        self.grants = grants
        self.tokenExpiresAt = tokenExpiresAt
        self.lastConsentAt = lastConsentAt
        self.refreshFailedCount = refreshFailedCount
    }
}

public actor PermissionLifecycleManager {
    private var states: [String: PermissionState] = [:] // AccountID -> State
    private let healthManager: HealthManager // To update health based on permissions

    public init(healthManager: HealthManager) {
        self.healthManager = healthManager
    }

    public func updateState(accountId: String, newState: PermissionState) {
        states[accountId] = newState
        checkHealth(accountId: accountId)
    }

    public func getState(accountId: String) -> PermissionState? {
        return states[accountId]
    }

    public func recordGrant(accountId: String, scopes: [String], expiresAt: Date?) {
        let state = states[accountId] ?? PermissionState(accountId: accountId)
        let newGrants = scopes.map { ScopeGrant(scope: $0, expiresAt: expiresAt) }

        // Merge grants
        var mergedGrants = state.grants
        for grant in newGrants {
            if let index = mergedGrants.firstIndex(where: { $0.scope == grant.scope }) {
                mergedGrants[index] = grant
            } else {
                mergedGrants.append(grant)
            }
        }

        let newState = PermissionState(
            accountId: accountId,
            grants: mergedGrants,
            tokenExpiresAt: state.tokenExpiresAt,
            lastConsentAt: Date(),
            refreshFailedCount: 0 // Reset failure count on new grant
        )

        updateState(accountId: accountId, newState: newState)
    }

    public func recordRefreshFailure(accountId: String) {
        guard let state = states[accountId] else { return }

        let newState = PermissionState(
            accountId: accountId,
            grants: state.grants,
            tokenExpiresAt: state.tokenExpiresAt,
            lastConsentAt: state.lastConsentAt,
            refreshFailedCount: state.refreshFailedCount + 1
        )

        updateState(accountId: accountId, newState: newState)
    }

    private func checkHealth(accountId: String) {
        guard let state = states[accountId] else { return }

        // Logic to determine if health should be degraded
        if state.refreshFailedCount > 3 {
            // This would ideally call back to HealthManager or emit an event
            // For now, we assume HealthManager polls or we expose a check method
        }

        if let expiresAt = state.tokenExpiresAt, expiresAt < Date() {
             // Token expired
        }
    }

    public func checkExpiry(accountId: String) -> Bool {
        guard let state = states[accountId], let expiresAt = state.tokenExpiresAt else { return false }
        return expiresAt < Date()
    }
}
