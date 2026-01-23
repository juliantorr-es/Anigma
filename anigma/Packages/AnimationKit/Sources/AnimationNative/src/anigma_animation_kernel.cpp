#include "../../include/anigma_animation_kernel.h"
#include "../../include/anigma_hash.h"
#include <cmath>
#include <algorithm>
#include <new>

namespace {

constexpr float PI = 3.14159265358979323846f;
constexpr float SPRING_MASS = 1.0f;
constexpr float SPRING_DAMPING = 0.5f;
constexpr float SPRING_STIFFNESS = 200.0f;

float ease_in_quad(float t) {
    return t * t;
}

float ease_out_quad(float t) {
    return t * (2.0f - t);
}

float ease_in_out_quad(float t) {
    return (t < 0.5f) ? 2.0f * t * t : -1.0f + (4.0f - 2.0f * t) * t;
}

float ease_in_cubic(float t) {
    return t * t * t;
}

float ease_out_cubic(float t) {
    float tt = 1.0f - t;
    return 1.0f - tt * tt * tt;
}

float ease_in_out_cubic(float t) {
    return (t < 0.5f) ? 4.0f * t * t * t : 1.0f - std::pow(-2.0f * t + 2.0f, 3.0f) / 2.0f;
}

float ease_in_sine(float t) {
    return 1.0f - std::cos(t * PI / 2.0f);
}

float ease_out_sine(float t) {
    return std::sin(t * PI / 2.0f);
}

float ease_in_out_sine(float t) {
    return -(std::cos(PI * t) - 1.0f) / 2.0f;
}

float ease_spring(float t, const float* params) {
    float stiffness = (params[0] > 0) ? params[0] : SPRING_STIFFNESS;
    float damping = (params[1] > 0) ? params[1] : SPRING_DAMPING;
    float mass = (params[2] > 0) ? params[2] : SPRING_MASS;
    
    float omega0 = std::sqrt(stiffness / mass);
    float omega1 = omega0 * std::sqrt(1.0f - damping * damping);
    float phi = std::atan2(damping, std::sqrt(1.0f - damping * damping));
    
    float decay = std::exp(-damping * omega0 * t);
    float oscillation = std::cos(omega1 * t - phi);
    
    return 1.0f - decay * oscillation;
}

}  // namespace

float anigma_easing_interpolate(
    float t,
    anigma_easing_type_t easing,
    const float* params
) {
    t = std::max(0.0f, std::min(1.0f, t));
    
    switch (easing) {
        case ANIGMA_EASING_LINEAR:
            return t;
        case ANIGMA_EASING_IN_QUAD:
            return ease_in_quad(t);
        case ANIGMA_EASING_OUT_QUAD:
            return ease_out_quad(t);
        case ANIGMA_EASING_IN_OUT_QUAD:
            return ease_in_out_quad(t);
        case ANIGMA_EASING_IN_CUBIC:
            return ease_in_cubic(t);
        case ANIGMA_EASING_OUT_CUBIC:
            return ease_out_cubic(t);
        case ANIGMA_EASING_IN_OUT_CUBIC:
            return ease_in_out_cubic(t);
        case ANIGMA_EASING_IN_SINE:
            return ease_in_sine(t);
        case ANIGMA_EASING_OUT_SINE:
            return ease_out_sine(t);
        case ANIGMA_EASING_IN_OUT_SINE:
            return ease_in_out_sine(t);
        case ANIGMA_EASING_SPRING:
            return ease_spring(t, params);
        case ANIGMA_EASING_CUSTOM:
            return params[0] + params[1] * t + params[2] * t * t + params[3] * t * t * t;
        default:
            return t;
    }
}

static int find_keyframe_range(
    const anigma_animation_track_t* track,
    anigma_time_tick_t time,
    uint32_t* out_left_index,
    uint32_t* out_right_index
) {
    if (track->keyframe_count == 0) {
        return 0;
    }
    
    if (time <= track->keyframes[0].time) {
        *out_left_index = 0;
        *out_right_index = 0;
        return 1;
    }
    
    if (time >= track->keyframes[track->keyframe_count - 1].time) {
        *out_left_index = track->keyframe_count - 1;
        *out_right_index = track->keyframe_count - 1;
        return 1;
    }
    
    for (uint32_t i = 0; i < track->keyframe_count - 1; i++) {
        if (time >= track->keyframes[i].time && time < track->keyframes[i + 1].time) {
            *out_left_index = i;
            *out_right_index = i + 1;
            return 2;
        }
    }
    
    return 0;
}

