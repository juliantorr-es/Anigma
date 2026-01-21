//
//  RepoIdentityGateTests.swift
//  PraxisCoreTests
//
//  Unit tests for PraxisCoreTests.
//

import XCTest
@testable import PraxisModule

final class RepoIdentityGateTests: XCTestCase {
    struct FakeProber: GitProbing {
        let probe: GitProbe
        func probe(cwd: URL) throws -> GitProbe {
            probe
        }
    }

    func testRejectsRejectedWorktree() {
        let policy = RepoIdentityPolicy(
            allowedRepoRoots: ["/repo"],
            allowedBranches: ["main"],
            rejectDetachedHEAD: true,
            requireCleanWorkingTree: true,
            rejectWorktreesUnderPaths: [".opencode/worktrees"],
            requireOriginURLPrefix: [],
            allowIfRepoRootContains: []
        )

        let probe = GitProbe(
            repoRoot: "/repo",
            worktreePath: "/repo/.opencode/worktrees/agent/foo",
            branch: "HEAD",
            headSHA: "abc",
            isDetached: true,
            isClean: true,
            originURL: "https://github.com/owner/anigma",
            worktrees: ["/repo", "/repo/.opencode/worktrees/agent/foo"]
        )

        let gate = RepoIdentityGate(prober: FakeProber(probe: probe))
        let result = gate.evaluate(policy: policy, cwd: URL(fileURLWithPath: "/repo"))

        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.failure, .worktreePathRejected)
    }

    func testPassesAllowedEnvironment() {
        let policy = RepoIdentityPolicy(
            allowedRepoRoots: ["/repo"],
            allowedBranches: ["main", "fix/*"],
            rejectDetachedHEAD: true,
            requireCleanWorkingTree: true,
            rejectWorktreesUnderPaths: [".opencode/worktrees"],
            requireOriginURLPrefix: ["https://github.com/"],
            allowIfRepoRootContains: []
        )

        let probe = GitProbe(
            repoRoot: "/repo",
            worktreePath: "/repo",
            branch: "main",
            headSHA: "abc",
            isDetached: false,
            isClean: true,
            originURL: "https://github.com/owner/anigma",
            worktrees: ["/repo"]
        )

        let gate = RepoIdentityGate(prober: FakeProber(probe: probe))
        let result = gate.evaluate(policy: policy, cwd: URL(fileURLWithPath: "/repo"))

        XCTAssertTrue(result.ok)
        XCTAssertNil(result.failure)
    }
}
