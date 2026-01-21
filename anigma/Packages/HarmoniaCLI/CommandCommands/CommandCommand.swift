//
//  CommandCommand.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import ArgumentParser
import Foundation
import PraxisCore

struct CommandCommand: ParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "cmd",
      abstract: "Work with file-backed Harmonia commands.",
      subcommands: [CommandShow.self, CommandRun.self, CommandAudit.self]
    )
  }
}

struct CommandList: ParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "list",
      abstract: "List available command specs."
    )
  }

  func run() throws {
    let catalog = CommandSpecCatalog()
    let specs = try catalog.loadSpecs()
    if specs.isEmpty {
      print("no command specs found")
      return
    }

    for spec in specs {
      let desc = spec.description ?? "no description"
      print("- \(spec.name) [\(spec.source.rawValue)] — \(desc)")
    }

    do {
      let writer = CommandReceiptWriter()
      _ = try writer.write(
        action: "list",
        commandSpec: nil,
        specsAvailable: specs.map { $0.name }
      )
    } catch {
      fputs("warning: failed to record command receipt: \(error)\n", stderr)
    }
  }
}

struct CommandShow: ParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "show",
      abstract: "Show the template and metadata for a command spec."
    )
  }

  @Argument(help: "Name of the command spec to show.")
  var name: String

  func run() throws {
    let catalog = CommandSpecCatalog()
    guard let spec = try catalog.spec(named: name) else {
      print("command spec '\(name)' not found")
      throw ExitCode.failure
    }
    print("name: \(spec.name)")
    if let description = spec.description {
      print("description: \(description)")
    }
    if let agent = spec.agentProfile {
      print("agent profile: \(agent)")
    }
    print("source: \(spec.source.rawValue)")
    if !spec.metadata.isEmpty {
      print("metadata:")
      for (key, value) in spec.metadata.sorted(by: { $0.key < $1.key }) {
        print("  \(key): \(value)")
      }
    }
    print("template:\n\(spec.template)")

    do {
      let writer = CommandReceiptWriter()
      _ = try writer.write(
        action: "show",
        commandSpec: spec.name,
        specsAvailable: [spec.name],
        metadata: spec.metadata
      )
    } catch {
      fputs("warning: failed to record command receipt: \(error)\n", stderr)
    }
  }
}

struct CommandRun: ParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "run",
      abstract: "Render and display a command template."
    )
  }

  @Argument(help: "Name of the command spec to run.")
  var name: String

  @Option(name: .long, help: "Agent profile to evaluate (overrides spec metadata).")
  var agent: String?

  @Flag(name: .long, help: "Confirm 'ask' permissions without prompting.")
  var confirm: Bool = false

  @Option(name: .long, help: "Session ID to attach this run to.")
  var session: String?

  @Flag(name: .long, help: "Force creation of a new session for this run.")
  var newSession: Bool = false

  @Option(
    name: .long, parsing: .unconditionalSingleValue,
    help: "KEY=VALUE substitutions applied to the template.")
  var arg: [String] = []

  func run() throws {
    let catalog = CommandSpecCatalog()
    guard let spec = try catalog.spec(named: name) else {
      print("command spec '\(name)' not found")
      throw ExitCode.failure
    }

    let context = parseArgs(arg)
    let renderer = CommandRenderer()
    let rendered = renderer.render(template: spec.template, context: context)
    print(rendered)

    let profileName = agent ?? spec.agentProfile ?? "plan"
    let profile: AgentProfile
    do {
      profile = try AgentProfileRegistry.shared.profile(named: profileName)
    } catch {
      print("unknown agent profile '\(profileName)'")
      throw ExitCode.failure
    }

    let decision = profile.permissionPolicy.evaluate(command: rendered)
    switch decision {
    case .deny:
      print("permission denied for rendered command under '\(profile.name)' profile.")
      throw ExitCode.failure
    case .ask:
      guard confirm else {
        print("permission requires --confirm for '\(profile.name)' profile.")
        throw ExitCode.failure
      }
    case .allow:
      break
    }

    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let sessionStore = SessionStore(repoRoot: repoRoot)
    let commandSession = try sessionStore.resolveSession(
      sessionID: session, forceNew: newSession, agentProfile: profile.name)
    try sessionStore.recordCommand(sessionID: commandSession.sessionID, commandName: spec.name)

    let eventBus = CommandEventBus.shared(repoRoot: repoRoot)
    Task {
      try? await eventBus.emit(
        CommandEvent(
          kind: .commandStarted, sessionID: commandSession.sessionID,
          payload: ["command": spec.name]))
    }
    Task {
      try? await eventBus.emit(
        CommandEvent(
          kind: .permissionDecision, sessionID: commandSession.sessionID,
          payload: ["decision": decision.rawValue, "agent": profile.name]))
    }

    do {
      let writer = CommandReceiptWriter(repoRoot: repoRoot)
      var metadata = context
      metadata["agent"] = profile.name
      metadata["permissionDecision"] = decision.rawValue
      metadata["sessionID"] = commandSession.sessionID
      let receiptPath = try writer.write(
        action: "run",
        commandSpec: spec.name,
        specsAvailable: [spec.name],
        metadata: metadata
      )

      do {
        let ledger = CommandLedger(repoRoot: repoRoot)
        try ledger.append(
          kind: "command",
          sessionID: commandSession.sessionID,
          agent: profile.name,
          command: spec.name,
          messageID: receiptPath,
          detail: metadata
        )
      } catch {
        fputs("warning: failed to append ledger entry: \(error)\n", stderr)
      }
    } catch {
      fputs("warning: failed to record command receipt: \(error)\n", stderr)
    }

    Task {
      try? await eventBus.emit(
        CommandEvent(
          kind: .commandCompleted, sessionID: commandSession.sessionID,
          payload: ["command": spec.name]))
    }
  }

  private func parseArgs(_ inputs: [String]) -> [String: String] {
    var context: [String: String] = [:]
    for entry in inputs {
      let parts = entry.split(separator: "=", maxSplits: 1)
      if parts.count == 2 {
        context[String(parts[0])] = String(parts[1])
      }
    }
    return context
  }
}
