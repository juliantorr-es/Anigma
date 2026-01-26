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

// ============================================================================
// Internal Types
// ============================================================================

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
    // If relative move, we treat as absolute (relative to (0,0))
    if (cmd == 'm') {
        // relative move: current position is (0,0) initially
        // ignore for now
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
                // relative move: add to previous point (pt_x, pt_y)
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
            // Close path: add line to start point if not already there
            ++it;
            if (has_m && (pt_x != m_x || pt_y != m_y)) {
                clipper2_path_d_add_point(current_path, m_x, m_y);
                pt_x = m_x;
                pt_y = m_y;
            }
            // Subpath finished, add to paths
            if (clipper2_path_d_size(current_path) > 0) {
                clipper2_paths_d_add_path(paths, current_path);
                clipper2_path_d_destroy(current_path);
                current_path = clipper2_path_d_create();
                if (!current_path) return false;
                has_m = false;
            }
            continue;
        }
        // Line command (L, l) or implicit line after M
        if (cmd == 'L' || cmd == 'l') {
            ++it;
        }
        // Parse coordinate pair
        double x, y;
        if (!GetNum(it, itEnd, x)) break;
        SkipOptionalComma(it, itEnd);
        if (!GetNum(it, itEnd, y)) break;
        if (cmd == 'l') { // relative line
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
    
    // Add the last subpath if any points
    if (clipper2_path_d_size(current_path) > 0) {
        clipper2_paths_d_add_path(paths, current_path);
    }
    clipper2_path_d_destroy(current_path);
    return true;
}

// Generate SVG path data string from Clipper2 PathsD.
// Simple: each subpath starts with M, then L for subsequent points, ends with Z.
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

