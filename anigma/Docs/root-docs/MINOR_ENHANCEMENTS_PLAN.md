# Minor Enhancements Implementation Plan

## Overview

This document outlines the implementation plan for all minor enhancements to the LayoutEngineCapsule integration with the PDF Exporter. These enhancements will significantly improve the PDF Exporter's capabilities while maintaining the existing standards of determinism, safety, and governance.

## Enhancement 1: Document Structure Analysis

### Current State
- Basic document structure analysis exists in LayoutAnalyzerCapsule
- Detects headers, footers, tables, figures
- Simple reading order detection

### Required Enhancements
1. **Enhanced Chapter Detection**: Better identification of chapter titles
2. **Special Page Detection**: Title pages, copyright pages, TOC, index, bibliography
3. **Section Hierarchy**: Multi-level section detection (chapters, sections, subsections)
4. **Front/Body/Back Matter**: Identification of document sections

### Implementation Plan

#### Step 1: Enhance Header Analysis
**File**: `LayoutAnalyzerCapsule.swift`

```swift
// Enhanced header detection with chapter identification
private func analyzeHeaders(from layouts: [PageLayout]) throws -> [HeaderInfo] {
    var headers: [HeaderInfo] = []
    
    for (pageIndex, layout) in layouts.enumerated() {
        // Extract all potential headers
        let headerSegments = extractHeaderSegments(from: layout)
        
        // Group segments by line
        let groupedHeaders = groupSegmentsByLine(segments: headerSegments)
        
        for group in groupedHeaders {
            let combinedText = group.map { $0.text }.joined(separator: " ")
            let combinedBBox = calculateCombinedBoundingBox(bboxes: group.map { $0.bbox })
            
            // Determine header level and type
            let (level, headerType) = determineHeaderType(
                text: combinedText,
                fontSize: group.first?.fontSize ?? 16.0,
                pageIndex: pageIndex,
                pageCount: layouts.count
            )
            
            let fontInfo = createFontInfo(from: group.first)
            
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
                font: fontInfo,
                type: headerType
            ))
        }
    }
    
    return headers.sorted { $0.pageIndex < $1.pageIndex }
}

private func determineHeaderType(
    text: String,
    fontSize: Double,
    pageIndex: Int,
    pageCount: Int
) -> (level: Int, type: HeaderType) {
    let lowerText = text.lowercased()
    
    // Check for special page types
    if pageIndex == 0 && (lowerText.contains("title") || fontSize > 24) {
        return (1, .titlePage)
    }
    
    if lowerText.contains("copyright") || lowerText.contains("©") {
        return (1, .copyrightPage)
    }
    
    if lowerText.contains("table of contents") || lowerText.contains("toc") {
        return (1, .tableOfContents)
    }
    
    if lowerText.contains("index") {
        return (1, .index)
    }
    
    if lowerText.contains("bibliography") || lowerText.contains("references") {
        return (1, .bibliography)
    }
    
    // Determine level based on font size and position
    if fontSize >= 24 {
        return (1, .chapter)
    } else if fontSize >= 18 {
        return (2, .section)
    } else if fontSize >= 14 {
        return (3, .subsection)
    } else {
        return (4, .subsubsection)
    }
}
```

#### Step 2: Enhance Document Structure Analysis
**File**: `LayoutAnalyzerCapsule.swift`

