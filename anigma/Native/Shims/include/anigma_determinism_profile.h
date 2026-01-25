#ifndef ANIGMA_DETERMINISM_PROFILE_H
#define ANIGMA_DETERMINISM_PROFILE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  uint32_t schema_version;

  // Geometry snapping
  uint32_t coord_scale;     // fixed-point scale, e.g. 1024 means 1 unit = 1/1024 px
  uint32_t snap_mode;       // 0=round,1=floor,2=ceil

  // Time
  uint32_t tick_hz;         // e.g. 120 ticks/sec
  uint32_t anim_value_scale;// fixed-point scale for anim outputs

  // Sorting/traversal
  uint32_t traversal_version;
  uint32_t sort_tiebreak_version;

  // Reserved for forward compatibility
  uint32_t reserved[8];
} anigma_det_profile_t;

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_DETERMINISM_PROFILE_H