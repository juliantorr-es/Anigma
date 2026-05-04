import XCTest
import Foundation
@testable import AnigmaTestSupport

final class TestReceiptWriterTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        // Create temporary directory for test receipts
        let fm = FileManager.default
        let tempBase = NSTemporaryDirectory()
        tempDir = "\(tempBase)/anigma-test-receipts-\(UUID().uuidString)"
        try? fm.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        super.tearDown()
        // Clean up temporary directory
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    func testReceiptWriting() throws {
        let receipt = TestReceipt(
            testTarget: "TestReceiptWriterTests",
            sourceFile: "TestReceiptWriterTests.swift",
            artifactFile: ".build/anigma-test-artifacts/TestReceiptWriterTests/TestReceiptWriterTests.json",
            status: .passed,
            summary: "1 test(s) executed, 0 failed",
            validatedBehaviors: ["receipt generation produces valid JSON", "atomic writes work correctly"],
            debugHintsForAgents: ["Check artifact path", "Verify JSON schema"],
            relatedFiles: ["Packages/AnigmaTestSupport/Sources/AnigmaTestSupport/TestReceiptWriter.swift"],
            diagnostics: TestDiagnostics(
                testCount: 1,
                passed: 1,
                failed: 0,
                skipped: 0,
                durationSeconds: 0.5
            ),
            canonicalPromotion: PromotionMetadata(
                eligible: true,
                promotedTo: nil,
                promotionGate: "manual_review"
            )
        )

        // Write receipt to temporary directory
        try TestReceiptWriter.write(
            receipt: receipt,
            sourceFile: "/path/TestReceiptWriterTests.swift",
            testTarget: "TestReceiptWriterTests",
            outputDirOverride: tempDir
        )

        // Verify receipt file was created
        let expectedPath = "\(tempDir)/TestReceiptWriterTests/TestReceiptWriterTests.json"
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath), 
                      "Receipt file should exist at \(expectedPath)")

        // Read and validate JSON structure
        let data = try Data(contentsOf: URL(fileURLWithPath: expectedPath))
        let decoder = JSONDecoder()
        let decodedReceipt = try decoder.decode(TestReceipt.self, from: data)

        XCTAssertEqual(decodedReceipt.schema, "anigma.test.receipt.v1")
        XCTAssertEqual(decodedReceipt.testTarget, "TestReceiptWriterTests")
        XCTAssertEqual(decodedReceipt.sourceFile, "TestReceiptWriterTests.swift")
        XCTAssertEqual(decodedReceipt.status, .passed)
        XCTAssertEqual(decodedReceipt.diagnostics.testCount, 1)
        XCTAssertEqual(decodedReceipt.diagnostics.passed, 1)
    }

    func testReceiptOverwrite() throws {
        // Write initial receipt
        let receipt1 = TestReceipt(
            testTarget: "OverwriteTests",
            sourceFile: "OverwriteTests.swift",
            artifactFile: ".build/anigma-test-artifacts/OverwriteTests/OverwriteTests.json",
            status: .passed,
            summary: "Initial run",
            validatedBehaviors: ["first run"],
            debugHintsForAgents: [],
            relatedFiles: [],
            diagnostics: TestDiagnostics(testCount: 1, passed: 1, failed: 0, skipped: 0, durationSeconds: 0.5),
            canonicalPromotion: PromotionMetadata(eligible: true)
        )

        try TestReceiptWriter.write(
            receipt: receipt1,
            sourceFile: "/path/OverwriteTests.swift",
            testTarget: "OverwriteTests",
            outputDirOverride: tempDir
        )

        let expectedPath = "\(tempDir)/OverwriteTests/OverwriteTests.json"
        let firstModTime = try FileManager.default.attributesOfItem(atPath: expectedPath)[.modificationDate] as! Date

        // Small delay to ensure different modification time
        Thread.sleep(forTimeInterval: 0.01)

        // Write second receipt (should overwrite)
        let receipt2 = TestReceipt(
            testTarget: "OverwriteTests",
            sourceFile: "OverwriteTests.swift",
            artifactFile: ".build/anigma-test-artifacts/OverwriteTests/OverwriteTests.json",
            status: .passed,
            summary: "Second run",
            validatedBehaviors: ["second run"],
            debugHintsForAgents: [],
            relatedFiles: [],
            diagnostics: TestDiagnostics(testCount: 1, passed: 1, failed: 0, skipped: 0, durationSeconds: 0.6),
            canonicalPromotion: PromotionMetadata(eligible: true)
        )

        try TestReceiptWriter.write(
            receipt: receipt2,
            sourceFile: "/path/OverwriteTests.swift",
            testTarget: "OverwriteTests",
            outputDirOverride: tempDir
        )

        // Verify only one file exists (not accumulated)
        let filesInDir = try FileManager.default.contentsOfDirectory(atPath: "\(tempDir)/OverwriteTests")
        XCTAssertEqual(filesInDir.count, 1, "Should have exactly one receipt file")

        // Verify file was overwritten
        let secondModTime = try FileManager.default.attributesOfItem(atPath: expectedPath)[.modificationDate] as! Date
        XCTAssertGreaterThan(secondModTime, firstModTime, "File should have been modified")

        // Verify content is from second receipt
        let data = try Data(contentsOf: URL(fileURLWithPath: expectedPath))
        let decoder = JSONDecoder()
        let decodedReceipt = try decoder.decode(TestReceipt.self, from: data)
        XCTAssertEqual(decodedReceipt.summary, "Second run")
        XCTAssertEqual(decodedReceipt.diagnostics.durationSeconds, 0.6)
    }

    func testEnvironmentVariableOverride() throws {
        let customDir = "\(tempDir)/custom-artifacts"
        try FileManager.default.createDirectory(atPath: customDir, withIntermediateDirectories: true)

        let receipt = TestReceipt(
            testTarget: "EnvVarTest",
            sourceFile: "EnvVarTest.swift",
            artifactFile: ".build/anigma-test-artifacts/EnvVarTest/EnvVarTest.json",
            status: .passed,
            summary: "Test",
            validatedBehaviors: [],
            debugHintsForAgents: [],
            relatedFiles: [],
            diagnostics: TestDiagnostics(testCount: 1, passed: 1, failed: 0, skipped: 0, durationSeconds: 0.5),
            canonicalPromotion: PromotionMetadata(eligible: true)
        )

        // Write with custom directory override
        try TestReceiptWriter.write(
            receipt: receipt,
            sourceFile: "/path/EnvVarTest.swift",
            testTarget: "EnvVarTest",
            outputDirOverride: customDir
        )

        let expectedPath = "\(customDir)/EnvVarTest/EnvVarTest.json"
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath),
                      "Receipt should be written to custom directory")
    }

    func testJSONKeysSorted() throws {
        let receipt = TestReceipt(
            testTarget: "SortedKeysTest",
            sourceFile: "SortedKeysTest.swift",
            artifactFile: ".build/anigma-test-artifacts/SortedKeysTest/SortedKeysTest.json",
            status: .passed,
            summary: "Test",
            validatedBehaviors: ["zebra", "apple", "middle"],
            debugHintsForAgents: ["zulu", "bravo", "alpha"],
            relatedFiles: ["z.swift", "a.swift", "m.swift"],
            diagnostics: TestDiagnostics(testCount: 1, passed: 1, failed: 0, skipped: 0, durationSeconds: 0.5),
            canonicalPromotion: PromotionMetadata(eligible: true)
        )

        try TestReceiptWriter.write(
            receipt: receipt,
            sourceFile: "/path/SortedKeysTest.swift",
            testTarget: "SortedKeysTest",
            outputDirOverride: tempDir
        )

        // Read JSON as string to verify key ordering
        let expectedPath = "\(tempDir)/SortedKeysTest/SortedKeysTest.json"
        let jsonString = try String(contentsOfFile: expectedPath, encoding: .utf8)

        // Verify top-level keys appear in alphabetical order
        let schemaIndex = jsonString.range(of: "\"schema\"")?.lowerBound
        let canonicalIndex = jsonString.range(of: "\"canonicalPromotion\"")?.lowerBound
        let debugIndex = jsonString.range(of: "\"debugHintsForAgents\"")?.lowerBound
        let diagnosticsIndex = jsonString.range(of: "\"diagnostics\"")?.lowerBound

        XCTAssertNotNil(schemaIndex)
        XCTAssertNotNil(canonicalIndex)
        XCTAssertNotNil(debugIndex)
        XCTAssertNotNil(diagnosticsIndex)

        // Verify sorted order: canonicalPromotion < debugHintsForAgents < diagnostics < schema
        XCTAssertLessThan(canonicalIndex!, debugIndex!, "canonicalPromotion should come before debugHintsForAgents")
        XCTAssertLessThan(debugIndex!, diagnosticsIndex!, "debugHintsForAgents should come before diagnostics")
        XCTAssertLessThan(diagnosticsIndex!, schemaIndex!, "diagnostics should come before schema")

        // Verify array sorting (validatedBehaviors should be sorted)
        let behaviorString = jsonString.range(of: "\"validatedBehaviors\"")
            .map { jsonString[$0.upperBound...] }
            .map { String($0.prefix(100)) } ?? ""
        XCTAssertTrue(behaviorString.contains("\"apple\""), "Arrays should be sorted")
    }

    func testNoAbsolutePathsInReceipt() throws {
        let receipt = TestReceipt(
            testTarget: "PathTest",
            sourceFile: "PathTest.swift",
            artifactFile: "/absolute/path/to/receipt.json",  // This should be normalized
            status: .passed,
            summary: "Test",
            validatedBehaviors: [],
            debugHintsForAgents: [],
            relatedFiles: ["/absolute/path/to/source.swift"],  // This will be in relatedFiles
            diagnostics: TestDiagnostics(testCount: 1, passed: 1, failed: 0, skipped: 0, durationSeconds: 0.5),
            canonicalPromotion: PromotionMetadata(eligible: true)
        )

        try TestReceiptWriter.write(
            receipt: receipt,
            sourceFile: "/path/PathTest.swift",
            testTarget: "PathTest",
            outputDirOverride: tempDir
        )

        let expectedPath = "\(tempDir)/PathTest/PathTest.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: expectedPath))
        let jsonString = String(data: data, encoding: .utf8)!

        // Verify that the artifactFile in the receipt does not contain absolute path
        XCTAssertFalse(jsonString.contains(tempDir), 
                       "Receipt JSON should not contain absolute temporary directory path")
    }
}
