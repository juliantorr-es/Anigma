//
//  CommandAudit.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import ArgumentParser
import Foundation
import PraxisCore

struct CommandAudit: ParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "audit",
      abstract: "Summarize command ledger and event sessions."
    )
  }

  @Option(name: .long, help: "Session ID to focus on. Defaults to last session.")
  var session: String?

  func run() throws {
    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let ledgerReader = CommandLedgerReader(repoRoot: repoRoot)
    let records = try ledgerReader.load()
    if records.isEmpty {
      print("no ledger entries yet")
      return
    }

    let sessions = ledgerReader.sessions(from: records)
    let targetSession = session ?? sessions.keys.sorted().last
    guard let sessionID = targetSession else {
      print("no sessions recorded")
      return
    }

    print("session: \(sessionID)")
    if let sessionRecords = sessions[sessionID] {
      for record in sessionRecords {
        let agent = record.meta.agent ?? "unknown"
        let command = record.meta.command ?? record.kind
        let stamp = ISO8601DateFormatter().string(from: record.ts)
        print("  [\(stamp)] \(command) (agent: \(agent)) -> kind=\(record.kind)")
      }
    }

    let eventReader = CommandEventReader(repoRoot: repoRoot)
    let events = try eventReader.listEvents(sessionID: sessionID)
    if !events.isEmpty {
      print("events:")
      for event in events {
        let stamp = ISO8601DateFormatter().string(from: event.timestamp)
        let payload = event.payload.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        print("  [\(stamp)] \(event.kind.rawValue) \(payload)")
      }
    }
  }
}
