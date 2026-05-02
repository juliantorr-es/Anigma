//
//  WorkerPool.swift
//  AnigmaDaemonCore
//
//  Manages a pool of warm worker processes.
//

import Foundation

/// Manages a pool of ready-to-use worker processes
public actor WorkerPool {
    private let maxConcurrentJobs: Int
    private let resourceLimits: (ramMB: Int, cpuSec: Int)
    private var activePool: [WorkerProcess] = []
    private var idlePool: [WorkerProcess] = []

    public init(maxConcurrentJobs: Int, resourceLimits: (ramMB: Int, cpuSec: Int) = (4096, 60)) {
        self.maxConcurrentJobs = maxConcurrentJobs
        self.resourceLimits = resourceLimits
    }

    /// Acquire a worker process for a job
    /// - Parameter jobId: The ID of the job
    /// - Returns: A worker process (newly created or from pool)
    public func acquireWorker(for jobId: String) async -> WorkerProcess {
        // Reuse idle worker if available
        if !idlePool.isEmpty {
            let worker = idlePool.removeLast()
            await worker.assignJob(jobId)
            activePool.append(worker)
            return worker
        }

        // Create new worker with resource limits
        let worker = WorkerProcess(resourceLimits: self.resourceLimits)
        await worker.assignJob(jobId)
        activePool.append(worker)
        return worker
    }

    /// Release a worker process back to the pool
    /// - Parameter worker: The worker to release
    public func releaseWorker(_ worker: WorkerProcess) async {
        if let index = activePool.firstIndex(where: { $0 === worker }) {
            activePool.remove(at: index)
        }
        await worker.assignJob(nil)
        idlePool.append(worker)
    }

    public func activeCount() -> Int {
        return activePool.count
    }

    public func idleCount() -> Int {
        return idlePool.count
    }

    /// Get the worker process for a specific job
    public func worker(for jobId: String) async -> WorkerProcess? {
        for worker in activePool {
            if await worker.currentJobId == jobId {
                return worker
            }
        }
        return nil
    }

    /// Terminate the worker for a specific job
    public func terminateWorker(for jobId: String) async {
        if let worker = await worker(for: jobId) {
            await worker.terminate()
            await releaseWorker(worker)
        }
    }
}
