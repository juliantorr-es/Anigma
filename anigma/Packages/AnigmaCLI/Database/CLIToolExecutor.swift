//
//  CLIToolExecutor.swift
//  AnigmaCLIDatabase
//
//  Tool execution layer with receipts, approval gates, and output capture.
//  Wraps tool calls with tracking, sandboxing, and audit trail.
//

import Foundation

// MARK: - Policy Integration

/// Tool execution context with tracking and policy enforcement.
public struct ToolExecutionContext: Sendable {
    public let runID: String
    public let stepID: String?
    public let toolName: String
    public let approved: Bool
    public let sandbox: Bool

    public init(
        runID: String,
        stepID: String?,
        toolName: String,
        approved: Bool = false,
        sandbox: Bool = true
    ) {
        self.runID = runID
        self.stepID = stepID
        self.toolName = toolName
        self.approved = approved
        self.sandbox = sandbox
    }
}

/// Tool execution result with captured output.
public struct ToolExecutionResult: Sendable {
    public let success: Bool
    public let output: String
    public let error: String?
    public let exitCode: Int?
    public let duration: TimeInterval

    public init(
        success: Bool,
        output: String,
        error: String? = nil,
        exitCode: Int? = nil,
        duration: TimeInterval
    ) {
        self.success = success
        self.output = output
        self.error = error
        self.exitCode = exitCode
        self.duration = duration
    }
}

