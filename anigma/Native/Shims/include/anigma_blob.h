#pragma once
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct anigma_blob_t {
  const uint8_t* ptr;
  size_t len;
} anigma_blob_t;

typedef struct anigma_mut_blob_t {
  uint8_t* ptr;
  size_t len;
} anigma_mut_blob_t;

typedef enum anigma_status_t {
  ANIGMA_OK = 0,
  ANIGMA_ERR_INVALID = 1,
  ANIGMA_ERR_SCHEMA = 2,
  ANIGMA_ERR_BUDGET = 3,
  ANIGMA_ERR_INTERNAL = 4
} anigma_status_t;

#ifdef __cplusplus
}
#endif
