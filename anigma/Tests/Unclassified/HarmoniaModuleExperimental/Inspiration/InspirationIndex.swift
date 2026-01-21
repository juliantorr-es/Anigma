//
//  InspirationIndex.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Inspiration
//
//  Database schema and models for indexing inspiration repositories.
//  Stores patterns, not code - prevents direct copying.
//

import Foundation
import SQLite3
import HarmoniaModule

/// Represents an inspiration repository in the inspiration/ directory.
public struct InspirationRepo: Sendable, Codable {
    public let id: UUID
    public let name: String
    public let path: String  // Relative path from project root
    public let gitUrl: String?
    public let license: String?
    public let tags: [String]
    public let lastIndexed: Date
    public let commitHash: String?

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        gitUrl: String? = nil,
        license: String? = nil,
        tags: [String] = [],
        lastIndexed: Date = Date(),
        commitHash: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.gitUrl = gitUrl
        self.license = license
        self.tags = tags
        self.lastIndexed = lastIndexed
        self.commitHash = commitHash
    }
}

/// A reusable pattern extracted from an inspiration repository.
public struct InspirationPattern: Sendable, Codable {
    public let id: UUID
    public let repoId: UUID
    public let patternId: String  // Unique identifier for this pattern type
    public let kind: PatternKind
    public let language: String
    public let astFingerprint: String?  // Hash of normalized AST structure
    public let description: String
    public let exampleSnippet: String  // Small, illustrative snippet (max 10 lines)
    public let metadata: [String: String]
    public let discoveredAt: Date

    public enum PatternKind: String, Codable, Sendable, CaseIterable {
        case architecture = "architecture"
        case astTraversal = "ast_traversal"
        case ruleDesign = "rule_design"
        case pipeline = "pipeline"
        case caching = "caching"
        case cli = "cli"
        case config = "config"
        case tooling = "tooling"
        case testing = "testing"
        case documentation = "documentation"
    }

    public init(
        id: UUID = UUID(),
        repoId: UUID,
        patternId: String,
        kind: PatternKind,
        language: String,
        astFingerprint: String? = nil,
        description: String,
        exampleSnippet: String,
        metadata: [String: String] = [:],
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.repoId = repoId
        self.patternId = patternId
        self.kind = kind
        self.language = language
        self.astFingerprint = astFingerprint
        self.description = description
        self.exampleSnippet = exampleSnippet
        self.metadata = metadata
        self.discoveredAt = discoveredAt
    }
}

/// Bridge between inspiration patterns and Anigma's design.
public struct PatternProposal: Sendable, Codable {
    public let id: UUID
    public let patternId: UUID
    public let targetComponent: String  // Which Anigma component to enhance
    public let proposalType: ProposalType
    public let description: String
    public let suggestedImplementation: String  // High-level description, not code
    public let priority: Priority
    public let status: ProposalStatus
    public let createdAt: Date

    public enum ProposalType: String, Codable, Sendable {
        case newRule = "new_rule"
        case refactor = "refactor"
        case newService = "new_service"
        case architectureChange = "architecture_change"
        case optimization = "optimization"
    }

    public enum Priority: Int, Codable, Sendable, Comparable {
        case low = 1
        case medium = 2
        case high = 3

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public enum ProposalStatus: String, Codable, Sendable {
        case pending = "pending"
        case approved = "approved"
        case implemented = "implemented"
        case rejected = "rejected"
        case blocked = "blocked"
    }

