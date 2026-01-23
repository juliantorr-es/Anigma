#pragma once
#include "anigma_blob.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct anigma_kernel_t anigma_kernel_t;

typedef struct anigma_kernel_build_id_t {
  uint32_t abi_major;
  uint32_t abi_minor;
  uint32_t kernel_build;
  uint32_t reserved;
} anigma_kernel_build_id_t;

anigma_kernel_build_id_t anigma_kernel_build_id(void);

anigma_status_t anigma_kernel_create(
  anigma_blob_t config,
  anigma_kernel_t** out_kernel
);

void anigma_kernel_destroy(anigma_kernel_t* kernel);

void anigma_kernel_free_blob(anigma_mut_blob_t blob);

anigma_status_t anigma_kernel_apply_diff_batch(
  anigma_kernel_t* kernel,
  anigma_blob_t diff_batch,
  anigma_mut_blob_t* out_receipt
);

anigma_status_t anigma_kernel_step_fixed(
  anigma_kernel_t* kernel,
  uint32_t ticks,          // integer ticks, not seconds
  anigma_mut_blob_t* out_receipt
);

anigma_status_t anigma_kernel_render_plan(
  anigma_kernel_t* kernel,
  anigma_blob_t viewport_request,
  anigma_mut_blob_t* out_plan
);

anigma_status_t anigma_kernel_hit_test(
  anigma_kernel_t* kernel,
  anigma_blob_t hit_query,
  anigma_mut_blob_t* out_hits
);

anigma_status_t anigma_kernel_snapshot_export(
  anigma_kernel_t* kernel,
  anigma_mut_blob_t* out_snapshot
);

anigma_status_t anigma_kernel_snapshot_import(
  anigma_kernel_t* kernel,
  anigma_blob_t snapshot
);

anigma_status_t anigma_kernel_state_hash(
  anigma_kernel_t* kernel,
  uint8_t out_hash32[32]
);

#ifdef __cplusplus
}
#endif