```swift
private func analyzeDocumentStructure(
    layouts: [PageLayout],
    headers: [HeaderInfo]
) throws -> DocumentStructureInfo {
    // Group headers by type
    let titlePages = headers.filter { $0.type == .titlePage }
    let copyrightPages = headers.filter { $0.type == .copyrightPage }
    let tocHeaders = headers.filter { $0.type == .tableOfContents }
    let indexHeaders = headers.filter { $0.type == .index }
    let bibliographyHeaders = headers.filter { $0.type == .bibliography }
    
    // Identify chapters and sections
    let chapters = headers.filter { $0.type == .chapter }
    let sections = headers.filter { $0.type == .section }
    let subsections = headers.filter { $0.type == .subsection }
    
    // Create section information with proper hierarchy
    var sectionInfos: [SectionInfo] = []
    
    // Add title page
    if let titlePage = titlePages.first {
        sectionInfos.append(SectionInfo(
            title: titlePage.text,
            startPage: titlePage.pageIndex,
            endPage: titlePage.pageIndex,
            level: 0,
            type: .titlePage
        ))
    }
    
    // Add copyright page
    if let copyrightPage = copyrightPages.first {
        sectionInfos.append(SectionInfo(
            title: copyrightPage.text,
            startPage: copyrightPage.pageIndex,
            endPage: copyrightPage.pageIndex,
            level: 0,
            type: .copyrightPage
        ))
    }
    
    // Add TOC
    if let toc = tocHeaders.first {
        sectionInfos.append(SectionInfo(
            title: toc.text,
            startPage: toc.pageIndex,
            endPage: toc.pageIndex,
            level: 0,
            type: .tableOfContents
        ))
    }
    
    // Add chapters
    for chapter in chapters {
        sectionInfos.append(SectionInfo(
            title: chapter.text,
            startPage: chapter.pageIndex,
            endPage: chapter.pageIndex, // Will be updated
            level: 1,
            type: .chapter
        ))
    }
    
    // Add sections
    for section in sections {
        sectionInfos.append(SectionInfo(
            title: section.text,
            startPage: section.pageIndex,
            endPage: section.pageIndex,
            level: 2,
            type: .section
        ))
    }
    
    // Add subsections
    for subsection in subsections {
        sectionInfos.append(SectionInfo(
            title: subsection.text,
            startPage: subsection.pageIndex,
            endPage: subsection.pageIndex,
            level: 3,
            type: .subsection
        ))
    }
    
    // Add index
    if let index = indexHeaders.first {
        sectionInfos.append(SectionInfo(
            title: index.text,
            startPage: index.pageIndex,
            endPage: index.pageIndex,
            level: 0,
            type: .index
        ))
    }
    
    // Add bibliography
    if let bibliography = bibliographyHeaders.first {
        sectionInfos.append(SectionInfo(
            title: bibliography.text,
            startPage: bibliography.pageIndex,
            endPage: bibliography.pageIndex,
            level: 0,
            type: .bibliography
        ))
    }
    
    return DocumentStructureInfo(
        totalPages: layouts.count,
        sections: sectionInfos,
        hasTOC: !tocHeaders.isEmpty,
        hasIndex: !indexHeaders.isEmpty,
        hasBibliography: !bibliographyHeaders.isEmpty
    )
}
```

#### Step 3: Update Data Structures
**File**: `LayoutAnalysisResult.swift`

```swift
// Add header type enumeration
public enum HeaderType: String, Codable, Hashable, Sendable {
    case titlePage
    case copyrightPage
    case tableOfContents
    case chapter
    case section
    case subsection
    case subsubsection
    case index
    case bibliography
    case colophon
    case other
}

// Update HeaderInfo to include type
public struct HeaderInfo: Codable, Hashable, Sendable {
    // ... existing properties
    public let type: HeaderType
    
    // ... existing initializer
    public init(
        text: String,
        bbox: BoundingBox,
        pageIndex: Int,
        level: Int,
        font: FontInfo? = nil,
        type: HeaderType = .other
    ) {
        // ... existing initialization
        self.type = type
    }
}

// Update SectionInfo to include type
public struct SectionInfo: Codable, Hashable, Sendable {
    // ... existing properties
    public let type: SectionType
    
    // ... existing initializer
    public init(
        title: String,
        startPage: Int,
        endPage: Int,
        level: Int,
        type: SectionType = .chapter
    ) {
        // ... existing initialization
        self.type = type
    }
}

// Add section type enumeration
public enum SectionType: String, Codable, Hashable, Sendable {
    case titlePage
    case copyrightPage
    case tableOfContents
    case chapter
    case section
    case subsection
    case subsubsection
    case index
    case bibliography
    case colophon
    case frontMatter
    case body
    case backMatter
}
```

### Success Criteria
- ✅ Detect title pages, copyright pages, TOC
- ✅ Identify chapters, sections, subsections
- ✅ Distinguish front matter, body, back matter
- ✅ Accuracy > 90% on standard book formats

## Enhancement 2: Layout-Aware Chunk Mapping

### Current State
- Chunks are normalized but not layout-aware
- No mapping between chunks and layout elements

### Required Enhancements
1. **Chunk to Layout Mapping**: Map chunks to specific layout elements
2. **Spatial Relationships**: Create relationships between chunks
3. **Element Identification**: Identify which chunks belong to headers, tables, figures

### Implementation Plan

#### Step 1: Create Chunk Layout Mapping
**File**: `LayoutAnalyzerCapsule.swift`

