//
//  AssistantConversationStore.swift
//  AnigmaAppMac
//
//  Persistent storage for assistant conversation history.
//  Handles serialization, retention limits, and context summary snapshots.
//

import Foundation
import ContractsCore

// MARK: - Row Models

struct AssistantConversationSessionRow: Codable, Sendable {
    let id: String
    let createdAt: Date
    var updatedAt: Date
}

struct AssistantConversationPruneEvent: Codable, Sendable, Identifiable {
    let id: String
    let createdAt: Date
    let messageCountBefore: Int
    let messageCountAfter: Int
    let pruneReason: String
    let summary: [AssistantConversationPrunedMessage]
}

struct AssistantConversationPrunedMessage: Sendable, Codable, Identifiable {
    let id: String
    let role: ConversationMessage.Role
    let createdAt: Date
    let contentPreview: String
    let provenanceId: String?
    let projectId: String?
    let replayMode: String?
    let deterministicRun: Bool?
    let confidence: Double?
    let sourceCount: Int?
}

// MARK: - Archive Model

private struct AssistantConversationArchive: Codable {
    var session: AssistantConversationSessionRow
    var contextPolicy: AssistantContextSourcePolicy?
    var messages: [ConversationMessage]
    var pruneEvents: [AssistantConversationPruneEvent]
    var contextSummaries: [AssistantConversationContextSnapshot]

    init(
        session: AssistantConversationSessionRow,
        contextPolicy: AssistantContextSourcePolicy? = nil,
        messages: [ConversationMessage],
        pruneEvents: [AssistantConversationPruneEvent],
        contextSummaries: [AssistantConversationContextSnapshot]
    ) {
        self.session = session
        self.contextPolicy = contextPolicy
        self.messages = messages
        self.pruneEvents = pruneEvents
        self.contextSummaries = contextSummaries
    }

    private enum CodingKeys: String, CodingKey {
        case session
        case contextPolicy
        case messages
        case pruneEvents
        case contextSummaries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decode(AssistantConversationSessionRow.self, forKey: .session)
        contextPolicy = try container.decodeIfPresent(AssistantContextSourcePolicy.self, forKey: .contextPolicy)
        messages = try container.decodeIfPresent([ConversationMessage].self, forKey: .messages) ?? []
        pruneEvents = try container.decodeIfPresent([AssistantConversationPruneEvent].self, forKey: .pruneEvents) ?? []
        contextSummaries = try container.decodeIfPresent([AssistantConversationContextSnapshot].self, forKey: .contextSummaries) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(session, forKey: .session)
        try container.encodeIfPresent(contextPolicy, forKey: .contextPolicy)
        try container.encode(messages, forKey: .messages)
        try container.encode(pruneEvents, forKey: .pruneEvents)
        try container.encode(contextSummaries, forKey: .contextSummaries)
    }
}

// MARK: - Store Actor

