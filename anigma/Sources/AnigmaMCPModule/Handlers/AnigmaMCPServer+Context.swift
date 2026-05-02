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
import CryptoKit

extension AnigmaMCPServer {
    func handleDigestCodebase(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        let rootPath = arguments?["path"]?.stringValue ?? FileManager.default.currentDirectoryPath
        await progress?.startPhase(.indexing, message: "Digesting codebase")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 3, currentItem: "Discovering sources")

        let rootURL = URL(fileURLWithPath: rootPath)
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var filesByLanguage: [String: Int] = [:]
        var totalLines = 0
        var filesIndexed = 0
        var moduleCounts: [String: Int] = [:]

        while let fileURL = enumerator?.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()
            let language = switch ext {
            case "swift": "Swift"
            case "md": "Markdown"
            case "json": "JSON"
            case "sh": "Shell"
            case "m", "mm", "c", "cc", "cpp", "h", "hpp": "C/C++"
            default: "Other"
            }

            filesByLanguage[language, default: 0] += 1
            filesIndexed += 1

            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                totalLines += content.split(separator: "\n", omittingEmptySubsequences: false).count
                let moduleName = fileURL.deletingLastPathComponent().lastPathComponent
                moduleCounts[moduleName, default: 0] += 1
            }
        }

        await progress?.updateProgress(itemsProcessed: 2, totalItems: 3, currentItem: "Summarizing structure")

        let keyModules = moduleCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ["name": $0.key, "file_count": String($0.value)] }

        let digest: [String: Any] = [
            "files_indexed": filesIndexed,
            "symbols_extracted": moduleCounts.values.reduce(0, +),
            "total_lines_of_code": totalLines,
            "duration": 0,
            "files_by_language": filesByLanguage,
            "key_modules": keyModules,
            "health_metrics": [
                "estimated_test_coverage": 0,
                "documentation_coverage": 0,
                "public_api_count": 0,
                "average_file_size": filesIndexed > 0 ? totalLines / filesIndexed : 0
            ],
            "architecture_insights": [
                "Digest generated from filesystem scan in MCP compatibility mode",
                "Symbol extraction and semantic analysis are currently stubbed"
            ]
        ]

        let data = try? JSONSerialization.data(withJSONObject: digest)
        let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{\"error\":\"digest encoding failed\"}"
        await progress?.updateProgress(itemsProcessed: 3, totalItems: 3, currentItem: "Digest complete")
        return CallTool.Result(content: [.text(text)])
    }

    func handleCodebaseIndexPurge(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Purging codebase index")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Clearing index tables")
        let includeSearchHistory = arguments?["include_search_history"]?.boolValue ?? false
        
        // Ensure runtime is initialized before accessing database
        await ensureInitialized()
        
        guard let db = runtime?.databaseExecutor() else {
            return CallTool.Result(content: [.text("Runtime not initialized")], isError: true)
        }

        do {
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

        await progress?.startPhase(.processing, message: "Running context search")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Preparing search")
        guard let contextum else {
            return CallTool.Result(content: [.text("Contextum pending")], isError: true)
        }

        let request = HybridSearchSystem.SearchRequest(
            query: query,
            mode: .fullText,
            limit: limit,
            workflowId: "mcp-context-search",
            runId: UUID().uuidString
        )
        let result = try? await contextum.search(request: request)
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Context search ready")
        guard let result else {
            return CallTool.Result(content: [.text("Context search unavailable")], isError: true)
        }
        let text = result.chunks.map { "[\(String(describing: $0.score))] \($0.content.prefix(200))" }.joined(separator: "\n---\n")
        return CallTool.Result(content: [.text(text.isEmpty ? "No matches" : text)])
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
        do {
            try toolRegistry.register(contract: contract, origin: .external)
        } catch ToolRegistryError.duplicateTool {
            return CallTool.Result(content: [.text("Tool already registered: \(name)")], isError: true)
        } catch {
            return CallTool.Result(content: [.text("Failed to register tool contract: \(error)")], isError: true)
        }
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

        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Delegation complete")
        return CallTool.Result(
            content: [.text("Delegation recorded in MCP compatibility mode: \(paramsString)")],
            isError: false
        )
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
        return anigmaDir.appendingPathComponent("codebase.postgres").path
    }

    func handleTraceQuery(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.analyzing, message: "Tracing query")
        let query = arguments?["query"]?.stringValue ?? ""
        guard !query.isEmpty else {
            return CallTool.Result(content: [.text("Missing query")], isError: true)
        }

        let digest = SHA256.hash(data: Data(query.utf8)).map { String(format: "%02x", $0) }.joined()
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Trace ready")
        return CallTool.Result(content: [.text("Trace query placeholder\nQuery: \(query)\nTrace ID: \(digest)")])
    }

    func handleListArtifacts(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        _ = arguments
        await progress?.startPhase(.processing, message: "Listing artifacts")
        guard artifactStore != nil else {
            return CallTool.Result(content: [.text("ArtifactStore pending")], isError: true)
        }
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Artifacts ready")
        return CallTool.Result(content: [.text("Artifact listing is not yet implemented in MCP compatibility mode")])
    }
}
