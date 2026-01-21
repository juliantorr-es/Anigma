//
//  JobQueue.swift
//  AnigmaDaemonCore
//
//  Job queue and worker pool management.
//

import Foundation

// MARK: - Job Queue Actor
public actor JobQueue {
    private var jobs: [String: Job] = [:]
    private var queuedJobIds: [String] = []
    private var runningJobIds: Set<String> = []

    private let maxConcurrentJobs: Int
    private let persistence: JobPersistence?

    public init(maxConcurrentJobs: Int = 8, persistence: JobPersistence? = nil) {
        self.maxConcurrentJobs = maxConcurrentJobs
        self.persistence = persistence
    }

    /// Restore jobs from persistence
    public func restore() async {
        guard let p = persistence else { return }
        do {
            let active = try await p.loadActiveJobs()
            for job in active {
                // If job was running when we crashed, re-queue it.
                if job.state == .running {
                    var recovered = job
                    recovered.state = .queued
                    jobs[recovered.id] = recovered
                    queuedJobIds.append(recovered.id)
                    // Persist the state change back to DB immediately
                    Task { try? await p.save(job: recovered) }
                } else {
                    jobs[job.id] = job
                    queuedJobIds.append(job.id)
                }
            }
            print("[JobQueue] Restored \(active.count) jobs from persistence.")
        } catch {
            print("[JobQueue] Failed to restore jobs: \(error)")
        }
    }

    /// Submit a job
    public func submit(spec: JobSpec, clientId: String) -> String {
        let jobId = UUID().uuidString
        let job = Job(id: jobId, spec: spec, clientId: clientId)

        jobs[jobId] = job
        queuedJobIds.append(jobId)

        if let p = persistence {
            Task { try? await p.save(job: job) }
        }

        return jobId
    }

    /// Get next job to run (if capacity available)
    public func dequeue() -> Job? {
        guard runningJobIds.count < maxConcurrentJobs else {
            return nil
        }

        guard let jobId = queuedJobIds.first else {
            return nil
        }

        queuedJobIds.removeFirst()
        runningJobIds.insert(jobId)

        if var job = jobs[jobId] {
            job.state = .running
            job.startedAt = Date()
            jobs[jobId] = job

            if let p = persistence {
                Task { try? await p.save(job: job) }
            }

            return job
        }

        return nil
    }

    /// Mark job as running
    public func markRunning(jobId: String) {
        guard var job = jobs[jobId] else { return }
        job.state = .running
        job.startedAt = Date()
        jobs[jobId] = job

        if let p = persistence {
            Task { try? await p.save(job: job) }
        }
    }

    /// Mark job as completed
    public func complete(jobId: String, outputs: [ArtifactRef], receiptHash: String) {
        guard var job = jobs[jobId] else { return }

        job.state = .succeeded
        job.completedAt = Date()
        job.outputs = outputs
        job.receiptHash = receiptHash

        jobs[jobId] = job
        runningJobIds.remove(jobId)

        if let p = persistence {
            Task { try? await p.save(job: job) }
        }
    }

    /// Mark job as failed
    public func fail(jobId: String, error: String, receiptHash: String? = nil) {
        guard var job = jobs[jobId] else { return }

        job.state = .failed
        job.completedAt = Date()
        job.errorMessage = error
        if let rh = receiptHash {
            job.receiptHash = rh
        }

        jobs[jobId] = job
        runningJobIds.remove(jobId)

        if let p = persistence {
            Task { try? await p.save(job: job) }
        }
    }

    /// Mark job as canceled
    public func cancel(jobId: String) {
        guard var job = jobs[jobId] else { return }

        job.state = .canceled
        job.completedAt = Date()

        jobs[jobId] = job

        // Remove from queues based on state
        if let idx = queuedJobIds.firstIndex(of: jobId) {
            queuedJobIds.remove(at: idx)
        }
        runningJobIds.remove(jobId)

        if let p = persistence {
            Task { try? await p.save(job: job) }
        }
    }

    /// Get job status
    public func getStatus(jobId: String) async -> Job? {
        // First check memory
        if let job = jobs[jobId] {
            return job
        }
        // Then Persistence (if we don't have it in memory, e.g. completed job purged from memory?)
        // Currently 'jobs' map keeps everything forever (MVP memory leak).
        // But if we evicted, we'd check DB.
        // For MVP, let's check DB just in case.
        if let p = persistence {
            return try? await p.loadJob(id: jobId)
        }
        return nil
    }

    /// Get queue statistics
    public func getStats() -> (queued: Int, running: Int, total: Int) {
        return (queuedJobIds.count, runningJobIds.count, jobs.count)
    }

    /// List jobs with pagination and filtering
    public func listJobs(pageToken: String?, pageSize: Int?, filterByState: [String]) async -> (jobs: [Job], nextPageToken: String?) {
        // Convert filterByState strings to JobState enum values
        let filteredStates: Set<JobState> = Set(filterByState.compactMap { JobState(rawValue: $0) })
        
        // Collect and filter jobs
        var filteredJobs = jobs.values
        if !filteredStates.isEmpty {
            filteredJobs = filteredJobs.filter { filteredStates.contains($0.state) }
        }
        
        // Sort by queuedAt descending (newest first)
        let sorted = filteredJobs.sorted { $0.queuedAt > $1.queuedAt }
        
        // Determine page size
        let size = max(1, min(pageSize ?? 100, 1000))
        var startIndex = 0
        
        // Handle pagination token (job ID)
        if let token = pageToken, !token.isEmpty {
            guard let tokenIndex = sorted.firstIndex(where: { $0.id == token }) else {
                // If token not found, start from beginning
                startIndex = 0
            }
            startIndex = tokenIndex + 1
        }
        
        // Calculate page bounds
        let endIndex = min(startIndex + size, sorted.count)
        let page = sorted[startIndex..<endIndex]
        let nextToken = endIndex < sorted.count ? page.last?.id : nil
        
        return (Array(page), nextToken)
    }
}
