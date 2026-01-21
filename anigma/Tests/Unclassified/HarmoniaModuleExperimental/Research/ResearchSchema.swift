//
//  ResearchSchema.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  Database schema for research bundles and related entities.
//

import Foundation
import SQLite3
import HarmoniaModule

/// SQL schema definitions for research system.
public enum ResearchSchema {

    // MARK: - Table Names

    public static let researchBundlesTable = "research_bundles"
    public static let papersTable = "research_papers"
    public static let researchNotesTable = "research_notes"
    public static let researchTasksTable = "research_tasks"
    public static let researchDebtTasksTable = "research_debt_tasks"
    public static let bundleLinksTable = "research_bundle_links"

    // MARK: - Column Definitions

    public enum ResearchBundlesColumns {
        public static let id = "id"
        public static let topicSpec = "topic_spec"
        public static let adequacyScore = "adequacy_score"
        public static let researchedAt = "researched_at"
        public static let expiresAt = "expires_at"
        public static let provenance = "provenance"
        public static let metadata = "metadata"
        public static let createdAt = "created_at"
        public static let updatedAt = "updated_at"
    }

    public enum PapersColumns {
        public static let id = "id"
        public static let bundleId = "bundle_id"
        public static let paperId = "paper_id"
        public static let title = "title"
        public static let authors = "authors"
        public static let year = "year"
        public static let venue = "venue"
        public static let abstract = "abstract"
        public static let url = "url"
        public static let citationCount = "citation_count"
        public static let isOpenAccess = "is_open_access"
        public static let source = "source"
        public static let fetchedAt = "fetched_at"
        public static let relevanceScore = "relevance_score"
        public static let tags = "tags"
        public static let createdAt = "created_at"
    }

    public enum ResearchNotesColumns {
        public static let id = "id"
        public static let bundleId = "bundle_id"
        public static let paperId = "paper_id"
        public static let noteType = "note_type"
        public static let content = "content"
        public static let confidence = "confidence"
        public static let extractedAt = "extracted_at"
        public static let tags = "tags"
        public static let createdAt = "created_at"
    }

    public enum ResearchTasksColumns {
        public static let id = "id"
        public static let topicSpec = "topic_spec"
        public static let projectId = "project_id"
        public static let moduleId = "module_id"
        public static let status = "status"
        public static let researchBundleId = "research_bundle_id"
        public static let errorMessage = "error_message"
        public static let createdAt = "created_at"
        public static let startedAt = "started_at"
        public static let completedAt = "completed_at"
        public static let priority = "priority"
    }

    public enum ResearchDebtTasksColumns {
        public static let id = "id"
        public static let researchBundleId = "research_bundle_id"
        public static let reason = "reason"
        public static let requiredActions = "required_actions"
        public static let blockedEntityId = "blocked_entity_id"
        public static let blockedEntityType = "blocked_entity_type"
        public static let createdAt = "created_at"
        public static let resolvedAt = "resolved_at"
        public static let priority = "priority"
    }

    public enum BundleLinksColumns {
        public static let id = "id"
        public static let bundleId = "bundle_id"
        public static let entityId = "entity_id"
        public static let entityType = "entity_type"
        public static let linkType = "link_type"
        public static let createdAt = "created_at"
    }

    // MARK: - SQL Creation Statements

    public static func createTablesSQL() -> [String] {
        return [
            createResearchBundlesTableSQL(),
            createPapersTableSQL(),
            createResearchNotesTableSQL(),
            createResearchTasksTableSQL(),
            createResearchDebtTasksTableSQL(),
            createBundleLinksTableSQL(),
            createIndexesSQL()
        ]
    }

    private static func createResearchBundlesTableSQL() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(researchBundlesTable) (
            \(ResearchBundlesColumns.id) TEXT PRIMARY KEY,
            \(ResearchBundlesColumns.topicSpec) TEXT NOT NULL,
            \(ResearchBundlesColumns.adequacyScore) REAL NOT NULL,
            \(ResearchBundlesColumns.researchedAt) TIMESTAMP NOT NULL,
            \(ResearchBundlesColumns.expiresAt) TIMESTAMP NOT NULL,
            \(ResearchBundlesColumns.provenance) TEXT NOT NULL,
            \(ResearchBundlesColumns.metadata) TEXT,
            \(ResearchBundlesColumns.createdAt) TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            \(ResearchBundlesColumns.updatedAt) TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
    }

