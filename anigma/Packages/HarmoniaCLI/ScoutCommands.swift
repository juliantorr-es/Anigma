//
//  ScoutCommands.swift
//  HarmoniaCLI
//
//  CLI commands for scouts and migration tasks.
//

import ArgumentParser
import Foundation
import HarmoniaModule

// MARK: - Scout Commands

public struct Scout: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "scout",
            abstract: "Run scouts and manage migration tasks",
            subcommands: [
                ScoutSwift6.self,
                TasksList.self,
                TasksRun.self,
                FindingsList.self
            ]
        )
    }

    public init() {}
}

public struct ScoutSwift6: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "swift6",
            abstract: "Run Swift 6 diagnostic scout",
            subcommands: [
                TasksList.self, TasksRun.self, RunNext.self, RunTask.self, FindingsList.self
            ]
        )
    }

    @Option(name: .shortAndLong, help: "Project ID (defaults to self-host project)")
    var projectId: String?

    @Flag(name: .shortAndLong, help: "Create migration tasks from findings")
    var createTasks: Bool = false

    public init() {}

    public func run() async throws {
        print("🔍 Running Swift 6 diagnostic scout...")

        // Get project ID (default to self-host project)
        let projectUUID: UUID
        if let projectId = projectId {
            guard let uuid = UUID(uuidString: projectId) else {
                throw ValidationError("Invalid project ID format")
            }
            projectUUID = uuid
        } else {
            // Default to self-host project
            projectUUID = SelfHostProjectConfig.projectId
            print("Using self-host project: \(projectUUID)")
        }

        // Get principality controller
        let controller = await PrincipalityProvider.shared.controller(for: projectUUID)

        // Run scout
        let summary = try await controller.runSwift6Scout()

        // Print results
        print("\n✅ Scout completed!")
        print("\n📊 Summary:")
        print("   Total findings: \(summary.totalFindings)")
        print("   Tasks created: \(summary.tasksCreated)")

        print("\n📈 Findings by severity:")
        for (severity, count) in summary.findingsBySeverity.sorted(by: {
            $0.key.rawValue < $1.key.rawValue
        }) {
            let icon: String
            switch severity {
            case .critical: icon = "🔴"
            case .error: icon = "🟠"
            case .warning: icon = "🟡"
            case .info: icon = "🔵"
            }
            print("   \(icon) \(severity.rawValue.capitalized): \(count)")
        }

        if summary.tasksCreated > 0 {
            print("\n🎯 Next steps:")
            print("   1. Run 'harmonia tasks list' to see pending tasks")
            print("   2. Run 'harmonia tasks run next' to execute next task")
            print(
                "   3. Run 'harmonia tasks run --feature swift6-migration' to run all Swift 6 tasks"
            )
        }
    }
}

struct TasksList: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "list",
            abstract: "List migration tasks"
        )
    }

    @Option(name: .shortAndLong, help: "Project ID (defaults to self-host project)")
    var projectId: String?

    @Option(name: .shortAndLong, help: "Filter by feature category")
    var feature: String?

    @Option(
        name: .shortAndLong,
        help: "Filter by status (pending, active, completed, failed, cancelled)")
    var status: String?

    @Option(name: .shortAndLong, help: "Maximum number of tasks to show")
    var limit: Int = 20

    func run() async throws {
        print("📋 Listing migration tasks...")

        // Get project ID (default to self-host project)
        let projectUUID: UUID
        if let projectId = projectId {
            guard let uuid = UUID(uuidString: projectId) else {
                throw ValidationError("Invalid project ID format")
            }
            projectUUID = uuid
        } else {
            // Default to self-host project
            projectUUID = SelfHostProjectConfig.projectId
            print("Using self-host project: \(projectUUID)")
        }

        // Parse status filter
        let statusFilter: MigrationTaskStatus?
        if let status = status {
            guard let parsedStatus = MigrationTaskStatus(rawValue: status.lowercased()) else {
                throw ValidationError(
                    "Invalid status. Must be: pending, active, completed, failed, cancelled")
            }
            statusFilter = parsedStatus
        } else {
            statusFilter = nil
        }

        // Get principality controller
        let controller = await PrincipalityProvider.shared.controller(for: projectUUID)

        // Get tasks
        let tasks = try await controller.listMigrationTasks(
            featureCategory: feature,
            status: statusFilter,
            limit: limit
        )

        // Print results
        if tasks.isEmpty {
            print("\n📭 No migration tasks found")
            return
        }

        print("\n📋 Migration Tasks (\(tasks.count) total):")

        for (index, task) in tasks.enumerated() {
            let statusIcon: String
            switch task.status {
            case .pending: statusIcon = "⏳"
            case .active: statusIcon = "⚡"
            case .completed: statusIcon = "✅"
            case .failed: statusIcon = "❌"
            case .cancelled: statusIcon = "🚫"
            }

            print("\n\(index + 1). \(statusIcon) \(task.featureCategory)")
            print("   ID: \(task.id)")
            print("   Status: \(task.status.rawValue.capitalized)")
            print("   Priority: \(task.priority)")
            print("   Created: \(task.createdAt.formatted(date: .abbreviated, time: .shortened))")

            if let startedAt = task.startedAt {
                print("   Started: \(startedAt.formatted(date: .abbreviated, time: .shortened))")
            }

            if let completedAt = task.completedAt {
                print(
                    "   Completed: \(completedAt.formatted(date: .abbreviated, time: .shortened))")
            }

            if let sessionIndex = task.sessionIndex {
                print("   Session: #\(sessionIndex)")
            }
        }

        // Show summary
        let pendingCount = tasks.filter { $0.status == .pending }.count
        let activeCount = tasks.filter { $0.status == .active }.count
        let completedCount = tasks.filter { $0.status == .completed }.count

        print("\n📊 Summary:")
        print("   ⏳ Pending: \(pendingCount)")
        print("   ⚡ Active: \(activeCount)")
        print("   ✅ Completed: \(completedCount)")

        if pendingCount > 0 {
            print("\n🎯 Run next task: 'harmonia tasks run next'")
        }
    }
}

