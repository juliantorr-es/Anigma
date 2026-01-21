//
//  CommandSpecTests.swift
//  PraxisCoreTests
//
//  Unit tests for PraxisCoreTests.
//

import XCTest
@testable import PraxisCore

final class CommandSpecTests: XCTestCase {
  func testMarkdownCommandParsedWithFrontMatter() throws {
    let repoRoot = try makeTempRepoRoot()
    let commandDir = repoRoot.appendingPathComponent(".anigma/command", isDirectory: true)
    try FileManager.default.createDirectory(at: commandDir, withIntermediateDirectories: true)

    let markdown = """
    ---
    name: say-hello
    description: Greet someone politely.
    agent: plan
    ---
    Hello, $NAME!
    """
    let fileURL = commandDir.appendingPathComponent("say-hello.md")
    try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

    let catalog = CommandSpecCatalog(repoRoot: repoRoot)
    let specs = try catalog.loadSpecs()

    XCTAssertEqual(specs.count, 1)
    let spec = specs[0]
    XCTAssertEqual(spec.name, "say-hello")
    XCTAssertEqual(spec.description, "Greet someone politely.")
    XCTAssertEqual(spec.agentProfile, "plan")
    XCTAssertEqual(spec.source, .project)
    XCTAssertTrue(spec.template.contains("Hello, $NAME"))
  }

  func testConfigCommandsLoadedFromJsonc() throws {
    let repoRoot = try makeTempRepoRoot()
    let anigmaDir = repoRoot.appendingPathComponent(".anigma", isDirectory: true)
    try FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)

    let config = """
    {
      // team commands
      "commands": {
        "config-greet": {
          "description": "Config defined greeting.",
          "agentProfile": "build",
          "template": "echo config-$VALUE"
        }
      }
    }
    """
    let configURL = anigmaDir.appendingPathComponent("anigma.jsonc")
    try config.write(to: configURL, atomically: true, encoding: .utf8)

    let catalog = CommandSpecCatalog(repoRoot: repoRoot)
    let specs = try catalog.loadSpecs()

    XCTAssertEqual(specs.count, 1)
    let spec = specs[0]
    XCTAssertEqual(spec.name, "config-greet")
    XCTAssertEqual(spec.agentProfile, "build")
    XCTAssertEqual(spec.source, .config)
    XCTAssertTrue(spec.template.contains("config-$VALUE"))
  }

  private func makeTempRepoRoot() throws -> URL {
    let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let repoRoot = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: repoRoot, withIntermediateDirectories: true)
    return repoRoot
  }
}