```swift
public func mapChunksToLayout(
    chunks: [NormalizedChunk],
    layouts: [PageLayout]
) throws -> [ChunkLayoutMapping] {
    var mappings: [ChunkLayoutMapping] = []
    
    // Create spatial index for fast lookup
    let spatialIndex = createSpatialIndex(from: layouts)
    
    for chunk in chunks {
        // Find layout elements that overlap with chunk content
        let overlappingElements = findOverlappingElements(
            for: chunk,
            in: spatialIndex
        )
        
        // Create mapping for each overlapping element
        for element in overlappingElements {
            mappings.append(ChunkLayoutMapping(
                chunkId: chunk.id,
                pageIndex: element.pageIndex,
                elementType: element.type,
                bbox: element.bbox,
                readingOrder: element.readingOrder,
                parentElementId: element.parentId
            ))
        }
    }
    
    return mappings
}

private func createSpatialIndex(from layouts: [PageLayout]) -> SpatialIndex {
    var index = SpatialIndex()
    
    for (pageIndex, layout) in layouts.enumerated() {
        // Index text segments
        for (segmentIndex, segment) in layout.segments.enumerated() {
            let elementId = "segment_\(pageIndex)_\(segmentIndex)"
            index.addElement(
                id: elementId,
                pageIndex: pageIndex,
                bbox: segment.bbox,
                type: .text,
                readingOrder: segmentIndex
            )
        }
        
        // Index tables
        for (tableIndex, tableBBox) in layout.tableBBoxes.enumerated() {
            let elementId = "table_\(pageIndex)_\(tableIndex)"
            index.addElement(
                id: elementId,
                pageIndex: pageIndex,
                bbox: tableBBox,
                type: .table,
                readingOrder: 0
            )
        }
        
        // Index figures
        for (figureIndex, figureBBox) in layout.figureBBoxes.enumerated() {
            let elementId = "figure_\(pageIndex)_\(figureIndex)"
            index.addElement(
                id: elementId,
                pageIndex: pageIndex,
                bbox: figureBBox,
                type: .figure,
                readingOrder: 0
            )
        }
    }
    
    return index
}

private func findOverlappingElements(
    for chunk: NormalizedChunk,
    in index: SpatialIndex
) -> [LayoutElement] {
    // For text chunks, find overlapping text segments
    // For table chunks, find overlapping table elements
    // For figure chunks, find overlapping figure elements
    
    // Implementation: Spatial query to find overlapping elements
    return []
}
```

#### Step 2: Create Data Structures
**File**: `LayoutAnalysisResult.swift`

```swift
/// Chunk layout mapping
public struct ChunkLayoutMapping: Codable, Hashable, Sendable {
    /// Chunk ID
    public let chunkId: String
    
    /// Page index
    public let pageIndex: Int
    
    /// Layout element type
    public let elementType: LayoutElementType
    
    /// Bounding box
    public let bbox: BoundingBox
    
    /// Reading order position
    public let readingOrder: Int
    
    /// Parent element ID
    public let parentElementId: String?
    
    /// Initialize new chunk layout mapping
    public init(
        chunkId: String,
        pageIndex: Int,
        elementType: LayoutElementType,
        bbox: BoundingBox,
        readingOrder: Int,
        parentElementId: String? = nil
    ) {
        self.chunkId = chunkId
        self.pageIndex = pageIndex
        self.elementType = elementType
        self.bbox = bbox
        self.readingOrder = readingOrder
        self.parentElementId = parentElementId
    }
}

/// Layout element type
public enum LayoutElementType: String, Codable, Hashable, Sendable {
    case text
    case header
    case footer
    case table
    case figure
    case image
    case list
    case codeBlock
    case quote
}

/// Spatial index for fast element lookup
private struct SpatialIndex {
    private var grid: UniformGrid
    private var elements: [String: LayoutElement]
    
    mutating func addElement(
        id: String,
        pageIndex: Int,
        bbox: BoundingBox,
        type: LayoutElementType,
        readingOrder: Int
    ) {
        let element = LayoutElement(
            id: id,
            pageIndex: pageIndex,
            bbox: bbox,
            type: type,
            readingOrder: readingOrder
        )
        elements[id] = element
        grid.addElement(element)
    }
    
    func query(bbox: BoundingBox) -> [LayoutElement] {
        // Query spatial index for overlapping elements
        return []
    }
}

/// Layout element
private struct LayoutElement {
    let id: String
    let pageIndex: Int
    let bbox: BoundingBox
    let type: LayoutElementType
    let readingOrder: Int
}
```

#### Step 3: Update LayoutAnalyzerCapsule API
**File**: `LayoutAnalyzerCapsule.swift`

```swift
/// Analyze source PDF and map chunks to layout elements
public func analyzeAndMap(
    data: Data,
    manifest: BookProjectManifest,
    chunks: [NormalizedChunk]
) async throws -> (LayoutAnalysisResult, [ChunkLayoutMapping], CapsuleReceipt) {
    // Analyze PDF layout
    let layouts = try layoutEngine.analyzePDF(data)
    
    // Extract layout information
    let result = try extractLayoutInformation(
        layouts: layouts,
        manifest: manifest
    )
    
    // Map chunks to layout elements
    let mappings = try mapChunksToLayout(
        chunks: chunks,
        layouts: layouts
    )
    
    // Generate receipt
    let receipt = try await generateReceipt(
        inputs: ["pdf": data],
        outputs: ["analysis": result, "mappings": mappings],
        metadata: [
            "page_count": "\(result.pageCount)",
            "header_count": "\(result.headers.count)",
            "table_count": "\(result.tables.count)",
            "mapping_count": "\(mappings.count)"
        ]
    )
    
    return (result, mappings, receipt)
}
```

### Success Criteria
- ✅ Map > 90% of chunks to layout elements
- ✅ Accurate spatial relationships
- ✅ Correct identification of element types
- ✅ Performance < 100ms for typical documents

