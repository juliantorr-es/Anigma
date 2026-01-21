//
//  CommandEventReader.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct CommandEventReader {
  public let repoRoot: URL

  public init(repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)) {
    self.repoRoot = repoRoot
  }

  public func listEvents(sessionID: String) throws -> [CommandEvent] {
    let sessionDir = repoRoot
      .appendingPathComponent("Artifacts", isDirectory: true)
      .appendingPathComponent("praxis", isDirectory: true)
      .appendingPathComponent("events", isDirectory: true)
      .appendingPathComponent(sessionID, isDirectory: true)

    guard FileManager.default.fileExists(atPath: sessionDir.path) else {
      return []
    }

    let files = try FileManager.default.contentsOfDirectory(at: sessionDir, includingPropertiesForKeys: nil)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    return try files.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { url in
      let data = try Data(contentsOf: url)
      return try decoder.decode(CommandEvent.self, from: data)
    }
  }
}
