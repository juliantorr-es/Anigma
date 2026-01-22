#include "../../include/anigma_vector_capsule.h"
#include "../../include/anigma_capsule_core.h"
#include <vector>
#include <cstring>
#include <cmath>
#include <limits>
#include <string>
#include <memory>
#include <cstdio>

// Clipper2 wrapper functions
extern "C" {
#include "../../../../Packages/CClipper2/clipper2_wrapper.h"
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

// ============================================================================
// Path Simplification Functions
// ============================================================================

anigma_status_t anigma_vector_capsule_simplify_douglas_peucker(
    anigma_vector_capsule_t handle,
    double tolerance,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!handle || tolerance < 0.0 || !out_result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    
    // Apply Douglas-Peucker simplification
    clipper2_paths_d_t* simplified = clipper2_paths_d_simplify(impl->paths, tolerance);
    if (!simplified) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Simplification failed";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    // Create new capsule with simplified paths
    auto* result_impl = new anigma_vector_capsule_impl();
    result_impl->paths = simplified;
    result_impl->fillrule = impl->fillrule;
    
    *out_result = static_cast<anigma_vector_capsule_t>(result_impl);
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_simplify_visvalingam(
    anigma_vector_capsule_t handle,
    double tolerance,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!handle || tolerance < 0.0 || !out_result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    
    // For now, use Douglas-Peucker as fallback
    // In production, implement Visvalingam algorithm
    clipper2_paths_d_t* simplified = clipper2_paths_d_simplify(impl->paths, tolerance * 2.0);
    if (!simplified) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Simplification failed";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    auto* result_impl = new anigma_vector_capsule_impl();
    result_impl->paths = simplified;
    result_impl->fillrule = impl->fillrule;
    
    *out_result = static_cast<anigma_vector_capsule_t>(result_impl);
    return ANIGMA_OK;
}

// ============================================================================
// Transformation Functions
// ============================================================================

anigma_status_t anigma_vector_capsule_transform(
    anigma_vector_capsule_t handle,
    double a, double b, double c, double d, double e, double f,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    
    // Create transformed paths
    clipper2_paths_d_t* transformed = clipper2_paths_d_transform(impl->paths, a, b, c, d, e, f);
    if (!transformed) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Transformation failed";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    auto* result_impl = new anigma_vector_capsule_impl();
    result_impl->paths = transformed;
    result_impl->fillrule = impl->fillrule;
    
    *out_result = static_cast<anigma_vector_capsule_t>(result_impl);
    return ANIGMA_OK;
}

// ============================================================================
// Geometric Primitive Creation Functions
// ============================================================================

anigma_status_t anigma_vector_capsule_create_bezier(
    double start_x, double start_y,
    double control1_x, double control1_y,
    double control2_x, double control2_y,
    double end_x, double end_y,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!out_result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Create Bezier curve points (simplified - in production use proper curve subdivision)
    std::vector<clipper2_point_d_t> points;
    
    // Add control points for approximation
    for (int i = 0; i <= 20; ++i) {
        double t = static_cast<double>(i) / 20.0;
        double u = 1.0 - t;
        double tt = t * t;
        double uu = u * u;
        double uuu = uu * u;
        double ttt = tt * t;
        
        double x = uuu * start_x + 3.0 * uu * t * control1_x + 3.0 * u * tt * control2_x + ttt * end_x;
        double y = uuu * start_y + 3.0 * uu * t * control1_y + 3.0 * u * tt * control2_y + ttt * end_y;
        
        clipper2_point_d_t pt = {x, y};
        points.push_back(pt);
    }
    
    // Create path with points
    clipper2_path_d_t* path = clipper2_path_d_create();
    for (const auto& pt : points) {
        clipper2_path_d_add_point(path, pt);
    }
    
    // Create paths container
    clipper2_paths_d_t* paths = clipper2_paths_d_create();
    clipper2_paths_d_add_path(paths, path);
    
    auto* result_impl = new anigma_vector_capsule_impl();
    result_impl->paths = paths;
    result_impl->fillrule = ANIGMA_VECTOR_FILL_EVEN_ODD;
    
    *out_result = static_cast<anigma_vector_capsule_t>(result_impl);
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_create_arc(
    double center_x, double center_y,
    double radius,
    double start_angle,
    double end_angle,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!out_result || radius < 0.0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Create arc points
    std::vector<clipper2_point_d_t> points;
    
    int segments = 50;
    double angle_step = (end_angle - start_angle) / segments;
    
    for (int i = 0; i <= segments; ++i) {
        double angle = start_angle + i * angle_step;
        double x = center_x + radius * cos(angle);
        double y = center_y + radius * sin(angle);
        
        clipper2_point_d_t pt = {x, y};
        points.push_back(pt);
    }
    
    // Create path with points
    clipper2_path_d_t* path = clipper2_path_d_create();
    for (const auto& pt : points) {
        clipper2_path_d_add_point(path, pt);
    }
    
    // Create paths container
    clipper2_paths_d_t* paths = clipper2_paths_d_create();
    clipper2_paths_d_add_path(paths, path);
    
    auto* result_impl = new anigma_vector_capsule_impl();
    result_impl->paths = paths;
    result_impl->fillrule = ANIGMA_VECTOR_FILL_EVEN_ODD;
    
    *out_result = static_cast<anigma_vector_capsule_t>(result_impl);
    return ANIGMA_OK;
}

// ============================================================================
// Geometric Predicate Functions
// ============================================================================

anigma_status_t anigma_vector_capsule_point_in_polygon(
    anigma_vector_capsule_t handle,
    double x, double y,
    bool* out_result,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    
    // Use Clipper2 point-in-polygon test
    clipper2_point_d_t pt = {x, y};
    *out_result = clipper2_paths_d_point_in_polygon(impl->paths, pt);
    
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_line_intersection(
    double line1_start_x, double line1_start_y,
    double line1_end_x, double line1_end_y,
    double line2_start_x, double line2_start_y,
    double line2_end_x, double line2_end_y,
    bool* out_has_intersection,
    double* out_x, double* out_y,
    anigma_capsule_error_t* err
) {
    if (!out_has_intersection || !out_x || !out_y) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Line-line intersection calculation
    double x1 = line1_start_x, y1 = line1_start_y;
    double x2 = line1_end_x, y2 = line1_end_y;
    double x3 = line2_start_x, y3 = line2_start_y;
    double x4 = line2_end_x, y4 = line2_end_y;
    
    double denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    
    if (fabs(denom) < std::numeric_limits<double>::epsilon()) {
        // Lines are parallel
        *out_has_intersection = false;
        *out_x = *out_y = 0.0;
        return ANIGMA_OK;
    }
    
    double t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
    double u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom;
    
    if (t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0) {
        // Intersection exists within both line segments
        *out_has_intersection = true;
        *out_x = x1 + t * (x2 - x1);
        *out_y = y1 + t * (y2 - y1);
    } else {
        *out_has_intersection = false;
        *out_x = *out_y = 0.0;
    }
    
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_point_to_line_distance(
    double point_x, double point_y,
    double line_start_x, double line_start_y,
    double line_end_x, double line_end_y,
    double* out_distance,
    anigma_capsule_error_t* err
) {
    if (!out_distance) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Point-to-line-segment distance calculation
    double A = point_x - line_start_x;
    double B = point_y - line_start_y;
    double C = line_end_x - line_start_x;
    double D = line_end_y - line_start_y;
    
    double dot = A * C + B * D;
    double len_sq = C * C + D * D;
    
    if (len_sq < std::numeric_limits<double>::epsilon()) {
        // Line segment is a point
        *out_distance = sqrt(A * A + B * B);
        return ANIGMA_OK;
    }
    
    double param = dot / len_sq;
    
    double xx, yy;
    if (param < 0.0) {
        xx = line_start_x;
        yy = line_start_y;
    } else if (param > 1.0) {
        xx = line_end_x;
        yy = line_end_y;
    } else {
        xx = line_start_x + param * C;
        yy = line_start_y + param * D;
    }
    
    double dx = point_x - xx;
    double dy = point_y - yy;
    *out_distance = sqrt(dx * dx + dy * dy);
    
    return ANIGMA_OK;
}

// ============================================================================
// Additional Utility Functions
// ============================================================================

anigma_status_t anigma_vector_capsule_get_length(
    anigma_vector_capsule_t handle,
    double* out_length,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_length) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    
    double total_length = 0.0;
    size_t num_paths = clipper2_paths_d_size(impl->paths);
    
    for (size_t i = 0; i < num_paths; ++i) {
        const clipper2_path_d_t* path = clipper2_paths_d_get_path(impl->paths, i);
        if (!path) continue;
        
        size_t num_points = clipper2_path_d_size(path);
        if (num_points < 2) continue;
        
        clipper2_point_d_t prev_pt = clipper2_path_d_get_point(path, 0);
        
        for (size_t j = 1; j < num_points; ++j) {
            clipper2_point_d_t curr_pt = clipper2_path_d_get_point(path, j);
            double dx = curr_pt.x - prev_pt.x;
            double dy = curr_pt.y - prev_pt.y;
            total_length += sqrt(dx * dx + dy * dy);
            prev_pt = curr_pt;
        }
    }
    
    *out_length = total_length;
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_capsule_smooth_path(
    anigma_vector_capsule_t handle,
    double factor,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!handle || factor < 0.0 || factor > 1.0 || !out_result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<anigma_vector_capsule_impl*>(handle);
    
    // For now, apply simplification with tolerance proportional to factor
    // In production, implement proper curve smoothing algorithm
    double tolerance = factor * 10.0;
    clipper2_paths_d_t* smoothed = clipper2_paths_d_simplify(impl->paths, tolerance);
    if (!smoothed) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Smoothing failed";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
    
    auto* result_impl = new anigma_vector_capsule_impl();
    result_impl->paths = smoothed;
    result_impl->fillrule = impl->fillrule;
    
    *out_result = static_cast<anigma_vector_capsule_t>(result_impl);
    return ANIGMA_OK;
}

} // extern "C"