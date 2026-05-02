#ifndef ANIGMA_NATIVE_SHIMS_H
#define ANIGMA_NATIVE_SHIMS_H

// Core definitions
#include "anigma_status.h"
#include "anigma_native_common.h"
#include "anigma_capsule_core.h"
#include "anigma_kernel_types.h"
#include "anigma_kernel_abi.h"

// Capsule-specific headers
#include "anigma_media_container_capsule.h"
#include "anigma_media_fingerprint_capsule.h"
#include "anigma_text_pipeline_capsule.h"
#include "anigma_rank_fusion_capsule.h"
#include "anigma_cosine_similarity_capsule.h"
#include "anigma_vector_capsule.h"
#include "anigma_vector_index_capsule.h"
#include "anigma_vector_store_capsule.h"
#include "anigma_layout_engine_capsule.h"
#include "anigma_text_chunking_capsule.h"
#include "anigma_hit_test.h"
#include "anigma_scene_graph.h"
#include "anigma_render_plan.h"
#include "anigma_animation.h"
#include "anigma_observability.h"

// Third-party stubs
#include "blake3.h"

#endif // ANIGMA_NATIVE_SHIMS_H
