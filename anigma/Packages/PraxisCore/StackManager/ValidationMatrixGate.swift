//
//  ValidationMatrixGate.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct ValidationMatrixConfig: Codable, Sendable {
    public var schemaVersion: Int
    public var targets: [String]

    public init(schemaVersion: Int = 1, targets: [String]) {
        self.schemaVersion = schemaVersion
        self.targets = targets
    }
}

public struct ValidationRun: Codable, Sendable {
    public var target: String
    public var exitCode: Int32
    public var stdoutPath: String?
    public var stderrPath: String?
}

public struct ValidationMatrixResult: Codable, Sendable {
    public enum Verdict: String, Codable, Sendable { case pass, block }
    public var verdict: Verdict
    public var runs: [ValidationRun]
}

public struct ValidationMatrixGate: Sendable {
    public init() {}

    public func loadOrCreateDefaultConfig(repoRoot: URL) throws -> ValidationMatrixConfig {
        let anigmaDir = repoRoot.appendingPathComponent(".anigma", isDirectory: true)
        let url = anigmaDir.appendingPathComponent("validation-matrix.json", isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ValidationMatrixConfig.self, from: data)
        }

        try FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)
        let cfg = ValidationMatrixConfig(targets: ["ContractsCore", "AnigmaCore", "DatabaseCore", "PraxisModule", "HarmoniaModule", "HarmoniaCLI"])
        try writeJSON(cfg, to: url)
        return cfg
    }

    public func run(repoRoot: URL, artifacts: inout ArtifactWriter) -> ValidationMatrixResult {
        let cfg = (try? loadOrCreateDefaultConfig(repoRoot: repoRoot)) ?? ValidationMatrixConfig(targets: [])
        var runs: [ValidationRun] = []
        for target in cfg.targets {
            let run = runValidateTarget(repoRoot: repoRoot, target: target, artifacts: &artifacts)
            runs.append(run)
            if run.exitCode != 0 {
                return ValidationMatrixResult(verdict: .block, runs: runs)
            }
        }
        return ValidationMatrixResult(verdict: .pass, runs: runs)
    }

    private func runValidateTarget(repoRoot: URL, target: String, artifacts: inout ArtifactWriter) -> ValidationRun {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = ["Scripts/validate-target.sh", target]
        proc.currentDirectoryURL = repoRoot

        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err

        do {
            try proc.run()
        } catch {
            let data = Data("failed to spawn validate-target for \(target): \(error)".utf8)
            let stderrPath = artifacts.writeArtifact(kind: "validation", label: "stderr", data: data)
            return ValidationRun(target: target, exitCode: 127, stdoutPath: nil, stderrPath: stderrPath)
        }

        proc.waitUntilExit()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()

        let stdoutPath = artifacts.writeArtifact(kind: "validation", label: "stdout", data: outData)
        let stderrPath = artifacts.writeArtifact(kind: "validation", label: "stderr", data: errData)

        return ValidationRun(target: target, exitCode: proc.terminationStatus, stdoutPath: stdoutPath, stderrPath: stderrPath)
    }
}

private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try enc.encode(value)
    try data.write(to: url, options: [.atomic])
}