## Enhancement 3: Enhanced Table Structure Extraction

### Current State
- Basic table bounding box detection
- No cell-level information
- No table structure analysis

### Required Enhancements
1. **Cell-Level Extraction**: Extract individual cell boundaries
2. **Header/Body Identification**: Distinguish header vs body cells
3. **Content Extraction**: Extract text content for each cell
4. **Span Detection**: Identify row/column spans

### Implementation Plan

#### Step 1: Extract Table Structures
**File**: `LayoutAnalyzerCapsule.swift`

```swift
public func extractTableStructures(
    layouts: [PageLayout]
) throws -> [TableStructure] {
    return layouts.enumerated().flatMap { (pageIndex, layout) in
        layout.tableBBoxes.enumerated().map { (tableIndex, tableBBox) in
            // Analyze table structure
            let structure = try analyzeTableStructure(
                pageIndex: pageIndex,
                tableIndex: tableIndex,
                bbox: tableBBox,
                layout: layout
            )
            return structure
        }
    }
}

private func analyzeTableStructure(
    pageIndex: Int,
    tableIndex: Int,
    bbox: BoundingBox,
    layout: PageLayout
) throws -> TableStructure {
    // Extract text segments within table bounding box
    let tableSegments = layout.segments.filter { segment in
        overlaps(bbox1: segment.bbox, bbox2: bbox)
    }
    
    // Group segments into rows
    let rows = groupSegmentsIntoRows(segments: tableSegments, tableBBox: bbox)
    
    // Group segments into columns
    let columns = groupSegmentsIntoColumns(segments: tableSegments, tableBBox: bbox)
    
    // Create cell map
    let cellMap = createCellMap(
        segments: tableSegments,
        rows: rows,
        columns: columns,
        tableBBox: bbox
    )
    
    // Detect header rows
    let headerRows = detectHeaderRows(cellMap: cellMap)
    
    return TableStructure(
        pageIndex: pageIndex,
        tableIndex: tableIndex,
        bbox: bbox,
        rows: rows,
        columns: columns,
        headerRows: headerRows,
        cellMap: cellMap
    )
}

private func overlaps(bbox1: BoundingBox, bbox2: BoundingBox) -> Bool {
    return !(bbox1.right < bbox2.left || 
            bbox1.left > bbox2.right || 
            bbox1.bottom < bbox2.top || 
            bbox1.top > bbox2.bottom)
}

private func groupSegmentsIntoRows(
    segments: [TextSegment],
    tableBBox: BoundingBox
) -> [TableRow] {
    // Group segments by vertical position (rows)
    return []
}

private func groupSegmentsIntoColumns(
    segments: [TextSegment],
    tableBBox: BoundingBox
) -> [TableColumn] {
    // Group segments by horizontal position (columns)
    return []
}

private func createCellMap(
    segments: [TextSegment],
    rows: [TableRow],
    columns: [TableColumn],
    tableBBox: BoundingBox
) -> [[TableCell]] {
    // Create 2D grid of cells
    return []
}

private func detectHeaderRows(cellMap: [[TableCell]]) -> Int {
    // Detect header rows based on font weight, position, etc.
    return 0
}
```

#### Step 2: Create Data Structures
**File**: `LayoutAnalysisResult.swift`

```swift
/// Table structure with cell-level information
public struct TableStructure: Codable, Hashable, Sendable {
    /// Page index
    public let pageIndex: Int
    
    /// Table index on page
    public let tableIndex: Int
    
    /// Bounding box
    public let bbox: BoundingBox
    
    /// Table rows
    public let rows: [TableRow]
    
    /// Table columns
    public let columns: [TableColumn]
    
    /// Number of header rows
    public let headerRows: Int
    
    /// 2D cell map
    public let cellMap: [[TableCell]]
    
    /// Initialize new table structure
    public init(
        pageIndex: Int,
        tableIndex: Int,
        bbox: BoundingBox,
        rows: [TableRow],
        columns: [TableColumn],
        headerRows: Int,
        cellMap: [[TableCell]]
    ) {
        self.pageIndex = pageIndex
        self.tableIndex = tableIndex
        self.bbox = bbox
        self.rows = rows
        self.columns = columns
        self.headerRows = headerRows
        self.cellMap = cellMap
    }
}

/// Table row
public struct TableRow: Codable, Hashable, Sendable {
    /// Row index
    public let index: Int
    
    /// Bounding box
    public let bbox: BoundingBox
    
    /// Initialize new table row
    public init(
        index: Int,
        bbox: BoundingBox
    ) {
        self.index = index
        self.bbox = bbox
    }
}

/// Table column
public struct TableColumn: Codable, Hashable, Sendable {
    /// Column index
    public let index: Int
    
    /// Bounding box
    public let bbox: BoundingBox
    
    /// Initialize new table column
    public init(
        index: Int,
        bbox: BoundingBox
    ) {
        self.index = index
        self.bbox = bbox
    }
}

/// Table cell
public struct TableCell: Codable, Hashable, Sendable {
    /// Bounding box
    public let bbox: BoundingBox
    
    /// Cell text content
    public let text: String
    
    /// Row span
    public let rowSpan: Int
    
    /// Column span
    public let colSpan: Int
    
    /// Is header cell
    public let isHeader: Bool
    
    /// Chunk references
    public let chunkReferences: [String]
    
    /// Initialize new table cell
    public init(
        bbox: BoundingBox,
        text: String,
        rowSpan: Int = 1,
        colSpan: Int = 1,
        isHeader: Bool = false,
        chunkReferences: [String] = []
    ) {
        self.bbox = bbox
        self.text = text
        self.rowSpan = rowSpan
        self.colSpan = colSpan
        self.isHeader = isHeader
        self.chunkReferences = chunkReferences
    }
}
```

