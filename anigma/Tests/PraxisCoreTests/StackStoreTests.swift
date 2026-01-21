//
//  StackStoreTests.swift
//  PraxisCoreTests
//
//  Unit tests for PraxisCoreTests.
//

import XCTest
@testable import PraxisCore

final class StackStoreTests: XCTestCase {
    func testCreateAndLoad() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("anigma-stackstore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let store = StackStore(repoRoot: tmp)
        let rec = try store.create(stackID: "demo", baseBranch: "main", remote: "origin", force: false)
        XCTAssertEqual(rec.stackID, "demo")

        let loaded = try store.load(stackID: "demo")
        XCTAssertEqual(loaded.remote, "origin")
    }
}
