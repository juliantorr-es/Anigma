//
//  CLIRunManager.swift
//  AnigmaCLIDatabase
//
//  Run and step tracking for anigma-cli executions.
//  Manages run lifecycle, step recording, and status transitions.
//

import Foundation
import Crypto

/// Run manager for tracking CLI execution runs and steps.
public actor CLIRunManager {
    private let db: CLIDatabaseActor
    private let receipts: CLIReceiptManager

    public init(database: CLIDatabaseActor, receiptManager: CLIReceiptManager) {
        self.db = database
        self.receipts = receiptManager
    }

    // MARK: - Run Management

    /// Create a new run record.
    public func createRun(
        taskSummary: String,
        taskDetails: String?,
        mode: ExecutionMode,
        dryRun: Bool,
        worktreePath: String?
    ) async throws -> Run {
        let runID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        // Compute spec hash
        let specContent = "\(taskSummary)|\(taskDetails ?? "")|\(mode.rawValue)|\(dryRun)"
        let specHash = hash(specContent)

        // Get base commit if in a worktree
        var baseCommit: String?
        if let worktreePath {
            baseCommit = try? await getGitCommit(path: worktreePath)
        }

        // Create run record
        _ = try await db.execute("""
            INSERT INTO runs (
                run_id, task_summary, task_details, mode, dry_run,
                status, created_at, spec_hash, worktree_path, base_commit
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                .text(runID),
                .text(taskSummary),
                taskDetails.map { .text($0) } ?? .null,
                .text(mode.rawValue),
                .int(dryRun ? 1 : 0),
                .text(RunStatus.pending.rawValue),
                .double(now),
                .text(specHash),
                worktreePath.map { .text($0) } ?? .null,
                baseCommit.map { .text($0) } ?? .null
            ])

        // Generate receipt
        _ = try await receipts.recordRunStart(
            runID: runID,
            taskSummary: taskSummary,
            mode: mode.rawValue,
            dryRun: dryRun
        )

        return Run(
            runID: runID,
            taskSummary: taskSummary,
            taskDetails: taskDetails,
            mode: mode,
            dryRun: dryRun,
            status: .pending,
            createdAt: now,
            completedAt: nil,
            specHash: specHash,
            worktreePath: worktreePath,
            baseCommit: baseCommit
        )
    }

    /// Update run status.
    public func updateRunStatus(
        runID: String,
        status: RunStatus,
        message: String? = nil
    ) async throws {
        let now = Date().timeIntervalSince1970

        if status == .completed || status == .failed {
            _ = try await db.execute("""
                UPDATE runs
                SET status = ?, completed_at = ?
                WHERE run_id = ?
                """, parameters: [
                    .text(status.rawValue),
                    .double(now),
                    .text(runID)
                ])

            // Generate completion receipt
            _ = try await receipts.recordRunComplete(
                runID: runID,
                status: status.rawValue,
                message: message ?? ""
            )
        } else {
            _ = try await db.execute("""
                UPDATE runs
                SET status = ?
                WHERE run_id = ?
                """, parameters: [
                    .text(status.rawValue),
                    .text(runID)
                ])
        }
    }

    /// Get a run by ID.
    public func getRun(runID: String) async throws -> Run? {
        let rows = try await db.query("""
            SELECT * FROM runs WHERE run_id = ?
            """, parameters: [.text(runID)])

        guard let row = rows.first else { return nil }
        return try decodeRun(row)
    }

    /// List recent runs.
    public func listRuns(
        limit: Int = 50,
        status: RunStatus? = nil
    ) async throws -> [Run] {
        let sql: String
        let params: [CLIParameter]

        if let status {
            sql = """
                SELECT * FROM runs
                WHERE status = ?
                ORDER BY created_at DESC
                LIMIT ?
                """
            params = [.text(status.rawValue), .int(limit)]
        } else {
            sql = """
                SELECT * FROM runs
                ORDER BY created_at DESC
                LIMIT ?
                """
            params = [.int(limit)]
        }

        let rows = try await db.query(sql, parameters: params)
        return try rows.map { try decodeRun($0) }
    }

    // MARK: - Step Management

    /// Record a step in a run.
    public func recordStep(
        runID: String,
        stepNumber: Int,
        actionType: String,
        actionData: String?,
        request: String? = nil,
        response: String? = nil
    ) async throws -> Step {
        let stepID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        // Create step record
        _ = try await db.execute("""
            INSERT INTO steps (
                step_id, run_id, step_number, action_type, action_data,
                status, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                .text(stepID),
                .text(runID),
                .int(stepNumber),
                .text(actionType),
                actionData.map { .text($0) } ?? .null,
                .text(StepStatus.running.rawValue),
                .double(now)
            ])

        // Generate receipt if we have request/response
        if let request, let response {
            _ = try await receipts.recordStep(
                runID: runID,
                stepID: stepID,
                actionType: actionType,
                request: request,
                response: response
            )
        }

        return Step(
            stepID: stepID,
            runID: runID,
            stepNumber: stepNumber,
            actionType: actionType,
            actionData: actionData,
            status: .running,
            createdAt: now,
            completedAt: nil,
            errorMessage: nil
        )
    }

    /// Update step status.
    public func updateStepStatus(
        stepID: String,
        status: StepStatus,
        errorMessage: String? = nil
    ) async throws {
        let now = Date().timeIntervalSince1970

        _ = try await db.execute("""
            UPDATE steps
            SET status = ?, completed_at = ?, error_message = ?
            WHERE step_id = ?
            """, parameters: [
                .text(status.rawValue),
                .double(now),
                errorMessage.map { .text($0) } ?? .null,
                .text(stepID)
            ])
    }

    /// Get steps for a run.
    public func getSteps(runID: String) async throws -> [Step] {
        let rows = try await db.query("""
            SELECT * FROM steps
            WHERE run_id = ?
            ORDER BY step_number ASC
            """, parameters: [.text(runID)])

        return try rows.map { try decodeStep($0) }
    }

    /// Get a specific step.
    public func getStep(stepID: String) async throws -> Step? {
        let rows = try await db.query("""
            SELECT * FROM steps WHERE step_id = ?
            """, parameters: [.text(stepID)])

        guard let row = rows.first else { return nil }
        return try decodeStep(row)
    }

    // MARK: - Run Details with Steps and Receipts

    /// Get complete run details including steps and receipts.
    public func getRunDetails(runID: String) async throws -> RunDetails? {
        guard let run = try await getRun(runID: runID) else {
            return nil
        }

        let steps = try await getSteps(runID: runID)
        let receipts = try await self.receipts.listReceipts(runID: runID)

        return RunDetails(
            run: run,
            steps: steps,
            receipts: receipts
        )
    }

    // MARK: - Private Helpers

    private func decodeRun(_ row: CLIRow) throws -> Run {
        guard let runID = row["run_id"]?.asString,
              let taskSummary = row["task_summary"]?.asString,
              let modeStr = row["mode"]?.asString,
              let dryRunInt = row["dry_run"]?.asInt,
              let statusStr = row["status"]?.asString,
              let createdAt = row["created_at"]?.asDouble else {
            throw RunError.invalidRunData
        }

        guard let mode = ExecutionMode(rawValue: modeStr),
              let status = RunStatus(rawValue: statusStr) else {
            throw RunError.invalidRunData
        }

        return Run(
            runID: runID,
            taskSummary: taskSummary,
            taskDetails: row["task_details"]?.asString,
            mode: mode,
            dryRun: dryRunInt != 0,
            status: status,
            createdAt: createdAt,
            completedAt: row["completed_at"]?.asDouble,
            specHash: row["spec_hash"]?.asString ?? "",
            worktreePath: row["worktree_path"]?.asString,
            baseCommit: row["base_commit"]?.asString
        )
    }

    private func decodeStep(_ row: CLIRow) throws -> Step {
        guard let stepID = row["step_id"]?.asString,
              let runID = row["run_id"]?.asString,
              let stepNumber = row["step_number"]?.asInt,
              let actionType = row["action_type"]?.asString,
              let statusStr = row["status"]?.asString,
              let createdAt = row["created_at"]?.asDouble else {
            throw RunError.invalidStepData
        }

        guard let status = StepStatus(rawValue: statusStr) else {
            throw RunError.invalidStepData
        }

        return Step(
            stepID: stepID,
            runID: runID,
            stepNumber: stepNumber,
            actionType: actionType,
            actionData: row["action_data"]?.asString,
            status: status,
            createdAt: createdAt,
            completedAt: row["completed_at"]?.asDouble,
            errorMessage: row["error_message"]?.asString
        )
    }

    private func hash(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func getGitCommit(path: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let commit = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw RunError.gitCommandFailed
        }

        return commit
    }
}

// MARK: - Supporting Types

public struct Run: Sendable, Identifiable {
    public let runID: String
    public let taskSummary: String
    public let taskDetails: String?
    public let mode: ExecutionMode
    public let dryRun: Bool
    public let status: RunStatus
    public let createdAt: TimeInterval
    public let completedAt: TimeInterval?
    public let specHash: String
    public let worktreePath: String?
    public let baseCommit: String?

    public var id: String { runID }
}

public struct Step: Sendable, Identifiable {
    public let stepID: String
    public let runID: String
    public let stepNumber: Int
    public let actionType: String
    public let actionData: String?
    public let status: StepStatus
    public let createdAt: TimeInterval
    public let completedAt: TimeInterval?
    public let errorMessage: String?

    public var id: String { stepID }
}

public struct RunDetails: Sendable {
    public let run: Run
    public let steps: [Step]
    public let receipts: [CoreReceipt]
}

public enum ExecutionMode: String, Sendable, Codable {
    case plan
    case run
}

public enum RunStatus: String, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

public enum StepStatus: String, Sendable {
    case pending
    case running
    case completed
    case failed
    case skipped
}

public enum RunError: Error, Sendable {
    case invalidRunData
    case invalidStepData
    case gitCommandFailed
}
