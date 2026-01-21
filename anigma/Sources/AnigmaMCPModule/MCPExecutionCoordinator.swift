//
//  MCPExecutionCoordinator.swift
//  AnigmaMCPModule
//
//  Centralized tool execution with metrics, streaming, parallelization, and error handling.
//

import Foundation
import MCP

/// Execution context for a tool call
public struct MCPExecutionContext: Sendable {
    public let toolName: String
    public let requestId: String
    public let priority: TaskPriority
    public let timeout: TimeInterval

    public init(
        toolName: String,
        requestId: String = UUID().uuidString,
        priority: TaskPriority = .medium,
        timeout: TimeInterval = 30
    ) {
        self.toolName = toolName
        self.requestId = requestId
        self.priority = priority
        self.timeout = timeout
    }
}

/// Central coordinator for tool execution
public actor MCPExecutionCoordinator {
    private let metrics: MCPMetrics
    private let progressTracker: ProgressTracker
    private let parallelizer: MCPParallelizationCoordinator
    private var activeTools: Set<String> = []
    private var executionLog: [(timestamp: Date, toolName: String, success: Bool, durationMs: Int)] = []
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

            // Record metrics
            await metrics.recordToolExecution(
                toolName: name,
                success: true,
                durationMs: durationMs,
                cacheHit: result.cacheHit
            )

            // Log execution
            logExecution(tool: name, success: true, durationMs: durationMs)

            return result.toMCPResult()
        } catch let error as MCPToolError {
            let duration = Date().timeIntervalSince(startTime)
            let durationMs = Int(duration * 1000)

            // Record metrics
            await metrics.recordToolExecution(
                toolName: name,
                success: false,
                durationMs: durationMs
            )

            // Log execution
            logExecution(tool: name, success: false, durationMs: durationMs)

            // Return error
            return CallTool.Result(
                content: [.text(error.errorDescription ?? error.message)],
                isError: true
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let durationMs = Int(duration * 1000)

            // Record metrics
            await metrics.recordToolExecution(
                toolName: name,
                success: false,
                durationMs: durationMs
            )

            // Log execution
            logExecution(tool: name, success: false, durationMs: durationMs)

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

    /// Get metrics for a specific tool
    public func getToolMetrics(_ toolName: String) -> ToolMetrics? {
        // Note: Must be called non-isolated or from async context
        // This is a limitation of actor isolation
        return nil  // Placeholder
    }

    /// Get all metrics
    public func getAllMetrics() -> [(String, ToolMetrics)] {
        // Placeholder - would need to be called properly
        return []
    }

    /// Get execution log
    public func getExecutionLog(limit: Int = 100) -> [(timestamp: Date, toolName: String, success: Bool, durationMs: Int)] {
        Array(executionLog.suffix(limit))
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

    /// Private: Log execution
    private func logExecution(tool: String, success: Bool, durationMs: Int) {
        executionLog.append((timestamp: Date(), toolName: tool, success: success, durationMs: durationMs))

        // Trim log if too large
        if executionLog.count > maxExecutionLogSize {
            executionLog.removeFirst(executionLog.count - maxExecutionLogSize)
        }
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
