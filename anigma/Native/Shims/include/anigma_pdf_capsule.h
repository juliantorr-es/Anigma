#ifndef ANIGMA_PDF_CAPSULE_H
#define ANIGMA_PDF_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"

#if defined(__cplusplus)
extern "C" {
#endif

// Opaque handles
typedef anigma_capsule_handle_t anigma_pdf_document_t;
typedef anigma_capsule_handle_t anigma_pdf_page_t;
typedef anigma_capsule_handle_t anigma_pdf_bitmap_t;

// Initialize PDFium library (idempotent, thread-safe)
anigma_status_t anigma_pdf_initialize(anigma_capsule_error_t* err);

// Destroy PDFium library (should be called on app exit if needed, or let OS handle it)
anigma_status_t anigma_pdf_destroy_library(anigma_capsule_error_t* err);

// -----------------------------------------------------------------------------
// Document
// -----------------------------------------------------------------------------

anigma_status_t anigma_pdf_document_create_from_path(
    const char* path,
    const char* password, // Can be NULL
    anigma_pdf_document_t* out_handle,
    anigma_capsule_error_t* err
);

// Note: data buffer must remain valid if PDFium doesn't copy it. 
// Standard PDFium FPDF_LoadMemDocument does NOT take ownership but usually requires buffer to stay valid.
// However, creating a copy inside might be safer for a capsule.
// For now, let's assume we copy the data or the caller keeps it alive. 
// Actually, `FPDF_LoadMemDocument` takes a buffer. The documentation says: 
// "The application must keep the buffer valid while the document is open."
// To be safe and "Capsule-like", we should probably copy the data internally or document strictly.
// Let's implement copy internally for safety in `anigma_pdf_document_create_from_bytes`.
anigma_status_t anigma_pdf_document_create_from_bytes(
    const uint8_t* data,
    size_t length,
    const char* password, // Can be NULL
    anigma_pdf_document_t* out_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_pdf_document_destroy(
    anigma_pdf_document_t handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_pdf_document_get_page_count(
    anigma_pdf_document_t handle,
    int* out_count,
    anigma_capsule_error_t* err
);

// -----------------------------------------------------------------------------
// Page
// -----------------------------------------------------------------------------

anigma_status_t anigma_pdf_page_load(
    anigma_pdf_document_t doc_handle,
    int page_index,
    anigma_pdf_page_t* out_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_pdf_page_destroy(
    anigma_pdf_page_t handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_pdf_page_get_size(
    anigma_pdf_page_t handle,
    double* out_width,
    double* out_height,
    anigma_capsule_error_t* err
);

// -----------------------------------------------------------------------------
// Text Extraction
// -----------------------------------------------------------------------------

// Get number of characters in the page
anigma_status_t anigma_pdf_page_get_text_length(
    anigma_pdf_page_t handle,
    int* out_length,
    anigma_capsule_error_t* err
);

// Extract text into buffer (buffer size should be at least (length + 1) * 2 bytes for UTF-16LE)
// Actually, FPDFText_GetText returns UTF-16LE.
// We can provide a helper to convert to UTF-8 or just return raw bytes.
// Let's return UTF-8 string for convenience in Swift.
anigma_status_t anigma_pdf_page_get_text(
    anigma_pdf_page_t handle,
    char** out_text_utf8, // Caller must free with anigma_free_buffer
    anigma_capsule_error_t* err
);

// -----------------------------------------------------------------------------
// Rendering
// -----------------------------------------------------------------------------

// Create a bitmap
anigma_status_t anigma_pdf_bitmap_create(
    int width,
    int height,
    bool alpha,
    anigma_pdf_bitmap_t* out_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_pdf_bitmap_destroy(
    anigma_pdf_bitmap_t handle,
    anigma_capsule_error_t* err
);

// Render page to bitmap
anigma_status_t anigma_pdf_page_render_to_bitmap(
    anigma_pdf_page_t page_handle,
    anigma_pdf_bitmap_t bitmap_handle,
    int start_x,
    int start_y,
    int size_x,
    int size_y,
    int rotate, // 0, 1, 2, 3 (0=0, 1=90, 2=180, 3=270)
    int flags, // FPDF_ANNOT | FPDF_LCD_TEXT etc.
    anigma_capsule_error_t* err
);

// Access raw bitmap data
anigma_status_t anigma_pdf_bitmap_get_buffer(
    anigma_pdf_bitmap_t handle,
    uint8_t** out_buffer,
    int* out_stride,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif
