#ifndef ANIGMA_VIZ_AGGREGATION_CAPSULE_H
#define ANIGMA_VIZ_AGGREGATION_CAPSULE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef anigma_capsule_handle_t anigma_viz_aggregation_capsule_t;

anigma_capsule_identity_t anigma_viz_aggregation_capsule_get_identity(void);
anigma_status_t anigma_viz_aggregation_capsule_create(anigma_viz_aggregation_capsule_t* out_handle, anigma_capsule_error_t* err);
anigma_status_t anigma_viz_aggregation_capsule_destroy(anigma_viz_aggregation_capsule_t handle, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
