#include "anigma_cosine_similarity_capsule.h"
#include <string.h>

extern "C" {

anigma_capsule_identity_t anigma_cosine_similarity_capsule_get_identity(void) {
    static const anigma_capsule_identity_t identity = { "cosine_similarity_capsule", "v1.0.0-stub", "1.0", 1 };
    return identity;
}

anigma_status_t anigma_cosine_similarity_capsule_compute(const float* a, const float* b, size_t dim, float* out_score, anigma_capsule_error_t* err) {
    if (!out_score) return ANIGMA_ERR_INVALID_ARG;
    *out_score = 1.0f;
    return ANIGMA_OK;
}

} // extern "C"