actor AssistantConversationStore {
    static let sessionId = "global"
    static let defaultRetentionLimit = 250

    private let storageURL: URL
    private let retentionLimit: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var isBootstrapped = false

    init(retentionLimit: Int = 250) {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Failed to unwrap application support directory")
        }

        self.storageURL = appSupport.appendingPathComponent("Anigma/Assistant/assistant_conversation.json")
        self.retentionLimit = retentionLimit
        Self.prepareStorageDirectory(for: storageURL)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    init(storageURL: URL, retentionLimit: Int = 250) {
        self.storageURL = storageURL
        self.retentionLimit = retentionLimit
        Self.prepareStorageDirectory(for: storageURL)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func bootstrap() async throws {
        _ = try await ensureBootstrapped()
    }

    func loadSession() async throws -> AssistantConversationSessionRow {
        let archive = try await ensureBootstrapped()
        return archive.session
    }

    func loadContextPolicy() async throws -> AssistantContextSourcePolicy {
        let archive = try await ensureBootstrapped()
        return archive.contextPolicy ?? AssistantContextSourcePolicy()
    }

    private func ensureBootstrapped() async throws -> AssistantConversationArchive {
        if !isBootstrapped {
            if !FileManager.default.fileExists(atPath: storageURL.path) {
                let initial = AssistantConversationArchive(
                    session: AssistantConversationSessionRow(id: Self.sessionId, createdAt: Date(), updatedAt: Date()),
                    contextPolicy: AssistantContextSourcePolicy(),
                    messages: [],
                    pruneEvents: [],
                    contextSummaries: []
                )
                try await save(initial)
            }
            isBootstrapped = true
        }
        
        let data = try Data(contentsOf: storageURL)
        return try decoder.decode(AssistantConversationArchive.self, from: data)
    }

    private func save(_ archive: AssistantConversationArchive) async throws {
        let data = try encoder.encode(archive)
        try data.write(to: storageURL, options: .atomic)
    }

    private static func prepareStorageDirectory(for storageURL: URL) {
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            print("⚠️ Assistant conversation storage unavailable: \(error.localizedDescription)")
        }
    }

    func loadHistory(limit: Int? = nil) async throws -> [ConversationMessage] {
        let archive = try await ensureBootstrapped()
        if let limit = limit {
            return Array(archive.messages.suffix(limit))
        }
        return archive.messages
    }

    func recordTurn(userMessage: ConversationMessage, assistantMessage: ConversationMessage?) async throws -> AssistantConversationSnapshot {
        var archive = try await ensureBootstrapped()
        
        archive.messages.append(userMessage)
        if let assistant = assistantMessage {
            archive.messages.append(assistant)
            
            // If we have provenance, create a context summary
            if let provenance = assistant.provenance {
                let summary = AssistantConversationContextSnapshot(
                    summary: makeContextSummary(from: provenance)
                )
                archive.contextSummaries.append(summary)
            }
        }
        
        archive.session.updatedAt = Date()
        
        // Handle retention limit
        _ = pruneArchiveIfNeeded(&archive)
        
        try await save(archive)
        
        return AssistantConversationSnapshot(
            history: archive.messages,
            latestContextSummary: archive.contextSummaries.last,
            messageCount: archive.messages.count,
            updatedAt: archive.session.updatedAt
        )
    }

    func pruneIfNeeded() async throws -> AssistantConversationPruneEvent? {
        var archive = try await ensureBootstrapped()
        let pruneEvent = pruneArchiveIfNeeded(&archive)
        guard pruneEvent != nil else {
            return nil
        }
        archive.session.updatedAt = Date()
        try await save(archive)
        return pruneEvent
    }

    func loadContextSummaries() async throws -> [AssistantConversationContextSnapshot] {
        let archive = try await ensureBootstrapped()
        return archive.contextSummaries
    }

    func loadLatestContextSummary() async throws -> AssistantConversationContextSnapshot? {
        let archive = try await ensureBootstrapped()
        return archive.contextSummaries.last
    }

    func loadPruneEvents() async throws -> [AssistantConversationPruneEvent] {
        let archive = try await ensureBootstrapped()
        return archive.pruneEvents
    }

    func exportJSON() async throws -> Data {
        let archive = try await ensureBootstrapped()
        return try encoder.encode(archive)
    }

    func exportMarkdown() async throws -> String {
        let archive = try await ensureBootstrapped()
        var md = "# Assistant Conversation Export\n\n"
        md += "- Session: \(archive.session.id)\n"
        md += "- Updated: \(archive.session.updatedAt)\n\n"
        
        for msg in archive.messages {
            md += "### \(msg.role.rawValue.capitalized) (\(msg.createdAt))\n"
            md += "\(msg.content)\n\n"
            if let prob = msg.confidence {
                md += "- Confidence: \(Int(prob * 100))%\n"
            }
            if let det = msg.provenance?.replay.deterministic {
                md += "- Run: \(det ? "deterministic" : "non-deterministic")\n"
            }
            let sourceCount = msg.sourceCount ?? msg.sources.count
            if sourceCount > 0 {
                md += "- Sources: \(sourceCount)\n"
            }
            md += "\n"
        }
        
        return md
    }
    
    func updateContextPolicy(_ policy: AssistantContextSourcePolicy) async throws -> AssistantContextSourcePolicy {
        var archive = try await ensureBootstrapped()
        archive.contextPolicy = policy
        try await save(archive)
        return policy
    }

    private func pruneArchiveIfNeeded(_ archive: inout AssistantConversationArchive) -> AssistantConversationPruneEvent? {
        guard archive.messages.count > retentionLimit else {
            return nil
        }

        let countBefore = archive.messages.count
        let toPrune = countBefore - (retentionLimit / 2)
        let pruned = Array(archive.messages.prefix(toPrune))
        archive.messages.removeFirst(toPrune)

        let prunedMessages = pruned.map { msg in
            AssistantConversationPrunedMessage(
                id: msg.id,
                role: msg.role,
                createdAt: msg.createdAt,
                contentPreview: String(msg.content.prefix(100)),
                provenanceId: msg.provenanceId ?? msg.provenance?.id,
                projectId: msg.projectId ?? msg.provenance?.projectId,
                replayMode: msg.replayMode ?? msg.provenance?.replay.mode,
                deterministicRun: msg.deterministicRun ?? msg.provenance?.replay.deterministic,
                confidence: msg.confidence ?? msg.provenance?.confidence,
                sourceCount: msg.sourceCount ?? msg.sources.count
            )
        }

        let pruneEvent = AssistantConversationPruneEvent(
            id: UUID().uuidString,
            createdAt: Date(),
            messageCountBefore: countBefore,
            messageCountAfter: archive.messages.count,
            pruneReason: "Retention limit reached (\(retentionLimit))",
            summary: prunedMessages
        )
        archive.pruneEvents.append(pruneEvent)
        return pruneEvent
    }

    private func makeContextSummary(from provenance: AnswerProvenanceRecord) -> String {
        let summary = "\(provenance.query) - \(provenance.answerText)"
        return String(summary.prefix(240))
    }
}
