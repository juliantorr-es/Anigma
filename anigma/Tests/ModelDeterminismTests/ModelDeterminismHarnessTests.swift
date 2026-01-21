//
//  ModelDeterminismHarnessTests.swift
//  Anigma
//
//  XCTest integration for ModelDeterminismHarness
//  Moved from production code to keep XCTest out of the main binary
//

import XCTest
@testable import ModelRegistry
import ContractsCore

final class ModelDeterminismHarnessTests: XCTestCase {

    /// Helper to run baseline verification as XCTest - fail build on drift
    func testModelBaseline(
        harness: ModelDeterminismHarness,
        modelId: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let result = try await harness.verifyAgainstBaseline(modelId: modelId)

        let report = harness.generateDriftReport(result)

        XCTAssertEqual(
            result.verdict, .pass,
            report,
            file: file,
            line: line
        )
    }

    // Example test case - you would add your specific models here
    func testExampleModel() async throws {
        // This is a placeholder - actual tests would be added based on your models
        // let harness = ModelDeterminismHarness(...)
        // try await testModelBaseline(harness: harness, modelId: "your-model-id")
    }
}
