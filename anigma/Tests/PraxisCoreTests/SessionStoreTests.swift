//
//  SessionStoreTests.swift
//  PraxisCoreTests
//
//  Unit tests for PraxisCoreTests.
//

import XCTest
@testable import PraxisCore

final class SessionStoreTests: XCTestCase {
  func testSessionLifecycle() throws {
    let repoRoot = try makeRepoRoot()
    let store = SessionStore(repoRoot: repoRoot)

    XCTAssertNil(store.lastSessionID())
    let session = try store.createSession(agentProfile: "plan")
    XCTAssertEqual(session.agentProfile, "plan")
    XCTAssertEqual(store.lastSessionID(), session.sessionID)

    let reloaded = try store.load(sessionID: session.sessionID)
    XCTAssertEqual(reloaded.sessionID, session.sessionID)

    try store.recordCommand(sessionID: session.sessionID, commandName: "foo")
    let updated = try store.load(sessionID: session.sessionID)
    XCTAssertEqual(updated.lastCommand, "foo")
  }

  private func makeRepoRoot() throws -> URL {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return tmp
  }
}
