//
//  SessionStore.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct CommandSession: Codable, Sendable {
  public var sessionID: String
  public var createdAt: Date
  public var agentProfile: String?
  public var lastCommand: String?

  public init(sessionID: String, createdAt: Date = Date(), agentProfile: String? = nil, lastCommand: String? = nil) {
    self.sessionID = sessionID
    self.createdAt = createdAt
    self.agentProfile = agentProfile
    self.lastCommand = lastCommand
  }
}

public struct SessionStore: Sendable {
  public let repoRoot: URL
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)) {
    self.repoRoot = repoRoot
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
  }

  private var sessionsDir: URL {
    repoRoot.appendingPathComponent(".anigma", isDirectory: true)
      .appendingPathComponent("sessions", isDirectory: true)
  }

  private var lastSessionFile: URL {
    sessionsDir.appendingPathComponent("last-session", isDirectory: false)
  }

  public func createSession(agentProfile: String? = nil) throws -> CommandSession {
    try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    let session = CommandSession(sessionID: UUID().uuidString, agentProfile: agentProfile)
    try save(session)
    try setLastSessionID(session.sessionID)
    return session
  }

  public func load(sessionID: String) throws -> CommandSession {
    let fileURL = sessionsDir.appendingPathComponent("\(sessionID).json", isDirectory: false)
    let data = try Data(contentsOf: fileURL)
    return try decoder.decode(CommandSession.self, from: data)
  }

  public func recordCommand(sessionID: String, commandName: String) throws {
    var session = try load(sessionID: sessionID)
    session.lastCommand = commandName
    try save(session)
  }

  public func lastSessionID() -> String? {
    guard FileManager.default.fileExists(atPath: lastSessionFile.path) else { return nil }
    return (try? String(contentsOf: lastSessionFile).trimmingCharacters(in: .whitespacesAndNewlines))
  }

  public func setLastSessionID(_ id: String) throws {
    try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    try id.write(to: lastSessionFile, atomically: true, encoding: .utf8)
  }

  public func resolveSession(sessionID: String?, forceNew: Bool, agentProfile: String?) throws -> CommandSession {
    if forceNew {
      return try createSession(agentProfile: agentProfile)
    }

    if let provided = sessionID {
      let session = try load(sessionID: provided)
      try setLastSessionID(provided)
      return session
    }

    if let last = lastSessionID() {
      return try load(sessionID: last)
    }

    return try createSession(agentProfile: agentProfile)
  }

  private func save(_ session: CommandSession) throws {
    try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    let fileURL = sessionsDir.appendingPathComponent("\(session.sessionID).json", isDirectory: false)
    let data = try encoder.encode(session)
    try data.write(to: fileURL, options: Data.WritingOptions.atomic)
  }
}
