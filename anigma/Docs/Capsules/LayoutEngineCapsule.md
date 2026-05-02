# LayoutEngineCapsule Specification

**Date**: 2026-01-13  
**Author**: opencode  
**Status**: Draft  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Priority**: High  
**Dependencies**: CPDFium (already integrated), PDFium library

## 1. Overview

The LayoutEngineCapsule extracts structured layout information from PDF documents, including text with bounding boxes, font metrics, layout hierarchy (columns, paragraphs, tables, figures), and spatial indexing for fast region queries. It extends the existing CPDFium wrapper to provide advanced layout analysis beyond raw text extraction.

## 2. Requirements

### 2.1 Functional Requirements

1. **Text extraction with geometry**:
   - Extract text characters with individual bounding boxes (x, y, width, height)
   - Extract font information (family, size, weight, style)
   - Extract color information (fill, stroke)
   - Preserve reading order

2. **Layout hierarchy construction**:
   - Detect text blocks (paragraphs)
   - Detect columns and multi‑column layouts
   - Detect tables (grid structure)
   - Detect figures and captions
   - Generate hierarchical representation (document → pages → columns → blocks → lines → words → characters)

3. **Spatial indexing**:
   - Build R‑tree or uniform grid index for fast spatial queries
   - Support region queries (e.g., "find all text in this rectangle")
   - Support nearest‑neighbor queries

4. **Output formats**:
   - Canonical binary format for receipt generation
   - JSON‑like structured output for Swift consumption
   - Support for incremental extraction (streaming page‑by‑page)

### 2.2 Non‑Functional Requirements

1. **Performance**: 5–10× speedup vs. Swift‑side post‑processing
2. **Memory**: Bounded memory usage (configurable working set)
3. **Determinism**: Tier 1 – bitwise identical output across runs with same input
4. **Thread safety**: Capsule must be thread‑safe for concurrent page processing
5. **Error handling**: Graceful degradation for malformed PDFs

## 3. C API Design

### 3.1 Header File Draft (`anigma_layout_engine_capsule.h`)

