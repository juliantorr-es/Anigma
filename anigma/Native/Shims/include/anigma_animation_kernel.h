#ifndef ANIGMA_ANIMATION_KERNEL_H
#define ANIGMA_ANIMATION_KERNEL_H

#include "anigma_kernel_types.h"
#include <cstddef>

#if defined(__cplusplus)
extern "C" {
#endif

using anigma_easing_type_t = uint8_t;
using anigma_property_value_type_t = uint8_t;

enum : anigma_easing_type_t {
    ANIGMA_EASING_LINEAR = 0,
    ANIGMA_EASING_IN_QUAD = 1,
    ANIGMA_EASING_OUT_QUAD = 2,
    ANIGMA_EASING_IN_OUT_QUAD = 3,
    ANIGMA_EASING_IN_CUBIC = 4,
    ANIGMA_EASING_OUT_CUBIC = 5,
    ANIGMA_EASING_IN_OUT_CUBIC = 6,
    ANIGMA_EASING_IN_SINE = 7,
    ANIGMA_EASING_OUT_SINE = 8,
    ANIGMA_EASING_IN_OUT_SINE = 9,
    ANIGMA_EASING_SPRING = 10,
    ANIGMA_EASING_CUSTOM = 11,
};

enum : anigma_property_value_type_t {
    ANIGMA_PROPERTY_FLOAT = 0,
    ANIGMA_PROPERTY_POINT = 1,
    ANIGMA_PROPERTY_RECT = 2,
    ANIGMA_PROPERTY_COLOR = 3,
    ANIGMA_PROPERTY_TRANSFORM = 4,
};

struct anigma_property_value_t {
    anigma_property_value_type_t type;
    union {
        float float_value;
        anigma_point_t point_value;
        anigma_rect_t rect_value;
        uint32_t color_value;
        anigma_transform_t transform_value;
    };
};

struct anigma_keyframe_t {
    anigma_time_tick_t time;
    anigma_property_value_t value;
    anigma_easing_type_t easing;
    float easing_params[4];
};

struct anigma_animation_track_t {
    anigma_entity_id_t target_id;
    char property_path[64];
    anigma_keyframe_t* keyframes;
    uint32_t keyframe_count;
    anigma_time_tick_t duration;
    anigma_time_tick_t loop_start;
    int32_t repeat_count;
    uint32_t direction;
    float playback_rate;
};

struct anigma_animation_state_t {
    anigma_time_tick_t current_time;
    anigma_property_value_t* property_deltas;
    uint32_t delta_count;
    int is_complete;
    int is_paused;
};

struct anigma_animation_t {
    anigma_animation_track_t* tracks;
    uint32_t track_count;
    anigma_time_tick_t duration;
    anigma_time_tick_t loop_start;
    anigma_time_tick_t loop_end;
    uint32_t flags;
};

struct anigma_timeline_marker_t {
    char name[32];
    anigma_time_tick_t time;
    uint64_t flags;
};

struct anigma_timeline_event_t {
    uint64_t event_id;
    anigma_time_tick_t trigger_time;
    uint32_t event_type;
    anigma_entity_id_t target;
    anigma_property_value_t payload;
};

struct anigma_timeline_t {
    anigma_animation_track_t* tracks;
    uint32_t track_count;
    anigma_timeline_marker_t* markers;
    uint32_t marker_count;
    anigma_time_tick_t duration;
    anigma_time_tick_t loop_start;
    anigma_time_tick_t loop_end;
    uint32_t flags;
};

struct anigma_timeline_state_t {
    anigma_time_tick_t current_time;
    float playback_rate;
    int is_playing;
    int is_looping;
    anigma_timeline_event_t* pending_events;
    uint32_t pending_count;
    uint32_t pending_capacity;
};

anigma_status_t anigma_animation_evaluate(
    const anigma_animation_track_t* track,
    anigma_time_tick_t time,
    anigma_property_value_t* out_value
);

anigma_status_t anigma_animation_state_create(
    const anigma_animation_t* animation,
    anigma_animation_state_t** state,
    anigma_arena_t* arena
);

anigma_status_t anigma_animation_state_destroy(anigma_animation_state_t* state);

anigma_status_t anigma_animation_step(
    anigma_animation_state_t* state,
    anigma_time_tick_t delta_time
);

anigma_status_t anigma_animation_seek(
    anigma_animation_state_t* state,
    anigma_time_tick_t target_time
);

anigma_status_t anigma_timeline_evaluate(
    const anigma_timeline_t* timeline,
    anigma_time_tick_t time,
    anigma_timeline_state_t* state,
    anigma_arena_t* arena
);

anigma_status_t anigma_timeline_collect_events(
    const anigma_timeline_t* timeline,
    anigma_time_tick_t from_time,
    anigma_time_tick_t to_time,
    anigma_timeline_event_t* output,
    uint32_t* output_count,
    uint32_t max_output,
    anigma_arena_t* arena
);

float anigma_easing_interpolate(
    float t,
    anigma_easing_type_t easing,
    const float* params
);

anigma_status_t anigma_property_lerp(
    const anigma_property_value_t* from,
    const anigma_property_value_t* to,
    float t,
    anigma_property_value_t* out
);

#if defined(__cplusplus)
}
#endif

#endif
