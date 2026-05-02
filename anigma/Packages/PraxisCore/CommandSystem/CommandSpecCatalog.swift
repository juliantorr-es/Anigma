//
//  CommandSpecCatalog.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct CommandSpecCatalog: Sendable {
  public let repoRoot: URL

  public init(repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)) {
    self.repoRoot = repoRoot
  }

  public func loadSpecs() throws -> [CommandSpec] {
    var specsByName: [String: CommandSpec] = [:]

    let global = try loadMarkdownCommands(from: globalCommandsDirectory, source: .global)
    for spec in global {
      specsByName[spec.name] = spec
    }

    let config = try loadConfigDefinedCommands()
    for spec in config {
      specsByName[spec.name] = spec
    }

    let project = try loadMarkdownCommands(from: projectCommandsDirectory, source: .project)
    for spec in project {
      specsByName[spec.name] = spec
    }

    return specsByName.values.sorted { $0.name < $1.name }
  }

  public func spec(named name: String) throws -> CommandSpec? {
    let specs = try loadSpecs()
    return specs.first { $0.name == name }
  }

  private var projectCommandsDirectory: URL {
    repoRoot.appendingPathComponent(".anigma", isDirectory: true)
      .appendingPathComponent("command", isDirectory: true)
  }

  private var globalCommandsDirectory: URL? {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config", isDirectory: true)
      .appendingPathComponent("anigma", isDirectory: true)
      .appendingPathComponent("command", isDirectory: true)
  }

  private var configSourceURL: URL {
    repoRoot.appendingPathComponent(".anigma", isDirectory: true)
      .appendingPathComponent("anigma.jsonc", isDirectory: false)
  }

  private func loadMarkdownCommands(from directory: URL?, source: CommandSpecSource) throws -> [CommandSpec] {
    guard let directory = directory else {
      return []
    }
    guard FileManager.default.fileExists(atPath: directory.path) else {
      return []
    }

    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
      return []
    }

    var specs: [CommandSpec] = []
    for case let fileURL as URL in enumerator {
      guard fileURL.pathExtension.lowercased() == "md" else { continue }
      let spec = try parseMarkdownCommand(at: fileURL, source: source)
      specs.append(spec)
    }
    return specs
  }

  private func loadConfigDefinedCommands() throws -> [CommandSpec] {
    guard FileManager.default.fileExists(atPath: configSourceURL.path) else {
      return []
    }
    let raw = try String(contentsOf: configSourceURL)
    let cleaned = stripJSONCComments(raw)

    struct ConfigFile: Decodable {
      let commands: [String: ConfigDefinition]
    }

    struct ConfigDefinition: Decodable {
      let description: String?
      let agentProfile: String?
      let template: String
      let metadata: [String: String]?
    }

    let data = Data(cleaned.utf8)
    let decoder = JSONDecoder()
    let config = try decoder.decode(ConfigFile.self, from: data)
    return config.commands.map { key, entry in
      CommandSpec(
        name: key,
        description: entry.description,
        agentProfile: entry.agentProfile,
        template: entry.template,
        source: .config,
        metadata: entry.metadata ?? [:],
        path: configSourceURL.path
      )
    }
  }

  private func parseMarkdownCommand(at url: URL, source: CommandSpecSource) throws -> CommandSpec {
    let raw = try String(contentsOf: url)
    let (meta, body) = splitFrontMatter(into: raw)
    let name = meta["name"] ?? url.deletingPathExtension().lastPathComponent
    return CommandSpec(
      name: name,
      description: meta["description"],
      agentProfile: meta["agent"] ?? meta["agentProfile"],
      template: body.trimmingCharacters(in: .whitespacesAndNewlines),
      source: source,
      metadata: meta,
      path: url.path
    )
  }

  private func splitFrontMatter(into input: String) -> ([String: String], String) {
    let lines = input.components(separatedBy: .newlines)
    guard let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
          first == "---" else {
      return ([:], input)
    }

    var metaLines: [String] = []
    var index = 1
    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed == "---" {
        index += 1
        break
      }
      metaLines.append(line)
      index += 1
    }

    let body = Array(lines[index...]).joined(separator: "\n")
    return (parseMeta(lines: metaLines), body)
  }

  private func parseMeta(lines: [String]) -> [String: String] {
    var metadata: [String: String] = [:]
    for raw in lines {
      let trimmed = raw.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { continue }
      let parts = trimmed.split(separator: ":", maxSplits: 1)
      guard parts.count == 2 else { continue }
      let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
      let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
      metadata[key] = value
    }
    return metadata
  }

  private func stripJSONCComments(_ input: String) -> String {
    let lines = input.components(separatedBy: .newlines)
    let stripped = lines.map { line -> String in
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("//") {
        return ""
      }
      return line
    }
    return stripped.joined(separator: "\n")
  }
}
