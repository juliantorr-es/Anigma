# TextPipelineCapsule Specification

**Date**: 2026-01-13  
**Author**: opencode  
**Status**: Draft  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Priority**: Medium  
**Dependencies**: ICU library (≥ 70.1)

## 1. Overview

The TextPipelineCapsule provides advanced Unicode text processing operations via the International Components for Unicode (ICU) library. It replaces basic Swift `String` operations with full Unicode support including normalization, segmentation (grapheme, word, sentence), case folding, diacritic stripping, and locale‑aware transformations. This capsule ensures consistent text processing across platforms while maintaining the "Swift governs, C++ computes" architecture.

## 2. Requirements

### 2.1 Functional Requirements

1. **Unicode normalization**:
   - NFD (Canonical Decomposition)
   - NFC (Canonical Composition)
   - NFKD (Compatibility Decomposition)
   - NFKC (Compatibility Composition)
   - Custom normalization (e.g., preserve certain compatibility characters)

2. **Text segmentation**:
   - Grapheme cluster boundaries (UAX #29)
   - Word boundaries (UAX #29)
   - Sentence boundaries (UAX #29)
   - Line breaking (UAX #14)
   - Character boundaries (code points)

3. **Text transformation**:
   - Case folding (case‑insensitive comparison)
   - Case mapping (upper, lower, title case)
   - Diacritic stripping (accent removal)
   - Locale‑aware transformations
   - Script detection and normalization

4. **Encoding conversion**:
   - UTF‑8 ↔ UTF‑16 ↔ UTF‑32
   - Legacy encodings (ISO‑8859‑*, Windows‑*, etc.)
   - Error‑handling strategies (strict, lenient, substitute)

5. **Text analysis**:
   - Script detection (Latin, Cyrillic, Arabic, CJK, etc.)
   - Direction detection (LTR, RTL)
   - Character properties (alphabetic, numeric, whitespace, etc.)
   - String similarity metrics (edit distance, Jaro‑Winkler)

6. **Deterministic processing**:
   - Tier 1: Bitwise identical output for same input
   - Tier 2: Locale‑aware with minor platform differences

### 2.2 Non‑Functional Requirements

1. **Performance**: 3–10× speedup vs. Swift `String` operations for heavy Unicode workloads
2. **Memory**: Bounded memory usage, streaming support for large texts
3. **Determinism**: Tier 1 with fixed ICU version and configuration
4. **Thread safety**: Capsule must be thread‑safe for concurrent operations
5. **Error handling**: Graceful handling of invalid Unicode, encoding errors

## 3. C API Design

### 3.1 Header File Draft (`anigma_text_pipeline_capsule.h`)

```c
#ifndef ANIGMA_TEXT_PIPELINE_CAPSULE_H
#define ANIGMA_TEXT_PIPELINE_CAPSULE_H

#include "anigma_capsule_core.h"
#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Text Pipeline Capsule Types
// ============================================================================

typedef anigma_capsule_handle_t anigma_text_pipeline_capsule_t;

// Normalization form enumeration
enum anigma_normalization_form_t {
    ANIGMA_NORMALIZATION_NONE = 0,
    ANIGMA_NORMALIZATION_NFD = 1,   // Canonical Decomposition
    ANIGMA_NORMALIZATION_NFC = 2,   // Canonical Composition
    ANIGMA_NORMALIZATION_NFKD = 3,  // Compatibility Decomposition
    ANIGMA_NORMALIZATION_NFKC = 4   // Compatibility Composition
};

// Text boundary type
enum anigma_text_boundary_t {
    ANIGMA_BOUNDARY_CHARACTER = 0,   // Code point boundaries
    ANIGMA_BOUNDARY_GRAPHEME = 1,    // Grapheme cluster boundaries
    ANIGMA_BOUNDARY_WORD = 2,        // Word boundaries
    ANIGMA_BOUNDARY_SENTENCE = 3,    // Sentence boundaries
    ANIGMA_BOUNDARY_LINE = 4         // Line break opportunities
};

// Case transformation type
enum anigma_case_transform_t {
    ANIGMA_CASE_NONE = 0,
    ANIGMA_CASE_FOLD = 1,           // Case folding (for case‑insensitive comparison)
    ANIGMA_CASE_UPPER = 2,          // Uppercase mapping
    ANIGMA_CASE_LOWER = 3,          // Lowercase mapping
    ANIGMA_CASE_TITLE = 4           // Titlecase mapping
};

// Locale specification
struct anigma_locale_t {
    const char* language;           // ISO 639‑1 language code (e.g., "en")
    const char* country;            // ISO 3166‑1 country code (e.g., "US") (optional)
    const char* variant;            // Variant code (optional)
    const char* encoding;           // Character encoding (e.g., "UTF‑8") (optional)
};

// Configuration structure
struct anigma_text_pipeline_config_t {
    uint32_t determinism_tier;      // ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    struct anigma_locale_t locale;  // Default locale for locale‑aware operations
    uint8_t preserve_style;         // Preserve font/style information when possible
    uint8_t streaming;              // Enable streaming processing for large texts
    uint32_t max_memory_mb;         // Maximum memory usage (MB)
    uint32_t buffer_size;           // Internal buffer size (bytes)
};

// Text segmentation iterator (opaque)
typedef struct anigma_text_iterator_t* anigma_text_iterator_handle_t;

// Text boundary result
struct anigma_boundary_result_t {
    size_t* boundaries;             // Array of boundary offsets (UTF‑8 byte offsets)
    size_t count;                   // Number of boundaries
    size_t capacity;                // Capacity of boundaries array
};

// Text transformation options
struct anigma_transform_options_t {
    enum anigma_case_transform_t case_transform;
    uint8_t strip_diacritics;       // Remove diacritical marks
    uint8_t normalize_whitespace;   // Normalize whitespace sequences
    uint8_t collapse_punctuation;   // Collapse repeated punctuation
    uint8_t transliterate;          // Transliterate to ASCII (fallback)
    const char* custom_replacements; // JSON mapping for custom replacements
};

// Script detection result
struct anigma_script_result_t {
    const char* script_code;        // ISO 15924 script code (e.g., "Latn")
    double confidence;              // Confidence score (0.0‑1.0)
    size_t start_offset;            // Start offset in UTF‑8 bytes
    size_t length;                  // Length in UTF‑8 bytes
};

// Text statistics
struct anigma_text_stats_t {
    size_t length_utf8;             // Length in UTF‑8 bytes
    size_t length_utf16;            // Length in UTF‑16 code units
    size_t length_utf32;            // Length in Unicode code points
    size_t grapheme_count;          // Number of grapheme clusters
    size_t word_count;              // Number of words
    size_t sentence_count;          // Number of sentences
    size_t line_count;              // Number of lines (by line breaking)
    size_t script_count;            // Number of distinct scripts
};

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get text pipeline capsule identity.
 */
anigma_capsule_identity_t anigma_text_pipeline_capsule_get_identity(void);

/**
 * Create a text pipeline capsule context with given configuration.
 */
anigma_status_t anigma_text_pipeline_capsule_create(
    const struct anigma_text_pipeline_config_t* config,
    anigma_text_pipeline_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a text pipeline capsule context.
 */
anigma_status_t anigma_text_pipeline_capsule_destroy(
    anigma_text_pipeline_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Normalization Functions
// ============================================================================

/**
 * Normalize text using specified normalization form.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_normalize(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input_utf8,
    size_t input_len,
    enum anigma_normalization_form_t form,
    uint8_t* output_utf8,
    size_t output_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Check if text is already normalized.
 */
anigma_status_t anigma_text_pipeline_capsule_is_normalized(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input_utf8,
    size_t input_len,
    enum anigma_normalization_form_t form,
    uint8_t* out_is_normalized,
    anigma_capsule_error_t* err
);

// ============================================================================
// Segmentation Functions
// ============================================================================

/**
 * Create text segmentation iterator.
 */
anigma_status_t anigma_text_pipeline_capsule_create_iterator(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* text_utf8,
    size_t text_len,
    enum anigma_text_boundary_t boundary_type,
    anigma_text_iterator_handle_t* out_iterator,
    anigma_capsule_error_t* err
);

/**
 * Destroy text segmentation iterator.
 */
anigma_status_t anigma_text_pipeline_capsule_destroy_iterator(
    anigma_text_iterator_handle_t iterator,
    anigma_capsule_error_t* err
);

/**
 * Get next boundary from iterator.
 * Returns offset in UTF‑8 bytes, or SIZE_MAX when done.
 */
anigma_status_t anigma_text_pipeline_capsule_iterator_next(
    anigma_text_iterator_handle_t iterator,
    size_t* out_boundary,
    anigma_capsule_error_t* err
);

/**
 * Reset iterator to start.
 */
anigma_status_t anigma_text_pipeline_capsule_iterator_reset(
    anigma_text_iterator_handle_t iterator,
    anigma_capsule_error_t* err
);

/**
 * Get all boundaries at once (convenience function).
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_get_boundaries(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* text_utf8,
    size_t text_len,
    enum anigma_text_boundary_t boundary_type,
    size_t* out_boundaries,
    size_t max_boundaries,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

// ============================================================================
// Transformation Functions
// ============================================================================

/**
 * Transform text with multiple operations.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_transform(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input_utf8,
    size_t input_len,
    const struct anigma_transform_options_t* options,
    uint8_t* output_utf8,
    size_t output_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Case‑fold text for case‑insensitive comparison.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_case_fold(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input_utf8,
    size_t input_len,
    uint8_t* output_utf8,
    size_t output_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Convert text to uppercase.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_to_upper(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input_utf8,
    size_t input_len,
    const struct anigma_locale_t* locale,
    uint8_t* output_utf8,
    size_t output_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Convert text to lowercase.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_to_lower(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input_utf8,
    size_t input_len,
    const struct anigma_locale_t* locale,
    uint8_t* output_utf8,
    size_t output_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Convert text to titlecase.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_to_title(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input_utf8,
    size_t input_len,
    const struct anigma_locale_t* locale,
    uint8_t* output_utf8,
    size_t output_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Strip diacritical marks (accents).
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_strip_diacritics(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input_utf8,
    size_t input_len,
    uint8_t* output_utf8,
    size_t output_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

// ============================================================================
// Encoding Conversion Functions
// ============================================================================

/**
 * Convert text between encodings.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_convert_encoding(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input,
    size_t input_len,
    const char* from_encoding,
    const char* to_encoding,
    uint8_t* output,
    size_t output_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Detect text encoding.
 */
anigma_status_t anigma_text_pipeline_capsule_detect_encoding(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* input,
    size_t input_len,
    char* out_encoding,
    size_t encoding_buf_size,
    double* out_confidence,
    anigma_capsule_error_t* err
);

// ============================================================================
// Analysis Functions
// ============================================================================

/**
 * Detect scripts used in text.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_detect_scripts(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* text_utf8,
    size_t text_len,
    struct anigma_script_result_t* out_scripts,
    size_t max_scripts,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Get text statistics.
 */
anigma_status_t anigma_text_pipeline_capsule_get_stats(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* text_utf8,
    size_t text_len,
    struct anigma_text_stats_t* out_stats,
    anigma_capsule_error_t* err
);

/**
 * Compute string similarity metrics.
 */
anigma_status_t anigma_text_pipeline_capsule_similarity(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* text1_utf8,
    size_t text1_len,
    const uint8_t* text2_utf8,
    size_t text2_len,
    double* out_edit_distance,
    double* out_jaro_winkler,
    double* out_cosine_similarity,
    anigma_capsule_error_t* err
);

/**
 * Detect text direction (LTR/RTL).
 */
anigma_status_t anigma_text_pipeline_capsule_detect_direction(
    anigma_text_pipeline_capsule_t handle,
    const uint8_t* text_utf8,
    size_t text_len,
    uint8_t* out_is_rtl,
    anigma_capsule_error_t* err
);

// ============================================================================
// Locale Management Functions
// ============================================================================

/**
 * Set default locale for subsequent operations.
 */
anigma_status_t anigma_text_pipeline_capsule_set_locale(
    anigma_text_pipeline_capsule_t handle,
    const struct anigma_locale_t* locale,
    anigma_capsule_error_t* err
);

/**
 * Get available locale information.
 */
anigma_status_t anigma_text_pipeline_capsule_get_locale_info(
    anigma_text_pipeline_capsule_t handle,
    const struct anigma_locale_t* locale,
    char* out_name,
    size_t name_buf_size,
    char* out_language,
    size_t language_buf_size,
    char* out_country,
    size_t country_buf_size,
    anigma_capsule_error_t* err
);

// ============================================================================
// Configuration and Utility Functions
// ============================================================================

/**
 * Get default configuration.
 */
struct anigma_text_pipeline_config_t anigma_text_pipeline_capsule_get_default_config(void);

/**
 * Validate configuration parameters.
 */
anigma_status_t anigma_text_pipeline_capsule_validate_config(
    const struct anigma_text_pipeline_config_t* config,
    anigma_capsule_error_t* err
);

/**
 * Get ICU library version.
 */
const char* anigma_text_pipeline_capsule_get_icu_version(void);

/**
 * Check if feature is supported (e.g., specific normalization form).
 */
uint8_t anigma_text_pipeline_capsule_supports_feature(
    const char* feature_name,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_TEXT_PIPELINE_CAPSULE_H
```

## 4. Swift Wrapper Interface

### 4.1 Swift Actor Wrapper (`TextPipelineCapsuleWrapper.swift`)

```swift
import Foundation
import AnigmaNativeShims
import CapsuleCore

public actor TextPipelineCapsuleWrapper {
    public static var identity: anigma_capsule_identity_t {
        anigma_text_pipeline_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let config: TextPipelineConfig
    
    public enum NormalizationForm: UInt32 {
        case none = 0
        case nfd = 1
        case nfc = 2
        case nfkd = 3
        case nfkc = 4
    }
    
    public enum BoundaryType: UInt32 {
        case character = 0
        case grapheme = 1
        case word = 2
        case sentence = 3
        case line = 4
    }
    
    public struct Locale: Sendable {
        public var language: String
        public var country: String?
        public var variant: String?
        public var encoding: String?
        
        public init(language: String, country: String? = nil, variant: String? = nil, encoding: String? = "UTF-8") {
            self.language = language
            self.country = country
            self.variant = variant
            self.encoding = encoding
        }
        
        public static let englishUS = Locale(language: "en", country: "US")
        public static let englishUK = Locale(language: "en", country: "GB")
        // Additional common locales...
    }
    
    public struct TextPipelineConfig: Sendable {
        public var determinismTier: UInt32
        public var locale: Locale
        public var preserveStyle: Bool
        public var streaming: Bool
        public var maxMemoryMB: UInt32
        public var bufferSize: UInt32
        
        public static var `default`: TextPipelineConfig {
            let cConfig = anigma_text_pipeline_capsule_get_default_config()
            return TextPipelineConfig(from: cConfig)
        }
        
        // Conversion methods to/from C struct
    }
    
    public init(config: TextPipelineConfig? = nil) throws {
        let config = config ?? TextPipelineConfig.default
        var rawHandle: anigma_text_pipeline_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = config.toCStruct()
        let status = anigma_text_pipeline_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_text_pipeline_capsule_destroy
        )
        self.config = config
    }
    
    deinit {
        handle?.invalidate()
    }
    
    // MARK: - Normalization
    
    public func normalize(_ text: String, form: NormalizationForm = .nfc) throws -> String {
        let utf8Data = text.data(using: .utf8)!
        var outputSize: size_t = 0
        var error = anigma_capsule_error_t()
        
        // Phase 1: Get required size
        let queryStatus = utf8Data.withUnsafeBytes { inputBytes in
            anigma_text_pipeline_capsule_normalize(
                try handle!.rawHandle,
                inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                utf8Data.count,
                anigma_normalization_form_t(rawValue: form.rawValue),
                nil,
                0,
                &outputSize,
                &error
            )
        }
        
        guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
            throw CapsuleError(status: queryStatus, error: error)
        }
        
        // Phase 2: Allocate and normalize
        var outputData = Data(count: outputSize)
        let normalizeStatus = utf8Data.withUnsafeBytes { inputBytes in
            outputData.withUnsafeMutableBytes { outputBytes in
                anigma_text_pipeline_capsule_normalize(
                    try handle!.rawHandle,
                    inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    utf8Data.count,
                    anigma_normalization_form_t(rawValue: form.rawValue),
                    outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    outputSize,
                    &outputSize,
                    &error
                )
            }
        }
        
        guard normalizeStatus == ANIGMA_OK else {
            throw CapsuleError(status: normalizeStatus, error: error)
        }
        
        outputData.count = outputSize
        return String(data: outputData, encoding: .utf8)!
    }
    
    public func isNormalized(_ text: String, form: NormalizationForm = .nfc) throws -> Bool {
        let utf8Data = text.data(using: .utf8)!
        var isNormalized: UInt8 = 0
        var error = anigma_capsule_error_t()
        
        let status = utf8Data.withUnsafeBytes { inputBytes in
            anigma_text_pipeline_capsule_is_normalized(
                try handle!.rawHandle,
                inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                utf8Data.count,
                anigma_normalization_form_t(rawValue: form.rawValue),
                &isNormalized,
                &error
            )
        }
        
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
        
        return isNormalized != 0
    }
    
    // MARK: - Segmentation
    
    public func segment(_ text: String, boundary: BoundaryType) throws -> [String] {
        let utf8Data = text.data(using: .utf8)!
        var boundaryCount: size_t = 0
        var error = anigma_capsule_error_t()
        
        // Phase 1: Get boundary count
        let queryStatus = utf8Data.withUnsafeBytes { inputBytes in
            anigma_text_pipeline_capsule_get_boundaries(
                try handle!.rawHandle,
                inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                utf8Data.count,
                anigma_text_boundary_t(rawValue: boundary.rawValue),
                nil,
                0,
                &boundaryCount,
                &error
            )
        }
        
        guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
            throw CapsuleError(status: queryStatus, error: error)
        }
        
        guard boundaryCount > 0 else {
            return []
        }
        
        // Phase 2: Get boundaries
        var boundaries = [size_t](repeating: 0, count: boundaryCount)
        let getStatus = utf8Data.withUnsafeBytes { inputBytes in
            anigma_text_pipeline_capsule_get_boundaries(
                try handle!.rawHandle,
                inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                utf8Data.count,
                anigma_text_boundary_t(rawValue: boundary.rawValue),
                &boundaries,
                boundaryCount,
                &boundaryCount,
                &error
            )
        }
        
        guard getStatus == ANIGMA_OK else {
            throw CapsuleError(status: getStatus, error: error)
        }
        
        // Convert boundaries to substrings
        let utf8Bytes = [UInt8](utf8Data)
        var segments: [String] = []
        var start: size_t = 0
        
        for boundary in boundaries {
            guard boundary <= utf8Bytes.count else { break }
            if boundary > start {
                let segmentData = Data(utf8Bytes[start..<boundary])
                if let segment = String(data: segmentData, encoding: .utf8) {
                    segments.append(segment)
                }
            }
            start = boundary
        }
        
        // Add final segment if any
        if start < utf8Bytes.count {
            let segmentData = Data(utf8Bytes[start...])
            if let segment = String(data: segmentData, encoding: .utf8) {
                segments.append(segment)
            }
        }
        
        return segments
    }
    
    public func createIterator(_ text: String, boundary: BoundaryType) throws -> TextIterator {
        let utf8Data = text.data(using: .utf8)!
        var iteratorHandle: anigma_text_iterator_handle_t?
        var error = anigma_capsule_error_t()
        
        let status = utf8Data.withUnsafeBytes { inputBytes in
            anigma_text_pipeline_capsule_create_iterator(
                try handle!.rawHandle,
                inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                utf8Data.count,
                anigma_text_boundary_t(rawValue: boundary.rawValue),
                &iteratorHandle,
                &error
            )
        }
        
        guard status == ANIGMA_OK, let iteratorHandle = iteratorHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        return TextIterator(
            handle: iteratorHandle,
            text: text,
            capsule: self
        )
    }
    
    // MARK: - Transformation
    
    public func caseFold(_ text: String) throws -> String {
        // Implementation similar to normalize
        fatalError("Not yet implemented")
    }
    
    public func toUpper(_ text: String, locale: Locale? = nil) throws -> String {
        // Implementation similar to normalize
        fatalError("Not yet implemented")
    }
    
    public func toLower(_ text: String, locale: Locale? = nil) throws -> String {
        // Implementation similar to normalize
        fatalError("Not yet implemented")
    }
    
    public func toTitle(_ text: String, locale: Locale? = nil) throws -> String {
        // Implementation similar to normalize
        fatalError("Not yet implemented")
    }
    
    public func stripDiacritics(_ text: String) throws -> String {
        // Implementation similar to normalize
        fatalError("Not yet implemented")
    }
    
    // MARK: - Analysis
    
    public func detectScripts(_ text: String) throws -> [ScriptResult] {
        // Implementation
        fatalError("Not yet implemented")
    }
    
    public func getStats(_ text: String) throws -> TextStats {
        // Implementation
        fatalError("Not yet implemented")
    }
    
    // Additional methods for encoding conversion, similarity metrics, etc.
}

public class TextIterator {
    private let handle: anigma_text_iterator_handle_t
    private let text: String
    private weak var capsule: TextPipelineCapsuleWrapper?
    private let utf8Data: Data
    
    fileprivate init(handle: anigma_text_iterator_handle_t, text: String, capsule: TextPipelineCapsuleWrapper) {
        self.handle = handle
        self.text = text
        self.capsule = capsule
        self.utf8Data = text.data(using: .utf8)!
    }
    
    deinit {
        // Destroy iterator
    }
    
    public func next() throws -> String? {
        var boundary: size_t = 0
        var error = anigma_capsule_error_t()
        
        let status = anigma_text_pipeline_capsule_iterator_next(handle, &boundary, &error)
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
        
        guard boundary != SIZE_MAX else {
            return nil
        }
        
        // Convert boundary to substring
        // Implementation depends on internal state tracking
        fatalError("Not yet implemented")
    }
    
    public func reset() throws {
        var error = anigma_capsule_error_t()
        let status = anigma_text_pipeline_capsule_iterator_reset(handle, &error)
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
    }
}

public struct ScriptResult: Sendable {
    public var scriptCode: String
    public var confidence: Double
    public var startOffset: Int
    public var length: Int
}

public struct TextStats: Sendable {
    public var lengthUTF8: Int
    public var lengthUTF16: Int
    public var lengthUTF32: Int
    public var graphemeCount: Int
    public var wordCount: Int
    public var sentenceCount: Int
    public var lineCount: Int
    public var scriptCount: Int
}
```

## 5. Performance Requirements

| Operation | Target Performance | Measurement |
|-----------|-------------------|-------------|
| Normalization (NFD, 1 MB text) | < 10 ms | Time for `normalize` |
| Word segmentation (1 MB text) | < 20 ms | Time for `segment` with `.word` |
| Case folding (1 MB text) | < 5 ms | Time for `caseFold` |
| Script detection (1 MB text) | < 50 ms | Time for `detectScripts` |
| Memory usage (streaming, 1 GB text) | < 100 MB | Peak memory during processing |

**Speedup target**: 3–10× vs. Swift `String` operations for heavy Unicode workloads.

## 6. Determinism Requirements

**Tier 1 (Receipt‑grade)**: Output must be bitwise identical across:
- Different runs on same machine
- Different machines (x86‑64, ARM64)
- Different operating systems (macOS, Linux)
- Same ICU major version (e.g., 70.x)

**ICU Version Pinning**: Lock to ICU 70.1 or later with stable ABI.

**Validation procedure**:
1. Golden corpus of Unicode test cases (emoji, combining characters, RTL text, etc.)
2. SHA‑256 hash verification for each operation
3. Cross‑platform CI testing (macOS, Linux)
4. ICU version check at capsule initialization

## 7. Integration Example

```swift
// Example: Advanced text preprocessing for indexing
let config = TextPipelineConfig(
    locale: .englishUS,
    determinismTier: ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE,
    streaming: true
)

let pipeline = try TextPipelineCapsuleWrapper(config: config)

// Normalize text for consistent indexing
let rawText = "Café 🍵 naïve naïve"
let normalized = try pipeline.normalize(rawText, form: .nfkc)
print("Normalized: \(normalized)") // "Café 🍵 naive naive"

// Segment into words for tokenization
let words = try pipeline.segment(normalized, boundary: .word)
print("Words: \(words)") // ["Café", "🍵", "naive", "naive"]

// Case‑fold for case‑insensitive search
let caseFolded = try pipeline.caseFold(normalized)
print("Case‑folded: \(caseFolded)") // "café 🍵 naive naive"

// Strip diacritics for accent‑insensitive search
let withoutAccents = try pipeline.stripDiacritics(normalized)
print("Without accents: \(withoutAccents)") // "Cafe 🍵 naive naive"

// Analyze text statistics
let stats = try pipeline.getStats(rawText)
print("""
  UTF‑8 bytes: \(stats.lengthUTF8)
  Graphemes: \(stats.graphemeCount)
  Words: \(stats.wordCount)
  Sentences: \(stats.sentenceCount)
""")

// Streaming processing for large documents
let iterator = try pipeline.createIterator(largeDocument, boundary: .sentence)
while let sentence = try iterator.next() {
    processSentence(sentence)
}
```

## 8. Integration Points

1. **ContextumModule text preprocessing**: Replace Swift `String` operations with capsule
2. **DiaplasionPipeline normalization**: Unicode normalization for OCR results
3. **VectorumModule tokenization**: Word segmentation for embeddings
4. **Search index**: Case‑folding and diacritic stripping for query expansion
5. **Receipt generation**: Deterministic text processing for provenance

## 9. Risk Mitigation

1. **ICU dependency**: Feature detection, fallback to Swift implementation
2. **Version compatibility**: Strict version pinning, ABI stability checks
3. **Memory usage**: Streaming API for large texts, configurable limits
4. **Performance regressions**: Benchmark suite, performance gates in CI
5. **Unicode complexity**: Extensive test corpus, edge‑case handling

## 10. Implementation Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Specification & ICU integration | 1 week | This document, build system updates |
| Core normalization | 1 week | NFD/NFC/NFKD/NFKC support |
| Segmentation | 2 weeks | Grapheme, word, sentence, line breaking |
| Transformation | 1 week | Case folding, mapping, diacritic stripping |
| Analysis | 1 week | Script detection, statistics, similarity |
| Swift wrapper & tests | 1 week | Swift actor, integration tests |
| Performance optimization | 1 week | Benchmarking, memory optimization |
| Integration & deployment | 1 week | Feature flags, fallback mechanisms |

**Total**: 9 weeks (2+ months)

---

*This specification provides the complete design for TextPipelineCapsule. Next step: review and begin implementation.*