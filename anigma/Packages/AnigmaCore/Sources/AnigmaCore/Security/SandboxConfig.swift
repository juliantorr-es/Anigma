//
//  SandboxConfig.swift
//  AnigmaCore
//

import Foundation

/// Configuration for sandboxed process execution.
public struct SandboxConfig: Sendable, Codable {
    /// Working directory for the engine.
    public let workingDirectory: String

    /// Allowed filesystem paths (read-only).
    public let allowedReadPaths: [String]

    /// Allowed filesystem paths (read-write).
    public let allowedWritePaths: [String]

    /// Whether network access is allowed.
    public let allowNetwork: Bool

    /// Allowed network endpoints (if network is allowed).
    public let allowedEndpoints: [String]

    /// Environment variables to pass.
    public let environment: [String: String]

    /// Maximum memory in MB.
    public let maxMemoryMB: Int

    /// Maximum CPU time in seconds.
    public let maxCPUTimeSeconds: Int

    /// Whether to run as different user (if supported).
    public let runAsDifferentUser: Bool

    public init(
        workingDirectory: String,
        allowedReadPaths: [String] = [],
        allowedWritePaths: [String] = [],
        allowNetwork: Bool = false,
        allowedEndpoints: [String] = [],
        environment: [String: String] = [:],
        maxMemoryMB: Int = 1024,
        maxCPUTimeSeconds: Int = 300,
        runAsDifferentUser: Bool = false
    ) {
        self.workingDirectory = workingDirectory
        self.allowedReadPaths = allowedReadPaths
        self.allowedWritePaths = allowedWritePaths
        self.allowNetwork = allowNetwork
        self.allowedEndpoints = allowedEndpoints
        self.environment = environment
        self.maxMemoryMB = maxMemoryMB
        self.maxCPUTimeSeconds = maxCPUTimeSeconds
        self.runAsDifferentUser = runAsDifferentUser
    }

    /// Default sandbox for mutation engines.
    public static func mutationEngineSandbox(projectPath: String) -> SandboxConfig {
        let sourcesPath = URL(fileURLWithPath: projectPath).appendingPathComponent("Sources").path
        let testsPath = URL(fileURLWithPath: projectPath).appendingPathComponent("Tests").path

        return SandboxConfig(
            workingDirectory: projectPath,
            allowedReadPaths: [
                projectPath,
                sourcesPath,
                testsPath,
                "/usr/lib",      // System libraries
                "/usr/include"   // Headers
            ],
            allowedWritePaths: [
                sourcesPath,
                testsPath
            ],
            allowNetwork: false,
            environment: [
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "HOME": NSHomeDirectory(),
                "USER": NSUserName()
            ],
            maxMemoryMB: 2048,
            maxCPUTimeSeconds: 600
        )
    }

    /// Default sandbox for network engines.
    public static func networkEngineSandbox(projectPath: String) -> SandboxConfig {
        return SandboxConfig(
            workingDirectory: projectPath,
            allowedReadPaths: [projectPath],
            allowedWritePaths: [],  // Network engines shouldn't write files
            allowNetwork: true,
            allowedEndpoints: [
                "https://api.github.com",
                "https://huggingface.co",
                "https://raw.githubusercontent.com"
            ],
            environment: [
                "PATH": "/usr/bin:/bin",
                "HOME": NSHomeDirectory()
            ],
            maxMemoryMB: 1024,
            maxCPUTimeSeconds: 300
        )
    }

    /// Default sandbox for read-only analysis.
    public static func readOnlySandbox(projectPath: String) -> SandboxConfig {
        return SandboxConfig(
            workingDirectory: projectPath,
            allowedReadPaths: [projectPath],
            allowedWritePaths: [],  // No writing
            allowNetwork: false,
            environment: [
                "PATH": "/usr/bin:/bin",
                "HOME": NSHomeDirectory()
            ],
            maxMemoryMB: 512,
            maxCPUTimeSeconds: 180
        )
    }
}

/// Result of a process execution.
public struct ProcessResult: Sendable, Codable {
    public let exitCode: Int32
    public let output: String
    public let error: String
    public let duration: TimeInterval
    public let timedOut: Bool

    public var succeeded: Bool {
        exitCode == 0 && !timedOut
    }

    public init(
        exitCode: Int32,
        output: String,
        error: String,
        duration: TimeInterval,
        timedOut: Bool
    ) {
        self.exitCode = exitCode
        self.output = output
        self.error = error
        self.duration = duration
        self.timedOut = timedOut
    }
}