#### Step 3: Update LayoutAnalysisResult
**File**: `LayoutAnalysisResult.swift`

```swift
// Update LayoutAnalysisResult to include table structures
public struct LayoutAnalysisResult: Codable, Hashable, Sendable {
    // ... existing properties
    
    /// Detected table structures
    public let tableStructures: [TableStructure]
    
    /// Initialize a new layout analysis result
    public init(
        pageCount: Int,
        headers: [HeaderInfo],
        footers: [FooterInfo],
        tables: [TableInfo],
        figures: [FigureInfo],
        readingOrder: ReadingOrderInfo,
        documentStructure: DocumentStructureInfo,
        tableStructures: [TableStructure] = []
    ) {
        // ... existing initialization
        self.tableStructures = tableStructures
    }
}
```

### Success Criteria
- ✅ Extract > 95% of table cells correctly
- ✅ Identify headers vs body cells with > 90% accuracy
- ✅ Detect row/column spans correctly
- ✅ Performance < 200ms for tables with < 100 cells

## Enhancement 4: Cross-Reference Detection

### Current State
- No cross-reference detection
- No page number identification
- No internal reference detection

### Required Enhancements
1. **Page Number Detection**: Identify page numbers in text
2. **Internal References**: Find "see page X" references
3. **Figure/Table References**: Find "Figure 1", "Table 2" references
4. **Citation Detection**: Identify citations and references

### Implementation Plan

#### Step 1: Detect Cross-References
**File**: `LayoutAnalyzerCapsule.swift`

