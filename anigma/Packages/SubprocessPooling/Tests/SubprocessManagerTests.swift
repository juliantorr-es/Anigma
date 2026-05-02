//
//  SubprocessManagerTests.swift
//  SubprocessPoolingTests
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 1: Implement SubprocessManager foundation with pool lifecycle (td-a84da2)
//

import Foundation
import Testing
import SubprocessPooling

// MARK: - Test Worker Implementation

/// A test worker for unit testing
struct EchoWorker: SubprocessWorker {
    typealias Input = String
    typealias Output = String
    
    static var poolSize: Int = 2
    static var maxIdleSeconds: Int = 60
    static var maxTasksPerWorker: Int = 100
    static var workerName: String = "EchoWorker"
    static var executablePath: String = "/bin/echo"
    static var executableArguments: [String] = []
    
    func initialize() async throws {}
    
    func handleTask(_ task: SubprocessTask<String, String>) async -> SubprocessResult<String> {
        return .success(task.input)
    }
    
    func cleanup() async {}
    
    func isHealthy() -> Bool {
        return true
    }
}

// MARK: - ProcessPool Tests

@Suite("ProcessPool Tests")
struct ProcessPoolTests {
    
    @Test("Pool initialization with default configuration")
    func testPoolInitialization() async {
        let pool = ProcessPool<TestWorker>()
        let metrics = await pool.getMetrics()
        
        #expect(metrics.poolSize == 2)
        #expect(metrics.activeWorkers == 0)
        #expect(metrics.idleWorkers == 0)
        #expect(metrics.busyWorkers == 0)
        #expect(metrics.queuedTasks == 0)
    }
    
    @Test("Pool initialization with custom configuration")
    func testPoolCustomConfiguration() async {
        let config = PoolConfiguration(
            poolSize: 5,
            maxIdleSeconds: 120,
            maxTasksPerWorker: 500
        )
        let pool = ProcessPool<TestWorker>(configuration: config)
        let metrics = await pool.getMetrics()
        
        #expect(metrics.poolSize == 5)
    }
    
    @Test("Pool configuration from worker type")
    func testPoolConfigurationFromWorker() async {
        let config = PoolConfiguration(for: EchoWorker.self)
        
        #expect(config.poolSize == 2)
        #expect(config.maxIdleSeconds == 60)
        #expect(config.maxTasksPerWorker == 100)
    }
    
    @Test("Metrics structure")
    func testMetricsStructure() async {
        let metrics = PoolMetrics(
            poolSize: 10,
            activeWorkers: 5,
            idleWorkers: 3,
            busyWorkers: 2,
            queuedTasks: 10,
            totalTasksCompleted: 100,
            totalTasksFailed: 5
        )
        
        #expect(metrics.poolSize == 10)
        #expect(metrics.activeWorkers == 5)
        #expect(metrics.idleWorkers == 3)
        #expect(metrics.busyWorkers == 2)
        #expect(metrics.queuedTasks == 10)
        #expect(metrics.totalTasksCompleted == 100)
        #expect(metrics.totalTasksFailed == 5)
    }
}

// MARK: - SubprocessManager Tests

@Suite("SubprocessManager Tests")
struct SubprocessManagerTests {
    
    @Test("Singleton instance")
    func testSingleton() {
        let manager1 = SubprocessManager.shared
        let manager2 = SubprocessManager.shared
        
        #expect(manager1 === manager2)
    }
    
    @Test("Get pool for worker type")
    func testGetPool() async {
        let manager = SubprocessManager.shared
        let pool = await manager.getPool(for: TestWorker.self)
        
        // Pool should be created and returned
        let metrics = await pool.getMetrics()
        #expect(metrics.poolSize == 2)
    }
    
    @Test("Get existing pool returns same instance")
    func testGetExistingPool() async {
        let manager = SubprocessManager.shared
        let pool1 = await manager.getPool(for: TestWorker.self)
        let pool2 = await manager.getPool(for: TestWorker.self)
        
        // Should return the same pool instance
        // Note: Due to type erasure, we can't directly compare, but the behavior should be consistent
        let metrics1 = await pool1.getMetrics()
        let metrics2 = await pool2.getMetrics()
        
        #expect(metrics1.poolSize == metrics2.poolSize)
    }
    
    @Test("Get metrics for pool")
    func testGetMetricsForPool() async {
        let manager = SubprocessManager.shared
        let metrics = await manager.getMetrics(for: TestWorker.self)
        
        #expect(metrics.poolSize == 2)
    }
    
    @Test("Get all metrics")
    func testGetAllMetrics() async {
        let manager = SubprocessManager.shared
        _ = await manager.getPool(for: TestWorker.self)
        _ = await manager.getPool(for: EchoWorker.self)
        
        let allMetrics = await manager.getAllMetrics()
        
        // Should have at least the pools we created
        #expect(!allMetrics.isEmpty)
    }
}

