#ifndef ANIGMA_HASH_H
#define ANIGMA_HASH_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void anigma_hash_init(uint64_t state[4]);
void anigma_hash_update(uint64_t state[4], const void* data, size_t size);
void anigma_hash_final(uint64_t state[4], uint8_t output[32]);
void anigma_hash(const void* data, size_t size, uint8_t output[32]);

uint64_t anigma_hash_combine(uint64_t a, uint64_t b);

#if defined(__cplusplus)
}
#endif

#endif