```swift
public func detectCrossReferences(
    layouts: [PageLayout]
) throws -> [CrossReference] {
    var references: [CrossReference] = []
    
    for (pageIndex, layout) in layouts.enumerated() {
        // Detect page numbers
        let pageNumberRefs = detectPageNumbers(
            segments: layout.segments,
            pageIndex: pageIndex
        )
        references.append(contentsOf: pageNumberRefs)
        
        // Detect figure references
        let figureRefs = detectFigureReferences(
            segments: layout.segments,
            pageIndex: pageIndex
        )
        references.append(contentsOf: figureRefs)
        
        // Detect table references
        let tableRefs = detectTableReferences(
            segments: layout.segments,
            pageIndex: pageIndex
        )
        references.append(contentsOf: tableRefs)
        
        // Detect section references
        let sectionRefs = detectSectionReferences(
            segments: layout.segments,
            pageIndex: pageIndex
        )
        references.append(contentsOf: sectionRefs)
    }
    
    return references
}

private func detectPageNumbers(
    segments: [TextSegment],
    pageIndex: Int
) -> [CrossReference] {
    var references: [CrossReference] = []
    
    let pageNumberPatterns = [
        #"page \([0-9]+\)"#,
        #"p\([0-9]+\)"#,
        #"[0-9]+"# // Simple page numbers
    ]
    
    for segment in segments {
        for pattern in pageNumberPatterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(
                in: segment.text,
                range: NSRange(segment.text.startIndex..., in: segment.text)
            )
            
            for match in matches {
                if let range = Range(match.range, in: segment.text) {
                    let matchedText = String(segment.text[range])
                    
                    // Extract page number
                    let pageNumber = extractPageNumber(from: matchedText)
                    
                    if let pageNumber = pageNumber {
                        references.append(CrossReference(
                            text: matchedText,
                            bbox: segment.bbox,
                            pageIndex: pageIndex,
                            targetType: .page,
                            targetId: "page_\(pageNumber)",
                            confidence: 0.95
                        ))
                    }
                }
            }
        }
    }
    
    return references
}

private func detectFigureReferences(
    segments: [TextSegment],
    pageIndex: Int
) -> [CrossReference] {
    var references: [CrossReference] = []
    
    let figurePatterns = [
        #"figure \([0-9]+\)"#,
        #"fig\([0-9]+\)"#,
        #"figure:[0-9]+"#
    ]
    
    for segment in segments {
        for pattern in figurePatterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(
                in: segment.text,
                range: NSRange(segment.text.startIndex..., in: segment.text)
            )
            
            for match in matches {
                if let range = Range(match.range, in: segment.text) {
                    let matchedText = String(segment.text[range])
                    
                    // Extract figure number
                    let figureNumber = extractNumber(from: matchedText)
                    
                    if let figureNumber = figureNumber {
                        references.append(CrossReference(
                            text: matchedText,
                            bbox: segment.bbox,
                            pageIndex: pageIndex,
                            targetType: .figure,
                            targetId: "figure_\(figureNumber)",
                            confidence: 0.90
                        ))
                    }
                }
            }
        }
    }
    
    return references
}

private func detectTableReferences(
    segments: [TextSegment],
    pageIndex: Int
) -> [CrossReference] {
    var references: [CrossReference] = []
    
    let tablePatterns = [
        #"table \([0-9]+\)"#,
        #"tab\([0-9]+\)"#,
        #"table:[0-9]+"#
    ]
    
    for segment in segments {
        for pattern in tablePatterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(
                in: segment.text,
                range: NSRange(segment.text.startIndex..., in: segment.text)
            )
            
            for match in matches {
                if let range = Range(match.range, in: segment.text) {
                    let matchedText = String(segment.text[range])
                    
                    // Extract table number
                    let tableNumber = extractNumber(from: matchedText)
                    
                    if let tableNumber = tableNumber {
                        references.append(CrossReference(
                            text: matchedText,
                            bbox: segment.bbox,
                            pageIndex: pageIndex,
                            targetType: .table,
                            targetId: "table_\(tableNumber)",
                            confidence: 0.90
                        ))
                    }
                }
            }
        }
    }
    
    return references
}

private func detectSectionReferences(
    segments: [TextSegment],
    pageIndex: Int
) -> [CrossReference] {
    var references: [CrossReference] = []
    
    let sectionPatterns = [
        #"see section \([0-9]+\)"#,
        #"section \([0-9]+\)"#,
        #"sec\([0-9]+\)"#
    ]
    
    for segment in segments {
        for pattern in sectionPatterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(
                in: segment.text,
                range: NSRange(segment.text.startIndex..., in: segment.text)
            )
            
            for match in matches {
                if let range = Range(match.range, in: segment.text) {
                    let matchedText = String(segment.text[range])
                    
                    // Extract section number
                    let sectionNumber = extractNumber(from: matchedText)
                    
                    if let sectionNumber = sectionNumber {
                        references.append(CrossReference(
                            text: matchedText,
                            bbox: segment.bbox,
                            pageIndex: pageIndex,
                            targetType: .section,
                            targetId: "section_\(sectionNumber)",
                            confidence: 0.85
                        ))
                    }
                }
            }
        }
    }
    
    return references
}

private func extractNumber(from text: String) -> Int? {
    let numberPattern = #"[0-9]+"#
    let regex = try! NSRegularExpression(pattern: numberPattern)
    let matches = regex.matches(
        in: text,
        range: NSRange(text.startIndex..., in: text)
    )
    
    guard let match = matches.first,
          let range = Range(match.range, in: text) else {
        return nil
    }
    
    return Int(String(text[range]))
}

private func extractPageNumber(from text: String) -> Int? {
    // Extract page number from various formats
    return extractNumber(from: text)
}
```

#### Step 2: Create Data Structures
**File**: `LayoutAnalysisResult.swift`

```swift
/// Cross-reference information
public struct CrossReference: Codable, Hashable, Sendable {
    /// Reference text
    public let text: String
    
    /// Bounding box
    public let bbox: BoundingBox
    
    /// Page index where reference appears
    public let pageIndex: Int
    
    /// Target type
    public let targetType: ReferenceTargetType
    
    /// Target identifier
    public let targetId: String?
    
    /// Confidence score (0.0-1.0)
    public let confidence: Double
    
    /// Initialize new cross-reference
    public init(
        text: String,
        bbox: BoundingBox,
        pageIndex: Int,
        targetType: ReferenceTargetType,
        targetId: String? = nil,
        confidence: Double = 0.9
    ) {
        self.text = text
        self.bbox = bbox
        self.pageIndex = pageIndex
        self.targetType = targetType
        self.targetId = targetId
        self.confidence = confidence
    }
}

/// Reference target type
public enum ReferenceTargetType: String, Codable, Hashable, Sendable {
    case page
    case figure
    case table
    case section
    case chapter
    case equation
    case citation
    case url
}
```

#### Step 3: Update LayoutAnalysisResult
**File**: `LayoutAnalysisResult.swift`

