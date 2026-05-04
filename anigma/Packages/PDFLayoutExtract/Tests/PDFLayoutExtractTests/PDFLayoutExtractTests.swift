//
//  PDFLayoutExtractTests.swift
//  PDFLayoutExtractTests
//

import Testing
import PDFLayoutExtract

@Test
func testPDFLayoutExtractContractMetadata() {
    // Test that the contract descriptor is accessible
    #expect(PDFLayoutExtractContract.id.name == "pipeline.pdf.layout_extract")
    #expect(PDFLayoutExtractContract.id.major == 1)
    #expect(PDFLayoutExtractContract.id.minor == 0)
    #expect(PDFLayoutExtractContract.inputSchemaVersion == 1)
    #expect(PDFLayoutExtractContract.outputSchemaVersion == 1)
}
