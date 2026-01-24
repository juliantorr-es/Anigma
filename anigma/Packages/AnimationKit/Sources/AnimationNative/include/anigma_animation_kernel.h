#ifndef ANIGMA_ANIMATION_KERNEL_H
#define ANIGMA_ANIMATION_KERNEL_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

anigma_status_t anigma_animation_engine_update(float delta_time, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
