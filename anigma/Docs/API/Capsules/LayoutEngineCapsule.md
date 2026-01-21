# Layout Engine Capsule API Reference

**Header**: `anigma_layout_engine_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Thread Safety**: Thread-safe for concurrent operations with distinct handles

## Overview

The Layout Engine Capsule extracts structured layout information from PDF documents, including text segments with bounding boxes and styling, tables, figures, images, and spatial indexing for fast region queries. It uses CPDFium (PDFium wrapper) for PDF parsing and provides advanced layout analysis.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_layout_engine_capsule_t;
```

### Configuration Structure
```c
struct anigma_layout_engine_config_t {
    uint32_t determinism_tier;  // ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    uint32_t flags;             // Analysis flags (e.g., extract_font_metrics, detect_tables)
    size_t max_elements_per_page; // Limit for memory safety
    double merge_text_threshold;   // Distance threshold for merging text segments (in points)
    double table_detection_confidence; // Confidence threshold for table detection (0.0-1.0)
};
```

### Layout Engine Flag Definitions
```c
#define ANIGMA_LAYOUT_ENGINE_FLAG_EXTRACT_FONT_METRICS   (1u << 0)
#define ANIGMA_LAYOUT_ENGINE_FLAG_DETECT_TABLES          (1u << 1)
#define ANIGMA_LAYOUT_ENGINE_FLAG_DETECT_FIGURES         (1u << 2)
#define ANIGMA_LAYOUT_ENGINE_FLAG_EXTRACT_IMAGES         (1u << 3)
#define ANIGMA_LAYOUT_ENGINE_FLAG_ENABLE_PROFILING       (1u << 4)
#define ANIGMA_LAYOUT_ENGINE_FLAG_PRESERVE_CACHES        (1u << 5)
```

### Profiling Statistics Structure
```c
struct anigma_layout_engine_profiling_stats_t {
    size_t total_chars_processed;
    size_t total_segments_created;
    size_t total_pages_processed;
    double pdf_load_time_ms;
    double text_extraction_time_ms;
    double spatial_index_build_time_ms;
    double total_analysis_time_ms; // sum of above times
};
```

### Bounding Box
```c
struct anigma_bounding_box_t {
    double left;
    double top;
    double right;
    double bottom;
};
```

### Text Segment with Styling Information
```c
struct anigma_text_segment_t {
    struct anigma_bounding_box_t bbox;
    const char* text;           // UTF-8 null-terminated string (capsule-owned)
    const char* font_name;      // Font name (optional)
    double font_size;           // Font size in points
    uint32_t font_flags;        // Bold, italic, etc.
    uint32_t color_rgb;         // RGB color (0xRRGGBB)
};
```

### Image Data with Metadata
```c
struct anigma_image_data_t {
    struct anigma_bounding_box_t bbox;
    uint8_t* raw_data;           // Raw image bytes (capsule-owned)
    size_t raw_data_len;
    unsigned int width;          // Pixels
    unsigned int height;         // Pixels
    float horizontal_dpi;
    float vertical_dpi;
    unsigned int bits_per_pixel;
    int colorspace;              // PDFium colorspace constant
    const char* filter;          // First image filter (e.g., "DCTDecode", "FlateDecode")
};
```

### Page Layout Analysis Result
```c
struct anigma_page_layout_t {
    uint32_t page_index;
    size_t segment_count;
    struct anigma_text_segment_t* segments; // Array of segments (capsule-owned)
    size_t table_count;
    struct anigma_bounding_box_t* table_bboxes; // Array of table bounding boxes
    size_t figure_count;
    struct anigma_bounding_box_t* figure_bboxes; // Array of figure bounding boxes
    size_t image_count;
    struct anigma_image_data_t* images; // Array of image data (capsule-owned)
};
```

## Core Functions

