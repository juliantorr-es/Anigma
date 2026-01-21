//
//  Main.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import AnigmaCore  // Import AnigmaCore for pipeline types
import ArgumentParser
import Foundation

// MARK: - Output Structures (Keep existing)

public enum OutputFormat: String, CaseIterable, ExpressibleByArgument, Codable {
  case text
  case json
}

public struct OutputOptions: ParsableArguments {
  @Option(name: .long, help: "Output format (text|json).")
  var format: OutputFormat = .json

  public init() {}
}

// Note: OutputEnvelope references 'GovernanceTrace', 'Create', 'List', 'Run', 'SelfHost' which are not defined in this file.
// Assuming these types are defined elsewhere and accessible, or will be replaced by actual subcommand definitions.
// For now, retaining for compatibility with existing structure if it compiles.
struct OutputEnvelope<P: Encodable>: Encodable {
  let status: String
  let timestamp: String
  let command: String
  let payload: P
  // let governanceTrace: GovernanceTrace? // Uncomment if GovernanceTrace is defined
  let contractVersion: Int
  let dbPath: String?
  let traceRecordingEnabled: Bool?
  let factoryType: String?

  enum CodingKeys: String, CodingKey {
    case status, timestamp, command, payload  // , governanceTrace
    case contractVersion, dbPath, traceRecordingEnabled, factoryType
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(status, forKey: .status)
    try container.encode(timestamp, forKey: .timestamp)
    try container.encode(command, forKey: .command)
    try container.encode(payload, forKey: .payload)
    // try container.encodeIfPresent(governanceTrace, forKey: .governanceTrace)
    try container.encode(contractVersion, forKey: .contractVersion)
    try container.encodeIfPresent(dbPath, forKey: .dbPath)

    if let enabled = traceRecordingEnabled {
      try container.encode(enabled, forKey: .traceRecordingEnabled)
    } else {
      try container.encodeNil(forKey: .traceRecordingEnabled)
    }

    try container.encodeIfPresent(factoryType, forKey: .factoryType)
  }
}

// MARK: - Main CLI Structure (ArgumentParser standard)

@main
struct HarmoniaCLI: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "harmonia",
      abstract: "A command-line interface for the Anigma ecosystem.",
      version: "0.1.0",  // Placeholder version
      subcommands: [
        PipelineStatusCommand.self,
        PraxisCommand.self,
        RepoIdentityCommand.self,
        StackCommand.self,
        AnigmaCommand.self,
        CommandCommand.self,
        SessionCommand.self,
        Swift6.self,
        Maintain.self,
        GC.self,
        Segment.self,
        Search.self,
        ReceiptMigrationCommand.self,
        ToolCommand.self,
        VaultCommand.self,
        TechDebt.self,
        DaemonCommand.self,
        Refactor.self
      ],
      helpNames: [.long, .customShort("h")]
    )
  }

  // A main command for HarmoniaCLI might not have a run() method if it only dispatches to subcommands.
  // If it needs a run() method, it usually prints help or a default action.
  // func run() throws { /* Optionally print help or do a default action */ }
}

// Removed custom CommandParser and handleX functions as ArgumentParser handles dispatch.
// If Create, List, Run, SelfHost were intended as subcommands, they need to be defined
// as `struct Create: ParsableCommand { ... }` and added to `subcommands` above.
// The OutputEnvelope might need adjustment if GovernanceTrace, etc. are not universally available.
