//
//  ConversationSessionManager.swift
//  AnigmaAppMac
//
//  Coordinates the global assistant session and storage lifecycle.
//

import Foundation
import ContractsCore

actor ConversationSessionManager {
    private let store: AssistantConversationStore
    private var isBootstrapped = false

    init(store: AssistantConversationStore = AssistantConversationStore()) {
        self.store = store
    }

    var currentSessionID: String {
        AssistantConversationStore.sessionId
    }

    func bootstrap() async throws {
        if isBootstrapped {
            return
        }

        try await store.bootstrap()
        isBootstrapped = true
    }

    func loadHistory(limit: Int? = nil) async throws -> [ConversationMessage] {
        try await bootstrap()
        return try await store.loadHistory(limit: limit)
    }

    func currentSession() async throws -> AssistantConversationSessionRow {
        try await bootstrap()
        return try await store.loadSession()
    }

    func recordTurn(
        userMessage: ConversationMessage,
        assistantMessage: ConversationMessage?
    ) async throws -> AssistantConversationSnapshot {
        try await bootstrap()
        return try await store.recordTurn(userMessage: userMessage, assistantMessage: assistantMessage)
    }

    func exportJSON() async throws -> Data {
        try await bootstrap()
        return try await store.exportJSON()
    }

    func exportMarkdown() async throws -> String {
        try await bootstrap()
        return try await store.exportMarkdown()
    }

    func pruneNow() async throws -> AssistantConversationPruneEvent? {
        try await bootstrap()
        return try await store.pruneIfNeeded()
    }

    func loadContextPolicy() async throws -> AssistantContextSourcePolicy {
        try await bootstrap()
        return try await store.loadContextPolicy()
    }

    func loadContextSummaries() async throws -> [AssistantConversationContextSnapshot] {
        try await bootstrap()
        return try await store.loadContextSummaries()
    }

    func loadLatestContextSummary() async throws -> AssistantConversationContextSnapshot? {
        try await bootstrap()
        return try await store.loadLatestContextSummary()
    }

    func updateContextPolicy(_ policy: AssistantContextSourcePolicy) async throws -> AssistantContextSourcePolicy {
        try await bootstrap()
        return try await store.updateContextPolicy(policy)
    }
}
