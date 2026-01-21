//
//  ConcurrencyDoctrinePackTests.swift
//  GovernedMigrationCoreTests
//
//  Unit tests for GovernedMigrationCoreTests.
//

import XCTest
@testable import GovernedMigrationCore
import DoctrineCore

final class ConcurrencyDoctrinePackTests: XCTestCase {
    func testDetectsSendableViolation_CS002() async throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "SendableViolation", withExtension: "swift"),
            "Fixture missing from Bundle.module. Check Package.swift resources config."
        )

        let pack = ConcurrencyDoctrinePack()
        let violations = try await pack.evaluate(for: url)

        XCTAssertEqual(violations.count, 1, "Expected exactly one violation for the Sendable fixture.")

        let violation = try XCTUnwrap(violations.first)
        XCTAssertEqual(violation.ruleId, "CS-002", "Violation rule ID should be CS-002 for Sendable errors.")

        let contextLowercased = violation.context?.lowercased() ?? ""
        XCTAssertTrue(
            contextLowercased.contains("sendable"),
            "Violation context should mention 'Sendable'."
        )
    }
}
