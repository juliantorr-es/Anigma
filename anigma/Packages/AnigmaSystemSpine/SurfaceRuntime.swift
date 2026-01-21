//
//  SurfaceRuntime.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public final class SurfaceRuntime: Sendable {
    private let jobQueue: JobQueue

    public init(appGroupIdentifier: String) throws {
        self.jobQueue = try JobQueue(appGroupIdentifier: appGroupIdentifier)
    }

    // For testing
    public init(jobQueue: JobQueue) {
        self.jobQueue = jobQueue
    }

    public func enqueueJob(_ job: SharedJob) throws {
        try jobQueue.enqueue(job: job)
    }

    public func submitIntent(intentType: String, payload: Data, sourceSurface: String) throws -> String {
        // In a real implementation, this would validate the intent against a policy
        // and then enqueue a job to process it.
        let jobId = UUID()
        let job = SharedJob(
            id: jobId,
            type: .intake, // Generic intake for intents for now
            payload: payload,
            idempotencyKey: UUID().uuidString, // Should be derived from payload
            sourceSurface: sourceSurface
        )
        try jobQueue.enqueue(job: job)
        return jobId.uuidString
    }

    public func readLocalMirror(query: String) async -> Data? {
        // Stub for reading from the local read-only mirror (e.g. SQLite or JSON cache)
        // This would access the shared container's "Mirror" directory
        return nil
    }
}
