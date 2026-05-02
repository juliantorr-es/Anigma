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
        let adapter = DatabaseAuthorityAdapter(databaseAuthority: dbActor)
        contextum = try await Contextum(databaseAuthority: adapter)
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

    func testDocumentTruthMarkdownIngestPreservesLineage() async throws {
        let source = ContextSourceComponent(
            sourceId: "doc-truth-md",
            sourceType: .document,
            artifactHash: "md-abc",
            receiptId: "receipt-md"
        )

        let input = DocumentTruthIngestInput(
            format: .markdown,
            content: """
            # Budget Policy

            Quarterly budget approvals stay local.
            """,
            mimeType: "text/markdown",
            canonicalRef: "docs/budget.md",
            title: "Budget Policy"
        )

        let receipt = try await contextum.ingestDocumentTruth(source: source, input: input)
        XCTAssertEqual(receipt.documentFormat, .markdown)
        XCTAssertGreaterThan(receipt.chunkCount, 0)

        let markdownResults = try await contextum.search(request: HybridSearchSystem.SearchRequest(
            query: "budget",
            mode: .fullText,
            limit: 5,
            workflowId: UUID().uuidString,
            runId: UUID().uuidString
        ))
        let ids = markdownResults.chunks

        guard let chunkId = ids.first,
              let replay = try await contextum.database.getChunkReplayContext(chunkId: chunkId) else {
            XCTFail("Expected replay context")
            return
        }

        XCTAssertEqual(replay.sourceId, source.sourceId)
        XCTAssertEqual(replay.documentLineage?.sourceFormat, .markdown)
        XCTAssertEqual(replay.sourceSectionTitle, "Budget Policy")
    }

    func testDocumentTruthPDFIngestPreservesPageLineage() async throws {
        let source = ContextSourceComponent(
            sourceId: "doc-truth-pdf",
            sourceType: .document,
            artifactHash: "pdf-abc",
            receiptId: "receipt-pdf"
        )

        let segment = PDFLayoutSegment(
            boundingBox: BoundingBoxRef(x: 10, y: 20, width: 200, height: 40),
            text: "Invoice Summary",
            fontName: "Helvetica",
            fontSize: 16.0,
            fontFlags: 0,
            colorRGB: 0x000000
        )
        let page = PDFPageLayout(pageIndex: 0, segments: [segment], tables: [], figures: [], images: [])
        let input = DocumentTruthIngestInput(
            format: .pdf,
            pdfLayout: PDFLayoutOutput(blobID: "blob-1", pages: [page]),
            mimeType: "application/pdf",
            canonicalRef: "docs/invoice.pdf",
            title: "Invoice Summary"
        )

        _ = try await contextum.ingestDocumentTruth(source: source, input: input)

        let pdfResults = try await contextum.search(request: HybridSearchSystem.SearchRequest(
            query: "Invoice",
            mode: .fullText,
            limit: 5,
            workflowId: UUID().uuidString,
            runId: UUID().uuidString
        ))
        let ids = pdfResults.chunks

        guard let chunkId = ids.first,
              let replay = try await contextum.database.getChunkReplayContext(chunkId: chunkId) else {
            XCTFail("Expected replay context")
            return
        }

        XCTAssertEqual(replay.documentLineage?.sourceFormat, .pdf)
        XCTAssertEqual(replay.sourcePageIndex, 0)
        XCTAssertEqual(replay.sourceSectionPath.last, "page-1")
    }

    func testSourceGraphDocumentAdapterPreservesStructureAndMetadata() async throws {
        let source = ContextSourceComponent(
            sourceId: "source-graph-doc",
            sourceType: .document,
            artifactHash: "doc-artifact",
            receiptId: "receipt-doc",
            timestamp: Date(timeIntervalSince1970: 10),
            discoveredAt: Date(timeIntervalSince1970: 10),
            lastSeenAt: Date(timeIntervalSince1970: 55),
            staleAt: Date(timeIntervalSince1970: 100),
            confidenceScore: 0.8
        )

        let input = DocumentTruthIngestInput(
            format: .markdown,
            content: """
            # Title

            First paragraph.

            - Bullet one
            """,
            mimeType: "text/markdown",
            canonicalRef: "docs/title.md",
            title: "Title"
        )

        let adapter = LocalDocumentSourceGraphAdapter()
        let graph = try await adapter.buildGraph(from: input, source: source)

        XCTAssertEqual(graph.origin, .document)
        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertEqual(graph.nodes.first?.section.kind, .heading)
        XCTAssertGreaterThan(graph.nodes.first?.tokenCount ?? 0, 0)
        XCTAssertEqual(graph.provenance.sourceHash, graph.sourceHash)
        XCTAssertEqual(graph.provenance.receiptID, source.receiptId)
        XCTAssertEqual(graph.provenance.sourceRecord?.receiptID, source.receiptId)
        XCTAssertEqual(graph.ingestReceipt?.replayHash, graph.provenance.replayHash)
        XCTAssertEqual(graph.replayMetadata?.nodeReplayHashes.count, graph.nodes.count)
        XCTAssertEqual(graph.freshness.score, 0.5, accuracy: 0.0001)
        XCTAssertGreaterThan(graph.confidence.score, 0.0)
    }

    func testSourceGraphNoteAdapterCarriesNoteMetadata() async throws {
        let source = ContextSourceComponent(
            sourceId: "source-graph-note",
            sourceType: .document,
            artifactHash: "note-artifact",
            receiptId: "receipt-note",
            confidenceScore: 0.9
        )

        let note = LocalNoteIngestInput(
            title: "Meeting Note",
            content: """
            # Meeting Note

            - Capture the action items.
            """,
            canonicalRef: "notes/meeting.md",
            notebook: "project",
            tags: ["planning", "follow-up"],
            metadata: ["owner": "team-a"]
        )

        let adapter = LocalNoteSourceGraphAdapter()
        let graph = try await adapter.buildGraph(from: note, source: source)

        XCTAssertEqual(graph.origin, .note)
        XCTAssertEqual(graph.title, "Meeting Note")
        XCTAssertEqual(graph.provenance.sourceRecord?.metadata["notebook"], "project")
        XCTAssertEqual(graph.provenance.sourceRecord?.metadata["tags"], "planning,follow-up")
        XCTAssertEqual(graph.provenance.sourceRecord?.metadata["owner"], "team-a")
        XCTAssertEqual(graph.provenance.ingestReceipt?.origin, .note)
        XCTAssertFalse(graph.nodes.isEmpty)
    }

    func testPolicyFingerprintsAreDeterministicAndSourceTypeAware() async throws {
        let ruleA = TextSanitizationRule(ruleID: "emails", pattern: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", replacement: "<email>")
        let ruleB = TextSanitizationRule(ruleID: "numbers", pattern: "\\d+", replacement: "<num>")
        let configA = TextPreprocessingConfiguration(
            sanitizationRules: [ruleA, ruleB],
            preserveParagraphBoundaries: false
        )
        let configB = TextPreprocessingConfiguration(
            sanitizationRules: [ruleB, ruleA],
            preserveParagraphBoundaries: false
        )

        let docTokenizerA = configA.tokenizerPolicyFingerprint(sourceType: .document)
        let docTokenizerB = configB.tokenizerPolicyFingerprint(sourceType: .document)
        let codeTokenizerA = configA.tokenizerPolicyFingerprint(sourceType: .codebase)
        XCTAssertEqual(docTokenizerA, docTokenizerB)
        XCTAssertNotEqual(docTokenizerA, codeTokenizerA)

        let docSanitizerA = configA.sanitizerPolicyFingerprint(sourceType: .document)
        let docSanitizerB = configB.sanitizerPolicyFingerprint(sourceType: .document)
        let codeSanitizerA = configA.sanitizerPolicyFingerprint(sourceType: .codebase)
        XCTAssertEqual(docSanitizerA, docSanitizerB)
        XCTAssertNotEqual(docSanitizerA, codeSanitizerA)
    }

    func testIngestPersistsTokenizerAndSanitizerPolicyFingerprintsInChunkProvenance() async throws {
        let config = TextPreprocessingConfiguration(
            sanitizationRules: [
                TextSanitizationRule(ruleID: "digits", pattern: "\\d+", replacement: "<num>")
            ],
            preserveParagraphBoundaries: false
        )
        let adapter = DatabaseAuthorityAdapter(databaseAuthority: dbActor)
        contextum = try await Contextum(
            databaseAuthority: adapter,
            preprocessingConfiguration: config
        )

        let source = ContextSourceComponent(
            sourceId: "policy-fingerprint-source",
            sourceType: .codebase,
            artifactHash: "policy-artifact",
            receiptId: "policy-receipt"
        )
        let input = DocumentTruthIngestInput(
            format: .markdown,
            content: "Build 1234 keeps alert@example.com visible.",
            mimeType: "text/markdown",
            canonicalRef: "docs/policy.md",
            title: "Policy Fingerprint"
        )

        _ = try await contextum.ingestDocumentTruth(source: source, input: input)
        let results = try await contextum.search(request: HybridSearchSystem.SearchRequest(
            query: "Build",
            mode: .fullText,
            limit: 5,
            workflowId: UUID().uuidString,
            runId: UUID().uuidString
        ))
        guard let chunkId = results.chunks.first,
              let replay = try await contextum.database.getChunkReplayContext(chunkId: chunkId) else {
            XCTFail("Expected replay context for persisted chunk")
            return
        }

        XCTAssertEqual(replay.tokenizerPolicyHash, config.tokenizerPolicyFingerprint(sourceType: source.sourceType))
        XCTAssertEqual(replay.sanitizerPolicyHash, config.sanitizerPolicyFingerprint(sourceType: source.sourceType))
    }

    func testSourceResolutionCreatesSupersessionChainForCanonicalLane() async throws {
        let first = ContextSourceComponent(
            sourceId: "person-lane-row-1",
            sourceType: .document,
            artifactHash: "entity-v1",
            receiptId: "receipt-v1",
            timestamp: Date(timeIntervalSince1970: 10),
            metadata: ["canonicalRef": "person://alex/profile"],
            canonicalRef: "person://alex/profile",
            currentHash: "hash-v1",
            revision: 1,
            discoveredAt: Date(timeIntervalSince1970: 10),
            lastSeenAt: Date(timeIntervalSince1970: 10),
            content: "Alex likes green tea."
        )
        let persistedFirst = try await contextum.database.upsertResolvedSource(first)

        let second = ContextSourceComponent(
            sourceId: "person-lane-row-1",
            sourceType: .document,
            artifactHash: "entity-v2",
            receiptId: "receipt-v2",
            timestamp: Date(timeIntervalSince1970: 20),
            metadata: ["canonicalRef": "person://alex/profile"],
            canonicalRef: "person://alex/profile",
            currentHash: "hash-v2",
            revision: 1,
            discoveredAt: Date(timeIntervalSince1970: 10),
            lastSeenAt: Date(timeIntervalSince1970: 20),
            content: "Alex now prefers coffee."
        )
        let persistedSecond = try await contextum.database.upsertResolvedSource(second)
        let supersededFirst = try await contextum.database.getSource(artifactHash: "entity-v1")

        XCTAssertEqual(persistedFirst.canonicalEntityId, persistedSecond.canonicalEntityId)
        XCTAssertEqual(persistedSecond.supersedesSourceId, persistedFirst.sourceId)
        XCTAssertEqual(persistedSecond.supersessionRootSourceId, persistedFirst.sourceId)
        XCTAssertEqual(persistedSecond.supersessionDepth, persistedFirst.supersessionDepth + 1)
        XCTAssertNotEqual(persistedSecond.sourceId, persistedFirst.sourceId)
        XCTAssertEqual(supersededFirst?.supersededBySourceId, persistedSecond.sourceId)
    }

    func testSourceResolutionDeduplicatesSameHashForCanonicalLane() async throws {
        let first = ContextSourceComponent(
            sourceId: "person-lane-stable-1",
            sourceType: .document,
            artifactHash: "entity-stable-v1",
            receiptId: "receipt-stable-v1",
            metadata: ["canonicalRef": "person://sam/preferences"],
            canonicalRef: "person://sam/preferences",
            currentHash: "hash-stable",
            revision: 1,
            content: "Sam likes trail running."
        )
        let persistedFirst = try await contextum.database.upsertResolvedSource(first)

        let duplicate = ContextSourceComponent(
            sourceId: "person-lane-stable-2",
            sourceType: .document,
            artifactHash: "entity-stable-v2",
            receiptId: "receipt-stable-v2",
            metadata: ["canonicalRef": "person://sam/preferences"],
            canonicalRef: "person://sam/preferences",
            currentHash: "hash-stable",
            revision: 1,
            content: "Sam likes trail running."
        )
        let persistedDuplicate = try await contextum.database.upsertResolvedSource(duplicate)

        XCTAssertEqual(persistedDuplicate.sourceId, persistedFirst.sourceId)
        XCTAssertEqual(persistedDuplicate.revision, persistedFirst.revision)
        XCTAssertEqual(persistedDuplicate.canonicalEntityId, persistedFirst.canonicalEntityId)
        XCTAssertNil(persistedDuplicate.supersededBySourceId)
    }

    func testSourceResolutionNormalizesPersonCanonicalLaneForRetrieval() async throws {
        let first = ContextSourceComponent(
            sourceId: "person-lane-canonicalized-1",
            sourceType: .document,
            artifactHash: "person-canonical-v1",
            receiptId: "person-canonical-receipt-v1",
            timestamp: Date(timeIntervalSince1970: 100),
            canonicalRef: " Person://Alex/Profile ",
            currentHash: "person-hash-v1",
            revision: 1,
            discoveredAt: Date(timeIntervalSince1970: 100),
            lastSeenAt: Date(timeIntervalSince1970: 100),
            content: "Alex keeps profile v1."
        )
        let persistedFirst = try await contextum.database.upsertResolvedSource(first)

        let second = ContextSourceComponent(
            sourceId: "person-lane-canonicalized-1",
            sourceType: .document,
            artifactHash: "person-canonical-v2",
            receiptId: "person-canonical-receipt-v2",
            timestamp: Date(timeIntervalSince1970: 120),
            canonicalRef: "person://alex/profile",
            currentHash: "person-hash-v2",
            revision: 1,
            discoveredAt: Date(timeIntervalSince1970: 100),
            lastSeenAt: Date(timeIntervalSince1970: 120),
            content: "Alex keeps profile v2."
        )
        let persistedSecond = try await contextum.database.upsertResolvedSource(second)
        let resolvedByCanonicalLane = try await contextum.database.getCurrentSource(
            canonicalRef: "PERSON://ALEX/PROFILE",
            sourceType: .document
        )

        XCTAssertNotNil(resolvedByCanonicalLane)
        XCTAssertEqual(persistedSecond.supersedesSourceId, persistedFirst.sourceId)
        XCTAssertEqual(persistedSecond.canonicalEntityId, persistedFirst.canonicalEntityId)
        XCTAssertEqual(resolvedByCanonicalLane?.sourceId, persistedSecond.sourceId)
        XCTAssertEqual(
            resolvedByCanonicalLane?.metadata["canonicalLaneRef"],
            "person://alex/profile"
        )
    }
}
