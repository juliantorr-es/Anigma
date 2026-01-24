#include "anigma_compression_capsule.h"
#include <string.h>

extern "C" {

anigma_capsule_identity_t anigma_compression_capsule_get_identity(void) {
    static const anigma_capsule_identity_t identity = { "compression_capsule", "v1.0.0-stub", "1.0", 1 };
    return identity;
}

anigma_status_t anigma_compression_capsule_create(anigma_compression_capsule_t* out_handle, anigma_capsule_error_t* err) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;
    *out_handle = (anigma_compression_capsule_t)1;
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_compress(const uint8_t* src, size_t src_len, uint8_t* dst, size_t* dst_len, anigma_capsule_error_t* err) {
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_decompress(const uint8_t* src, size_t src_len, uint8_t* dst, size_t* dst_len, anigma_capsule_error_t* err) {
    return ANIGMA_OK;
}

} // extern "C"
