//
//  ModernTaskTool.swift
//  HarmoniaModule
//
//  Modern implementation of the task tool for spawning subagents.
//  Replaces and extends the legacy DelegateTool with session nesting.
//

import AnigmaPrimitives
import AnigmaCLICore
import AnigmaCLIOrchestrator
@preconcurrency import Foundation

public struct ModernTaskTool: Tool {
    public static let id = "task"
    public static let description = "Spawn a subagent to handle a specific sub-task. Creates a child session."

    public struct Parameters: Codable, Sendable {
        public let summary: String
        public let details: String?
        public let providerId: String?
        public let dryRun: Bool?

        public init(summary: String, details: String? = nil, providerId: String? = nil, dryRun: Bool? = true) {
            self.summary = summary
            self.details = details
            self.providerId = providerId
            self.dryRun = dryRun
        }
    }

    public struct Metadata: Codable, Sendable {
        public let childSessionId: String
        public let status: String
        public let providerId: String?
    }

    private let orchestrator: AnigmaCLIOrchestrator

    public init(orchestrator: AnigmaCLIOrchestrator = AnigmaCLIOrchestrator()) {
        self.orchestrator = orchestrator
    }

    public func execute(params: Parameters, context: ToolContext) async throws -> ToolResult<Metadata> {
        // 1. Notify parent about child task
        await context.updateMetadata(["child_task_started": params.summary])

        // 2. Prepare sub-task
        let taskIntent = TaskIntent(
            summary: params.summary,
            details: params.details,
            source: .mcp
        )

        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let taskContext = AnigmaCLICore.TaskContext(repoRoot: rootURL, worktreeRoot: rootURL)

        // 3. Run the sub-task via orchestrator
        // In Phase 4, we primarily 'plan' and then optionally 'run' if not dry-run.
        let dryRun = params.dryRun ?? true

        let result = try await orchestrator.run(
            task: taskIntent,
            context: taskContext,
            dryRun: dryRun
        )

        let metadata = Metadata(
            childSessionId: taskIntent.id.uuidString,
            status: result.status.rawValue,
            providerId: result.plan.route.selected?.id
        )

        return ToolResult(
            title: "Sub-task: \(params.summary)",
            output: "Child task [\(taskIntent.id.uuidString)] completed with status: \(result.status.rawValue). \(result.message)",
            metadata: metadata
        )
    }
}
