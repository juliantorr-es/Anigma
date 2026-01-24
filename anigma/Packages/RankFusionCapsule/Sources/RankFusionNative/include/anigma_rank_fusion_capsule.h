#ifndef ANIGMA_RANK_FUSION_CAPSULE_H
#define ANIGMA_RANK_FUSION_CAPSULE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint64_t* ids;
    float* scores;
    size_t count;
} anigma_rank_list_t;

anigma_capsule_identity_t anigma_rank_fusion_capsule_get_identity(void);
anigma_status_t anigma_rank_fusion_capsule_rrf(const anigma_rank_list_t* lists, size_t list_count, float k, anigma_rank_list_t* out_list, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
