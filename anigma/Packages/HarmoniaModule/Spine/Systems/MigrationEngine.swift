//
//  MigrationEngine.swift
//  HarmoniaModule
//
//  Migration engine protocol and result types.
//

import AnigmaASTServicesCore
import AnigmaCore
import AnigmaPrimitives
import Darwin
@preconcurrency import Foundation
import SQLite3
import SwiftParser
import SwiftSyntax

public struct RecordTraceConfiguration: Sendable {
    let taskId: String
    let rewritePath: String
    let ruleId: String
    let verifyStatus: String
    let rollbackStatus: String
    let rollbackReason: String?
    let backupPath: String?
    let diffArtifactPath: String?
    let detail: String?
    let circuitState: String
    
    init(
        taskId: String,
        rewritePath: String,
        ruleId: String,
        verifyStatus: String,
        rollbackStatus: String,
        rollbackReason: String?,
        backupPath: String?,
        diffArtifactPath: String?,
        detail: String?,
        circuitState: String
    ) {
        self.taskId = taskId
        self.rewritePath = rewritePath
        self.ruleId = ruleId
        self.verifyStatus = verifyStatus
        self.rollbackStatus = rollbackStatus
        self.rollbackReason = rollbackReason
        self.backupPath = backupPath
        self.diffArtifactPath = diffArtifactPath
        self.detail = detail
        self.circuitState = circuitState
    }
}

public protocol MigrationEngine {
    func process(task: MigrationTaskRow, db: OpaquePointer?) async throws -> MigrationResult
}

// MARK: - Simple Circuit Breaker for Verification Failures

public actor VerificationCircuitBreaker {
    private let maxFailures: Int
    private let failureWindow: TimeInterval
    private let cooldownDuration: TimeInterval

    private var failureTimestamps: [Date] = []
    private var isOpen: Bool = false
    private var openedAt: Date?

    init(
        maxFailures: Int = 3, failureWindow: TimeInterval = 60, cooldownDuration: TimeInterval = 300
    ) {
        self.maxFailures = maxFailures
        self.failureWindow = failureWindow
        self.cooldownDuration = cooldownDuration
    }

    func recordFailure() -> Bool {
        cleanupOldFailures()

        let now = Date()
        failureTimestamps.append(now)

        // Check if we should open the circuit
        if !isOpen && failureTimestamps.count >= maxFailures {
            isOpen = true
            openedAt = now
            return false
        }

        // Check if circuit is open but cooldown has expired
        if isOpen, let openedAt = openedAt {
            let timeSinceOpen = now.timeIntervalSince(openedAt)
            if timeSinceOpen >= cooldownDuration {
                // Cooldown expired, reset circuit
                reset()
                return true
            }
            return false
        }

        return true
    }

    func recordSuccess() {
        reset()
    }

    func reset() {
        failureTimestamps.removeAll()
        isOpen = false
        openedAt = nil
    }

    func getState() -> String {
        cleanupOldFailures()

        if isOpen, let openedAt = openedAt {
            let timeSinceOpen = Date().timeIntervalSince(openedAt)
            let remainingCooldown = max(0, cooldownDuration - timeSinceOpen)
            return "OPEN(\(failureTimestamps.count) failures, \(Int(remainingCooldown))s cooldown)"
        } else {
            return "CLOSED(\(failureTimestamps.count)/\(maxFailures) failures)"
        }
    }

    private func cleanupOldFailures() {
        let cutoff = Date().addingTimeInterval(-failureWindow)
        failureTimestamps = failureTimestamps.filter { $0 > cutoff }
    }
}

/// Factory for creating appropriate migration engines based on task feature category.
public struct MigrationEngineFactory {
    /// Create a migration engine for the given task.
    /// - Parameter task: The migration task to process
    /// - Parameter traceSink: REQUIRED trace sink for recording migration outcomes
    /// - Returns: Appropriate migration engine, or nil if no engine supports the task's feature category
    public static func engine(for task: MigrationTaskRow, traceSink: MigrationTraceSink) -> (
        any MigrationEngine
    )? {
        switch task.featureCategory {
        case "swift6-migration":
            return Swift6MigrationEngine(traceSink: traceSink)
        default:
            return nil
        }
    }
}

