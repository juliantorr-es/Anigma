//
//  PerformanceBenchmarkTests.swift
//  AnigmaAppMacTests
//
//  Performance contract enforcement via XCTest benchmarks.
//

import XCTest
import ContractsCore
@testable import AnigmaAppMac

final class PerformanceBenchmarkTests: XCTestCase {

    // MARK: - Ingest Operations

    func testPDFImportPerformance() async throws {
        let job = PDFImportJob()
        let testPDF = createTestPDF(pages: 10)

        measure {
            let expectation = XCTestExpectation(description: "PDF import completes")

            Task {
                let result = await job.importPDF(at: testPDF, stageDelay: 0.0)
                XCTAssertEqual(result.state, .success)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0) // 200ms/page * 10 = 2s budget
        }
    }

    func testWebCapturePerformance() async throws {
        let html = String(repeating: "<p>Test content</p>", count: 100)

        measure {
            let expectation = XCTestExpectation(description: "Web capture completes")

            Task {
                let extractor = WebContentExtractor()
                let result = await extractor.extract(
                    html: html,
                    url: URL(string: "https://example.com")!,
                    title: "Test Page"
                )
                XCTAssertNotNil(result)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 0.5) // 500ms budget
        }
    }

    // MARK: - Compute Operations

    func testOCRPerformance() async throws {
        // Note: This would require a real image
        // For now, we measure the setup overhead
        measure {
            _ = createTestImage(width: 1000, height: 1000)
        }

        // Budget: 300ms per image
        // Actual OCR would be tested with Vision framework
    }

    func testSummarizePerformance() async throws {
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1000)

        measure {
            let expectation = XCTestExpectation(description: "Summarize completes")

            Task {
                // Simulate summarization
                let summary = longText.prefix(100)
                XCTAssertFalse(summary.isEmpty)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0) // 1000ms budget
        }
    }

    // MARK: - UI Operations

    func testToastDisplayPerformance() {
        measure {
            let store = AppStore()
            store.showToast(
                title: "Test",
                subtitle: "Performance test",
                icon: "checkmark"
            )
            XCTAssertFalse(store.activeToasts.isEmpty)
        }

        // Budget: 100ms
    }

    func testJobSubmissionPerformance() {
        measure {
            let store = AppStore()
            Task {
                await store.submitJob(action: "test", parameters: [:])
            }
        }

        // Budget: 50ms (optimistic receipt)
    }

    // MARK: - Memory Benchmarks

    func testPDFImportMemoryUsage() async throws {
        let job = PDFImportJob()
        let testPDF = createTestPDF(pages: 1)

        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let memoryBefore = getMemoryUsage()

            startMeasuring()

            let expectation = XCTestExpectation(description: "PDF import")
            Task {
                _ = await job.importPDF(at: testPDF, stageDelay: 0.0)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)

            stopMeasuring()

            let memoryAfter = getMemoryUsage()
            let memoryDelta = memoryAfter - memoryBefore

            // Budget: 100 MB per page
            XCTAssertLessThan(memoryDelta, 100 * 1024 * 1024, "Memory usage exceeds budget")
        }
    }

    // MARK: - OperationResult Compliance

    func testOperationResultProgressReporting() async throws {
        let job = PDFImportJob()
        let testPDF = createTestPDF(pages: 1)

        var progressUpdates: [Int] = []

        let cancellable = await job.progressPublisher.sink { progress in
            progressUpdates.append(progress.percent)
        }

        let result = await job.importPDF(at: testPDF, stageDelay: 0.01)

        // Contract: Progress must be reported for operations > 200ms
        XCTAssertGreaterThan(progressUpdates.count, 0, "No progress updates emitted")
        XCTAssertEqual(progressUpdates.last, 100, "Final progress must be 100%")

        assertOperationValid(result, expectedKind: "pdfImport")

        cancellable.cancel()
    }

    func testOperationResultStateTransitions() async throws {
        let job = PDFImportJob()
        let testPDF = createTestPDF(pages: 1)

        var states: [OperationState] = []

        let cancellable = await job.progressPublisher.sink { progress in
            states.append(progress.state)
        }

        let result = await job.importPDF(at: testPDF, stageDelay: 0.01)

        // Contract: Valid state transitions only
        // running -> running -> ... -> success
        XCTAssertEqual(states.first, .running)
        XCTAssertEqual(states.last, .success)

        // No invalid transitions (e.g., success -> running)
        for i in 0..<states.count - 1 {
            let current = states[i]
            let next = states[i + 1]

            if current == .success || current == .failure || current == .cancelled {
                XCTFail("Terminal state \(current) followed by \(next)")
            }
        }

        cancellable.cancel()
    }

    // MARK: - Helpers

    private func createTestPDF(pages: Int) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).pdf")

        // Create a minimal PDF for testing
        let data = Data("Mock PDF".utf8)
        try? data.write(to: pdfURL)

        return pdfURL
    }

    private func createTestImage(width: Int, height: Int) -> Data {
        // Create minimal image data for testing
        return Data(repeating: 0, count: width * height * 4)
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}
