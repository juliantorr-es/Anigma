//
//  AgentProfileTests.swift
//  PraxisCoreTests
//
//  Unit tests for PraxisCoreTests.
//

import XCTest
@testable import PraxisCore

final class AgentProfileTests: XCTestCase {
  func testPermissionPolicyDenyOverridesAsk() {
    let policy = PermissionPolicy(denyTokens: ["rm"], askTokens: ["git"])
    XCTAssertEqual(policy.evaluate(command: "rm -rf /tmp"), .deny)
  }

  func testPermissionPolicyAskTriggersForToken() {
    let policy = PermissionPolicy(denyTokens: [], askTokens: ["git commit"])
    XCTAssertEqual(policy.evaluate(command: "git commit -m message"), .ask)
  }

  func testPermissionPolicyAllowByDefault() {
    let policy = PermissionPolicy()
    XCTAssertEqual(policy.evaluate(command: "echo hi"), .allow)
  }

  func testRegistryProvidesDefaultProfiles() throws {
    let registry = AgentProfileRegistry()
    let plan = try registry.profile(named: "plan")
    XCTAssertEqual(plan.name, "plan")
    let build = try registry.profile(named: "build")
    XCTAssertEqual(build.permissionPolicy.evaluate(command: "rm -rf /tmp"), .deny)
  }
}
