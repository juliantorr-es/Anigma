//
//  ToolsCommand.swift
//  AnigmaCLIExecutable
//
//  Commands for executing and testing tools with tracking.
//

import AnigmaCLICore
import AnigmaCLIDatabase
import ArgumentParser
import Foundation

struct AnigmaToolsCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "tools",
            abstract: "Execute and test tools with tracking.",
            subcommands: [
                ToolsExecCommand.self,
                ToolsListCommand.self,
                ToolsTestCommand.self
            ]
        )
    }
}

// MARK: - Tool Exec

struct ToolsExecCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "exec",
            abstract: "Execute a tool with tracking."
        )
    }

    @Argument(help: "Tool name to execute.")
    var toolName: String

    @Option(name: .long, help: "Tool arguments in key=value format (repeatable).")
    var arg: [String] = []

    @Option(name: .long, help: "Run ID to associate with.")
    var runID: String?

    @Flag(name: .long, help: "Request approval before execution.")
    var approved: Bool = false

    @Flag(name: .long, help: "Disable sandboxing.")
    var noSandbox: Bool = false

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let receiptManager = CLIReceiptManager(database: db)
        let executor = CLIToolExecutor(
            database: db,
            receiptManager: receiptManager
        )

        // Parse arguments
        var arguments: [String: String] = [:]
        for argStr in arg {
            let parts = argStr.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                arguments[String(parts[0])] = String(parts[1])
            }
        }

        let actualRunID = runID ?? UUID().uuidString

        let context = ToolExecutionContext(
            runID: actualRunID,
            stepID: nil,
            toolName: toolName,
            approved: approved,
            sandbox: !noSandbox
        )

        print("🔧 Executing tool: \(toolName)")
        if !arguments.isEmpty {
            print("   Arguments: \(arguments)")
        }
        print("   Run ID: \(actualRunID.prefix(8))")
        print("   Approved: \(approved)")
        print("   Sandbox: \(!noSandbox)")
        print("")

        do {
            let result = try await executor.execute(
                context: context,
                arguments: arguments
            )

            if result.success {
                print("✅ Tool executed successfully (\(String(format: "%.2f", result.duration))s)")
                print("")
                print("Output:")
                print(result.output)
            } else {
                print("❌ Tool execution failed (\(String(format: "%.2f", result.duration))s)")
                if let error = result.error {
                    print("")
                    print("Error:")
                    print(error)
                }
                throw ExitCode.failure
            }
        } catch ToolExecutionError.notImplemented(let tool) {
            print("❌ Tool not implemented: \(tool)")
            print("   Available: read_file, write_file, shell")
            throw ExitCode.failure
        } catch {
            print("❌ Execution error: \(error)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Tool List

struct ToolsListCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "list",
            abstract: "List available tools."
        )
    }

    mutating func run() async throws {
        print("🔧 Available Tools:\n")

        let tools = [
            ("read_file", "Read file contents with tracking", "path=<file>"),
            ("write_file", "Write file contents (requires approval)", "path=<file> content=<text>"),
            ("shell", "Execute shell command", "command=<cmd>"),
            ("claude", "Execute Claude CLI", "prompt=<text> [model=<model>]"),
            ("openai", "Execute OpenAI CLI", "prompt=<text> [model=<model>]")
        ]

        for (name, description, args) in tools {
            print("  \(name)")
            print("    \(description)")
            print("    Args: \(args)")
            print("")
        }
    }
}

// MARK: - Tool Test

struct ToolsTestCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "test",
            abstract: "Test tool execution with tracking."
        )
    }

    @Option(name: .long, help: "Test scenario (read|write|shell).")
    var scenario: String = "read"

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let receiptManager = CLIReceiptManager(database: db)
        let runManager = CLIRunManager(database: db, receiptManager: receiptManager)
        let executor = CLIToolExecutor(
            database: db,
            receiptManager: receiptManager
        )

        print("🧪 Tool Execution Test: \(scenario)\n")

        // Create a test run
        let run = try await runManager.createRun(
            taskSummary: "Tool execution test: \(scenario)",
            taskDetails: nil,
            mode: .run,
            dryRun: true,
            worktreePath: nil
        )

        print("Created test run: \(run.runID.prefix(8))\n")

        let context = ToolExecutionContext(
            runID: run.runID,
            stepID: nil,
            toolName: scenario,
            approved: true,
            sandbox: false
        )

        switch scenario {
        case "read":
            try await testReadFile(executor: executor, context: context)

        case "write":
            try await testWriteFile(executor: executor, context: context)

        case "shell":
            try await testShellCommand(executor: executor, context: context)

        default:
            print("❌ Unknown scenario: \(scenario)")
            print("   Valid options: read, write, shell")
            throw ExitCode.failure
        }

        // Show receipts
        print("\n🧾 Generated Receipts:")
        let receipts = try await receiptManager.listReceipts(runID: run.runID)
        for receipt in receipts {
            print("  [\(receipt.type.rawValue)] \(receipt.metadata)")
        }
    }

    private func testReadFile(executor: CLIToolExecutor, context: ToolExecutionContext) async throws {
        print("Testing read_file...")

        // Create a temp file
        let tempPath = NSTemporaryDirectory() + "test-\(UUID().uuidString).txt"
        let testContent = "Hello from anigma-cli tool test!"
        try testContent.write(toFile: tempPath, atomically: true, encoding: .utf8)

        print("Created temp file: \(tempPath)")

        let result = try await executor.readFile(context: context, path: tempPath)

        if result.success {
            print("✅ Read successful (\(String(format: "%.2f", result.duration))s)")
            print("   Content: \(result.output)")
        } else {
            print("❌ Read failed: \(result.error ?? "unknown")")
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempPath)
    }

    private func testWriteFile(executor: CLIToolExecutor, context: ToolExecutionContext) async throws {
        print("Testing write_file...")

        let tempPath = NSTemporaryDirectory() + "test-write-\(UUID().uuidString).txt"
        let content = "Written by anigma-cli at \(Date())"

        let result = try await executor.writeFile(
            context: context,
            path: tempPath,
            content: content
        )

        if result.success {
            print("✅ Write successful (\(String(format: "%.2f", result.duration))s)")
            print("   File: \(tempPath)")

            // Verify
            let readBack = try String(contentsOfFile: tempPath, encoding: .utf8)
            print("   Verified: \(readBack == content ? "✅" : "❌")")
        } else {
            print("❌ Write failed: \(result.error ?? "unknown")")
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempPath)
    }

    private func testShellCommand(executor: CLIToolExecutor, context: ToolExecutionContext) async throws {
        print("Testing shell command...")

        let result = try await executor.executeShellCommand(
            context: context,
            command: "echo 'Hello from shell' && date",
            workingDirectory: nil
        )

        if result.success {
            print("✅ Shell command successful (\(String(format: "%.2f", result.duration))s)")
            print("   Output:")
            print(result.output)
        } else {
            print("❌ Shell command failed: \(result.error ?? "unknown")")
        }
    }
}
