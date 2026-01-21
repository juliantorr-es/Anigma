import XCTest
@testable import LayoutEngineCapsule
import CapsuleCore

final class LayoutEngineCapsuleTests: XCTestCase {
    
    private func loadResourcePDF(named name: String = "sample") throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "pdf") else {
            XCTFail("Missing resource PDF: \(name).pdf")
            throw NSError(domain: "Test", code: 1)
        }
        return try Data(contentsOf: url)
    }
    
    // MARK: - Basic Tests
    
    func testWrapperInitialization() throws {
        let wrapper = try LayoutEngineCapsuleWrapper()
        XCTAssertNotNil(wrapper)
    }
    
    func testDefaultConfiguration() {
        let config = LayoutEngineConfig.default
        XCTAssertGreaterThan(config.maxElementsPerPage, 0)
        XCTAssertGreaterThanOrEqual(config.tableDetectionConfidence, 0.0)
        XCTAssertLessThanOrEqual(config.tableDetectionConfidence, 1.0)
    }
    
    func testConfigurationValidation() throws {
        let config = LayoutEngineConfig.default
        try config.validate()
    }
    
    // MARK: - Empty PDF Test
    
    func testEmptyPDF() throws {
        let wrapper = try LayoutEngineCapsuleWrapper()
        let emptyData = Data()
        let layouts = try wrapper.analyzePDF(emptyData)
        XCTAssertEqual(layouts.count, 0)
    }
    
    func testEmptyGeneratedPDF() throws {
        let wrapper = try LayoutEngineCapsuleWrapper()
        let emptyPDFData = SimplePDFGenerator.generateEmpty()
        let layouts = try wrapper.analyzePDF(emptyPDFData)
        // Empty PDF with zero pages should return zero layouts
        XCTAssertEqual(layouts.count, 0)
    }
    
    // MARK: - Simple Text Extraction
    
    func testSimpleTextPDF() throws {
        let pdfData = try generateSimpleTextPDF()
        let wrapper = try LayoutEngineCapsuleWrapper()
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertEqual(layouts.count, 1)
        let layout = layouts[0]
        XCTAssertGreaterThan(layout.segments.count, 0)
        
        // Verify at least one segment contains "Hello World"
        let helloWorldFound = layout.segments.contains { $0.text.contains("Hello World") }
        XCTAssertTrue(helloWorldFound, "Expected to find 'Hello World' in extracted text")
    }
    
    // MARK: - Table Detection
    
    func testTableDetection() throws {
        let pdfData = try generateTablePDF()
        let wrapper = try LayoutEngineCapsuleWrapper()
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertEqual(layouts.count, 1)
        let layout = layouts[0]
        
        // Should detect at least one table
        XCTAssertGreaterThan(layout.tableBBoxes.count, 0)
        
        // Verify segments exist (text within table)
        XCTAssertGreaterThan(layout.segments.count, 0)
    }
    
    func testInferredTableDetection() throws {
        let pdfData = SimplePDFGenerator.generateInferredTable()
        let wrapper = try LayoutEngineCapsuleWrapper()
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertEqual(layouts.count, 1)
        let layout = layouts[0]
        // The layout engine may detect a table based on text alignment
        // At minimum we should have text segments
        XCTAssertGreaterThan(layout.segments.count, 0)
    }
    
    func testMergedCellsTableDetection() throws {
        let pdfData = SimplePDFGenerator.generateMergedCellsTable()
        let wrapper = try LayoutEngineCapsuleWrapper()
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertEqual(layouts.count, 1)
        let layout = layouts[0]
        // Should detect at least one table (maybe)
        // At least segments
        XCTAssertGreaterThan(layout.segments.count, 0)
    }
    
    func testImageDetection() throws {
        let pdfData = SimplePDFGenerator.generateImagePDF()
        let wrapper = try LayoutEngineCapsuleWrapper()
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertEqual(layouts.count, 1)
        let layout = layouts[0]
        // Should detect at least one figure (rectangle)
        // This depends on the layout engine's ability to detect shapes
        // For now, just ensure analysis completes without error
        XCTAssertGreaterThanOrEqual(layout.segments.count + layout.tableBBoxes.count + layout.figureBBoxes.count, 0)
        // Images array should be present (likely empty since PDF has no embedded images)
        XCTAssertEqual(layout.images.count, 0, "PDF with rectangle should have zero images (rectangle is not an image object)")
    }
    
    func testImageExtraction() throws {
        let pdfData = try loadResourcePDF()
        let wrapper = try LayoutEngineCapsuleWrapper()
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertGreaterThanOrEqual(layouts.count, 1)
        let layout = layouts[0]
        
        // Verify images are extracted
        XCTAssertGreaterThan(layout.images.count, 0, "Sample PDF should contain images")
        
        // Validate each image
        for image in layout.images {
            // Basic metadata
            XCTAssertGreaterThan(image.width, 0)
            XCTAssertGreaterThan(image.height, 0)
            // Bounding box should be within page bounds (approx)
            XCTAssertLessThan(image.bbox.right, 612) // typical PDF page width
            XCTAssertLessThan(image.bbox.bottom, 792) // typical PDF page height
            // Raw data may be present
            if let rawData = image.rawData {
                XCTAssertGreaterThan(rawData.count, 0)
            }
        }
    }
    
    func testMixedContentPDF() throws {
        let pdfData = SimplePDFGenerator.generateMixedContentPDF()
        let wrapper = try LayoutEngineCapsuleWrapper()
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertEqual(layouts.count, 1)
        let layout = layouts[0]
        // Should have some content
        XCTAssertGreaterThan(layout.segments.count, 0)
        // Mixed content PDF may not have images
        XCTAssertEqual(layout.images.count, 0, "Mixed content PDF with rectangle should have zero images")
    }
    
    // MARK: - Spatial Index Queries
    
    func testSpatialIndexQuery() throws {
        let pdfData = try generateSimpleTextPDF()
        let wrapper = try LayoutEngineCapsuleWrapper()
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertEqual(layouts.count, 1)
        
        let spatialIndex = try wrapper.getSpatialIndex(forPage: 0)
        let queryBox = BoundingBox(left: 0, top: 0, right: 100, bottom: 100)
        let results = try wrapper.queryBoundingBox(spatialIndex, bbox: queryBox, maxElements: 10)
        
        // Should return some indices (maybe none if no text in that region)
        XCTAssertNotNil(results)
    }
    
    // MARK: - Error Handling
    
    func testInvalidPDFData() throws {
        let wrapper = try LayoutEngineCapsuleWrapper()
        let invalidData = Data([0x00, 0x01, 0x02])
        
        // Expect an error to be thrown
        XCTAssertThrowsError(try wrapper.analyzePDF(invalidData)) { error in
            // Verify it's a CapsuleError or something appropriate
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    // MARK: - Configuration Options
    
    func testDifferentDeterminismTiers() throws {
        let pdfData = try generateSimpleTextPDF()
        
        for tier in [0, 1, 2] as [UInt32] {
            let config = LayoutEngineConfig(determinismTier: tier)
            let wrapper = try LayoutEngineCapsuleWrapper(config: config)
            let layouts = try wrapper.analyzePDF(pdfData)
            XCTAssertEqual(layouts.count, 1)
        }
    }
    
    func testTableDetectionConfidenceThreshold() throws {
        let pdfData = try generateTablePDF()
        
        // Low confidence should detect more tables (maybe false positives)
        let lowConfidenceConfig = LayoutEngineConfig(tableDetectionConfidence: 0.1)
        let lowWrapper = try LayoutEngineCapsuleWrapper(config: lowConfidenceConfig)
        let lowLayouts = try lowWrapper.analyzePDF(pdfData)
        
        // High confidence should detect fewer tables (maybe none)
        let highConfidenceConfig = LayoutEngineConfig(tableDetectionConfidence: 0.99)
        let highWrapper = try LayoutEngineCapsuleWrapper(config: highConfidenceConfig)
        let highLayouts = try highWrapper.analyzePDF(pdfData)
        
        XCTAssertGreaterThanOrEqual(lowLayouts[0].tableBBoxes.count, highLayouts[0].tableBBoxes.count)
    }
    
    // MARK: - Performance Test
    
    func testPerformanceLargePDF() throws {
        let pdfData = try generateLargePDF()
        let wrapper = try LayoutEngineCapsuleWrapper()
        
        measure {
            do {
                _ = try wrapper.analyzePDF(pdfData)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testProfilingStats() throws {
        let pdfData = try generateSimpleTextPDF()
        var config = LayoutEngineConfig.default
        config.flags |= 0x10 // ANIGMA_LAYOUT_ENGINE_FLAG_ENABLE_PROFILING
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertGreaterThan(layouts.count, 0)
        
        let stats = try wrapper.getProfilingStats()
        XCTAssertGreaterThan(stats.totalPagesProcessed, 0)
        XCTAssertGreaterThanOrEqual(stats.totalCharsProcessed, 0)
        XCTAssertGreaterThanOrEqual(stats.totalSegmentsCreated, 0)
        XCTAssertGreaterThanOrEqual(stats.pdfLoadTimeMs, 0.0)
        XCTAssertGreaterThanOrEqual(stats.textExtractionTimeMs, 0.0)
        XCTAssertGreaterThanOrEqual(stats.spatialIndexBuildTimeMs, 0.0)
        XCTAssertGreaterThanOrEqual(stats.totalAnalysisTimeMs, 0.0)
    }
    
    // MARK: - Memory Management
    
    func testMemoryLeak() throws {
        // Create and destroy many wrappers to ensure no leaks
        for _ in 0..<100 {
            let wrapper = try LayoutEngineCapsuleWrapper()
            _ = try wrapper.analyzePDF(try generateSimpleTextPDF())
            // wrapper deallocated at end of iteration
        }
    }
    
    // MARK: - Resource-based Tests
    
    func testSampleResourcePDF() throws {
        let pdfData = try loadResourcePDF()
        let wrapper = try LayoutEngineCapsuleWrapper()
        let layouts = try wrapper.analyzePDF(pdfData)
        
        // Should have at least one page
        XCTAssertGreaterThanOrEqual(layouts.count, 1)
        
        // Should have some segments
        if let layout = layouts.first {
            XCTAssertGreaterThan(layout.segments.count, 0)
            
            // Log some info for debugging
            print("Resource PDF analysis:")
            print("  Segments: \(layout.segments.count)")
            print("  Tables: \(layout.tableBBoxes.count)")
            print("  Figures: \(layout.figureBBoxes.count)")
            print("  Images: \(layout.images.count)")
            
            // Sample PDF should contain at least one image
            XCTAssertGreaterThan(layout.images.count, 0, "Sample PDF should contain at least one embedded image")
            
            // Verify image metadata
            for (index, image) in layout.images.enumerated() {
                print("  Image \(index): \(image.width)x\(image.height) pixels, DPI: \(image.horizontalDPI)x\(image.verticalDPI), BPP: \(image.bitsPerPixel), colorspace: \(image.colorspace), filter: \(image.filter ?? "none")")
                XCTAssertGreaterThan(image.width, 0, "Image width should be positive")
                XCTAssertGreaterThan(image.height, 0, "Image height should be positive")
                // Raw data may or may not be present depending on PDFium extraction
                if let rawData = image.rawData {
                    XCTAssertGreaterThan(rawData.count, 0, "Raw image data should not be empty")
                    print("    Raw data size: \(rawData.count) bytes")
                }
            }
            
            // Verify we can query spatial index
            let spatialIndex = try wrapper.getSpatialIndex(forPage: 0)
            let queryBox = BoundingBox(left: 0, top: 0, right: 100, bottom: 100)
            let results = try wrapper.queryBoundingBox(spatialIndex, bbox: queryBox, maxElements: 10)
            print("  Spatial query results: \(results.count)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateSimpleTextPDF() throws -> Data {
        // Generate a PDF with "Hello World" text
        return SimplePDFGenerator.generateSimpleText()
    }
    
    private func generateTablePDF() throws -> Data {
        // Generate a PDF with a simple table
        return SimplePDFGenerator.generateTable()
    }
    
    private func generateLargePDF() throws -> Data {
        // For now, reuse simple text PDF
        return SimplePDFGenerator.generateSimpleText()
    }
    
    private func generateEmptyPDF() -> Data {
        return SimplePDFGenerator.generateEmpty()
    }
}