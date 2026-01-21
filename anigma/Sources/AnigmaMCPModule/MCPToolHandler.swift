//
//  MCPToolHandler.swift
//  AnigmaMCPModule
//
//  Abstract tool handler with built-in metrics, streaming, and error handling.
//

import Foundation
import MCP

/// Tool execution result with metrics and metadata
public struct MCPToolExecutionResult: Sendable {
    public let text: String
    public let isError: Bool
    public let durationMs: Int
    public let cacheHit: Bool
    public let streamedUpdates: Int

    public init(
        text: String,
        isError: Bool,
        durationMs: Int,
        cacheHit: Bool = false,
        streamedUpdates: Int = 0
    ) {
        self.text = text
        self.isError = isError
        self.durationMs = durationMs
        self.cacheHit = cacheHit
        self.streamedUpdates = streamedUpdates
    }

    /// Convert to MCP CallTool.Result
    func toMCPResult() -> CallTool.Result {
        CallTool.Result(content: [.text(text)], isError: isError)
    }
}

/// Tool handler protocol for implementing tools with instrumentation
public protocol MCPToolHandler: Sendable {
    /// Tool name for identification
    var toolName: String { get }

    /// Execute the tool with given arguments
    /// Implementations should throw MCPToolError for structured errors
    func execute(arguments: [String: Value]?) async throws -> MCPToolExecutionResult
}

/// Base tool handler with metrics and error handling wired in
public actor MCPBaseToolHandler: MCPToolHandler {
    public let toolName: String
    private let metrics: MCPMetrics?
    private let progressTracker: ProgressTracker?

    public init(
        toolName: String,
        metrics: MCPMetrics? = nil,
        progressTracker: ProgressTracker? = nil
    ) {
        self.toolName = toolName
        self.metrics = metrics
        self.progressTracker = progressTracker
    }

    /// Execute with automatic metrics and error handling
    public func execute(arguments: [String: Value]?) async throws -> MCPToolExecutionResult {
        let startTime = Date()

        do {
            // Emit initializing phase
            await progressTracker?.startPhase(.initializing, message: "Starting \(toolName)")

            // Call implementation
            let result = try await executeImpl(arguments: arguments)

            let duration = Date().timeIntervalSince(startTime)
            let durationMs = Int(duration * 1000)

            // Record metrics
            if let metrics = metrics {
                await metrics.recordToolExecution(
                    toolName: toolName,
                    success: true,
                    durationMs: durationMs,
                    cacheHit: result.cacheHit
                )
            }

            // Emit completion phase
            await progressTracker?.completePhase(message: "Completed in \(durationMs)ms")

            return result
        } catch let error as MCPToolError {
            let duration = Date().timeIntervalSince(startTime)
            let durationMs = Int(duration * 1000)

            // Record error metrics
            if let metrics = metrics {
                await metrics.recordToolExecution(
                    toolName: toolName,
                    success: false,
                    durationMs: durationMs
                )
            }

            // Emit error phase
            await progressTracker?.error(error.errorDescription ?? error.message)

            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let durationMs = Int(duration * 1000)

            // Record unknown error
            if let metrics = metrics {
                await metrics.recordToolExecution(
                    toolName: toolName,
                    success: false,
                    durationMs: durationMs
                )
            }

            // Emit error phase
            await progressTracker?.error("Unknown error: \(error)")

            throw MCPToolError.internalError(
                tool: toolName,
                reason: error.localizedDescription,
                details: String(describing: error)
            )
        }
    }

    /// Override this to implement tool logic
    func executeImpl(arguments: [String: Value]?) async throws -> MCPToolExecutionResult {
        throw MCPToolError.notImplemented(tool: toolName)
    }

    /// Helper to extract string argument
    func getStringArgument(
        _ arguments: [String: Value]?,
        name: String,
        required: Bool = true
    ) throws -> String? {
        let value = arguments?[name]?.stringValue

        if required && value == nil {
            throw MCPToolError.missingArgument(tool: toolName, argument: name)
        }

        return value
    }

    /// Helper to extract int argument
    func getIntArgument(
        _ arguments: [String: Value]?,
        name: String,
        defaultValue: Int? = nil
    ) throws -> Int? {
        if let value = arguments?[name]?.intValue {
            return value
        }

        if let defaultValue = defaultValue {
            return defaultValue
        }

        if arguments?[name] != nil {
            throw MCPToolError.argumentTypeMismatch(
                tool: toolName,
                argument: name,
                expected: "integer"
            )
        }

        return nil
    }

    /// Helper to extract double argument
    func getDoubleArgument(
        _ arguments: [String: Value]?,
        name: String,
        defaultValue: Double? = nil
    ) throws -> Double? {
        if let value = arguments?[name]?.doubleValue {
            return value
        }

        if let defaultValue = defaultValue {
            return defaultValue
        }

        if arguments?[name] != nil {
            throw MCPToolError.argumentTypeMismatch(
                tool: toolName,
                argument: name,
                expected: "number"
            )
        }

        return nil
    }

    /// Helper to extract bool argument
    func getBoolArgument(
        _ arguments: [String: Value]?,
        name: String,
        defaultValue: Bool = false
    ) throws -> Bool {
        if let value = arguments?[name]?.boolValue {
            return value
        }

        return defaultValue
    }

    /// Helper to create success result
    func successResult(
        _ text: String,
        durationMs: Int = 0,
        cacheHit: Bool = false,
        streamedUpdates: Int = 0
    ) -> MCPToolExecutionResult {
        MCPToolExecutionResult(
            text: text,
            isError: false,
            durationMs: durationMs,
            cacheHit: cacheHit,
            streamedUpdates: streamedUpdates
        )
    }

    /// Helper to create error result
    func errorResult(
        error: MCPToolError,
        durationMs: Int = 0
    ) -> MCPToolExecutionResult {
        MCPToolExecutionResult(
            text: error.errorDescription ?? error.message,
            isError: true,
            durationMs: durationMs
        )
    }
}

