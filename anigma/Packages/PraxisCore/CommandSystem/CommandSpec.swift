//
//  CommandSpec.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public enum CommandSpecSource: String, Codable, Sendable {
  case project
  case global
  case config
}

public struct CommandSpec: Codable, Sendable {
  public let name: String
  public let description: String?
  public let agentProfile: String?
  public let template: String
  public let source: CommandSpecSource
  public let metadata: [String: String]
  public let path: String?

  public init(
    name: String,
    description: String?,
    agentProfile: String?,
    template: String,
    source: CommandSpecSource,
    metadata: [String: String] = [:],
    path: String? = nil
  ) {
    self.name = name
    self.description = description
    self.agentProfile = agentProfile
    self.template = template
    self.source = source
    self.metadata = metadata
    self.path = path
  }
}
