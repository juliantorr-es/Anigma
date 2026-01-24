#include "anigma_kernel_abi.h"
#include "anigma_kernel_types.h"
#include <string.h>
#include <stdlib.h>

anigma_status_t anigma_kernel_initialize(
  anigma_ctx_t ctx,
  anigma_blob_t config,
  anigma_kernel_instance_t* out_instance
) {
  if (!out_instance) return ANIGMA_ERR_INVALID_ARG;
  *out_instance = (anigma_kernel_instance_t)1;
  return ANIGMA_OK;
}

void anigma_kernel_shutdown(anigma_kernel_instance_t instance) {
}

void anigma_kernel_free_blob(anigma_mut_blob_t blob) {
  if (blob.ptr) free(blob.ptr);
}

anigma_status_t anigma_kernel_apply_diff(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_blob_t diff_batch,
  anigma_mut_blob_t* out_receipt
) {
  return ANIGMA_OK;
}

anigma_status_t anigma_kernel_simulation_step(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_time_tick_t delta_ticks,
  anigma_mut_blob_t* out_receipt
) {
  return ANIGMA_OK;
}

anigma_status_t anigma_kernel_render_plan(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_blob_t viewport_request,
  anigma_mut_blob_t* out_plan
) {
  if (!out_plan) return ANIGMA_ERR_INVALID_ARG;
  
  // Allocate a minimal plan using the data struct size
  size_t size = sizeof(anigma_render_plan_data_t);
  out_plan->ptr = (uint8_t*)malloc(size);
  if (!out_plan->ptr) return ANIGMA_ERR_INTERNAL;
  
  memset(out_plan->ptr, 0, size);
  out_plan->size = size;
  
  return ANIGMA_OK;
}

anigma_status_t anigma_kernel_hit_test(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_blob_t hit_query,
  anigma_mut_blob_t* out_hits
) {
  return ANIGMA_OK;
}

anigma_status_t anigma_kernel_snapshot_export(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_mut_blob_t* out_snapshot
) {
  return ANIGMA_OK;
}

anigma_status_t anigma_kernel_snapshot_import(
  anigma_kernel_instance_t instance,
  anigma_ctx_t ctx,
  anigma_blob_t snapshot
) {
  return ANIGMA_OK;
}
