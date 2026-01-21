//
//  TraceQueryTool.swift
//  HarmoniaModule
//
//  Governed trace_query tool.
//

import AnigmaPrimitives
import DatabaseCore
import Foundation
import GovernedMigrationCore

public struct TraceQueryTool: Sendable {
    public init() {}

    public func execute(_ request: ToolCallRequest, session: SessionContext) async
        -> ToolCallResponse {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        do {
            let input = try decoder.decode(TraceQueryInput.self, from: Data(request.parameters.utf8))
            let dbPath = input.dbPath ?? DatabaseConfiguration.defaultDatabasePath()
            let api = GovernedMigrationAPI(dbPath: dbPath)

            let steps = try await api.queryMigrationTraceSteps(
                taskId: input.taskId,
                limit: input.limit,
                offset: input.offset
            )

            let payload = TraceQueryOutput(
                taskId: input.taskId,
                count: steps.count,
                steps: steps
            )
            let data = try encoder.encode(payload)

            return ToolCallResponse(
                status: .success,
                result: data,
                toolName: request.toolName
            )
        } catch {
            return ToolCallResponse(
                status: .failed,
                toolName: request.toolName,
                diagnosis: "trace_query failed: \(error.localizedDescription)"
            )
        }
    }
}

private struct TraceQueryInput: Codable {
    let taskId: String?
    let limit: Int
    let offset: Int
    let dbPath: String?

    init(taskId: String? = nil, limit: Int = 10, offset: Int = 0, dbPath: String? = nil) {
        self.taskId = taskId
        self.limit = limit
        self.offset = offset
        self.dbPath = dbPath
    }
}

private struct TraceQueryOutput: Codable {
    let taskId: String?
    let count: Int
    let steps: [MigrationTraceStep]
}