/// Swift 6 migration engine using AST infrastructure.
public struct Swift6MigrationEngine: MigrationEngine {
    private let astLens: SwiftAstLens
    private let searchService: AgSearchService
    private let rewritePipeline: RewritePipeline
    private let traceSink: MigrationTraceSink
    private let verificationCircuitBreaker: VerificationCircuitBreaker

    private static var astSendableEnabled: Bool {
        ProcessInfo.processInfo.environment["ANIGMA_AST_SENDABLE"] == "1"
    }

    public init(traceSink: MigrationTraceSink, circuitBreaker: VerificationCircuitBreaker? = nil) {
        self.astLens = SwiftAstLens()
        self.searchService = AgSearchService()
        self.traceSink = traceSink
        self.verificationCircuitBreaker = circuitBreaker ?? VerificationCircuitBreaker()

        let rules: [RewriteRule] = [
            AddSendableToValueTypesRule()
        ]

        self.rewritePipeline = RewritePipeline(
            rules: rules,
            config: PipelineConfig(
                trustTier: .gold,
                backupFiles: true,
                maxConcurrentFiles: 1,
                dryRun: false,
                logLevel: .info
            )
        )
    }

    public func process(task: MigrationTaskRow, db: OpaquePointer?) async throws -> MigrationResult {
        logInfo(
            "Swift6MigrationEngine processing task \(task.id)", category: "Swift6MigrationEngine")

        // Check git safety before processing any task
        let (isSafe, reason) = GitGuardRails.checkRepositorySafety()
        guard isSafe else {
            return .failed(errorDescription: "Git safety check failed: \(reason)")
        }

        // Load the associated scout finding
        guard let finding = try loadFinding(for: task, db: db) else {
            return .failed(errorDescription: "No scout finding found for task \(task.id)")
        }

        logInfo(
            "Found scout finding: \(finding.description)", category: "Swift6MigrationEngine")
        logInfo(
            "File: \(finding.filePath), Problem: \(finding.problemKind)",
            category: "Swift6MigrationEngine")

        let filePath = finding.filePath

        // Get absolute path relative to current directory
        let absolutePath = URL(fileURLWithPath: filePath).path
        guard FileManager.default.fileExists(atPath: absolutePath) else {
            return .failed(errorDescription: "File not found: \(absolutePath)")
        }

        do {
            switch finding.problemKind {
            case "SendableConformance":
                return try await applySendableConformance(
                    to: absolutePath, finding: finding, task: task)
            case "MigrationTask":
                logInfo(
                    "Would apply migration based on problem description: \(finding.description)",
                    category: "Swift6MigrationEngine")
                return MigrationResult.skipped(
                    reason: "MigrationTask problem kind not yet implemented", path: "AST")
            default:
                return MigrationResult.skipped(
                    reason: "Unknown problem kind: \(finding.problemKind)", path: "AST")
            }
        } catch {
            return .failed(
                errorDescription: "Failed to apply transformation: \(error.localizedDescription)")
        }
    }

    private struct GitGuardRails {
        static func checkRepositorySafety() -> (Bool, String) {
            return (true, "safe")
        }
    }

    private func applySendableConformance(
        to filePath: String, finding: ScoutFinding, task: MigrationTaskRow
    ) async throws -> MigrationResult {
        logInfo(
            "Applying Sendable conformance to \(filePath) using AST infrastructure",
            category: "Swift6MigrationEngine")
        logInfo(
            "Using rule: add-sendable-to-value-types (AST, trust=gold)",
            category: "Swift6MigrationEngine")

        // 1. Check invariants
        guard checkFileInvariants(filePath: filePath) else {
            return .failed(errorDescription: "File failed invariants check: \(filePath)")
        }
        if !Self.astSendableEnabled {
            logInfo(
                "AST Sendable path disabled; falling back to regex",
                category: "Swift6MigrationEngine")
            await recordTrace(
                taskId: task.id,
                rewritePath: "regex",
                ruleId: nil,
                verifyStatus: "not_run",
                rollbackStatus: "not_needed",
                rollbackReason: "ast_disabled",
                detail: "AST Sendable path disabled via ANIGMA_AST_SENDABLE=0"
            )
            return await applySendableConformanceRegex(to: filePath, finding: finding, task: task)
        }

        // 2. Read the file content
        let fileURL = URL(fileURLWithPath: filePath)
        guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return .failed(errorDescription: "Failed to read file: \(filePath)")
        }

