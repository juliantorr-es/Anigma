// LayoutAnalyzerCapsule - Layout analysis wrapper for PDF exporter
//
// This capsule provides layout analysis capabilities for the PDF exporter
// pipeline, enabling enhanced document structure understanding and content
// placement based on source PDF layout information.

import Foundation
import CapsuleCore
import LayoutEngineCapsule
import TelemetryCore
import DocumentIRKit
import TableExtractionCapsule
import MathOCRCapsule
import CitationExtractionCapsule
import ReferenceResolutionCapsule
import DiffCapsule

/// Layout analyzer capsule for PDF exporter
public actor LayoutAnalyzerCapsule: IdentifiableCapsule {
    private let layoutEngine: LayoutEngineCapsule
    private let tableExtractor: TableExtractionCapsule?
    private let equationRecognizer: MathOCRCapsule?
    private let citationExtractor: CitationExtractionCapsule?
    private let referenceResolver: ReferenceResolutionCapsule?
    private let diffEngine: DiffCapsule?
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "layout-analyzer-v1"
    
    /// Initialize the layout analyzer capsule
    ///
    /// - Parameters:
    ///   - config: Layout engine configuration
    ///   - diagnostics: Optional diagnostics provider
    /// - Throws: If initialization fails
    public init(
        config: LayoutEngineConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "LayoutAnalyzerCapsule.init",
            category: "pdfexporter.layout.analyzer.init",
            correlationID: nil,
            tags: [
                "algorithm_version": Self.algorithmVersion,
                "determinism_tier": "\(config.determinismTier.rawValue)",
                "flags": "\(config.flags)"
            ]
        )
        
        do {
            self.layoutEngine = try LayoutEngineCapsule(
                config: config,
                diagnostics: resolvedDiagnostics
            )
            
            // Initialize table extractor if enabled
            if config.flags.contains(.enableTableExtraction) {
                let tableConfig = TableExtractionConfig()
                tableConfig.minTableArea = config.tableDetectionMinArea
                tableConfig.maxAspectRatio = config.tableDetectionMaxAspectRatio
                tableConfig.enableCellMerging = config.flags.contains(.enableCellMerging)
                tableConfig.enableHeaderDetection = config.flags.contains(.enableHeaderDetection)
                tableConfig.enableFooterDetection = config.flags.contains(.enableFooterDetection)
                self.tableExtractor = try TableExtractionCapsule(config: tableConfig, diagnostics: resolvedDiagnostics)
            } else {
                self.tableExtractor = nil
            }
            
            // Initialize equation recognizer if enabled
            if config.flags.contains(.enableEquationRecognition) {
                let equationConfig = EquationRecognitionConfig()
                equationConfig.minEquationArea = config.equationDetectionMinArea
                equationConfig.enableSymbolRecognition = config.flags.contains(.enableSymbolRecognition)
                equationConfig.enableLaTeXGeneration = config.flags.contains(.enableLaTeXGeneration)
                equationConfig.enableUnicodeGeneration = config.flags.contains(.enableUnicodeGeneration)
                self.equationRecognizer = try MathOCRCapsule(config: equationConfig, diagnostics: resolvedDiagnostics)
            } else {
                self.equationRecognizer = nil
            }
            
            // Initialize citation extractor if enabled
            if config.flags.contains(.enableCitationExtraction) {
                let citationConfig = CitationExtractionConfig()
                citationConfig.enableRegexExtraction = config.flags.contains(.enableRegexExtraction)
                citationConfig.enableReferenceSectionDetection = config.flags.contains(.enableReferenceSectionDetection)
                citationConfig.enableInlineCitationDetection = config.flags.contains(.enableInlineCitationDetection)
                self.citationExtractor = try CitationExtractionCapsule(config: citationConfig, diagnostics: resolvedDiagnostics)
            } else {
                self.citationExtractor = nil
            }
            
            // Initialize reference resolver if enabled
            if config.flags.contains(.enableReferenceResolution) {
                let resolverConfig = ReferenceResolutionConfig()
                resolverConfig.fuzzyThreshold = config.referenceResolutionFuzzyThreshold
                resolverConfig.enableFuzzyMatching = config.flags.contains(.enableFuzzyMatching)
                resolverConfig.enableCaching = config.flags.contains(.enableCaching)
                self.referenceResolver = try ReferenceResolutionCapsule(config: resolverConfig, diagnostics: resolvedDiagnostics)
            } else {
                self.referenceResolver = nil
            }
            
            // Initialize diff engine if enabled
            if config.flags.contains(.enableDiffAnalysis) {
                let diffConfig = DiffConfig()
                diffConfig.enableLineDiff = config.flags.contains(.enableLineDiff)
                diffConfig.enableWordDiff = config.flags.contains(.enableWordDiff)
                diffConfig.enableCharDiff = config.flags.contains(.enableCharDiff)
                diffConfig.ignoreWhitespace = config.flags.contains(.ignoreWhitespace)
                diffConfig.ignoreCase = config.flags.contains(.ignoreCase)
                diffConfig.contextLines = config.diffContextLines
                self.diffEngine = try DiffCapsule(config: diffConfig, diagnostics: resolvedDiagnostics)
            } else {
                self.diffEngine = nil
            }
            
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "pdfexporter.layout.analyzer.init",
                message: "Failed to initialize layout analyzer: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Analyze source PDF for layout information
    ///
    /// - Parameters:
    ///   - data: PDF data
    ///   - manifest: Book project manifest
    /// - Returns: Tuple containing layout analysis result and capsule receipt
    /// - Throws: If analysis fails
    public func analyzeSourcePDF(
        data: Data,
        manifest: BookProjectManifest
    ) async throws -> (LayoutAnalysisResult, CapsuleReceipt) {
        let span = diagnostics.beginSpan(
            name: "LayoutAnalyzerCapsule.analyzeSourcePDF",
            category: "pdfexporter.layout.analyzer.analyze",
            correlationID: nil,
            tags: [
                "input_bytes": "\(data.count)",
                "page_count": "\(manifest.paperSize.height / 792)", // Approximate
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            // Analyze PDF layout
            let layouts = try layoutEngine.analyzePDF(data)
            
            // Extract layout information
            let result = try extractLayoutInformation(
                layouts: layouts,
                manifest: manifest
            )
            
            // Generate receipt
            let receipt = try await generateReceipt(
                inputs: ["pdf": data],
                outputs: ["analysis": result],
                metadata: [
                    "page_count": "\(result.pageCount)",
                    "header_count": "\(result.headers.count)",
                    "table_count": "\(result.tables.count)",
                    "figure_count": "\(result.figures.count)",
                    "section_count": "\(result.documentStructure.sections.count)"
                ]
            )
            
            diagnostics.event(
                level: .info,
                category: "pdfexporter.layout.analyzer.analyze",
                message: "Layout analysis completed successfully",
                correlationID: nil,
                tags: [
                    "page_count": "\(result.pageCount)",
                    "header_count": "\(result.headers.count)",
                    "table_count": "\(result.tables.count)"
                ]
            )
            
            span.end(status: .ok)
            return (result, receipt)
        } catch {
            diagnostics.event(
                level: .error,
                category: "pdfexporter.layout.analyzer.analyze",
                message: "Layout analysis failed: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Extract layout information from page layouts
    ///
    /// - Parameters:
    ///   - layouts: Page layouts from layout engine
    ///   - manifest: Book project manifest
    /// - Returns: Layout analysis result
    /// - Throws: If extraction fails
    private func extractLayoutInformation(
        layouts: [PageLayout],
        manifest: BookProjectManifest
    ) throws -> LayoutAnalysisResult {
        // Extract headers
        let headers = try extractHeaders(from: layouts)
        
        // Extract footers
        let footers = try extractFooters(from: layouts)
        
        // Extract tables
        let tables = try extractTables(from: layouts)
        
        // Extract figures
        let figures = try extractFigures(from: layouts)
        
        // Extract equations
        let equations = try extractEquations(from: layouts)
        
        // Extract citations
        let citations = try extractCitations(from: layouts)
        
        // Resolve references
        let resolvedReferences = try resolveReferences(from: citations)
        
        // Detect reading order
        let readingOrder = try detectReadingOrder(from: layouts)
        
        // Analyze document structure
        let documentStructure = try analyzeDocumentStructure(
            layouts: layouts,
            headers: headers
        )
        
        return LayoutAnalysisResult(
            pageCount: layouts.count,
            headers: headers,
            footers: footers,
            tables: tables,
            figures: figures,
            equations: equations,
            citations: citations,
            resolvedReferences: resolvedReferences,
            readingOrder: readingOrder,
            documentStructure: documentStructure
        )
    }
    
    /// Extract headers from page layouts
    ///
    /// - Parameter layouts: Page layouts
    /// - Returns: Array of header information
    /// - Throws: If extraction fails
    private func extractHeaders(from layouts: [PageLayout]) throws -> [HeaderInfo] {
        var headers: [HeaderInfo] = []
        
        for (pageIndex, layout) in layouts.enumerated() {
            // Headers are typically at the top of pages
            // We look for text segments with large font sizes and top positioning
            let headerSegments = layout.segments.filter { segment in
                // Consider segments in top 20% of page as potential headers
                let topPosition = segment.bbox.top
                let pageHeight = manifest.paperSize.height
                let isTopPositioned = topPosition > pageHeight * 0.8
                
                // Consider segments with larger font sizes as headers
                let isLargeFont = segment.fontSize > 14.0
                
                return isTopPositioned && isLargeFont && !segment.text.isEmpty
            }
            
            // Group segments by horizontal position (same line)
            let groupedHeaders = groupSegmentsByLine(segments: headerSegments)
            
            for group in groupedHeaders {
                let combinedText = group.map { $0.text }.joined(separator: " ")
                let combinedBBox = calculateCombinedBoundingBox(bboxes: group.map { $0.bbox })
                
                // Determine header level based on font size
                let level = determineHeaderLevel(fontSize: group.first?.fontSize ?? 16.0)
                
                let fontInfo = group.first.flatMap { segment in
                    FontInfo(
                        family: segment.fontName ?? "Unknown",
                        subfamily: "",
                        size: segment.fontSize,
                        weight: segment.fontFlags & 0x1 != 0 ? 700 : 400, // Bold flag
                        italic: segment.fontFlags & 0x2 != 0,
                        bold: segment.fontFlags & 0x1 != 0
                    )
                }
                
                // Determine header type
                let headerType = determineHeaderType(
                    text: combinedText,
                    level: level,
                    pageIndex: pageIndex,
                    fontInfo: fontInfo
                )
                
                headers.append(HeaderInfo(
                    text: combinedText,
                    bbox: BoundingBox(
                        left: combinedBBox.left,
                        top: combinedBBox.top,
                        right: combinedBBox.right,
                        bottom: combinedBBox.bottom
                    ),
                    pageIndex: pageIndex,
                    level: level,
                    type: headerType,
                    font: fontInfo
                ))
            }
        }
        
        // Sort headers by page and position
        return headers.sorted { a, b in
            if a.pageIndex == b.pageIndex {
                return a.bbox.top > b.bbox.top // Higher on page first
            }
            return a.pageIndex < b.pageIndex
        }
    }
    
    /// Extract footers from page layouts
    ///
    /// - Parameter layouts: Page layouts
    /// - Returns: Array of footer information
    /// - Throws: If extraction fails
    private func extractFooters(from layouts: [PageLayout]) throws -> [FooterInfo] {
        var footers: [FooterInfo] = []
        
        for (pageIndex, layout) in layouts.enumerated() {
            // Footers are typically at the bottom of pages
            let footerSegments = layout.segments.filter { segment in
                // Consider segments in bottom 15% of page as potential footers
                let bottomPosition = segment.bbox.bottom
                let pageHeight = manifest.paperSize.height
                let isBottomPositioned = bottomPosition < pageHeight * 0.15
                
                return isBottomPositioned && !segment.text.isEmpty
            }
            
            // Group segments by horizontal position (same line)
            let groupedFooters = groupSegmentsByLine(segments: footerSegments)
            
            for group in groupedFooters {
                let combinedText = group.map { $0.text }.joined(separator: " ")
                let combinedBBox = calculateCombinedBoundingBox(bboxes: group.map { $0.bbox })
                
                let fontInfo = group.first.flatMap { segment in
                    FontInfo(
                        family: segment.fontName ?? "Unknown",
                        subfamily: "",
                        size: segment.fontSize,
                        weight: segment.fontFlags & 0x1 != 0 ? 700 : 400,
                        italic: segment.fontFlags & 0x2 != 0,
                        bold: segment.fontFlags & 0x1 != 0
                    )
                }
                
                footers.append(FooterInfo(
                    text: combinedText,
                    bbox: BoundingBox(
                        left: combinedBBox.left,
                        top: combinedBBox.top,
                        right: combinedBBox.right,
                        bottom: combinedBBox.bottom
                    ),
                    pageIndex: pageIndex,
                    font: fontInfo
                ))
            }
        }
        
        return footers
    }
    
    /// Extract tables from page layouts
    ///
    /// - Parameter layouts: Page layouts
    /// - Returns: Array of table information
    /// - Throws: If extraction fails
    private func extractTables(from layouts: [PageLayout]) throws -> [TableInfo] {
        // If table extraction is enabled, use the dedicated table extractor
        if let tableExtractor = tableExtractor {
            return try layouts.enumerated().flatMap { (pageIndex, layout) in
                let result = try tableExtractor.extractTables(
                    from: layout.segments,
                    pageIndex: pageIndex,
                    pageWidth: manifest.paperSize.width,
                    pageHeight: manifest.paperSize.height
                )
                
                return result.tables.enumerated().map { (tableIndex, table) in
                    TableInfo(
                        bbox: BoundingBox(
                            left: table.bbox.x,
                            top: table.bbox.y,
                            right: table.bbox.x + table.bbox.width,
                            bottom: table.bbox.y + table.bbox.height
                        ),
                        pageIndex: pageIndex,
                        rowCount: Int32(table.numRows),
                        columnCount: Int32(table.numColumns),
                        caption: nil,
                        cells: table.cells.map { cell in
                            TableCell(
                                text: cell.text,
                                row: Int32(cell.row),
                                column: Int32(cell.column),
                                bbox: BoundingBox(
                                    left: cell.bounding_box.x,
                                    top: cell.bounding_box.y,
                                    right: cell.bounding_box.x + cell.bounding_box.width,
                                    bottom: cell.bounding_box.y + cell.bounding_box.height
                                )
                            )
                        }
                    )
                }
            }
        }
        
        // Fallback to layout engine table detection
        return layouts.enumerated().flatMap { (pageIndex, layout) in
            layout.tableBBoxes.enumerated().map { (tableIndex, bbox) in
                TableInfo(
                    bbox: BoundingBox(
                        left: bbox.left,
                        top: bbox.top,
                        right: bbox.right,
                        bottom: bbox.bottom
                    ),
                    pageIndex: pageIndex,
                    rowCount: nil,
                    columnCount: nil,
                    caption: nil
                )
            }
        }
    }
    
    /// Extract figures from page layouts
    ///
    /// - Parameter layouts: Page layouts
    /// - Returns: Array of figure information
    /// - Throws: If extraction fails
    private func extractFigures(from layouts: [PageLayout]) throws -> [FigureInfo] {
        return layouts.enumerated().flatMap { (pageIndex, layout) in
            layout.figureBBoxes.enumerated().map { (figureIndex, bbox) in
                FigureInfo(
                    bbox: BoundingBox(
                        left: bbox.left,
                        top: bbox.top,
                        right: bbox.right,
                        bottom: bbox.bottom
                    ),
                    pageIndex: pageIndex,
                    caption: nil
                )
            }
        }
    }
    
    /// Compute diff between two documents
    ///
    /// - Parameters:
    ///   - original: Original document content
    ///   - modified: Modified document content
    /// - Returns: Document diff result
    /// - Throws: If diff computation fails
    public func computeDocumentDiff(original: String, modified: String) throws -> DocumentDiffResult {
        let span = diagnostics.beginSpan(
            name: "LayoutAnalyzerCapsule.computeDocumentDiff",
            category: "pdfexporter.layout.analyzer.diff",
            correlationID: nil,
            tags: [
                "original_length": "\(original.count)",
                "modified_length": "\(modified.count)"
            ]
        )
        
        do {
            // If diff engine is enabled, use it
            if let diffEngine = diffEngine {
                let result = try diffEngine.computeDiff(original: original, modified: modified)
                span.end(status: .ok)
                return result
            }
            
            // Fallback: simple diff using string comparison
            let similarity: Float
            if original == modified {
                similarity = 1.0
            } else if original.isEmpty || modified.isEmpty {
                similarity = 0.0
            } else {
                // Simple similarity based on common characters
                let common = original.filter { original.contains($0) && modified.contains($0) }
                similarity = Float(common.count) / Float(max(original.count, modified.count))
            }
            
            span.end(status: .ok)
            return DocumentDiffResult(
                operations: [],
                original: DocumentVersion(content: original),
                modified: DocumentVersion(content: modified),
                similarity: similarity,
                processingTime: 0
            )
        } catch {
            diagnostics.event(
                level: .error,
                category: "pdfexporter.layout.analyzer.diff",
                message: "Failed to compute document diff: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Resolve references using the reference resolver
    ///
    /// - Parameter citations: Citation extraction result
    /// - Returns: Reference resolution result
    /// - Throws: If resolution fails
    private func resolveReferences(from citations: CitationExtractionResult) throws -> ReferenceResolutionResult {
        // If reference resolution is enabled, use the dedicated resolver
        if let referenceResolver = referenceResolver {
            return try referenceResolver.resolve(references: citations.references)
        }
        
        // Fallback: return unresolved references
        return ReferenceResolutionResult(
            resolvedReferences: [],
            unresolvedReferences: citations.references,
            processingTime: 0
        )
    }
    
    /// Extract citations from page layouts
    ///
    /// - Parameter layouts: Page layouts
    /// - Returns: Citation extraction result
    /// - Throws: If extraction fails
    private func extractCitations(from layouts: [PageLayout]) throws -> CitationExtractionResult {
        // If citation extraction is enabled, use the dedicated extractor
        if let citationExtractor = citationExtractor {
            // Combine all segments from all pages
            var allSegments: [LayoutSegment] = []
            for (pageIndex, layout) in layouts.enumerated() {
                allSegments.append(contentsOf: layout.segments)
            }
            
            let result = try citationExtractor.extractCitations(
                from: allSegments,
                pageIndex: 0, // All segments combined
                pageWidth: manifest.paperSize.width,
                pageHeight: manifest.paperSize.height
            )
            
            return result
        }
        
        // Fallback: simple citation detection based on patterns
        var references: [CitationReference] = []
        var inlineCitations: [InlineCitation] = []
        
        // Look for reference sections
        for (pageIndex, layout) in layouts.enumerated() {
            for segment in layout.segments {
                let text = segment.text.lowercased()
                // Check for reference section headers
                if text.contains("references") || text.contains("bibliography") || text.contains("works cited") {
                    // This is a reference section - extract subsequent segments
                    break
                }
            }
        }
        
        return CitationExtractionResult(
            references: references,
            inlineCitations: inlineCitations,
            processingTime: 0
        )
    }
    
    /// Extract equations from page layouts
    ///
    /// - Parameter layouts: Page layouts
    /// - Returns: Array of equation information
    /// - Throws: If extraction fails
    private func extractEquations(from layouts: [PageLayout]) throws -> [EquationInfo] {
        // If equation recognition is enabled, use the dedicated recognizer
        if let equationRecognizer = equationRecognizer {
            return try layouts.enumerated().flatMap { (pageIndex, layout) in
                let result = try equationRecognizer.recognizeEquations(
                    from: layout.segments,
                    pageIndex: pageIndex,
                    pageWidth: manifest.paperSize.width,
                    pageHeight: manifest.paperSize.height
                )
                
                return result.equations.enumerated().map { (equationIndex, equation) in
                    EquationInfo(
                        bbox: BoundingBox(
                            left: equation.boundingBox.left,
                            top: equation.boundingBox.top,
                            right: equation.boundingBox.right,
                            bottom: equation.boundingBox.bottom
                        ),
                        pageIndex: pageIndex,
                        latex: equation.latex,
                        unicode: equation.unicode,
                        mathml: equation.mathml,
                        symbols: equation.symbols.map { symbol in
                            EquationSymbol(
                                text: symbol.text,
                                type: symbol.symbolType?.rawValue ?? 0,
                                position: Int32(symbol.positionInEquation)
                            )
                        }
                    )
                }
            }
        }
        
        // Fallback: detect equations based on mathematical content in text segments
        return layouts.enumerated().flatMap { (pageIndex, layout) in
            layout.segments.enumerated().compactMap { (segmentIndex, segment) in
                // Look for segments containing mathematical content
                let text = segment.text
                let hasMathContent = text.contains(where: { $0 == "$" || $0 == "\\" || $0 == "=" || $0 == "+" || $0 == "-" || $0 == "×" || $0 == "÷" || $0 == "∑" || $0 == "∫" || $0 == "√" })
                
                if hasMathContent {
                    return EquationInfo(
                        bbox: BoundingBox(
                            left: segment.bbox.left,
                            top: segment.bbox.top,
                            right: segment.bbox.right,
                            bottom: segment.bbox.bottom
                        ),
                        pageIndex: pageIndex,
                        latex: text,
                        unicode: text,
                        mathml: "<math>" + text + "</math>",
                        symbols: []
                    )
                }
                
                return nil
            }
        }
    }
    
    /// Detect reading order from page layouts
    ///
    /// - Parameter layouts: Page layouts
    /// - Returns: Reading order information
    /// - Throws: If detection fails
    private func detectReadingOrder(from layouts: [PageLayout]) throws -> ReadingOrderInfo {
        // For now, use a simple top-to-bottom, left-to-right approach
        // In the future, this could be enhanced with more sophisticated
        // reading order detection algorithms
        
        var elementIds: [String] = []
        var confidenceScores: [Double] = []
        var columnBreaks: [Int] = []
        
        for layout in layouts {
            // Sort segments by reading order
            let sortedSegments = layout.segments.sorted { a, b in
                // First by top position (top to bottom)
                if a.bbox.top != b.bbox.top {
                    return a.bbox.top > b.bbox.top
                }
                // Then by left position (left to right)
                return a.bbox.left < b.bbox.left
            }
            
            for segment in sortedSegments {
                let elementId = "segment_\(UUID().uuidString)"
                elementIds.append(elementId)
                confidenceScores.append(0.95) // High confidence for simple algorithm
            }
            
            // Add column break after each page
            if !elementIds.isEmpty {
                columnBreaks.append(elementIds.count - 1)
            }
        }
        
        return ReadingOrderInfo(
            elementIds: elementIds,
            confidenceScores: confidenceScores,
            columnBreaks: columnBreaks
        )
    }
    
    /// Analyze document structure
    ///
    /// - Parameters:
    ///   - layouts: Page layouts
    ///   - headers: Extracted headers
    /// - Returns: Document structure information
    /// - Throws: If analysis fails
    private func analyzeDocumentStructure(
        layouts: [PageLayout],
        headers: [HeaderInfo]
    ) throws -> DocumentStructureInfo {
        // Create section information with enhanced type detection
        var sectionInfos: [SectionInfo] = []
        
        // Add all headers as sections with proper typing
        for (index, header) in headers.enumerated() {
            let isFirstSection = index == 0
            let sectionType = determineSectionType(
                header: header,
                pageIndex: header.pageIndex,
                isFirstSection: isFirstSection
            )
            
            sectionInfos.append(SectionInfo(
                title: header.text,
                startPage: header.pageIndex,
                endPage: header.pageIndex, // Will be updated
                level: header.level,
                type: sectionType
            ))
        }
        
        // Update end pages for sections
        try updateSectionEndPages(sections: &sectionInfos, totalPages: layouts.count)
        
        // Detect special pages (TOC, index, bibliography)
        let hasTOC = detectTableOfContents(in: headers)
        let hasIndex = detectIndex(in: headers)
        let hasBibliography = detectBibliography(in: headers)
        
        return DocumentStructureInfo(
            totalPages: layouts.count,
            sections: sectionInfos,
            hasTOC: hasTOC,
            hasIndex: hasIndex,
            hasBibliography: hasBibliography
        )
    }
    
    /// Update end pages for sections based on subsequent sections
    ///
    /// - Parameters:
    ///   - sections: Array of section info (inout)
    ///   - totalPages: Total number of pages
    /// - Throws: If section processing fails
    private func updateSectionEndPages(sections: inout [SectionInfo], totalPages: Int) throws {
        guard !sections.isEmpty else { return }
        
        // Start with the last section
        var lastSectionIndex = sections.count - 1
        sections[lastSectionIndex].endPage = totalPages - 1
        
        // Work backwards to set end pages
        for i in stride(from: lastSectionIndex - 1, through: 0, by: -1) {
            let currentSection = sections[i]
            let nextSection = sections[i + 1]
            
            // End page is the page before the next section starts
            sections[i].endPage = nextSection.startPage - 1
        }
    }
    
    /// Detect table of contents in headers
    ///
    /// - Parameter headers: Extracted headers
    /// - Returns: True if TOC detected
    private func detectTableOfContents(in headers: [HeaderInfo]) -> Bool {
        let tocKeywords = ["table", "of", "contents", "toc", "index"]
        return headers.contains { header in
            let lowerText = header.text.lowercased()
            return tocKeywords.contains { keyword in
                lowerText.contains(keyword)
            }
        }
    }
    
    /// Detect index in headers
    ///
    /// - Parameter headers: Extracted headers
    /// - Returns: True if index detected
    private func detectIndex(in headers: [HeaderInfo]) -> Bool {
        let indexKeywords = ["index"]
        return headers.contains { header in
            let lowerText = header.text.lowercased()
            return indexKeywords.contains { keyword in
                lowerText.contains(keyword)
            }
        }
    }
    
    /// Detect bibliography in headers
    ///
    /// - Parameter headers: Extracted headers
    /// - Returns: True if bibliography detected
    private func detectBibliography(in headers: [HeaderInfo]) -> Bool {
        let bibKeywords = ["bibliography", "references", "works cited"]
        return headers.contains { header in
            let lowerText = header.text.lowercased()
            return bibKeywords.contains { keyword in
                lowerText.contains(keyword)
            }
        }
    }
    
    /// Determine header type based on text content and position
    ///
    /// - Parameters:
    ///   - text: Header text
    ///   - level: Header level
    ///   - pageIndex: Page index
    ///   - fontInfo: Font information
    /// - Returns: Header type
    private func determineHeaderType(
        text: String,
        level: Int,
        pageIndex: Int,
        fontInfo: FontInfo?
    ) -> HeaderType {
        let lowerText = text.lowercased()
        
        // Check for special page types
        if pageIndex == 0 {
            // First page is likely title page
            if lowerText.contains("copyright") || lowerText.contains("©") {
                return .copyrightPage
            }
            return .titlePage
        }
        
        // Check for TOC
        if lowerText.contains("table") && lowerText.contains("contents") {
            return .tableOfContents
        }
        
        // Check for index
        if lowerText.contains("index") {
            return .index
        }
        
        // Check for bibliography/references
        if lowerText.contains("bibliography") || 
           lowerText.contains("references") || 
           lowerText.contains("works cited") {
            return .bibliography
        }
        
        // Check for appendix
        if lowerText.contains("appendix") {
            return .appendix
        }
        
        // Determine based on level
        switch level {
        case 1:
            return .chapter
        case 2:
            return .section
        case 3:
            return .subsection
        default:
            return .other
        }
    }
    
    /// Determine section type based on header type and position
    ///
    /// - Parameters:
    ///   - header: Header information
    ///   - pageIndex: Page index
    ///   - isFirstSection: Whether this is the first section
    /// - Returns: Section type
    private func determineSectionType(
        header: HeaderInfo,
        pageIndex: Int,
        isFirstSection: Bool
    ) -> SectionType {
        // Map header type to section type
        switch header.type {
        case .titlePage:
            return .titlePage
        case .copyrightPage:
            return .copyrightPage
        case .tableOfContents:
            return .tableOfContents
        case .chapter:
            return .chapter
        case .section:
            return .section
        case .subsection:
            return .subsection
        case .appendix:
            return .appendix
        case .index:
            return .index
        case .bibliography:
            return .bibliography
        case .other:
            // Determine based on position and level
            if pageIndex < 5 && header.level == 1 {
                return .frontMatter
            } else if header.level == 1 {
                return .chapter
            } else if header.level == 2 {
                return .section
            } else {
                return .subsection
            }
        }
    }
    
    /// Group text segments by line (horizontal position)
    ///
    /// - Parameter segments: Text segments
    /// - Returns: Array of segment groups
    private func groupSegmentsByLine(segments: [LayoutEngineCapsule.TextSegment]) -> [[LayoutEngineCapsule.TextSegment]] {
        guard !segments.isEmpty else { return [] }
        
        // Sort by vertical position (top to bottom)
        let sortedSegments = segments.sorted { $0.bbox.top > $1.bbox.top }
        
        var groups: [[LayoutEngineCapsule.TextSegment]] = []
        var currentGroup: [LayoutEngineCapsule.TextSegment] = [sortedSegments[0]]
        
        for segment in sortedSegments.dropFirst() {
            // Check if segment is on the same line as previous
            // We consider segments on the same line if their vertical overlap
            // is significant compared to their height
            let previous = currentGroup.last!
            let verticalOverlap = min(segment.bbox.bottom, previous.bbox.bottom) - 
                                 max(segment.bbox.top, previous.bbox.top)
            let segmentHeight = segment.bbox.height
            let previousHeight = previous.bbox.height
            let avgHeight = (segmentHeight + previousHeight) / 2
            
            if verticalOverlap > avgHeight * 0.7 {
                // Same line, add to current group
                currentGroup.append(segment)
            } else {
                // New line, start new group
                groups.append(currentGroup)
                currentGroup = [segment]
            }
        }
        
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    /// Calculate combined bounding box from multiple bounding boxes
    ///
    /// - Parameter bboxes: Array of bounding boxes
    /// - Returns: Combined bounding box
    private func calculateCombinedBoundingBox(bboxes: [LayoutEngineCapsule.BoundingBox]) -> LayoutEngineCapsule.BoundingBox {
        guard !bboxes.isEmpty else {
            return LayoutEngineCapsule.BoundingBox(
                left: 0, top: 0, right: 0, bottom: 0
            )
        }
        
        let minLeft = bboxes.map { $0.left }.min() ?? 0
        let maxTop = bboxes.map { $0.top }.max() ?? 0
        let maxRight = bboxes.map { $0.right }.max() ?? 0
        let minBottom = bboxes.map { $0.bottom }.min() ?? 0
        
        return LayoutEngineCapsule.BoundingBox(
            left: minLeft,
            top: maxTop,
            right: maxRight,
            bottom: minBottom
        )
    }
    
    /// Determine header level based on font size
    ///
    /// - Parameter fontSize: Font size in points
    /// - Returns: Header level (1 = main title, 2 = chapter, etc.)
    private func determineHeaderLevel(fontSize: Double) -> Int {
        if fontSize >= 24 {
            return 1 // Main title
        } else if fontSize >= 18 {
            return 2 // Chapter title
        } else if fontSize >= 14 {
            return 3 // Section title
        } else {
            return 4 // Subsection title
        }
    }
}

// MARK: - Extension for PDFExporterKit

extension PDFExporterKit {
    /// Layout analysis types
    public typealias LayoutAnalysisResult = PDFExporterKit.LayoutAnalysisResult
    public typealias HeaderInfo = PDFExporterKit.HeaderInfo
    public typealias FooterInfo = PDFExporterKit.FooterInfo
    public typealias TableInfo = PDFExporterKit.TableInfo
    public typealias FigureInfo = PDFExporterKit.FigureInfo
    public typealias ReadingOrderInfo = PDFExporterKit.ReadingOrderInfo
    public typealias DocumentStructureInfo = PDFExporterKit.DocumentStructureInfo
    public typealias SectionInfo = PDFExporterKit.SectionInfo
    public typealias FontInfo = PDFExporterKit.FontInfo
    public typealias BoundingBox = PDFExporterKit.BoundingBox
}
