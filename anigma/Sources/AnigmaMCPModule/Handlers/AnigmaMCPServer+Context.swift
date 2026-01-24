//
//  AnigmaMCPServer+Context.swift
//  AnigmaMCPModule
//
//  Context and administration related tool handlers for MCP.
//

import Foundation
import MCP
import AnigmaCore
import PolytroposModule
import AnigmaPrimitives
import ContractsCore
import ContextumModule
import DatabaseCore

extension AnigmaMCPServer {
    func handleDigestCodebase(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        let rootPath = arguments?["path"]?.stringValue ?? FileManager.default.currentDirectoryPath
        await progress?.startPhase(.indexing, message: "Digesting codebase")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Discovering sources")
        let tool = EnhancedDigestCodebaseTool(workingDirectory: URL(fileURLWithPath: rootPath))
        let result = await tool.execute(
            ToolCallRequest(toolName: "digest_codebase", sessionId: "mcp", parameters: "{}"),
            session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases))
        )
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Digest complete")
        return result.mcpResult
    }

    func handleCodebaseIndexPurge(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Purging codebase index")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Clearing index tables")
        let includeSearchHistory = arguments?["include_search_history"]?.boolValue ?? false
        let dbPath = codebaseDatabasePath()
        let db = DatabaseActor(dbPath: dbPath)

        do {
            try await db.open()
            try await CodebaseIndexSchema.apply(using: db)
            try await SearchSchema.apply(using: db)

            try await db.execute("DELETE FROM code_symbols")
            try await db.execute("DELETE FROM indexed_files")
            try await db.execute("DELETE FROM content_embeddings")

            if includeSearchHistory {
                try await db.execute("DELETE FROM search_clicks")
                try await db.execute("DELETE FROM search_feedback")
                try await db.execute("DELETE FROM search_queries")
                try await db.execute("DELETE FROM search_sessions")
                try await db.execute("DELETE FROM term_mappings")
            }

            let message = includeSearchHistory
                ? "Purged codebase index and search history."
                : "Purged codebase index."
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Purge complete")
            return CallTool.Result(content: [.text(message)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    func handleContextSearch(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        guard let query = arguments?["query"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing query")], isError: true)
        }
        let limit = arguments?["limit"]?.intValue ?? 10

        let params: [String: Any] = [
            "query": query,
            "limit": limit
        ]
        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        await progress?.startPhase(.processing, message: "Running context search")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Preparing search")
        let tool = ContextSearchTool()
        let result = await tool.execute(
            ToolCallRequest(toolName: "context_search", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases))
        )
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Context search ready")
        return result.mcpResult
    }

    func handleContextPurge(progress: ProgressTracker?) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Purging context database")
        guard let contextum = contextum else {
            return CallTool.Result(content: [.text("Contextum pending")], isError: true)
        }
        try? await contextum.database.clearAll()
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Context purge complete")
        return CallTool.Result(content: [.text("Purged")])
    }

    func handleGetSystemHealth(progress: ProgressTracker?) async -> CallTool.Result {
        await progress?.startPhase(.analyzing, message: "Gathering system health")
        guard let observatorium = observatorium else {
            return CallTool.Result(content: [.text("Observatorium pending")], isError: true)
        }
        let summary = await observatorium.getHealthSummary()
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "System health ready")
        return CallTool.Result(content: [.text("Status: \(summary.status.rawValue)\nAlerts: \(summary.activeAlerts)\nErrors: \(summary.recentErrors)")])
    }

    func handleListActiveAlerts(progress: ProgressTracker?) async -> CallTool.Result {
        await progress?.startPhase(.analyzing, message: "Listing active alerts")
        guard let observatorium = observatorium else {
            return CallTool.Result(content: [.text("Observatorium pending")], isError: true)
        }
        let alerts = await observatorium.alerts.getActiveAlerts()
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Alerts ready")
        let text = alerts.map { "[\($0.severity.rawValue)] \($0.title)\n\($0.message)\n" }.joined(separator: "\n---\n\n")
        return CallTool.Result(content: [.text(text.isEmpty ? "None" : text)])
    }

    func handleDatabaseQuery(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Executing database query")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: "Running SQL")
        guard let runtime = runtime else {
            return CallTool.Result(content: [.text("Runtime pending")], isError: true)
        }
        guard let sql = arguments?["sql"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing SQL")], isError: true)
        }
        let params = arguments?["parameters"]?.objectValue?.compactMapValues { $0.stringValue } ?? [:]
        do {
            let rows = try await runtime.database.query(sql, parameters: params)
            let text: String = rows.enumerated().map { offset, row in
                let rowText = row.values
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key): \(formatDatabaseValue($0.value))" }
                    .joined(separator: "\n")
                return "Row \(offset + 1):\n\(rowText)"
            }.joined(separator: "\n---\n\n")
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Query complete")
            return CallTool.Result(content: [.text(text.isEmpty ? "No rows" : text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    func handleCreateToolContract(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.initializing, message: "Creating tool contract")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Validating parameters")
        guard let name = arguments?["name"]?.stringValue,
              let desc = arguments?["description"]?.stringValue,
              let schema = arguments?["input_schema_json"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing params")], isError: true)
        }
        let caps = arguments?["capabilities"]?.arrayValue?.compactMap { $0.stringValue } ?? ["custom"]
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 2, currentItem: "Registering contract")
        let contract = ToolContract(
            toolName: name,
            toolDescription: desc,
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: schema,
            outputSchema: "{}",
            requiredCapabilities: caps
        )
        toolRegistry.register(contract: contract)
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Contract ready")
        return CallTool.Result(content: [.text("Registered \(name)")])
    }

    func handleVerifyEvidenceChain(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.analyzing, message: "Verifying evidence chain")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: "Checking Cathedral context")
        guard let ctx = self.cathedral else {
            return CallTool.Result(content: [.text("Cathedral pending")], isError: true)
        }
        guard let sid = arguments?["session_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing session_id")], isError: true)
        }
        do {
            let val = try await ctx.validateEvidenceChain(sessionId: sid)
            let hashStr = val.lastHash ?? "N/A"
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Evidence chain verified")
            return CallTool.Result(content: [.text("Valid: \(val.isValid)\nLength: \(val.chainLength)\nHash: \(hashStr)")], isError: false)
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    func handleDelegate(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Delegating task")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Preparing delegation payload")
        guard let summary = arguments?["summary"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing 'summary' parameter")], isError: true)
        }

        var params: [String: Any] = ["summary": summary]
        if let details = arguments?["details"]?.stringValue {
            params["details"] = details
        }
        if let providerId = arguments?["providerId"]?.stringValue {
            params["providerId"] = providerId
        }
        if let caps = arguments?["requiredCapabilities"]?.arrayValue?.compactMap({ $0.stringValue }) {
            params["requiredCapabilities"] = caps
        }

        let paramsData = (try? JSONSerialization.data(withJSONObject: params)) ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        let tool = DelegateTool()
        let result = await tool.execute(
            ToolCallRequest(toolName: "delegate", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases))
        )
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Delegation complete")
        return result.mcpResult
    }

    func handleGetModuleStatus(progress: ProgressTracker?) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Gathering module status")
        let statuses = await moduleInitializer.getModuleStatuses()
        var text = "## Module Status\n\n"
        for (name, info) in statuses.sorted(by: { $0.key < $1.key }) {
            text += "### \(name)\n- Status: \(info.status)\n"
            if let err = info.error { text += "- Error: \(err)\n" }
        }
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Module status ready")
        return CallTool.Result(content: [.text(text)])
    }

    func codebaseDatabasePath() -> String {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Failed to unwrap appSupport")
        }
        let anigmaDir = appSupport.appendingPathComponent("Anigma", isDirectory: true)
        return anigmaDir.appendingPathComponent("codebase.sqlite").path
    }
}
