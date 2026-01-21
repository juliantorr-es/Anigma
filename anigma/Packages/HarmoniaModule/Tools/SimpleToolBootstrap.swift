//
//  SimpleToolBootstrap.swift
//  HarmoniaModule
//
//  Simple tool bootstrap for harness testing.
//  Registers basic tools without complex dependencies.
//

import Foundation
import AnigmaPrimitives
import AnigmaCLIOrchestrator

// MARK: - Simple Tool Implementations

/// Simple file read tool for testing.
struct FileReadTool: ToolHandlerProtocol {
    private let baseDirectory: String

    init(baseDirectory: String) {
        self.baseDirectory = baseDirectory
    }

    func handle(request: ToolRequest) async throws -> ToolResponse {
        guard let filePath = request.arguments["path"] else {
            return .failure("Missing 'path' parameter", output: "")
        }

        let fullPath = (baseDirectory as NSString).appendingPathComponent(filePath)

        do {
            let content = try String(contentsOfFile: fullPath, encoding: .utf8)
            return .success("File content (first 1000 chars): \(content.prefix(1000))")
        } catch {
            return .failure("Failed to read file: \(error)", output: "")
        }
    }
}

/// Simple file write tool for testing.
struct FileWriteTool: ToolHandlerProtocol {
    private let baseDirectory: String

    init(baseDirectory: String) {
        self.baseDirectory = baseDirectory
    }

    func handle(request: ToolRequest) async throws -> ToolResponse {
        guard let filePath = request.arguments["path"] else {
            return .failure("Missing 'path' parameter", output: "")
        }

        guard let content = request.arguments["content"] else {
            return .failure("Missing 'content' parameter", output: "")
        }

        let fullPath = (baseDirectory as NSString).appendingPathComponent(filePath)

        do {
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
            return .success("File written successfully: \(filePath)")
        } catch {
            return .failure("Failed to write file: \(error)", output: "")
        }
    }
}

/// Simple shell command tool for testing.
struct ShellCommandTool: ToolHandlerProtocol {
    func handle(request: ToolRequest) async throws -> ToolResponse {
        guard let command = request.arguments["command"] else {
            return .failure("Missing 'command' parameter", output: "")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return .success("Command executed successfully:\n\(output)")
            } else {
                return .failure("Command failed with exit code \(process.terminationStatus):\n\(error)", output: output)
            }
        } catch {
            return .failure("Failed to execute command: \(error)", output: "")
        }
    }
}

/// Simple test runner tool for testing.
struct TestRunnerTool: ToolHandlerProtocol {
    func handle(request: ToolRequest) async throws -> ToolResponse {
        // Simulate test execution with random results
        let testPassed = Bool.random()

        if testPassed {
            return .success("All tests passed! ✅")
        } else {
            return .failure("Some tests failed ❌", output: "Test output: Simulated failure")
        }
    }
}

/// Simple git tool for testing.
struct GitTool: ToolHandlerProtocol {
    private let baseDirectory: String

    init(baseDirectory: String) {
        self.baseDirectory = baseDirectory
    }

    func handle(request: ToolRequest) async throws -> ToolResponse {
        guard let action = request.arguments["action"] else {
            return .failure("Missing 'action' parameter", output: "")
        }

        switch action {
        case "status":
            return .success("Git status: On main branch, no changes")
        case "commit":
            let message = request.arguments["message"] ?? "Auto-commit from harness"
            return .success("Committed with message: \(message)")
        case "diff":
            return .success("No changes to diff")
        default:
            return .failure("Unknown git action: \(action)", output: "")
        }
    }
}

// MARK: - Bootstrap Function

/// Bootstraps a simple tool registry with basic tools.
public struct SimpleToolBootstrap {
    /// Configuration for tool bootstrap.
    public struct Config {
        public let projectDirectory: String
        public let enableCodeAnalysis: Bool
        public let mode: Mode

        public enum Mode {
            case simulation  // Stub tools only
            case real        // Real tools where available
        }

        public init(projectDirectory: String, enableCodeAnalysis: Bool = false, mode: Mode = .simulation) {
            self.projectDirectory = projectDirectory
            self.enableCodeAnalysis = enableCodeAnalysis
            self.mode = mode
        }
    }

    /// Configures a tool registry with basic tools for a project.
    public static func configure(
        registry: SimpleToolRegistry,
        config: Config
    ) async throws {
        // Create project directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: config.projectDirectory) {
            try fileManager.createDirectory(atPath: config.projectDirectory, withIntermediateDirectories: true)
        }

        print("🛠️  Configuring tools in mode: \(config.mode)")

        // Register basic tools (always available)
        await registry.register(
            name: "read_file",
            handler: AnyToolHandler(FileReadTool(baseDirectory: config.projectDirectory))
        )

        await registry.register(
            name: "write_file",
            handler: AnyToolHandler(FileWriteTool(baseDirectory: config.projectDirectory))
        )

        await registry.register(
            name: "run_shell",
            handler: AnyToolHandler(ShellCommandTool())
        )

        await registry.register(
            name: "run_tests",
            handler: AnyToolHandler(TestRunnerTool())
        )

        await registry.register(
            name: "git",
            handler: AnyToolHandler(GitTool(baseDirectory: config.projectDirectory))
        )

        // Register modern tools
        await ModernToolRegistry.shared.register(ModernReadFileTool(repoRoot: config.projectDirectory))
        await ModernToolRegistry.shared.register(ModernTaskTool())

        // Register code analysis tools if enabled
        if config.enableCodeAnalysis {
            try await SimpleCodeAnalysisTool.registerTools(
                with: registry,
                projectDirectory: config.projectDirectory
            )
            print("✅ Registered code analysis tools")
        }

        let toolCount = await registry.toolCount
        print("✅ Registered \(toolCount) tools for project at: \(config.projectDirectory)")
    }

    /// Creates a minimal tool registry for testing.
    public static func createMinimalRegistry(config: Config) async throws -> SimpleToolRegistry {
        let registry = SimpleToolRegistry()
        try await configure(registry: registry, config: config)
        return registry
    }
}
