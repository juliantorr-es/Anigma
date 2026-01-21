//
//  CLIGitProvider.swift
//  PlatformCore
//
//  [Brief description of file purpose]
//

import Foundation
import CapabilityCore

public final class CLIGitProvider: SidecarCapabilityProvider, GitCapability {
    public let providerId: String = "anigma.provider.git.cli"
    public let executablePath: String

    public var supportedCapabilities: [String] {
        [CapabilityIds.git]
    }

    public init(gitPath: String = "/usr/bin/git") {
        self.executablePath = gitPath
    }

    public func clone(url: URL, to localPath: URL) async throws {
        _ = try await execute(arguments: ["clone", url.absoluteString, localPath.path], input: nil)
    }

    public func fetch(repoPath: URL) async throws {
        _ = try await execute(arguments: ["-C", repoPath.path, "fetch"], input: nil)
    }

    public func status(repoPath: URL) async throws -> String {
        let output = try await execute(arguments: ["-C", repoPath.path, "status", "--porcelain"], input: nil)
        return String(data: output, encoding: .utf8) ?? ""
    }

    public func commit(repoPath: URL, message: String) async throws -> String {
        _ = try await execute(arguments: ["-C", repoPath.path, "add", "."], input: nil)
        let output = try await execute(arguments: ["-C", repoPath.path, "commit", "-m", message], input: nil)
        return String(data: output, encoding: .utf8) ?? ""
    }

    public func push(repoPath: URL) async throws {
        _ = try await execute(arguments: ["-C", repoPath.path, "push"], input: nil)
    }
}
