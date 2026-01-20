//
//  CLITUIManager.swift
//  AnigmaCLIDatabase
//
//  Enhanced TUI management with live status display.
//  Shows run info, worktree status, loop breaker counters, and recent actions.
//

import Foundation

/// TUI display state with live updates.
public struct TUIDisplayState: Sendable {
    public let projectIdentity: ProjectIdentity?
    public let activeRun: ActiveRunInfo?
    public let worktreeStatus: WorktreeStatus?
    public let indexStatus: CLITUIIndexStatus?
    public let loopBreakerCounters: LoopBreakerCounters?
    public let recentActions: [RecentAction]
    public let approvalsQueue: [ApprovalRequest]

    public init(
        projectIdentity: ProjectIdentity? = nil,
        activeRun: ActiveRunInfo? = nil,
        worktreeStatus: WorktreeStatus? = nil,
        indexStatus: CLITUIIndexStatus? = nil,
        loopBreakerCounters: LoopBreakerCounters? = nil,
        recentActions: [RecentAction] = [],
        approvalsQueue: [ApprovalRequest] = []
    ) {
        self.projectIdentity = projectIdentity
        self.activeRun = activeRun
        self.worktreeStatus = worktreeStatus
        self.indexStatus = indexStatus
        self.loopBreakerCounters = loopBreakerCounters
        self.recentActions = recentActions
        self.approvalsQueue = approvalsQueue
    }
}

/// Project identity information.
public struct ProjectIdentity: Sendable {
    public let name: String
    public let path: String
    public let repoHash: String?

    public init(name: String, path: String, repoHash: String? = nil) {
        self.name = name
        self.path = path
        self.repoHash = repoHash
    }
}

/// Active run information.
public struct ActiveRunInfo: Sendable {
    public let runID: String
    public let taskSummary: String
    public let mode: String
    public let status: String
    public let startTime: TimeInterval
    public let currentStep: Int
    public let worktreePath: String?

    public init(
        runID: String,
        taskSummary: String,
        mode: String,
        status: String,
        startTime: TimeInterval,
        currentStep: Int,
        worktreePath: String?
    ) {
        self.runID = runID
        self.taskSummary = taskSummary
        self.mode = mode
        self.status = status
        self.startTime = startTime
        self.currentStep = currentStep
        self.worktreePath = worktreePath
    }
}

/// Worktree status summary.
public struct WorktreeStatus: Sendable {
    public let total: Int
    public let active: Int
    public let locked: Int

    public init(total: Int, active: Int, locked: Int) {
        self.total = total
        self.active = active
        self.locked = locked
    }
}

/// Index status summary.
public struct CLITUIIndexStatus: Sendable {
    public let totalChunks: Int
    public let lastUpdated: TimeInterval?

    public init(totalChunks: Int, lastUpdated: TimeInterval?) {
        self.totalChunks = totalChunks
        self.lastUpdated = lastUpdated
    }
}

/// Recent action record.
public struct RecentAction: Sendable, Identifiable {
    public let id: String
    public let timestamp: TimeInterval
    public let actionType: String
    public let description: String
    public let status: String

    public init(
        id: String,
        timestamp: TimeInterval,
        actionType: String,
        description: String,
        status: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionType = actionType
        self.description = description
        self.status = status
    }
}

/// Approval request pending user action.
public struct ApprovalRequest: Sendable, Identifiable {
    public let id: String
    public let toolName: String
    public let arguments: String
    public let requestedAt: TimeInterval

    public init(
        id: String,
        toolName: String,
        arguments: String,
        requestedAt: TimeInterval
    ) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
        self.requestedAt = requestedAt
    }
}