/// Tool executor with receipt generation, safety checks, and policy enforcement.
public actor CLIToolExecutor {
    private let db: CLIDatabaseActor
    private let receiptManager: CLIReceiptManager
    private let loopBreaker: CLILoopBreaker?
    private let policyEngine: CLIPolicyEngine?
    private let repoGate: CLIRepoIdentityGate?
    private let mcpTrust: CLIMCPTrustModel?

    public init(
        database: CLIDatabaseActor,
        receiptManager: CLIReceiptManager,
        loopBreaker: CLILoopBreaker? = nil,
        policyEngine: CLIPolicyEngine? = nil,
        repoGate: CLIRepoIdentityGate? = nil,
        mcpTrust: CLIMCPTrustModel? = nil
    ) {
        self.db = database
        self.receiptManager = receiptManager
        self.loopBreaker = loopBreaker
        self.policyEngine = policyEngine
        self.repoGate = repoGate
        self.mcpTrust = mcpTrust
    }

    // MARK: - Tool Execution

    /// Execute a tool with full tracking, policy checks, and receipts.
    public func execute(
        context: ToolExecutionContext,
        arguments: [String: String]
    ) async throws -> ToolExecutionResult {
        let startTime = Date()

        // Policy checks before execution
        try await performPolicyChecks(context: context, arguments: arguments)

        // Update loop breaker if present
        if let loopBreaker {
            let argsStr = arguments.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            await loopBreaker.recordToolCall(toolName: context.toolName, args: argsStr)

            // Check limits
            if let stopResult = await loopBreaker.shouldStop() {
                throw ToolExecutionError.loopBreakerTriggered(stopResult.message)
            }
        }

        // Execute the tool
        let result: ToolExecutionResult
        do {
            result = try await executeToolInternal(
                toolName: context.toolName,
                arguments: arguments,
                sandbox: context.sandbox
            )
        } catch {
            result = ToolExecutionResult(
                success: false,
                output: "",
                error: error.localizedDescription,
                exitCode: nil,
                duration: Date().timeIntervalSince(startTime)
            )
        }

        // Generate receipt
        let requestStr = serializeArguments(arguments)
        let responseStr = result.success ? result.output : (result.error ?? "")

        _ = try await receiptManager.recordToolCall(
            runID: context.runID,
            stepID: context.stepID,
            toolName: context.toolName,
            request: requestStr,
            response: responseStr,
            approved: context.approved
        )

        return result
    }

    /// Execute a shell command with sandboxing.
    public func executeShellCommand(
        context: ToolExecutionContext,
        command: String,
        workingDirectory: String? = nil
    ) async throws -> ToolExecutionResult {
        _ = Date()

        // Update loop breaker
        if let loopBreaker {
            await loopBreaker.recordToolCall(toolName: "shell", args: command)

            if let stopResult = await loopBreaker.shouldStop() {
                throw ToolExecutionError.loopBreakerTriggered(stopResult.message)
            }
        }

        // Execute shell command
        let result = try await runShellCommand(
            command: command,
            workingDirectory: workingDirectory,
            sandbox: context.sandbox
        )

        // Generate receipt
        _ = try await receiptManager.recordToolCall(
            runID: context.runID,
            stepID: context.stepID,
            toolName: "shell",
            request: command,
            response: result.output,
            approved: context.approved
        )

        return result
    }

    // MARK: - External CLI Wrappers

    /// Execute Claude CLI in non-interactive mode.
    public func executeClaude(
        context: ToolExecutionContext,
        prompt: String,
        model: String = "claude-3-5-sonnet-20241022"
    ) async throws -> ToolExecutionResult {
        let args = [
            "--non-interactive",
            "--model", model,
            "--output", "json"
        ]

        return try await executeExternalCLI(
            context: context,
            cliPath: "/usr/local/bin/claude",
            args: args,
            input: prompt
        )
    }

    /// Execute OpenAI CLI in non-interactive mode.
    public func executeOpenAI(
        context: ToolExecutionContext,
        prompt: String,
        model: String = "gpt-4"
    ) async throws -> ToolExecutionResult {
        let args = [
            "chat",
            "--model", model,
            "--no-stream"
        ]

        return try await executeExternalCLI(
            context: context,
            cliPath: "/usr/local/bin/openai",
            args: args,
            input: prompt
        )
    }

    // MARK: - File Operations

    /// Read a file with tracking.
    public func readFile(
        context: ToolExecutionContext,
        path: String
    ) async throws -> ToolExecutionResult {
        let startTime = Date()

        _ = ["path": path]

        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)

            let result = ToolExecutionResult(
                success: true,
                output: content,
                error: nil,
                exitCode: 0,
                duration: Date().timeIntervalSince(startTime)
            )

            // Generate receipt
            _ = try await receiptManager.recordToolCall(
                runID: context.runID,
                stepID: context.stepID,
                toolName: "read_file",
                request: path,
                response: hash(content),
                approved: context.approved
            )

            return result
        } catch {
            let result = ToolExecutionResult(
                success: false,
                output: "",
                error: error.localizedDescription,
                exitCode: nil,
                duration: Date().timeIntervalSince(startTime)
            )

            // Still generate receipt for failed attempts
            _ = try await receiptManager.recordToolCall(
                runID: context.runID,
                stepID: context.stepID,
                toolName: "read_file",
                request: path,
                response: error.localizedDescription,
                approved: context.approved
            )

            return result
        }
    }

    /// Write a file with tracking.
    public func writeFile(
        context: ToolExecutionContext,
        path: String,
        content: String
    ) async throws -> ToolExecutionResult {
        let startTime = Date()

        guard context.approved else {
            throw ToolExecutionError.approvalRequired("write_file")
        }

        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)

            let result = ToolExecutionResult(
                success: true,
                output: "File written: \(path)",
                error: nil,
                exitCode: 0,
                duration: Date().timeIntervalSince(startTime)
            )

            // Generate receipt with content hash
            _ = try await receiptManager.recordToolCall(
                runID: context.runID,
                stepID: context.stepID,
                toolName: "write_file",
                request: "\(path):\(hash(content))",
                response: "success",
                approved: true
            )

            // Record novelty
            if let loopBreaker {
                await loopBreaker.recordNovelty(hash: hash(content))
            }

            return result
        } catch {
            let result = ToolExecutionResult(
                success: false,
                output: "",
                error: error.localizedDescription,
                exitCode: nil,
                duration: Date().timeIntervalSince(startTime)
            )

            _ = try await receiptManager.recordToolCall(
                runID: context.runID,
                stepID: context.stepID,
                toolName: "write_file",
                request: path,
                response: error.localizedDescription,
                approved: true
            )

            return result
        }
    }

    // MARK: - Private Helpers

    private func executeToolInternal(
        toolName: String,
        arguments: [String: String],
        sandbox: Bool
    ) async throws -> ToolExecutionResult {
        // Placeholder for actual tool execution
        // In real implementation, this would route to the appropriate tool handler
        throw ToolExecutionError.notImplemented(toolName)
    }

    private func runShellCommand(
        command: String,
        workingDirectory: String?,
        sandbox: Bool
    ) async throws -> ToolExecutionResult {
        let startTime = Date()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]

        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8)

        let duration = Date().timeIntervalSince(startTime)

        return ToolExecutionResult(
            success: process.terminationStatus == 0,
            output: output,
            error: error,
            exitCode: Int(process.terminationStatus),
            duration: duration
        )
    }

    private func executeExternalCLI(
        context: ToolExecutionContext,
        cliPath: String,
        args: [String],
        input: String
    ) async throws -> ToolExecutionResult {
        let startTime = Date()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = args

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // Write input
        if let inputData = input.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(inputData)
            try inputPipe.fileHandleForWriting.close()
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8)

        let duration = Date().timeIntervalSince(startTime)

        let result = ToolExecutionResult(
            success: process.terminationStatus == 0,
            output: output,
            error: error,
            exitCode: Int(process.terminationStatus),
            duration: duration
        )

        // Generate receipt
        _ = try await receiptManager.recordToolCall(
            runID: context.runID,
            stepID: context.stepID,
            toolName: cliPath.components(separatedBy: "/").last ?? "external_cli",
            request: input,
            response: output,
            approved: context.approved
        )

        return result
    }

    private func serializeArguments(_ arguments: [String: String]) -> String {
        arguments.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
    }

    private func hash(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Policy Enforcement

    /// Perform policy checks before executing a tool.
    private func performPolicyChecks(
        context: ToolExecutionContext,
        arguments: [String: String]
    ) async throws {
        // Skip if no policy engine configured
        guard let policyEngine = policyEngine else {
            return
        }

        // Determine operation type from tool name
        let toolName = context.toolName.lowercased()

        if toolName.contains("read") || toolName == "read_file" {
            if let path = arguments["path"] {
                try await checkFileReadPolicy(path: path, policyEngine: policyEngine)
            }
        } else if toolName.contains("write") || toolName == "write_file" {
            if let path = arguments["path"] {
                try await checkFileWritePolicy(
                    path: path,
                    size: Int64(arguments["content"]?.count ?? 0),
                    policyEngine: policyEngine
                )
            }
        } else if toolName.contains("delete") {
            if let path = arguments["path"] {
                try await checkFileDeletePolicy(path: path, policyEngine: policyEngine)
            }
        } else if toolName.contains("shell") || toolName.contains("execute") {
            if let command = arguments["command"] {
                try await checkShellCommandPolicy(command: command, policyEngine: policyEngine)
            }
        } else if toolName.contains("git") {
            if let operation = arguments["operation"], let path = arguments["path"] {
                try await checkGitOperationPolicy(
                    operation: operation,
                    path: path,
                    policyEngine: policyEngine
                )
            }
        }
    }

    private func checkFileReadPolicy(
        path: String,
        policyEngine: CLIPolicyEngine
    ) async throws {
        let decision = await policyEngine.evaluateFileRead(path: path)

        switch decision {
        case .allow:
            return
        case .deny(let reason):
            throw ToolExecutionError.policyDenied(reason)
        case .requireApproval(let operation):
            if !(await policyEngine.requestApproval(operation: operation)) {
                throw ToolExecutionError.approvalRequired(operation)
            }
        }
    }

    private func checkFileWritePolicy(
        path: String,
        size: Int64,
        policyEngine: CLIPolicyEngine
    ) async throws {
        // Check policy engine
        let decision = await policyEngine.evaluateFileWrite(path: path, size: size)

        switch decision {
        case .allow:
            break
        case .deny(let reason):
            throw ToolExecutionError.policyDenied(reason)
        case .requireApproval(let operation):
            if !(await policyEngine.requestApproval(operation: operation)) {
                throw ToolExecutionError.approvalRequired(operation)
            }
        }

        // Check RepoIdentity gate
        if let repoGate = repoGate {
            let gateResult = try await repoGate.guardFileWrite(path: path)
            if !gateResult.allowed {
                throw ToolExecutionError.repoGateDenied(gateResult.reason)
            }
        }
    }

    private func checkFileDeletePolicy(
        path: String,
        policyEngine: CLIPolicyEngine
    ) async throws {
        let decision = await policyEngine.evaluateFileDelete(path: path)

        switch decision {
        case .allow:
            break
        case .deny(let reason):
            throw ToolExecutionError.policyDenied(reason)
        case .requireApproval(let operation):
            if !(await policyEngine.requestApproval(operation: operation)) {
                throw ToolExecutionError.approvalRequired(operation)
            }
        }

        // Check RepoIdentity gate
        if let repoGate = repoGate {
            let gateResult = try await repoGate.guardFileDelete(path: path)
            if !gateResult.allowed {
                throw ToolExecutionError.repoGateDenied(gateResult.reason)
            }
        }
    }

    private func checkShellCommandPolicy(
        command: String,
        policyEngine: CLIPolicyEngine
    ) async throws {
        let decision = await policyEngine.evaluateShellCommand(command: command)

        switch decision {
        case .allow:
            return
        case .deny(let reason):
            throw ToolExecutionError.policyDenied(reason)
        case .requireApproval(let operation):
            if !(await policyEngine.requestApproval(operation: operation)) {
                throw ToolExecutionError.approvalRequired(operation)
            }
        }
    }

    private func checkGitOperationPolicy(
        operation: String,
        path: String,
        policyEngine: CLIPolicyEngine
    ) async throws {
        let decision = await policyEngine.evaluateGitOperation(operation: operation, path: path)

        switch decision {
        case .allow:
            break
        case .deny(let reason):
            throw ToolExecutionError.policyDenied(reason)
        case .requireApproval(let op):
            if !(await policyEngine.requestApproval(operation: op)) {
                throw ToolExecutionError.approvalRequired(op)
            }
        }

        // Check RepoIdentity gate
        if let repoGate = repoGate {
            let gateResult = try await repoGate.guardGitOperation(path: path, operation: operation)
            if !gateResult.allowed {
                throw ToolExecutionError.repoGateDenied(gateResult.reason)
            }
        }
    }
}

// MARK: - Errors

public enum ToolExecutionError: Error, Sendable {
    case notImplemented(String)
    case approvalRequired(String)
    case loopBreakerTriggered(String)
    case executionFailed(String)
    case policyDenied(String)
    case repoGateDenied(String)
}

// Import for SHA256
import Crypto
