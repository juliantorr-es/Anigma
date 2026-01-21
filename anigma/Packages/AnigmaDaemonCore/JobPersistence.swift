//
//  JobPersistence.swift
//  AnigmaDaemonCore
//
//  Persistence layer for daemon jobs.
//

import DatabaseCore
import Foundation

/// Protocol for job persistence
public protocol JobPersistence: Sendable {
    func initializeSchema() async throws
    func save(job: Job) async throws
    func loadActiveJobs() async throws -> [Job]
    func loadJob(id: String) async throws -> Job?
    func delete(jobId: String) async throws
}

/// SQLite-based job persistence
public actor SQLiteJobPersistence: JobPersistence {
    private let database: DatabaseActor

    public init(database: DatabaseActor) {
        self.database = database
    }

    public func initializeSchema() async throws {
        _ = try await database.execute("""
            CREATE TABLE IF NOT EXISTS daemon_jobs (
                id TEXT PRIMARY KEY,
                client_id TEXT NOT NULL,
                state TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                job_json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_daemon_jobs_state ON daemon_jobs(state);
            CREATE INDEX IF NOT EXISTS idx_daemon_jobs_client ON daemon_jobs(client_id);
        """)
    }

    public func save(job: Job) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(job)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        // UPSERT
        let sql = """
            INSERT INTO daemon_jobs (id, client_id, state, created_at, updated_at, job_json)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                state = excluded.state,
                updated_at = excluded.updated_at,
                job_json = excluded.job_json
        """

        let now = Date().timeIntervalSince1970
        // We use 'now' for created if new, but ideally we should extract it from Job if available.
        // Assuming Job has a timestamp we can't see, we'll just use 'now' for simplicity in MVP.
        // The JSON blob has full fidelity.

        _ = try await database.execute(
            sql,
            parameters: [
                .text(job.id),
                .text(job.clientId),
                .text(job.state.rawValue),
                .double(now),
                .double(now),
                .text(jsonString)
            ]
        )
    }

    public func loadActiveJobs() async throws -> [Job] {
        let rows = try await database.query(
            """
            SELECT job_json FROM daemon_jobs
            WHERE state IN ('queued', 'running')
            ORDER BY created_at ASC
            """
        )

        return try rows.compactMap { row in
            guard let json = row.string(for: "job_json") else { return nil }
            return try decodeJob(json)
        }
    }

    public func loadJob(id: String) async throws -> Job? {
        let rows = try await database.query(
            "SELECT job_json FROM daemon_jobs WHERE id = ?",
            parameters: [.text(id)]
        )
        guard let row = rows.first, let json = row.string(for: "job_json") else { return nil }
        return try decodeJob(json)
    }

    public func delete(jobId: String) async throws {
        _ = try await database.execute(
            "DELETE FROM daemon_jobs WHERE id = ?",
            parameters: [.text(jobId)]
        )
    }

    private func decodeJob(_ json: String) throws -> Job? {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Job.self, from: data)
    }
}
