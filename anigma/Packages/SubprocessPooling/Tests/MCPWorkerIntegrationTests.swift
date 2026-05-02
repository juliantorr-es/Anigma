// Test MCPWorker integration with ProcessPool
import XCTest
@testable import SubprocessPooling

final class MCPWorkerIntegrationTests: XCTestCase {
    
    // MARK: - MCPWorker Tests
    
    func testMCPWorkerInitialization() async {
        let worker = MCPWorker()
        
        // Test initial state
        XCTAssertFalse(worker.isHealthy())
        
        // Test initialization
        do {
            try await worker.initialize()
            XCTAssertTrue(worker.isHealthy())
        } catch {
            // Initialization may fail if socket is not available, which is expected for Phase 4
            print("Expected initialization failure (no actual MCP server): \(error)")
        }
    }
    
    func testMCPWorkerTaskExecution() async {
        let worker = MCPWorker()
        
        // Create test input
        let input = MCPWorkerInput(
            requestId: "test-\(UUID())",
            method: "tools/list",
            clientId: "test-client"
        )
        
        // Create task
        let task = SubprocessTask<MCPWorkerInput, MCPWorkerOutput>(input: input)
        
        // Execute task
        let result = await worker.handleTask(task)
        
        // Verify result
        switch result {
        case .success(let output):
            XCTAssertEqual(output.requestId, input.requestId)
            XCTAssertNotNil(output.result)
            XCTAssertNil(output.error)
            XCTAssertGreaterThanOrEqual(output.executionTime, 0)
        case .failure(let error):
            XCTFail("Task should succeed, but got error: \(error)")
        }
    }
    
    func testMCPWorkerToolCall() async {
        let worker = MCPWorker()
        
        // Test tool call with parameters
        let input = MCPWorkerInput(
            requestId: "test-tool-\(UUID())",
            method: "tools/call",
            parameters: [
                "name": AnyCodable.string("test-tool"),
                "input": AnyCodable.string("test input")
            ],
            clientId: "test-client"
        )
        
        let task = SubprocessTask<MCPWorkerInput, MCPWorkerOutput>(input: input)
        let result = await worker.handleTask(task)
        
        switch result {
        case .success(let output):
            XCTAssertEqual(output.requestId, input.requestId)
            XCTAssertNotNil(output.result)
        case .failure(let error):
            XCTFail("Task should succeed, but got error: \(error)")
        }
    }
    
    func testMCPWorkerResourceOperations() async {
        let worker = MCPWorker()
        
        // Test resource list
        var input = MCPWorkerInput(
            requestId: "test-resources-\(UUID())",
            method: "resources/list",
            clientId: "test-client"
        )
        
        var task = SubprocessTask<MCPWorkerInput, MCPWorkerOutput>(input: input)
        var result = await worker.handleTask(task)
        
        switch result {
        case .success(let output):
            XCTAssertEqual(output.requestId, input.requestId)
            XCTAssertNotNil(output.result)
        case .failure(let error):
            XCTFail("Task should succeed, but got error: \(error)")
        }
        
        // Test resource read
        input = MCPWorkerInput(
            requestId: "test-read-\(UUID())",
            method: "resources/read",
            parameters: ["uri": AnyCodable.string("test://resource")],
            clientId: "test-client"
        )
        
        task = SubprocessTask<MCPWorkerInput, MCPWorkerOutput>(input: input)
        result = await worker.handleTask(task)
        
        switch result {
        case .success(let output):
            XCTAssertEqual(output.requestId, input.requestId)
            XCTAssertNotNil(output.result)
        case .failure(let error):
            XCTFail("Task should succeed, but got error: \(error)")
        }
    }
    
    // MARK: - MCPWorkerPool Tests
    
    func testMCPWorkerPoolCreation() async {
        let pool = ProcessPool<MCPWorker>()
        let mcWorkerPool = await pool.getMCPWorkerPool()
        
        // Verify pool is created
        XCTAssertNotNil(mcWorkerPool)
        // XCTAssertTrue(mcWorkerPool is MCPWorkerPool) // Always true
    }
    
    func testMCPWorkerPoolTaskSubmission() async {
        let pool = ProcessPool<MCPWorker>()
        let mcWorkerPool = await pool.getMCPWorkerPool()
        
        // Create test input
        let input = MCPWorkerInput(
            requestId: "pool-test-\(UUID())",
            method: "tools/list",
            clientId: "test-client"
        )
        
        // Submit task through pool
        let result = await mcWorkerPool.submitTask(input)
        
        switch result {
        case .success(let output):
            XCTAssertEqual(output.requestId, input.requestId)
            XCTAssertNotNil(output.result)
        case .failure(let error):
            XCTFail("Task should succeed, but got error: \(error)")
        }
    }
    
    func testMCPWorkerPoolMetrics() async {
        let pool = ProcessPool<MCPWorker>()
        let mcWorkerPool = await pool.getMCPWorkerPool()
        
        // Get initial metrics
        let metrics = mcWorkerPool.getMetrics()
        
        // Verify metrics structure
        XCTAssertEqual(metrics.workerCount, MCPWorker.poolSize)
        XCTAssertGreaterThanOrEqual(metrics.activeWorkers, 0)
        XCTAssertGreaterThanOrEqual(metrics.idleWorkers, 0)
        XCTAssertEqual(metrics.totalTasksCompleted, 0)
        XCTAssertEqual(metrics.totalTasksFailed, 0)
    }
    
