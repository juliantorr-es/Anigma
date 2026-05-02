//
//  GitRunner.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation
import CryptoKit
import AnigmaPrimitives

public struct GitOpArtifactRefs: Codable, Sendable {
    public var stdoutPath: String?
    public var stderrPath: String?
}

public struct GitOpResult: Codable, Sendable {
    public var argv: [String]
    public var cwd: String
    public var exitCode: Int32
    public var durationMS: Int
    public var artifacts: GitOpArtifactRefs
}

public enum GitRunnerError: Error, CustomStringConvertible, Sendable {
    case failed(command: String, exitCode: Int32, stderr: String?)

    public var description: String {
        switch self {
        case .failed(let command, let code, let stderr):
            if let stderr, !stderr.isEmpty { return "git failed (\(code)) for: \(command) | \(stderr)" }
            return "git failed (\(code)) for: \(command)"
        }
    }
}

public struct GitRunner: Sendable {
    public let repoRoot: URL

    public init(repoRoot: URL) {
        self.repoRoot = repoRoot
    }

    public func repoRoot(cwd: URL) throws -> URL {
        let out = try runCaptureStdout(["rev-parse", "--show-toplevel"], cwd: cwd)
        return URL(fileURLWithPath: out.trimmingCharacters(in: .whitespacesAndNewlines), isDirectory: true)
    }

    public func headSHA(cwd: URL) throws -> String {
        try runCaptureStdout(["rev-parse", "HEAD"], cwd: cwd).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func currentBranchName(cwd: URL) throws -> String {
        let out = try runCaptureStdout(["symbolic-ref", "--quiet", "--short", "HEAD"], cwd: cwd)
        let v = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty { throw GitRunnerError.failed(command: "symbolic-ref", exitCode: 1, stderr: "detached") }
        return v
    }

    public func isDirty(cwd: URL) throws -> Bool {
        let out = try runCaptureStdout(["status", "--porcelain"], cwd: cwd)
        return !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func branchExists(_ name: String, cwd: URL) throws -> Bool {
        do {
            _ = try runCaptureStdout(["show-ref", "--verify", "--quiet", "refs/heads/\(name)"], cwd: cwd)
            return true
        } catch {
            return false
        }
    }

    public func fetch(remote: String, cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        try run(["fetch", remote, "--prune"], cwd: cwd, artifacts: artifacts)
    }

    public func checkout(_ ref: String, cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        try run(["checkout", ref], cwd: cwd, artifacts: artifacts)
    }

    public func createBranch(_ name: String, from: String, cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        try run(["branch", name, from], cwd: cwd, artifacts: artifacts)
    }

    public func checkoutNewBranch(_ name: String, from: String, cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        try run(["checkout", "-b", name, from], cwd: cwd, artifacts: artifacts)
    }

    public func rebase(onto parent: String, cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        try run(["rebase", parent], cwd: cwd, artifacts: artifacts)
    }

    public func mergeNoFF(_ branch: String, cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        try run(["merge", "--no-ff", branch], cwd: cwd, artifacts: artifacts)
    }

    public func mergeSquash(_ branch: String, cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        try run(["merge", "--squash", branch], cwd: cwd, artifacts: artifacts)
    }

    public func deleteBranch(_ name: String, cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        try run(["branch", "-D", name], cwd: cwd, artifacts: artifacts)
    }

    public func worktreeRemove(_ path: String, force: Bool, cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        var args = ["worktree", "remove", path]
        if force { args.append("--force") }
        return try run(args, cwd: cwd, artifacts: artifacts)
    }

    public func revParse(_ ref: String, cwd: URL, artifacts: ArtifactWriter? = nil) throws -> (String, GitOpResult?) {
        if let artifacts {
            let op = try run(["rev-parse", ref], cwd: cwd, artifacts: artifacts)
            let out = try String(contentsOfFile: artifacts.lastStdoutPath ?? "", encoding: .utf8)
            return (out.trimmingCharacters(in: .whitespacesAndNewlines), op)
        } else {
            let out = try runCaptureStdout(["rev-parse", ref], cwd: cwd)
            return (out.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
    }

    public func run(_ args: [String], cwd: URL, artifacts: ArtifactWriter) throws -> GitOpResult {
        let start = DispatchTime.now()
        let result = try runProcess("/usr/bin/env", ["git"] + args, cwd: cwd, artifacts: artifacts)
        let end = DispatchTime.now()
        let ms = Int((end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
        return GitOpResult(
            argv: ["git"] + args,
            cwd: cwd.path,
            exitCode: result.exitCode,
            durationMS: ms,
            artifacts: result.artifacts
        )
    }

    private func runCaptureStdout(_ args: [String], cwd: URL) throws -> String {
        let tmp = ArtifactWriter(repoRoot: repoRoot)
        let op = try run(args, cwd: cwd, artifacts: tmp)
        if op.exitCode != 0 {
            let stderr = tmp.lastStderrPath.flatMap { try? String(contentsOfFile: $0, encoding: .utf8) }
            throw GitRunnerError.failed(command: op.argv.joined(separator: " "), exitCode: op.exitCode, stderr: stderr)
        }
        guard let p = tmp.lastStdoutPath else { return "" }
        return (try? String(contentsOfFile: p, encoding: .utf8)) ?? ""
    }

    private func runProcess(_ exe: String, _ argv: [String], cwd: URL, artifacts: ArtifactWriter) throws -> (exitCode: Int32, artifacts: GitOpArtifactRefs) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: exe)
        proc.arguments = argv
        proc.currentDirectoryURL = cwd

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        try proc.run()
        proc.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

        var copy = artifacts
        let stdoutPath = copy.writeArtifact(kind: "git", label: "stdout", data: outData)
        let stderrPath = copy.writeArtifact(kind: "git", label: "stderr", data: errData)

        return (proc.terminationStatus, GitOpArtifactRefs(stdoutPath: stdoutPath, stderrPath: stderrPath))
    }
}

public struct ArtifactWriter: Sendable {
    public let repoRoot: URL
    public private(set) var lastStdoutPath: String?
    public private(set) var lastStderrPath: String?

    public init(repoRoot: URL) {
        self.repoRoot = repoRoot
        self.lastStdoutPath = nil
        self.lastStderrPath = nil
    }

    @discardableResult
    public mutating func writeArtifact(kind: String, label: String, data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let ts = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let sha = blake3Hex(data)
        let dir = repoRoot.appendingPathComponent("Artifacts", isDirectory: true)
            .appendingPathComponent("praxis", isDirectory: true)
            .appendingPathComponent(kind, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(ts)-\(label)-\(sha).log", isDirectory: false)
        do {
            try data.write(to: url, options: [.atomic])
            let p = url.path
            if label == "stdout" { lastStdoutPath = p }
            if label == "stderr" { lastStderrPath = p }
            return p
        } catch {
            return nil
        }
    }
}

private func blake3Hex(_ data: Data) -> String {
    return BLAKE3Digest.hex(of: data)
}
