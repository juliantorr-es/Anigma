#include "anigma_container.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct anigma_container_s {
    char* path;
    bool read_only;
};

extern "C" {

anigma_result_t anigma_container_open(
    anigma_ctx_t* ctx,
    const char* path,
    bool read_only,
    anigma_container_t* out_handle
) {
    (void)ctx;
    if (!path || !out_handle) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    }

    struct anigma_container_s* container =
        static_cast<struct anigma_container_s*>(malloc(sizeof(struct anigma_container_s)));
    if (!container) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    }

    container->path = strdup(path);
    container->read_only = read_only;
    *out_handle = container;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_container_close(anigma_container_t handle) {
    if (handle) {
        free(handle->path);
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
    (void)ctx;
    if (!handle || !name || !out_data || !out_len) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    }

    const char* mock_content = "<root><mock>content</mock></root>";
    size_t len = strlen(mock_content);

    uint8_t* buffer = static_cast<uint8_t*>(malloc(len));
    if (!buffer) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    }

    memcpy(buffer, mock_content, len);
    *out_data = buffer;
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
    (void)ctx;
    (void)len;
    if (!handle || !name || !data) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    }
    if (handle->read_only) {
        return (anigma_result_t){ANIGMA_ERR_IO, "Container is read-only"};
    }
    return (anigma_result_t){ANIGMA_OK, NULL};
}

} // extern "C"
