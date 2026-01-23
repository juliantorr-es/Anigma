# Enhanced Layout Engine Capsule - Advanced Document Processing Features

## Overview

The Layout Engine Capsule has been significantly enhanced with advanced document intelligence capabilities including OCR integration, font analysis, layout classification, and multi-page document structure analysis. This document describes the new features, implementation details, and usage examples.

## New Features

### 1. OCR Integration (Tesseract)

**Purpose**: Extract text from images and non-text regions within PDF documents.

**Implementation**:
- Integration with Tesseract OCR engine via C++ wrapper
- Multi-language support with ISO 639-3 language codes
- Confidence scoring for each OCR result
- Word-level text extraction with bounding boxes

**API**:
```swift
// Perform OCR on a specific page
try wrapper.performOCR(pageIndex: 0, language: "eng")

// Get OCR results
let ocrResults = try wrapper.getOCRResults(pageIndex: 0)

// Validate OCR accuracy
let accuracy = try wrapper.validateOCRAccuracy(
    pageIndex: 0, 
    groundTruthText: "Expected text"
)
```

**Data Structure**:
```swift
public struct OCRResult: Sendable {
    public var bbox: BoundingBox
    public var text: String
    public var confidence: Double        // 0.0 - 1.0
    public var language: String        // ISO 639-3 code
    public var wordCount: UInt32
}
```

**Configuration**:
```swift
var config = LayoutEngineConfig.default
config.enableOCR = true
```

### 2. Advanced Font Analysis

**Purpose**: Comprehensive font family detection, style classification, and typographic analysis.

**Features**:
- Font family detection with fallback mapping
- Subfamily identification (Bold, Italic, etc.)
- Weight calculation (100-900 scale)
- Serif/Monospace classification
- X-height and cap-height analysis
- Contrast ratio calculation

**API**:
```swift
// Perform advanced font analysis
try wrapper.analyzeFonts(pageIndex: 0)

// Font analysis is embedded in layout elements
let elements = try wrapper.getLayoutElements(pageIndex: 0)
for element in elements {
    let font = element.font
    print("Font: \(font.family) \(font.subfamily)")
    print("Size: \(font.size)pt, Weight: \(font.weight)")
    print("Serif: \(font.serif), Monospace: \(font.monospace)")
}
```

**Data Structure**:
```swift
public struct FontAnalysis: Sendable {
    public var family: String          // "Times New Roman", "Arial", etc.
    public var subfamily: String       // "Bold", "Italic", "Bold Italic"
    public var size: Double           // Font size in points
    public var weight: UInt32         // 100-900 (CSS font-weight scale)
    public var italic: Bool           // Italic detection
    public var bold: Bool             // Bold detection
    public var monospace: Bool        // Monospace font detection
    public var serif: Bool            // Serif font detection
    public var styleFlags: UInt32     // Raw font flags
    public var xHeight: Double        // X-height ratio
    public var capHeight: Double      // Cap-height ratio
    public var colorRGB: UInt32       // RGB color value
    public var contrastRatio: Double   // Contrast with background
}
```

### 3. Layout Classification

**Purpose**: Semantic classification of document elements into meaningful types.

**Element Types**:
- **Headers**: Large text at top of pages/sections
- **Paragraphs**: Regular body text
- **List Items**: Bulleted or numbered lists
- **Table Cells**: Content within table structures
- **Captions**: Text associated with figures/tables
- **Footers**: Page numbers, copyright notices
- **Sidebars**: Peripheral content
- **Quotes**: Block quotes or extracted text
- **Code Blocks**: Monospace formatted text

**Classification Algorithm**:
- Position-based heuristics (headers at top, footers at bottom)
- Font size and weight analysis
- Pattern recognition (lists, code blocks)
- Layout context (proximity to other elements)

**API**:
```swift
// Classify layout elements
try wrapper.classifyLayout(pageIndex: 0)

// Get classified elements
let elements = try wrapper.getLayoutElements(pageIndex: 0)

// Process elements by type
let headers = elements.filter { $0.type == .header }
let paragraphs = elements.filter { $0.type == .paragraph }
let codeBlocks = elements.filter { $0.type == .codeBlock }

for element in headers {
    print("Header: \(element.text) (confidence: \(element.confidence))")
}
```

**Data Structure**:
```swift
public struct LayoutElement: Sendable {
    public var bbox: BoundingBox
    public var type: LayoutElementType
    public var text: String
    public var confidence: Double        // Classification confidence
    public var readingOrder: UInt32      // Reading order position
    public var font: FontAnalysis       // Font information
    public var elementId: UInt32        // Unique ID
    public var parentId: UInt32         // Parent element ID
    public var level: UInt32            // Hierarchy level
}
```

### 4. Reading Order Detection

