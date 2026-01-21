//
//  Scheduler.swift
//  AnigmaCore
//
//  Governed job scheduler for asynchronous workflows.
//

import Foundation

public actor Scheduler {
    private var queue: [Job] = []
    private var activeJobs: Set<JobId> = []
    private let maxConcurrentJobs = 4

    public init() {}

    /// Submit a job to the queue.
    public func submit(_ job: Job) {
        queue.append(job)
        // Sort by priority (high first)
        queue.sort { $0.priority.rawValue > $1.priority.rawValue }

        processQueue()
    }

    private func processQueue() {
        guard activeJobs.count < maxConcurrentJobs else { return }
        guard !queue.isEmpty else { return }

        let job = queue.removeFirst()
        activeJobs.insert(job.id)

        Task {
            await execute(job)
            activeJobs.remove(job.id)
            processQueue()
        }
    }

    private func execute(_ job: Job) async {
        print("Scheduler: Executing job \(job.id) (Priority: \(job.priority))")
        // Implementation would call the actual job runner logic
    }
}
