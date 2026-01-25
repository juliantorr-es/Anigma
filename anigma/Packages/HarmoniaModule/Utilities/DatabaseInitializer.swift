//
//  DatabaseInitializer.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import DatabaseCore
//  DatabaseInitializer.swift
//  HarmoniaModule/Utilities
//
//  Centralized database schema creation and migration.
//  Creates all required tables with proper versioning.
//

@preconcurrency import Foundation
import SQLite3
import AnigmaCore

/// Centralized database schema creation and migration.
public struct DatabaseInitializer: Sendable {

    /// Current schema version.
    public static let currentSchemaVersion = 4

    /// Initialize database with all required tables.
    /// Returns true if successful, false otherwise.
    public static func initializeDatabase(at dbPath: String, isExperiment: Bool = false) -> Bool {
        logInfo("[DB][INIT] Initializing database at: \(dbPath)", category: "DatabaseInitializer")
        if isExperiment {
            logInfo("[DB][INIT] Using experiment DB: \(dbPath)", category: "DatabaseInitializer")
        } else {
            logInfo("[DB][INIT] Using production DB: \(dbPath)", category: "DatabaseInitializer")
        }

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            logError("[DB][INIT] Failed to open database at \(dbPath): \(errMsg)", category: "DatabaseInitializer")
            return false
        }
        defer { sqlite3_close(db) }