struct TasksRun: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "run",
            abstract: "Run migration tasks",
            discussion: "Runs pending migration tasks. Use --count to limit the number of tasks.",
            subcommands: [
                RunNext.self,
                RunTask.self
            ]
        )
    }
}

struct RunNext: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "next",
            abstract: "Run the next pending migration task"
        )
    }

    @Option(name: .shortAndLong, help: "Project ID (defaults to self-host project)")
    var projectId: String?

    @Option(name: .shortAndLong, help: "Filter by feature category")
    var feature: String?

    func run() async throws {
        print("⚡ Running next migration task...")

        // Get project ID (default to self-host project)
        let projectUUID: UUID
        if let projectId = projectId {
            guard let uuid = UUID(uuidString: projectId) else {
                throw ValidationError("Invalid project ID format")
            }
            projectUUID = uuid
        } else {
            // Default to self-host project
            projectUUID = SelfHostProjectConfig.projectId
            print("Using self-host project: \(projectUUID)")
        }

        // Get principality controller
        let controller = await PrincipalityProvider.shared.controller(for: projectUUID)

        // Run next task
        let report = try await controller.runNextMigrationTask(featureCategory: feature)

        // Print results
        print("\n✅ Task completed!")
        print("\n📊 Session Report:")
        print("   Session Index: #\(report.sessionIndex)")
        print("   Feature Category: \(report.featureCategory ?? "none")")
        print("   Config ID: \(report.configId ?? "none")")
        print("   Verdict: \(report.verdict)")

        if let governanceTrace = report.governanceTrace {
            print("\n👼 Governance Trace:")
            print("   Config ID: \(governanceTrace.configId ?? "none")")
            print("   Trust Tier: \(governanceTrace.trustTier.rawValue.capitalized)")
            print("   Policy Decision: \(governanceTrace.policyDecision)")
            print("   Security Outcome: \(governanceTrace.securityOutcome)")
            print("   Escalated: \(governanceTrace.escalated ? "✅" : "❌")")
            print("   Tainted: \(governanceTrace.tainted ? "✅" : "❌")")
        }

        print("\n🎯 Next: Run 'harmonia tasks list' to see remaining tasks")
    }
}