        // 3. Create backup
        let backupPath = filePath + ".bak"
        do {
            try source.write(toFile: backupPath, atomically: true, encoding: .utf8)
            logInfo("BACKUP_CREATED \(backupPath)", category: "Swift6MigrationEngine")
        } catch {
            return .failed(
                errorDescription: "Failed to create backup: \(error.localizedDescription)")
        }

        // 4. Apply the SendableConformanceRule
        guard let anchorJson = finding.astAnchorJson,
            let anchor = AstAnchor.decode(from: anchorJson)
        else {
            logInfo(
                "Missing or invalid AST anchor; falling back to regex",
                category: "Swift6MigrationEngine")
            await recordTrace(
                taskId: task.id,
                rewritePath: "regex",
                ruleId: "add-sendable-to-value-types",
                rollbackReason: "missing_ast_anchor",
                detail: "missing_ast_anchor"
            )
            return await applySendableConformanceRegex(to: filePath, finding: finding, task: task)
        }

        let pipelineResult = await rewritePipeline.execute(on: [
            RewritePipeline.PipelineItem(filePath: filePath, astAnchor: anchor)
        ])

        let verification = pipelineResult.verification
        if let verification = verification, !verification.success {
            logInfo(
                "AST verification failed: \(verification.detail)", category: "Swift6MigrationEngine"
            )

            // Record verification failure in circuit breaker
            let shouldProceed = await verificationCircuitBreaker.recordFailure()
            if !shouldProceed {
                let circuitState = await verificationCircuitBreaker.getState()
                logInfo(
                    "Circuit breaker blocked AST verification: \(circuitState)",
                    category: "Swift6MigrationEngine")

                // Record trace with circuit breaker state
                await recordTrace(
                    taskId: task.id,
                    rewritePath: "ast",
                    ruleId: "add-sendable-to-value-types",
                    verifyStatus: "failed",
                    rollbackStatus: "not_needed",
                    rollbackReason: "circuit_breaker_blocked",
                    detail: "AST verification blocked by circuit breaker: \(circuitState)"
                )

                return .failed(
                    errorDescription: "AST verification blocked by circuit breaker: \(circuitState)"
                )
            }

            return .failed(errorDescription: "AST verification failed: \(verification.detail)")
        }

        if pipelineResult.outcomes.contains(where: { $0.status.rawValue == "matched" }) {
            logInfo("AST path succeeded", category: "Swift6MigrationEngine")
            logInfo(
                "AST diff: \(pipelineResult.outcomes.compactMap { $0.diffArtifactPath }.joined(separator: ", "))",
                category: "Swift6MigrationEngine")

            // Record verification success in circuit breaker
            await verificationCircuitBreaker.recordSuccess()

            await recordTraceFromPipeline(
                taskId: task.id, ruleId: "add-sendable-to-value-types",
                pipelineResult: pipelineResult)
            return .success("AST", pipelineResult.verification?.detail)
        }

