//
//  AgentProfile.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public enum PermissionDecision: String, Codable, Sendable {
  case allow
  case ask
  case deny
}

public struct PermissionPolicy: Sendable {
  public let denyTokens: [String]
  public let askTokens: [String]

  public init(denyTokens: [String] = [], askTokens: [String] = []) {
    self.denyTokens = denyTokens
    self.askTokens = askTokens
  }

  public func evaluate(command: String) -> PermissionDecision {
    let normalized = command.lowercased()
    if denyTokens.contains(where: normalized.contains) {
      return .deny
    }
    if askTokens.contains(where: normalized.contains) {
      return .ask
    }
    return .allow
  }
}

public struct AgentProfile: Sendable {
  public let name: String
  public let description: String
  public let permissionPolicy: PermissionPolicy

  public init(name: String, description: String, permissionPolicy: PermissionPolicy) {
    self.name = name
    self.description = description
    self.permissionPolicy = permissionPolicy
  }
}

public enum AgentProfileRegistryError: Error {
  case unknownProfile(String)
}

public struct AgentProfileRegistry: Sendable {
  private let profiles: [String: AgentProfile]

  public init(profiles: [String: AgentProfile] = Self.defaultProfiles) {
    self.profiles = profiles
  }

  public func profile(named name: String) throws -> AgentProfile {
    guard let profile = profiles[name] else {
      throw AgentProfileRegistryError.unknownProfile(name)
    }
    return profile
  }

  public static var shared: AgentProfileRegistry {
    AgentProfileRegistry()
  }

  public static var defaultProfiles: [String: AgentProfile] {
    [
      "plan": AgentProfile(
        name: "plan",
        description: "Read-only planning agent.",
        permissionPolicy: PermissionPolicy(
          denyTokens: ["rm ", "mv ", "sed ", "apply-patch"],
          askTokens: ["swift build", "xcodebuild", "git commit", "bash"]
        )
      ),
      "build": AgentProfile(
        name: "build",
        description: "Regular build agent with editing allowed.",
        permissionPolicy: PermissionPolicy(
          denyTokens: ["rm -rf /", "sudo"]
        )
      )
    ]
  }
}
