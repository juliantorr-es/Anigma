#ifndef ANIGMA_BLOB_H
#define ANIGMA_BLOB_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  const uint8_t* ptr;
  size_t size;
} anigma_blob_t;

typedef struct {
  uint8_t* ptr;
  size_t size;
} anigma_mut_blob_t;

#ifdef __cplusplus
}
#endif

#endif