```swift
// Update LayoutAnalysisResult to include cross-references
public struct LayoutAnalysisResult: Codable, Hashable, Sendable {
    // ... existing properties
    
    /// Detected cross-references
    public let crossReferences: [CrossReference]
    
    /// Initialize a new layout analysis result
    public init(
        pageCount: Int,
        headers: [HeaderInfo],
        footers: [FooterInfo],
        tables: [TableInfo],
        figures: [FigureInfo],
        readingOrder: ReadingOrderInfo,
        documentStructure: DocumentStructureInfo,
        tableStructures: [TableStructure] = [],
        crossReferences: [CrossReference] = []
    ) {
        // ... existing initialization
        self.tableStructures = tableStructures
        self.crossReferences = crossReferences
    }
}
```

### Success Criteria
- ✅ Detect > 90% of page number references
- ✅ Detect > 85% of figure/table references
- ✅ Detect > 80% of section references
- ✅ Accuracy > 90% for reference targets

## Enhancement 5: Performance Optimization

### Current State
- Good performance for typical documents
- No incremental processing
- No caching for repeated analysis

### Required Enhancements
1. **Incremental Processing**: Process documents in chunks
2. **Caching**: Cache analysis results
3. **Memory Optimization**: Reduce memory usage for large documents

### Implementation Plan

#### Step 1: Add Incremental Processing
**File**: `LayoutAnalyzerCapsule.swift`

```swift
/// Analyze PDF incrementally (page range)
public func analyzePDFIncremental(
    data: Data,
    pageRange: Range<Int>? = nil
) async throws -> [PageLayout] {
    let span = diagnostics.beginSpan(
        name: "LayoutAnalyzerCapsule.analyzePDFIncremental",
        category: "pdfexporter.layout.analyzer.analyze",
        correlationID: nil,
        tags: [
            "input_bytes": "\(data.count)",
            "page_range": "\(pageRange?.description ?? "all")",
            "algorithm_version": Self.algorithmVersion
        ]
    )
    
    do {
        // Analyze PDF with page range
        let layouts = try layoutEngine.analyzePDFIncremental(
            data: data,
            pageRange: pageRange
        )
        
        span.end(status: .ok)
        return layouts
    } catch {
        diagnostics.event(
            level: .error,
            category: "pdfexporter.layout.analyzer.analyze",
            message: "Incremental analysis failed: \(error)",
            correlationID: nil,
            tags: [:]
        )
        span.end(status: .error)
        throw error
    }
}

/// Analyze PDF with caching
public func analyzePDFWithCache(
    data: Data,
    cacheKey: String,
    cache: LayoutCache
) async throws -> (layouts: [PageLayout], cacheHit: Bool) {
    let span = diagnostics.beginSpan(
        name: "LayoutAnalyzerCapsule.analyzePDFWithCache",
        category: "pdfexporter.layout.analyzer.analyze",
        correlationID: nil,
        tags: [
            "input_bytes": "\(data.count)",
            "cache_key": cacheKey,
            "algorithm_version": Self.algorithmVersion
        ]
    )
    
    do {
        // Check cache first
        if let cached = try cache.lookup(key: cacheKey) {
            diagnostics.event(
                level: .info,
                category: "pdfexporter.layout.analyzer.analyze",
                message: "Cache hit for layout analysis",
                correlationID: nil,
                tags: ["cache_key": cacheKey]
            )
            span.end(status: .ok)
            return (cached, true)
        }
        
        // Analyze PDF
        let layouts = try layoutEngine.analyzePDF(data)
        
        // Store in cache
        try cache.store(key: cacheKey, layouts: layouts)
        
        diagnostics.event(
            level: .info,
            category: "pdfexporter.layout.analyzer.analyze",
            message: "Cache miss, stored layout analysis",
            correlationID: nil,
            tags: ["cache_key": cacheKey]
        )
        
        span.end(status: .ok)
        return (layouts, false)
    } catch {
        diagnostics.event(
            level: .error,
            category: "pdfexporter.layout.analyzer.analyze",
            message: "Cached analysis failed: \(error)",
            correlationID: nil,
            tags: [:]
        )
        span.end(status: .error)
        throw error
    }
}
```

#### Step 2: Create Cache Interface
**File**: `LayoutAnalysisResult.swift`

