#ifndef ANIGMA_XML_SHIM_H
#define ANIGMA_XML_SHIM_H

#include "anigma_native_common.h"

#if defined(__cplusplus)
extern "C" {
#endif

// Opaque handle for parsed XML document
typedef struct anigma_xml_doc_s* anigma_xml_doc_t;

/**
 * Parse XML data.
 */
anigma_result_t anigma_xml_parse(
    anigma_ctx_t* ctx,
    const uint8_t* data,
    size_t len,
    anigma_xml_doc_t* out_doc
);

/**
 * Destroy XML document.
 */
anigma_result_t anigma_xml_destroy(anigma_xml_doc_t doc);

/**
 * Apply a patch to the XML document.
 * This is a simplified "find and replace" or structure patch op.
 */
anigma_result_t anigma_xml_apply_patch(
    anigma_xml_doc_t doc,
    anigma_ctx_t* ctx,
    const uint8_t* patch_spec,
    size_t patch_len
);

/**
 * Serialize the XML document back to buffer.
 */
anigma_result_t anigma_xml_serialize(
    anigma_xml_doc_t doc,
    anigma_ctx_t* ctx,
    uint8_t** out_data,
    size_t* out_len
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_XML_SHIM_H
