//
//  SubprocessPoolingTests.swift
//  SubprocessPoolingTests
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//

import Foundation
import Testing
import SubprocessPooling

@Suite("SubprocessPooling Tests")
struct SubprocessPoolingTests {
    
    @Test("TestWorker conforms to SubprocessWorker")
    func testWorkerConformance() {
        let worker = TestWorker()
        #expect(TestWorker.workerName == "TestWorker")
        #expect(worker.isHealthy() == true)
    }
    
    @Test("SubprocessTask creation")
    func testSubprocessTask() {
        let input = "test input"
        let task = SubprocessTask<String, String>(input: input)
        #expect(task.input == input)
        #expect(task.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }
    
    @Test("SubprocessResult success case")
    func testSubprocessResultSuccess() {
        let output = "test output"
        let result = SubprocessResult<String>.success(output)
        
        switch result {
        case .success(let value):
            #expect(value == output)
        case .failure:
            Issue.record("Expected success case")
        }
    }
    
    @Test("SubprocessResult failure case")
    func testSubprocessResultFailure() {
        let error = SubprocessError.spawnFailed(path: "test", reason: "test reason")
        let result = SubprocessResult<String>.failure(error)
        
        switch result {
        case .success:
            Issue.record("Expected failure case")
        case .failure(let err):
            #expect(err.localizedDescription.contains("test reason"))
        }
    }
    
    @Test("PoolConfiguration defaults")
    func testPoolConfiguration() {
        let config = PoolConfiguration()
        #expect(config.poolSize == 1)
        #expect(config.maxIdleSeconds == 300)
        #expect(config.maxTasksPerWorker == 1000)
    }
    
    @Test("PoolConfiguration from worker type")
    func testPoolConfigurationFromWorker() {
        let config = PoolConfiguration(for: TestWorker.self)
        #expect(config.poolSize == TestWorker.poolSize)
        #expect(config.maxIdleSeconds == TestWorker.maxIdleSeconds)
        #expect(config.maxTasksPerWorker == TestWorker.maxTasksPerWorker)
    }
    
    @Test("PoolMetrics creation")
    func testPoolMetrics() {
        let metrics = PoolMetrics(
            poolSize: 10,
            activeWorkers: 5,
            idleWorkers: 3,
            busyWorkers: 2,
            queuedTasks: 0,
            totalTasksCompleted: 100,
            totalTasksFailed: 5
        )
        
        #expect(metrics.poolSize == 10)
        #expect(metrics.activeWorkers == 5)
        #expect(metrics.idleWorkers == 3)
        #expect(metrics.busyWorkers == 2)
        #expect(metrics.totalTasksCompleted == 100)
        #expect(metrics.totalTasksFailed == 5)
    }
    
    @Test("WorkerInfo creation")
    func testWorkerInfo() {
        let info = WorkerInfo(
            id: UUID(),
            processId: 12345,
            state: .ready,
            tasksCompleted: 10
        )
        
        #expect(info.isInState(.ready))
        #expect(info.tasksCompleted == 10)
        
        let updated = info.withUpdatedState(.busy)
        #expect(updated.isInState(.busy))
        #expect(updated.tasksCompleted == 10)
        
        let withLastUsed = updated.withUpdatedLastUsed(.now)
        #expect(withLastUsed.lastUsedAt != nil)
    }
}

// MARK: - Test Worker for Testing

public struct TestWorker: SubprocessWorker {
    public typealias Input = String
    public typealias Output = String
    
    public static var poolSize: Int = 2
    public static var maxIdleSeconds: Int = 60
    public static var maxTasksPerWorker: Int = 100
    public static var workerName: String = "TestWorker"
    public static var executablePath: String = "/usr/bin/echo"
    public static var executableArguments: [String] = ["test"]
    
    public init() {
        // Test worker initialization
    }
    
    public func initialize() async throws {
        // No initialization needed for test worker
    }
    
    public func handleTask(_ task: SubprocessTask<String, String>) async -> SubprocessResult<String> {
        return .success("Processed: \(task.input)")
    }
    
    public func cleanup() async {
        // No cleanup needed
    }
    
    public func isHealthy() -> Bool {
        return true
    }
}
