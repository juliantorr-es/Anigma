//
//  AstRewriteTests.swift
//  AnigmaASTServicesTests
//
//  Unit tests for AnigmaASTServicesTests.
//

import XCTest
import SwiftSyntax
import AnigmaPrimitives
@testable import AnigmaASTServices

final class AstRewriteTests: XCTestCase {
    override func setUp() {
        super.setUp()
        setenv("ANIGMA_AST_VERIFY", "0", 1)
        unsetenv("ANIGMA_AST_VERIFY_FORCE")
    }

    override func tearDown() {
        unsetenv("ANIGMA_AST_VERIFY")
        unsetenv("ANIGMA_AST_VERIFY_FORCE")
        super.tearDown()
    }

    func testAddSendableIdempotent() async throws {
        let tempFile = try createTemporarySwiftFile(content: """
        struct Document {
            let title: String
        }
        """)

        let anchor = try await makeAnchor(for: tempFile)
        let pipeline = RewritePipeline(rules: [AddSendableToValueTypesRule()], config: PipelineConfig(trustTier: .gold, backupFiles: false, maxConcurrentFiles: 1, logLevel: .warn))

        let firstResult = await pipeline.execute(on: [RewritePipeline.PipelineItem(filePath: tempFile, astAnchor: anchor)])
        XCTAssertTrue(firstResult.outcomes.contains { $0.status == RewritePipeline.FileOutcome.Status.matched })

        let content = try String(contentsOfFile: tempFile)
        XCTAssertTrue(content.contains(": Sendable"))

        let secondResult = await pipeline.execute(on: [RewritePipeline.PipelineItem(filePath: tempFile, astAnchor: anchor)])
        XCTAssertTrue(secondResult.outcomes.contains { $0.status == RewritePipeline.FileOutcome.Status.noChange })
    }

    func testVerificationFailureRollsBack() async throws {
        setenv("ANIGMA_AST_VERIFY", "1", 1)
        setenv("ANIGMA_AST_VERIFY_FORCE", "fail", 1)
        let tempFile = try createTemporarySwiftFile(content: """
        struct Document {
            let title: String
        }
        """)

        let anchor = try await makeAnchor(for: tempFile)
        let pipeline = RewritePipeline(rules: [AddSendableToValueTypesRule()], config: PipelineConfig(trustTier: .gold, backupFiles: true, maxConcurrentFiles: 1, logLevel: .warn))

        let result = await pipeline.execute(on: [RewritePipeline.PipelineItem(filePath: tempFile, astAnchor: anchor)])
        XCTAssertFalse(result.verification?.success ?? true)
        XCTAssertTrue(result.outcomes.contains { $0.reason == "verification_failed" })

        let content = try String(contentsOfFile: tempFile)
        XCTAssertFalse(content.contains(": Sendable"))
    }

    private func createTemporarySwiftFile(content: String) throws -> String {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("swift")
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL.path
    }

    private func makeAnchor(for filePath: String) async throws -> AstAnchor {
        let lens = SwiftAstLens()
        let (ast, hash) = try await lens.ast(for: filePath)
        let finder = FirstNominalFinder(viewMode: .sourceAccurate)
        _ = finder.visit(ast)
        guard let node = finder.node else {
            throw XCTestError(.failureWhileWaiting)
        }

        let start = node.positionAfterSkippingLeadingTrivia.utf8Offset
        let end = node.endPositionBeforeTrailingTrivia.utf8Offset
        let fingerprint = AstAnchor.fingerprint(sourceText: try String(contentsOfFile: filePath), startOffset: start, endOffset: end)
        return AstAnchor(filePath: filePath, contentHash: hash, startOffset: start, endOffset: end, nodeKind: "Nominal", contextFingerprint: fingerprint)
    }
}

private final class FirstNominalFinder: SyntaxAnyVisitor {
    var node: Syntax?

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        if self.node == nil, node.is(StructDeclSyntax.self) || node.is(ClassDeclSyntax.self) {
            self.node = node
            return .skipChildren
        }
        return .visitChildren
    }
}
