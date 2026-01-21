//
//  WorkspaceSnapshotCapture.swift
//  HarmoniaModule
//
//  Workspace snapshot capture and recording for deterministic loop execution.
//  Ensures the workspace state is recorded before any work begins and used as
//  the canonical reference for all stage boundary artifacts and verification.
//

import AnigmaPrimitives
import Foundation

/// Captures the current workspace state as a content-addressed hash.
/// This hash is a pinned input that must match across all stages and verification.
public struct WorkspaceSnapshot: Codable, Sendable, Equatable {
    public let snapshotHash: String  // Content-addressed hash of workspace state
    public let gitHeadCommit: String
    public let fileCount: Int
    public let sourceFilesModified: [String]  // Relative to repo root
    public let capturedAt: String  // Sequence timestamp, not wall-clock

    public init(
        snapshotHash: String,
        gitHeadCommit: String,
        fileCount: Int,
        sourceFilesModified: [String],
        capturedAt: String
    ) {
        self.snapshotHash = snapshotHash
        self.gitHeadCommit = gitHeadCommit
        self.fileCount = fileCount
        self.sourceFilesModified = sourceFilesModified
        self.capturedAt = capturedAt
    }

    /// Verify that this snapshot matches a given hash
    public func verify(against hash: String) -> Bool {
        return self.snapshotHash == hash
    }
}

/// Captures workspace state at execution time.
public struct WorkspaceSnapshotCapture {

    /// Capture the current workspace snapshot
    public static func current() throws -> WorkspaceSnapshot {
        let headCommit = try captureGitHeadCommit()
        let modifiedFiles = try captureModifiedSourceFiles()

        // Create deterministic snapshot hash from workspace state
        let snapshotHash = try createDeterministicHash(
            gitCommit: headCommit,
            modifiedFiles: modifiedFiles
        )

        return WorkspaceSnapshot(
            snapshotHash: snapshotHash,
            gitHeadCommit: headCommit,
            fileCount: modifiedFiles.count,
            sourceFilesModified: modifiedFiles,
            capturedAt: ""  // Will be set to sequence timestamp
        )
    }

    /// Capture current git HEAD commit
    private static func captureGitHeadCommit() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? "unknown"
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Capture modified source files relative to repo root
    private static func captureModifiedSourceFiles() throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "--name-only", "HEAD"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return
            output
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.hasSuffix(".swift") }
            .sorted()  // Deterministic order
    }

    /// Create a deterministic hash of the workspace state
    private static func createDeterministicHash(
        gitCommit: String,
        modifiedFiles: [String]
    ) throws -> String {
        struct SnapshotData: Codable {
            let git_commit: String
            let modified_files: [String]
            let file_count: Int
        }

        let snapshotData = SnapshotData(
            git_commit: gitCommit,
            modified_files: modifiedFiles,
            file_count: modifiedFiles.count
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = try encoder.encode(snapshotData)

        return BLAKE3Digest.hex(of: jsonData)
    }
}

/// Event that records the workspace snapshot captured at session start
public struct WorkspaceSnapshotEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let snapshot: WorkspaceSnapshot

    public init(sessionId: String, snapshot: WorkspaceSnapshot) {
        self.eventId = "workspace-snapshot-\(sessionId.prefix(8))"
        self.eventType = "workspace.snapshot"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.snapshot = snapshot
    }
}

/// Extends VerificationInputs to enforce workspace snapshot validation
extension VerificationInputs {

    /// Validate that workspace snapshot hash is properly pinned
    public func validateWorkspaceSnapshot() throws {
        guard !workspaceSnapshotHash.isEmpty else {
            throw WorkspaceSnapshotError.emptyHash
        }

        guard workspaceSnapshotHash.count == 64 else {
            throw WorkspaceSnapshotError.invalidHashLength(workspaceSnapshotHash.count)
        }
    }
}

/// Errors related to workspace snapshot capture and validation
public enum WorkspaceSnapshotError: Error, LocalizedError {
    case emptyHash
    case invalidHashLength(Int)
    case mismatch(expected: String, actual: String)
    case captureFailure(String)

    public var localizedDescription: String? {
        switch self {
        case .emptyHash:
            return "Workspace snapshot hash is empty"
        case .invalidHashLength(let length):
            return "Invalid workspace snapshot hash length: \(length) (expected 64)"
        case .mismatch(let expected, let actual):
            return "Workspace snapshot mismatch: expected \(expected), got \(actual)"
        case .captureFailure(let reason):
            return "Failed to capture workspace snapshot: \(reason)"
        }
    }
}

/// Ensures workspace snapshot is recorded at session start and referenced throughout
public struct WorkspaceSnapshotContract {

    /// Validate that workspace snapshot is properly recorded
    public static func validate(_ snapshot: WorkspaceSnapshot) throws {
        // Hash must be non-empty and valid
        guard !snapshot.snapshotHash.isEmpty else {
            throw WorkspaceSnapshotError.emptyHash
        }

        // Hash must be deterministic length (BLAKE3 = 64 hex chars)
        guard snapshot.snapshotHash.count == 64 else {
            throw WorkspaceSnapshotError.invalidHashLength(snapshot.snapshotHash.count)
        }

        // Must have git commit
        guard !snapshot.gitHeadCommit.isEmpty else {
            throw WorkspaceSnapshotError.captureFailure("No git commit captured")
        }
    }

    /// Ensure workspace snapshot is used as pinned input in stage boundaries
    public static func linkToStageArtifact(
        artifact: StageArtifact,
        snapshot: WorkspaceSnapshot
    ) -> StageArtifactWithSnapshot {
        return StageArtifactWithSnapshot(
            artifact: artifact,
            snapshotHash: snapshot.snapshotHash
        )
    }
}

/// Stage artifact linked to the workspace snapshot it was computed against
public struct StageArtifactWithSnapshot: Sendable {
    public let artifact: StageArtifact
    public let snapshotHash: String  // Must match the pinned workspace hash

    /// Verify that this artifact's snapshot matches the expected hash
    public func verifySnapshot(against expectedHash: String) throws {
        guard snapshotHash == expectedHash else {
            throw WorkspaceSnapshotError.mismatch(
                expected: expectedHash,
                actual: snapshotHash
            )
        }
    }
}