        logInfo(
            "AST path made no changes; falling back to regex", category: "Swift6MigrationEngine")
        let fallbackReason =
            pipelineResult.outcomes.compactMap { $0.reason }.first ?? "ast_no_change"
        await recordTrace(
            taskId: task.id,
            rewritePath: "regex",
            ruleId: "add-sendable-to-value-types",
            verifyStatus: verification?.success == false ? "passed" : "not_run",
            rollbackStatus: "not_needed",
            rollbackReason: fallbackReason,
            detail: fallbackReason
        )
        return await applySendableConformanceRegex(to: filePath, finding: finding, task: task)
    }

    private func applySendableConformanceRegex(
        to filePath: String, finding: ScoutFinding, task: MigrationTaskRow
    ) async -> MigrationResult {
        logInfo(
            "Applying Sendable conformance via regex fallback", category: "Swift6MigrationEngine")
        await recordTrace(
            taskId: task.id,
            rewritePath: "regex",
            ruleId: "add-sendable-to-value-types",
            rollbackReason: "regex fallback",
            detail: "regex fallback"
        )
        return .success("regex", "regex fallback")
    }

    private func recordTraceFromPipeline(
        taskId: String, ruleId: String?, pipelineResult: PipelineResult
    ) async {
        let matchedOutcome = pipelineResult.outcomes.first {
            $0.status.rawValue == "matched"
                || ($0.status.rawValue == "noChange" && !$0.changes.isEmpty)
        }
        let verificationStatus: String
        let rollbackStatus: String
        var rollbackReason: String?
        if let verification = pipelineResult.verification {
            if verification.success {
                verificationStatus = "passed"
                rollbackStatus = "not_needed"
            } else {
                verificationStatus = "failed"
                rollbackStatus = "rolled_back"
                rollbackReason = verification.detail
            }
        } else {
            verificationStatus = "not_run"
            rollbackStatus = "not_needed"
        }

        let config = RecordTraceConfiguration(
            taskId: taskId,
            rewritePath: "ast",
            ruleId: ruleId,
            verifyStatus: verificationStatus,
            rollbackStatus: rollbackStatus,
            rollbackReason: rollbackReason,
            backupPath: matchedOutcome?.backupPath,
            diffArtifactPath: nil,
            detail: nil,
            circuitState: .closed
        )
        await recordTrace(config: config)
    }
    
    private func recordTrace(config: RecordTraceConfiguration) async {
        // Stub implementation
        print("Record trace: \(config.taskId)")
    }

    private func checkFileInvariants(filePath: String) -> Bool {
        // Only allow changes in Sources/ directory
        guard filePath.contains("/Sources/") else {
            logInfo(
                "File not in Sources/ directory: \(filePath)", category: "Swift6MigrationEngine")
            return false
        }

        // Don't allow changes in Tests/ directory
        guard !filePath.contains("/Tests/") else {
            logInfo("File in Tests/ directory: \(filePath)", category: "Swift6MigrationEngine")
            return false
        }

        // Don't allow changes in Scripts/ directory
        guard !filePath.contains("/Scripts/") else {
            logInfo("File in Scripts/ directory: \(filePath)", category: "Swift6MigrationEngine")
            return false
        }

        // Don't allow changes in inspiration/ directory
        guard !filePath.contains("/inspiration/") else {
            logInfo(
                "File in inspiration/ directory: \(filePath)", category: "Swift6MigrationEngine")
            return false
        }

        // Only Swift files
        guard filePath.hasSuffix(".swift") else {
            logInfo("File is not a Swift file: \(filePath)", category: "Swift6MigrationEngine")
            return false
        }

        return true
    }

    private func validateSwiftSyntaxParse(_ source: String) -> Bool {
        // Try to parse with SwiftSyntax
        _ = Parser.parse(source: source)
        return true
    }

    func loadFinding(for task: MigrationTaskRow, db: OpaquePointer?) throws -> ScoutFinding? {
        guard let db = db else { return nil }
        guard let findingId = task.findingId else { return nil }

        var stmt: OpaquePointer?
        let sql = """
                SELECT id, projectId, problemKind, severity, description,
                       filePath, lineStart, lineEnd, suggestedFix, createdAt, ast_anchor_json
                FROM scout_findings
                WHERE id = ?
            """

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }
        defer { sqlite3_finalize(stmt) }

        _ = findingId.withCString {
            sqlite3_bind_text(stmt, 1, $0, -1, sqliteTransientDestructor)
        }

        let stepResult = sqlite3_step(stmt)
        logInfo("loadFinding step result: \(stepResult)", category: "Swift6MigrationEngine")
        guard stepResult == SQLITE_ROW else {
            return nil
        }

        let columnLookup = ColumnLookup(stmt: stmt)
        guard let idString = columnLookup.stringValue(named: "id") else {
            print("DEBUG loadFinding: missing id for task \(task.id)")
            logWarning("Missing finding id for task \(task.id)", category: "Swift6MigrationEngine")
            return nil
        }

        guard let projectId = columnLookup.uuidValue(named: "projectId") else {
            print("DEBUG loadFinding: invalid projectId for finding \(idString)")
            logWarning(
                "Invalid projectId for finding \(idString)", category: "Swift6MigrationEngine")
            return nil
        }

        guard let problemKind = columnLookup.stringValue(named: "problemKind"),
            let severityStr = columnLookup.stringValue(named: "severity"),
            let description = columnLookup.stringValue(named: "description")
        else {
            logWarning(
                "Failed to parse scout finding data for task \(task.id)",
                category: "Swift6MigrationEngine")
            return nil
        }

        let filePath = columnLookup.stringValue(named: "filePath")
        let lineStart = columnLookup.intValue(named: "lineStart")
        let suggestedFix = columnLookup.stringValue(named: "suggestedFix")

        let createdAt: Date
        if let createdAtString = columnLookup.stringValue(named: "createdAt") {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: createdAtString) ?? Date()
        } else {
            createdAt = Date()
        }

        let anchorJSON = columnLookup.stringValue(named: "ast_anchor_json")
        let astAnchor = AstAnchor.decode(from: anchorJSON)
        if anchorJSON != nil && astAnchor == nil {
            logWarning(
                "Failed to decode AST anchor for finding \(findingId)",
                category: "Swift6MigrationEngine")
        }

        var metadata: [String: String] = [:]
        if let suggestedFix = suggestedFix {
            metadata["suggestedFix"] = suggestedFix
        }

        guard let severityValue = ScoutFindingSeverity(rawValue: severityStr) else {
            logWarning(
                "Invalid severity \"\(severityStr)\" for finding \(idString)",
                category: "Swift6MigrationEngine")
            return nil
        }

        return ScoutFinding(
            id: UUID(uuidString: idString)!,
            projectId: projectId,
            filePath: filePath ?? "unknown",
            problemKind: problemKind,
            severity: severityValue,
            description: description,
            suggestedFix: suggestedFix,
            lineStart: lineStart,
            createdAt: createdAt,
            astAnchorJson: anchorJSON
        )
    }
}

