//
//  JobPersistence.swift
//  AnigmaCore
//
//  Protocol for job persistence and crash recovery.
//

import Foundation
import AnigmaPrimitives

/// Protocol for persisting job records across system restarts.
public protocol JobPersistence: Sendable {
    /// Save a job record to persistent storage.
    func save(record: JobRecord) async throws
    
    /// Load a specific job record by ID.
    func load(jobId: JobId) async throws -> JobRecord?
    
    /// Load all active (non-terminal) job records.
    func loadActiveJobs() async throws -> [JobRecord]
    
    /// Load job records with optional filtering.
    func loadJobs(status: Set<JobStatus>?, limit: Int?) async throws -> [JobRecord]
    
    /// Delete a job record (typically for completed jobs after retention period).
    func delete(jobId: JobId) async throws
    
    /// Delete old job records older than specified date.
    func cleanup(before date: Date) async throws
}

/// In-memory implementation for testing and development.
public actor InMemoryJobPersistence: JobPersistence {
    private var records: [JobId: JobRecord] = [:]
    
    public init() {}
    
    public func save(record: JobRecord) async throws {
        records[record.id] = record
    }
    
    public func load(jobId: JobId) async throws -> JobRecord? {
        return records[jobId]
    }
    
    public func loadActiveJobs() async throws -> [JobRecord] {
        return records.values.filter { !$0.status.isTerminal }
    }
    
    public func loadJobs(status: Set<JobStatus>?, limit: Int?) async throws -> [JobRecord] {
        var filtered = Array(records.values)
        
        if let status = status {
            filtered = filtered.filter { status.contains($0.status) }
        }
        
        let sorted = filtered.sorted { $0.job.createdAt > $1.job.createdAt }
        
        if let limit = limit {
            return Array(sorted.prefix(limit))
        }
        
        return sorted
    }
    
    public func delete(jobId: JobId) async throws {
        records.removeValue(forKey: jobId)
    }
    
    public func cleanup(before date: Date) async throws {
        records = records.filter { _, record in
            // Keep records that completed AFTER the cutoff date (or created after if not completed)
            let timestamp = record.completedAt ?? record.job.createdAt
            return timestamp >= date
        }
    }
}