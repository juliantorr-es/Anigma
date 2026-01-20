import XCTest
@testable import ContextumModule
@testable import AnigmaCore
import ContractsCore
import Foundation

final class LayoutIndexingSystemTests: XCTestCase {
    var dbActor: DatabaseActor!
    var database: ContextumDatabase!
    var system: LayoutIndexingSystem!
    
    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("layout_test_\(UUID().uuidString).db")
        dbActor = DatabaseActor(dbPath: dbPath.path)
        try await dbActor.open()
        
        let adapter = DatabaseAuthorityAdapter(dbActor: dbActor)
        database = ContextumDatabase(dbActor: adapter)
        system = LayoutIndexingSystem(database: database, maxChunkSize: 100)
    }
    
    override func tearDown() async throws {
        dbActor = nil
        database = nil
        system = nil
    }
    
    func testProcessEmptyLayout() async throws {
        // Create empty layout output
        let layoutOutput = PDFLayoutOutput(
            blobID: "test-blob",
            pages: []
        )
        
        let chunks = try await system.processPDFLayout(
            sourceId: "test-source",
            layoutOutput: layoutOutput
        )
        
        XCTAssertTrue(chunks.isEmpty, "Empty layout should produce no chunks")
    }
    
    func testProcessSimpleTextSegment() async throws {
        // Create a simple page with one text segment
        let segment = PDFLayoutSegment(
            boundingBox: BoundingBoxRef(x: 10, y: 20, width: 100, height: 30),
            text: "Hello World",
            fontName: "Helvetica",
            fontSize: 12.0,
            fontFlags: 0,
            colorRGB: 0x000000
        )
        
        let page = PDFPageLayout(
            pageIndex: 0,
            segments: [segment],
            tables: [],
            figures: [],
            images: []
        )
        
        let layoutOutput = PDFLayoutOutput(
            blobID: "test-blob",
            pages: [page]
        )
        
        let chunks = try await system.processPDFLayout(
            sourceId: "test-source",
            layoutOutput: layoutOutput
        )
        
        XCTAssertEqual(chunks.count, 1, "Should create one chunk for the text segment")
        
        // Verify chunk properties
        let chunk = chunks[0]
        XCTAssertEqual(chunk.sourceId, "test-source")
        XCTAssertTrue(chunk.chunkId.contains("pdf-page0-seg0"), "Chunk ID should contain page and segment info")
        
        // Verify the chunk was stored in database (simplified check)
        // In a real test, we would query the database to verify
    }
    
    func testProcessLargeTextSegment() async throws {
        // Create a text segment that exceeds max chunk size
        let longText = String(repeating: "This is a long sentence. ", count: 20) // ~500 chars
        let segment = PDFLayoutSegment(
            boundingBox: BoundingBoxRef(x: 10, y: 20, width: 100, height: 30),
            text: longText,
            fontName: "Helvetica",
            fontSize: 12.0,
            fontFlags: 0,
            colorRGB: 0x000000
        )
        
        let page = PDFPageLayout(
            pageIndex: 0,
            segments: [segment],
            tables: [],
            figures: [],
            images: []
        )
        
        let layoutOutput = PDFLayoutOutput(
            blobID: "test-blob",
            pages: [page]
        )
        
        let chunks = try await system.processPDFLayout(
            sourceId: "test-source",
            layoutOutput: layoutOutput,
            chunkPrefix: "test-"
        )
        
        // Should split into multiple chunks since text exceeds maxChunkSize (100)
        XCTAssertGreaterThan(chunks.count, 1, "Long text should be split into multiple chunks")
        
        // All chunks should have the same source ID
        for chunk in chunks {
            XCTAssertEqual(chunk.sourceId, "test-source")
        }
    }
    
    func testProcessTable() async throws {
        // Create a page with a table
        let table = PDFLayoutTable(
            boundingBox: BoundingBoxRef(x: 50, y: 100, width: 200, height: 150)
        )
        
        let page = PDFPageLayout(
            pageIndex: 1,
            segments: [],
            tables: [table],
            figures: [],
            images: []
        )
        
        let layoutOutput = PDFLayoutOutput(
            blobID: "test-blob",
            pages: [page]
        )
        
        let chunks = try await system.processPDFLayout(
            sourceId: "test-source",
            layoutOutput: layoutOutput
        )
        
        XCTAssertEqual(chunks.count, 1, "Should create one chunk for the table")
        let chunk = chunks[0]
        XCTAssertTrue(chunk.chunkId.contains("table"), "Chunk ID should indicate it's a table")
    }
    
    func testProcessMultiplePageTypes() async throws {
        // Create a complex layout with multiple element types across pages
        let segment = PDFLayoutSegment(
            boundingBox: BoundingBoxRef(x: 10, y: 20, width: 100, height: 30),
            text: "Sample text",
            fontName: nil,
            fontSize: 10.0,
            fontFlags: 0,
            colorRGB: 0x000000
        )
        
        let table = PDFLayoutTable(
            boundingBox: BoundingBoxRef(x: 50, y: 100, width: 200, height: 150)
        )
        
        let figure = PDFLayoutFigure(
            boundingBox: BoundingBoxRef(x: 300, y: 200, width: 100, height: 80)
        )
        
        let page1 = PDFPageLayout(
            pageIndex: 0,
            segments: [segment],
            tables: [table],
            figures: [figure],
            images: []
        )
        
        let page2 = PDFPageLayout(
            pageIndex: 1,
            segments: [],
            tables: [],
            figures: [],
            images: []
        )
        
        let layoutOutput = PDFLayoutOutput(
            blobID: "test-blob",
            pages: [page1, page2]
        )
        
        let chunks = try await system.processPDFLayout(
            sourceId: "test-source",
            layoutOutput: layoutOutput
        )
        
        // Should have chunks for segment, table, and figure
        XCTAssertEqual(chunks.count, 3, "Should create chunks for each element type")
        
        // Count different types
        let segmentChunks = chunks.filter { $0.chunkId.contains("seg") }
        let tableChunks = chunks.filter { $0.chunkId.contains("table") }
        let figureChunks = chunks.filter { $0.chunkId.contains("figure") }
        
        XCTAssertEqual(segmentChunks.count, 1)
        XCTAssertEqual(tableChunks.count, 1)
        XCTAssertEqual(figureChunks.count, 1)
    }
}