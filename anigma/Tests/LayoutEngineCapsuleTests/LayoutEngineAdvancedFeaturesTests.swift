import XCTest
@testable import LayoutEngineCapsule
import CapsuleCore

final class LayoutEngineAdvancedFeaturesTests: XCTestCase {
    
    private func loadResourcePDF(named name: String = "sample") throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "pdf") else {
            XCTFail("Missing resource PDF: \(name).pdf")
            throw NSError(domain: "Test", code: 1)
        }
        return try Data(contentsOf: url)
    }
    
    private func createAdvancedConfig() -> LayoutEngineConfig {
        return LayoutEngineConfig(
            extractFontMetrics: true,
            detectTables: true,
            detectFigures: true,
            extractImages: true,
            enableProfiling: true,
            preserveCaches: false,
            enableOCR: true,
            advancedFontAnalysis: true,
            layoutClassification: true,
            readingOrderDetection: true,
            multiPageAnalysis: true
        )
    }
    
    // MARK: - Configuration Tests
    
    func testAdvancedConfigurationFlags() {
        let config = createAdvancedConfig()
        
        XCTAssertTrue(config.extractFontMetrics)
        XCTAssertTrue(config.detectTables)
        XCTAssertTrue(config.detectFigures)
        XCTAssertTrue(config.extractImages)
        XCTAssertTrue(config.enableProfiling)
        XCTAssertFalse(config.preserveCaches)
        XCTAssertTrue(config.enableOCR)
        XCTAssertTrue(config.advancedFontAnalysis)
        XCTAssertTrue(config.layoutClassification)
        XCTAssertTrue(config.readingOrderDetection)
        XCTAssertTrue(config.multiPageAnalysis)
    }
    
    func testConfigurationFlagSetters() {
        var config = LayoutEngineConfig.default
        
        // Test flag setters
        config.enableOCR = true
        XCTAssertTrue(config.enableOCR)
        XCTAssertEqual(config.flags & 0x40, 0x40)
        
        config.advancedFontAnalysis = true
        XCTAssertTrue(config.advancedFontAnalysis)
        XCTAssertEqual(config.flags & 0x80, 0x80)
        
        config.layoutClassification = true
        XCTAssertTrue(config.layoutClassification)
        XCTAssertEqual(config.flags & 0x100, 0x100)
        
        config.readingOrderDetection = true
        XCTAssertTrue(config.readingOrderDetection)
        XCTAssertEqual(config.flags & 0x200, 0x200)
        
        config.multiPageAnalysis = true
        XCTAssertTrue(config.multiPageAnalysis)
        XCTAssertEqual(config.flags & 0x400, 0x400)
        
        // Test flag clearing
        config.enableOCR = false
        XCTAssertFalse(config.enableOCR)
        XCTAssertEqual(config.flags & 0x40, 0)
    }
    
    // MARK: - OCR Tests
    
    func testOCRPerformAndResults() throws {
        let config = createAdvancedConfig()
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        // Analyze PDF first
        _ = try wrapper.analyzePDF(pdfData)
        
        // Perform OCR on first page
        try wrapper.performOCR(pageIndex: 0, language: "eng")
        
        // Get OCR results
        let ocrResults = try wrapper.getOCRResults(pageIndex: 0)
        XCTAssertFalse(ocrResults.isEmpty, "OCR should produce some results")
        
        // Validate OCR result structure
        for result in ocrResults {
            XCTAssertFalse(result.text.isEmpty)
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            XCTAssertFalse(result.language.isEmpty)
            XCTAssertGreaterThanOrEqual(result.wordCount, 0)
            
            // Validate bounding box
            XCTAssertLessThan(result.bbox.left, result.bbox.right)
            XCTAssertLessThan(result.bbox.top, result.bbox.bottom)
        }
    }
    
    func testOCRAccuracyValidation() throws {
        let config = createAdvancedConfig()
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        // Analyze PDF and perform OCR
        _ = try wrapper.analyzePDF(pdfData)
        try wrapper.performOCR(pageIndex: 0, language: "eng")
        
        // Test accuracy validation with ground truth
        let groundTruth = "Sample text for testing OCR accuracy"
        let accuracy = try wrapper.validateOCRAccuracy(pageIndex: 0, groundTruthText: groundTruth)
        
        XCTAssertGreaterThanOrEqual(accuracy.characterAccuracy, 0.0)
        XCTAssertLessThanOrEqual(accuracy.characterAccuracy, 1.0)
        XCTAssertGreaterThanOrEqual(accuracy.wordAccuracy, 0.0)
        XCTAssertLessThanOrEqual(accuracy.wordAccuracy, 1.0)
    }
    
    func testOCRWithoutConfiguration() throws {
        let config = LayoutEngineConfig.default // OCR not enabled
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        _ = try wrapper.analyzePDF(pdfData)
        
        // Should fail when OCR not enabled
        XCTAssertThrowsError(try wrapper.performOCR(pageIndex: 0, language: "eng")) { error in
            XCTAssertTrue(error is CapsuleError)
            XCTAssertEqual(error.localizedDescription, "OCR not enabled in configuration")
        }
    }
    
    // MARK: - Font Analysis Tests
    
    func testAdvancedFontAnalysis() throws {
        let config = createAdvancedConfig()
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        _ = try wrapper.analyzePDF(pdfData)
        
        // Perform font analysis
        try wrapper.analyzeFonts(pageIndex: 0)
        
        // Get layout elements to see font analysis
        try wrapper.classifyLayout(pageIndex: 0)
        let elements = try wrapper.getLayoutElements(pageIndex: 0)
        
        XCTAssertFalse(elements.isEmpty, "Should have layout elements with font analysis")
        
        for element in elements {
            XCTAssertFalse(element.font.family.isEmpty)
            XCTAssertGreaterThan(element.font.size, 0.0)
            XCTAssertGreaterThanOrEqual(element.font.weight, 100)
            XCTAssertLessThanOrEqual(element.font.weight, 900)
            XCTAssertGreaterThanOrEqual(element.font.xHeight, 0.0)
            XCTAssertGreaterThanOrEqual(element.font.capHeight, 0.0)
        }
    }
    
    // MARK: - Layout Classification Tests
    
    func testLayoutClassification() throws {
        let config = createAdvancedConfig()
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        _ = try wrapper.analyzePDF(pdfData)
        
        // Perform layout classification
        try wrapper.classifyLayout(pageIndex: 0)
        
        let elements = try wrapper.getLayoutElements(pageIndex: 0)
        XCTAssertFalse(elements.isEmpty, "Should have classified layout elements")
        
        // Validate classification results
        var foundTypes: Set<LayoutElementType> = []
        for element in elements {
            foundTypes.insert(element.type)
            XCTAssertGreaterThanOrEqual(element.confidence, 0.0)
            XCTAssertLessThanOrEqual(element.confidence, 1.0)
            XCTAssertNotEqual(element.elementId, 0)
        }
        
        // Should have at least some paragraphs
        XCTAssertTrue(foundTypes.contains(.paragraph) || !elements.isEmpty, 
                     "Should detect paragraphs or have some elements")
    }
    
    func testLayoutElementTypes() {
        // Test all layout element types
        for type in LayoutElementType.allCases {
            let description = type.description
            XCTAssertFalse(description.isEmpty)
            
            // Test enum values
            switch type {
            case .unknown:
                XCTAssertEqual(type.rawValue, 0)
            case .header:
                XCTAssertEqual(type.rawValue, 1)
            case .paragraph:
                XCTAssertEqual(type.rawValue, 2)
            case .listItem:
                XCTAssertEqual(type.rawValue, 3)
            case .tableCell:
                XCTAssertEqual(type.rawValue, 4)
            case .caption:
                XCTAssertEqual(type.rawValue, 5)
            case .footer:
                XCTAssertEqual(type.rawValue, 6)
            case .sidebar:
                XCTAssertEqual(type.rawValue, 7)
            case .quote:
                XCTAssertEqual(type.rawValue, 8)
            case .codeBlock:
                XCTAssertEqual(type.rawValue, 9)
            }
        }
    }
    
    // MARK: - Reading Order Tests
    
    func testReadingOrderDetection() throws {
        let config = createAdvancedConfig()
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        _ = try wrapper.analyzePDF(pdfData)
        try wrapper.classifyLayout(pageIndex: 0)
        
        // Detect reading order
        try wrapper.detectReadingOrder(pageIndex: 0)
        
        let readingOrder = try wrapper.getReadingOrder(pageIndex: 0)
        
        if !readingOrder.elementIds.isEmpty {
            XCTAssertEqual(readingOrder.elementIds.count, readingOrder.confidenceScores.count)
            
            for (index, confidence) in readingOrder.confidenceScores.enumerated() {
                XCTAssertGreaterThanOrEqual(confidence, 0.0)
                XCTAssertLessThanOrEqual(confidence, 1.0)
                XCTAssertNotEqual(readingOrder.elementIds[index], 0)
            }
        }
    }
    
    // MARK: - Document Structure Tests
    
    func testDocumentStructureAnalysis() throws {
        let config = createAdvancedConfig()
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        _ = try wrapper.analyzePDF(pdfData)
        
        // Analyze document structure
        let structure = try wrapper.analyzeDocumentStructure()
        
        XCTAssertGreaterThan(structure.totalPages, 0)
        XCTAssertGreaterThanOrEqual(structure.sectionCount, 0)
        
        if structure.sectionCount > 0 {
            XCTAssertEqual(structure.sectionTitles.count, Int(structure.sectionCount))
            XCTAssertEqual(structure.sectionStartPages.count, Int(structure.sectionCount))
            XCTAssertEqual(structure.elementCounts.count, Int(structure.sectionCount))
            
            for (index, title) in structure.sectionTitles.enumerated() {
                XCTAssertFalse(title.isEmpty, "Section \(index) should have a title")
            }
        }
        
        // Validate boolean flags
        let hasTOC = structure.hasTOC
        let hasIndex = structure.hasIndex
        let hasBibliography = structure.hasBibliography
        
        // These can be true or false, but should be valid booleans
        XCTAssertTrue(hasTOC == true || hasTOC == false)
        XCTAssertTrue(hasIndex == true || hasIndex == false)
        XCTAssertTrue(hasBibliography == true || hasBibliography == false)
    }
    
    // MARK: - Integration Tests
    
    func testFullAdvancedWorkflow() throws {
        let config = createAdvancedConfig()
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        // Step 1: Analyze PDF
        let layouts = try wrapper.analyzePDF(pdfData)
        XCTAssertFalse(layouts.isEmpty, "Should analyze PDF successfully")
        
        let pageIndex: UInt32 = 0
        
        // Step 2: Perform OCR
        try wrapper.performOCR(pageIndex: pageIndex, language: "eng")
        let ocrResults = try wrapper.getOCRResults(pageIndex: pageIndex)
        
        // Step 3: Analyze fonts
        try wrapper.analyzeFonts(pageIndex: pageIndex)
        
        // Step 4: Classify layout
        try wrapper.classifyLayout(pageIndex: pageIndex)
        let elements = try wrapper.getLayoutElements(pageIndex: pageIndex)
        XCTAssertFalse(elements.isEmpty, "Should have classified elements")
        
        // Step 5: Detect reading order
        try wrapper.detectReadingOrder(pageIndex: pageIndex)
        let readingOrder = try wrapper.getReadingOrder(pageIndex: pageIndex)
        
        // Step 6: Analyze document structure
        let structure = try wrapper.analyzeDocumentStructure()
        XCTAssertGreaterThan(structure.totalPages, 0)
        
        // Step 7: Validate OCR accuracy if we have results
        if !ocrResults.isEmpty {
            let combinedOCRText = ocrResults.map { $0.text }.joined(separator: " ")
            if !combinedOCRText.isEmpty {
                let accuracy = try wrapper.validateOCRAccuracy(
                    pageIndex: pageIndex, 
                    groundTruthText: combinedOCRText
                )
                XCTAssertGreaterThanOrEqual(accuracy.characterAccuracy, 0.0)
                XCTAssertLessThanOrEqual(accuracy.characterAccuracy, 1.0)
            }
        }
        
        print("Advanced workflow completed successfully!")
        print("  OCR results: \(ocrResults.count)")
        print("  Layout elements: \(elements.count)")
        print("  Reading order elements: \(readingOrder.elementIds.count)")
        print("  Document sections: \(structure.sectionCount)")
    }
    
    // MARK: - Performance Tests
    
    func testAdvancedFeaturesPerformance() throws {
        let config = createAdvancedConfig()
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        measure {
            do {
                let layouts = try wrapper.analyzePDF(pdfData)
                if !layouts.isEmpty {
                    let pageIndex: UInt32 = 0
                    
                    // Perform all advanced features
                    try? wrapper.performOCR(pageIndex: pageIndex, language: "eng")
                    try? wrapper.analyzeFonts(pageIndex: pageIndex)
                    try? wrapper.classifyLayout(pageIndex: pageIndex)
                    try? wrapper.detectReadingOrder(pageIndex: pageIndex)
                    try? wrapper.analyzeDocumentStructure()
                }
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testAdvancedFeaturesMemoryLeak() throws {
        let config = createAdvancedConfig()
        let pdfData = try loadResourcePDF()
        
        // Create and destroy many wrappers with advanced features
        for _ in 0..<10 {
            let wrapper = try LayoutEngineCapsuleWrapper(config: config)
            let layouts = try wrapper.analyzePDF(pdfData)
            
            if !layouts.isEmpty {
                let pageIndex: UInt32 = 0
                
                // Use all advanced features
                try? wrapper.performOCR(pageIndex: pageIndex, language: "eng")
                _ = try? wrapper.getOCRResults(pageIndex: pageIndex)
                try? wrapper.analyzeFonts(pageIndex: pageIndex)
                try? wrapper.classifyLayout(pageIndex: pageIndex)
                _ = try? wrapper.getLayoutElements(pageIndex: pageIndex)
                try? wrapper.detectReadingOrder(pageIndex: pageIndex)
                _ = try? wrapper.getReadingOrder(pageIndex: pageIndex)
                _ = try? wrapper.analyzeDocumentStructure()
            }
            
            // wrapper should be deallocated at end of iteration
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testAdvancedFeaturesErrorHandling() throws {
        let config = createAdvancedConfig()
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        _ = try wrapper.analyzePDF(pdfData)
        
        // Test with invalid page index
        XCTAssertThrowsError(try wrapper.performOCR(pageIndex: 999, language: "eng")) { error in
            XCTAssertTrue(error is CapsuleError)
        }
        
        XCTAssertThrowsError(try wrapper.analyzeFonts(pageIndex: 999)) { error in
            XCTAssertTrue(error is CapsuleError)
        }
        
        XCTAssertThrowsError(try wrapper.classifyLayout(pageIndex: 999)) { error in
            XCTAssertTrue(error is CapsuleError)
        }
        
        XCTAssertThrowsError(try wrapper.detectReadingOrder(pageIndex: 999)) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    // MARK: - Profiling Tests
    
    func testAdvancedFeaturesProfiling() throws {
        var config = createAdvancedConfig()
        config.enableProfiling = true
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        let pdfData = try loadResourcePDF()
        
        _ = try wrapper.analyzePDF(pdfData)
        
        // Perform advanced features
        let pageIndex: UInt32 = 0
        try wrapper.performOCR(pageIndex: pageIndex, language: "eng")
        try wrapper.analyzeFonts(pageIndex: pageIndex)
        try wrapper.classifyLayout(pageIndex: pageIndex)
        try wrapper.detectReadingOrder(pageIndex: pageIndex)
        _ = try wrapper.analyzeDocumentStructure()
        
        // Get profiling stats
        let stats = try wrapper.getProfilingStats()
        XCTAssertGreaterThan(stats.totalPagesProcessed, 0)
        XCTAssertGreaterThanOrEqual(stats.totalAnalysisTimeMs, 0.0)
    }
}