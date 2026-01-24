#ifndef ANIGMA_CONTAINER_SHIM_H
#define ANIGMA_CONTAINER_SHIM_H

#include "anigma_native_common.h"

#if defined(__cplusplus)
extern "C" {
#endif

// Opaque handle for a container (zip archive)
typedef struct anigma_container_s* anigma_container_t;

/**
 * Open a container (zip file).
 * @param path Filesystem path to the container.
 * @param read_only If true, opens for reading only.
 */
anigma_result_t anigma_container_open(
    anigma_ctx_t* ctx,
    const char* path,
    bool read_only,
    anigma_container_t* out_handle
);

/**
 * Close and free the container handle.
 */
anigma_result_t anigma_container_close(anigma_container_t handle);

/**
 * Read an entry from the container.
 * @param name Path within the zip (e.g. "word/document.xml").
 * @param out_data Output buffer, allocated by shim.
 */
anigma_result_t anigma_container_read_entry(
    anigma_container_t handle,
    anigma_ctx_t* ctx,
    const char* name,
    uint8_t** out_data,
    size_t* out_len
);

/**
 * Write/Update an entry in the container.
 * @param name Path within the zip.
 * @param data Data to write.
 */
anigma_result_t anigma_container_write_entry(
    anigma_container_t handle,
    anigma_ctx_t* ctx,
    const char* name,
    const uint8_t* data,
    size_t len
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_CONTAINER_SHIM_H