    private static func createPapersTableSQL() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(papersTable) (
            \(PapersColumns.id) INTEGER PRIMARY KEY AUTOINCREMENT,
            \(PapersColumns.bundleId) TEXT NOT NULL,
            \(PapersColumns.paperId) TEXT NOT NULL,
            \(PapersColumns.title) TEXT NOT NULL,
            \(PapersColumns.authors) TEXT NOT NULL,
            \(PapersColumns.year) INTEGER NOT NULL,
            \(PapersColumns.venue) TEXT,
            \(PapersColumns.abstract) TEXT,
            \(PapersColumns.url) TEXT,
            \(PapersColumns.citationCount) INTEGER,
            \(PapersColumns.isOpenAccess) BOOLEAN DEFAULT 0,
            \(PapersColumns.source) TEXT NOT NULL,
            \(PapersColumns.fetchedAt) TIMESTAMP NOT NULL,
            \(PapersColumns.relevanceScore) REAL DEFAULT 0.0,
            \(PapersColumns.tags) TEXT,
            \(PapersColumns.createdAt) TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (\(PapersColumns.bundleId)) REFERENCES \(researchBundlesTable)(\(ResearchBundlesColumns.id)) ON DELETE CASCADE,
            UNIQUE(\(PapersColumns.bundleId), \(PapersColumns.paperId))
        );
        """
    }

    private static func createResearchNotesTableSQL() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(researchNotesTable) (
            \(ResearchNotesColumns.id) TEXT PRIMARY KEY,
            \(ResearchNotesColumns.bundleId) TEXT NOT NULL,
            \(ResearchNotesColumns.paperId) TEXT NOT NULL,
            \(ResearchNotesColumns.noteType) TEXT NOT NULL,
            \(ResearchNotesColumns.content) TEXT NOT NULL,
            \(ResearchNotesColumns.confidence) REAL DEFAULT 1.0,
            \(ResearchNotesColumns.extractedAt) TIMESTAMP NOT NULL,
            \(ResearchNotesColumns.tags) TEXT,
            \(ResearchNotesColumns.createdAt) TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (\(ResearchNotesColumns.bundleId)) REFERENCES \(researchBundlesTable)(\(ResearchBundlesColumns.id)) ON DELETE CASCADE
        );
        """
    }

    private static func createResearchTasksTableSQL() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(researchTasksTable) (
            \(ResearchTasksColumns.id) TEXT PRIMARY KEY,
            \(ResearchTasksColumns.topicSpec) TEXT NOT NULL,
            \(ResearchTasksColumns.projectId) TEXT,
            \(ResearchTasksColumns.moduleId) TEXT,
            \(ResearchTasksColumns.status) TEXT NOT NULL,
            \(ResearchTasksColumns.researchBundleId) TEXT,
            \(ResearchTasksColumns.errorMessage) TEXT,
            \(ResearchTasksColumns.createdAt) TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            \(ResearchTasksColumns.startedAt) TIMESTAMP,
            \(ResearchTasksColumns.completedAt) TIMESTAMP,
            \(ResearchTasksColumns.priority) TEXT NOT NULL,
            FOREIGN KEY (\(ResearchTasksColumns.researchBundleId)) REFERENCES \(researchBundlesTable)(\(ResearchBundlesColumns.id)) ON DELETE SET NULL
        );
        """
    }

    private static func createResearchDebtTasksTableSQL() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(researchDebtTasksTable) (
            \(ResearchDebtTasksColumns.id) TEXT PRIMARY KEY,
            \(ResearchDebtTasksColumns.researchBundleId) TEXT NOT NULL,
            \(ResearchDebtTasksColumns.reason) TEXT NOT NULL,
            \(ResearchDebtTasksColumns.requiredActions) TEXT NOT NULL,
            \(ResearchDebtTasksColumns.blockedEntityId) TEXT NOT NULL,
            \(ResearchDebtTasksColumns.blockedEntityType) TEXT NOT NULL,
            \(ResearchDebtTasksColumns.createdAt) TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            \(ResearchDebtTasksColumns.resolvedAt) TIMESTAMP,
            \(ResearchDebtTasksColumns.priority) TEXT NOT NULL,
            FOREIGN KEY (\(ResearchDebtTasksColumns.researchBundleId)) REFERENCES \(researchBundlesTable)(\(ResearchBundlesColumns.id)) ON DELETE CASCADE
        );
        """
    }

    private static func createBundleLinksTableSQL() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(bundleLinksTable) (
            \(BundleLinksColumns.id) INTEGER PRIMARY KEY AUTOINCREMENT,
            \(BundleLinksColumns.bundleId) TEXT NOT NULL,
            \(BundleLinksColumns.entityId) TEXT NOT NULL,
            \(BundleLinksColumns.entityType) TEXT NOT NULL,
            \(BundleLinksColumns.linkType) TEXT NOT NULL,
            \(BundleLinksColumns.createdAt) TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (\(BundleLinksColumns.bundleId)) REFERENCES \(researchBundlesTable)(\(ResearchBundlesColumns.id)) ON DELETE CASCADE,
            UNIQUE(\(BundleLinksColumns.bundleId), \(BundleLinksColumns.entityId), \(BundleLinksColumns.entityType), \(BundleLinksColumns.linkType))
        );
        """
    }

    private static func createIndexesSQL() -> [String] {
        return [
            // Research bundles indexes
            "CREATE INDEX IF NOT EXISTS idx_research_bundles_researched_at ON \(researchBundlesTable)(\(ResearchBundlesColumns.researchedAt));",
            "CREATE INDEX IF NOT EXISTS idx_research_bundles_expires_at ON \(researchBundlesTable)(\(ResearchBundlesColumns.expiresAt));",
            "CREATE INDEX IF NOT EXISTS idx_research_bundles_adequacy_score ON \(researchBundlesTable)(\(ResearchBundlesColumns.adequacyScore));",

            // Papers indexes
            "CREATE INDEX IF NOT EXISTS idx_papers_bundle_id ON \(papersTable)(\(PapersColumns.bundleId));",
            "CREATE INDEX IF NOT EXISTS idx_papers_year ON \(papersTable)(\(PapersColumns.year));",
            "CREATE INDEX IF NOT EXISTS idx_papers_source ON \(papersTable)(\(PapersColumns.source));",
            "CREATE INDEX IF NOT EXISTS idx_papers_relevance_score ON \(papersTable)(\(PapersColumns.relevanceScore));",

            // Research notes indexes
            "CREATE INDEX IF NOT EXISTS idx_research_notes_bundle_id ON \(researchNotesTable)(\(ResearchNotesColumns.bundleId));",
            "CREATE INDEX IF NOT EXISTS idx_research_notes_paper_id ON \(researchNotesTable)(\(ResearchNotesColumns.paperId));",
            "CREATE INDEX IF NOT EXISTS idx_research_notes_note_type ON \(researchNotesTable)(\(ResearchNotesColumns.noteType));",

            // Research tasks indexes
            "CREATE INDEX IF NOT EXISTS idx_research_tasks_status ON \(researchTasksTable)(\(ResearchTasksColumns.status));",
            "CREATE INDEX IF NOT EXISTS idx_research_tasks_project_id ON \(researchTasksTable)(\(ResearchTasksColumns.projectId));",
            "CREATE INDEX IF NOT EXISTS idx_research_tasks_module_id ON \(researchTasksTable)(\(ResearchTasksColumns.moduleId));",
            "CREATE INDEX IF NOT EXISTS idx_research_tasks_priority ON \(researchTasksTable)(\(ResearchTasksColumns.priority));",
            "CREATE INDEX IF NOT EXISTS idx_research_tasks_created_at ON \(researchTasksTable)(\(ResearchTasksColumns.createdAt));",

            // Research debt tasks indexes
            "CREATE INDEX IF NOT EXISTS idx_research_debt_tasks_research_bundle_id ON \(researchDebtTasksTable)(\(ResearchDebtTasksColumns.researchBundleId));",
            "CREATE INDEX IF NOT EXISTS idx_research_debt_tasks_blocked_entity ON \(researchDebtTasksTable)(\(ResearchDebtTasksColumns.blockedEntityId), \(ResearchDebtTasksColumns.blockedEntityType));",
            "CREATE INDEX IF NOT EXISTS idx_research_debt_tasks_resolved_at ON \(researchDebtTasksTable)(\(ResearchDebtTasksColumns.resolvedAt));",

            // Bundle links indexes
            "CREATE INDEX IF NOT EXISTS idx_bundle_links_bundle_id ON \(bundleLinksTable)(\(BundleLinksColumns.bundleId));",
            "CREATE INDEX IF NOT EXISTS idx_bundle_links_entity ON \(bundleLinksTable)(\(BundleLinksColumns.entityId), \(BundleLinksColumns.entityType));",
            "CREATE INDEX IF NOT EXISTS idx_bundle_links_link_type ON \(bundleLinksTable)(\(BundleLinksColumns.linkType));"
        ]
    }

    // MARK: - Migration Support

    public static func migrationSQL(from version: Int) -> [String] {
        switch version {
        case 0:
            // Initial schema creation
            return createTablesSQL()
        default:
            return []
        }
    }

    // MARK: - Helper Functions

    public static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public static func decodeJSON<T: Decodable>(_ jsonString: String, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "ResearchSchema", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        return try decoder.decode(type, from: data)
    }

    public static func encodeStringArray(_ array: [String]) -> String {
        return try! encodeJSON(array)
    }

    public static func decodeStringArray(_ jsonString: String) -> [String] {
        return (try? decodeJSON(jsonString, as: [String].self)) ?? []
    }

    public static func encodeStringDict(_ dict: [String: String]) -> String {
        return try! encodeJSON(dict)
    }

    public static func decodeStringDict(_ jsonString: String) -> [String: String] {
        return (try? decodeJSON(jsonString, as: [String: String].self)) ?? [:]
    }
}

// MARK: - SQLite Helper Extensions

extension OpaquePointer {
    func bindText(_ statement: OpaquePointer, index: Int32, value: String?) {
        if let value = value {
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    func bindInt(_ statement: OpaquePointer, index: Int32, value: Int?) {
        if let value = value {
            sqlite3_bind_int(statement, index, Int32(value))
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    func bindDouble(_ statement: OpaquePointer, index: Int32, value: Double?) {
        if let value = value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    func bindBool(_ statement: OpaquePointer, index: Int32, value: Bool?) {
        if let value = value {
            sqlite3_bind_int(statement, index, value ? 1 : 0)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    func bindDate(_ statement: OpaquePointer, index: Int32, value: Date?) {
        if let value = value {
            let dateString = ISO8601DateFormatter().string(from: value)
            sqlite3_bind_text(statement, index, dateString, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    func columnText(_ statement: OpaquePointer, index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: text)
    }

    func columnInt(_ statement: OpaquePointer, index: Int32) -> Int? {
        let value = sqlite3_column_int(statement, index)
        return sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : Int(value)
    }

    func columnDouble(_ statement: OpaquePointer, index: Int32) -> Double? {
        let value = sqlite3_column_double(statement, index)
        return sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : value
    }

    func columnBool(_ statement: OpaquePointer, index: Int32) -> Bool? {
        let value = sqlite3_column_int(statement, index)
        return sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : (value != 0)
    }

    func columnDate(_ statement: OpaquePointer, index: Int32) -> Date? {
        guard let text = columnText(statement, index: index) else { return nil }
        return ISO8601DateFormatter().date(from: text)
    }
}