```swift
/// Layout cache interface
public protocol LayoutCache {
    /// Lookup cached layouts
    ///
    /// - Parameter key: Cache key
    /// - Returns: Cached layouts or nil if not found
    /// - Throws: If lookup fails
    func lookup(key: String) throws -> [PageLayout]?
    
    /// Store layouts in cache
    ///
    /// - Parameters:
    ///   - key: Cache key
    ///   - layouts: Layouts to store
    /// - Throws: If storage fails
    func store(key: String, layouts: [PageLayout]) throws
    
    /// Remove cached layouts
    ///
    /// - Parameter key: Cache key
    /// - Throws: If removal fails
    func remove(key: String) throws
    
    /// Clear cache
    ///
    /// - Throws: If clear fails
    func clear() throws
}

/// In-memory layout cache
public struct InMemoryLayoutCache: LayoutCache {
    private var cache: [String: [PageLayout]]
    private let maxSize: Int
    private var accessOrder: [String]
    
    /// Initialize new in-memory cache
    ///
    /// - Parameter maxSize: Maximum number of entries
    public init(maxSize: Int = 100) {
        self.cache = [:]
        self.maxSize = maxSize
        self.accessOrder = []
    }
    
    public func lookup(key: String) throws -> [PageLayout]? {
        guard let layouts = cache[key] else { return nil }
        
        // Update access order
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        
        return layouts
    }
    
    public func store(key: String, layouts: [PageLayout]) throws {
        // Remove if already exists
        if cache[key] != nil {
            accessOrder.removeAll { $0 == key }
        }
        
        // Add to cache
        cache[key] = layouts
        accessOrder.append(key)
        
        // Enforce size limit
        if accessOrder.count > maxSize {
            let oldestKey = accessOrder.removeFirst()
            cache.removeValue(forKey: oldestKey)
        }
    }
    
    public func remove(key: String) throws {
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }
    
    public func clear() throws {
        cache.removeAll()
        accessOrder.removeAll()
    }
}

/// Disk-based layout cache
public struct DiskLayoutCache: LayoutCache {
    private let storageDirectory: URL
    private let maxSize: Int
    
    /// Initialize new disk-based cache
    ///
    /// - Parameters:
    ///   - storageDirectory: Directory for cache storage
    ///   - maxSize: Maximum number of entries
    public init(
        storageDirectory: URL,
        maxSize: Int = 100
    ) throws {
        self.storageDirectory = storageDirectory
        self.maxSize = maxSize
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    public func lookup(key: String) throws -> [PageLayout]? {
        let fileURL = storageDirectory.appendingPathComponent("layout_\(key).cache")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let layouts = try JSONDecoder().decode([PageLayout].self, from: data)
        
        return layouts
    }
    
    public func store(key: String, layouts: [PageLayout]) throws {
        let fileURL = storageDirectory.appendingPathComponent("layout_\(key).cache")
        let data = try JSONEncoder().encode(layouts)
        try data.write(to: fileURL)
    }
    
    public func remove(key: String) throws {
        let fileURL = storageDirectory.appendingPathComponent("layout_\(key).cache")
        try FileManager.default.removeItem(at: fileURL)
    }
    
    public func clear() throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: []
        )
        
        for fileURL in contents {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
```

### Success Criteria
- ✅ Incremental processing works for page ranges
- ✅ Cache hit rate > 80% for repeated analysis
- ✅ Memory usage < 512MB for 1000-page documents
- ✅ Disk cache works correctly

## Implementation Timeline

### Phase 1: Document Structure Analysis (1 week)
- ✅ Enhance header analysis
- ✅ Improve document structure detection
- ✅ Update data structures
- ✅ Test with various book formats

### Phase 2: Layout-Aware Chunk Mapping (1 week)
- ✅ Create spatial index
- ✅ Implement chunk mapping
- ✅ Create data structures
- ✅ Test mapping accuracy

### Phase 3: Enhanced Table Extraction (1 week)
- ✅ Extract cell boundaries
- ✅ Identify headers/body
- ✅ Detect spans
- ✅ Test with various tables

### Phase 4: Cross-Reference Detection (1 week)
- ✅ Detect page numbers
- ✅ Detect figure/table references
- ✅ Detect section references
- ✅ Test with various references

### Phase 5: Performance Optimization (1 week)
- ✅ Implement incremental processing
- ✅ Create cache interfaces
- ✅ Test performance improvements
- ✅ Validate memory usage

**Total**: 5 weeks

## Success Metrics

### Quantitative Metrics
- ✅ **Document Structure Accuracy**: > 90% for standard formats
- ✅ **Chunk Mapping Accuracy**: > 90% of chunks mapped correctly
- ✅ **Table Extraction Accuracy**: > 95% of cells extracted correctly
- ✅ **Cross-Reference Detection**: > 90% of references detected
- ✅ **Performance**: < 5s for 100-page documents
- ✅ **Memory Usage**: < 1GB for large documents
- ✅ **Cache Hit Rate**: > 80% for repeated analysis

### Qualitative Metrics
- ✅ **Determinism**: Same inputs always produce same outputs
- ✅ **Safety**: No memory safety violations
- ✅ **Governance**: Complete audit trail for all operations
- ✅ **Maintainability**: Clear separation of concerns

## Conclusion

These minor enhancements will significantly improve the PDF Exporter's capabilities while maintaining the high standards of the Anigma platform. The enhancements enable:

1. **Advanced Document Understanding**: Automatic structure detection and analysis
2. **Precise Content Placement**: Layout-aware chunk mapping for better PDF quality
3. **Table Support**: Detailed table extraction with cell-level information
4. **Reference Handling**: Automatic cross-reference detection and generation
5. **Performance**: Optimized processing for large documents

The implementation plan provides a clear roadmap for completing these enhancements in 5 weeks, resulting in a production-ready PDF Exporter with advanced capabilities.
