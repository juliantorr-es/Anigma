//
//  CommandRendererTests.swift
//  PraxisCoreTests
//
//  Unit tests for PraxisCoreTests.
//

import XCTest
@testable import PraxisCore

final class CommandRendererTests: XCTestCase {
  func testRendererReplacesVariables() {
    let renderer = CommandRenderer()
    let template = "Hello $WHO! Action: $ACTION"
    let context = ["WHO": "Agent", "ACTION": "plan"]
    let result = renderer.render(template: template, context: context)
    XCTAssertEqual(result, "Hello Agent! Action: plan")
  }

  func testRendererLeavesUnknownTokens() {
    let renderer = CommandRenderer()
    let template = "No substitution: $UNKNOWN"
    let result = renderer.render(template: template, context: [:])
    XCTAssertEqual(result, "No substitution: $UNKNOWN")
  }
}
