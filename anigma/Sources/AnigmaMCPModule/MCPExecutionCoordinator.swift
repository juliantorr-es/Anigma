//
//  MCPExecutionCoordinator.swift
//  AnigmaMCPModule
//
//  Centralized tool execution with metrics, streaming, parallelization, and error handling.
//

import Foundation
import OSLog
import MCP
import AnigmaPrimitives
import AnigmaEvents
import TelemetryCore

/// Execution context for a tool call
public struct MCPExecutionContext: Sendable {
    public let toolName: String
    public let requestId: String
    public let jobId: String?
    public let runId: String?
    public let priority: TaskPriority
    public let timeout: TimeInterval

    public init(
        toolName: String,
        requestId: String = UUID().uuidString,
        jobId: String? = nil,
        runId: String? = nil,
        priority: TaskPriority = .medium,
        timeout: TimeInterval = 30
    ) {
        self.toolName = toolName
        self.requestId = requestId
        self.jobId = jobId
        self.runId = runId
        self.priority = priority
        self.timeout = timeout
    }
}

/// Central coordinator for tool execution
public actor MCPExecutionCoordinator {
    private let logger = Logger(subsystem: "com.anigma.mcp", category: "execution")
    private let metrics: MCPMetrics
    private let progressTracker: ProgressTracker
    private let parallelizer: MCPParallelizationCoordinator
    private var activeTools: Set<String> = []
    private var executionLog: [
        (
            timestamp: Date,
            toolName: String,
            success: Bool,
            durationMs: Int,
            requestId: String,
            jobId: String?,
            runId: String?
        )
    ] = []
    private let maxExecutionLogSize = 1000

    public init(
        metrics: MCPMetrics,
        progressTracker: ProgressTracker
    ) {
        self.metrics = metrics
        self.progressTracker = progressTracker
        self.parallelizer = MCPParallelizationCoordinator(
            config: ParallelExecutionConfig(
                maxConcurrency: 4,
                batchTimeout: 300
            )
        )
    }

    /// Execute a tool with full instrumentation
    public func executeTool(
        name: String,
        arguments: [String: Value]?,
        handler: @escaping @Sendable () async throws -> MCPToolExecutionResult,
        context: MCPExecutionContext? = nil
    ) async -> CallTool.Result {
        let ctx = context ?? MCPExecutionContext(toolName: name)
        let startTime = Date()

        // Track active tool
        activeTools.insert(name)
        defer { activeTools.remove(name) }
        logger.debug(
            "Tool \(name, privacy: .public) started \(self.logContextFields(tool: name, stage: "started", context: ctx), privacy: .public)"
        )

        do {
            // Execute with timeout
            let result = try await withThrowingTaskGroup(of: MCPToolExecutionResult.self) { group in
                // Main execution task
                group.addTask {
                    try await handler()
                }

                // Timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(ctx.timeout * 1_000_000_000))
                    throw MCPToolError.timeout(
                        tool: name,
                        duration: ctx.timeout
                    )
                }

                // Return first result (cancels other task)
                guard let result = try await group.next() else {
                    fatalError("Failed to unwrap result")
                }
                group.cancelAll()
                return result
            }

            let duration = Date().timeIntervalSince(startTime)
            let durationMs = Int(duration * 1000)

            // Record metrics with context
            await metrics.recordToolExecution(
                toolName: name,
                success: true,
                durationMs: durationMs,
                cacheHit: result.cacheHit
            )

            // Log execution with context IDs
            logExecution(tool: name, success: true, durationMs: durationMs, context: ctx)
            await publishEvidence(
                toolName: name,
                context: ctx,
                success: true,
                durationMs: durationMs,
                output: result.text,
                error: nil
            )

            return result.toMCPResult()
        } catch let error as MCPToolError {
            let duration = Date().timeIntervalSince(startTime)
            let durationMs = Int(duration * 1000)

            // Record metrics with context
            await metrics.recordToolExecution(
                toolName: name,
                success: false,
                durationMs: durationMs
            )

            // Log execution with context IDs
            logExecution(tool: name, success: false, durationMs: durationMs, context: ctx, error: error.message)
            await publishEvidence(
                toolName: name,
                context: ctx,
                success: false,
                durationMs: durationMs,
                output: error.errorDescription ?? error.message,
                error: error.message
            )

            // Return error
            return CallTool.Result(
                content: [.text(error.errorDescription ?? error.message)],
                isError: true
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let durationMs = Int(duration * 1000)

            // Record metrics with context
            await metrics.recordToolExecution(
                toolName: name,
                success: false,
                durationMs: durationMs
            )

            // Log execution with context IDs
            logExecution(
                tool: name,
                success: false,
                durationMs: durationMs,
                context: ctx,
                error: error.localizedDescription
            )
            await publishEvidence(
                toolName: name,
                context: ctx,
                success: false,
                durationMs: durationMs,
                output: error.localizedDescription,
                error: error.localizedDescription
            )

            // Convert to structured error
            let toolError = MCPToolError.internalError(
                tool: name,
                reason: error.localizedDescription,
                details: String(describing: error)
            )

            return CallTool.Result(
                content: [.text(toolError.errorDescription ?? toolError.message)],
                isError: true
            )
        }
    }

    /// Get metrics for a specific tool.
    /// Returns `nil` when the tool has not recorded executions yet.
    public func getToolMetrics(_ toolName: String) async -> ToolMetrics? {
        await metrics.getToolMetrics(toolName)
    }

    /// Get all metrics
    public func getAllMetrics() async -> [(String, ToolMetrics)] {
        let allToolMetrics = await metrics.getAllToolMetrics()
        return allToolMetrics.map { ($0.toolName, $0) }
    }

    /// Get execution log
    public func getExecutionLog(limit: Int = 100) -> [(timestamp: Date, toolName: String, success: Bool, durationMs: Int)] {
        executionLog.suffix(limit).map { entry in
            (timestamp: entry.timestamp, toolName: entry.toolName, success: entry.success, durationMs: entry.durationMs)
        }
    }

    /// Get active tools
    public func getActiveTools() -> Set<String> {
        activeTools
    }

    /// Get system status
    public func getSystemStatus() -> MCPSystemStatus {
        let recentTime = Date().timeIntervalSince(Date(timeIntervalSinceNow: -300))  // Last 5 minutes
        return MCPSystemStatus(
            activeToolCount: activeTools.count,
            recentExecutions: UInt64(executionLog.count),
            uptime: recentTime
        )
    }

    /// Private: Log execution with context
    private func logExecution(
        tool: String,
        success: Bool,
        durationMs: Int,
        context: MCPExecutionContext,
        error: String? = nil
    ) {
        executionLog.append((
            timestamp: Date(),
            toolName: tool,
            success: success,
            durationMs: durationMs,
            requestId: context.requestId,
            jobId: context.jobId,
            runId: context.runId
        ))

        // Trim log if too large
        if executionLog.count > maxExecutionLogSize {
            executionLog.removeFirst(executionLog.count - maxExecutionLogSize)
        }

        if success {
            logger.info(
                "Tool \(tool, privacy: .public) completed in \(durationMs, privacy: .public)ms \(self.logContextFields(tool: tool, stage: "completed", context: context, durationMs: durationMs), privacy: .public)"
            )
        } else {
            logger.error(
                "Tool \(tool, privacy: .public) failed in \(durationMs, privacy: .public)ms \(self.logContextFields(tool: tool, stage: "failed", context: context, durationMs: durationMs, error: error), privacy: .public)"
            )
        }
    }

    private func logContextFields(
        tool: String,
        stage: String,
        context: MCPExecutionContext,
        durationMs: Int? = nil,
        error: String? = nil
    ) -> String {
        var parts = [
            "lifecycle_stage=\(stage)",
            "tool_name=\(tool)",
            "request_id=\(context.requestId)"
        ]
        if let jobId = context.jobId {
            parts.append("job_id=\(jobId)")
        }
        if let runId = context.runId {
            parts.append("run_id=\(runId)")
        }
        if let durationMs {
            parts.append("duration_ms=\(durationMs)")
        }
        if let error {
            parts.append("error=\(error)")
        }
        parts.append("priority=\(context.priority)")
        return parts.joined(separator: " ")
    }

    private func publishEvidence(
        toolName: String,
        context: MCPExecutionContext,
        success: Bool,
        durationMs: Int,
        output: String,
        error: String?
    ) async {
        let traceID = TelemetryHash(
            input: "\(toolName)|\(context.requestId)|\(context.runId ?? "-")|\(context.jobId ?? "-")"
        ).hex
        let spanID = TelemetryHash(
            input: "\(toolName)|\(context.requestId)|span"
        ).hex
        let event = AgentEvidenceEvent.toolExecution(
            source: "MCPExecutionCoordinator",
            outcome: success ? "allowed" : "failed",
            traceID: traceID,
            spanID: spanID,
            runID: context.runId,
            sessionID: context.requestId,
            jobID: context.jobId,
            toolID: toolName,
            requestID: context.requestId,
            metadata: [
                "duration_ms": "\(durationMs)",
                "priority": "\(context.priority)",
                "success": String(success),
                "output": output,
                "error": error ?? ""
            ]
        )
        _ = await sharedEventBus.publishWithLogging(event, source: event.source)
    }
}