```c
#ifndef ANIGMA_LAYOUT_ENGINE_CAPSULE_H
#define ANIGMA_LAYOUT_ENGINE_CAPSULE_H

#include "anigma_capsule_core.h"
#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Layout Engine Capsule Types
// ============================================================================

typedef anigma_capsule_handle_t anigma_layout_engine_capsule_t;

// Configuration structure
struct anigma_layout_engine_config_t {
    uint32_t determinism_tier;           // ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    uint8_t extract_font_metrics;        // Whether to extract font information
    uint8_t extract_color;               // Whether to extract color information
    uint8_t detect_tables;               // Whether to perform table detection
    uint8_t detect_figures;              // Whether to perform figure detection
    uint32_t max_memory_mb;              // Maximum working memory in MB
    uint32_t spatial_index_type;         // 0 = none, 1 = uniform grid, 2 = R‑tree
    uint32_t grid_cell_size;             // Cell size for uniform grid (pixels)
    uint32_t rtree_node_capacity;        // Node capacity for R‑tree
};

// Bounding box (points in PDF coordinate system)
struct anigma_bbox_t {
    double x;       // Left
    double y;       // Bottom (PDF coordinate system: origin at bottom‑left)
    double width;
    double height;
};

// Font information
struct anigma_font_info_t {
    const char* family;     // Font family name (UTF‑8, null‑terminated)
    double size;            // Font size in points
    uint32_t weight;        // Font weight (100‑900, 400 = normal)
    uint8_t italic;         // 1 if italic
    uint8_t bold;           // 1 if bold (derived from weight)
    uint8_t monospace;      // 1 if monospace font
    uint32_t color;         // RGB color (0xRRGGBB)
};

// Text character with full metadata
struct anigma_text_char_t {
    uint32_t unicode;       // Unicode code point
    struct anigma_bbox_t bbox;
    struct anigma_font_info_t font;
    uint64_t char_index;    // Sequential index in text stream
};

// Text line
struct anigma_text_line_t {
    struct anigma_bbox_t bbox;
    uint64_t start_char_index;
    uint64_t char_count;
    double baseline_y;      // Baseline Y coordinate
};

// Text block (paragraph)
struct anigma_text_block_t {
    struct anigma_bbox_t bbox;
    uint64_t start_line_index;
    uint64_t line_count;
    uint32_t column_index;  // Which column this block belongs to
    uint8_t is_header;      // 1 if likely header/footer
    uint8_t is_caption;     // 1 if likely figure/table caption
};

// Table cell
struct anigma_table_cell_t {
    struct anigma_bbox_t bbox;
    uint32_t row;
    uint32_t col;
    uint32_t row_span;
    uint32_t col_span;
    uint64_t start_char_index;
    uint64_t char_count;
};

// Table structure
struct anigma_table_t {
    struct anigma_bbox_t bbox;
    uint32_t row_count;
    uint32_t col_count;
    uint64_t start_cell_index;
    uint64_t cell_count;
    uint8_t has_borders;    // 1 if borders detected
};

// Figure/Image region
struct anigma_figure_t {
    struct anigma_bbox_t bbox;
    uint32_t type;          // 0 = unknown, 1 = image, 2 = drawing, 3 = chart
    const char* caption;    // Associated caption text (UTF‑8, null‑terminated)
};

// Page layout result
struct anigma_page_layout_t {
    uint32_t page_number;   // 1‑based page number
    struct anigma_bbox_t mediabox;
    uint64_t char_count;
    uint64_t line_count;
    uint64_t block_count;
    uint64_t column_count;
    uint64_t table_count;
    uint64_t figure_count;
    // All arrays are stored in separate buffers
};

// Complete document layout result
struct anigma_document_layout_t {
    uint32_t page_count;
    uint64_t total_char_count;
    uint64_t total_line_count;
    uint64_t total_block_count;
    uint64_t total_table_count;
    uint64_t total_figure_count;
    // Page results array
    struct anigma_page_layout_t* pages;
};

// Spatial query result
struct anigma_spatial_query_result_t {
    uint64_t* char_indices;     // Array of character indices within query region
    size_t char_count;
    uint64_t* line_indices;     // Array of line indices
    size_t line_count;
    uint64_t* block_indices;    // Array of block indices
    size_t block_count;
};

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get layout engine capsule identity.
 */
anigma_capsule_identity_t anigma_layout_engine_capsule_get_identity(void);

/**
 * Create a layout engine capsule context with given configuration.
 */
anigma_status_t anigma_layout_engine_capsule_create(
    const struct anigma_layout_engine_config_t* config,
    anigma_layout_engine_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a layout engine capsule context.
 */
anigma_status_t anigma_layout_engine_capsule_destroy(
    anigma_layout_engine_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// PDF Processing Functions
// ============================================================================

/**
 * Load PDF document from memory buffer.
 * This parses the PDF and prepares for layout analysis.
 */
anigma_status_t anigma_layout_engine_capsule_load_pdf(
    anigma_layout_engine_capsule_t handle,
    const uint8_t* pdf_data,
    size_t pdf_data_len,
    anigma_capsule_error_t* err
);

/**
 * Process a specific page for layout analysis.
 * Can be called multiple times for different pages.
 */
anigma_status_t anigma_layout_engine_capsule_process_page(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_number,  // 1‑based
    anigma_capsule_error_t* err
);

/**
 * Process all pages in the loaded document.
 */
anigma_status_t anigma_layout_engine_capsule_process_all_pages(
    anigma_layout_engine_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Result Retrieval Functions (Two-Phase Buffer Fill)
// ============================================================================

/**
 * Get the complete document layout result.
 * Uses two‑phase buffer fill pattern.
 * 
 * Phase 1: Call with out_layout = NULL to get required size (in err->aux)
 * Phase 2: Allocate buffer and call again
 */
anigma_status_t anigma_layout_engine_capsule_get_document_layout(
    anigma_layout_engine_capsule_t handle,
    struct anigma_document_layout_t* out_layout,
    size_t max_pages,
    size_t* out_actual_pages,
    anigma_capsule_error_t* err
);

/**
 * Get text characters for a specific page.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_layout_engine_capsule_get_page_chars(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_number,
    struct anigma_text_char_t* out_chars,
    size_t max_chars,
    size_t* out_actual_chars,
    anigma_capsule_error_t* err
);

/**
 * Get text lines for a specific page.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_layout_engine_capsule_get_page_lines(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_number,
    struct anigma_text_line_t* out_lines,
    size_t max_lines,
    size_t* out_actual_lines,
    anigma_capsule_error_t* err
);

/**
 * Get text blocks (paragraphs) for a specific page.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_layout_engine_capsule_get_page_blocks(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_number,
    struct anigma_text_block_t* out_blocks,
    size_t max_blocks,
    size_t* out_actual_blocks,
    anigma_capsule_error_t* err
);

/**
 * Get tables for a specific page.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_layout_engine_capsule_get_page_tables(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_number,
    struct anigma_table_t* out_tables,
    size_t max_tables,
    size_t* out_actual_tables,
    anigma_capsule_error_t* err
);

/**
 * Get figures for a specific page.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_layout_engine_capsule_get_page_figures(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_number,
    struct anigma_figure_t* out_figures,
    size_t max_figures,
    size_t* out_actual_figures,
    anigma_capsule_error_t* err
);

// ============================================================================
// Spatial Query Functions
// ============================================================================

/**
 * Query characters within a rectangular region.
 * Returns indices of characters whose bounding boxes intersect the query region.
 */
anigma_status_t anigma_layout_engine_capsule_query_chars_in_region(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_number,
    const struct anigma_bbox_t* region,
    struct anigma_spatial_query_result_t* out_result,
    anigma_capsule_error_t* err
);

/**
 * Find the nearest text block to a point.
 */
anigma_status_t anigma_layout_engine_capsule_find_nearest_block(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_number,
    double x,
    double y,
    uint64_t* out_block_index,
    anigma_capsule_error_t* err
);

// ============================================================================
// Configuration and Utility Functions
// ============================================================================

/**
 * Get default configuration.
 */
struct anigma_layout_engine_config_t anigma_layout_engine_capsule_get_default_config(void);

/**
 * Validate configuration parameters.
 */
anigma_status_t anigma_layout_engine_capsule_validate_config(
    const struct anigma_layout_engine_config_t* config,
    anigma_capsule_error_t* err
);

/**
 * Estimate memory usage for processing a document.
 */
anigma_status_t anigma_layout_engine_capsule_estimate_memory(
    anigma_layout_engine_capsule_t handle,
    size_t* out_estimate_bytes,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_LAYOUT_ENGINE_CAPSULE_H
```

