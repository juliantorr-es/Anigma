//
//  SessionCommand.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import ArgumentParser
import Foundation
import PraxisCore

struct SessionCommand: ParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "session",
      abstract: "Manage Harmonia command sessions.",
      subcommands: [SessionStart.self, SessionShow.self]
    )
  }
}

struct SessionStart: ParsableCommand {
  static var configuration: CommandConfiguration { CommandConfiguration(commandName: "start") }

  @Option(name: .long, help: "Agent profile to associate with the session.")
  var agent: String?

  func run() throws {
    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let sessionStore = SessionStore(repoRoot: repoRoot)
    let session = try sessionStore.createSession(agentProfile: agent)
    print("session started: \(session.sessionID)")
  }
}

struct SessionShow: ParsableCommand {
  static var configuration: CommandConfiguration { CommandConfiguration(commandName: "show") }

  @Option(name: .long, help: "Session ID to show. Defaults to last session.")
  var id: String?

  func run() throws {
    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let sessionStore = SessionStore(repoRoot: repoRoot)
    let sessionID = id ?? sessionStore.lastSessionID()
    guard let sessionID else {
      print("no session available")
      return
    }
    let session = try sessionStore.load(sessionID: sessionID)
    print("session \(session.sessionID)")
    print("  created: \(session.createdAt)")
    if let agent = session.agentProfile {
      print("  agent: \(agent)")
    }
    if let last = session.lastCommand {
      print("  last command: \(last)")
    }
  }
}
