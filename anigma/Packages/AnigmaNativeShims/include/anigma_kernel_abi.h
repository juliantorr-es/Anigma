#ifndef ANIGMA_KERNEL_ABI_H
#define ANIGMA_KERNEL_ABI_H

#include "anigma_native_common.h"
#include "anigma_kernel_types.h"
#include "anigma_blob.h"

#include "anigma_evidence_ring.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef void* anigma_kernel_instance_t;

anigma_status_t anigma_kernel_initialize(
  anigma_ctx_t ctx,
  anigma_blob_t config,
  anigma_evidence_ring_t* logging_ring,
  anigma_kernel_instance_t* out_instance
);

void anigma_kernel_shutdown(anigma_kernel_instance_t instance);

void anigma_kernel_free_blob(anigma_mut_blob_t blob);

anigma_status_t anigma_kernel_apply_diff_batch(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_blob_t diff_batch,
  anigma_mut_blob_t* out_receipt
);

anigma_status_t anigma_kernel_step_fixed(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_time_tick_t delta_ticks,
  anigma_mut_blob_t* out_receipt
);

anigma_status_t anigma_kernel_render_plan(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_blob_t viewport_request,
  anigma_mut_blob_t* out_plan
);

anigma_status_t anigma_kernel_hit_test(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_blob_t hit_query,
  anigma_mut_blob_t* out_hits
);

anigma_status_t anigma_kernel_snapshot_export(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_mut_blob_t* out_snapshot
);

anigma_status_t anigma_kernel_snapshot_import(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_blob_t snapshot
);

#ifdef __cplusplus
}
#endif

#endif
