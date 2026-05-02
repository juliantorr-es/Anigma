//
//  RepoIdentityGate.swift
//  PraxisModule
//
//  [Brief description of file purpose]
//

import Foundation

public struct RepoIdentityGateResult: Sendable, Codable {
    public let ok: Bool
    public let probe: GitProbe?
    public let failure: RepoIdentityGateFailure?
    public let message: String

    public init(ok: Bool, probe: GitProbe?, failure: RepoIdentityGateFailure?, message: String) {
        self.ok = ok
        self.probe = probe
        self.failure = failure
        self.message = message
    }
}

public struct RepoIdentityGate {
    private let prober: GitProbing

    public init(prober: GitProbing = ShellGitProber()) {
        self.prober = prober
    }

    public func evaluate(policy: RepoIdentityPolicy, cwd: URL) -> RepoIdentityGateResult {
        do {
            let probe = try prober.probe(cwd: cwd)

            if !isRepoRootAllowed(policy: policy, repoRoot: probe.repoRoot) {
                return .init(ok: false, probe: probe, failure: .repoRootNotAllowed, message: "Repo root not allowed: \(probe.repoRoot)")
            }

            if isWorktreeRejected(policy: policy, probe: probe) {
                return .init(ok: false, probe: probe, failure: .worktreePathRejected, message: "Worktree path rejected: \(probe.worktreePath)")
            }

            if policy.rejectDetachedHEAD && probe.isDetached {
                return .init(ok: false, probe: probe, failure: .detachedHEADRejected, message: "Detached HEAD rejected by policy.")
            }

            if !isBranchAllowed(policy: policy, branch: probe.branch) {
                return .init(ok: false, probe: probe, failure: .branchNotAllowed, message: "Branch not allowed by policy: \(probe.branch)")
            }

            if policy.requireCleanWorkingTree && !probe.isClean {
                return .init(ok: false, probe: probe, failure: .dirtyWorkingTreeRejected, message: "Working tree dirty and policy requires clean.")
            }

            if !isOriginAllowed(policy: policy, origin: probe.originURL) {
                return .init(ok: false, probe: probe, failure: .originURLRejected, message: "Origin URL rejected: \(probe.originURL ?? "nil")")
            }

            return .init(ok: true, probe: probe, failure: nil, message: "Repo identity gate passed.")
        } catch {
            return .init(ok: false, probe: nil, failure: .notAGitRepo, message: "Git probe failed: \(error.localizedDescription)")
        }
    }

    private func isRepoRootAllowed(policy: RepoIdentityPolicy, repoRoot: String) -> Bool {
        if policy.allowedRepoRoots.contains(repoRoot) { return true }
        if policy.allowIfRepoRootContains.contains(where: { repoRoot.contains($0) }) { return true }
        return false
    }

    private func isWorktreeRejected(policy: RepoIdentityPolicy, probe: GitProbe) -> Bool {
        let rel = relativePath(from: probe.repoRoot, to: probe.worktreePath) ?? probe.worktreePath
        for rejected in policy.rejectWorktreesUnderPaths {
            if rel.contains(rejected) || probe.worktreePath.contains(rejected) {
                return true
            }
        }
        return false
    }

    private func relativePath(from root: String, to path: String) -> String? {
        guard path.hasPrefix(root) else { return nil }
        var rest = path.dropFirst(root.count)
        if rest.first == "/" {
            rest = rest.dropFirst()
        }
        return String(rest)
    }

    private func isBranchAllowed(policy: RepoIdentityPolicy, branch: String) -> Bool {
        for rule in policy.allowedBranches {
            if rule.hasSuffix("/*") {
                let prefix = rule.dropLast(2)
                if branch.hasPrefix(prefix) { return true }
            } else if branch == rule {
                return true
            }
        }
        return false
    }

    private func isOriginAllowed(policy: RepoIdentityPolicy, origin: String?) -> Bool {
        if policy.requireOriginURLPrefix.isEmpty { return true }
        guard let origin = origin else { return false }
        return policy.requireOriginURLPrefix.contains { origin.hasPrefix($0) }
    }
}