/// TUI manager for live status display.
public actor CLITUIManager {
    private let db: CLIDatabaseActor
    private let indexManager: CLIIndexManager?
    private let worktreeManager: CLIWorktreeManager?
    private let runManager: CLIRunManager?

    private var currentState: TUIDisplayState

    public init(
        database: CLIDatabaseActor,
        indexManager: CLIIndexManager? = nil,
        worktreeManager: CLIWorktreeManager? = nil,
        runManager: CLIRunManager? = nil
    ) {
        self.db = database
        self.indexManager = indexManager
        self.worktreeManager = worktreeManager
        self.runManager = runManager
        self.currentState = TUIDisplayState()
    }

    // MARK: - State Updates

    /// Refresh all state from database.
    public func refreshState() async throws {
        let projectIdentity = try await fetchProjectIdentity()
        let activeRun = try await fetchActiveRun()
        let worktreeStatus = try await fetchWorktreeStatus()
        let indexStatus = try await fetchIndexStatus()
        let loopBreakerCounters = await fetchLoopBreakerCounters(for: activeRun)
        let recentActions = try await fetchRecentActions(limit: 10)
        let approvalsQueue = await fetchApprovalsQueue()

        currentState = TUIDisplayState(
            projectIdentity: projectIdentity,
            activeRun: activeRun,
            worktreeStatus: worktreeStatus,
            indexStatus: indexStatus,
            loopBreakerCounters: loopBreakerCounters,
            recentActions: recentActions,
            approvalsQueue: approvalsQueue
        )
    }

    /// Get current display state.
    public func getState() -> TUIDisplayState {
        currentState
    }

    // MARK: - State Fetching

    private func fetchProjectIdentity() async throws -> ProjectIdentity? {
        let cwd = FileManager.default.currentDirectoryPath
        let name = URL(fileURLWithPath: cwd).lastPathComponent

        return ProjectIdentity(
            name: name,
            path: cwd,
            repoHash: nil
        )
    }

    private func fetchActiveRun() async throws -> ActiveRunInfo? {
        guard let runManager else { return nil }

        // Get most recent running run
        let runs = try await runManager.listRuns(limit: 1, status: .running)
        guard let run = runs.first else { return nil }

        // Get steps to count current step
        let steps = try await runManager.getSteps(runID: run.runID)

        return ActiveRunInfo(
            runID: run.runID,
            taskSummary: run.taskSummary,
            mode: run.mode.rawValue,
            status: run.status.rawValue,
            startTime: run.createdAt,
            currentStep: steps.count,
            worktreePath: run.worktreePath
        )
    }

    private func fetchWorktreeStatus() async throws -> WorktreeStatus? {
        guard let worktreeManager else { return nil }

        let leases = try await worktreeManager.listLeases()
        let active = leases.count // Placeholder for active if status is missing
        let locked = leases.filter { $0.locked }.count

        return WorktreeStatus(
            total: leases.count,
            active: active,
            locked: locked
        )
    }

    private func fetchIndexStatus() async throws -> CLITUIIndexStatus? {
        guard indexManager != nil else { return nil }

        // Query chunk count
        let rows = try await db.query("SELECT COUNT(*) as count FROM document_chunks", parameters: [])
        let count = rows.first?["count"]?.asInt ?? 0

        return CLITUIIndexStatus(
            totalChunks: count,
            lastUpdated: nil
        )
    }

    private func fetchLoopBreakerCounters(for run: ActiveRunInfo?) async -> LoopBreakerCounters? {
        // Would be populated by active loop breaker
        // For now, return nil if no active run
        return nil
    }

    private func fetchRecentActions(limit: Int) async throws -> [RecentAction] {
        // Query recent steps from database
        let rows = try await db.query("""
            SELECT step_id, created_at, action_type, status
            FROM steps
            ORDER BY created_at DESC
            LIMIT ?
            """, parameters: [.int(limit)])

        return rows.compactMap { row in
            guard let stepID = row["step_id"]?.asString,
                  let createdAt = row["created_at"]?.asDouble,
                  let actionType = row["action_type"]?.asString,
                  let status = row["status"]?.asString else {
                return nil
            }

            return RecentAction(
                id: stepID,
                timestamp: createdAt,
                actionType: actionType,
                description: actionType,
                status: status
            )
        }
    }

    private func fetchApprovalsQueue() async -> [ApprovalRequest] {
        // Placeholder - would integrate with approval system
        return []
    }

    // MARK: - Display Helpers

    /// Format state for terminal display.
    public func formatDisplay() -> String {
        var output = ""

        // Header
        output += "╔══════════════════════════════════════════════════════════════╗\n"
        output += "║                    ANIGMA CLI STATUS                         ║\n"
        output += "╚══════════════════════════════════════════════════════════════╝\n\n"

        // Project Identity
        if let project = currentState.projectIdentity {
            output += "📦 Project: \(project.name)\n"
            output += "   Path: \(project.path)\n"
            if let hash = project.repoHash {
                output += "   Repo Hash: \(hash.prefix(12))...\n"
            }
            output += "\n"
        }

        // Active Run
        if let run = currentState.activeRun {
            let elapsed = Date().timeIntervalSince1970 - run.startTime
            let elapsedStr = formatDuration(elapsed)

            output += "🏃 Active Run\n"
            output += "   ID: \(run.runID.prefix(8))\n"
            output += "   Task: \(run.taskSummary)\n"
            output += "   Status: \(run.status)\n"
            output += "   Mode: \(run.mode)\n"
            output += "   Step: \(run.currentStep)\n"
            output += "   Elapsed: \(elapsedStr)\n"
            if let worktree = run.worktreePath {
                output += "   Worktree: \(worktree)\n"
            }
            output += "\n"
        }

        // Loop Breaker Counters
        if let counters = currentState.loopBreakerCounters {
            output += "📊 Loop Breaker Counters\n"
            output += "   Steps: \(counters.steps)\n"
            output += "   Tool Calls: \(counters.toolCalls)\n"
            output += "   Tokens: \(counters.tokens)\n"
            output += "   Spend: $\(String(format: "%.2f", counters.spend))\n"
            output += "   Wall Time: \(String(format: "%.1f", counters.wallTimeSeconds))s\n"
            output += "\n"
        }

        // Worktree Status
        if let worktree = currentState.worktreeStatus {
            output += "🌳 Worktrees\n"
            output += "   Total: \(worktree.total)\n"
            output += "   Active: \(worktree.active)\n"
            output += "   Locked: \(worktree.locked)\n"
            output += "\n"
        }

        // Index Status
        if let index = currentState.indexStatus {
            output += "📇 Index\n"
            output += "   Chunks: \(index.totalChunks)\n"
            if let updated = index.lastUpdated {
                let date = Date(timeIntervalSince1970: updated)
                output += "   Updated: \(formatDate(date))\n"
            }
            output += "\n"
        }

        // Recent Actions
        if !currentState.recentActions.isEmpty {
            output += "📝 Recent Actions\n"
            for action in currentState.recentActions.prefix(5) {
                let timestamp = Date(timeIntervalSince1970: action.timestamp)
                let timeStr = formatTime(timestamp)
                let statusIcon = getStatusIcon(action.status)
                output += "   \(statusIcon) [\(timeStr)] \(action.actionType)\n"
            }
            output += "\n"
        }

        // Approvals Queue
        if !currentState.approvalsQueue.isEmpty {
            output += "⚠️  Pending Approvals (\(currentState.approvalsQueue.count))\n"
            for approval in currentState.approvalsQueue.prefix(3) {
                output += "   • \(approval.toolName) \(approval.arguments)\n"
            }
            output += "\n"
        }

        return output
    }

    // MARK: - Formatters

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func getStatusIcon(_ status: String) -> String {
        switch status.lowercased() {
        case "running": return "🏃"
        case "completed": return "✅"
        case "failed": return "❌"
        case "pending": return "⏳"
        case "cancelled": return "🚫"
        default: return "•"
        }
    }
}
