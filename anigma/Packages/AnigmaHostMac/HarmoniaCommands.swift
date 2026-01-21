//
//  HarmoniaCommands.swift
//  AnigmaHostMac
//
//  Strongly-typed wrappers for Harmonia CLI commands.
//

import Foundation

// MARK: - Daemon Commands

extension HarmoniaClient {

    /// Daemon status response
    public struct DaemonStatusResponse: Codable {
        public let running: Bool
        public let pid: Int?
        public let uptime: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case running, pid, uptime
        }
    }

    /// Start the anigmad daemon.
    public func daemonStart(foreground: Bool = false) async throws {
        var args = ["daemon", "start"]
        if foreground {
            args.append("--foreground")
        }
        let _: EmptyResponse = try await execute(args)
    }

    /// Stop the anigmad daemon.
    public func daemonStop() async throws {
        let _: EmptyResponse = try await execute(["daemon", "stop"])
    }

    /// Get daemon status.
    public func daemonStatus() async throws -> DaemonStatusResponse {
        return try await execute(["daemon", "status", "--format", "json"])
    }
}

// MARK: - Vault Commands

extension HarmoniaClient {

    /// Vault status response
    public struct VaultStatusResponse: Codable {
        public let totalArtifacts: Int
        public let totalSizeBytes: Int64
        public let lastCompaction: Date?
        public let health: String

        enum CodingKeys: String, CodingKey {
            case totalArtifacts, totalSizeBytes, lastCompaction, health
        }
    }

    /// Get vault status.
    public func vaultStatus() async throws -> VaultStatusResponse {
        return try await execute(["vault", "status", "--format", "json"])
    }

    /// Verify vault integrity.
    public func vaultVerify() async throws -> VaultVerificationResponse {
        return try await execute(["vault", "verify", "--format", "json"])
    }

    /// Run vault garbage collection.
    public func vaultGC(dryRun: Bool = false) async throws -> VaultGCResponse {
        var args = ["vault", "gc", "--format", "json"]
        if dryRun {
            args.append("--dry-run")
        }
        return try await execute(args)
    }
}

// MARK: - Pipeline Commands

extension HarmoniaClient {

    /// Pipeline status response
    public struct PipelineStatusResponse: Codable {
        public let workspace: String
        public let pendingJobs: Int
        public let runningJobs: Int
        public let completedJobs: Int
        public let failedJobs: Int

        enum CodingKeys: String, CodingKey {
            case workspace, pendingJobs, runningJobs, completedJobs, failedJobs
        }
    }

    /// Get pipeline status.
    public func pipelineStatus(workspace: String? = nil) async throws -> PipelineStatusResponse {
        var args = ["status", "--format", "json"]
        if let ws = workspace {
            args.append(contentsOf: ["--workspace", ws])
        }
        return try await execute(args)
    }
}

// MARK: - Tech Debt Commands

extension HarmoniaClient {

    /// Tech debt audit response
    public struct TechDebtAuditResponse: Codable {
        public let totalIssues: Int
        public let criticalIssues: Int
        public let highIssues: Int
        public let mediumIssues: Int
        public let lowIssues: Int
        public let categories: [String: Int]

        enum CodingKeys: String, CodingKey {
            case totalIssues, criticalIssues, highIssues, mediumIssues, lowIssues, categories
        }
    }

    /// Run tech debt audit.
    public func techDebtAudit(path: String) async throws -> TechDebtAuditResponse {
        return try await execute(["techdebt", "audit", path, "--format", "json"])
    }
}

// MARK: - Search Commands

extension HarmoniaClient {

    /// Search result
    public struct SearchResult: Codable {
        public let id: String
        public let type: String
        public let timestamp: Date
        public let relevance: Double
        public let preview: String

        enum CodingKeys: String, CodingKey {
            case id, type, timestamp, relevance, preview
        }
    }

    /// Search response
    public struct SearchResponse: Codable {
        public let query: String
        public let results: [SearchResult]
        public let totalMatches: Int

        enum CodingKeys: String, CodingKey {
            case query, results, totalMatches
        }
    }

