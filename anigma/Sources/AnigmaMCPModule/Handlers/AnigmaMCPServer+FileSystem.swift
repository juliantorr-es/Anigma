//
//  AnigmaMCPServer+FileSystem.swift
//  AnigmaMCPModule
//
//  File system related tool handlers for MCP.
//

import Foundation
import MCP
import AnigmaCore
import PolytroposModule
import AnigmaPrimitives
import ContractsCore

extension AnigmaMCPServer {
    func handleReadFile(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        guard let path = arguments?["file_path"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing path")], isError: true)
        }

        var params: [String: Any] = ["file_path": path]
        if let cache = arguments?["cache"]?.boolValue {
            params["cache"] = cache
        }

        await progress?.startPhase(.processing, message: "Reading \(path)")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: path)

        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        let tool = ReadFileTool()
        let result = await tool.execute(
            ToolCallRequest(toolName: "read_file", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(
                sessionId: "mcp",
                agentId: "mcp",
                permissions: Set(Permission.allCases)
            )
        )
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: path)
        return result.mcpResult
    }

    func handleSwiftBuild(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        let path = arguments?["package_path"]?.stringValue ?? FileManager.default.currentDirectoryPath
        let target = arguments?["target"]?.stringValue
        let configuration = arguments?["configuration"]?.stringValue

        var params: [String: Any] = ["package_path": path]
        if let target = target { params["target"] = target }
        if let configuration = configuration { params["configuration"] = configuration }
        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        let trackerRef = progress
        let progressCallback: ToolProgressCallback? = if trackerRef == nil {
            nil
        } else {
            { processed, total, message in
                guard let tracker = trackerRef else { return }
                await tracker.updateProgress(itemsProcessed: processed, totalItems: total, currentItem: message)
            }
        }
        let tool = SwiftBuildTool(progressCallback: progressCallback)
        let result = await tool.execute(
            ToolCallRequest(toolName: "swift_build", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(
                sessionId: "mcp",
                agentId: "mcp",
                permissions: Set(Permission.allCases),
                allowGovernedBuild: true
            )
        )
        return result.mcpResult
    }

    func handleApplyPatch(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        guard let patch = arguments?["patch"]?.stringValue else { return CallTool.Result(content: [.text("Missing patch")], isError: true) }
        let trackerRef = progress
        let progressCallback: ToolProgressCallback? = if trackerRef == nil {
            nil
        } else {
            { processed, total, message in
                guard let tracker = trackerRef else { return }
                await tracker.updateProgress(itemsProcessed: processed, totalItems: total, currentItem: message)
            }
        }
        let tool = ApplyPatchTool(progressCallback: progressCallback)
        var params: [String: Any] = ["patch": patch]
        if let targetFiles = arguments?["target_files"]?.arrayValue?.compactMap({ $0.stringValue }),
           !targetFiles.isEmpty {
            params["target_files"] = targetFiles
        }
        if let rollback = arguments?["rollback_on_failure"]?.boolValue {
            params["rollback_on_failure"] = rollback
        }
        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"
        let result = await tool.execute(
            ToolCallRequest(toolName: "apply_patch", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases))
        )
        return result.mcpResult
    }

    func handleGitDiff(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        let path = arguments?["path"]?.stringValue ?? ""
        await progress?.startPhase(.analyzing, message: "Computing git diff")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Gathering diff")
        let tool = GitDiffTool()
        let result = await tool.execute(ToolCallRequest(toolName: "git_diff", sessionId: "mcp", parameters: "{\"path\":\"\(path)\"}"), session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases)))
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 2, currentItem: "Analyzing diff")
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Diff ready")
        return result.mcpResult
    }

    func handleSwiftTest(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        let filter = arguments?["filter"]?.stringValue ?? ""
        let verbose = arguments?["verbose"]?.boolValue
        var params: [String: Any] = ["filter": filter]
        if let verbose = verbose { params["verbose"] = verbose }
        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        let tool = SwiftTestTool()
        await progress?.startPhase(.processing, message: "Running Swift tests")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Preparing tests")
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 2, currentItem: "Executing tests")
        let result = await tool.execute(
            ToolCallRequest(toolName: "swift_test", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(
                sessionId: "mcp",
                agentId: "mcp",
                permissions: Set(Permission.allCases),
                allowGovernedBuild: true
            )
        )
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Tests finished")
        return result.mcpResult
    }
}
