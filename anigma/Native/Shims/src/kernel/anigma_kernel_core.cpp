#include "anigma_kernel_types.h"
#include "anigma_arena.h"
#include <cstring>
#include <algorithm>

extern "C" {

anigma_status_t anigma_initialize(const anigma_determinism_profile_t* profile) {
    if (!profile) return ANIGMA_STATUS_INVALID_INPUT;
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_get_info(anigma_info_response_t* response) {
    if (!response) return ANIGMA_STATUS_INVALID_INPUT;
    response->build_id = 0x1234;
    response->capabilities = 0;
    return ANIGMA_STATUS_SUCCESS;
}

void* anigma_arena_alloc(anigma_arena_t* arena, size_t size, size_t alignment) {
    if (!arena || !arena->base) return nullptr;
    
    uintptr_t current_ptr = reinterpret_cast<uintptr_t>(arena->base) + arena->offset;
    uintptr_t aligned_ptr = (current_ptr + alignment - 1) & ~(alignment - 1);
    size_t new_offset = aligned_ptr - reinterpret_cast<uintptr_t>(arena->base) + size;
    
    if (new_offset > arena->size) {
        return nullptr;
    }
    
    arena->offset = new_offset;
    return reinterpret_cast<void*>(aligned_ptr);
}

} // extern "C"
