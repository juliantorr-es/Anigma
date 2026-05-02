//
//  SearchSchema.swift
//  HarmoniaModule
//
//  Schema for search expansion, analytics, feedback, and embeddings.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import InferenceCore
import DatabaseCore
@preconcurrency import Foundation

public enum SearchSchema {
    public static func apply(using db: any DatabaseExecutor) async throws {
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

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_term_mappings_original
            ON term_mappings(original_term);
            """
        )

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
            CREATE INDEX IF NOT EXISTS idx_search_queries_timestamp
            ON search_queries(query_timestamp);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_search_queries_query
            ON search_queries(query);
            """
        )

        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS search_clicks (
                id TEXT PRIMARY KEY,
                query_id TEXT NOT NULL,
                result_id TEXT NOT NULL,
                result_rank INTEGER NOT NULL,
                clicked_at INTEGER NOT NULL,
                FOREIGN KEY(query_id) REFERENCES search_queries(id)
            );
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_search_clicks_query
            ON search_clicks(query_id);
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
            CREATE INDEX IF NOT EXISTS idx_search_feedback_user
            ON search_feedback(user_id);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_search_feedback_result
            ON search_feedback(result_id);
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
            CREATE INDEX IF NOT EXISTS idx_search_sessions_user
            ON search_sessions(user_id);
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

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_content_embeddings_content
            ON content_embeddings(content_id);
            """
        )
    }
}
