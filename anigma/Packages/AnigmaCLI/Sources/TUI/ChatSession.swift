//
//  ChatSession.swift
//  AnigmaCLI
//
//  Enhanced chat session with ML inference, RAG, and MCP tools.
//

import Foundation
import AnigmaCLICore
import AnigmaCLIDatabase

public actor ChatSession {
    // MARK: - Properties
    private let sessionID: String
    private let database: CLIDatabaseActor
    private let renderer: TUIRenderer
    private var currentModel: String
    private var toolsEnabled: Bool
    private var dryRun: Bool
    private var stepCounter: Int = 0

    // MARK: - Initialization
    public init(
        database: CLIDatabaseActor,
        renderer: TUIRenderer,
        model: String = "llama-3.1-8b-instruct-4bit",
        toolsEnabled: Bool = true,
        dryRun: Bool = false
    ) async throws {
        self.sessionID = UUID().uuidString
        self.database = database
        self.renderer = renderer
        self.currentModel = model
        self.toolsEnabled = toolsEnabled
        self.dryRun = dryRun

        // Create session in database
        _ = try await database.execute("""
            INSERT INTO runs (
                run_id, task_summary, task_details, mode, dry_run,
                status, created_at, spec_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                .text(sessionID),
                .text("Chat session"),
                .text("Interactive chat mode"),
                .text("chat"),
                .int(dryRun ? 1 : 0),
                .text("running"),
                .double(Date().timeIntervalSince1970),
                .text("")
            ])

        await renderer.appendLog("Session started: \(sessionID)")
        await renderer.setModel(model)
        await renderer.setToolsEnabled(toolsEnabled)
        await renderer.setDryRun(dryRun)
    }

    // MARK: - Session Control
    public func switchModel(_ model: String) async {
        self.currentModel = model
        await renderer.setModel(model)
        await renderer.appendLog("Model switched to: \(model)")
    }

    public func toggleTools() async {
        toolsEnabled.toggle()
        await renderer.setToolsEnabled(toolsEnabled)
        await renderer.appendLog("Tools \(toolsEnabled ? "enabled" : "disabled")")
    }

    public func toggleDryRun() async {
        dryRun.toggle()
        await renderer.setDryRun(dryRun)
        await renderer.appendLog("Dry-run mode \(dryRun ? "enabled" : "disabled")")
    }

    // MARK: - Message Processing
    public func processMessage(_ message: String) async throws {
        await renderer.setStatus("processing")
        stepCounter += 1

        let stepID = UUID().uuidString
        _ = try await database.execute("""
            INSERT INTO steps (
                step_id, run_id, step_number, action_type,
                action_data, status, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                .text(stepID),
                .text(sessionID),
                .int(stepCounter),
                .text("chat"),
                .text(message),
                .text("pending"),
                .double(Date().timeIntervalSince1970)
            ])

        // Perform RAG retrieval
        let context = try await performRAG(query: message)

        // TODO: Integrate ML inference
        await renderer.appendLog("User: \(message)")

        if !context.isEmpty {
            await renderer.appendLog("📚 Retrieved \(context.count) relevant chunks")
        }

        // Stub response
        await renderer.appendLog("Assistant: [ML inference pending - model: \(currentModel)]")

        // Mark step as completed
        _ = try await database.execute("""
            UPDATE steps SET status = ?, completed_at = ?
            WHERE step_id = ?
            """, parameters: [
                .text("completed"),
                .double(Date().timeIntervalSince1970),
                .text(stepID)
            ])

        await renderer.setStatus("idle")
    }

    // MARK: - RAG
    private func performRAG(query: String) async throws -> String {
        let retrieval = CLIHybridRetrieval(database: database)
        let request = CLIRetrievalRequest(
            query: query,
            mode: .hybrid,
            limit: 3
        )

        let hits = try await retrieval.search(request)
        await renderer.setContextChunks(hits.count)

        if hits.isEmpty {
            return ""
        }

        var contextParts: [String] = []
        for hit in hits {
            let contentSQL = "SELECT content FROM document_chunks WHERE chunk_id = ?"
            let rows = try await database.query(contentSQL, parameters: [.text(hit.chunkID)])
            if let content = rows.first?["content"]?.asString {
                contextParts.append("// File: \(hit.sourcePath)\n\(content)")
            }
        }

        return contextParts.joined(separator: "\n\n")
    }

    // MARK: - Indexing
    public func indexCurrentDirectory() async throws {
        await renderer.setStatus("indexing")
        await renderer.appendLog("📚 Indexing current directory...")

        let indexManager = CLIIndexManager(database: database)
        let repoRoot = FileManager.default.currentDirectoryPath

        let commit = try await getCurrentGitCommit(repoRoot: repoRoot)
        let files = try findSwiftFiles(in: repoRoot)

        await renderer.appendLog("Found \(files.count) Swift files")

        let result = try await indexManager.indexRepository(
            repoRoot: repoRoot,
            commit: commit,
            files: files
        )

        await renderer.appendLog("✅ Indexed \(result.chunksCreated) chunks in \(String(format: "%.2f", result.duration))s")
        await renderer.setStatus("idle")
    }

    // MARK: - Search
    public func search(query: String) async throws {
        await renderer.setStatus("searching")
        await renderer.appendLog("🔍 Searching for: \(query)")

        let retrieval = CLIHybridRetrieval(database: database)
        let request = CLIRetrievalRequest(
            query: query,
            mode: .hybrid,
            limit: 5
        )

        let hits = try await retrieval.search(request)

        if hits.isEmpty {
            await renderer.appendLog("❌ No results found")
        } else {
            await renderer.appendLog("📄 Found \(hits.count) results:")
            for (i, hit) in hits.enumerated() {
                await renderer.appendLog("  [\(i + 1)] \(hit.sourcePath) (score: \(String(format: "%.4f", hit.score)))")
            }
        }

        await renderer.setStatus("idle")
    }

    // MARK: - Cleanup
    public func end() async throws {
        await renderer.appendLog("Session ending...")

        _ = try await database.execute("""
            UPDATE runs SET status = ?, completed_at = ?
            WHERE run_id = ?
            """, parameters: [
                .text("completed"),
                .double(Date().timeIntervalSince1970),
                .text(sessionID)
            ])

        await renderer.appendLog("👋 Goodbye!")
    }

    // MARK: - Helpers
    private func getCurrentGitCommit(repoRoot: String) async throws -> String {
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: repoRoot)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let commit = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ChatSessionError.gitCommandFailed
        }

        return commit
    }

    private func findSwiftFiles(in directory: String) throws -> [String] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: directory)

        var files: [String] = []

        while let file = enumerator?.nextObject() as? String {
            if file.hasSuffix(".swift") && !file.contains(".build/") {
                files.append(file)
            }
        }

        return files
    }
}

public enum ChatSessionError: Error {
    case gitCommandFailed
}
