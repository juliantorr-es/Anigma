//
//  PraxisSessionIndex.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Represents what a gate or apply-check returned.
public struct GateOutcome: Codable, Sendable {
    public let ok: Bool
    public let code: Int?
    public let stdout: String?
    public let stderr: String?

    public init(ok: Bool, code: Int?, stdout: String?, stderr: String?) {
        self.ok = ok
        self.code = code
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Captures the optional metadata attached to a ledger row.
public struct LedgerRecordDetail: Codable, Sendable {
    public let phaseId: String?
    public let acceptanceRefs: [String]?
    public let applyCheck: GateOutcome?
    public let gates: GateOutcome?
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case phaseId
        case acceptanceRefs
        case applyCheck
        case gates
        case reason
    }
}

/// Raw ledger entry.
public struct LedgerRecord: Codable, Sendable {
    public let kind: String
    public let timestamp: Date
    public let meta: LedgerMeta
    public let patchHash: String?
    public let detail: LedgerRecordDetail?

    public var sessionID: String {
        meta.sessionID ?? "unknown"
    }

    public var receiptID: String? {
        meta.messageID
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case timestamp = "ts"
        case meta
        case patchHash
        case detail
    }

    public init(kind: String, timestamp: Date, meta: LedgerMeta, patchHash: String?, detail: LedgerRecordDetail?) {
        self.kind = kind
        self.timestamp = timestamp
        self.meta = meta
        self.patchHash = patchHash
        self.detail = detail
    }
}

public struct LedgerMeta: Codable, Sendable {
    public let sessionID: String?
    public let patchHash: String?
    public let messageID: String?
    public let gate: String?
    public let phaseId: String?
}

/// Quarantine entry.
public struct QuarantineRecord: Codable, Sendable {
    public let ts: Date
    public let sessionID: String?
    public let patchHash: String?
    public let reason: String?
}

/// Aggregated session record with patch chains and blockers.
public struct GateFailure: Codable, Sendable {
    public let kind: String
    public let phaseId: String?
    public let gateName: String?
    public let outcome: GateOutcome
    public let receiptIDs: [String]

    public init(kind: String, phaseId: String?, gateName: String?, outcome: GateOutcome, receiptIDs: [String]) {
        self.kind = kind
        self.phaseId = phaseId
        self.gateName = gateName
        self.outcome = outcome
        self.receiptIDs = receiptIDs
    }
}

public struct SessionRecord: Sendable {
    public let sessionID: String
    public let patchChains: [PatchReceiptChain]
    public let quarantineReasons: [String]
    public let missingPhases: [String]
    public let gateFailures: [GateFailure]

    public init(sessionID: String, patchChains: [PatchReceiptChain], quarantineReasons: [String], missingPhases: [String], gateFailures: [GateFailure]) {
        self.sessionID = sessionID
        self.patchChains = patchChains
        self.quarantineReasons = quarantineReasons
        self.missingPhases = missingPhases
        self.gateFailures = gateFailures
    }
}

public struct PatchReceiptChain: Sendable {
    public let patchHash: String?
    public let records: [LedgerRecord]
    public let gateOutcomes: [String]
    public let acceptanceRefs: [String]
    public let phaseId: String?
    public let gateFailures: [GateFailure]

    public init(patchHash: String?, records: [LedgerRecord], gateOutcomes: [String], acceptanceRefs: [String], phaseId: String?, gateFailures: [GateFailure]) {
        self.patchHash = patchHash
        self.records = records
        self.gateOutcomes = gateOutcomes
        self.acceptanceRefs = acceptanceRefs
        self.phaseId = phaseId
        self.gateFailures = gateFailures
    }
}

/// In-memory index over Praxis sessions derived from ledger files.
public struct PraxisSessionIndex: Sendable {
    public let sessions: [SessionRecord]

    public init(sessions: [SessionRecord]) {
        self.sessions = sessions
    }

    public init(ledgerURL: URL, quarantineURL: URL? = nil) throws {
        let ledgerEntries = try Self.loadLedger(from: ledgerURL)
        let quarantines = try Self.loadQuarantine(from: quarantineURL)
        let sessions = Self.buildSessions(from: ledgerEntries, quarantines: quarantines)
        self.sessions = sessions
    }

