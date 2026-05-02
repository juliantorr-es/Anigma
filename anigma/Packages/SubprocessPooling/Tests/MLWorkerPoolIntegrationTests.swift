// Test MLWorkerPool integration with ProcessPool
import XCTest
@testable import SubprocessPooling

final class MLWorkerPoolIntegrationTests: XCTestCase {
    
    func testMLWorkerPoolCreationFromProcessPool() async {
        // Create a ProcessPool for MLWorker
        let pool = ProcessPool<MLWorker>()
        
        // Get the MLWorkerPool (actor-isolated call)
        let mlWorkerPool = await pool.getMLWorkerPool()
        
        // Verify it's not nil and is the correct type
        XCTAssertNotNil(mlWorkerPool, "MLWorkerPool should be created")
        // XCTAssertTrue(mlWorkerPool is MLWorkerPool, "Should be MLWorkerPool type") // Always true
    }
    
    func testMLWorkerPoolTaskExecution() async {
        // Create a ProcessPool for MLWorker
        let pool = ProcessPool<MLWorker>()
        let mlWorkerPool = await pool.getMLWorkerPool()
        
        // Create test input
        let input = MLWorkerInput(
            modelId: "test-model",
            taskType: .embedding,
            inputData: Array(repeating: 0.5, count: 100)
        )
        
        // Submit task
        let result = await mlWorkerPool.submitTask(input)
        
        // Verify result
        switch result {
        case .success(let output):
            XCTAssertEqual(output.modelId, "test-model", "Model ID should match")
            XCTAssertGreaterThan(output.outputData.count, 0, "Should have output data")
            XCTAssertGreaterThanOrEqual(output.inferenceTime, 0, "Should have non-negative inference time")
        case .failure(let error):
            XCTFail("Task should succeed, but got error: \(error)")
        }
    }
    
    func testMLWorkerPoolMetrics() async {
        // Create a ProcessPool for MLWorker
        let pool = ProcessPool<MLWorker>()
        let mlWorkerPool = await pool.getMLWorkerPool()
        
        // Get metrics
        let metrics = mlWorkerPool.getMetrics()
        
        // Verify metrics structure
        XCTAssertGreaterThanOrEqual(metrics.workerCount, 0, "Worker count should be non-negative")
        XCTAssertGreaterThanOrEqual(metrics.gpuCount, 0, "GPU count should be non-negative")
        XCTAssertEqual(metrics.totalTasksCompleted, 0, "Should start with 0 completed tasks")
        XCTAssertEqual(metrics.totalTasksFailed, 0, "Should start with 0 failed tasks")
    }
    
    func testProcessPoolMetricsIncludeMLWorkerPool() async {
        // Create a ProcessPool for MLWorker
        let pool = ProcessPool<MLWorker>()
        _ = await pool.getMLWorkerPool() // Create the MLWorkerPool
        
        // Get pool metrics
        let poolMetrics = await pool.getMetrics()
        
        // Verify MLWorkerPool metrics are included
        XCTAssertNotNil(poolMetrics.mlWorkerMetrics, "Pool metrics should include MLWorkerPool metrics")
        
        if let mlMetrics = poolMetrics.mlWorkerMetrics {
            XCTAssertGreaterThanOrEqual(mlMetrics.workerCount, 0, "MLWorkerPool worker count should be non-negative")
            XCTAssertGreaterThanOrEqual(mlMetrics.gpuCount, 0, "MLWorkerPool GPU count should be non-negative")
        }
    }
    
    func testMLWorkerPoolShutdown() async {
        // Create a ProcessPool for MLWorker
        let pool = ProcessPool<MLWorker>()
        _ = await pool.getMLWorkerPool()
        
        // Shutdown should not throw
        await pool.shutdown()
        
        // After shutdown, mlWorkerPool should be nil
        let metrics = await pool.getMetrics()
        XCTAssertNil(metrics.mlWorkerMetrics, "MLWorkerPool should be nil after shutdown")
    }
    
    func testMultipleTasks() async {
        // Create a ProcessPool for MLWorker
        let pool = ProcessPool<MLWorker>()
        let mlWorkerPool = await pool.getMLWorkerPool()
        
        // Submit multiple tasks
        let taskCount = 5
        var successCount = 0
        
        for i in 0..<taskCount {
            let input = MLWorkerInput(
                modelId: "test-model-\(i)",
                taskType: .embedding,
                inputData: Array(repeating: Float(i), count: 50)
            )
            
            let result = await mlWorkerPool.submitTask(input)
            
            switch result {
            case .success:
                successCount += 1
            case .failure:
                break
            }
        }
        
        // Verify all tasks succeeded
        XCTAssertEqual(successCount, taskCount, "All tasks should succeed")
        
        // Verify metrics reflect the tasks
        let metrics = mlWorkerPool.getMetrics()
        XCTAssertEqual(metrics.totalTasksCompleted, taskCount, "Should show correct completed task count")
        XCTAssertEqual(metrics.totalTasksFailed, 0, "Should have no failed tasks")
    }
}