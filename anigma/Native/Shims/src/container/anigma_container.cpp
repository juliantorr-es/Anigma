#include "anigma_container.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct anigma_container_s {
    char* path;
    bool read_only;
};

anigma_result_t anigma_container_open(
    anigma_ctx_t* ctx,
    const char* path,
    bool read_only,
    anigma_container_t* out_handle
) {
    if (!path || !out_handle) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    struct anigma_container_s* c = (struct anigma_container_s*) (void*)malloc(sizeof(struct anigma_container_s));
    if (!c) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    
    c->path = strdup(path);
    c->read_only = read_only;
    *out_handle = c;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_container_close(anigma_container_t handle) {
    if (handle) {
        if (handle->path) free(handle->path);
        free(handle);
    }
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_container_read_entry(
    anigma_container_t handle,
    anigma_ctx_t* ctx,
    const char* name,
    uint8_t** out_data,
    size_t* out_len
) {
    if (!handle || !name || !out_data || !out_len) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    // Mock: Return a dummy XML string for testing
    const char* mock_content = "<root><mock>content</mock></root>";
    size_t len = strlen(mock_content);
    
    uint8_t* buf = (uint8_t*) (void*)malloc(len);
    if (!buf) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    
    memcpy(buf, mock_content, len);
    *out_data = buf;
    *out_len = len;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_container_write_entry(
    anigma_container_t handle,
    anigma_ctx_t* ctx,
    const char* name,
    const uint8_t* data,
    size_t len
) {
    if (!handle || !name || !data) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    if (handle->read_only) return (anigma_result_t){ANIGMA_ERR_IO, "Container is read-only"};
    
    // Mock: Pretend write succeeded
    return (anigma_result_t){ANIGMA_OK, NULL};
}