## 4. Swift Wrapper Interface

### 4.1 Swift Actor Wrapper (`LayoutEngineCapsuleWrapper.swift`)

```swift
import Foundation
import AnigmaNativeShims
import CapsuleCore

public actor LayoutEngineCapsuleWrapper {
    public static var identity: anigma_capsule_identity_t {
        anigma_layout_engine_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let config: LayoutEngineConfig
    private var documentLoaded: Bool = false
    
    public init(config: LayoutEngineConfig? = nil) throws {
        let config = config ?? LayoutEngineConfig.default
        var rawHandle: anigma_layout_engine_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = config.toCStruct()
        let status = anigma_layout_engine_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_layout_engine_capsule_destroy
        )
        self.config = config
    }
    
    deinit {
        handle?.invalidate()
    }
    
    public func loadPDF(_ data: Data) throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = data.withUnsafeBytes { bytes in
                anigma_layout_engine_capsule_load_pdf(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        documentLoaded = true
    }
    
    public func processPage(_ pageNumber: Int) throws -> PageLayout {
        guard documentLoaded else {
            throw CapsuleError.invalidState("PDF not loaded")
        }
        
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_layout_engine_capsule_process_page(
                rawHandle,
                UInt32(pageNumber),
                &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return try getPageLayout(pageNumber)
    }
    
    public func processAllPages() throws -> DocumentLayout {
        guard documentLoaded else {
            throw CapsuleError.invalidState("PDF not loaded")
        }
        
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_layout_engine_capsule_process_all_pages(
                rawHandle,
                &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return try getDocumentLayout()
    }
    
    // Additional methods for retrieving characters, lines, blocks, tables, figures
    // Spatial query methods
    // Memory estimation methods
}

// Swift data structures mirroring C structs
public struct LayoutEngineConfig: Sendable {
    public var determinismTier: UInt32
    public var extractFontMetrics: Bool
    public var extractColor: Bool
    public var detectTables: Bool
    public var detectFigures: Bool
    public var maxMemoryMB: UInt32
    public var spatialIndexType: SpatialIndexType
    public var gridCellSize: UInt32
    public var rtreeNodeCapacity: UInt32
    
    public enum SpatialIndexType: UInt32 {
        case none = 0
        case uniformGrid = 1
        case rtree = 2
    }
    
    public static var `default`: LayoutEngineConfig {
        let cConfig = anigma_layout_engine_capsule_get_default_config()
        return LayoutEngineConfig(from: cConfig)
    }
    
    // Conversion methods to/from C struct
}

public struct BoundingBox: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
}

public struct FontInfo: Sendable {
    public var family: String
    public var size: Double
    public var weight: UInt32
    public var italic: Bool
    public var bold: Bool
    public var monospace: Bool
    public var color: UInt32
}

public struct TextCharacter: Sendable {
    public var unicode: UnicodeScalar
    public var bbox: BoundingBox
    public var font: FontInfo
    public var charIndex: UInt64
}

public struct PageLayout: Sendable {
    public var pageNumber: Int
    public var mediabox: BoundingBox
    public var characters: [TextCharacter]
    public var lines: [TextLine]
    public var blocks: [TextBlock]
    public var columns: [Column]
    public var tables: [Table]
    public var figures: [Figure]
}

public struct DocumentLayout: Sendable {
    public var pages: [PageLayout]
    public var totalCharacterCount: Int
    public var totalTableCount: Int
    public var totalFigureCount: Int
}
```

