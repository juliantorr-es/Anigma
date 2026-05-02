import XCTest
import Foundation
import AVFoundation
import CapsuleCore
import TelemetryCore
@testable import VizAggregationCapsule

final class VizAggregationCapsuleTests: XCTestCase {
    
    var capsule: VizAggregationCapsule!
    var diagnostics: MockDiagnostics!
    var tempDir: URL!
    
    override func setUp() async throws {
        diagnostics = MockDiagnostics()
        capsule = try VizAggregationCapsule(id: "test-capsule", diagnostics: diagnostics)
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Metadata Extraction Tests
    
    func testExtractMetadataFromValidFile() async throws {
        // Create a test video file (simplified test)
        let testFile = tempDir.appendingPathComponent("test.mp4")
        let testData = Data(repeating: 0, count: 1024) // Dummy data
        try testData.write(to: testFile)
        
        let metadata = try await capsule.extractMetadata(from: testFile)
        
        XCTAssertEqual(metadata.format, .mp4)
        XCTAssertEqual(metadata.fileSize, 1024)
        XCTAssertNotNil(metadata.creationDate)
    }
    
    func testExtractMetadataFromNonExistentFile() async throws {
        let nonExistentFile = tempDir.appendingPathComponent("nonexistent.mp4")
        
        do {
            _ = try await capsule.extractMetadata(from: nonExistentFile)
            XCTFail("Should have thrown an error")
        } catch let error as CapsuleError {
            if case .invalidInput = error {
                XCTAssertTrue(true) // Correct error type
            } else {
                XCTFail("Expected invalidInput error, got: \(error)")
            }
        }
    }
    
    // MARK: - Format Conversion Tests
    
    func testConvertValidFile() async throws {
        let inputFile = tempDir.appendingPathComponent("input.mp4")
        let outputFile = tempDir.appendingPathComponent("output.mp4")
        let testData = Data(repeating: 0, count: 1024)
        try testData.write(to: inputFile)
        
        var progressValues: [Double] = []
        try await capsule.convertFormat(
            inputURL: inputFile,
            outputURL: outputFile,
            outputFormat: .mp4
        ) { progress in
            progressValues.append(progress)
        }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputFile.path))
        XCTAssertTrue(progressValues.contains(1.0)) // Should reach completion
    }
    
    // MARK: - Aggregation Tests
    
    func testAggregateMultipleFiles() async throws {
        // Create test files
        let file1 = tempDir.appendingPathComponent("file1.mp4")
        let file2 = tempDir.appendingPathComponent("file2.mp4")
        let output = tempDir.appendingPathComponent("aggregated.mp4")
        
        let testData = Data(repeating: 0, count: 512)
        try testData.write(to: file1)
        try testData.write(to: file2)
        
        let result = try await capsule.aggregate(
            mediaURLs: [file1, file2],
            outputFormat: .mp4,
            outputPath: output.path
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.metadata.count, 2)
        XCTAssertEqual(result.outputFormat, .mp4)
        XCTAssertGreaterThan(result.processingTime, 0)
    }
    
    func testAggregateEmptyArray() async throws {
        do {
            _ = try await capsule.aggregate(
                mediaURLs: [],
                outputFormat: .mp4,
                outputPath: "/tmp/output.mp4"
            )
            XCTFail("Should have thrown an error")
        } catch let error as CapsuleError {
            if case .invalidInput = error {
                XCTAssertTrue(true) // Correct error type
            } else {
                XCTFail("Expected invalidInput error, got: \(error)")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testMetadataExtractionPerformance() async throws {
        let testFile = tempDir.appendingPathComponent("perf_test.mp4")
        let testData = Data(repeating: 0, count: 1024)
        try testData.write(to: testFile)
        
        measure {
            Task {
                do {
                    _ = try await capsule.extractMetadata(from: testFile)
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testUnsupportedFormatError() async throws {
        let testFile = tempDir.appendingPathComponent("test.unsupported")
        let testData = Data(repeating: 0, count: 1024)
        try testData.write(to: testFile)
        
        do {
            _ = try await capsule.extractMetadata(from: testFile)
            XCTFail("Should have thrown an error for unsupported format")
        } catch let error as CapsuleError {
            if case .invalidInput = error {
                XCTAssertTrue(true) // Correct error type
            } else {
                XCTFail("Expected invalidInput error, got: \(error)")
            }
        }
    }
    
    // MARK: - Health Status Tests
    
    func testHealthStatus() {
        let health = capsule.healthStatus()
        
        XCTAssertEqual(health["capsule_id"], "test-capsule")
        XCTAssertEqual(health["status"], "healthy")
        XCTAssertNotNil(health["timestamp"])
    }
    
    // MARK: - Edge Cases
    
    func testEmojiFileName() async throws {
        let testFile = tempDir.appendingPathComponent("🚀test.mp4")
        let testData = Data(repeating: 0, count: 1024)
        try testData.write(to: testFile)
        
        let metadata = try await capsule.extractMetadata(from: testFile)
        XCTAssertEqual(metadata.fileSize, 1024)
    }
    
    func testLargeFileHandling() async throws {
        let testFile = tempDir.appendingPathComponent("large.mp4")
        let testData = Data(repeating: 0, count: 10 * 1024 * 1024) // 10MB
        try testData.write(to: testFile)
        
        let metadata = try await capsule.extractMetadata(from: testFile)
        XCTAssertEqual(metadata.fileSize, 10 * 1024 * 1024)
    }
}