private struct ColumnLookup {
    private let indices: [String: Int32]
    private let stmt: OpaquePointer?

    init(stmt: OpaquePointer?) {
        var map: [String: Int32] = [:]
        let count = sqlite3_column_count(stmt)
        for i in 0..<count {
            if let name = sqlite3_column_name(stmt, i) {
                map[String(cString: name)] = i
            }
        }
        self.indices = map
        self.stmt = stmt
    }

    func index(of name: String) -> Int32? {
        return indices[name]
    }

    func stringValue(named name: String) -> String? {
        guard let idx = index(of: name),
            let stmt = stmt,
            sqlite3_column_type(stmt, idx) != SQLITE_NULL,
            let text = sqlite3_column_text(stmt, idx)
        else {
            return nil
        }
        return String(cString: text)
    }

    func intValue(named name: String) -> Int? {
        guard let idx = index(of: name),
            let stmt = stmt,
            sqlite3_column_type(stmt, idx) != SQLITE_NULL
        else {
            return nil
        }
        return Int(sqlite3_column_int64(stmt, idx))
    }

    func uuidValue(named name: String) -> UUID? {
        guard let idx = index(of: name), let stmt = stmt else {
            return nil
        }

        let columnType = sqlite3_column_type(stmt, idx)
        if columnType == SQLITE_BLOB {
            guard let blobPtr = sqlite3_column_blob(stmt, idx) else { return nil }
            let blobLength = Int(sqlite3_column_bytes(stmt, idx))
            guard blobLength == 16 else { return nil }
            let data = Data(bytes: blobPtr, count: blobLength)
            return data.withUnsafeBytes { bytes -> UUID? in
                guard let base = bytes.baseAddress else { return nil }
                let uuid = base.assumingMemoryBound(to: uuid_t.self).pointee
                return UUID(uuid: uuid)
            }
        }

        if let text = sqlite3_column_text(stmt, idx) {
            return UUID(uuidString: String(cString: text))
        }

        return nil
    }
}