## 5. Performance Requirements

| Operation | Target Performance | Measurement |
|-----------|-------------------|-------------|
| PDF loading (10 MB) | < 500 ms | Time from `loadPDF` to ready |
| Page processing (typical academic paper) | < 100 ms/page | Time for `processPage` |
| Full document (100 pages) | < 5 s | Time for `processAllPages` |
| Spatial query (region) | < 1 ms | Time for `queryCharsInRegion` |
| Memory usage (100 pages) | < 500 MB | Peak memory during processing |

**Speedup target**: 5–10× vs. current Swift‑side post‑processing for layout analysis.

## 6. Determinism Requirements

**Tier 1 (Receipt‑grade)**: Output must be bitwise identical across:
- Different runs on same machine
- Different machines (x86‑64, ARM64)
- Different operating systems (macOS, Linux)
- Different PDFium library versions (within same major version)

**Validation procedure**:
1. Maintain golden corpus of 100 diverse PDFs (academic papers, forms, magazines, etc.)
2. Compute SHA‑256 hash of canonical binary output for each PDF
3. Store hashes in version‑controlled file
4. CI pipeline must reproduce identical hashes
5. Any drift triggers investigation and approval

## 7. Integration Example

```swift
// Example: Extract structured content from PDF
let pdfData = try Data(contentsOf: pdfURL)
let config = LayoutEngineConfig(
    detectTables: true,
    detectFigures: true,
    spatialIndexType: .rtree
)

let capsule = try LayoutEngineCapsuleWrapper(config: config)
try capsule.loadPDF(pdfData)
let documentLayout = try capsule.processAllPages()

// Access extracted content
for page in documentLayout.pages {
    print("Page \(page.pageNumber): \(page.characters.count) characters")
    
    for table in page.tables {
        print("  Table at (\(table.bbox.x), \(table.bbox.y)): \(table.rowCount)×\(table.colCount)")
    }
    
    // Query text in specific region (e.g., sidebar)
    let sidebarRegion = BoundingBox(x: 0, y: 0, width: 100, height: page.mediabox.height)
    let sidebarText = try capsule.queryCharsInRegion(
        pageNumber: page.pageNumber,
        region: sidebarRegion
    )
    print("  Sidebar text: \(sidebarText.count) characters")
}

// Generate receipt for provenance
let receipt = try capsule.generateReceipt()
```

## 8. Integration Points

1. **PDFiumProvider**: Replace raw text extraction with layout‑aware extraction
2. **DocumentRenderKit**: Use bounding boxes for precise text highlighting
3. **ContextumModule**: Index structured content (tables, figures) separately from plain text
4. **DiaplasionModule**: Use layout information for improved OCR post‑processing
5. **SegmentIRModule**: Provide geometric foundation for multimodal understanding

## 9. Risk Mitigation

1. **Fallback implementation**: Keep existing Swift text extraction as fallback
2. **Feature flags**: Enable capsule via runtime flag (default: on)
3. **Progressive rollout**: Use capsule only for offline indexing initially
4. **Telemetry**: Monitor performance, memory usage, error rates
5. **Golden corpus tests**: Detect regressions early

## 10. Implementation Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Specification & design | 1 week | This document, C header finalization |
| Core C++ implementation | 2 weeks | PDFium integration, basic geometry extraction |
| Advanced layout analysis | 1 week | Column detection, table recognition |
| Spatial indexing | 1 week | R‑tree implementation, query API |
| Swift wrapper & tests | 1 week | Swift actor, integration tests |
| Performance optimization | 1 week | Benchmarking, memory optimization |
| Integration & deployment | 1 week | Feature flags, fallback mechanisms |

**Total**: 8 weeks (2 months)

---

*This specification provides the complete design for LayoutEngineCapsule. Next step: review and begin implementation.*