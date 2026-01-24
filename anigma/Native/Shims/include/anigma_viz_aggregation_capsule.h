#ifndef ANIGMA_VIZ_AGGREGATION_CAPSULE_H
#define ANIGMA_VIZ_AGGREGATION_CAPSULE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef anigma_capsule_handle_t anigma_viz_aggregation_capsule_t;
typedef void* anigma_viz_dataset_t;

typedef enum {
    ANIGMA_VIZ_SCALAR_I64,
    ANIGMA_VIZ_SCALAR_U64,
    ANIGMA_VIZ_SCALAR_F64,
    ANIGMA_VIZ_SCALAR_F32,
    ANIGMA_VIZ_SCALAR_BOOL,
    ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC,
    ANIGMA_VIZ_SCALAR_STRING_UTF8
} anigma_viz_scalar_type_t;

typedef enum {
    ANIGMA_VIZ_NULL_DISALLOW,
    ANIGMA_VIZ_NULL_PROPAGATE
} anigma_viz_null_policy_t;

typedef enum {
    ANIGMA_VIZ_AGG_MODE_DETERMINISTIC,
    ANIGMA_VIZ_AGG_MODE_FAST
} anigma_viz_aggregation_mode_t;

typedef enum {
    ANIGMA_VIZ_AGG_COUNT,
    ANIGMA_VIZ_AGG_SUM,
    ANIGMA_VIZ_AGG_MEAN,
    ANIGMA_VIZ_AGG_MIN,
    ANIGMA_VIZ_AGG_MAX,
    ANIGMA_VIZ_AGG_VARIANCE
} anigma_viz_agg_fn_t;

typedef struct {
    const char* name;
    anigma_viz_scalar_type_t type;
    const void* data;
    size_t count;
    const uint8_t* null_bitmap;
} anigma_viz_column_view_t;

typedef struct {
    const char* name;
    anigma_viz_scalar_type_t type;
} anigma_viz_column_ref_t;

typedef struct {
    anigma_viz_column_ref_t* select_columns;
    size_t select_columns_count;
    anigma_viz_aggregation_mode_t mode;
    anigma_viz_null_policy_t null_policy;
} anigma_viz_aggregation_plan_t;

typedef struct {
    void* domains;
    size_t domains_bytes;
    void* ticks;
    size_t ticks_bytes;
} anigma_viz_aggregation_meta_t;

anigma_capsule_identity_t anigma_viz_aggregation_capsule_get_identity(void);
anigma_status_t anigma_viz_aggregation_capsule_create(anigma_viz_aggregation_capsule_t* out_handle, anigma_capsule_error_t* err);
anigma_status_t anigma_viz_aggregation_capsule_destroy(anigma_viz_aggregation_capsule_t handle, anigma_capsule_error_t* err);

anigma_status_t anigma_viz_dataset_destroy(anigma_viz_dataset_t dataset, anigma_capsule_error_t* err);
anigma_status_t anigma_viz_dataset_get_column_count(anigma_viz_dataset_t dataset, size_t* count, anigma_capsule_error_t* err);
anigma_status_t anigma_viz_dataset_get_column_info(anigma_viz_dataset_t dataset, size_t index, anigma_viz_column_ref_t* info, anigma_capsule_error_t* err);
anigma_status_t anigma_viz_dataset_get_column_data(anigma_viz_dataset_t dataset, size_t index, const void** data, size_t* count, anigma_capsule_error_t* err);
anigma_status_t anigma_viz_dataset_create_from_columns(const anigma_viz_column_view_t* columns, size_t count, anigma_viz_dataset_t* out_dataset, anigma_capsule_error_t* err);

anigma_status_t anigma_viz_aggregation_capsule_execute(
    anigma_viz_aggregation_capsule_t handle,
    anigma_viz_dataset_t input,
    const anigma_viz_aggregation_plan_t* plan,
    anigma_viz_dataset_t* out_dataset,
    anigma_viz_aggregation_meta_t* out_meta,
    anigma_capsule_error_t* err
);

void anigma_viz_aggregation_capsule_free_meta(anigma_viz_aggregation_meta_t* meta);

#ifdef __cplusplus
}
#endif

#endif
