//
//  AnigmaASTServicesTests.swift
//  AnigmaASTServicesTests
//
//  Unit tests for AnigmaASTServicesTests.
//

import XCTest
import AnigmaPrimitives
@testable import AnigmaASTServices

final class AnigmaASTServicesTests: XCTestCase {

    func testSwiftAstLensInitialization() async throws {
        let lens = SwiftAstLens()
        let stats = await lens.cacheStats()
        XCTAssertEqual(stats.entries, 0)
        XCTAssertEqual(stats.sizeBytes, 0)
    }

    func testTrustTierComparison() {
        XCTAssertTrue(TrustTier.bronze < TrustTier.silver)
        XCTAssertTrue(TrustTier.silver < TrustTier.gold)
        XCTAssertTrue(TrustTier.gold < TrustTier.platinum)
        XCTAssertEqual(TrustTier.allCases.count, 4)
    }

    func testRewriteResultUnchanged() {
        let result = RewriteResult.unchanged
        XCTAssertFalse(result.modified)
        XCTAssertTrue(result.newSource.isEmpty)
        XCTAssertTrue(result.diagnostics.isEmpty)
        XCTAssertTrue(result.appliedChanges.isEmpty)
    }

    func testSearchConfigDefaults() {
        let config = SearchConfig(pattern: "test")
        XCTAssertEqual(config.pattern, "test")
        XCTAssertEqual(config.directory, ".")
        XCTAssertEqual(config.fileExtensions, ["swift"])
        XCTAssertTrue(config.ignorePatterns.isEmpty)
        XCTAssertTrue(config.caseSensitive)
        XCTAssertEqual(config.maxFileSize, 10 * 1024 * 1024)
        XCTAssertEqual(config.contextLines, 2)
    }

    func testPipelineConfigDefaults() {
        let config = PipelineConfig()
        XCTAssertEqual(config.trustTier, .bronze)
        XCTAssertTrue(config.backupFiles)
        XCTAssertEqual(config.maxConcurrentFiles, 4)
        XCTAssertFalse(config.dryRun)
        XCTAssertEqual(config.logLevel, .info)
    }

    func testSwiftPatternCaseSensitivity() {
        XCTAssertTrue(SwiftPattern.classDeclaration.caseSensitive)
        XCTAssertTrue(SwiftPattern.structDeclaration.caseSensitive)
        XCTAssertTrue(SwiftPattern.enumDeclaration.caseSensitive)
        XCTAssertTrue(SwiftPattern.protocolDeclaration.caseSensitive)
        XCTAssertTrue(SwiftPattern.extensionDeclaration.caseSensitive)
        XCTAssertTrue(SwiftPattern.functionDeclaration.caseSensitive)
        XCTAssertTrue(SwiftPattern.variableDeclaration.caseSensitive)
        XCTAssertTrue(SwiftPattern.typealiasDeclaration.caseSensitive)
        XCTAssertTrue(SwiftPattern.importStatement.caseSensitive)
        XCTAssertFalse(SwiftPattern.sendableConformance.caseSensitive)
        XCTAssertFalse(SwiftPattern.actorDeclaration.caseSensitive)
        XCTAssertFalse(SwiftPattern.asyncFunction.caseSensitive)
        XCTAssertFalse(SwiftPattern.awaitExpression.caseSensitive)
        XCTAssertFalse(SwiftPattern.taskCreation.caseSensitive)
    }

    func testDefaultIgnorePatterns() {
        let patterns = AgSearchService.defaultIgnorePatterns
        XCTAssertTrue(patterns.contains(".git/"))
        XCTAssertTrue(patterns.contains(".build/"))
        XCTAssertTrue(patterns.contains(".swiftpm/"))
        XCTAssertTrue(patterns.contains("DerivedData/"))
        XCTAssertTrue(patterns.contains("Pods/"))
        XCTAssertTrue(patterns.contains("node_modules/"))
        XCTAssertTrue(patterns.contains("*.xcworkspace"))
        XCTAssertTrue(patterns.contains("*.xcodeproj"))
        XCTAssertTrue(patterns.contains("*.DS_Store"))
        XCTAssertTrue(patterns.contains("*.log"))
    }
}
