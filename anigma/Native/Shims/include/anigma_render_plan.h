#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// RenderPlan blob layout (little-endian):
// [Header]
// [Op array]
// [Transform array]
// [Clip array]
// [Paint array]
// [ResourceRef array]
// [Payload byte pool] (text runs, mesh refs, etc.)

#define ANIGMA_PLAN_MAGIC 0x504C4E41u  // 'ANLP' little-endian, pick any 4cc you like
#define ANIGMA_PLAN_VERSION 1

typedef enum anigma_draw_op_type_t {
  ANIGMA_OP_CLEAR = 0,
  ANIGMA_OP_RECT  = 1,
  ANIGMA_OP_MESH  = 2,
  ANIGMA_OP_TEXT  = 3,
  ANIGMA_OP_IMAGE = 4,
  ANIGMA_OP_CLIP_PUSH = 5,
  ANIGMA_OP_CLIP_POP  = 6
} anigma_draw_op_type_t;

typedef enum anigma_resource_type_t {
  ANIGMA_RES_IMAGE = 1,
  ANIGMA_RES_MESH  = 2,
  ANIGMA_RES_GLYPH_ATLAS = 3,
  ANIGMA_RES_FONT = 4
} anigma_resource_type_t;

// Fixed-point geometry is used for anything that affects visible layout.
typedef struct anigma_vec2_i32_t { int32_t x, y; } anigma_vec2_i32_t;
typedef struct anigma_rect_i32_t { int32_t x, y, w, h; } anigma_rect_i32_t;

// 2D affine transform in fixed-point 16.16 (or pick your convention).
// m00 m01 tx
// m10 m11 ty
typedef struct anigma_affine_i32_t {
  int32_t m00, m01, tx;
  int32_t m10, m11, ty;
} anigma_affine_i32_t;

typedef struct anigma_plan_header_t {
  uint32_t magic;
  uint32_t version;

  uint32_t flags;
  uint32_t coord_scale;   // matches determinism profile
  uint32_t tick_hz;
  uint32_t reserved0;

  uint32_t op_count;
  uint32_t transform_count;
  uint32_t clip_count;
  uint32_t paint_count;
  uint32_t resource_count;

  uint32_t ops_offset;
  uint32_t transforms_offset;
  uint32_t clips_offset;
  uint32_t paints_offset;
  uint32_t resources_offset;
  uint32_t payload_offset;
  uint32_t payload_size;

  uint8_t plan_hash32[32]; // hash over canonical bytes excluding this field OR include it, but be consistent.
} anigma_plan_header_t;

typedef struct anigma_resource_ref_t {
  uint64_t logical_id;      // stable ID from orchestrator/content store
  uint32_t type;            // anigma_resource_type_t
  uint32_t flags;
  uint64_t aux0;            // e.g. image pixel format, mesh vertex format, atlas page count
  uint64_t aux1;
} anigma_resource_ref_t;

typedef struct anigma_paint_t {
  uint32_t paint_kind;      // 0=solid,1=stroke,2=image,3=text
  uint32_t blend_mode;      // stable enum, keep small
  uint32_t rgba8;           // packed color if solid; otherwise optional
  uint32_t material_flags;  // antialias, gamma, etc.

  int32_t stroke_width;     // fixed-point in coord_scale units
  uint32_t cap_join;        // packed cap/join enum
  uint32_t reserved;
} anigma_paint_t;

typedef struct anigma_clip_t {
  uint32_t clip_kind;       // 0=rect,1=roundedRect,2=pathMeshRef
  uint32_t payload_off;     // into payload pool
  uint32_t payload_len;
  uint32_t reserved;
  anigma_rect_i32_t bounds; // fast reject and scissor
} anigma_clip_t;

// The op struct is fixed-size. Payload references are offsets into payload pool.
typedef struct anigma_draw_op_t {
  uint32_t type;            // anigma_draw_op_type_t
  uint32_t flags;

  uint64_t sort_key;        // deterministic ordering key (layer, z, stable id, etc.)
  uint64_t entity_id_hi;    // optional: stable id for debugging/selection mapping
  uint64_t entity_id_lo;

  uint32_t transform_index;
  uint32_t clip_index;      // 0xFFFFFFFF = none
  uint32_t paint_index;     // 0xFFFFFFFF = none
  uint32_t layer_id;        // stable layer bucket

  uint32_t payload_off;     // into payload pool
  uint32_t payload_len;     // bytes
  uint32_t resource_index;  // optional: 0xFFFFFFFF if none
  uint32_t reserved;
} anigma_draw_op_t;

// TEXT payload format (in payload pool), versioned so you can evolve:
#define ANIGMA_TEXT_PAYLOAD_VERSION 1
typedef struct anigma_text_payload_header_t {
  uint32_t version;
  uint32_t atlas_resource_index;   // points into resource refs
  uint32_t glyph_count;
  uint32_t flags;
  anigma_vec2_i32_t origin;        // baseline origin, fixed-point
  int32_t font_size;               // fixed-point
  uint32_t reserved;
  // Followed by glyph_count entries:
  // uint32 glyph_id
  // int16 x, int16 y  (or int32 fixed if you need)
} anigma_text_payload_header_t;

// IMAGE payload format
#define ANIGMA_IMAGE_PAYLOAD_VERSION 1
typedef struct anigma_image_payload_t {
  uint32_t version;
  uint32_t image_resource_index;   // resource refs
  anigma_rect_i32_t src_rect;      // in image pixels fixed-point if needed
  anigma_rect_i32_t dst_rect;      // in canvas coords
} anigma_image_payload_t;

// MESH payload format
#define ANIGMA_MESH_PAYLOAD_VERSION 1
typedef struct anigma_mesh_payload_t {
  uint32_t version;
  uint32_t mesh_resource_index;    // resource refs
  uint32_t submesh_index;
  uint32_t flags;
} anigma_mesh_payload_t;

#ifdef __cplusplus
}
#endif
