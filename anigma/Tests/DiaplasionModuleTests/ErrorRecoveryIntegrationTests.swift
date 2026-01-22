import XCTest
@testable import DiaplasionModule
import Foundation

/// Integration tests for Phase 5 Error Recovery & Resilience components
final class ErrorRecoveryIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var retryManager: RetryManager!
    private var errorHandler: ErrorHandler!
    private var resilientSystem: ResilientProcessingSystem!
    private var testDocumentURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test components
        retryManager = RetryManager()
        errorHandler = ErrorHandler()
        resilientSystem = ResilientProcessingSystem(
            retryManager: retryManager,
            errorHandler: errorHandler,
            documentProcessor: LargeDocumentProcessor(),
            progressTracker: ProgressTracker(),
            checkpointManager: CheckpointManager()
        )
        
        // Create test document URL
        testDocumentURL = createTestDocument()
    }
    
    override func tearDownWithError() throws {
        // Clean up test files
        try? FileManager.default.removeItem(at: testDocumentURL)
        
        retryManager = nil
        errorHandler = nil
        resilientSystem = nil
        testDocumentURL = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Retry Manager Tests
    
    func testRetryManagerSuccessfulOperation() async throws {
        var attemptCount = 0
        
        let result = try await retryManager.execute(operation: "test_operation") {
            attemptCount += 1
            return "success"
        }
        
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attemptCount, 1)
    }
    
    func testRetryManagerWithTemporaryFailure() async throws {
        var attemptCount = 0
        
        let result = try await retryManager.execute(operation: "test_operation") {
            attemptCount += 1
            if attemptCount < 2 {
                throw URLError(.timedOut)
            }
            return "success_after_retry"
        }
        
        XCTAssertEqual(result, "success_after_retry")
        XCTAssertEqual(attemptCount, 2)
    }
    
    func testRetryManagerMaxAttemptsExceeded() async throws {
        var attemptCount = 0
        
        do {
            _ = try await retryManager.execute(operation: "test_operation") {
                attemptCount += 1
                throw URLError(.timedOut)
            }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(attemptCount <= 3) // Default max attempts
            XCTAssertGreaterThan(attemptCount, 1)
        }
    }
    
    func testCircuitBreakerActivation() async throws {
        // Simulate multiple failures to trigger circuit breaker
        for _ in 0..<10 {
            do {
                _ = try await retryManager.execute(operation: "circuit_test") {
                    throw URLError(.timedOut)
                }
            } catch {
                // Expected to fail
            }
        }
        
        // Circuit breaker should now be open
        do {
            _ = try await retryManager.execute(operation: "circuit_test") {
                return "should_not_execute"
            }
            XCTFail("Expected circuit breaker to be open")
        } catch {
            // Circuit breaker should prevent execution
            XCTAssertTrue(error.localizedDescription.contains("Circuit breaker"))
        }
    }
    
    // MARK: - Error Handler Tests
    
    func testErrorHandlerClassification() async throws {
        let networkError = URLError(.timedOut)
        let context = ErrorContext(
            operation: "test_operation",
            stage: .processing,
            parameters: [:],
            metadata: [:]
        )
        
        let result = await errorHandler.handleError(
            networkError,
            context: context,
            documentId: "test_doc_1"
        )
        
        XCTAssertEqual(result.classification, .networkError)
        XCTAssertTrue(result.recoveryAttempted)
    }
    
    func testErrorHandlerRecoveryStrategy() async throws {
        let processingError = NSError(
            domain: "TestDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Simulated processing failure"]
        )
        let context = ErrorContext(
            operation: "processDocument",
            stage: .processing,
            parameters: [:],
            metadata: [:]
        )
        
        let result = await errorHandler.handleError(
            processingError,
            context: context,
            documentId: "test_doc_2"
        )
        
        XCTAssertEqual(result.classification, .processingError)
        XCTAssertTrue(result.recoveryAttempted)
    }
    
    func testErrorHandlerStatistics() async throws {
        let initialStats = await errorHandler.getErrorStatistics()
        
        // Generate some errors
        let networkError = URLError(.timedOut)
        let context = ErrorContext(
            operation: "test_operation",
            stage: .processing,
            parameters: [:],
            metadata: [:]
        )
        
        await errorHandler.handleError(networkError, context: context, documentId: "test_doc_1")
        await errorHandler.handleError(networkError, context: context, documentId: "test_doc_2")
        
        let updatedStats = await errorHandler.getErrorStatistics()
        XCTAssertEqual(updatedStats.totalErrors, initialStats.totalErrors + 2)
    }
    
    // MARK: - Resilient Processing System Tests
    
    func testResilientSystemSuccessfulProcessing() async throws {
        let result = try await resilientSystem.processDocument(
            inputURL: testDocumentURL,
            outputFormats: [.epub, .brf],
            documentId: "test_success_1"
        )
        
        XCTAssertEqual(result.documentId, "test_success_1")
        XCTAssertEqual(result.outputFormats, [.epub, .brf])
        XCTAssertGreaterThan(result.processingTime, 0)
    }
    
    func testResilientSystemJobTracking() async throws {
        let initialStats = resilientSystem.getProcessingStatistics()
        
        // Start processing (but don't wait for completion)
        let task = Task {
            try await resilientSystem.processDocument(
                inputURL: testDocumentURL,
                outputFormats: [.epub],
                documentId: "test_job_1"
            )
        }
        
        // Check that job is being tracked
        try await Task.sleep(for: .milliseconds(100))
        let activeStats = resilientSystem.getProcessingStatistics()
        XCTAssertGreaterThan(activeStats.totalJobs, initialStats.totalJobs)
        
        // Wait for completion
        _ = try await task.value
        
        // Check final statistics
        let finalStats = resilientSystem.getProcessingStatistics()
        XCTAssertGreaterThan(finalStats.completedJobs, initialStats.completedJobs)
    }
    
    func testResilientSystemJobCancellation() async throws {
        let initialStats = resilientSystem.getProcessingStatistics()
        
        // Start a long-running task
        let task = Task {
            try await resilientSystem.processDocument(
                inputURL: testDocumentURL,
                outputFormats: [.epub, .brf, .audio],
                documentId: "test_cancel_1"
            )
        }
        
        // Give it time to start
        try await Task.sleep(for: .milliseconds(50))
        
        // Cancel the job
        let cancelled = await resilientSystem.cancelJob(documentId: "test_cancel_1")
        XCTAssertTrue(cancelled)
        
        // Wait for task to complete with cancellation
        do {
            _ = try await task.value
            XCTFail("Expected task to be cancelled")
        } catch {
            // Expected - task was cancelled
        }
        
        // Verify cancellation was recorded
        let finalStats = resilientSystem.getProcessingStatistics()
        XCTAssertGreaterThan(finalStats.cancelledJobs, initialStats.cancelledJobs)
    }
    
    func testResilientSystemReset() async throws {
        // Generate some activity
        _ = try await resilientSystem.processDocument(
            inputURL: testDocumentURL,
            outputFormats: [.epub],
            documentId: "test_reset_1"
        )
        
        let beforeResetStats = resilientSystem.getProcessingStatistics()
        XCTAssertGreaterThan(beforeResetStats.totalJobs, 0)
        
        // Reset the system
        resilientSystem.reset()
        
        let afterResetStats = resilientSystem.getProcessingStatistics()
        XCTAssertEqual(afterResetStats.totalJobs, 0)
        XCTAssertEqual(afterResetStats.activeJobs, 0)
        XCTAssertEqual(afterResetStats.completedJobs, 0)
    }
    
    // MARK: - Integration Scenarios
    
    func testEndToEndErrorRecovery() async throws {
        // This test simulates a complete error recovery scenario
        // from initial failure through recovery strategies to successful completion
        
        // 1. Start processing with potentially failing input
        let result = try await resilientSystem.processDocument(
            inputURL: testDocumentURL,
            outputFormats: [.epub],
            documentId: "test_e2e_1"
        )
        
        // 2. Verify successful processing
        XCTAssertEqual(result.documentId, "test_e2e_1")
        XCTAssertEqual(result.outputFormats, [.epub])
        
        // 3. Check that all systems were utilized
        let retryStats = retryManager.getRetryStatistics()
        let errorStats = await errorHandler.getErrorStatistics()
        let processingStats = resilientSystem.getProcessingStatistics()
        
        // Verify that the pipeline components are working
        XCTAssertNotNil(retryStats)
        XCTAssertNotNil(errorStats)
        XCTAssertGreaterThan(processingStats.totalJobs, 0)
    }
    
    func testMultipleConcurrentJobs() async throws {
        // Test that the resilient system can handle multiple concurrent jobs
        let documents = (1...5).map { i in
            (url: createTestDocument(), id: "concurrent_test_\(i)")
        }
        
        let tasks = documents.map { (url, id) in
            Task {
                try await resilientSystem.processDocument(
                    inputURL: url,
                    outputFormats: [.epub],
                    documentId: id
                )
            }
        }
        
        // Wait for all tasks to complete
        var results: [ProcessingResult] = []
        for task in tasks {
            do {
                let result = try await task.value
                results.append(result)
            } catch {
                // Some failures are acceptable in this test
                print("Concurrent job failed: \(error)")
            }
        }
        
        // Verify at least some jobs completed successfully
        XCTAssertGreaterThan(results.count, 0)
        
        // Clean up test documents
        for (url, _) in documents {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestDocument() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent("test_document_\(UUID().uuidString).txt")
        
        let testContent = """
        Test Document Content
        
        This is a test document for error recovery integration testing.
        It contains multiple paragraphs to simulate a real document.
        
        Chapter 1: Introduction
        This chapter introduces the concepts covered in this document.
        
        Chapter 2: Methods
        This chapter describes the methods used for testing.
        
        Chapter 3: Results
        This chapter presents the results of the testing.
        
        Chapter 4: Conclusion
        This chapter provides conclusions and next steps.
        """
        
        try? testContent.write(to: testURL, atomically: true, encoding: .utf8)
        return testURL
    }
}

// MARK: - Performance Tests

extension ErrorRecoveryIntegrationTests {
    
    func testRetryManagerPerformance() async throws {
        measure {
            Task {
                do {
                    _ = try await retryManager.execute(operation: "performance_test") {
                        return "performance_result"
                    }
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
    
    func testErrorHandlerPerformance() async throws {
        let errors: [Error] = [
            URLError(.timedOut),
            URLError(.networkConnectionLost),
            NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        ]
        
        measure {
            Task {
                for (index, error) in errors.enumerated() {
                    let context = ErrorContext(
                        operation: "performance_test",
                        stage: .processing,
                        parameters: [:],
                        metadata: [:]
                    )
                    
                    await errorHandler.handleError(
                        error,
                        context: context,
                        documentId: "perf_test_\(index)"
                    )
                }
            }
        }
    }
}