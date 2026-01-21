//
//  StackPlannerTests.swift
//  PraxisCoreTests
//
//  Unit tests for PraxisCoreTests.
//

import XCTest
@testable import PraxisCore

final class StackPlannerTests: XCTestCase {
    func testOrdersBranchesByParentChain() throws {
        let record = StackRecord(
            stackID: "demo",
            baseBranch: "main",
            branches: [
                .init(name: "b2", parent: "b1"),
                .init(name: "b1", parent: "main"),
                .init(name: "b3", parent: "b2")
            ]
        )
        let planner = StackPlanner()
        let ordered = try planner.orderedBranches(record: record).map(\.name)
        XCTAssertEqual(Set(ordered), Set(["b1", "b2", "b3"]))
    }
}