/// System status snapshot
public struct MCPSystemStatus: Sendable, Codable {
    public let activeToolCount: Int
    public let recentExecutions: UInt64
    public let uptime: TimeInterval

    public init(
        activeToolCount: Int,
        recentExecutions: UInt64,
        uptime: TimeInterval
    ) {
        self.activeToolCount = activeToolCount
        self.recentExecutions = recentExecutions
        self.uptime = uptime
    }
}

/// Handler executor for a specific tool
public struct MCPHandlerExecutor: Sendable {
    private let coordinator: MCPExecutionCoordinator
    private let toolName: String

    public init(
        coordinator: MCPExecutionCoordinator,
        toolName: String
    ) {
        self.coordinator = coordinator
        self.toolName = toolName
    }

    /// Execute handler with coordination
    public func execute(
        arguments: [String: Value]?,
        handler: @escaping @Sendable () async throws -> MCPToolExecutionResult
    ) async -> CallTool.Result {
        let context = MCPExecutionContext(toolName: toolName)
        return await coordinator.executeTool(
            name: toolName,
            arguments: arguments,
            handler: handler,
            context: context
        )
    }

    /// Execute with custom timeout
    public func executeWithTimeout(
        arguments: [String: Value]?,
        timeout: TimeInterval,
        handler: @escaping @Sendable () async throws -> MCPToolExecutionResult
    ) async -> CallTool.Result {
        let context = MCPExecutionContext(
            toolName: toolName,
            timeout: timeout
        )
        return await coordinator.executeTool(
            name: toolName,
            arguments: arguments,
            handler: handler,
            context: context
        )
    }
}

// MARK: - Metrics Access Extensions

public extension MCPExecutionCoordinator {
    /// Get current metrics snapshot (must be called with proper isolation)
    nonisolated func getMetricsSnapshot() async -> [(String, ToolMetrics)] {
        // This would be implemented by storing metrics reference
        return []
    }
}
