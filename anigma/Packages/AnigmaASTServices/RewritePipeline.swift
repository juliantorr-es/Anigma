//
//  RewritePipeline.swift
//  AnigmaASTServices
//
//  Orchestrates AST rewrite rules with governance metadata.
//

import Foundation
import AnigmaPrimitives
import SwiftSyntax
import SwiftParser

public struct PipelineConfig: Sendable {
    public let trustTier: TrustTier
    public let backupFiles: Bool
    public let maxConcurrentFiles: Int
    public let dryRun: Bool
    public let logLevel: LogLevel

    public init(
        trustTier: TrustTier = .bronze,
        backupFiles: Bool = true,
        maxConcurrentFiles: Int = 4,
        dryRun: Bool = false,
        logLevel: LogLevel = .info
    ) {
        self.trustTier = trustTier
        self.backupFiles = backupFiles
        self.maxConcurrentFiles = maxConcurrentFiles
        self.dryRun = dryRun
        self.logLevel = logLevel
    }
}

public enum LogLevel: Int, Sendable {
    case error = 0
    case warn = 1
    case info = 2
    case debug = 3
    case trace = 4
}

    public enum PipelineError: Error, Sendable {
        case readError(String, Error)
        case ruleError(String, String, Error)
        case writeError(String, Error)
        case verificationError(String, String)

        public var description: String {
            switch self {
            case .readError(let path, let error):
                return "Read error for \(path): \(error)"
            case .ruleError(let rule, let file, let error):
                return "Rule '\(rule)' failed on \(file): \(error)"
            case .writeError(let path, let error):
                return "Write error for \(path): \(error)"
            case .verificationError(let cmd, let detail):
                return "Verification '\(cmd)' failed: \(detail)"
            }
        }
    }

public struct VerificationOutcome: Sendable {
    public let success: Bool
    public let detail: String

    public init(success: Bool, detail: String) {
        self.success = success
        self.detail = detail
    }
}

public struct PipelineResult: Sendable {
    public let filesProcessed: Int
    public let filesModified: Int
    public let totalChanges: Int
    public let errors: [PipelineError]
    public let changes: [SourceChange]
    public let outcomes: [RewritePipeline.FileOutcome]
    public let duration: TimeInterval
    public let verification: VerificationOutcome?

    public init(
        filesProcessed: Int,
        filesModified: Int,
        totalChanges: Int,
        errors: [PipelineError],
        changes: [SourceChange],
        outcomes: [RewritePipeline.FileOutcome],
        duration: TimeInterval,
        verification: VerificationOutcome? = nil
    ) {
        self.filesProcessed = filesProcessed
        self.filesModified = filesModified
        self.totalChanges = totalChanges
        self.errors = errors
        self.changes = changes
        self.outcomes = outcomes
        self.duration = duration
        self.verification = verification
    }
}

