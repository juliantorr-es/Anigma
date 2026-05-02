import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - Worker

/// Worker actor for processing jobs from the queue
internal actor Worker: Identifiable, Sendable {
    
    // MARK: - Properties
    
    let id: String
    private weak var queueManager: QueueManager?
    private let diagnostics: CapsuleDiagnostics
    private let configuration: QueueManagerConfiguration
    
    private var isActive: Bool = false
    private var currentJob: Job?
    private var processingTask: Task<Void, Never>?
    private var wakeUpContinuation: CheckedContinuation<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        id: String,
        queueManager: QueueManager,
        diagnostics: CapsuleDiagnostics,
        configuration: QueueManagerConfiguration
    ) {
        self.id = id
        self.queueManager = queueManager
        self.diagnostics = diagnostics
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    func start() async {
        guard !isActive else { return }
        
        isActive = true
        processingTask = Task {
            await runWorkerLoop()
        }
        
        diagnostics.event(
            level: .debug,
            category: "queue.worker",
            message: "Worker started: \(id)",
            correlationID: nil,
            metadata: ["worker_id": id]
        )
    }
    
    func stop() async {
        guard isActive else { return }
        
        isActive = false
        processingTask?.cancel()
        
        // Wake up to exit the loop
        wakeUpContinuation?.resume()
        
        // Wait for current job to finish with timeout
        if let job = currentJob {
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(configuration.workerIdleTimeout * 1_000_000_000))
            }
            
            _ = await timeoutTask.value
        }
        
        diagnostics.event(
            level: .debug,
            category: "queue.worker",
            message: "Worker stopped: \(id)",
            correlationID: nil,
            metadata: ["worker_id": id]
        )
    }
    
    func wakeUp() async {
        if !isActive { return }
        
        wakeUpContinuation?.resume()
        wakeUpContinuation = nil
    }
    
    // MARK: - Private Methods
    
    private func runWorkerLoop() async {
        while isActive && !Task.isCancelled {
            // Get next job from queue
            guard let job = await queueManager?.getNextJob() else {
                // No jobs available, wait to be woken up
                await waitForJob()
                continue
            }
            
            // Process the job
            await processJob(job)
        }
    }
    
    private func waitForJob() async {
        await withCheckedContinuation { continuation in
            wakeUpContinuation = continuation
        }
    }
    
    private func processJob(_ job: Job) async {
        currentJob = job
        
        let span = diagnostics.beginSpan(
            name: "Worker.processJob",
            category: "queue.processing",
            correlationID: job.id,
            tags: [
                "worker_id": id,
                "job_type": job.type,
                "job_id": job.id
            ]
        )
        
        do {
            // Notify queue manager that job started
            await queueManager?.jobStarted(job)
            
            // Execute the job
            let result = try await executeJob(job)
            
            // Notify queue manager of completion
            await queueManager?.jobCompleted(job, result: result)
            
            span.end(status: .ok)
            
            diagnostics.event(
                level: .debug,
                category: "queue.processing",
                message: "Job completed successfully: \(job.id)",
                correlationID: job.id,
                metadata: [
                    "worker_id": id,
                    "job_type": job.type
                ]
            )
            
        } catch {
            let capsuleError = error as? CapsuleError ?? CapsuleError.internalError(details: "\(error)")
            
            // Retry logic
            if job.retryCount < job.maxRetries && shouldRetry(error: capsuleError) {
                job.incrementRetryCount()
                
                // Re-queue the job with exponential backoff
                let delay = pow(2.0, Double(job.retryCount)) * 1.0 // Exponential backoff
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Re-submit job
                _ = try? await queueManager?.submitJob(job, correlationID: job.id)
                
                span.end(status: .error)
                
                diagnostics.event(
                    level: .warning,
                    category: "queue.processing",
                    message: "Job retry scheduled: \(job.id) (attempt \(job.retryCount))",
                    correlationID: job.id,
                    metadata: [
                        "worker_id": id,
                        "retry_count": "\(job.retryCount)",
                        "delay": "\(delay)"
                    ]
                )
                
            } else {
                // Job failed permanently
                await queueManager?.jobFailed(job, error: capsuleError)
                
                span.end(status: .error)
                
                diagnostics.event(
                    level: .error,
                    category: "queue.processing",
                    message: "Job failed permanently: \(job.id)",
                    correlationID: job.id,
                    metadata: [
                        "worker_id": id,
                        "error": capsuleError.description,
                        "retry_count": "\(job.retryCount)"
                    ]
                )
            }
        }
        
        currentJob = nil
    }
    
    private func executeJob(_ job: Job) async throws -> JobResult {
        // Create a timeout task
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(job.timeout * 1_000_000_000))
        }
        
        // Create the actual work task
        let workTask = Task {
            try await performJobWork(job)
        }
        
        // Race between work and timeout
        let result = await withCheckedContinuation { continuation in
            Task {
                do {
                    let workResult = try await workTask.value
                    timeoutTask.cancel()
                    continuation.resume(returning: workResult)
                } catch {
                    timeoutTask.cancel()
                    if error is CancellationError {
                        continuation.resume(returning: .timeout)
                    } else {
                        throw error
                    }
                }
            }
        }
        
        return result
    }
    
    private func performJobWork(_ job: Job) async throws -> JobResult {
        // This is where the actual job work would be performed
        // For now, simulate work with different behaviors based on job type
        
        switch job.type {
        case "test.success":
            // Simulate successful work
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            return .success("Job completed successfully".data(using: .utf8) ?? Data())
            
        case "test.failure":
            // Simulate failure
            throw CapsuleError.operationFailed(
                code: 4001,
                message: "Simulated job failure",
                context: ["job_type": job.type]
            )
            
        case "test.timeout":
            // Simulate long-running job (will timeout)
            try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            return .success("This should timeout".data(using: .utf8) ?? Data())
            
        default:
            // Default behavior - process job payload and return as result
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            return .success(job.payload)
        }
    }
    
    private func shouldRetry(error: CapsuleError) -> Bool {
        switch error {
        case .timeout, .resourceExhausted, .operationFailed:
            return true
        case .invalidConfiguration, .invalidInput, .internalError:
            return false
        case .nativeError:
            return true // Native errors might be transient
        }
    }
}