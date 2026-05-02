//
//  JobEngine.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public enum JobType: String, Codable, Sendable {
    case intake
    case refresh
    case resolveDeepLink = "resolve_deep_link"
    case materializeFile = "materialize_file"
    case writeBack = "write_back"
    case rosterSync = "roster_sync"
    case repair
    case ingest
    case profile
    case transform
    case query
    case render
    case agentExecution = "agent_execution"
    case governance
    case export
}

public enum JobPriority: Int, Codable, Sendable, Comparable {
    case background = 0
    case utility = 1
    case userInitiated = 2
    case immediate = 3

    public static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct SharedJob: Codable, Identifiable, Sendable {
    public let id: UUID
    public let type: JobType
    public let payload: Data
    public let idempotencyKey: String
    public let createdAt: Date
    public let deadline: Date?
    public let priority: JobPriority
    public let sourceSurface: String // e.g. "extension.share", "app.main"

    public init(
        id: UUID = UUID(),
        type: JobType,
        payload: Data,
        idempotencyKey: String,
        createdAt: Date = Date(),
        deadline: Date? = nil,
        priority: JobPriority = .utility,
        sourceSurface: String
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.deadline = deadline
        self.priority = priority
        self.sourceSurface = sourceSurface
    }
}

public typealias JobEntry = SharedJob

public final class JobEngine: Sendable {
    private let queue: JobQueue

    public init(appGroupIdentifier: String) throws {
        self.queue = try JobQueue(appGroupIdentifier: appGroupIdentifier)
    }

    public init(directoryURL: URL) throws {
        self.queue = try JobQueue(directoryURL: directoryURL)
    }

    public func enqueue(_ job: JobEntry) async throws {
        try queue.enqueue(job: job)
    }
}

public final class JobQueue: Sendable {
    private let queueDirectoryURL: URL

    public init(appGroupIdentifier: String) throws {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw NSError(domain: "JobQueue", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access App Group container"])
        }
        self.queueDirectoryURL = containerURL.appendingPathComponent("JobQueue", isDirectory: true)
        try createDirectoryIfNeeded()
    }

    // For testing or non-app-group usage
    public init(directoryURL: URL) throws {
        self.queueDirectoryURL = directoryURL
        try createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: queueDirectoryURL.path) {
            try fileManager.createDirectory(at: queueDirectoryURL, withIntermediateDirectories: true)
        }
    }

    public func enqueue(job: SharedJob) throws {
        // Use a filename that sorts by priority (descending) then timestamp (ascending)
        // Priority 3 (Immediate) should come first.
        // We invert priority for sorting: 9 - priority.
        let priorityPrefix = 9 - job.priority.rawValue
        let timestamp = Int(job.createdAt.timeIntervalSince1970 * 1000)
        let filename = String(format: "%d_%d_%@.json", priorityPrefix, timestamp, job.id.uuidString)
        let fileURL = queueDirectoryURL.appendingPathComponent(filename)

        let data = try JSONEncoder().encode(job)
        // Atomic write
        try data.write(to: fileURL, options: .atomic)
    }

    public func peek() throws -> SharedJob? {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: queueDirectoryURL, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard let firstFile = files.first else { return nil }

        let data = try Data(contentsOf: firstFile)
        return try JSONDecoder().decode(SharedJob.self, from: data)
    }

    public func pop() throws -> SharedJob? {
        // Simple pop: list, read first, delete.
        // Note: This is not strictly race-condition free across processes without file coordination,
        // but for this phase it establishes the mechanism.
        // A robust implementation would use NSFileCoordinator.

        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: queueDirectoryURL, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard let firstFile = files.first else { return nil }

        let data = try Data(contentsOf: firstFile)
        let job = try JSONDecoder().decode(SharedJob.self, from: data)

        try fileManager.removeItem(at: firstFile)
        return job
    }

    public func list() throws -> [SharedJob] {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: queueDirectoryURL, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(SharedJob.self, from: data)
        }
    }
}