public actor RewritePipeline {
    public struct PipelineItem: Sendable {
        public let filePath: String
        public let astAnchor: AstAnchor?

        public init(filePath: String, astAnchor: AstAnchor? = nil) {
            self.filePath = filePath
            self.astAnchor = astAnchor
        }
    }

    public struct FileOutcome: Sendable {
        public enum Status: String, Sendable {
            case skipped
            case noChange
            case matched
        }

        public let filePath: String
        public let status: Status
        public let path: String
        public let reason: String?
        public let changes: [SourceChange]
        public let backupPath: String?
        public let diffArtifactPath: String?
        public let verificationStatus: String?

        public init(
            filePath: String,
            status: Status,
            path: String,
            reason: String? = nil,
            changes: [SourceChange] = [],
            backupPath: String? = nil,
            diffArtifactPath: String? = nil,
            verificationStatus: String? = nil
        ) {
            self.filePath = filePath
            self.status = status
            self.path = path
            self.reason = reason
            self.changes = changes
            self.backupPath = backupPath
            self.diffArtifactPath = diffArtifactPath
            self.verificationStatus = verificationStatus
        }
    }

    private let config: PipelineConfig
    private let rules: [RewriteRule]
    private let lens: SwiftAstLens
    private let artifactDirectory: URL
    private let runId: String
    private var logger: (LogLevel, String) -> Void

    public init(
        rules: [RewriteRule],
        config: PipelineConfig = PipelineConfig(),
        lens: SwiftAstLens = SwiftAstLens(),
        logger: @escaping (LogLevel, String) -> Void = { level, message in
            let prefix: String
            switch level {
            case .error: prefix = "❌"
            case .warn: prefix = "⚠️"
            case .info: prefix = "ℹ️"
            case .debug: prefix = "🔍"
            case .trace: prefix = "📝"
            }
            print("\(prefix) \(message)")
        }
    ) {
        self.rules = rules
        self.config = config
        self.lens = lens
        self.logger = logger
        self.runId = UUID().uuidString
        let baseArtifacts = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Artifacts")
            .appendingPathComponent("ast-rewrite")
            .appendingPathComponent(runId)
        self.artifactDirectory = baseArtifacts
        do {
            try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        } catch {
            logger(.warn, "Failed to create artifact directory: \(error)")
        }
    }

    public func execute(on items: [PipelineItem]) async -> PipelineResult {
        let startTime = Date()
        var processed = 0
        var modified = 0
        var totalChanges = 0
        var errors: [PipelineError] = []
        var allChanges: [SourceChange] = []
        var outcomes: [FileOutcome] = []

        let activeRules = rules.filter { $0.requiredTrustTier <= config.trustTier }
        log(.info, "Active rules: \(activeRules.map { $0.name }.joined(separator: ", "))")

        let batches = items.chunked(into: config.maxConcurrentFiles)
        for batch in batches {
            let batchResult = await withTaskGroup(of: (Int, Int, [SourceChange], [PipelineError], [FileOutcome]).self) { group in
                for item in batch {
                    group.addTask {
                        await self.process(item: item, with: activeRules)
                    }
                }

                var batchProcessed = 0
                var batchModified = 0
                var batchChanges: [SourceChange] = []
                var batchErrors: [PipelineError] = []
                var batchOutcomes: [FileOutcome] = []

                for await (p, m, changes, errs, fileOutcomes) in group {
                    batchProcessed += p
                    batchModified += m
                    batchChanges.append(contentsOf: changes)
                    batchErrors.append(contentsOf: errs)
                    batchOutcomes.append(contentsOf: fileOutcomes)
                }

                return (batchProcessed, batchModified, batchChanges, batchErrors, batchOutcomes)
            }

            processed += batchResult.0
            modified += batchResult.1
            totalChanges += batchResult.2.count
            errors.append(contentsOf: batchResult.3)
            allChanges.append(contentsOf: batchResult.2)
            outcomes.append(contentsOf: batchResult.4)
        }

        let duration = Date().timeIntervalSince(startTime)
        let verification: VerificationOutcome? = await self.runVerificationIfNeeded(processed: processed, modified: &modified, totalChanges: &totalChanges, outcomes: &outcomes, errors: &errors)

        return PipelineResult(
            filesProcessed: processed,
            filesModified: modified,
            totalChanges: totalChanges,
            errors: errors,
            changes: allChanges,
            outcomes: outcomes,
            duration: duration,
            verification: verification
        )
    }

    private func process(item: PipelineItem, with rules: [RewriteRule]) async -> (Int, Int, [SourceChange], [PipelineError], [FileOutcome]) {
        let filePath = item.filePath
        log(.debug, "Processing \(filePath)")

        guard let anchor = item.astAnchor else {
            return (1, 0, [], [], [
                FileOutcome(filePath: filePath, status: .skipped, path: "AST", reason: "no_anchor")
            ])
        }

        let content: String
        do {
            content = try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            log(.error, "Failed to read \(filePath): \(error)")
            return (0, 0, [], [.readError(filePath, error)], [])
        }

        let ast: SourceFileSyntax
        let currentHash: String
        do {
            (ast, currentHash) = try await lens.ast(for: filePath)
        } catch {
            log(.error, "Failed to parse \(filePath): \(error)")
            return (0, 0, [], [.ruleError("ast", filePath, error)], [])
        }

        if currentHash != anchor.contentHash {
            return (1, 0, [], [], [
                FileOutcome(filePath: filePath, status: .skipped, path: "AST", reason: "stale_content_hash")
            ])
        }

        let fingerprint = AstAnchor.fingerprint(
            sourceText: content,
            startOffset: anchor.startOffset,
            endOffset: anchor.endOffset
        )

        if fingerprint != anchor.contextFingerprint {
            return (1, 0, [], [], [
                FileOutcome(filePath: filePath, status: .skipped, path: "AST", reason: "stale_fingerprint")
            ])
        }

        let applicableRules = rules.filter { $0.shouldApply(to: filePath, source: content) }
        let converter = SourceLocationConverter(fileName: filePath, tree: ast)
        if applicableRules.isEmpty {
            return (1, 0, [], [], [
                FileOutcome(filePath: filePath, status: .skipped, path: "AST", reason: "no_applicable_rules")
            ])
        }

        var currentContent = content
        var allChanges: [SourceChange] = []
        var errors: [PipelineError] = []
        var modified = false

        for rule in applicableRules {
            do {
                let result: RewriteResult
                if let anchoredRule = rule as? AstAnchoredRule {
                    result = try anchoredRule.apply(
                        to: currentContent,
                        filePath: filePath,
                        anchor: anchor,
                        ast: ast,
                        converter: converter
                    )
                } else {
                    result = try rule.apply(to: currentContent, filePath: filePath)
                }

                if result.modified {
                    modified = true
                    currentContent = result.newSource
                    allChanges.append(contentsOf: result.appliedChanges)
                    if !result.diagnostics.isEmpty {
                        for diagnostic in result.diagnostics {
                            log(.info, "\(filePath): \(rule.name): \(diagnostic)")
                        }
                    }
                    log(.debug, "Rule \(rule.name) would change \(filePath)")
                }
            } catch {
                let pipelineError = PipelineError.ruleError(rule.name, filePath, error)
                errors.append(pipelineError)
                log(.error, pipelineError.description)
            }
        }

        if !modified {
            let finalOutcome = FileOutcome(
                filePath: filePath,
                status: .noChange,
                path: "AST",
                reason: errors.first?.description,
                changes: allChanges
            )
            return (1, 0, allChanges, errors, [finalOutcome])
        }

        var backupPath: String?
        var diffPath: String?
        if !config.dryRun {
            do {
                if config.backupFiles {
                    backupPath = try createBackup(for: filePath)
                }
                try currentContent.write(toFile: filePath, atomically: true, encoding: .utf8)
                diffPath = try createDiffArtifact(original: content, updated: currentContent, filePath: filePath)
            } catch {
                let pipelineError = PipelineError.writeError(filePath, error)
                errors.append(pipelineError)
                log(.error, pipelineError.description)
                if let backup = backupPath {
                    try? restoreBackup(backupPath: backup, to: filePath)
                }
                return (0, 0, allChanges, errors, [
                    FileOutcome(
                        filePath: filePath,
                        status: .skipped,
                        path: "AST",
                        reason: "write_failed",
                        changes: allChanges,
                        backupPath: backupPath
                    )
                ])
            }
        }

        let finalOutcome = FileOutcome(
            filePath: filePath,
            status: .matched,
            path: "AST",
            reason: errors.first?.description,
            changes: allChanges,
            backupPath: backupPath,
            diffArtifactPath: diffPath
        )

        return (1, config.dryRun ? 0 : 1, allChanges, errors, [finalOutcome])
    }

    private func createBackup(for filePath: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: filePath)
        let backupURL = sourceURL.appendingPathExtension("anigma.bak")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }

        try fileManager.copyItem(at: sourceURL, to: backupURL)
        return backupURL.path
    }

    private func restoreBackup(backupPath: String, to filePath: String) throws {
        let backupURL = URL(fileURLWithPath: backupPath)
        let targetURL = URL(fileURLWithPath: filePath)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }

        try fileManager.copyItem(at: backupURL, to: targetURL)
    }

    private func createDiffArtifact(original: String, updated: String, filePath: String) throws -> String {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let originalURL = tempDir.appendingPathComponent(UUID().uuidString + ".orig")
        let updatedURL = tempDir.appendingPathComponent(UUID().uuidString + ".new")

        try original.write(to: originalURL, atomically: true, encoding: .utf8)
        try updated.write(to: updatedURL, atomically: true, encoding: .utf8)

        defer {
            try? fileManager.removeItem(at: originalURL)
            try? fileManager.removeItem(at: updatedURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/diff")
        process.arguments = ["-u", originalURL.path, updatedURL.path]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let status = process.terminationStatus
        if status > 1 {
            let err = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "RewritePipeline", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "diff command failed: \(err)"])
        }

        let diffData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let artifactName = "\(sanitizedFileName(filePath))-\(UUID().uuidString).diff"
        let artifactURL = artifactDirectory.appendingPathComponent(artifactName)
        try diffData.write(to: artifactURL, options: .atomic)
        log(.info, "Created diff artifact for \(filePath): \(artifactURL.path)")
        return artifactURL.path
    }

    private func sanitizedFileName(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let relative = url.path.replacingOccurrences(of: "/", with: "_")
        return relative.replacingOccurrences(of: ":", with: "-")
    }

    private func runVerificationIfNeeded(
        processed: Int,
        modified: inout Int,
        totalChanges: inout Int,
        outcomes: inout [FileOutcome],
        errors: inout [PipelineError]
    ) async -> VerificationOutcome? {
        guard !config.dryRun, modified > 0 else {
            return nil
        }
        if let forced = forcedVerificationOutcome() {
            log(.info, "Forced verification outcome: success=\(forced.success)")
            return forced
        }

        guard shouldRunVerification() else {
            return nil
        }

        let verification = verifyChanges()

        if verification.success {
            outcomes = outcomes.map { updateOutcomeForVerification($0, status: nil, verificationStatus: "verified") }
            return verification
        }

        let failedReason = "verification_failed"
        rollback(outcomes.filter { $0.status == .matched })
        modified = 0
        totalChanges = 0
        errors.append(.verificationError("swift test --filter MigrationPipelineTests", verification.detail))
        outcomes = outcomes.map {
            updateOutcomeForVerification($0, status: .skipped, reason: failedReason, verificationStatus: "verification_failed: \(verification.detail)")
        }

        return verification
    }

    private func verifyChanges() -> VerificationOutcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["test", "--filter", "MigrationPipelineTests"]
        process.environment = verificationEnvironment()

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            log(.error, "Verification command failed to start: \(error)")
            return VerificationOutcome(success: false, detail: "failed to run verification: \(error)")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let success = process.terminationStatus == 0
        log(.info, "Verification \(success ? "passed" : "failed") for run \(runId)")
        return VerificationOutcome(success: success, detail: output)
    }

    private func shouldRunVerification() -> Bool {
        let env = ProcessInfo.processInfo.environment["ANIGMA_AST_VERIFY"]?.lowercased()
        return env != "0"
    }

    private func forcedVerificationOutcome() -> VerificationOutcome? {
        guard let forced = ProcessInfo.processInfo.environment["ANIGMA_AST_VERIFY_FORCE"]?.lowercased() else {
            return nil
        }
        switch forced {
        case "fail":
            return VerificationOutcome(success: false, detail: "forced failure")
        case "pass":
            return VerificationOutcome(success: true, detail: "forced pass")
        default:
            return nil
        }
    }

    private func verificationEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["CLANG_MODULE_CACHE_PATH"] = ".cache-clang"
        env["SWIFTPM_DIRECTORY"] = ".cache-swiftpm"
        return env
    }

    private func updateOutcomeForVerification(
        _ outcome: FileOutcome,
        status: FileOutcome.Status?,
        reason: String? = nil,
        verificationStatus: String? = nil
    ) -> FileOutcome {
        guard outcome.status == .matched else {
            return outcome
        }

        return FileOutcome(
            filePath: outcome.filePath,
            status: status ?? outcome.status,
            path: outcome.path,
            reason: reason ?? outcome.reason,
            changes: outcome.changes,
            backupPath: outcome.backupPath,
            diffArtifactPath: outcome.diffArtifactPath,
            verificationStatus: verificationStatus ?? outcome.verificationStatus
        )
    }

    private func rollback(_ outcomes: [FileOutcome]) {
        for outcome in outcomes {
            guard let backupPath = outcome.backupPath else {
                continue
            }
            do {
                try restoreBackup(backupPath: backupPath, to: outcome.filePath)
                log(.warn, "Rolled back changes to \(outcome.filePath) from backup")
            } catch {
                log(.error, "Failed to roll back \(outcome.filePath): \(error)")
            }
        }
    }

    private func log(_ level: LogLevel, _ message: String) {
        if level.rawValue <= config.logLevel.rawValue {
            logger(level, message)
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