// MARK: - Error Helpers

public extension MCPToolError {
    static func internalError(
        tool: String,
        reason: String,
        details: String? = nil
    ) -> MCPToolError {
        MCPToolError(
            code: .internalError,
            message: "Internal error: \(reason)",
            toolName: tool,
            hint: MCPRecoveryHint(
                action: "Contact support",
                details: "An unexpected error occurred",
                retryable: false
            ),
            details: details
        )
    }

    static func notImplemented(tool: String) -> MCPToolError {
        MCPToolError(
            code: .notImplemented,
            message: "Tool implementation pending",
            toolName: tool,
            hint: MCPRecoveryHint(
                action: "Check back later",
                details: "This tool is not yet implemented"
            )
        )
    }

    static func argumentTypeMismatch(
        tool: String,
        argument: String,
        expected: String
    ) -> MCPToolError {
        MCPToolError(
            code: .argumentTypeMismatch,
            message: "Argument '\(argument)' has wrong type, expected \(expected)",
            toolName: tool,
            hint: MCPRecoveryHint(
                action: "Check argument type",
                details: "The '\(argument)' parameter must be of type \(expected)",
                retryable: true
            )
        )
    }

    static func resourceUnavailable(
        tool: String,
        resource: String
    ) -> MCPToolError {
        MCPToolError(
            code: .resourceUnavailable,
            message: "Required resource '\(resource)' is unavailable",
            toolName: tool,
            hint: MCPRecoveryHint(
                action: "Wait for resource initialization",
                details: "The \(resource) is still loading or failed to initialize",
                retryable: true
            )
        )
    }

    static func processError(
        tool: String,
        process: String,
        exitCode: Int32,
        stderr: String?
    ) -> MCPToolError {
        MCPToolError(
            code: .processExitNonZero,
            message: "\(process) failed with exit code \(exitCode)",
            toolName: tool,
            hint: MCPRecoveryHint(
                action: "Check process output",
                details: stderr ?? "The process exited with non-zero status",
                retryable: true
            ),
            details: stderr
        )
    }
}