// Convert Clipper2 PathsD to canonical binary format.
// Format: [num_paths: uint32_t][for each path: point_count: uint32_t][points: double*2*point_count]
std::vector<uint8_t> paths_to_canonical(clipper2_paths_d_t* paths) {
    std::vector<uint8_t> data;
    if (!paths) return data;
    uint32_t num_paths = static_cast<uint32_t>(clipper2_paths_d_size(paths));
    // First write num_paths
    size_t offset = 0;
    data.resize(sizeof(uint32_t));
    memcpy(data.data(), &num_paths, sizeof(uint32_t));
    offset += sizeof(uint32_t);
    
    for (uint32_t i = 0; i < num_paths; ++i) {
        const clipper2_path_d_t* path = clipper2_paths_d_get_path(paths, i);
        if (!path) continue;
        uint32_t point_count = static_cast<uint32_t>(clipper2_path_d_size(path));
        // Append point_count
        size_t old_size = data.size();
        data.resize(old_size + sizeof(uint32_t) + point_count * 2 * sizeof(double));
        memcpy(data.data() + old_size, &point_count, sizeof(uint32_t));
        offset = old_size + sizeof(uint32_t);
        // Append points
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

// Convert canonical binary format to Clipper2 PathsD.
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

// Map fill rule enum from capsule to Clipper2
clipper2_fillrule_t map_fillrule(anigma_vector_fillrule_t fillrule) {
    switch (fillrule) {
        case ANIGMA_VECTOR_FILL_EVEN_ODD: return CLIPPER2_FILLRULE_EVEN_ODD;
        case ANIGMA_VECTOR_FILL_NON_ZERO: return CLIPPER2_FILLRULE_NON_ZERO;
        case ANIGMA_VECTOR_FILL_POSITIVE: return CLIPPER2_FILLRULE_POSITIVE;
        case ANIGMA_VECTOR_FILL_NEGATIVE: return CLIPPER2_FILLRULE_NEGATIVE;
        default: return CLIPPER2_FILLRULE_EVEN_ODD;
    }
}

// Map operation enum from capsule to Clipper2 cliptype
clipper2_cliptype_t map_op(anigma_vector_op_t op) {
    switch (op) {
        case ANIGMA_VECTOR_OP_UNION: return CLIPPER2_CLIPTYPE_UNION;           // 0 -> 1
        case ANIGMA_VECTOR_OP_DIFFERENCE: return CLIPPER2_CLIPTYPE_DIFFERENCE; // 1 -> 2
        case ANIGMA_VECTOR_OP_INTERSECTION: return CLIPPER2_CLIPTYPE_INTERSECTION; // 2 -> 0
        case ANIGMA_VECTOR_OP_XOR: return CLIPPER2_CLIPTYPE_XOR;               // 3 -> 3
        default: return CLIPPER2_CLIPTYPE_INTERSECTION;
    }
}

// Perform boolean operation using Clipper2 double precision
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
    // Use double precision with default precision 6 (enough for graphics)
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

// ============================================================================
// C API Implementation
// ============================================================================

// Vector capsule handle is a pointer to clipper2_paths_d_t
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

// ----------------------------------------------------------------------------
// Identity
// ----------------------------------------------------------------------------

anigma_capsule_identity_t anigma_vector_capsule_get_identity(void) {
    static const char* capsule_id = "vector_capsule";
    static const char* build_hash = "dev_20250112_1";  // Should be generated from build
    static const char* algo_version = "1.0.0";
    
    return (anigma_capsule_identity_t) {
        .capsule_id = capsule_id,
        .build_hash = build_hash,
        .algo_version = algo_version,
        .determinism_tier = ANIGMA_DETERMINISM_TIER_2_CANONICAL_BOUNDARY
    };
}

// ----------------------------------------------------------------------------
// Creation and Destruction
// ----------------------------------------------------------------------------

anigma_status_t anigma_vector_capsule_create_from_svg(
    const char* svg_path,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!svg_path || !out_handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = new (std::nothrow) anigma_vector_capsule_impl;
    if (!impl) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate vector capsule";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    impl->paths = clipper2_paths_d_create();
    if (!impl->paths) {
        delete impl;
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to create paths container";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    if (!parse_svg_path_string(svg_path, impl->paths)) {
        delete impl;
        if (err) {
            err->code = ANIGMA_ERR_CORRUPT_DATA;
            err->message = "Failed to parse SVG path";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_CORRUPT_DATA;
    }
    
    *out_handle = impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_destroy(
    anigma_vector_capsule_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Handle is null";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    delete static_cast<anigma_vector_capsule_impl*>(handle);
    return ANIGMA_OK;
}

// ----------------------------------------------------------------------------
// Boolean Operations
// ----------------------------------------------------------------------------

anigma_status_t anigma_vector_capsule_boolean_op(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!subject || !clip || !out_result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* subject_impl = static_cast<anigma_vector_capsule_impl*>(subject);
    auto* clip_impl = static_cast<anigma_vector_capsule_impl*>(clip);
    
    auto* result_impl = new (std::nothrow) anigma_vector_capsule_impl;
    if (!result_impl) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate result capsule";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    result_impl->paths = clipper2_paths_d_create();
    if (!result_impl->paths) {
        delete result_impl;
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to create result paths container";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    clipper2_paths_d_t* result_paths = nullptr;
    if (!perform_boolean_op(subject_impl->paths, clip_impl->paths, op, fillrule, &result_paths)) {
        delete result_impl;
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Boolean operation failed";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    // Replace the empty paths with the result
    clipper2_paths_d_destroy(result_impl->paths);
    result_impl->paths = result_paths;
    
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
    if (!subject || !clip) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* subject_impl = static_cast<anigma_vector_capsule_impl*>(subject);
    auto* clip_impl = static_cast<anigma_vector_capsule_impl*>(clip);
    
    clipper2_paths_d_t* result_paths = nullptr;
    if (!perform_boolean_op(subject_impl->paths, clip_impl->paths, op, fillrule, &result_paths)) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Boolean operation failed";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    // Replace subject's paths with result
    clipper2_paths_d_destroy(subject_impl->paths);
    subject_impl->paths = result_paths;
    
    return ANIGMA_OK;
}

// ----------------------------------------------------------------------------
// Export Functions
// ----------------------------------------------------------------------------

anigma_status_t anigma_vector_capsule_export_to_svg(
    anigma_vector_capsule_t handle,
    char** out_svg_string,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_svg_string) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    std::string svg = generate_svg_path_string(impl->paths);
    
    char* copy = anigma_capsule_copy_string(svg.c_str(), err);
    if (!copy) {
        return ANIGMA_ERR_INTERNAL;
    }
    
    *out_svg_string = copy;
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_export_canonical(
    anigma_vector_capsule_t handle,
    anigma_capsule_buffer_t* out_buffer,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_buffer) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    std::vector<uint8_t> canonical = paths_to_canonical(impl->paths);
    
    // Two-phase filling pattern
    if (!out_buffer->ptr || out_buffer->cap == 0) {
        return anigma_capsule_query_output_size(err, canonical.size());
    }
    
    if (out_buffer->cap < canonical.size()) {
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
    if (!buffer || !buffer->ptr || !out_handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = new (std::nothrow) anigma_vector_capsule_impl;
    if (!impl) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate vector capsule";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    impl->paths = clipper2_paths_d_create();
    if (!impl->paths) {
        delete impl;
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to create paths container";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    if (!canonical_to_paths(buffer->ptr, buffer->len, impl->paths)) {
        delete impl;
        if (err) {
            err->code = ANIGMA_ERR_CORRUPT_DATA;
            err->message = "Failed to parse canonical format";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_CORRUPT_DATA;
    }
    
    *out_handle = impl;
    return ANIGMA_OK;
}

// ----------------------------------------------------------------------------
// Utility Functions
// ----------------------------------------------------------------------------

anigma_status_t anigma_vector_capsule_is_empty(
    anigma_vector_capsule_t handle,
    bool* out_empty,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_empty) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
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
    if (!handle || !out_min_x || !out_min_y || !out_max_x || !out_max_y) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    size_t num_paths = clipper2_paths_d_size(impl->paths);
    if (num_paths == 0) {
        *out_min_x = *out_min_y = *out_max_x = *out_max_y = 0.0;
        return ANIGMA_OK;
    }
    
    bool first = true;
    double min_x = 0.0, min_y = 0.0, max_x = 0.0, max_y = 0.0;
    for (size_t i = 0; i < num_paths; ++i) {
        const clipper2_path_d_t* path = clipper2_paths_d_get_path(impl->paths, i);
        if (!path) continue;
        size_t num_points = clipper2_path_d_size(path);
        for (size_t j = 0; j < num_points; ++j) {
            clipper2_point_d_t pt = clipper2_path_d_get_point(path, j);
            if (first) {
                min_x = max_x = pt.x;
                min_y = max_y = pt.y;
                first = false;
            } else {
                if (pt.x < min_x) min_x = pt.x;
                if (pt.x > max_x) max_x = pt.x;
                if (pt.y < min_y) min_y = pt.y;
                if (pt.y > max_y) max_y = pt.y;
            }
        }
    }
    
    *out_min_x = min_x;
    *out_min_y = min_y;
    *out_max_x = max_x;
    *out_max_y = max_y;
    return ANIGMA_OK;
}

} // extern "C"