struct RunTask: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "task",
            abstract: "Run a specific migration task"
        )
    }

    @Option(name: .shortAndLong, help: "Project ID (defaults to self-host project)")
    var projectId: String?

    @Argument(help: "Task ID to run")
    var taskId: String

    func run() async throws {
        print("⚡ Running migration task...")

        // Get project ID (default to self-host project)
        let projectUUID: UUID
        if let projectId = projectId {
            guard let uuid = UUID(uuidString: projectId) else {
                throw ValidationError("Invalid project ID format")
            }
            projectUUID = uuid
        } else {
            // Default to self-host project
            projectUUID = SelfHostProjectConfig.projectId
            print("Using self-host project: \(projectUUID)")
        }

        // Parse task ID
        guard let taskUUID = UUID(uuidString: taskId) else {
            throw ValidationError("Invalid task ID format")
        }

        // Get principality controller
        let controller = await PrincipalityProvider.shared.controller(for: projectUUID)

        // Get the task
        let tasks = try await controller.listMigrationTasks(limit: 100)
        guard let task = tasks.first(where: { $0.id == taskUUID }) else {
            throw ValidationError("Task not found: \(taskId)")
        }

        // Run the task
        let report = try await controller.runMigrationTask(task)

        // Print results
        print("\n✅ Task completed!")
        print("\n📊 Session Report:")
        print("   Session Index: #\(report.sessionIndex)")
        print("   Feature Category: \(report.featureCategory ?? "none")")
        print("   Task ID: \(task.id)")
        print("   Config ID: \(report.configId ?? "none")")
        print("   Verdict: \(report.verdict)")

        print("\n🎯 Next: Run 'harmonia tasks list' to see remaining tasks")
    }
}

struct FindingsList: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "findings",
            abstract: "List scout findings"
        )
    }

    @Option(name: .shortAndLong, help: "Project ID (defaults to self-host project)")
    var projectId: String?

    @Option(name: .shortAndLong, help: "Filter by problem kind")
    var problemKind: String?

    @Option(name: .shortAndLong, help: "Filter by severity (info, warning, error, critical)")
    var severity: String?

    @Option(name: .shortAndLong, help: "Maximum number of findings to show")
    var limit: Int = 20

    func run() async throws {
        print("🔍 Listing scout findings...")

        // Get project ID (default to self-host project)
        let projectUUID: UUID
        if let projectId = projectId {
            guard let uuid = UUID(uuidString: projectId) else {
                throw ValidationError("Invalid project ID format")
            }
            projectUUID = uuid
        } else {
            // Default to self-host project
            projectUUID = SelfHostProjectConfig.projectId
            print("Using self-host project: \(projectUUID)")
        }

        // Parse severity filter
        let severityFilter: ScoutFindingSeverity?
        if let severity = severity {
            guard let parsedSeverity = ScoutFindingSeverity(rawValue: severity.lowercased()) else {
                throw ValidationError("Invalid severity. Must be: info, warning, error, critical")
            }
            severityFilter = parsedSeverity
        } else {
            severityFilter = nil
        }

        // Get principality controller
        let controller = await PrincipalityProvider.shared.controller(for: projectUUID)

        // Get findings
        let findings = try await controller.listScoutFindings(
            problemKind: problemKind,
            severity: severityFilter,
            limit: limit
        )

        // Print results
        if findings.isEmpty {
            print("\n📭 No scout findings found")
            return
        }

        print("\n🔍 Scout Findings (\(findings.count) total):")

        for (index, finding) in findings.enumerated() {
            let severityIcon: String
            switch finding.severity {
            case .critical: severityIcon = "🔴"
            case .error: severityIcon = "🟠"
            case .warning: severityIcon = "🟡"
            case .info: severityIcon = "🔵"
            }

            print("\n\(index + 1). \(severityIcon) \(finding.problemKind)")
            print("   File: \(finding.filePath)")

            if let lineStart = finding.lineStart {
                if let lineEnd = finding.lineEnd, lineEnd != lineStart {
                    print("   Lines: \(lineStart)-\(lineEnd)")
                } else {
                    print("   Line: \(lineStart)")
                }
            }

            print("   Description: \(finding.description)")

            if let suggestedFix = finding.suggestedFix {
                print("   Suggested fix: \(suggestedFix)")
            }

            if let taskId = finding.taskId {
                print("   Task: \(taskId)")
            }

            print(
                "   Created: \(finding.createdAt.formatted(date: .abbreviated, time: .shortened))")
        }

        // Show summary
        var severityCounts: [ScoutFindingSeverity: Int] = [:]
        for finding in findings {
            severityCounts[finding.severity, default: 0] += 1
        }

        print("\n📊 Summary by severity:")
        for severity in [ScoutFindingSeverity.critical, .error, .warning, .info] {
            if let count = severityCounts[severity], count > 0 {
                let icon: String
                switch severity {
                case .critical: icon = "🔴"
                case .error: icon = "🟠"
                case .warning: icon = "🟡"
                case .info: icon = "🔵"
                }
                print("   \(icon) \(severity.rawValue.capitalized): \(count)")
            }
        }
    }
}
