#ifndef ANIGMA_ARENA_H
#define ANIGMA_ARENA_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint8_t* base;
    size_t size;
    size_t offset;
} anigma_arena_t;

void* anigma_arena_alloc(anigma_arena_t* arena, size_t size, size_t alignment);

#ifdef __cplusplus
}
#endif

#endif
