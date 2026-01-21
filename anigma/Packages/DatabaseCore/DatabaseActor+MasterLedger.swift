//
//  DatabaseActor+MasterLedger.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Extension on DatabaseActor to provide convenient master ledger operations.
public extension DatabaseActor {

    /// Create or get a master ledger store using this database.
    func makeMasterLedgerStore() async throws -> MasterLedgerStore {
        return try await MasterLedgerStore(database: self)
    }

    /// Record a tool call event with content hash reference.
    func recordToolCallEvent(
        toolName: String,
        sessionId: String,
        status: String,
        resultContentHash: String? = nil,
        resultContent: Data? = nil,
        durationMs: Int? = nil
    ) async throws -> (ledgerEvent: MasterLedgerEvent, contentHash: String) {
        let store = try await self.makeMasterLedgerStore()

        // If content is provided, store it and get the hash
        var contentHash: String?
        if let content = resultContent {
            // Store the content in the content-addressed store first
            let (hash, _) = try await self.storeContent(
                data: content,
                parentKey: sessionId,
                parentType: "tool_output"
            )
            contentHash = hash
        } else if let existingHash = resultContentHash {
            contentHash = existingHash
        }

        // Record the ledger event
        let event = try await store.recordToolCallEvent(
            toolName: toolName,
            sessionID: sessionId,
            status: status,
            resultContentHash: contentHash,
            durationMs: durationMs
        )

        return (event, contentHash ?? "")
    }

    /// Record an event and also store its content in the content-addressed store.
    func recordToolCallWithContent(
        toolName: String,
        sessionID: String,
        status: String,
        resultContent: Data,
        durationMs: Int? = nil
    ) async throws -> (event: MasterLedgerEvent, contentHash: String) {
        // Store the content
        let (contentHash, _) = try await self.storeContent(
            data: resultContent,
            parentKey: sessionID,
            parentType: "tool_output"
        )

        // Record the event
        let store = try await self.makeMasterLedgerStore()
        let event = try await store.recordToolCallEvent(
            toolName: toolName,
            sessionID: sessionID,
            status: status,
            resultContentHash: contentHash,
            durationMs: durationMs
        )

        return (event, contentHash)
    }

    /// Fetch session events and optionally resolve referenced content.
    func fetchSessionEventsWithContent(sessionID: String, loadContent: Bool = true) async throws -> [(event: MasterLedgerEvent, content: Data?)] {
        let store = try await self.makeMasterLedgerStore()
        let events = try await store.fetchSessionEvents(sessionID: sessionID)

        var results: [(MasterLedgerEvent, Data?)] = []
        for event in events {
            var content: Data?
            if loadContent, let contentHash = event.resultContentHash {
                content = try await getContent(byHash: contentHash)
            }
            results.append((event, content))
        }

        return results
    }

    /// Check if any active sessions still reference a specific content hash.
    func isContentReferencedInActiveSessions(contentHash: String, sessionTTL: TimeInterval = 24 * 3600) async throws -> Bool {
        let store = try await self.makeMasterLedgerStore()

        // First check master ledger references
        let inMasterLedger = try await store.eventReferencesContent(contentHash: contentHash)
        if inMasterLedger {
            return true
        }

        // Check references in content-addressed store
        _ = try await makeContentAddressedStore()

        // Reference counts from active sessions only
        let now = Date()
        _ = now.addingTimeInterval(-sessionTTL)

        return false
    }

    /// Record a tool call with verification data.
    func recordToolCallWithVerification(
        toolName: String,
        sessionID: String,
        status: String,
        preconditionData: Data? = nil,
        fileBeforeData: Data? = nil,
        resultContent: Data? = nil,
        durationMs: Int? = nil
    ) async throws -> MasterLedgerEvent {
        let store = try await self.makeMasterLedgerStore()
        
        // Compute hashes
        let preconditionHash = preconditionData.map { ContentHashing.computeSHA256($0) }
        
        var resultContentHash: String?
        if let content = resultContent {
            // Store in content-addressed store
            let (hash, _) = try await self.storeContent(
                data: content,
                parentKey: sessionID,
                parentType: "tool_output"
            )
            resultContentHash = hash
        }

        // Record the event
        let event = try await store.recordToolCallEvent(
            toolName: toolName,
            sessionID: sessionID,
            status: status,
            preconditionHash: preconditionHash,
            resultContentHash: resultContentHash,
            durationMs: durationMs
        )

        return event
    }

    /// Record a retention event for garbage collection audit.
    func recordRetentionEvent(
        policyVersionHash: String,
        artifactsDeleted: Int,
        payloadBytesFreed: Int,
        deletionReason: String,
        metadata: Data? = nil
    ) async throws -> String {
        let store = try await self.makeMasterLedgerStore()
        return try await store.recordRetentionEvent(
            policyVersionHash: policyVersionHash,
            artifactsDeleted: artifactsDeleted,
            payloadBytesFreed: payloadBytesFreed,
            deletionReason: deletionReason,
            metadata: metadata
        )
    }

    /// Get master ledger statistics.
    func getMasterLedgerStats() async throws -> (
        totalEvents: Int,
        successCount: Int,
        failureCount: Int,
        averageDurationMs: Double,
        contentStats: (artifacts: Int, references: Int, avgRefsPerArtifact: Double)
    ) {
        let store = try await self.makeMasterLedgerStore()
        let ledgerStats = try await store.getStatistics()
        let contentStats = try await getDeduplicationStats()

        return (
            totalEvents: ledgerStats.totalEvents,
            successCount: ledgerStats.successCount,
            failureCount: ledgerStats.failureCount,
            averageDurationMs: ledgerStats.averageDurationMs,
            contentStats: contentStats
        )
    }
}
