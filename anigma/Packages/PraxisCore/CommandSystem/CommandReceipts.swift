//
//  CommandReceipts.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct CommandExecutionReceipt: Codable, Sendable {
  public let action: String
  public let commandSpec: String?
  public let specsAvailable: [String]
  public let timestamp: Date
  public let metadata: [String: String]
  public let repoRoot: String

  public init(
    action: String,
    commandSpec: String?,
    specsAvailable: [String],
    metadata: [String: String],
    repoRoot: String,
    timestamp: Date = Date()
  ) {
    self.action = action
    self.commandSpec = commandSpec
    self.specsAvailable = specsAvailable
    self.timestamp = timestamp
    self.metadata = metadata
    self.repoRoot = repoRoot
  }
}

public struct CommandReceiptWriter: Sendable {
  private let repoRoot: URL

  public init(repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)) {
    self.repoRoot = repoRoot
  }

  public func write(action: String, commandSpec: String?, specsAvailable: [String], metadata: [String: String] = [:]) throws -> String {
    let receipt = CommandExecutionReceipt(
      action: action,
      commandSpec: commandSpec,
      specsAvailable: specsAvailable,
      metadata: metadata,
      repoRoot: repoRoot.path
    )

    let dir = repoRoot
      .appendingPathComponent("Artifacts", isDirectory: true)
      .appendingPathComponent("praxis", isDirectory: true)
      .appendingPathComponent("command-receipts", isDirectory: true)

    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(receipt)

    let timestamp = ISO8601DateFormatter().string(from: receipt.timestamp).replacingOccurrences(of: ":", with: "")
    let safeAction = action.replacingOccurrences(of: " ", with: "-")
    let fileName = "\(safeAction)-\(timestamp)-\(UUID().uuidString.prefix(6)).json"
    let fileURL = dir.appendingPathComponent(fileName, isDirectory: false)

    try data.write(to: fileURL, options: Data.WritingOptions.atomic)
    return fileURL.path
  }
}
