//
//  CommandLedgerReader.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct CommandLedgerReader {
  public let repoRoot: URL
  private let decoder = JSONDecoder()
  private let ledgerURL: URL

  public init(repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)) {
    self.repoRoot = repoRoot
    self.decoder.dateDecodingStrategy = .iso8601
    let ledgerDir = repoRoot.appendingPathComponent(".opencode", isDirectory: true)
      .appendingPathComponent("ledger", isDirectory: true)
    self.ledgerURL = ledgerDir.appendingPathComponent("workflow.jsonl", isDirectory: false)
  }

  public func load() throws -> [CommandLedgerRecord] {
    guard FileManager.default.fileExists(atPath: ledgerURL.path) else {
      return []
    }
    let contents = try String(contentsOf: ledgerURL)
    let lines = contents.split(whereSeparator: \.isNewline)
    return try lines.compactMap { line in
      guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
        return nil
      }
      return try decoder.decode(CommandLedgerRecord.self, from: Data(line.utf8))
    }
  }

  public func sessions(from records: [CommandLedgerRecord]) -> [String: [CommandLedgerRecord]] {
    Dictionary(grouping: records) { $0.meta.sessionID ?? "unknown" }
  }
}
