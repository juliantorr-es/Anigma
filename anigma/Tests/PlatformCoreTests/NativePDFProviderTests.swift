//
//  NativePDFProviderTests.swift
//  PlatformCoreTests
//
//  Unit tests for PlatformCoreTests.
//

import XCTest
#if canImport(PDFKit)
import PDFKit
#endif
@testable import PlatformCore
@testable import CapabilityCore

final class NativePDFProviderTests: XCTestCase {
    #if canImport(PDFKit)
    func testExtractText() async throws {
        let provider = NativePDFProvider()

        // Create a simple PDF
        #if os(macOS)
        let pdfDoc = PDFDocument()
        let page = PDFPage()
        pdfDoc.insert(page, at: 0)

        // Add some text if possible, or just test with empty
        guard let pdfData = pdfDoc.dataRepresentation() else {
            fatalError("Failed to unwrap pdfData")
        }

        let text = try await provider.extractText(pdfData: pdfData)
        XCTAssertNotNil(text)
        #endif
    }

    func testMerge() async throws {
        let provider = NativePDFProvider()

        #if os(macOS)
        let pdfDoc1 = PDFDocument()
        pdfDoc1.insert(PDFPage(), at: 0)
        guard let data1 = pdfDoc1.dataRepresentation() else {
            fatalError("Failed to unwrap data1")
        }

        let pdfDoc2 = PDFDocument()
        pdfDoc2.insert(PDFPage(), at: 0)
        guard let data2 = pdfDoc2.dataRepresentation() else {
            fatalError("Failed to unwrap data2")
        }

        let mergedData = try await provider.merge(pdfs: [data1, data2])
        let mergedDoc = PDFDocument(data: mergedData)
        XCTAssertEqual(mergedDoc?.pageCount, 2)
        #endif
    }
    #endif
}