**Purpose**: Determine natural reading flow for complex multi-column layouts.

**Algorithm**:
- Primary sorting by Y-coordinate (top to bottom)
- Secondary sorting by X-coordinate within same row
- Column detection and break identification
- Confidence scoring based on spacing consistency

**API**:
```swift
// Detect reading order
try wrapper.detectReadingOrder(pageIndex: 0)

// Get reading order information
let order = try wrapper.getReadingOrder(pageIndex: 0)

// Process elements in reading order
for (index, elementId) in order.elementIds.enumerated() {
    let confidence = order.confidenceScores[index]
    print("Element \(elementId): confidence \(confidence)")
}
```

**Data Structure**:
```swift
public struct ReadingOrder: Sendable {
    public var elementIds: [UInt32]        // Elements in reading order
    public var confidenceScores: [Double]   // Confidence for each ordering
    public var columnBreaks: [UInt32]      // Column break indices
}
```

### 5. Multi-Page Document Structure Analysis

**Purpose**: Analyze document structure across all pages to identify sections, hierarchy, and special content.

**Features**:
- Section detection based on headers
- Table of contents identification
- Index and bibliography detection
- Document hierarchy construction
- Page-by-page element counting

**API**:
```swift
// Analyze document structure
let structure = try wrapper.analyzeDocumentStructure()

// Access document information
print("Total pages: \(structure.totalPages)")
print("Sections: \(structure.sectionCount)")

for (index, title) in structure.sectionTitles.enumerated() {
    let startPage = structure.sectionStartPages[index]
    let elementCount = structure.elementCounts[index]
    print("Section \(index + 1): '\(title)' starting at page \(startPage) with \(elementCount) elements")
}

// Check for special document features
if structure.hasTOC {
    print("Document contains table of contents")
}
```

**Data Structure**:
```swift
public struct DocumentStructure: Sendable {
    public var totalPages: UInt32
    public var sectionCount: UInt32
    public var sectionTitles: [String]
    public var sectionStartPages: [UInt32]
    public var elementCounts: [UInt32]
    public var hasTOC: Bool
    public var hasIndex: Bool
    public var hasBibliography: Bool
}
```

## Configuration

### Advanced Feature Flags

All advanced features are controlled via configuration flags:

```swift
public struct LayoutEngineConfig: Sendable {
    // Advanced feature flags
    public var enableOCR: Bool
    public var advancedFontAnalysis: Bool
    public var layoutClassification: Bool
    public var readingOrderDetection: Bool
    public var multiPageAnalysis: Bool
    
    // Convenience initializer
    public init(
        extractFontMetrics: Bool = false,
        detectTables: Bool = true,
        detectFigures: Bool = true,
        extractImages: Bool = false,
        enableProfiling: Bool = false,
        preserveCaches: Bool = false,
        enableOCR: Bool = false,
        advancedFontAnalysis: Bool = false,
        layoutClassification: Bool = false,
        readingOrderDetection: Bool = false,
        multiPageAnalysis: Bool = false
    )
}
```

### Determinism Tiers

- **Tier 1**: Receipt-grade deterministic output (existing features)
- **Tier 2**: Canonical boundary with ML-based features (new advanced features)

## Performance Considerations

### Memory Management

- Automatic cleanup of OCR engine resources
- Font name caching across pages to reduce allocations
- Text interning to minimize duplicate strings
- Proper cleanup of all C-allocated memory

### Performance Targets

| Operation | Target | Notes |
|------------|---------|--------|
| OCR Processing | < 100ms/page | Depends on image complexity |
| Font Analysis | < 20ms/page | Cached font families |
| Layout Classification | < 50ms/page | Heuristic-based |
| Reading Order Detection | < 10ms/page | Spatial sorting |
| Document Structure Analysis | < 200ms | Multi-page analysis |
| Total Analysis | < 5s (100 pages) | Including all features |

### Memory Usage

| Feature | Memory Impact | Optimization |
|---------|----------------|---------------|
| OCR | High (image processing) | Page-by-page processing |
| Font Analysis | Low (caching) | Shared font name cache |
| Layout Classification | Low | Temporary structures |
| Reading Order | Low | Sorting algorithm |
| Document Structure | Medium | Depends on document size |

## Usage Examples

### Basic Workflow

