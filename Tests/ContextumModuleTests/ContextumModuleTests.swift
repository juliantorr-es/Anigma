import XCTest
@testable import ContextumModule
import DatabaseCore
import AnigmaCore
import Foundation

final class ContextumModuleTests: XCTestCase {
    var dbActor: DatabaseActor!
    var contextum: Contextum!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("contextum_test_\(UUID().uuidString).db")
        dbActor = DatabaseActor(dbPath: dbPath.path)
        contextum = try await Contextum(dbActor: dbActor)
    }

    override func tearDown() async throws {
        dbActor = nil
        contextum = nil
    }

    func testIngestAndChunk() async throws {
        // Create a source
        let source = ContextSourceComponent(
            sourceId: "test-source-1",
            sourceType: .document,
            artifactHash: "abc123",
            receiptId: "receipt-1"
        )

        // Ingest the source
        try await contextum.ingest(source: source)

        // Chunk some content
        let testContent = """
        This is a test document.
        It has multiple lines.
        Each line contains different content.
        We will chunk this into smaller pieces.
        """

        let chunks = try await contextum.chunk(sourceId: source.sourceId, content: testContent)

        XCTAssertFalse(chunks.isEmpty, "Should produce at least one chunk")
        XCTAssertEqual(chunks[0].sourceId, source.sourceId, "Chunk should reference correct source")
    }

    func testFullTextSearch() async throws {
        // Ingest and chunk a document
        let source = ContextSourceComponent(
            sourceId: "test-source-2",
            sourceType: .document,
            artifactHash: "def456",
            receiptId: "receipt-2"
        )

        try await contextum.ingest(source: source)

        let testContent = """
        Swift is a powerful programming language.
        It is used for iOS, macOS, and server-side development.
        Anigma uses Swift for its core implementation.
        """

        _ = try await contextum.chunk(sourceId: source.sourceId, content: testContent)

        // Search for content
        let searchRequest = HybridSearchSystem.SearchRequest(
            query: "Swift programming",
            mode: .fullText,
            limit: 10,
            workflowId: UUID().uuidString,
            runId: UUID().uuidString
        )

        let results = try await contextum.search(request: searchRequest)

        XCTAssertGreaterThan(results.totalResults, 0, "Should find at least one result")
        XCTAssertFalse(results.chunks.isEmpty, "Should return chunk IDs")
    }

    func testAgentStats() async throws {
        let agentId = "test-agent-1"
        let taxonomy = "code.refactor"

        // Record a successful execution
        try await contextum.recordAgentExecution(
            agentId: agentId,
            taskTaxonomy: taxonomy,
            durationMs: 1500,
            outcome: .success
        )

        // Record a failed execution
        try await contextum.recordAgentExecution(
            agentId: agentId,
            taskTaxonomy: taxonomy,
            durationMs: 800,
            outcome: .failure,
            errorCode: "ERR_TIMEOUT"
        )

        // Note: Stats aggregation would need to be implemented in a real system
        // For Phase 0, we're just ensuring events are recorded
    }

    func testMultipleChunks() async throws {
        let source = ContextSourceComponent(
            sourceId: "test-source-3",
            sourceType: .codebase,
            artifactHash: "ghi789",
            receiptId: "receipt-3"
        )

        try await contextum.ingest(source: source)

        // Create a longer document that will definitely be chunked
        // The chunker splits by newlines, so we must include them.
        let longContent = String(repeating: "This is a line of text that will be repeated many times.\n", count: 100)

        let chunks = try await contextum.chunk(sourceId: source.sourceId, content: longContent)

        XCTAssertGreaterThan(chunks.count, 1, "Long content should produce multiple chunks")

        // Verify chunk ordering
        for (index, chunk) in chunks.enumerated() {
            XCTAssertEqual(chunk.chunkIndex, index, "Chunks should be in sequential order")
            XCTAssertEqual(chunk.totalChunks, chunks.count, "Each chunk should know total count")
        }
    }
}
