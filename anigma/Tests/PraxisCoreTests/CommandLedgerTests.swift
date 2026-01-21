//
//  CommandLedgerTests.swift
//  PraxisCoreTests
//
//  Unit tests for PraxisCoreTests.
//

import XCTest
@testable import PraxisCore

final class CommandLedgerTests: XCTestCase {
  func testLedgerAppendAndSessionAggregation() throws {
    let repoRoot = try makeTempRepoRoot()
    let ledger = CommandLedger(repoRoot: repoRoot)
    try ledger.append(kind: "run", sessionID: "session-1", agent: "plan", command: "greet", messageID: "receipt-id", detail: ["decision": "allow"])

    let reader = CommandLedgerReader(repoRoot: repoRoot)
    let records = try reader.load()
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records[0].meta.sessionID, "session-1")

    let grouped = reader.sessions(from: records)
    XCTAssertEqual(grouped["session-1"]?.count, 1)
  }

  private func makeTempRepoRoot() throws -> URL {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return tmp
  }
}
