//
//  SyncManager.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public enum SyncStatus: String, Codable, Sendable {
    case idle
    case syncing
    case pendingVerification = "pending_verification"
    case queued
    case blocked
    case failed
}

public struct SyncTrackState: Codable, Sendable {
    public let trackType: SyncTrackType
    public let status: SyncStatus
    public let lastSyncedAt: Date?
    public let lastVerifiedAt: Date?
    public let watermark: String? // Cursor or token
    public let error: String?

    public init(
        trackType: SyncTrackType,
        status: SyncStatus = .idle,
        lastSyncedAt: Date? = nil,
        lastVerifiedAt: Date? = nil,
        watermark: String? = nil,
        error: String? = nil
    ) {
        self.trackType = trackType
        self.status = status
        self.lastSyncedAt = lastSyncedAt
        self.lastVerifiedAt = lastVerifiedAt
        self.watermark = watermark
        self.error = error
    }
}

public actor SyncManager {
    private var tracks: [String: [SyncTrackType: SyncTrackState]] = [:] // AccountID -> TrackType -> State

    public init() {}

    public func updateState(accountId: String, trackType: SyncTrackType, newState: SyncTrackState) {
        var accountTracks = tracks[accountId] ?? [:]
        accountTracks[trackType] = newState
        tracks[accountId] = accountTracks
    }

    public func getState(accountId: String, trackType: SyncTrackType) -> SyncTrackState? {
        return tracks[accountId]?[trackType]
    }

    public func getAllStates(accountId: String) -> [SyncTrackType: SyncTrackState] {
        return tracks[accountId] ?? [:]
    }

    // Helper to transition state
    public func transition(accountId: String, trackType: SyncTrackType, to status: SyncStatus, error: String? = nil) {
        let currentState = getState(accountId: accountId, trackType: trackType) ?? SyncTrackState(trackType: trackType)

        let newState = SyncTrackState(
            trackType: trackType,
            status: status,
            lastSyncedAt: status == .idle ? Date() : currentState.lastSyncedAt, // Update sync time on completion (idle)
            lastVerifiedAt: currentState.lastVerifiedAt,
            watermark: currentState.watermark,
            error: error
        )

        updateState(accountId: accountId, trackType: trackType, newState: newState)
    }

    public func updateWatermark(accountId: String, trackType: SyncTrackType, watermark: String) {
        guard let currentState = getState(accountId: accountId, trackType: trackType) else { return }

        let newState = SyncTrackState(
            trackType: trackType,
            status: currentState.status,
            lastSyncedAt: currentState.lastSyncedAt,
            lastVerifiedAt: currentState.lastVerifiedAt,
            watermark: watermark,
            error: currentState.error
        )

        updateState(accountId: accountId, trackType: trackType, newState: newState)
    }
}
