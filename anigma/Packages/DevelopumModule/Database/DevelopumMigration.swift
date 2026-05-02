//
//  DevelopumMigration.swift
//  DevelopumModule
//
//  Database migrations for Develop mode tables.
//

import Foundation
import DatabaseCore

/// Database migrations for DevelopumModule.
public enum DevelopumMigration {
    /// Apply all DevelopumModule migrations.
    /// Call this during module registration or startup.
    public static func migrate(_ db: any DatabaseExecutor) async throws {
        do {
            try await db.execute("BEGIN TRANSACTION")
            try await createDevelopumTables(db)
            try await createIndexes(db)
            try await db.execute("COMMIT TRANSACTION")
        } catch {
            _ = try? await db.execute("ROLLBACK TRANSACTION")
            throw error
        }
    }
    
    /// Create the core DevelopumModule tables.
    private static func createDevelopumTables(_ db: any DatabaseExecutor) async throws {
        // Table: developum_repos
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS developum_repos (
                id TEXT PRIMARY KEY,
                repo_path TEXT NOT NULL,
                remote_url TEXT,
                current_branch TEXT NOT NULL,
                head_sha TEXT NOT NULL,
                created_at REAL NOT NULL,
                last_activity_at REAL NOT NULL,
                is_active INTEGER NOT NULL,
                workspace_config TEXT,
                metadata TEXT
            );
            """
        )
        
        // Table: developum_workspace_states
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS developum_workspace_states (
                id TEXT PRIMARY KEY,
                repo_id TEXT NOT NULL,
                file_path TEXT NOT NULL,
                cursor_line INTEGER NOT NULL,
                cursor_column INTEGER NOT NULL,
                selection_start_line INTEGER,
                selection_start_column INTEGER,
                selection_end_line INTEGER,
                selection_end_column INTEGER,
                viewport_top_line INTEGER,
                viewport_bottom_line INTEGER,
                is_open INTEGER NOT NULL,
                has_unsaved_changes INTEGER NOT NULL,
                updated_at REAL NOT NULL,
                editor_state TEXT,
                FOREIGN KEY (repo_id) REFERENCES developum_repos(id) ON DELETE CASCADE
            );
            """
        )
        
        // Table: developum_index_artifacts
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS developum_index_artifacts (
                id TEXT PRIMARY KEY,
                repo_id TEXT NOT NULL,
                artifact_hash TEXT NOT NULL,
                file_path TEXT NOT NULL,
                mime_type TEXT NOT NULL,
                language_id TEXT,
                file_size INTEGER NOT NULL,
                file_modified_at REAL NOT NULL,
                indexed_at REAL NOT NULL,
                index_content BLOB NOT NULL,
                is_current INTEGER NOT NULL,
                FOREIGN KEY (repo_id) REFERENCES developum_repos(id) ON DELETE CASCADE
            );
            """
        )
        
        // Table: developum_bridge_events (for evidence of bridge messages)
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS developum_bridge_events (
                id TEXT PRIMARY KEY,
                repo_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                message_type TEXT NOT NULL,
                message_hash TEXT NOT NULL,
                message_body BLOB NOT NULL,
                timestamp REAL NOT NULL,
                receipt_hash TEXT,
                artifact_hash TEXT,
                FOREIGN KEY (repo_id) REFERENCES developum_repos(id) ON DELETE CASCADE
            );
            """
        )
        
        // Table: developum_editor_operations (for file save receipts)
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS developum_editor_operations (
                id TEXT PRIMARY KEY,
                repo_id TEXT NOT NULL,
                file_path TEXT NOT NULL,
                operation_type TEXT NOT NULL,
                artifact_hash_before TEXT,
                artifact_hash_after TEXT NOT NULL,
                patch_hash TEXT,
                receipt_hash TEXT NOT NULL,
                timestamp REAL NOT NULL,
                metadata TEXT,
                FOREIGN KEY (repo_id) REFERENCES developum_repos(id) ON DELETE CASCADE
            );
            """
        )
        
        // Table: developum_virtual_documents
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS developum_virtual_documents (
                id TEXT PRIMARY KEY,
                repo_id TEXT NOT NULL,
                file_path TEXT NOT NULL,
                chunks_json TEXT NOT NULL,
                mime_type TEXT NOT NULL,
                last_modified REAL NOT NULL,
                is_active INTEGER NOT NULL,
                FOREIGN KEY (repo_id) REFERENCES developum_repos(id) ON DELETE CASCADE
            );
            """
        )
    }
    
    /// Create indexes for query performance.
    private static func createIndexes(_ db: any DatabaseExecutor) async throws {
        // Indexes for developum_repos
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_repos_path 
            ON developum_repos(repo_path);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_repos_active 
            ON developum_repos(is_active, last_activity_at);
            """
        )
        
        // Indexes for developum_workspace_states
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_workspace_repo 
            ON developum_workspace_states(repo_id, file_path);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_workspace_open 
            ON developum_workspace_states(is_open, updated_at);
            """
        )
        
        // Indexes for developum_index_artifacts
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_index_repo 
            ON developum_index_artifacts(repo_id, file_path);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_index_current 
            ON developum_index_artifacts(is_current, indexed_at);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_index_hash 
            ON developum_index_artifacts(artifact_hash);
            """
        )
        
        // Indexes for developum_bridge_events
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_bridge_session 
            ON developum_bridge_events(session_id, timestamp);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_bridge_receipt 
            ON developum_bridge_events(receipt_hash);
            """
        )
        
        // Indexes for developum_editor_operations
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_ops_repo 
            ON developum_editor_operations(repo_id, file_path);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_ops_receipt 
            ON developum_editor_operations(receipt_hash);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_ops_timestamp 
            ON developum_editor_operations(timestamp);
            """
        )
        
        // Indexes for developum_virtual_documents
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_developum_vdoc_repo 
            ON developum_virtual_documents(repo_id, file_path);
            """
        )
    }
    
    /// Drop all DevelopumModule tables (for testing/cleanup).
    public static func dropAll(_ db: any DatabaseExecutor) async throws {
        try await db.execute("DROP TABLE IF EXISTS developum_editor_operations")
        try await db.execute("DROP TABLE IF EXISTS developum_bridge_events")
        try await db.execute("DROP TABLE IF EXISTS developum_index_artifacts")
        try await db.execute("DROP TABLE IF EXISTS developum_workspace_states")
        try await db.execute("DROP TABLE IF EXISTS developum_repos")
        try await db.execute("DROP TABLE IF EXISTS developum_virtual_documents")
    }
}