        do {
            // Create schema_version table first
            try createSchemaVersionTable(db: db)

            // Get current version
            let currentVersion = try getCurrentSchemaVersion(db: db)
            logInfo("[DB][INIT] Current schema version: \(currentVersion)", category: "DatabaseInitializer")

            // Apply migrations if needed
            if currentVersion < currentSchemaVersion {
                logInfo("[DB][INIT] Applying migrations from v\(currentVersion) to v\(currentSchemaVersion)", category: "DatabaseInitializer")
                try applyMigrations(db: db, from: currentVersion, to: currentSchemaVersion)
            }

            // Ensure all tables exist (idempotent)
            try createAllTables(db: db)

            // Initialize default governance mode if not set
            try initializeGovernanceMode(db: db)

            logInfo("[DB][INIT] Database initialization complete", category: "DatabaseInitializer")
            return true

        } catch {
            logError("[DB][INIT] Database initialization failed: \(error)", category: "DatabaseInitializer")
            return false
        }
    }

    // MARK: - Schema Version Management

    private static func createSchemaVersionTable(db: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS schema_version (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            version INTEGER NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DatabaseInitializer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create schema_version table: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DatabaseInitializer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to execute schema_version creation: \(errMsg)"])
        }

        // Insert initial version if table is empty
        let checkSql = "SELECT COUNT(*) FROM schema_version"
        var checkStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DatabaseInitializer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to check schema_version: \(errMsg)"])
        }
        defer { sqlite3_finalize(checkStmt) }

        if sqlite3_step(checkStmt) == SQLITE_ROW {
            let count = sqlite3_column_int64(checkStmt, 0)
            if count == 0 {
                let insertSql = "INSERT INTO schema_version (id, version) VALUES (1, 0)"
                var insertStmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, insertSql, -1, &insertStmt, nil) == SQLITE_OK else {
                    let errMsg = String(cString: sqlite3_errmsg(db))
                    throw NSError(domain: "DatabaseInitializer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to insert initial schema version: \(errMsg)"])
                }
                defer { sqlite3_finalize(insertStmt) }

                if sqlite3_step(insertStmt) != SQLITE_DONE {
                    let errMsg = String(cString: sqlite3_errmsg(db))
                    throw NSError(domain: "DatabaseInitializer", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to execute initial version insert: \(errMsg)"])
                }
            }
        }
    }

    private static func getCurrentSchemaVersion(db: OpaquePointer?) throws -> Int {
        let sql = "SELECT version FROM schema_version WHERE id = 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DatabaseInitializer", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get schema version: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        } else {
            return 0
        }
    }

    private static func updateSchemaVersion(db: OpaquePointer?, to version: Int) throws {
        let sql = "UPDATE schema_version SET version = ?, updated_at = CURRENT_TIMESTAMP WHERE id = 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DatabaseInitializer", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to update schema version: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(version))

        if sqlite3_step(stmt) != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DatabaseInitializer", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to execute schema version update: \(errMsg)"])
        }
    }

    // MARK: - Migration Application

    private static func applyMigrations(db: OpaquePointer?, from: Int, to: Int) throws {
        for version in from..<to {
            let migrationSQL = migrationSQL(for: version + 1)
            for sql in migrationSQL {
                try executeSQL(db: db, sql: sql)
            }
            try updateSchemaVersion(db: db, to: version + 1)
            logInfo("[DB][MIGRATION] Applied migration to v\(version + 1)", category: "DatabaseInitializer")
        }
    }

    private static func migrationSQL(for version: Int) -> [String] {
        switch version {
        case 1:
            return v1MigrationSQL()
        case 2:
            return v2MigrationSQL()
        case 3:
            return v3MigrationSQL()
        case 4:
            return v4MigrationSQL()
        default:
            return []
        }
    }

    private static func v1MigrationSQL() -> [String] {
        // Initial schema creation
        return [
            // Core tables (already exist in some form)
            """
            CREATE TABLE IF NOT EXISTS project_specs (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                rootPath TEXT NOT NULL,
                createdAt DATETIME NOT NULL
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS scout_findings (
                id TEXT PRIMARY KEY,
                projectId TEXT NOT NULL,
                taskId TEXT,
                filePath TEXT NOT NULL,
                problemKind TEXT NOT NULL,
                severity TEXT NOT NULL,
                description TEXT NOT NULL,
                suggestedFix TEXT,
                lineStart INTEGER,
                lineEnd INTEGER,
                createdAt DATETIME NOT NULL,
                ast_anchor_json TEXT,
                FOREIGN KEY (projectId) REFERENCES project_specs(id) ON DELETE CASCADE,
                FOREIGN KEY (taskId) REFERENCES migration_tasks(id) ON DELETE SET NULL
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS migration_tasks (
                id TEXT PRIMARY KEY,
                projectId TEXT NOT NULL,
                featureCategory TEXT NOT NULL,
                status TEXT NOT NULL,
                priority INTEGER NOT NULL,
                createdAt DATETIME NOT NULL,
                updatedAt DATETIME NOT NULL,
                startedAt DATETIME,
                completedAt DATETIME,
                sessionIndex INTEGER,
                findingId TEXT,
                errorMessage TEXT,
                research_bundle_id TEXT,
                path TEXT,
                pathDetail TEXT,
                FOREIGN KEY (projectId) REFERENCES project_specs(id) ON DELETE CASCADE,
                FOREIGN KEY (findingId) REFERENCES scout_findings(id) ON DELETE SET NULL,
                FOREIGN KEY (research_bundle_id) REFERENCES research_bundles(id) ON DELETE SET NULL
            )
            """,

            // New governance tables
            """
            CREATE TABLE IF NOT EXISTS security_events (
                id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                engine_id TEXT,
                operation TEXT,
                severity TEXT NOT NULL,
                details TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS trust_state (
                subject_id TEXT NOT NULL,
                subject_kind TEXT NOT NULL,
                current_trust_tier TEXT NOT NULL,
                last_changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                changed_by TEXT,
                reason TEXT,
                signature TEXT,
                PRIMARY KEY (subject_id, subject_kind)
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS governance_mode (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                mode TEXT NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_by TEXT
            )
            """,

            // Research tables
            """
            CREATE TABLE IF NOT EXISTS research_bundles (
                id TEXT PRIMARY KEY,
                topic_spec TEXT NOT NULL,
                adequacy_score REAL NOT NULL,
                researched_at TIMESTAMP NOT NULL,
                expires_at TIMESTAMP NOT NULL,
                provenance TEXT NOT NULL,
                metadata TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS research_papers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                bundle_id TEXT NOT NULL,
                paper_id TEXT NOT NULL,
                title TEXT NOT NULL,
                authors TEXT NOT NULL,
                year INTEGER NOT NULL,
                venue TEXT,
                abstract TEXT,
                url TEXT,
                citation_count INTEGER,
                is_open_access BOOLEAN DEFAULT 0,
                source TEXT NOT NULL,
                fetched_at TIMESTAMP NOT NULL,
                relevance_score REAL DEFAULT 0.0,
                tags TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (bundle_id) REFERENCES research_bundles(id) ON DELETE CASCADE,
                UNIQUE(bundle_id, paper_id)
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS research_notes (
                id TEXT PRIMARY KEY,
                bundle_id TEXT NOT NULL,
                paper_id TEXT NOT NULL,
                note_type TEXT NOT NULL,
                content TEXT NOT NULL,
                confidence REAL DEFAULT 1.0,
                extracted_at TIMESTAMP NOT NULL,
                tags TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (bundle_id) REFERENCES research_bundles(id) ON DELETE CASCADE
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS research_tasks (
                id TEXT PRIMARY KEY,
                topic_spec TEXT NOT NULL,
                project_id TEXT,
                module_id TEXT,
                status TEXT NOT NULL,
                research_bundle_id TEXT,
                error_message TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                started_at TIMESTAMP,
                completed_at TIMESTAMP,
                priority TEXT NOT NULL,
                FOREIGN KEY (research_bundle_id) REFERENCES research_bundles(id) ON DELETE SET NULL
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS research_debt_tasks (
                id TEXT PRIMARY KEY,
                research_bundle_id TEXT NOT NULL,
                reason TEXT NOT NULL,
                required_actions TEXT NOT NULL,
                blocked_entity_id TEXT NOT NULL,
                blocked_entity_type TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                resolved_at TIMESTAMP,
                priority TEXT NOT NULL,
                FOREIGN KEY (research_bundle_id) REFERENCES research_bundles(id) ON DELETE CASCADE
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS research_bundle_links (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                bundle_id TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                link_type TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (bundle_id) REFERENCES research_bundles(id) ON DELETE CASCADE
            )
            """,

            // Doctrine tables
            """
            CREATE TABLE IF NOT EXISTS doctrine_violations (
                id TEXT PRIMARY KEY,
                rule_id TEXT NOT NULL,
                file_path TEXT,
                line_number INTEGER,
                context TEXT NOT NULL,
                severity TEXT NOT NULL,
                detected_at TEXT NOT NULL,
                metadata TEXT,
                resolved_at TEXT,
                resolution TEXT
            )
            """,

            """
            CREATE TABLE IF NOT EXISTS doctrine_rule_stats (
                rule_id TEXT PRIMARY KEY,
                violation_count INTEGER NOT NULL DEFAULT 0,
                last_violation TEXT,
                first_violation TEXT,
                resolved_count INTEGER NOT NULL DEFAULT 0
            )
            """,

            // Capability debt table
            """
            CREATE TABLE IF NOT EXISTS capability_debt_tasks (
                id TEXT PRIMARY KEY,
                original_task_id TEXT NOT NULL,
                engine_type TEXT NOT NULL,
                reason TEXT NOT NULL,
                created_at REAL NOT NULL,
                status TEXT NOT NULL,
                priority TEXT NOT NULL,
                resolved_at REAL,
                resolution TEXT,
                FOREIGN KEY (original_task_id) REFERENCES migration_tasks(id)
            )
            """
        ]
    }

    private static func v2MigrationSQL() -> [String] {
        // Phase 4A: Dynamic trust scoring
        return [
            // Add trust_score and trust_calculated_at to trust_state
            """
            ALTER TABLE trust_state ADD COLUMN trust_score INTEGER DEFAULT 60
            """,
            """
            ALTER TABLE trust_state ADD COLUMN trust_calculated_at TIMESTAMP
            """,

            // Create trust_history table for audit trail
            """
            CREATE TABLE IF NOT EXISTS trust_history (
                id TEXT PRIMARY KEY,
                subject_id TEXT NOT NULL,
                subject_kind TEXT NOT NULL,
                old_score INTEGER,
                new_score INTEGER,
                old_tier TEXT,
                new_tier TEXT,
                reason TEXT NOT NULL,
                changed_by TEXT NOT NULL,
                event_id TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (event_id) REFERENCES security_events(id) ON DELETE SET NULL
            )
            """,

            // Update existing trust_state rows with initial scores
            """
            UPDATE trust_state
            SET trust_score = CASE current_trust_tier
                WHEN 'bronze' THEN 30
                WHEN 'silver' THEN 50
                WHEN 'gold' THEN 60
                WHEN 'platinum' THEN 85
                ELSE 60
            END,
            trust_calculated_at = CURRENT_TIMESTAMP
            WHERE trust_score IS NULL
            """
        ]
    }

    private static func v3MigrationSQL() -> [String] {
        return [
            """
            ALTER TABLE scout_findings ADD COLUMN ast_anchor_json TEXT
            """
        ]
    }

    private static func v4MigrationSQL() -> [String] {
        return [
            """
            ALTER TABLE migration_tasks ADD COLUMN path TEXT
            """,
            """
            ALTER TABLE migration_tasks ADD COLUMN pathDetail TEXT
            """
        ]
    }

    // MARK: - Table Creation (Idempotent)

    private static func createAllTables(db: OpaquePointer?) throws {
        // All tables are created in v1 migration, but ensure they exist
        // This is idempotent due to CREATE TABLE IF NOT EXISTS
        let tablesSQL = v1MigrationSQL()
        for sql in tablesSQL {
            try executeSQL(db: db, sql: sql)
        }

        // Create indexes
        try createIndexes(db: db)
    }

    private static func createIndexes(db: OpaquePointer?) throws {
        let indexes = [
            // Security events indexes
            "CREATE INDEX IF NOT EXISTS idx_security_events_type ON security_events(event_type)",
            "CREATE INDEX IF NOT EXISTS idx_security_events_severity ON security_events(severity)",
            "CREATE INDEX IF NOT EXISTS idx_security_events_created ON security_events(created_at)",
            "CREATE INDEX IF NOT EXISTS idx_security_events_subject ON security_events(engine_id, created_at DESC) WHERE engine_id IS NOT NULL",

            // Trust state indexes
            "CREATE INDEX IF NOT EXISTS idx_trust_state_subject ON trust_state(subject_id, subject_kind)",
            "CREATE INDEX IF NOT EXISTS idx_trust_state_tier ON trust_state(current_trust_tier)",
            "CREATE INDEX IF NOT EXISTS idx_trust_state_score ON trust_state(trust_score)",
            "CREATE INDEX IF NOT EXISTS idx_trust_state_calculated ON trust_state(trust_calculated_at)",

            // Trust history indexes
            "CREATE INDEX IF NOT EXISTS idx_trust_history_subject ON trust_history(subject_id, subject_kind, created_at)",
            "CREATE INDEX IF NOT EXISTS idx_trust_history_created ON trust_history(created_at DESC)",

            // Migration tasks indexes
            "CREATE INDEX IF NOT EXISTS idx_migration_tasks_status ON migration_tasks(status)",
            "CREATE INDEX IF NOT EXISTS idx_migration_tasks_project ON migration_tasks(projectId)",
            "CREATE INDEX IF NOT EXISTS idx_migration_tasks_category ON migration_tasks(featureCategory)",

            // Scout findings indexes
            "CREATE INDEX IF NOT EXISTS idx_scout_findings_project ON scout_findings(projectId)",
            "CREATE INDEX IF NOT EXISTS idx_scout_findings_task ON scout_findings(taskId)",

            // Research indexes
            "CREATE INDEX IF NOT EXISTS idx_research_bundles_adequacy ON research_bundles(adequacy_score)",
            "CREATE INDEX IF NOT EXISTS idx_research_papers_bundle ON research_papers(bundle_id)",
            "CREATE INDEX IF NOT EXISTS idx_research_tasks_status ON research_tasks(status)",
            "CREATE INDEX IF NOT EXISTS idx_research_debt_tasks_resolved ON research_debt_tasks(resolved_at)",

            // Doctrine indexes
            "CREATE INDEX IF NOT EXISTS idx_doctrine_violations_resolved ON doctrine_violations(resolved_at)",
            "CREATE INDEX IF NOT EXISTS idx_doctrine_violations_severity ON doctrine_violations(severity)",

            // Capability debt indexes
            "CREATE INDEX IF NOT EXISTS idx_capability_debt_status ON capability_debt_tasks(status)",
            "CREATE INDEX IF NOT EXISTS idx_capability_debt_resolved ON capability_debt_tasks(resolved_at)"
        ]

        for sql in indexes {
            try executeSQL(db: db, sql: sql)
        }
    }

    private static func initializeGovernanceMode(db: OpaquePointer?) throws {
        let checkSql = "SELECT COUNT(*) FROM governance_mode"
        var checkStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DatabaseInitializer", code: 9, userInfo: [NSLocalizedDescriptionKey: "Failed to check governance_mode: \(errMsg)"])
        }
        defer { sqlite3_finalize(checkStmt) }

        if sqlite3_step(checkStmt) == SQLITE_ROW {
            let count = sqlite3_column_int64(checkStmt, 0)
            if count == 0 {
                // Default to governed mode (cathedral mode)
                let insertSql = "INSERT INTO governance_mode (id, mode, updated_by) VALUES (1, 'governed', 'system')"
                var insertStmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, insertSql, -1, &insertStmt, nil) == SQLITE_OK else {
                    let errMsg = String(cString: sqlite3_errmsg(db))
                    throw NSError(domain: "DatabaseInitializer", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to insert default governance mode: \(errMsg)"])
                }
                defer { sqlite3_finalize(insertStmt) }

                if sqlite3_step(insertStmt) != SQLITE_DONE {
                    let errMsg = String(cString: sqlite3_errmsg(db))
                    throw NSError(domain: "DatabaseInitializer", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to execute governance mode insert: \(errMsg)"])
                }
                logInfo("[DB][INIT] Set default governance mode to 'governed'", category: "DatabaseInitializer")
            }
        }
    }

    // MARK: - Helper Functions

    private static func executeSQL(db: OpaquePointer?, sql: String) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DatabaseInitializer", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare SQL: \(errMsg)\nSQL: \(sql)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DatabaseInitializer", code: 13, userInfo: [NSLocalizedDescriptionKey: "Failed to execute SQL: \(errMsg)\nSQL: \(sql)"])
        }
    }

    // MARK: - Public Helpers

    /// Check if database is initialized (has schema_version table).
    public static func isDatabaseInitialized(at dbPath: String) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version'"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(stmt) }

        return sqlite3_step(stmt) == SQLITE_ROW
    }

    /// Get database statistics for observability.
    public static func getDatabaseStats(at dbPath: String) -> [String: Int] {
        var stats: [String: Int] = [:]
        var db: OpaquePointer?

        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return stats
        }
        defer { sqlite3_close(db) }

        let tables = [
            "migration_tasks",
            "scout_findings",
            "security_events",
            "doctrine_violations",
            "capability_debt_tasks",
            "research_bundles",
            "research_debt_tasks"
        ]

        for table in tables {
            let sql = "SELECT COUNT(*) FROM \(table)"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                if sqlite3_step(stmt) == SQLITE_ROW {
                    stats[table] = Int(sqlite3_column_int64(stmt, 0))
                }
            }
        }

        return stats
    }
}
