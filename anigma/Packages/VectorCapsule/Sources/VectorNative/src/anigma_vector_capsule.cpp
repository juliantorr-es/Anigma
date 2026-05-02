#include "anigma_vector_capsule.h"
#include "anigma_capsule_core.h"
#include <vector>
#include <cstring>
#include <cmath>
#include <limits>
#include <string>
#include <memory>
#include <cstdio>

// Clipper2 wrapper functions
extern "C" {
#include "clipper2_wrapper.h"
}

namespace {

// Copy of SVG parsing utilities from clipper.svg.cpp
static bool SkipBlanks(std::string::const_iterator& si,
    const std::string::const_iterator se)
{
    while (si != se && *si <= ' ') ++si;
    return si != se;
}

static bool SkipOptionalComma(std::string::const_iterator& si,
    const std::string::const_iterator se)
{
    while (si != se && *si <= ' ') ++si;
    if (si != se && *si == ',') ++si;
    return si != se;
}

static bool GetNum(std::string::const_iterator& si,
    const std::string::const_iterator se, double& value)
{
    while (si != se && *si <= ' ') ++si;
    if (si != se &&  *si == ',') ++si;
    while (si != se && *si <= ' ') ++si;
    if (si == se) return false;
    std::string::const_iterator sit = si;
    while ((si != se && (*si <= ' ')) || *si == ',') ++si;
    bool isneg = *si == '-';
    if (isneg) ++si;
    value = 0;
    int loop_cnt = 0, decpos = -1;
    while (si != se)
    {
        if (*si == '.')
        {
            if (loop_cnt == 0 || decpos >= 0) return false; //invalid
            else decpos = loop_cnt;
        }
        else if (*si < '0' || *si > '9') break;
        else value = value * 10 + (long)(*si) - (long)'0';
        ++si; loop_cnt++;
    }
    if (decpos >= 0)
    {
        decpos = loop_cnt - decpos - 1;
        value *= pow(10, -decpos);
    }
    if (isneg) value = -value;
    return si != sit;
}

// Parse SVG path data string (e.g., "M0,0 L100,0 L100,100 L0,100 Z")
// into Clipper2 PathsD (multiple subpaths).
// Returns true on success, false on parse error.
bool parse_svg_path_string(const char* svg, clipper2_paths_d_t* paths) {
    if (!svg || !*svg) {
        return false;
    }
    std::string str(svg);
    std::string::const_iterator it = str.cbegin(), itEnd = str.cend();
    if (!SkipBlanks(it, itEnd)) {
        return false;
    }
    
    // State from SvgReader parsing logic
    clipper2_path_d_t* current_path = clipper2_path_d_create();
    if (!current_path) return false;
    
    double m_x = 0.0, m_y = 0.0, pt_x = 0.0, pt_y = 0.0;
    bool has_m = false;
    
    // Parse first coordinate pair (must start with M or m)
    char cmd = *it;
    if (cmd != 'M' && cmd != 'm') {
        clipper2_path_d_destroy(current_path);
        return false;
    }
    ++it;
    if (!GetNum(it, itEnd, m_x)) {
        clipper2_path_d_destroy(current_path);
        return false;
    }
    SkipOptionalComma(it, itEnd);
    if (!GetNum(it, itEnd, m_y)) {
        clipper2_path_d_destroy(current_path);
        return false;
    }
    clipper2_path_d_add_point(current_path, m_x, m_y);
    pt_x = m_x;
    pt_y = m_y;
    has_m = true;
    
    while (SkipBlanks(it, itEnd)) {
        cmd = *it;
        if (cmd == 'M' || cmd == 'm') {
            // Start new subpath
            if (clipper2_path_d_size(current_path) > 0) {
                clipper2_paths_d_add_path(paths, current_path);
                clipper2_path_d_destroy(current_path);
                current_path = clipper2_path_d_create();
                if (!current_path) return false;
            }
            ++it;
            if (!GetNum(it, itEnd, m_x)) break;
            SkipOptionalComma(it, itEnd);
            if (!GetNum(it, itEnd, m_y)) break;
            if (cmd == 'm') {
                m_x += pt_x;
                m_y += pt_y;
            }
            clipper2_path_d_add_point(current_path, m_x, m_y);
            pt_x = m_x;
            pt_y = m_y;
            has_m = true;
            continue;
        }
        if (cmd == 'Z' || cmd == 'z') {
            ++it;
            if (has_m && (pt_x != m_x || pt_y != m_y)) {
                clipper2_path_d_add_point(current_path, m_x, m_y);
                pt_x = m_x;
                pt_y = m_y;
            }
            if (clipper2_path_d_size(current_path) > 0) {
                clipper2_paths_d_add_path(paths, current_path);
                clipper2_path_d_destroy(current_path);
                current_path = clipper2_path_d_create();
                if (!current_path) return false;
                has_m = false;
            }
            continue;
        }
        if (cmd == 'L' || cmd == 'l') {
            ++it;
        }
        double x, y;
        if (!GetNum(it, itEnd, x)) break;
        SkipOptionalComma(it, itEnd);
        if (!GetNum(it, itEnd, y)) break;
        if (cmd == 'l') {
            x += pt_x;
            y += pt_y;
        }
        clipper2_path_d_add_point(current_path, x, y);
        pt_x = x;
        pt_y = y;
        if (!has_m) {
            m_x = x;
            m_y = y;
            has_m = true;
        }
        SkipOptionalComma(it, itEnd);
    }
    
    if (clipper2_path_d_size(current_path) > 0) {
        clipper2_paths_d_add_path(paths, current_path);
    }
    clipper2_path_d_destroy(current_path);
    return true;
}

std::string generate_svg_path_string(clipper2_paths_d_t* paths) {
    if (!paths) return "";
    std::string result;
    size_t num_paths = clipper2_paths_d_size(paths);
    for (size_t i = 0; i < num_paths; ++i) {
        const clipper2_path_d_t* path = clipper2_paths_d_get_path(paths, i);
        if (!path) continue;
        size_t num_points = clipper2_path_d_size(path);
        if (num_points == 0) continue;
        if (!result.empty()) result += " ";
        result += "M";
        for (size_t j = 0; j < num_points; ++j) {
            clipper2_point_d_t pt = clipper2_path_d_get_point(path, j);
            if (j > 0) result += " L";
            char buffer[64];
            snprintf(buffer, sizeof(buffer), "%g,%g", pt.x, pt.y);
            result += buffer;
        }
        result += " Z";
    }
    return result;
}

std::vector<uint8_t> paths_to_canonical(clipper2_paths_d_t* paths) {
    std::vector<uint8_t> data;
    if (!paths) return data;
    uint32_t num_paths = static_cast<uint32_t>(clipper2_paths_d_size(paths));
    data.resize(sizeof(uint32_t));
    memcpy(data.data(), &num_paths, sizeof(uint32_t));
    
    for (uint32_t i = 0; i < num_paths; ++i) {
        const clipper2_path_d_t* path = clipper2_paths_d_get_path(paths, i);
        if (!path) continue;
        uint32_t point_count = static_cast<uint32_t>(clipper2_path_d_size(path));
        size_t old_size = data.size();
        data.resize(old_size + sizeof(uint32_t) + point_count * 2 * sizeof(double));
        memcpy(data.data() + old_size, &point_count, sizeof(uint32_t));
        size_t offset = old_size + sizeof(uint32_t);
        for (uint32_t j = 0; j < point_count; ++j) {
            clipper2_point_d_t pt = clipper2_path_d_get_point(path, j);
            memcpy(data.data() + offset, &pt.x, sizeof(double));
            offset += sizeof(double);
            memcpy(data.data() + offset, &pt.y, sizeof(double));
            offset += sizeof(double);
        }
    }
    return data;
}

bool canonical_to_paths(const uint8_t* data, size_t size, clipper2_paths_d_t* paths) {
    if (!data || size < sizeof(uint32_t)) return false;
    uint32_t num_paths;
    memcpy(&num_paths, data, sizeof(uint32_t));
    size_t offset = sizeof(uint32_t);
    for (uint32_t i = 0; i < num_paths; ++i) {
        if (offset + sizeof(uint32_t) > size) return false;
        uint32_t point_count;
        memcpy(&point_count, data + offset, sizeof(uint32_t));
        offset += sizeof(uint32_t);
        if (offset + point_count * 2 * sizeof(double) > size) return false;
        clipper2_path_d_t* path = clipper2_path_d_create();
        if (!path) return false;
        for (uint32_t j = 0; j < point_count; ++j) {
            double x, y;
            memcpy(&x, data + offset, sizeof(double));
            offset += sizeof(double);
            memcpy(&y, data + offset, sizeof(double));
            offset += sizeof(double);
            clipper2_path_d_add_point(path, x, y);
        }
        clipper2_paths_d_add_path(paths, path);
        clipper2_path_d_destroy(path);
    }
    return true;
}

clipper2_fillrule_t map_fillrule(anigma_vector_fillrule_t fillrule) {
    switch (fillrule) {
        case ANIGMA_VECTOR_FILL_EVEN_ODD: return CLIPPER2_FILLRULE_EVEN_ODD;
        case ANIGMA_VECTOR_FILL_NON_ZERO: return CLIPPER2_FILLRULE_NON_ZERO;
        case ANIGMA_VECTOR_FILL_POSITIVE: return CLIPPER2_FILLRULE_POSITIVE;
        case ANIGMA_VECTOR_FILL_NEGATIVE: return CLIPPER2_FILLRULE_NEGATIVE;
        default: return CLIPPER2_FILLRULE_EVEN_ODD;
    }
}

clipper2_cliptype_t map_op(anigma_vector_op_t op) {
    switch (op) {
        case ANIGMA_VECTOR_OP_UNION: return CLIPPER2_CLIPTYPE_UNION;
        case ANIGMA_VECTOR_OP_DIFFERENCE: return CLIPPER2_CLIPTYPE_DIFFERENCE;
        case ANIGMA_VECTOR_OP_INTERSECTION: return CLIPPER2_CLIPTYPE_INTERSECTION;
        case ANIGMA_VECTOR_OP_XOR: return CLIPPER2_CLIPTYPE_XOR;
        default: return CLIPPER2_CLIPTYPE_INTERSECTION;
    }
}

bool perform_boolean_op(
    clipper2_paths_d_t* subject,
    clipper2_paths_d_t* clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    clipper2_paths_d_t** result
) {
    if (!subject || !clip || !result) return false;
    clipper2_fillrule_t fr = map_fillrule(fillrule);
    clipper2_cliptype_t ct = map_op(op);
    int precision = 6;
    switch (ct) {
        case CLIPPER2_CLIPTYPE_INTERSECTION:
            *result = clipper2_intersect_d(subject, clip, fr, precision);
            break;
        case CLIPPER2_CLIPTYPE_UNION:
            *result = clipper2_union_d(subject, clip, fr, precision);
            break;
        case CLIPPER2_CLIPTYPE_DIFFERENCE:
            *result = clipper2_difference_d(subject, clip, fr, precision);
            break;
        case CLIPPER2_CLIPTYPE_XOR:
            *result = clipper2_xor_d(subject, clip, fr, precision);
            break;
        default:
            return false;
    }
    return (*result != nullptr);
}

} // anonymous namespace

