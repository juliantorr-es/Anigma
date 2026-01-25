//
//  GitDiffTool.swift
//  HarmoniaModule
//
//  Governed git_diff tool with sandboxing and path restrictions.
//

import AnigmaPrimitives
@preconcurrency import CryptoKit
import DatabaseCore
@preconcurrency import Foundation
import os

public struct GitDiffTool: Sendable {
    private let repoRoot: String

    public init(repoRoot: String = FileManager.default.currentDirectoryPath) {
        self.repoRoot = repoRoot
    }

    public func execute(_ request: ToolCallRequest, session: SessionContext) async
        -> ToolCallResponse {
        let paramsData = Data(request.parameters.utf8)
        let parameters =
            (try? JSONSerialization.jsonObject(with: paramsData) as? [String: Any]) ?? [:]

        // Optional path filter
        let pathFilter = parameters["path"] as? String

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = URL(fileURLWithPath: repoRoot)

        var arguments = ["diff"]
        if let pathFilter = pathFilter, !pathFilter.isEmpty {
            // Basic sandboxing: check if path is within repoRoot (git usually handles this but we're being explicit)
            if pathFilter.contains("..") {
                return ToolCallResponse(
                    status: .failed,
                    toolName: request.toolName,
                    diagnosis: "Security Violation: Path traversal detected in path filter"
                )
            }
            arguments.append(pathFilter)
        }

        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        final class DataAccumulator: Sendable {
            private let data = OSAllocatedUnfairLock(initialState: Data())

            func append(_ chunk: Data) {
                data.withLock { $0.append(chunk) }
            }

            func getData() -> Data {
                data.withLock { $0 }
            }
        }

        let stdoutData = DataAccumulator()
        let stderrData = DataAccumulator()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stdoutData.append(chunk)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stderrData.append(chunk)
            }
        }

        do {
            try process.run()
            process.waitUntilExit()

            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            var outputData = stdoutData.getData()
            outputData.append(outputPipe.fileHandleForReading.availableData)
            var errorData = stderrData.getData()
            errorData.append(errorPipe.fileHandleForReading.availableData)

            let status: ToolCallStatus = (process.terminationStatus == 0) ? .success : .failed

            let diffText = String(data: outputData, encoding: .utf8) ?? ""
            let hash = SHA256.hash(data: outputData).compactMap { String(format: "%02x", $0) }
                .joined()

            let truncatedDiff = diffText.count > 200_000
            let diffForAnalysis = truncatedDiff ? String(diffText.prefix(200_000)) : diffText

            var resultPayload: [String: Any] = [
                "diff": diffText,
                "sha256_hash": hash,
                "exit_code": Int(process.terminationStatus),
                "stderr": String(data: errorData, encoding: .utf8) ?? ""
            ]

            if truncatedDiff {
                resultPayload["truncated_diff"] = true
            }

            if !diffText.isEmpty {
                let analyzer = GitDiffAnalyzer()
                do {
                    let analysis = try await withTimeout(seconds: 5) {
                        try await analyzer.analyze(diffOutput: diffForAnalysis)
                    }
                    let analysisData = try JSONEncoder().encode(analysis)
                    if let analysisJSON = try JSONSerialization.jsonObject(with: analysisData) as? [String: Any] {
                        resultPayload["analysis"] = analysisJSON
                    }
                } catch is GitDiffTimeoutError {
                    resultPayload["analysis_error"] = "Analysis aborted after 5s to keep git_diff responsive"
                } catch {
                    resultPayload["analysis_error"] = error.localizedDescription
                }
            }

            let resultData = try JSONSerialization.data(withJSONObject: resultPayload)

            return ToolCallResponse(
                status: status,
                result: resultData,
                toolName: request.toolName,
                diagnosis: process.terminationStatus != 0
                    ? "Git diff failed with exit code \(process.terminationStatus)" : nil
            )
        } catch {
            return ToolCallResponse(
                status: .failed,
                toolName: request.toolName,
                diagnosis: "Process Execution Error: \(error.localizedDescription)"
            )
        }
    }

    private struct GitDiffTimeoutError: Error, Sendable {
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw GitDiffTimeoutError()
            }

            if let result = try await group.next() {
                group.cancelAll()
                return result
            }

            throw GitDiffTimeoutError()
        }
    }
}