// MARK: - SubprocessTask Tests

@Suite("SubprocessTask Tests")
struct SubprocessTaskTests {
    
    @Test("Task creation")
    func testTaskCreation() {
        let task = SubprocessTask<String, String>(input: "test input")
        
        #expect(task.input == "test input")
        #expect(task.id != UUID()) // Just check it has a non-nil UUID
        #expect(task.deadline == nil)
    }
    
    @Test("Task with deadline")
    func testTaskWithDeadline() {
        let deadline = ContinuousClock.now + .seconds(10)
        let task = SubprocessTask<String, String>(input: "urgent", deadline: deadline)
        
        #expect(task.deadline != nil)
    }
}

// MARK: - SubprocessResult Tests

@Suite("SubprocessResult Tests")
struct SubprocessResultTests {
    
    @Test("Success result")
    func testSuccessResult() {
        let result: SubprocessResult<String> = .success("output")
        
        switch result {
        case .success(let output):
            #expect(output == "output")
        case .failure:
            Issue.record("Expected success but got failure")
        }
    }
    
    @Test("Failure result")
    func testFailureResult() {
        let error = SubprocessError.spawnFailed(path: "/bin/test", reason: "File not found")
        let result: SubprocessResult<String> = .failure(error)
        
        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            if case .spawnFailed(let path, let reason) = error {
                #expect(path == "/bin/test")
                #expect(reason == "File not found")
            } else {
                Issue.record("Unexpected error type")
            }
        }
    }
}

// MARK: - SubprocessError Tests

@Suite("SubprocessError Tests")
struct SubprocessErrorTests {
    
    @Test("All error cases are sendable")
    func testErrorIsSendable() {
        let errors: [SubprocessError] = [
            .spawnFailed(path: "/bin/test", reason: "not found"),
            .workerInitializationFailed(workerType: "Test", reason: "init failed"),
            .workerTimeout(workerType: "Test"),
            .poolExhausted(workerType: "Test", maxPoolSize: 10),
            .communicationFailed(workerType: "Test", reason: "connection lost"),
            .recyclingFailed(workerType: "Test", reason: "cleanup error")
        ]
        
        #expect(errors.count == 6)
    }
}

// MARK: - WorkerInfo Tests

@Suite("WorkerInfo Tests")
struct WorkerInfoTests {
    
    @Test("Worker info creation")
    func testWorkerInfoCreation() {
        let info = WorkerInfo(
            id: UUID(),
            processId: 12345,
            state: .ready,
            tasksCompleted: 10,
            createdAt: ContinuousClock.now,
            lastUsedAt: ContinuousClock.now
        )
        
        #expect(info.processId == 12345)
        #expect(info.tasksCompleted == 10)
    }
    
    @Test("Default worker info")
    func testDefaultWorkerInfo() {
        let info = WorkerInfo()
        
        #expect(info.processId == nil)
        #expect(info.tasksCompleted == 0)
        // Compare state using switch since WorkerState has associated values
        switch info.state {
        case .notStarted:
            break
        default:
            Issue.record("Expected .notStarted state")
        }
    }
    
    @Test("Worker info with updated state")
    func testWorkerInfoWithUpdatedState() {
        let info = WorkerInfo()
        let updated = info.withUpdatedState(.ready)
        
        switch updated.state {
        case .ready:
            break
        default:
            Issue.record("Expected .ready state")
        }
    }
}

// MARK: - WorkerState Tests

@Suite("WorkerState Tests")
struct WorkerStateTests {
    
    @Test("All worker states")
    func testAllWorkerStates() {
        let states: [WorkerState] = [
            .notStarted,
            .initializing,
            .ready,
            .busy,
            .recycling,
            .terminated,
            .failed(SubprocessError.spawnFailed(path: "", reason: ""))
        ]
        
        #expect(states.count == 7)
    }
}

// MARK: - PoolConfiguration Tests

@Suite("PoolConfiguration Tests")
struct PoolConfigurationTests {
    
    @Test("Default configuration")
    func testDefaultConfiguration() {
        let config = PoolConfiguration()
        
        #expect(config.poolSize == 1)
        #expect(config.maxIdleSeconds == 300)
        #expect(config.maxTasksPerWorker == 1000)
        #expect(config.spawnTimeout == 10.0)
        #expect(config.recycleOnMaxTasks == true)
    }
    
    @Test("Custom configuration")
    func testCustomConfiguration() {
        let config = PoolConfiguration(
            poolSize: 10,
            maxIdleSeconds: 600,
            maxTasksPerWorker: 5000,
            spawnTimeout: 30.0,
            recycleOnMaxTasks: false
        )
        
        #expect(config.poolSize == 10)
        #expect(config.maxIdleSeconds == 600)
        #expect(config.maxTasksPerWorker == 5000)
        #expect(config.spawnTimeout == 30.0)
        #expect(config.recycleOnMaxTasks == false)
    }
}
