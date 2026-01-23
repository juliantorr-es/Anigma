#include "../include/anigma_kernel_abi.h"
#include "../include/anigma_render_plan.h"
#include <stdlib.h>
#include <string.h>

// Stub implementation for now
// This allows the Swift layer to link against the C ABI even without the full C++ kernel implementation.

anigma_kernel_build_id_t anigma_kernel_build_id(void) {
    anigma_kernel_build_id_t id = {1, 0, 1, 0};
    return id;
}

anigma_status_t anigma_kernel_create(
  anigma_blob_t config,
  anigma_kernel_t** out_kernel
) {
    if (!out_kernel) return ANIGMA_ERR_INVALID;
    // Just allocate a dummy byte for the handle
    *out_kernel = (anigma_kernel_t*)malloc(1);
    return ANIGMA_OK;
}

void anigma_kernel_destroy(anigma_kernel_t* kernel) {
    if (kernel) free(kernel);
}

void anigma_kernel_free_blob(anigma_mut_blob_t blob) {
    if (blob.ptr) free(blob.ptr);
}

anigma_status_t anigma_kernel_apply_diff_batch(
  anigma_kernel_t* kernel,
  anigma_blob_t diff_batch,
  anigma_mut_blob_t* out_receipt
) {
    // Stub
    if (out_receipt) {
        out_receipt->ptr = NULL;
        out_receipt->len = 0;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_step_fixed(
  anigma_kernel_t* kernel,
  uint32_t ticks,
  anigma_mut_blob_t* out_receipt
) {
    // Stub
    if (out_receipt) {
        out_receipt->ptr = NULL;
        out_receipt->len = 0;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_render_plan(
  anigma_kernel_t* kernel,
  anigma_blob_t viewport_request,
  anigma_mut_blob_t* out_plan
) {
    // Stub: Create a minimal valid plan header
    if (!out_plan) return ANIGMA_ERR_INVALID;
    
    size_t size = sizeof(anigma_plan_header_t);
    anigma_plan_header_t* header = (anigma_plan_header_t*)malloc(size);
    if (!header) return ANIGMA_ERR_INTERNAL;
    
    memset(header, 0, size);
    header->magic = ANIGMA_PLAN_MAGIC;
    header->version = ANIGMA_PLAN_VERSION;
    
    out_plan->ptr = (uint8_t*)header;
    out_plan->len = size;
    
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_hit_test(
  anigma_kernel_t* kernel,
  anigma_blob_t hit_query,
  anigma_mut_blob_t* out_hits
) {
    if (out_hits) {
        out_hits->ptr = NULL;
        out_hits->len = 0;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_snapshot_export(
  anigma_kernel_t* kernel,
  anigma_mut_blob_t* out_snapshot
) {
    if (out_snapshot) {
        out_snapshot->ptr = NULL;
        out_snapshot->len = 0;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_snapshot_import(
  anigma_kernel_t* kernel,
  anigma_blob_t snapshot
) {
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_state_hash(
  anigma_kernel_t* kernel,
  uint8_t out_hash32[32]
) {
    if (!out_hash32) return ANIGMA_ERR_INVALID;
    memset(out_hash32, 0, 32);
    return ANIGMA_OK;
}
