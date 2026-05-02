#ifndef BLAKE3_H
#define BLAKE3_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t cv[8];
    uint64_t chunk_counter;
    uint8_t buf[64];
    uint8_t buf_len;
    uint8_t blocks_compressed;
    uint8_t flags;
} blake3_hasher;

void blake3_hasher_init(blake3_hasher *self);
void blake3_hasher_update(blake3_hasher *self, const void *input, size_t input_len);
void blake3_hasher_finalize(const blake3_hasher *self, uint8_t *out, size_t out_len);

#ifdef __cplusplus
}
#endif

#endif
