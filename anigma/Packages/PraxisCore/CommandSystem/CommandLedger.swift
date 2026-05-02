//
//  CommandLedger.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct CommandLedgerMeta: Codable, Sendable {
  public let sessionID: String?
  public let agent: String?
  public let messageID: String?
  public let command: String?
}

public struct CommandLedgerRecord: Codable, Sendable {
  public let kind: String
  public let ts: Date
  public let meta: CommandLedgerMeta
  public let detail: [String: String]?

  public init(kind: String, ts: Date = Date(), meta: CommandLedgerMeta, detail: [String: String]? = nil) {
    self.kind = kind
    self.ts = ts
    self.meta = meta
    self.detail = detail
  }
}

public struct CommandLedger: Sendable {
  public let repoRoot: URL
  private let encoder = JSONEncoder()
  private let ledgerURL: URL

  public init(repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)) {
    self.repoRoot = repoRoot
    self.encoder.dateEncodingStrategy = .iso8601
    let ledgerDir = repoRoot.appendingPathComponent(".opencode", isDirectory: true)
      .appendingPathComponent("ledger", isDirectory: true)
    self.ledgerURL = ledgerDir.appendingPathComponent("workflow.jsonl", isDirectory: false)
  }

  public func append(kind: String, sessionID: String?, agent: String?, command: String, messageID: String?, detail: [String: String]? = nil) throws {
    let record = CommandLedgerRecord(
      kind: kind,
      meta: CommandLedgerMeta(sessionID: sessionID, agent: agent, messageID: messageID, command: command),
      detail: detail
    )
    let lineData = try encoder.encode(record)
    guard let line = String(data: lineData, encoding: .utf8) else {
        fatalError("Failed to unwrap line")
    }

    try FileManager.default.createDirectory(at: ledgerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: ledgerURL.path) {
      let handle = try FileHandle(forWritingTo: ledgerURL)
      try handle.seekToEnd()
      handle.write(line.data(using: .utf8)!)
      try handle.close()
    } else {
      try line.write(to: ledgerURL, atomically: true, encoding: .utf8)
    }
  }
}