anigma_status_t anigma_animation_evaluate(
    const anigma_animation_track_t* track,
    anigma_time_tick_t time,
    anigma_property_value_t* out_value
) {
    if (track == nullptr || out_value == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    if (track->keyframe_count == 0) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    anigma_time_tick_t effective_time = time;
    
    if (track->duration > 0 && track->repeat_count != 0) {
        anigma_time_tick_t loop_time = track->duration;
        if (track->loop_start > 0) {
            loop_time = track->duration - track->loop_start;
        }
        
        if (loop_time > 0) {
            effective_time = track->loop_start + (time % loop_time);
        }
    }
    
    uint32_t left_idx, right_idx;
    int range_count = find_keyframe_range(track, effective_time, &left_idx, &right_idx);
    
    if (range_count == 0) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    const anigma_keyframe_t& left = track->keyframes[left_idx];
    const anigma_keyframe_t& right = track->keyframes[right_idx];
    
    float t = 0.0f;
    if (right.time > left.time) {
        float duration = static_cast<float>(right.time - left.time);
        float elapsed = static_cast<float>(effective_time - left.time);
        t = elapsed / duration;
    }
    
    float eased_t = anigma_easing_interpolate(t, left.easing, left.easing_params);
    
    anigma_property_lerp(&left.value, &right.value, eased_t, out_value);
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_property_lerp(
    const anigma_property_value_t* from,
    const anigma_property_value_t* to,
    float t,
    anigma_property_value_t* out
) {
    if (from == nullptr || to == nullptr || out == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    out->type = from->type;
    
    switch (from->type) {
        case ANIGMA_PROPERTY_FLOAT:
            out->float_value = from->float_value + (to->float_value - from->float_value) * t;
            break;
            
        case ANIGMA_PROPERTY_POINT:
            out->point_value.x = from->point_value.x + 
                static_cast<anigma_coordinate_t>((to->point_value.x - from->point_value.x) * t);
            out->point_value.y = from->point_value.y + 
                static_cast<anigma_coordinate_t>((to->point_value.y - from->point_value.y) * t);
            break;
            
        case ANIGMA_PROPERTY_RECT:
            out->rect_value.x = from->rect_value.x + 
                static_cast<anigma_coordinate_t>((to->rect_value.x - from->rect_value.x) * t);
            out->rect_value.y = from->rect_value.y + 
                static_cast<anigma_coordinate_t>((to->rect_value.y - from->rect_value.y) * t);
            out->rect_value.width = from->rect_value.width + 
                static_cast<anigma_coordinate_t>((to->rect_value.width - from->rect_value.width) * t);
            out->rect_value.height = from->rect_value.height + 
                static_cast<anigma_coordinate_t>((to->rect_value.height - from->rect_value.height) * t);
            break;
            
        case ANIGMA_PROPERTY_COLOR: {
            uint8_t r1 = (from->color_value >> 24) & 0xFF;
            uint8_t g1 = (from->color_value >> 16) & 0xFF;
            uint8_t b1 = (from->color_value >> 8) & 0xFF;
            uint8_t a1 = from->color_value & 0xFF;
            
            uint8_t r2 = (to->color_value >> 24) & 0xFF;
            uint8_t g2 = (to->color_value >> 16) & 0xFF;
            uint8_t b2 = (to->color_value >> 8) & 0xFF;
            uint8_t a2 = to->color_value & 0xFF;
            
            out->color_value = 
                (static_cast<uint32_t>(r1 + (r2 - r1) * t) << 24) |
                (static_cast<uint32_t>(g1 + (g2 - g1) * t) << 16) |
                (static_cast<uint32_t>(b1 + (b2 - b1) * t) << 8) |
                static_cast<uint32_t>(a1 + (a2 - a1) * t);
            break;
        }
            
        case ANIGMA_PROPERTY_TRANSFORM:
            for (int i = 0; i < 3; i++) {
                for (int j = 0; j < 3; j++) {
                    out->transform_value.m[i][j] = from->transform_value.m[i][j] +
                        static_cast<anigma_coordinate_t>((to->transform_value.m[i][j] - from->transform_value.m[i][j]) * t);
                }
            }
            break;
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_animation_state_create(
    const anigma_animation_t* animation,
    anigma_animation_state_t** state,
    anigma_arena_t* arena
) {
    if (animation == nullptr || state == nullptr || arena == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    anigma_animation_state_t* s = static_cast<anigma_animation_state_t*>(
        anigma_arena_alloc(arena, sizeof(anigma_animation_state_t), alignof(anigma_animation_state_t))
    );
    
    if (s == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    s->current_time = 0;
    s->delta_count = animation->track_count;
    s->property_deltas = static_cast<anigma_property_value_t*>(
        anigma_arena_alloc(arena, sizeof(anigma_property_value_t) * animation->track_count, 
                          alignof(anigma_property_value_t))
    );
    
    if (s->property_deltas == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    s->is_complete = 0;
    s->is_paused = 0;
    
    *state = s;
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_animation_state_destroy(anigma_animation_state_t* state) {
    if (state == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    state->property_deltas = nullptr;
    state->delta_count = 0;
    state->is_complete = 1;
    state->is_paused = 1;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_animation_step(
    anigma_animation_state_t* state,
    anigma_time_tick_t delta_time
) {
    if (state == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    if (state->is_paused) {
        return ANIGMA_STATUS_SUCCESS;
    }
    
    state->current_time += delta_time;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_animation_seek(
    anigma_animation_state_t* state,
    anigma_time_tick_t target_time
) {
    if (state == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    state->current_time = target_time;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_timeline_evaluate(
    const anigma_timeline_t* timeline,
    anigma_time_tick_t time,
    anigma_timeline_state_t* state,
    anigma_arena_t* arena
) {
    if (timeline == nullptr || state == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    state->current_time = time;
    state->pending_count = 0;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_timeline_collect_events(
    const anigma_timeline_t* timeline,
    anigma_time_tick_t from_time,
    anigma_time_tick_t to_time,
    anigma_timeline_event_t* output,
    uint32_t* output_count,
    uint32_t max_output,
    anigma_arena_t* arena
) {
    if (timeline == nullptr || output == nullptr || output_count == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    *output_count = 0;
    
    for (uint32_t i = 0; i < timeline->marker_count && *output_count < max_output; i++) {
        const anigma_timeline_marker_t& marker = timeline->markers[i];
        
        if (marker.time >= from_time && marker.time <= to_time) {
            output[*output_count].event_id = i;
            output[*output_count].trigger_time = marker.time;
            output[*output_count].event_type = 0;
            output[*output_count].target = (anigma_entity_id_t){0, 0};
            (*output_count)++;
        }
    }
    
    return ANIGMA_STATUS_SUCCESS;
}
