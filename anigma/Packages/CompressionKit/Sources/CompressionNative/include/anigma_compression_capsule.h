#ifndef ANIGMA_COMPRESSION_CAPSULE_H
#define ANIGMA_COMPRESSION_CAPSULE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef anigma_capsule_handle_t anigma_compression_capsule_t;

anigma_capsule_identity_t anigma_compression_capsule_get_identity(void);
anigma_status_t anigma_compression_capsule_create(anigma_compression_capsule_t* out_handle, anigma_capsule_error_t* err);
anigma_status_t anigma_compression_capsule_compress(const uint8_t* src, size_t src_len, uint8_t* dst, size_t* dst_len, anigma_capsule_error_t* err);
anigma_status_t anigma_compression_capsule_decompress(const uint8_t* src, size_t src_len, uint8_t* dst, size_t* dst_len, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
