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

        await progress?.startPhase(.processing, message: "Reading \(path)")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: path)
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: path)
            return CallTool.Result(content: [.text(content)])
        } catch {
            return CallTool.Result(content: [.text("Read failed: \(error)")], isError: true)
        }
    }

    func handleSwiftBuild(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        let path = arguments?["package_path"]?.stringValue ?? FileManager.default.currentDirectoryPath
        let target = arguments?["target"]?.stringValue
        let configuration = arguments?["configuration"]?.stringValue

        await progress?.startPhase(.compiling, message: "Running swift build")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: path)
        var commandArgs = ["build"]
        if let target, !target.isEmpty {
            commandArgs += ["--target", target]
        }
        if let configuration, !configuration.isEmpty {
            commandArgs += ["-c", configuration]
        }

        do {
            let (status, stdout, stderr) = try await runCommand("/usr/bin/env", arguments: ["swift"] + commandArgs, currentDirectory: path)
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: path)
            let output = [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
            return CallTool.Result(content: [.text(output.isEmpty ? "swift build exited \(status)" : output)], isError: status != 0)
        } catch {
            return CallTool.Result(content: [.text("swift build failed to launch: \(error)")], isError: true)
        }
    }

    func handleApplyPatch(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        guard arguments?["patch"]?.stringValue != nil else {
            return CallTool.Result(content: [.text("Missing patch")], isError: true)
        }
        await progress?.startPhase(.processing, message: "apply_patch is unavailable in MCP compatibility mode")
        await progress?.completePhase(message: "Patch request recorded")
        return CallTool.Result(
            content: [.text("apply_patch is not supported by the compile-safe MCP compatibility layer")],
            isError: true
        )
    }

    func handleGitDiff(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        let path = arguments?["path"]?.stringValue ?? ""
        await progress?.startPhase(.analyzing, message: "Computing git diff")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Gathering diff")
        let cwd = path.isEmpty ? FileManager.default.currentDirectoryPath : path
        let result: CallTool.Result
        do {
            let (status, stdout, stderr) = try await runCommand("/usr/bin/env", arguments: ["git", "diff", "--", path], currentDirectory: cwd)
            let output = [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
            result = CallTool.Result(content: [.text(output.isEmpty ? "No diff output" : output)], isError: status != 0)
        } catch {
            result = CallTool.Result(content: [.text("git diff failed: \(error)")], isError: true)
        }
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 2, currentItem: "Analyzing diff")
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Diff ready")
        return result
    }

    func handleSwiftTest(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        let filter = arguments?["filter"]?.stringValue ?? ""
        let verbose = arguments?["verbose"]?.boolValue
        await progress?.startPhase(.processing, message: "Running Swift tests")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Preparing tests")
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 2, currentItem: "Executing tests")
        var commandArgs = ["test"]
        if !filter.isEmpty {
            commandArgs += ["--filter", filter]
        }
        if verbose == true {
            commandArgs.append("--verbose")
        }
        let result: CallTool.Result
        do {
            let (status, stdout, stderr) = try await runCommand("/usr/bin/env", arguments: ["swift"] + commandArgs, currentDirectory: FileManager.default.currentDirectoryPath)
            let output = [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
            result = CallTool.Result(content: [.text(output.isEmpty ? "swift test exited \(status)" : output)], isError: status != 0)
        } catch {
            result = CallTool.Result(content: [.text("swift test failed to launch: \(error)")], isError: true)
        }
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Tests finished")
        return result
    }
}
