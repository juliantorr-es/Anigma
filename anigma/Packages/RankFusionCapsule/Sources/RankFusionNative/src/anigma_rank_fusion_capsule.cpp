#include "anigma_rank_fusion_capsule.h"
#include <string.h>

extern "C" {

anigma_capsule_identity_t anigma_rank_fusion_capsule_get_identity(void) {
    static const anigma_capsule_identity_t identity = { "rank_fusion_capsule", "v1.0.0-stub", "1.0", 1 };
    return identity;
}

anigma_status_t anigma_rank_fusion_capsule_rrf(const anigma_rank_list_t* lists, size_t list_count, float k, anigma_rank_list_t* out_list, anigma_capsule_error_t* err) {
    return ANIGMA_OK;
}

} // extern "C"
