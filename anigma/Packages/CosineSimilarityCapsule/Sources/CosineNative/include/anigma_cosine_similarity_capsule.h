#ifndef ANIGMA_COSINE_SIMILARITY_CAPSULE_H
#define ANIGMA_COSINE_SIMILARITY_CAPSULE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

anigma_capsule_identity_t anigma_cosine_similarity_capsule_get_identity(void);
anigma_status_t anigma_cosine_similarity_capsule_compute(const float* a, const float* b, size_t dim, float* out_score, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
