#include "blake3.h"
#include <string.h>

void blake3_hasher_init(blake3_hasher *self) {
    memset(self, 0, sizeof(*self));
}

void blake3_hasher_update(blake3_hasher *self, const void *input, size_t input_len) {
    // Stub implementation: XOR first bytes into cv for non-zero hash
    const uint8_t* p = (const uint8_t*)input;
    for (size_t i = 0; i < input_len && i < 32; ++i) {
        ((uint8_t*)self->cv)[i % 32] ^= p[i];
    }
}

void blake3_hasher_finalize(const blake3_hasher *self, uint8_t *out, size_t out_len) {
    if (out_len > 32) out_len = 32;
    memcpy(out, self->cv, out_len);
}
