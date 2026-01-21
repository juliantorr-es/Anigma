//
//  LedgerEventIndexer.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Automatic indexer for ledger events.
public actor LedgerEventIndexer {
    private let searchManager: SemanticSearchManager

    public init(searchManager: SemanticSearchManager) {
        self.searchManager = searchManager
    }

    /// Index a ledger event for semantic search.
    public func indexEvent(
        segmentId: String,
        eventId: String,
        contentHash: String,
        textContent: String
    ) async throws {
        try await searchManager.indexEvent(
            segmentId: segmentId,
            eventId: eventId,
            contentHash: contentHash,
            textContent: textContent
        )
    }

    /// Batch index multiple events.
    public func indexBatch(
        events: [LedgerEventToIndex]
    ) async throws {
        for event in events {
            try await indexEvent(
                segmentId: event.segmentId,
                eventId: event.eventId,
                contentHash: event.contentHash,
                textContent: event.textContent
            )
        }
    }
}

/// Event to be indexed.
public struct LedgerEventToIndex: Sendable {
    public let segmentId: String
    public let eventId: String
    public let contentHash: String
    public let textContent: String

    public init(
        segmentId: String,
        eventId: String,
        contentHash: String,
        textContent: String
    ) {
        self.segmentId = segmentId
        self.eventId = eventId
        self.contentHash = contentHash
        self.textContent = textContent
    }
}
