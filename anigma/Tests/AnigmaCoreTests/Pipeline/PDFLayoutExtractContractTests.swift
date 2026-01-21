//
//  PDFLayoutExtractContractTests.swift
//  AnigmaCoreTests
//
//  Unit tests for PDF layout extraction contract.
//

import XCTest
@testable import AnigmaCore
@testable import ContractsCore

final class PDFLayoutExtractContractTests: XCTestCase {
    
    private func generateSimpleTextPDF() -> Data {
        var pdfData = Data()
        
        // PDF header
        let header = "%PDF-1.4\n"
        pdfData.append(header.data(using: .utf8)!)
        
        // PDF binary comment
        let binaryComment = "%\u{E2}\u{E3}\u{CF}\u{D3}\n"
        pdfData.append(binaryComment.data(using: .utf8)!)
        
        // Object 1: Catalog
        let catalogObj = """
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        """
        pdfData.append((catalogObj + "\n").data(using: .utf8)!)
        
        // Object 2: Pages
        let pagesObj = """
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        """
        pdfData.append((pagesObj + "\n").data(using: .utf8)!)
        
        // Create content stream
        let contentStream = """
        BT
        /F1 24 Tf
        100 700 Td
        (Hello World) Tj
        ET
        """
        let streamLength = contentStream.count
        
        // Object 3: Page
        let pageObj = """
        3 0 obj
        << /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>
        endobj
        """
        pdfData.append((pageObj + "\n").data(using: .utf8)!)
        
        // Object 4: Font
        let fontObj = """
        4 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        """
        pdfData.append((fontObj + "\n").data(using: .utf8)!)
        
        // Object 5: Content stream
        let contentObj = """
        5 0 obj
        << /Length \(streamLength) >>
        stream
        \(contentStream)
        endstream
        endobj
        """
        pdfData.append((contentObj + "\n").data(using: .utf8)!)
        
        // Cross-reference table
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
        
        // Trailer
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
    
    func testSuccessfulExtraction() async throws {
        let pdfData = generateSimpleTextPDF()
        let inputMetrics = ExecutionMetrics(wallTimeMs: 0, executor: "tester")
        let receipt = ContractReceipt.placeholder(
            contractID: PDFLayoutExtractContract.id,
            runID: "run-1",
            sessionID: "sess-1",
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: inputMetrics
        )
        let envelope = ArtifactEnvelope(
            schemaVersion: PDFLayoutExtractContract.inputSchemaVersion,
            payload: PDFBlobArtifact(blobID: "test-pdf", rawData: pdfData),
            evidenceRefs: [],
            metrics: inputMetrics,
            receipt: receipt
        )
        let ctx = ContractContext(
            contractID: PDFLayoutExtractContract.id,
            runID: "run-1",
            sessionID: "sess-1",
            trustTier: .silver,
            securityZone: .restricted,
            budgets: ContractBudgets(),
            executorIdentity: "tester",
            testRunner: nil
        )
        
        let output = try await PDFLayoutExtractContract.execute(input: envelope, ctx: ctx)
        try PDFLayoutExtractContract.validate(output: output)
        
        XCTAssertEqual(output.payload.blobID, "test-pdf")
        XCTAssertEqual(output.payload.pages.count, 1)
        XCTAssertEqual(output.payload.pages[0].pageIndex, 0)
        XCTAssertGreaterThan(output.payload.pages[0].segments.count, 0)
        
        let helloWorldFound = output.payload.pages[0].segments.contains { $0.text.contains("Hello World") }
        XCTAssertTrue(helloWorldFound, "Expected to find 'Hello World' in extracted text")
        
        XCTAssertGreaterThan(output.evidenceRefs.count, 0)
    }
    
    func testEmptyPDFFailsValidation() async throws {
        let emptyData = Data()
        let inputMetrics = ExecutionMetrics(wallTimeMs: 0, executor: "tester")
        let receipt = ContractReceipt.placeholder(
            contractID: PDFLayoutExtractContract.id,
            runID: "run-2",
            sessionID: "sess-1",
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: inputMetrics
        )
        let envelope = ArtifactEnvelope(
            schemaVersion: PDFLayoutExtractContract.inputSchemaVersion,
            payload: PDFBlobArtifact(blobID: "empty-pdf", rawData: emptyData),
            evidenceRefs: [],
            metrics: inputMetrics,
            receipt: receipt
        )
        let ctx = ContractContext(
            contractID: PDFLayoutExtractContract.id,
            runID: "run-2",
            sessionID: "sess-1",
            trustTier: .silver,
            securityZone: .restricted,
            budgets: ContractBudgets(),
            executorIdentity: "tester",
            testRunner: nil
        )
        
        let output = try await PDFLayoutExtractContract.execute(input: envelope, ctx: ctx)
        XCTAssertThrowsError(try PDFLayoutExtractContract.validate(output: output)) { error in
            if let validationError = error as? ContractValidationError {
                XCTAssertEqual(validationError.code, "pdf.layout_extract.empty_pages")
            } else {
                XCTFail("Expected ContractValidationError")
            }
        }
    }
    
    func testMetricsAreRecorded() async throws {
        let pdfData = generateSimpleTextPDF()
        let inputMetrics = ExecutionMetrics(wallTimeMs: 0, executor: "tester")
        let receipt = ContractReceipt.placeholder(
            contractID: PDFLayoutExtractContract.id,
            runID: "run-3",
            sessionID: "sess-1",
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: inputMetrics
        )
        let envelope = ArtifactEnvelope(
            schemaVersion: PDFLayoutExtractContract.inputSchemaVersion,
            payload: PDFBlobArtifact(blobID: "test-pdf", rawData: pdfData),
            evidenceRefs: [],
            metrics: inputMetrics,
            receipt: receipt
        )
        let ctx = ContractContext(
            contractID: PDFLayoutExtractContract.id,
            runID: "run-3",
            sessionID: "sess-1",
            trustTier: .silver,
            securityZone: .restricted,
            budgets: ContractBudgets(),
            executorIdentity: "tester",
            testRunner: nil
        )
        
        let output = try await PDFLayoutExtractContract.execute(input: envelope, ctx: ctx)
        try PDFLayoutExtractContract.validate(output: output)
        
        XCTAssertNotNil(output.metrics)
        XCTAssertGreaterThan(output.metrics.wallTimeMs, 0)
        XCTAssertEqual(output.metrics.executor, "tester")
    }
    
    func testEvidenceRefsGenerated() async throws {
        let pdfData = generateSimpleTextPDF()
        let inputMetrics = ExecutionMetrics(wallTimeMs: 0, executor: "tester")
        let receipt = ContractReceipt.placeholder(
            contractID: PDFLayoutExtractContract.id,
            runID: "run-4",
            sessionID: "sess-1",
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: inputMetrics
        )
        let envelope = ArtifactEnvelope(
            schemaVersion: PDFLayoutExtractContract.inputSchemaVersion,
            payload: PDFBlobArtifact(blobID: "test-pdf", rawData: pdfData),
            evidenceRefs: [],
            metrics: inputMetrics,
            receipt: receipt
        )
        let ctx = ContractContext(
            contractID: PDFLayoutExtractContract.id,
            runID: "run-4",
            sessionID: "sess-1",
            trustTier: .silver,
            securityZone: .restricted,
            budgets: ContractBudgets(),
            executorIdentity: "tester",
            testRunner: nil
        )
        
        let output = try await PDFLayoutExtractContract.execute(input: envelope, ctx: ctx)
        try PDFLayoutExtractContract.validate(output: output)
        
        XCTAssertGreaterThan(output.evidenceRefs.count, 0)
        
        for evidence in output.evidenceRefs {
            XCTAssertEqual(evidence.sourceArtifactID, "test-pdf")
            XCTAssertNotNil(evidence.kind)
        }
    }
}