### `anigma_layout_engine_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_layout_engine_capsule_get_identity(void);
```
Returns capsule identity information.

### `anigma_layout_engine_capsule_create`
```c
anigma_status_t anigma_layout_engine_capsule_create(
    const struct anigma_layout_engine_config_t* config,
    anigma_layout_engine_capsule_t* out_handle,
    anigma_capsule_error_t* err
);
```
Creates a layout engine capsule context with given configuration.

### `anigma_layout_engine_capsule_destroy`
```c
anigma_status_t anigma_layout_engine_capsule_destroy(
    anigma_layout_engine_capsule_t handle,
    anigma_capsule_error_t* err
);
```
Destroys a layout engine capsule context.

### `anigma_layout_engine_capsule_reset`
```c
anigma_status_t anigma_layout_engine_capsule_reset(
    anigma_layout_engine_capsule_t handle,
    int preserve_caches,
    anigma_capsule_error_t* err
);
```
Resets layout engine capsule context, clearing document-specific state but preserving configuration and optionally caches.

## Layout Analysis Functions

### `anigma_layout_engine_capsule_analyze_pdf`
```c
anigma_status_t anigma_layout_engine_capsule_analyze_pdf(
    anigma_layout_engine_capsule_t handle,
    const uint8_t* pdf_data,
    size_t pdf_data_len,
    struct anigma_page_layout_t* out_layout,
    size_t max_pages,
    size_t* out_actual,
    anigma_capsule_error_t* err
);
```
Analyzes PDF data and extracts layout information. Uses two-phase buffer fill pattern for variable-sized output.

**Two-phase pattern**:
1. Phase 1: Call with `out_layout = NULL` to get required size (in `err->aux`)
2. Phase 2: Allocate buffer and call again

**Parameters**:
- `handle`: Capsule handle
- `pdf_data`: Input PDF data
- `pdf_data_len`: Length of PDF data
- `out_layout`: Output layout structure (caller-allocated)
- `max_pages`: Maximum number of pages that can be stored
- `out_actual`: Actual number of pages analyzed
- `err`: Error output

**Returns**: `ANIGMA_OK` on success, `ANIGMA_ERR_BUFFER_TOO_SMALL` if buffer too small.

### `anigma_layout_engine_capsule_free_layout`
```c
anigma_status_t anigma_layout_engine_capsule_free_layout(
    anigma_layout_engine_capsule_t handle,
    struct anigma_page_layout_t* layout,
    anigma_capsule_error_t* err
);
```
Frees layout analysis results allocated by the capsule. Must be called after processing the layout data to release memory.

### `anigma_layout_engine_capsule_get_spatial_index`
```c
anigma_status_t anigma_layout_engine_capsule_get_spatial_index(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    void** out_index_handle,
    anigma_capsule_error_t* err
);
```
Gets spatial index for a page (R-tree for efficient spatial queries). Returns a handle to an internal spatial index that can be used for queries. The index is owned by the capsule and valid until the capsule is destroyed or the page layout is freed.

### `anigma_layout_engine_capsule_query_bbox`
```c
anigma_status_t anigma_layout_engine_capsule_query_bbox(
    anigma_layout_engine_capsule_t handle,
    void* index_handle,
    const struct anigma_bounding_box_t* bbox,
    uint32_t* out_element_indices,
    size_t max_elements,
    size_t* out_actual,
    anigma_capsule_error_t* err
);
```
Queries elements within a bounding box using spatial index.

### `anigma_layout_engine_capsule_get_profiling_stats`
```c
anigma_status_t anigma_layout_engine_capsule_get_profiling_stats(
    anigma_layout_engine_capsule_t handle,
    struct anigma_layout_engine_profiling_stats_t* out_stats,
    anigma_capsule_error_t* err
);
```
Gets profiling statistics for the layout engine capsule. Statistics are cumulative across all PDF analyses performed with this handle. If profiling flag is not enabled, values may be zero.

## Configuration and Utility Functions

### `anigma_layout_engine_capsule_get_default_config`
```c
struct anigma_layout_engine_config_t anigma_layout_engine_capsule_get_default_config(void);
```
Gets default configuration.

### `anigma_layout_engine_capsule_validate_config`
```c
anigma_status_t anigma_layout_engine_capsule_validate_config(
    const struct anigma_layout_engine_config_t* config,
    anigma_capsule_error_t* err
);
```
Validates configuration parameters.

## Error Handling

All functions return `anigma_status_t` with `ANIGMA_OK` (0) on success. Common error codes:

- `ANIGMA_ERR_INVALID_ARG`: Invalid argument (e.g., null handle, invalid PDF data)
- `ANIGMA_ERR_BUFFER_TOO_SMALL`: Output buffer too small (required size in `aux`)
- `ANIGMA_ERR_INTERNAL`: Internal capsule error
- `ANIGMA_ERR_PDF_PARSE`: Failed to parse PDF document

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Analyze PDF and extract layout
func analyzePDF(_ pdfData: Data) throws -> [PageLayout] {
    var config = anigma_layout_engine_capsule_get_default_config()
    config.flags = ANIGMA_LAYOUT_ENGINE_FLAG_EXTRACT_FONT_METRICS | ANIGMA_LAYOUT_ENGINE_FLAG_DETECT_TABLES
    
    var handle: anigma_layout_engine_capsule_t?
    var error = anigma_capsule_error_t()
    
    let createStatus = anigma_layout_engine_capsule_create(&config, &handle, &error)
    guard createStatus == ANIGMA_OK, let handle = handle else {
        throw CapsuleError(status: createStatus, error: error)
    }
    
    defer {
        anigma_layout_engine_capsule_destroy(handle, &error)
    }
    
    // Phase 1: Get required size
    var layout: UnsafeMutablePointer<anigma_page_layout_t>?
    var actualPages: size_t = 0
    let queryStatus = pdfData.withUnsafeBytes { pdfBytes in
        anigma_layout_engine_capsule_analyze_pdf(
            handle,
            pdfBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
            pdfData.count,
            nil,
            0,
            &actualPages,
            &error
        )
    }
    
    guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
        throw CapsuleError(status: queryStatus, error: error)
    }
    
    let requiredSize = error.aux
    let layoutBuffer = UnsafeMutablePointer<anigma_page_layout_t>.allocate(capacity: requiredSize)
    defer { layoutBuffer.deallocate() }
    
    // Phase 2: Perform analysis
    let analyzeStatus = pdfData.withUnsafeBytes { pdfBytes in
        anigma_layout_engine_capsule_analyze_pdf(
            handle,
            pdfBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
            pdfData.count,
            layoutBuffer,
            requiredSize,
            &actualPages,
            &error
        )
    }
    
    guard analyzeStatus == ANIGMA_OK else {
        throw CapsuleError(status: analyzeStatus, error: error)
    }
    
    // Process results
    var pages: [PageLayout] = []
    for i in 0..<actualPages {
        let pageLayout = layoutBuffer[Int(i)]
        // Convert to Swift types...
    }
    
    // Free layout memory
    anigma_layout_engine_capsule_free_layout(handle, layoutBuffer, &error)
    
    return pages
}
```