struct anigma_vector_capsule_impl {
    clipper2_paths_d_t* paths;
    anigma_vector_capsule_impl() : paths(nullptr) {}
    ~anigma_vector_capsule_impl() {
        if (paths) {
            clipper2_paths_d_destroy(paths);
        }
    }
};

extern "C" {

anigma_capsule_identity_t anigma_vector_capsule_get_identity(void) {
    anigma_capsule_identity_t identity;
    identity.capsule_id = "vector_capsule";
    identity.build_hash = "dev_hash";
    identity.algo_version = "1.0.0";
    identity.determinism_tier = ANIGMA_DETERMINISM_TIER_2_CANONICAL_BOUNDARY;
    return identity;
}

anigma_status_t anigma_vector_capsule_create_from_svg(
    const char* svg_path,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!svg_path || !out_handle) return ANIGMA_ERR_INVALID_ARG;
    auto* impl = new anigma_vector_capsule_impl;
    if (!impl) return ANIGMA_ERR_INTERNAL;
    impl->paths = clipper2_paths_d_create();
    if (!impl->paths) {
        delete impl;
        return ANIGMA_ERR_INTERNAL;
    }
    if (!parse_svg_path_string(svg_path, impl->paths)) {
        delete impl;
        return ANIGMA_ERR_CORRUPT_DATA;
    }
    *out_handle = impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_destroy(
    anigma_vector_capsule_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    delete static_cast<anigma_vector_capsule_impl*>(handle);
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_boolean_op(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!subject || !clip || !out_result) return ANIGMA_ERR_INVALID_ARG;
    auto* subject_impl = static_cast<anigma_vector_capsule_impl*>(subject);
    auto* clip_impl = static_cast<anigma_vector_capsule_impl*>(clip);
    auto* result_impl = new anigma_vector_capsule_impl;
    if (!result_impl) return ANIGMA_ERR_INTERNAL;
    result_impl->paths = nullptr;
    if (!perform_boolean_op(subject_impl->paths, clip_impl->paths, op, fillrule, &result_impl->paths)) {
        delete result_impl;
        return ANIGMA_ERR_INTERNAL;
    }
    *out_result = result_impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_boolean_op_in_place(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_capsule_error_t* err
) {
    if (!subject || !clip) return ANIGMA_ERR_INVALID_ARG;
    auto* subject_impl = static_cast<anigma_vector_capsule_impl*>(subject);
    auto* clip_impl = static_cast<anigma_vector_capsule_impl*>(clip);
    clipper2_paths_d_t* result_paths = nullptr;
    if (!perform_boolean_op(subject_impl->paths, clip_impl->paths, op, fillrule, &result_paths)) {
        return ANIGMA_ERR_INTERNAL;
    }
    clipper2_paths_d_destroy(subject_impl->paths);
    subject_impl->paths = result_paths;
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_export_to_svg(
    anigma_vector_capsule_t handle,
    char** out_svg_string,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_svg_string) return ANIGMA_ERR_INVALID_ARG;
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    std::string svg = generate_svg_path_string(impl->paths);
    char* copy = (char*)malloc(svg.size() + 1);
    if (!copy) return ANIGMA_ERR_INTERNAL;
    strcpy(copy, svg.c_str());
    *out_svg_string = copy;
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_export_canonical(
    anigma_vector_capsule_t handle,
    anigma_capsule_buffer_t* out_buffer,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_buffer) return ANIGMA_ERR_INVALID_ARG;
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    std::vector<uint8_t> canonical = paths_to_canonical(impl->paths);
    if (!out_buffer->ptr || out_buffer->cap < canonical.size()) {
        return anigma_capsule_query_output_size(err, canonical.size());
    }
    memcpy(out_buffer->ptr, canonical.data(), canonical.size());
    out_buffer->len = canonical.size();
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_create_from_canonical(
    const anigma_capsule_buffer_t* buffer,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!buffer || !buffer->ptr || !out_handle) return ANIGMA_ERR_INVALID_ARG;
    auto* impl = new anigma_vector_capsule_impl;
    if (!impl) return ANIGMA_ERR_INTERNAL;
    impl->paths = clipper2_paths_d_create();
    if (!impl->paths) {
        delete impl;
        return ANIGMA_ERR_INTERNAL;
    }
    if (!canonical_to_paths(buffer->ptr, buffer->len, impl->paths)) {
        delete impl;
        return ANIGMA_ERR_CORRUPT_DATA;
    }
    *out_handle = impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_is_empty(
    anigma_vector_capsule_t handle,
    bool* out_empty,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_empty) return ANIGMA_ERR_INVALID_ARG;
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    *out_empty = (clipper2_paths_d_size(impl->paths) == 0);
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_get_bounds(
    anigma_vector_capsule_t handle,
    double* out_min_x,
    double* out_min_y,
    double* out_max_x,
    double* out_max_y,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_min_x || !out_min_y || !out_max_x || !out_max_y) return ANIGMA_ERR_INVALID_ARG;
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    size_t num_paths = clipper2_paths_d_size(impl->paths);
    if (num_paths == 0) {
        *out_min_x = *out_min_y = *out_max_x = *out_max_y = 0.0;
        return ANIGMA_OK;
    }
    bool first = true;
    for (size_t i = 0; i < num_paths; ++i) {
        const clipper2_path_d_t* path = clipper2_paths_d_get_path(impl->paths, i);
        if (!path) continue;
        size_t num_points = clipper2_path_d_size(path);
        for (size_t j = 0; j < num_points; ++j) {
            clipper2_point_d_t pt = clipper2_path_d_get_point(path, j);
            if (first) {
                *out_min_x = *out_max_x = pt.x;
                *out_min_y = *out_max_y = pt.y;
                first = false;
            } else {
                if (pt.x < *out_min_x) *out_min_x = pt.x;
                if (pt.x > *out_max_x) *out_max_x = pt.x;
                if (pt.y < *out_min_y) *out_min_y = pt.y;
                if (pt.y > *out_max_y) *out_max_y = pt.y;
            }
        }
    }
    return ANIGMA_OK;
}

} // extern "C"