    public func session(withID sessionID: String) -> SessionRecord? {
        sessions.first { $0.sessionID == sessionID }
    }

    public func describeSessions() -> [SessionRecord] {
        sessions
    }

    private static func loadLedger(from url: URL) throws -> [LedgerRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let raw = try String(contentsOf: url)
        let lines = raw.split(whereSeparator: \.isNewline)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try lines.compactMap { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                return nil
            }
            return try decoder.decode(LedgerRecord.self, from: Data(line.utf8))
        }
    }

    private static func loadQuarantine(from url: URL?) throws -> [QuarantineRecord] {
        guard let url = url, FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let raw = try String(contentsOf: url)
        let lines = raw.split(whereSeparator: \.isNewline)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try lines.compactMap { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                return nil
            }
            return try decoder.decode(QuarantineRecord.self, from: Data(line.utf8))
        }
    }

    private static func buildSessions(from entries: [LedgerRecord], quarantines: [QuarantineRecord]) -> [SessionRecord] {
        let grouped = Dictionary(grouping: entries) { $0.sessionID }
        return grouped.map { sessionID, records in
            let patchChains = Self.buildPatchChains(from: records)
            let missingPhases = patchChains.flatMap { chain in
                Self.missingPhases(in: chain.records)
            }
            let gateFailures = patchChains.flatMap { $0.gateFailures }
            let quarantineReasons = quarantines
                .filter { $0.sessionID == sessionID }
                .compactMap { $0.reason }

            return SessionRecord(
                sessionID: sessionID,
                patchChains: patchChains,
                quarantineReasons: quarantineReasons,
                missingPhases: Array(Set(missingPhases)).sorted(),
                gateFailures: gateFailures
            )
        }.sorted { $0.sessionID < $1.sessionID }
    }

    private static func buildPatchChains(from records: [LedgerRecord]) -> [PatchReceiptChain] {
        let grouped = Dictionary(grouping: records) { $0.patchHash ?? "head" }
        return grouped.map { patchHash, recs in
            let gateOutcomes = recs.compactMap { $0.meta.gate }
            let sorted = recs.sorted { $0.timestamp < $1.timestamp }
            let acceptanceRefs = Self.collectAcceptanceRefs(from: sorted)
            let phaseId = sorted.compactMap { $0.detail?.phaseId ?? $0.meta.phaseId }.first
            let gateFailures = Self.buildGateFailures(from: sorted)
            return PatchReceiptChain(
                patchHash: patchHash == "head" ? nil : patchHash,
                records: sorted,
                gateOutcomes: gateOutcomes,
                acceptanceRefs: acceptanceRefs,
                phaseId: phaseId,
                gateFailures: gateFailures
            )
        }.sorted { ($0.patchHash ?? "") < ($1.patchHash ?? "") }
    }

    private static func collectAcceptanceRefs(from records: [LedgerRecord]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for entry in records {
            guard let refs = entry.detail?.acceptanceRefs else {
                continue
            }
            for ref in refs {
                guard !seen.contains(ref) else { continue }
                seen.insert(ref)
                ordered.append(ref)
            }
        }
        return ordered
    }

    private static func buildGateFailures(from records: [LedgerRecord]) -> [GateFailure] {
        var failures: [GateFailure] = []

        for record in records {
            let receiptIDs = record.receiptID.map { [$0] } ?? []
            let phaseId = record.detail?.phaseId ?? record.meta.phaseId
            let gateName = record.meta.gate

            if let applyCheck = record.detail?.applyCheck, !applyCheck.ok {
                failures.append(.init(kind: record.kind, phaseId: phaseId, gateName: gateName, outcome: applyCheck, receiptIDs: receiptIDs))
            }
            if let gateOutcome = record.detail?.gates, !gateOutcome.ok {
                failures.append(.init(kind: record.kind, phaseId: phaseId, gateName: gateName, outcome: gateOutcome, receiptIDs: receiptIDs))
            }
        }

        return failures
    }

    public static func missingPhases(in records: [LedgerRecord]) -> [String] {
        let requiredSequence = ["inspection", "generation", "proposal", "validation", "apply"]
        let kinds = Set(records.map { $0.kind })
        return requiredSequence.filter { !kinds.contains($0) }
    }
}