    public init(
        id: UUID = UUID(),
        patternId: UUID,
        targetComponent: String,
        proposalType: ProposalType,
        description: String,
        suggestedImplementation: String,
        priority: Priority = .medium,
        status: ProposalStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.patternId = patternId
        self.targetComponent = targetComponent
        self.proposalType = proposalType
        self.description = description
        self.suggestedImplementation = suggestedImplementation
        self.priority = priority
        self.status = status
        self.createdAt = createdAt
    }
}

/// Database operations for the InspirationIndex.
public actor InspirationIndexStore {
    private var db: OpaquePointer?

    public init(dbPath: String = "harmonia_harness.sqlite") async throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw NSError(domain: "SQLite", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to open database: \(String(cString: sqlite3_errmsg(db)))"
            ])
        }
        try await createTables()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func createTables() throws {
        let createReposTable = """
        CREATE TABLE IF NOT EXISTS inspiration_repos (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            path TEXT NOT NULL UNIQUE,
            git_url TEXT,
            license TEXT,
            tags TEXT,  -- JSON array
            last_indexed TEXT NOT NULL,
            commit_hash TEXT
        )
        """

        let createPatternsTable = """
        CREATE TABLE IF NOT EXISTS inspiration_patterns (
            id TEXT PRIMARY KEY,
            repo_id TEXT NOT NULL,
            pattern_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            language TEXT NOT NULL,
            ast_fingerprint TEXT,
            description TEXT NOT NULL,
            example_snippet TEXT NOT NULL,
            metadata TEXT,  -- JSON object
            discovered_at TEXT NOT NULL,
            FOREIGN KEY (repo_id) REFERENCES inspiration_repos(id) ON DELETE CASCADE,
            UNIQUE(repo_id, pattern_id)
        )
        """

        let createProposalsTable = """
        CREATE TABLE IF NOT EXISTS pattern_proposals (
            id TEXT PRIMARY KEY,
            pattern_id TEXT NOT NULL,
            target_component TEXT NOT NULL,
            proposal_type TEXT NOT NULL,
            description TEXT NOT NULL,
            suggested_implementation TEXT NOT NULL,
            priority INTEGER NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (pattern_id) REFERENCES inspiration_patterns(id) ON DELETE CASCADE
        )
        """

        try executeSQL(createReposTable)
        try executeSQL(createPatternsTable)
        try executeSQL(createProposalsTable)
    }

    private func executeSQL(_ sql: String) throws {
        guard let db = db else { throw NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: "Database not open"]) }

        var error: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let errorMsg = error.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(error)
            throw NSError(domain: "SQLite", code: 3, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }

    // MARK: - Repo Operations

    public func saveRepo(_ repo: InspirationRepo) throws {
        let sql = """
        INSERT OR REPLACE INTO inspiration_repos
        (id, name, path, git_url, license, tags, last_indexed, commit_hash)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """

        let tagsJSON = try JSONSerialization.data(withJSONObject: repo.tags)
        let tagsString = String(data: tagsJSON, encoding: .utf8)
        let dateString = ISO8601DateFormatter().string(from: repo.lastIndexed)

        try executePrepared(sql, bindings: [
            repo.id.uuidString,
            repo.name,
            repo.path,
            repo.gitUrl ?? NSNull(),
            repo.license ?? NSNull(),
            tagsString ?? "[]",
            dateString,
            repo.commitHash ?? NSNull()
        ])
    }

    public func getRepo(byPath path: String) throws -> InspirationRepo? {
        let sql = "SELECT * FROM inspiration_repos WHERE path = ?"
        return try querySingle(sql, bindings: [path]) { stmt in
            try parseRepo(from: stmt)
        }
    }

    public func getAllRepos() throws -> [InspirationRepo] {
        let sql = "SELECT * FROM inspiration_repos ORDER BY last_indexed DESC"
        return try queryMultiple(sql) { stmt in
            try parseRepo(from: stmt)
        }
    }

    // MARK: - Pattern Operations

    public func savePattern(_ pattern: InspirationPattern) throws {
        let sql = """
        INSERT OR REPLACE INTO inspiration_patterns
        (id, repo_id, pattern_id, kind, language, ast_fingerprint, description, example_snippet, metadata, discovered_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        let metadataJSON = try JSONSerialization.data(withJSONObject: pattern.metadata)
        let metadataString = String(data: metadataJSON, encoding: .utf8)
        let dateString = ISO8601DateFormatter().string(from: pattern.discoveredAt)

        try executePrepared(sql, bindings: [
            pattern.id.uuidString,
            pattern.repoId.uuidString,
            pattern.patternId,
            pattern.kind.rawValue,
            pattern.language,
            pattern.astFingerprint ?? NSNull(),
            pattern.description,
            pattern.exampleSnippet,
            metadataString ?? "{}",
            dateString
        ])
    }

    public func getPatterns(forRepo repoId: UUID, kind: InspirationPattern.PatternKind? = nil) throws -> [InspirationPattern] {
        var sql = "SELECT * FROM inspiration_patterns WHERE repo_id = ?"
        var bindings: [Any] = [repoId.uuidString]

        if let kind = kind {
            sql += " AND kind = ?"
            bindings.append(kind.rawValue)
        }

        sql += " ORDER BY discovered_at DESC"

        return try queryMultiple(sql, bindings: bindings) { stmt in
            try parsePattern(from: stmt)
        }
    }

    public func getPatternsByKind(_ kind: InspirationPattern.PatternKind) throws -> [InspirationPattern] {
        let sql = "SELECT * FROM inspiration_patterns WHERE kind = ? ORDER BY discovered_at DESC"
        return try queryMultiple(sql, bindings: [kind.rawValue]) { stmt in
            try parsePattern(from: stmt)
        }
    }

    // MARK: - Proposal Operations

    public func saveProposal(_ proposal: PatternProposal) throws {
        let sql = """
        INSERT OR REPLACE INTO pattern_proposals
        (id, pattern_id, target_component, proposal_type, description, suggested_implementation, priority, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        let dateString = ISO8601DateFormatter().string(from: proposal.createdAt)

        try executePrepared(sql, bindings: [
            proposal.id.uuidString,
            proposal.patternId.uuidString,
            proposal.targetComponent,
            proposal.proposalType.rawValue,
            proposal.description,
            proposal.suggestedImplementation,
            proposal.priority.rawValue,
            proposal.status.rawValue,
            dateString
        ])
    }

    public func getPendingProposals() throws -> [PatternProposal] {
        let sql = "SELECT * FROM pattern_proposals WHERE status = 'pending' ORDER BY priority DESC, created_at ASC"
        return try queryMultiple(sql) { stmt in
            try parseProposal(from: stmt)
        }
    }

    public func getProposals(forPattern patternId: UUID) throws -> [PatternProposal] {
        let sql = "SELECT * FROM pattern_proposals WHERE pattern_id = ? ORDER BY created_at DESC"
        return try queryMultiple(sql, bindings: [patternId.uuidString]) { stmt in
            try parseProposal(from: stmt)
        }
    }

    // MARK: - Helper Methods

    private func executePrepared(_ sql: String, bindings: [Any]) throws {
        guard let db = db else { throw NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: "Database not open"]) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 4, userInfo: [
                NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))
            ])
        }
        defer { sqlite3_finalize(stmt) }

        for (index, binding) in bindings.enumerated() {
            let idx = Int32(index + 1)

            if binding is NSNull {
                sqlite3_bind_null(stmt, idx)
            } else if let string = binding as? String {
                sqlite3_bind_text(stmt, idx, string, -1, nil)
            } else if let int = binding as? Int {
                sqlite3_bind_int(stmt, idx, Int32(int))
            } else if let int64 = binding as? Int64 {
                sqlite3_bind_int64(stmt, idx, int64)
            } else if let double = binding as? Double {
                sqlite3_bind_double(stmt, idx, double)
            } else {
                sqlite3_bind_null(stmt, idx)
            }
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw NSError(domain: "SQLite", code: 5, userInfo: [
                NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))
            ])
        }
    }

    private func querySingle<T>(_ sql: String, bindings: [Any] = [], parser: (OpaquePointer) throws -> T) throws -> T? {
        guard let db = db else { throw NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: "Database not open"]) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 4, userInfo: [
                NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))
            ])
        }
        defer { sqlite3_finalize(stmt) }

        for (index, binding) in bindings.enumerated() {
            let idx = Int32(index + 1)

            if binding is NSNull {
                sqlite3_bind_null(stmt, idx)
            } else if let string = binding as? String {
                sqlite3_bind_text(stmt, idx, string, -1, nil)
            } else if let int = binding as? Int {
                sqlite3_bind_int(stmt, idx, Int32(int))
            } else {
                sqlite3_bind_null(stmt, idx)
            }
        }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        return try parser(stmt!)
    }

    private func queryMultiple<T>(_ sql: String, bindings: [Any] = [], parser: (OpaquePointer) throws -> T) throws -> [T] {
        guard let db = db else { throw NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: "Database not open"]) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 4, userInfo: [
                NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))
            ])
        }
        defer { sqlite3_finalize(stmt) }

        for (index, binding) in bindings.enumerated() {
            let idx = Int32(index + 1)

            if binding is NSNull {
                sqlite3_bind_null(stmt, idx)
            } else if let string = binding as? String {
                sqlite3_bind_text(stmt, idx, string, -1, nil)
            } else if let int = binding as? Int {
                sqlite3_bind_int(stmt, idx, Int32(int))
            } else {
                sqlite3_bind_null(stmt, idx)
            }
        }

        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(try parser(stmt!))
        }

        return results
    }

    private func parseRepo(from stmt: OpaquePointer) throws -> InspirationRepo {
        guard let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) else {
            fatalError("Failed to unwrap id")
        }
        let name = String(cString: sqlite3_column_text(stmt, 1))
        let path = String(cString: sqlite3_column_text(stmt, 2))

        let gitUrl = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 3))
        let license = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 4))

        let tagsJSON = String(cString: sqlite3_column_text(stmt, 5))
        guard let tagsData = tagsJSON.data(using: .utf8) else {
            fatalError("Failed to unwrap tagsData")
        }
        let tags = try JSONSerialization.jsonObject(with: tagsData) as? [String] ?? []

        let dateString = String(cString: sqlite3_column_text(stmt, 6))
        let lastIndexed = ISO8601DateFormatter().date(from: dateString) ?? Date()

        let commitHash = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 7))

        return InspirationRepo(
            id: id,
            name: name,
            path: path,
            gitUrl: gitUrl,
            license: license,
            tags: tags,
            lastIndexed: lastIndexed,
            commitHash: commitHash
        )
    }

    private func parsePattern(from stmt: OpaquePointer) throws -> InspirationPattern {
        guard let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) else {
            fatalError("Failed to unwrap id")
        }
        guard let repoId = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 1))) else {
            fatalError("Failed to unwrap repoId")
        }
        let patternId = String(cString: sqlite3_column_text(stmt, 2))
        guard let kind = InspirationPattern.PatternKind(rawValue: String(cString: sqlite3_column_text(stmt, 3))) else {
            fatalError("Failed to unwrap kind")
        }
        let language = String(cString: sqlite3_column_text(stmt, 4))

        let astFingerprint = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 5))

        let description = String(cString: sqlite3_column_text(stmt, 6))
        let exampleSnippet = String(cString: sqlite3_column_text(stmt, 7))

        let metadataJSON = String(cString: sqlite3_column_text(stmt, 8))
        guard let metadataData = metadataJSON.data(using: .utf8) else {
            fatalError("Failed to unwrap metadataData")
        }
        let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: String] ?? [:]

        let dateString = String(cString: sqlite3_column_text(stmt, 9))
        let discoveredAt = ISO8601DateFormatter().date(from: dateString) ?? Date()

        return InspirationPattern(
            id: id,
            repoId: repoId,
            patternId: patternId,
            kind: kind,
            language: language,
            astFingerprint: astFingerprint,
            description: description,
            exampleSnippet: exampleSnippet,
            metadata: metadata,
            discoveredAt: discoveredAt
        )
    }

    private func parseProposal(from stmt: OpaquePointer) throws -> PatternProposal {
        guard let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) else {
            fatalError("Failed to unwrap id")
        }
        guard let patternId = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 1))) else {
            fatalError("Failed to unwrap patternId")
        }
        let targetComponent = String(cString: sqlite3_column_text(stmt, 2))
        guard let proposalType = PatternProposal.ProposalType(rawValue: String(cString: sqlite3_column_text(stmt, 3))) else {
            fatalError("Failed to unwrap proposalType")
        }
        let description = String(cString: sqlite3_column_text(stmt, 4))
        let suggestedImplementation = String(cString: sqlite3_column_text(stmt, 5))
        let priority = PatternProposal.Priority(rawValue: Int(sqlite3_column_int(stmt, 6))) ?? .medium
        guard let status = PatternProposal.ProposalStatus(rawValue: String(cString: sqlite3_column_text(stmt, 7))) else {
            fatalError("Failed to unwrap status")
        }

        let dateString = String(cString: sqlite3_column_text(stmt, 8))
        let createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()

        return PatternProposal(
            id: id,
            patternId: patternId,
            targetComponent: targetComponent,
            proposalType: proposalType,
            description: description,
            suggestedImplementation: suggestedImplementation,
            priority: priority,
            status: status,
            createdAt: createdAt
        )
    }
}
