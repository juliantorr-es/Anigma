//
//  HarmoniaSchema.swift
//  HarmoniaSurface
//
//  Centralized schema initialization for Harmonia database tables.
//  Provides idempotent initialization function to create all required tables,
//  FTS indexes, and triggers for the Harmonia memory and code chunk system.
//

import Foundation
import DatabaseCore
import AnigmaCore

/// Harmonia database schema initialization
public enum HarmoniaSchema {
    
    /// Initialize all Harmonia database tables
    /// - Parameter database: Database authority adapter for executing SQL
    /// - Throws: Database errors if schema creation fails
    ///
    /// This function is idempotent and safe to call multiple times.
    /// It creates:
    /// - harmonia_memories table (with all columns including embedding)
    /// - harmonia_chunks table (with all columns including embedding)
    /// - FTS5 virtual tables for full-text search
    /// - Triggers to keep FTS tables synchronized
    public static func initialize(using database: DatabaseAuthorityAdapter) async throws {
        // Create harmonia_memories table with all required columns
        try await database.execute("""
            CREATE TABLE IF NOT EXISTS harmonia_memories (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                project_id TEXT,
                embedding BLOB,
                embedding_dim INTEGER,
                embedding_model TEXT,
                metadata_json TEXT
            )
        """, parameters: [])
        
        // Create harmonia_chunks table with all required columns
        try await database.execute("""
            CREATE TABLE IF NOT EXISTS harmonia_chunks (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                content TEXT NOT NULL,
                file_path TEXT NOT NULL,
                start_line INTEGER NOT NULL,
                end_line INTEGER NOT NULL,
                content_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                embedding BLOB,
                embedding_dim INTEGER,
                embedding_model TEXT
            )
        """, parameters: [])
        
        // Create FTS5 virtual table for harmonia_memories
        try await database.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS harmonia_memories_fts USING fts5(
                content,
                content='harmonia_memories',
                content_rowid='rowid'
            )
        """, parameters: [])
        
        // Create FTS5 virtual table for harmonia_chunks
        try await database.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS harmonia_chunks_fts USING fts5(
                content,
                content='harmonia_chunks',
                content_rowid='rowid'
            )
        """, parameters: [])
        
        // Create triggers for harmonia_memories FTS synchronization
        
        // AFTER INSERT: Add new memory to FTS
        try await database.execute("""
            CREATE TRIGGER IF NOT EXISTS harmonia_memories_ai
            AFTER INSERT ON harmonia_memories
            BEGIN
                INSERT INTO harmonia_memories_fts(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """, parameters: [])
        
        // AFTER DELETE: Mark FTS entry as deleted
        try await database.execute("""
            CREATE TRIGGER IF NOT EXISTS harmonia_memories_ad
            AFTER DELETE ON harmonia_memories
            BEGIN
                INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
            END
        """, parameters: [])
        
        // AFTER UPDATE: Remove old and insert new FTS entry
        try await database.execute("""
            CREATE TRIGGER IF NOT EXISTS harmonia_memories_au
            AFTER UPDATE ON harmonia_memories
            BEGIN
                INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
                INSERT INTO harmonia_memories_fts(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """, parameters: [])
        
        // Create triggers for harmonia_chunks FTS synchronization
        
        // AFTER INSERT: Add new chunk to FTS
        try await database.execute("""
            CREATE TRIGGER IF NOT EXISTS harmonia_chunks_ai
            AFTER INSERT ON harmonia_chunks
            BEGIN
                INSERT INTO harmonia_chunks_fts(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """, parameters: [])
        
        // AFTER DELETE: Mark FTS entry as deleted
        try await database.execute("""
            CREATE TRIGGER IF NOT EXISTS harmonia_chunks_ad
            AFTER DELETE ON harmonia_chunks
            BEGIN
                INSERT INTO harmonia_chunks_fts(harmonia_chunks_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
            END
        """, parameters: [])
        
        // AFTER UPDATE: Remove old and insert new FTS entry
        try await database.execute("""
            CREATE TRIGGER IF NOT EXISTS harmonia_chunks_au
            AFTER UPDATE ON harmonia_chunks
            BEGIN
                INSERT INTO harmonia_chunks_fts(harmonia_chunks_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
                INSERT INTO harmonia_chunks_fts(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """, parameters: [])
    }
}