```swift
// 1. Create configuration with advanced features
let config = LayoutEngineConfig(
    enableOCR: true,
    advancedFontAnalysis: true,
    layoutClassification: true,
    readingOrderDetection: true,
    multiPageAnalysis: true
)

// 2. Create capsule wrapper
let wrapper = try LayoutEngineCapsuleWrapper(config: config)

// 3. Analyze PDF
let pdfData = try Data(contentsOf: pdfURL)
let layouts = try wrapper.analyzePDF(pdfData)

// 4. Process each page with advanced features
for (pageIndex, _) in layouts.enumerated() {
    // OCR analysis
    try wrapper.performOCR(pageIndex: UInt32(pageIndex), language: "eng")
    let ocrResults = try wrapper.getOCRResults(pageIndex: UInt32(pageIndex))
    
    // Font and layout analysis
    try wrapper.analyzeFonts(pageIndex: UInt32(pageIndex))
    try wrapper.classifyLayout(pageIndex: UInt32(pageIndex))
    let elements = try wrapper.getLayoutElements(pageIndex: UInt32(pageIndex))
    
    // Reading order
    try wrapper.detectReadingOrder(pageIndex: UInt32(pageIndex))
    let readingOrder = try wrapper.getReadingOrder(pageIndex: UInt32(pageIndex))
    
    // Process results...
}
```

### Document Structure Analysis

```swift
// Analyze overall document structure
let structure = try wrapper.analyzeDocumentStructure()

// Build document outline
var outline: [String] = []
for (index, title) in structure.sectionTitles.enumerated() {
    let startPage = structure.sectionStartPages[index]
    outline.append("\(title) (page \(startPage + 1))")
}

print("Document Outline:")
outline.forEach { print("  • \($0)") }
```

### Content Extraction by Type

```swift
// Extract all headers from document
var allHeaders: [String] = []
for pageIndex in 0..<layouts.count {
    let elements = try wrapper.getLayoutElements(pageIndex: UInt32(pageIndex))
    let headers = elements.filter { $0.type == .header }
        .sorted { $0.readingOrder < $1.readingOrder }
    
    for header in headers {
        allHeaders.append(header.text)
    }
}

print("Document Headers:")
allHeaders.forEach { print("  \($0)") }
```

## Testing and Validation

### Test Coverage

- **Unit Tests**: Individual feature testing
- **Integration Tests**: Complete workflow testing
- **Performance Tests**: Timing and memory validation
- **Accuracy Tests**: OCR and classification validation
- **Memory Leak Tests**: Resource cleanup verification

### Validation Data

- **OCR Accuracy**: Character and word-level accuracy testing
- **Classification Accuracy**: Manual annotation comparison
- **Reading Order**: Human verification of complex layouts
- **Font Analysis**: Font database validation

### Benchmark Suite

The `AdvancedLayoutBenchmark.swift` tool provides comprehensive performance testing:

```bash
# Run benchmark suite
swift AdvancedLayoutBenchmark.swift

# Expected output includes:
# - Processing times per feature
# - Accuracy metrics
# - Memory usage statistics
# - Comparison against targets
```

## Error Handling

### Common Error Scenarios

1. **OCR Not Enabled**: 
   ```swift
   CapsuleError.invalidState("OCR not enabled in configuration")
   ```

2. **Invalid Page Index**:
   ```swift
   CapsuleError.invalidArg("Page index out of range")
   ```

3. **OCR Engine Failure**:
   ```swift
   CapsuleError.internal("Failed to initialize OCR engine")
   ```

4. **Memory Allocation**:
   ```swift
   CapsuleError.internal("Failed to allocate analysis state")
   ```

### Error Recovery

- Graceful degradation when features fail
- Fallback to basic text extraction
- Detailed error messages for debugging
- Automatic resource cleanup on errors

## Integration Considerations

### Thread Safety

- Actor-based Swift wrapper for thread safety
- PDFium thread safety considerations
- OCR engine isolation per page
- Mutex protection for shared caches

### Backward Compatibility

- All existing APIs remain unchanged
- New features are opt-in via configuration
- Existing data structures preserved
- No breaking changes to current clients

### Memory Management

- RAII pattern in C++ implementation
- Automatic cleanup in Swift deinit
- No manual memory management required
- Proper exception safety

## Future Enhancements

### Potential Improvements

1. **ML-Based Classification**: Replace heuristics with ML models
2. **Handwriting OCR**: Support for scanned handwritten documents
3. **Table Structure Extraction**: Detailed cell content analysis
4. **Cross-Document References**: Citation and link detection
5. **Language Detection**: Automatic language identification

### Extension Points

- Custom classification rules
- Additional font database support
- Pluggable OCR engines
- Custom layout analyzers

## Conclusion

The enhanced Layout Engine Capsule provides comprehensive document intelligence capabilities while maintaining the performance and determinism characteristics of the original implementation. The modular design allows for selective feature adoption and easy integration into existing workflows.

All advanced features are production-ready with:
- ✅ Comprehensive error handling
- ✅ Memory safety guarantees
- ✅ Thread safety
- ✅ Performance optimization
- ✅ Extensive test coverage
- ✅ Documentation and examples

The capsule is now capable of handling complex document analysis tasks including OCR text extraction, semantic layout understanding, and multi-page document structure analysis.