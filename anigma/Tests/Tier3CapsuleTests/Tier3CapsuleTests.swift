import XCTest
import TextChunkingCapsule
import VectorIndexCapsule
import RankFusionCapsule
import PDFCapsule
import LayoutEngineCapsule
import CapsuleCore
import TelemetryCore

final class Tier3CapsuleTests: XCTestCase {
    func testEnhancedTextChunkingStableIds() throws {
        let diagnostics = RecordingDiagnostics()
        let config = TextChunkingConfig(targetChunkSize: 16, minChunkSize: 8, maxChunkSize: 64)
        let wrapper = try EnhancedTextChunkingCapsuleWrapper(config: config, diagnostics: diagnostics)
        let data = Data("Hello there, friend. This is a small sample.".utf8)

        let first = try wrapper.chunk(data, documentId: "doc-1")
        let second = try wrapper.chunk(data, documentId: "doc-1")

        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first.map { $0.stableId }, second.map { $0.stableId })
        XCTAssertTrue(diagnostics.containsSpan(named: "EnhancedTextChunkingCapsuleWrapper.chunk", status: .ok))
    }

    func testRankFusionEmitsSpans() throws {
        let diagnostics = RecordingDiagnostics()
        let capsule = try RankFusionCapsule(diagnostics: diagnostics)

        let results = try capsule.fuse(rankLists: [[1, 2, 3], [2, 3, 4]], topK: 3)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.id == 2 })
        XCTAssertTrue(diagnostics.containsSpan(named: "RankFusionCapsule.fuseImplicit", status: .ok))
    }

    func testVectorIndexSearchEmitsSpans() async throws {
        let diagnostics = RecordingDiagnostics()
        let config = VectorIndexConfig(dimension: 2, maxElements: 4)
        let capsule = try VectorIndexCapsule(config: config, diagnostics: diagnostics)

        try await capsule.add(id: 1, vector: [0.0, 0.0])
        try await capsule.add(id: 2, vector: [1.0, 1.0])

        let results = try await capsule.search(query: [0.05, 0.05], k: 1)

        XCTAssertEqual(results.first?.id, 1)
        XCTAssertTrue(diagnostics.containsSpan(named: "VectorIndexCapsule.search", status: .ok))
    }

    func testPDFDocumentDiagnostics() throws {
        let diagnostics = RecordingDiagnostics()
        let pdfData = makeSimplePDF()
        let document = try PDFDocument(data: pdfData, diagnostics: diagnostics)

        XCTAssertEqual(document.pageCount, 1)
        let page = try document.page(at: 0)
        XCTAssertGreaterThan(page.size.width, 0)
        XCTAssertTrue(diagnostics.containsSpan(named: "PDFDocument.pageCount", status: .ok))
        XCTAssertTrue(diagnostics.containsSpan(named: "PDFDocument.page", status: .ok))
    }

    func testLayoutEngineRequiresData() throws {
        let diagnostics = RecordingDiagnostics()
        let config = LayoutEngineConfig()

        XCTAssertThrowsError(try LayoutEngineCapsuleWrapper.analyzePDF(nil, config: config, diagnostics: diagnostics)) { error in
            guard case CapsuleError.invalidInput = error else {
                XCTFail("Expected invalidInput error")
                return
            }
        }

        XCTAssertTrue(diagnostics.containsSpan(named: "LayoutEngineCapsuleWrapper.analyzePDFStatic", status: .error))
    }
}

private func makeSimplePDF() -> Data {
    var pdfData = Data()
    pdfData.append("%PDF-1.4\n".data(using: .utf8)!)
    pdfData.append("%\u{E2}\u{E3}\u{CF}\u{D3}\n".data(using: .utf8)!)

    let catalogObj = """
    1 0 obj
    << /Type /Catalog /Pages 2 0 R >>
    endobj
    """
    pdfData.append((catalogObj + "\n").data(using: .utf8)!)

    let pagesObj = """
    2 0 obj
    << /Type /Pages /Kids [3 0 R] /Count 1 >>
    endobj
    """
    pdfData.append((pagesObj + "\n").data(using: .utf8)!)

    let contentStream = """
    BT
    /F1 24 Tf
    100 700 Td
    (Hello World) Tj
    ET
    """
    let streamLength = contentStream.count

    let pageObj = """
    3 0 obj
    << /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>
    endobj
    """
    pdfData.append((pageObj + "\n").data(using: .utf8)!)

    let fontObj = """
    4 0 obj
    << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
    endobj
    """
    pdfData.append((fontObj + "\n").data(using: .utf8)!)

    let contentObj = """
    5 0 obj
    << /Length \(streamLength) >>
    stream
    \(contentStream)
    endstream
    endobj
    """
    pdfData.append((contentObj + "\n").data(using: .utf8)!)

    let xrefOffset = pdfData.count
    let xrefTable = """
    xref
    0 6
    0000000000 65535 f
    0000000009 00000 n
    0000000058 00000 n
    0000000115 00000 n
    0000000214 00000 n
    0000000287 00000 n
    """
    pdfData.append(xrefTable.data(using: .utf8)!)

    let trailer = """
    trailer
    << /Size 6 /Root 1 0 R >>
    startxref
    \(xrefOffset)
    %%EOF
    """
    pdfData.append((trailer + "\n").data(using: .utf8)!)

    return pdfData
}

private final class RecordingDiagnostics: CapsuleDiagnostics {
    private let lock = NSLock()
    private(set) var spans: [RecordingSpan] = []
    private(set) var events: [DiagnosticEvent] = []

    func beginSpan(
        name: String,
        category: String,
        correlationID: String?,
        tags: [String: String]
    ) -> DiagnosticSpan {
        let span = RecordingSpan(
            name: name,
            category: category,
            correlationID: correlationID ?? UUID().uuidString,
            tags: tags
        )
        lock.lock()
        spans.append(span)
        lock.unlock()
        return span
    }

    func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String?,
        tags: [String: String]
    ) {
        let event = DiagnosticEvent(
            level: level,
            category: category,
            message: message,
            correlationID: correlationID ?? UUID().uuidString,
            tags: tags
        )
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func getEvents(since: Date) -> [DiagnosticEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events.filter { $0.timestamp >= since }
    }

    func getAllEvents() -> [DiagnosticEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    func clearEvents() {
        lock.lock()
        events.removeAll()
        lock.unlock()
    }

    func containsSpan(named name: String, status: SpanStatus) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return spans.contains { $0.name == name && $0.status == status }
    }
}

private final class RecordingSpan: DiagnosticSpan {
    let spanID: String
    let name: String
    let category: String
    let correlationID: String
    let startTime: Date
    private(set) var endTime: Date?
    private(set) var status: SpanStatus?
    private(set) var tags: [String: String]

    var duration: TimeInterval? {
        guard let endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    init(name: String, category: String, correlationID: String, tags: [String: String]) {
        self.spanID = UUID().uuidString
        self.name = name
        self.category = category
        self.correlationID = correlationID
        self.startTime = Date()
        self.tags = tags
    }

    func end(status: SpanStatus) {
        self.status = status
        endTime = Date()
    }

    func addTag(key: String, value: String) {
        tags[key] = value
    }

    func recordEvent(level: DiagnosticLevel, message: String) {
        _ = level
        _ = message
    }
}
