//
//  AnigmaMCPServer+Helpers.swift
//  AnigmaMCPModule
//
//  Helper functions and extensions for MCP server.
//

import Foundation
import MCP
import AnigmaPrimitives
import DatabaseCore

extension AnigmaMCPServer {
    func formatDatabaseValue(_ value: DatabaseValue) -> String {
        switch value {
        case .text(let text):
            return text
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .blob(let data):
            return "<blob \(data.count) bytes>"
        case .date(let date):
            return ISO8601DateFormatter().string(from: date)
        case .null:
            return "null"
        }
    }

    func valueToAny(_ value: Value) -> Any? {
        switch value {
        case .null: return NSNull()
        case .bool(let b): return b
        case .int(let i): return i
        case .double(let d): return d
        case .string(let s): return s
        case .array(let a): return a.compactMap { valueToAny($0) }
        case .object(let o):
            var dict: [String: Any] = [: ]
            for (k, v) in o {
                if let val = valueToAny(v) { dict[k] = val }
            }
            return dict
        case .data: return nil
        }
    }

    func convertToValue(_ any: Any) -> Value? {
        // TODO: Fix after MCP package API update
        // if let s = any as? String { return .string(s) }
        // if let i = any as? Int { return .number(Double(i)) }
        // if let d = any as? Double { return .number(d) }
        // if let b = any as? Bool { return .bool(b) }
        if let s = any as? String { return .string(s) }
        if let b = any as? Bool { return .bool(b) }
        return nil
    }
}

extension ToolCallResponse {
    var mcpResult: CallTool.Result {
        if let data = result, let str = String(data: data, encoding: .utf8) {
            return CallTool.Result(content: [.text(str)], isError: status == .failed)
        }
        return CallTool.Result(content: [.text(diagnosis ?? "Tool execution status: \(status.rawValue)")], isError: status == .failed)
    }
}

enum CodebaseIndexSchema {
    static func apply(using db: any DatabaseExecutor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS indexed_files (
                path TEXT PRIMARY KEY,
                language TEXT,
                line_count INTEGER NOT NULL DEFAULT 0,
                indexed_at INTEGER NOT NULL DEFAULT 0
            );
            """
        )

        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS code_symbols (
                id TEXT PRIMARY KEY,
                file_path TEXT NOT NULL,
                symbol_name TEXT NOT NULL,
                symbol_kind TEXT NOT NULL
            );
            """
        )

        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS content_embeddings (
                id TEXT PRIMARY KEY,
                content_id TEXT NOT NULL,
                embedding TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                model TEXT NOT NULL,
                content_hash TEXT NOT NULL
            );
            """
        )
    }
}

enum SearchSchema {
    static func apply(using db: any DatabaseExecutor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS search_queries (
                id TEXT PRIMARY KEY,
                query TEXT NOT NULL,
                user_id TEXT,
                result_count INTEGER NOT NULL DEFAULT 0,
                query_timestamp INTEGER NOT NULL,
                session_id TEXT
            );
            """
        )

        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS search_clicks (
                id TEXT PRIMARY KEY,
                query_id TEXT NOT NULL,
                result_id TEXT NOT NULL,
                result_rank INTEGER NOT NULL,
                clicked_at INTEGER NOT NULL
            );
            """
        )

        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS search_feedback (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                result_id TEXT NOT NULL,
                query TEXT NOT NULL,
                useful INTEGER NOT NULL,
                feedback TEXT,
                recorded_at INTEGER NOT NULL
            );
            """
        )

        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS search_sessions (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                started_at INTEGER NOT NULL,
                ended_at INTEGER
            );
            """
        )

        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS term_mappings (
                id TEXT PRIMARY KEY,
                original_term TEXT NOT NULL,
                alternative_term TEXT NOT NULL,
                context TEXT NOT NULL,
                frequency INTEGER NOT NULL,
                learned_at INTEGER NOT NULL
            );
            """
        )
    }
}

extension AnigmaMCPServer {
    func runCommand(_ launchPath: String, arguments: [String], currentDirectory: String? = nil) async throws -> (Int32, String, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let out = String(decoding: outData, as: UTF8.self)
        let err = String(decoding: errData, as: UTF8.self)
        return (process.terminationStatus, out, err)
    }

    func makeTextResult(_ text: String, isError: Bool = false) -> CallTool.Result {
        CallTool.Result(content: [.text(text)], isError: isError)
    }
}