    /// Search the ledger.
    public func search(query: String, limit: Int = 10) async throws -> SearchResponse {
        return try await execute(["search", query, "--limit", "\(limit)", "--format", "json"])
    }
}

// MARK: - Tool Commands

extension HarmoniaClient {

    /// Tool status response
    public struct ToolStatusResponse: Codable {
        public let toolName: String
        public let trusted: Bool
        public let verified: Bool
        public let lastUsed: Date?
        public let usageCount: Int

        enum CodingKeys: String, CodingKey {
            case toolName, trusted, verified, lastUsed, usageCount
        }
    }

    /// Get tool status.
    public func toolStatus(toolName: String) async throws -> ToolStatusResponse {
        return try await execute(["tool", "status", toolName, "--format", "json"])
    }

    /// Trust a tool.
    public func toolTrustAdd(toolName: String, binaryPath: String) async throws {
        let _: EmptyResponse = try await execute([
            "tool", "trust", "add",
            "--name", toolName,
            "--path", binaryPath,
            "--format", "json"
        ])
    }

    /// Remove tool trust.
    public func toolTrustRemove(toolName: String) async throws {
        let _: EmptyResponse = try await execute([
            "tool", "trust", "remove", toolName, "--format", "json"
        ])
    }

    /// List trusted tools.
    public func toolTrustList() async throws -> [ToolStatusResponse] {
        struct ListResponse: Codable {
            let tools: [ToolStatusResponse]
        }
        let response: ListResponse = try await execute(["tool", "trust", "list", "--format", "json"])
        return response.tools
    }
}

// MARK: - Stack Commands

extension HarmoniaClient {

    /// Stack status response
    public struct StackStatusResponse: Codable {
        public let branches: [String]
        public let currentBranch: String
        public let hasUncommittedChanges: Bool

        enum CodingKeys: String, CodingKey {
            case branches, currentBranch, hasUncommittedChanges
        }
    }

    /// Get stack status.
    public func stackStatus() async throws -> StackStatusResponse {
        return try await execute(["stack", "status", "--format", "json"])
    }

    /// Create a new stack branch.
    public func stackCreate(name: String, baseBranch: String? = nil) async throws {
        var args = ["stack", "create", name, "--format", "json"]
        if let base = baseBranch {
            args.append(contentsOf: ["--base", base])
        }
        let _: EmptyResponse = try await execute(args)
    }

    /// Sync stack with remote.
    public func stackSync() async throws {
        let _: EmptyResponse = try await execute(["stack", "sync", "--format", "json"])
    }
}

// MARK: - Maintenance Commands

extension HarmoniaClient {

    /// Run database maintenance.
    public func maintain(vacuum: Bool = false, analyze: Bool = true) async throws {
        var args = ["maintain", "--format", "json"]
        if vacuum {
            args.append("--vacuum")
        }
        if analyze {
            args.append("--analyze")
        }
        let _: EmptyResponse = try await execute(args)
    }

    /// Run garbage collection.
    public func gc(retentionDays: Int? = nil) async throws -> GCResponse {
        var args = ["gc", "--format", "json"]
        if let days = retentionDays {
            args.append(contentsOf: ["--retention-days", "\(days)"])
        }
        return try await execute(args)
    }
}

// MARK: - Response Types

extension HarmoniaClient {

    public struct EmptyResponse: Codable {
        public init() {}
    }

    public struct VaultVerificationResponse: Codable {
        public let valid: Bool
        public let errors: [String]
        public let warnings: [String]

        enum CodingKeys: String, CodingKey {
            case valid, errors, warnings
        }
    }

    public struct VaultGCResponse: Codable {
        public let removedArtifacts: Int
        public let freedBytes: Int64
        public let dryRun: Bool

        enum CodingKeys: String, CodingKey {
            case removedArtifacts, freedBytes, dryRun
        }
    }

    public struct GCResponse: Codable {
        public let removedEvents: Int
        public let freedBytes: Int64
        public let retentionDays: Int

        enum CodingKeys: String, CodingKey {
            case removedEvents, freedBytes, retentionDays
        }
    }
}
