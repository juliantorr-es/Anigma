//
//  Swift6StepEngine.swift
//  HarmoniaModule
//
//  Step engine for Swift 6 migration domain.
//

@preconcurrency import Foundation

/// Intent for a Swift 6 migration step.
public enum Swift6StepIntent: Sendable, Codable {
    /// Run a specific migration task.
    case runTask(taskId: UUID)

    /// Rescout a specific file.
    case rescoutFile(path: String)

    /// Pause migration with a reason.
    case pause(reason: String)

    /// Human-readable description of the intent.
    public var description: String {
        switch self {
        case .runTask(let taskId):
            return "Run migration task \(taskId.uuidString.prefix(8))..."
        case .rescoutFile(let path):
            return "Rescout file \(path)"
        case .pause(let reason):
            return "Pause: \(reason)"
        }
    }
}

/// Protocol for Swift 6 step engines.
public protocol Swift6StepEngine: Sendable {
    /// Chooses the next step based on migration state and policy.
    /// - Parameters:
    ///   - state: Current migration state.
    ///   - policy: Migration policy.
    /// - Returns: The chosen step intent.
    func chooseNextStep(
        from state: Swift6MigrationState,
        policy: Swift6MigrationPolicy
    ) -> Swift6StepIntent
}

/// Basic deterministic step engine for Swift 6 migration.
public struct BasicSwift6StepEngine: Swift6StepEngine {
    /// Creates a new basic step engine.
    public init() {}

    /// Chooses the next step using a deterministic heuristic.
    public func chooseNextStep(
        from state: Swift6MigrationState,
        policy: Swift6MigrationPolicy
    ) -> Swift6StepIntent {
        // Rule 1: If migration is complete, pause
        guard !state.isComplete else {
            return .pause(reason: "Migration complete - no open tasks")
        }

        // Rule 2: Get files with pending work
        let filesWithWork = state.filesWithPendingWork

        // Rule 3: Filter out files with recent tainted sessions if policy says to avoid them
        let candidateFiles: [Swift6FileSummary]
        if policy.avoidTaintedAreas {
            candidateFiles = filesWithWork.filter { !$0.hasRecentTaintedSessions }
        } else {
            candidateFiles = filesWithWork
        }

        // Rule 4: If no candidate files due to taint avoidance, pause
        if policy.avoidTaintedAreas && candidateFiles.isEmpty && !filesWithWork.isEmpty {
            return .pause(reason: "All files with pending work have recent tainted sessions")
        }

        // Rule 5: If no files with work at all, consider rescout
        if candidateFiles.isEmpty {
            if policy.allowRescouts && !state.files.isEmpty {
                // Find file with most findings that hasn't been rescouted recently
                if let fileToRescout = chooseFileForRescout(from: state.files) {
                    return .rescoutFile(path: fileToRescout.path)
                }
            }
            return .pause(reason: "No pending work and rescouts not allowed or no files to rescout")
        }

        // Rule 6: Choose the best file based on policy
        let chosenFile = chooseBestFile(from: candidateFiles, policy: policy)

        // Rule 7: Choose the best task from that file
        if let chosenTask = chooseBestTask(from: chosenFile.tasks) {
            return .runTask(taskId: chosenTask.id)
        }

        // Rule 8: If file has work but no suitable tasks, rescout it
        if policy.allowRescouts {
            return .rescoutFile(path: chosenFile.path)
        }

        // Rule 9: Fallback pause
        return .pause(reason: "No suitable tasks found in chosen file")
    }

    /// Chooses the best file from candidates based on policy.
    private func chooseBestFile(
        from candidates: [Swift6FileSummary],
        policy: Swift6MigrationPolicy
    ) -> Swift6FileSummary {
        // Sort by priority criteria
        return candidates.sorted { file1, file2 in
            // 1. Prefer high severity if policy says so
            if policy.preferHighSeverity && file1.highestSeverity != file2.highestSeverity {
                return file1.highestSeverity.rawValue > file2.highestSeverity.rawValue
            }

            // 2. Prefer more open tasks
            if file1.openTaskCount != file2.openTaskCount {
                return file1.openTaskCount > file2.openTaskCount
            }

            // 3. Prefer files that haven't been touched recently
            let file1LastTouch = file1.lastTouchedSession ?? 0
            let file2LastTouch = file2.lastTouchedSession ?? 0
            return file1LastTouch < file2LastTouch
        }.first!
    }

    /// Chooses the best task from a file's tasks.
    private func chooseBestTask(from tasks: [MigrationTask]) -> MigrationTask? {
        // Filter to pending tasks
        let pendingTasks = tasks.filter { $0.status == .pending }

        // Sort by: priority (higher first), then creation date (oldest first)
        return pendingTasks.sorted { task1, task2 in
            // Compare by priority
            if task1.priority != task2.priority {
                return task1.priority > task2.priority
            }

            // Fall back to creation date (oldest first)
            return task1.createdAt < task2.createdAt
        }.first
    }

    /// Chooses a file to rescout.
    private func chooseFileForRescout(from files: [Swift6FileSummary]) -> Swift6FileSummary? {
        // Prefer files with findings but no recent sessions
        return files
            .filter { !$0.findings.isEmpty }
            .sorted { file1, file2 in
                // More findings first
                if file1.findings.count != file2.findings.count {
                    return file1.findings.count > file2.findings.count
                }

                // Higher severity findings first
                if file1.highestSeverity != file2.highestSeverity {
                    return file1.highestSeverity.rawValue > file2.highestSeverity.rawValue
                }

                // Less recently touched first
                let file1LastTouch = file1.lastTouchedSession ?? 0
                let file2LastTouch = file2.lastTouchedSession ?? 0
                return file1LastTouch < file2LastTouch
            }
            .first
    }
}

/// Factory for Swift 6 step engines.
public enum Swift6StepEngineFactory {
    /// Creates a step engine for the given configuration.
    /// - Parameter config: Engine configuration.
    /// - Returns: A step engine instance.
    public static func create(config: String = "basic") -> any Swift6StepEngine {
        switch config {
        case "basic":
            return BasicSwift6StepEngine()
        default:
            return BasicSwift6StepEngine()
        }
    }
}
