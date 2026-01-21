//
//  PraxisReceipts.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct PraxisReceipt: Codable, Sendable {
    public struct RepoInfo: Codable, Sendable {
        public var repoRoot: String
        public var worktreeRoot: String
        public var branchName: String?
        public var headSHA: String?
    }

    public struct GateInfo: Codable, Sendable {
        public var repoIdentity: RepoIdentityGateResult?
        public var validationMatrix: ValidationMatrixResult?
    }

    public enum Outcome: String, Codable, Sendable { case success, failure }

    public var schemaVersion: Int
    public var command: String
    public var timestamp: Date
    public var repo: RepoInfo
    public var gates: GateInfo
    public var gitOps: [GitOpResult]
    public var outcome: Outcome
    public var message: String
    public var payload: [String: String]

    public init(
        schemaVersion: Int = 1,
        command: String,
        timestamp: Date = Date(),
        repo: RepoInfo,
        gates: GateInfo,
        gitOps: [GitOpResult],
        outcome: Outcome,
        message: String,
        payload: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.command = command
        self.timestamp = timestamp
        self.repo = repo
        self.gates = gates
        self.gitOps = gitOps
        self.outcome = outcome
        self.message = message
        self.payload = payload
    }
}

public struct ReceiptWriter: Sendable {
    public let repoRoot: URL

    public init(repoRoot: URL) {
        self.repoRoot = repoRoot
    }

    public func writeReceipt(_ receipt: PraxisReceipt) throws -> String {
        let dir = repoRoot.appendingPathComponent("Artifacts", isDirectory: true)
            .appendingPathComponent("praxis", isDirectory: true)
            .appendingPathComponent("receipts", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let ts = ISO8601DateFormatter().string(from: receipt.timestamp).replacingOccurrences(of: ":", with: "")
        let safeCmd = receipt.command.replacingOccurrences(of: " ", with: "_")
        let url = dir.appendingPathComponent("\(ts)-\(safeCmd).json", isDirectory: false)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(receipt)
        try data.write(to: url, options: Data.WritingOptions.atomic)
        return url.path
    }

    public func writeTicket(_ ticket: BoundaryTicket) throws -> String {
        let dir = repoRoot.appendingPathComponent("Artifacts", isDirectory: true)
            .appendingPathComponent("praxis", isDirectory: true)
            .appendingPathComponent("tickets", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let ts = ISO8601DateFormatter().string(from: ticket.timestamp).replacingOccurrences(of: ":", with: "")
        let url = dir.appendingPathComponent("\(ts)-\(ticket.ticketID).json", isDirectory: false)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(ticket)
        try data.write(to: url, options: Data.WritingOptions.atomic)
        return url.path
    }
}
