//
//  RepoIdentityGate.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct RepoIdentityConfig: Codable, Sendable {
    public var schemaVersion: Int
    public var canonicalRepoRoot: String
    public var allowedWorktreeRoots: [String]
    public var forbiddenPathSubstrings: [String]
    public var requireSymbolicBranchForMutations: Bool

    public init(
        schemaVersion: Int = 1,
        canonicalRepoRoot: String,
        allowedWorktreeRoots: [String],
        forbiddenPathSubstrings: [String] = ["/.opencode/", "/.opencode/.tmp/", "/.opencode/worktrees/"],
        requireSymbolicBranchForMutations: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.canonicalRepoRoot = canonicalRepoRoot
        self.allowedWorktreeRoots = allowedWorktreeRoots
        self.forbiddenPathSubstrings = forbiddenPathSubstrings
        self.requireSymbolicBranchForMutations = requireSymbolicBranchForMutations
    }
}

public struct RepoIdentityGateResult: Codable, Sendable {
    public enum Verdict: String, Codable, Sendable { case pass, block }
    public var verdict: Verdict
    public var repoRoot: String
    public var worktreeRoot: String
    public var branchName: String?
    public var headSHA: String?
    public var reasons: [String]

    public init(verdict: Verdict, repoRoot: String, worktreeRoot: String, branchName: String?, headSHA: String?, reasons: [String]) {
        self.verdict = verdict
        self.repoRoot = repoRoot
        self.worktreeRoot = worktreeRoot
        self.branchName = branchName
        self.headSHA = headSHA
        self.reasons = reasons
    }
}

public enum RepoIdentityGateError: Error, CustomStringConvertible, Sendable {
    case blocked(RepoIdentityGateResult)
    case notAGitRepo(String)

    public var description: String {
        switch self {
        case .blocked(let r):
            return "RepoIdentityGate blocked: \(r.reasons.joined(separator: "; "))"
        case .notAGitRepo(let msg):
            return "RepoIdentityGate not a git repo: \(msg)"
        }
    }
}

public struct RepoIdentityGate: Sendable {
    public enum Mode: Sendable {
        case readOnly
        case mutation
    }

    public init() {}

    public func loadOrCreateDefaultConfig(repoRoot: URL) throws -> RepoIdentityConfig {
        let anigmaDir = repoRoot.appendingPathComponent(".anigma", isDirectory: true)
        let configURL = anigmaDir.appendingPathComponent("repo-identity.json", isDirectory: false)
        if FileManager.default.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(RepoIdentityConfig.self, from: data)
        }

        try FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)
        let cfg = RepoIdentityConfig(
            canonicalRepoRoot: repoRoot.standardizedFileURL.path,
            allowedWorktreeRoots: [repoRoot.standardizedFileURL.path]
        )
        try writeJSON(cfg, to: configURL)
        return cfg
    }

    public func evaluate(
        mode: Mode,
        cwd: URL,
        git: GitRunner
    ) throws -> RepoIdentityGateResult {
        let repoRoot = try git.repoRoot(cwd: cwd)
        let worktreeRoot = cwd.standardizedFileURL.path
        let cfg = try loadOrCreateDefaultConfig(repoRoot: repoRoot)

        var reasons: [String] = []

        for bad in cfg.forbiddenPathSubstrings where worktreeRoot.lowercased().contains(bad.lowercased()) {
            reasons.append("worktree path contains forbidden segment: \(bad)")
        }

        let allowed = cfg.allowedWorktreeRoots.contains { allowedRoot in
            let a = allowedRoot.standardizedPathLowercased
            let w = worktreeRoot.standardizedPathLowercased
            return w == a || w.hasPrefix(a + "/")
        }
        if !allowed {
            reasons.append("worktree root is not allow-listed by .anigma/repo-identity.json")
        }

        let branch = try? git.currentBranchName(cwd: cwd)
        let head = try? git.headSHA(cwd: cwd)

        if mode == .mutation, cfg.requireSymbolicBranchForMutations {
            if branch == nil || branch?.isEmpty == true {
                reasons.append("detached HEAD is not allowed for mutation operations")
            }
        }

        let result = RepoIdentityGateResult(
            verdict: reasons.isEmpty ? .pass : .block,
            repoRoot: repoRoot.standardizedFileURL.path,
            worktreeRoot: worktreeRoot,
            branchName: branch,
            headSHA: head,
            reasons: reasons
        )

        if result.verdict == .block {
            throw RepoIdentityGateError.blocked(result)
        }

        return result
    }
}

private extension String {
    var standardizedPathLowercased: String {
        (self as NSString).standardizingPath.lowercased()
    }
}

private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try enc.encode(value)
    try data.write(to: url, options: [.atomic])
}