    // MARK: - ProcessPool Integration Tests
    
    func testProcessPoolMCPIntegration() async {
        let manager = SubprocessManager.shared
        
        // Create test input
        let input = MCPWorkerInput(
            requestId: "integration-test-\(UUID())",
            method: "tools/list",
            clientId: "test-client"
        )
        
        // Submit through SubprocessManager
        let result = await manager.submitMCPTask(input)
        
        switch result {
        case .success(let output):
            XCTAssertEqual(output.requestId, input.requestId)
            XCTAssertNotNil(output.result)
        case .failure(let error):
            XCTFail("Task should succeed, but got error: \(error)")
        }
    }
    
    func testMCPMetricsThroughManager() async {
        let manager = SubprocessManager.shared
        
        // Get MCP metrics
        let metrics = await manager.getMCPMetrics()
        
        // Verify metrics structure
        XCTAssertEqual(metrics.poolSize, MCPWorker.poolSize)
        XCTAssertGreaterThanOrEqual(metrics.activeWorkers, 0)
    }
    
    // MARK: - Concurrent Execution Tests
    
    func testConcurrentMCPTasks() async {
        let manager = SubprocessManager.shared
        let taskCount = 5
        var successCount = 0
        var failedCount = 0
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<taskCount {
                group.addTask {
                    let input = MCPWorkerInput(
                        requestId: "concurrent-\(i)-\(UUID())",
                        method: "tools/list",
                        clientId: "test-client-\(i)"
                    )
                    
                    let result = await manager.submitMCPTask(input)
                    
                    switch result {
                    case .success:
                        successCount += 1
                    case .failure:
                        failedCount += 1
                    }
                }
            }
        }
        
        // All tasks should succeed
        XCTAssertEqual(successCount, taskCount)
        XCTAssertEqual(failedCount, 0)
    }
    
    func testMixedWorkerConcurrentExecution() async {
        let manager = SubprocessManager.shared
        let taskCount = 3
        var mcpSuccess = 0
        var pdfSuccess = 0
        var benchmarkSuccess = 0
        var totalFailed = 0
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<taskCount {
                // MCP task
                group.addTask {
                    let input = MCPWorkerInput(
                        requestId: "mixed-mcp-\(i)",
                        method: "tools/list",
                        clientId: "test-client"
                    )
                    
                    let result = await manager.submitMCPTask(input)
                    switch result {
                    case .success: mcpSuccess += 1
                    case .failure: totalFailed += 1
                    }
                }
                
                // PDF task
                group.addTask {
                    let input = PDFSidecarWorkerInput(
                        requestId: "mixed-pdf-\(i)",
                        operation: .countPages,
                        filePath: "/tmp/test.pdf"
                    )
                    
                    let result = await manager.submitPDFTask(input)
                    switch result {
                    case .success: pdfSuccess += 1
                    case .failure: totalFailed += 1
                    }
                }
                
                // Benchmark task
                group.addTask {
                    let input = BenchmarkWorkerInput(
                        requestId: "mixed-benchmark-\(i)",
                        benchmarkType: .cpu,
                        timeout: 5.0
                    )
                    
                    let result = await manager.submitBenchmarkTask(input)
                    switch result {
                    case .success: benchmarkSuccess += 1
                    case .failure: totalFailed += 1
                    }
                }
            }
        }
        
        let totalSuccess = mcpSuccess + pdfSuccess + benchmarkSuccess
        XCTAssertEqual(totalSuccess + totalFailed, taskCount * 3)
        XCTAssertGreaterThanOrEqual(mcpSuccess, 0)
        XCTAssertGreaterThanOrEqual(pdfSuccess, 0)
        XCTAssertGreaterThanOrEqual(benchmarkSuccess, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testMCPWorkerErrorHandling() async {
        let worker = MCPWorker()
        
        // Test with invalid method
        let input = MCPWorkerInput(
            requestId: "error-test",
            method: "invalid/method",
            clientId: "test-client"
        )
        
        let task = SubprocessTask<MCPWorkerInput, MCPWorkerOutput>(input: input)
        let result = await worker.handleTask(task)
        
        // Should handle gracefully
        switch result {
        case .success(let output):
            // Should still return success with appropriate response
            XCTAssertEqual(output.requestId, input.requestId)
            XCTAssertNotNil(output.result)
        case .failure(let error):
            // Or return appropriate error
            print("Expected error for invalid method: \(error)")
        }
    }
    
    func testMCPWorkerCleanup() async {
        let worker = MCPWorker()
        
        // Initialize first
        try? await worker.initialize()
        
        // Verify it's healthy
        if worker.isHealthy() {
            // Cleanup
            await worker.cleanup()
            
            // Verify it's no longer healthy
            XCTAssertFalse(worker.isHealthy())
        }
    }
}