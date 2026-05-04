//
//  LayoutEngineContractsTests.swift
//  LayoutEngineContractsTests
//

import Testing
import LayoutEngineContracts

@Test
func testPDFLayoutSegment() {
    let segment = PDFLayoutSegment(
        boundingBox: BoundingBoxRef(x: 0, y: 0, width: 100, height: 50),
        text: "Hello",
        fontName: "Helvetica",
        fontSize: 12.0,
        fontFlags: 0,
        colorRGB: 0x000000
    )
    #expect(segment.text == "Hello")
    #expect(segment.boundingBox.width == 100)
    #expect(segment.boundingBox.height == 50)
}

@Test
func testPDFPageLayout() {
    let segment = PDFLayoutSegment(
        boundingBox: BoundingBoxRef(x: 0, y: 0, width: 100, height: 50),
        text: "Test",
        fontName: nil,
        fontSize: 10.0,
        fontFlags: 0,
        colorRGB: 0
    )
    let page = PDFPageLayout(
        pageIndex: 0,
        segments: [segment],
        tables: [],
        figures: [],
        images: []
    )
    #expect(page.pageIndex == 0)
    #expect(page.segments.count == 1)
}

@Test
func testPDFLayoutOutput() {
    let output = PDFLayoutOutput(blobID: "test-blob", pages: [])
    #expect(output.blobID == "test-blob")
    #expect(output.pages.isEmpty)
}

@Test
func testPDFBlobArtifact() {
    let data = Data("test pdf bytes".utf8)
    let artifact = PDFBlobArtifact(blobID: "test-id", pageCount: 5, rawData: data)
    #expect(artifact.blobID == "test-id")
    #expect(artifact.pageCount == 5)
    #expect(artifact.rawData == data)
}
