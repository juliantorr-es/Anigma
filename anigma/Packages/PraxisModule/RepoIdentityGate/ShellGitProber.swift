//
//  ShellGitProber.swift
//  PraxisModule
//
//  [Brief description of file purpose]
//

import Foundation

public struct ShellGitProber: GitProbing {
    public init() {}

    public func probe(cwd: URL) throws -> GitProbe {
        let repoRoot = try runGit(["rev-parse", "--show-toplevel"], cwd: cwd).trimmingCharacters(in: .whitespacesAndNewlines)
        let worktreePath = cwd.path

        let branchRaw = try runGit(["rev-parse", "--abbrev-ref", "HEAD"], cwd: cwd).trimmingCharacters(in: .whitespacesAndNewlines)
        let isDetached = (branchRaw == "HEAD")
        let branch = branchRaw

        let headSHA = try runGit(["rev-parse", "HEAD"], cwd: cwd).trimmingCharacters(in: .whitespacesAndNewlines)

        let porcelain = (try? runGit(["status", "--porcelain=v1"], cwd: cwd)) ?? ""
        let isClean = porcelain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let originURL = (try? runGit(["config", "--get", "remote.origin.url"], cwd: cwd))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }

        let worktreeList = (try? runGit(["worktree", "list", "--porcelain"], cwd: cwd)) ?? ""
        let worktrees = worktreeList
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("worktree ") {
                    return trimmed.replacingOccurrences(of: "worktree ", with: "")
                }
                return nil
            }

        return GitProbe(
            repoRoot: repoRoot,
            worktreePath: worktreePath,
            branch: branch,
            headSHA: headSHA,
            isDetached: isDetached,
            isClean: isClean,
            originURL: originURL,
            worktrees: worktrees
        )
    }

    private func runGit(_ args: [String], cwd: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = cwd

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let msg = String(data: errData, encoding: .utf8) ?? "git command failed"
            throw NSError(domain: "RepoIdentityGate.git", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return String(data: outData, encoding: .utf8) ?? ""
    }
}
