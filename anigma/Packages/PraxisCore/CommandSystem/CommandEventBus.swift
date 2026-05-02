//
//  CommandEventBus.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public enum CommandEventKind: String, Codable, Sendable {
  case commandStarted
  case commandCompleted
  case permissionDecision
}

public struct CommandEvent: Codable, Sendable {
  public let kind: CommandEventKind
  public let sessionID: String
  public let timestamp: Date
  public let payload: [String: String]

  public init(kind: CommandEventKind, sessionID: String, payload: [String: String] = [:], timestamp: Date = Date()) {
    self.kind = kind
    self.sessionID = sessionID
    self.payload = payload
    self.timestamp = timestamp
  }
}

public actor CommandEventBus {
  public static func shared(repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)) -> CommandEventBus {
    CommandEventBus(repoRoot: repoRoot)
  }

  private let repoRoot: URL
  private let encoder = JSONEncoder()

  public init(repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)) {
    self.repoRoot = repoRoot
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
  }

  public func emit(_ event: CommandEvent) throws {
    let eventsDir = repoRoot
      .appendingPathComponent("Artifacts", isDirectory: true)
      .appendingPathComponent("praxis", isDirectory: true)
      .appendingPathComponent("events", isDirectory: true)
      .appendingPathComponent(event.sessionID, isDirectory: true)

    try FileManager.default.createDirectory(at: eventsDir, withIntermediateDirectories: true)
    let ts = ISO8601DateFormatter().string(from: event.timestamp).replacingOccurrences(of: ":", with: "")
    let fileURL = eventsDir.appendingPathComponent("\(ts)-\(event.kind.rawValue).json", isDirectory: false)
    let data = try encoder.encode(event)
    try data.write(to: fileURL, options: Data.WritingOptions.atomic)
  }
}
