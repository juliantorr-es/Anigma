#include "anigma_geometry_capsule.h"

// Include Clipper2 headers
// Assumes include path is set to src/Clipper2Lib/include
#include "clipper2/clipper.h"
#include "clipper2/clipper.offset.h"
// #include "clipper.svg.h" // If we need SVG support, we need to include Utils headers and source

#include <vector>
#include <new>
#include <cstring>

// -----------------------------------------------------------------------------
// Internal Types
// -----------------------------------------------------------------------------

struct GeometryPaths64 {
    Clipper2Lib::Paths64 paths;
};

struct GeometryPathsD {
    Clipper2Lib::PathsD paths;
};

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

static void set_error(anigma_capsule_error_t* err, const char* msg) {
    if (err) {
        // Simple error setting, assuming err->message is a fixed buffer or handled elsewhere
        // For this implementation we might just log or ignore if struct doesn't support string copy properly yet
        // standard anigma_capsule_error_t usually has a char buffer
    }
}

static Clipper2Lib::FillRule to_fillrule(anigma_geometry_fillrule_t fr) {
    switch (fr) {
        case ANIGMA_GEOMETRY_FILL_EVEN_ODD: return Clipper2Lib::FillRule::EvenOdd;
        case ANIGMA_GEOMETRY_FILL_NON_ZERO: return Clipper2Lib::FillRule::NonZero;
        case ANIGMA_GEOMETRY_FILL_POSITIVE: return Clipper2Lib::FillRule::Positive;
        case ANIGMA_GEOMETRY_FILL_NEGATIVE: return Clipper2Lib::FillRule::Negative;
        default: return Clipper2Lib::FillRule::EvenOdd;
    }
}

static Clipper2Lib::JoinType to_jointype(anigma_geometry_jointype_t jt) {
    switch (jt) {
        case ANIGMA_GEOMETRY_JOIN_SQUARE: return Clipper2Lib::JoinType::Square;
        case ANIGMA_GEOMETRY_JOIN_ROUND:  return Clipper2Lib::JoinType::Round;
        case ANIGMA_GEOMETRY_JOIN_MITER:  return Clipper2Lib::JoinType::Miter;
        default: return Clipper2Lib::JoinType::Square;
    }
}

static Clipper2Lib::EndType to_endtype(anigma_geometry_endtype_t et) {
    switch (et) {
        case ANIGMA_GEOMETRY_END_SQUARE:  return Clipper2Lib::EndType::Square;
        case ANIGMA_GEOMETRY_END_ROUND:   return Clipper2Lib::EndType::Round;
        case ANIGMA_GEOMETRY_END_BUTT:    return Clipper2Lib::EndType::Butt;
        case ANIGMA_GEOMETRY_END_POLYGON: return Clipper2Lib::EndType::Polygon;
        default: return Clipper2Lib::EndType::Square;
    }
}

// -----------------------------------------------------------------------------
// Paths64 Implementation
// -----------------------------------------------------------------------------

extern "C" {

anigma_status_t anigma_geometry_paths64_create(
    anigma_geometry_paths64_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPaths64* ptr = new GeometryPaths64();
        *out_handle = reinterpret_cast<anigma_geometry_paths64_t>(ptr);
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
}

anigma_status_t anigma_geometry_paths64_destroy(
    anigma_geometry_paths64_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_OK;
    try {
        GeometryPaths64* ptr = reinterpret_cast<GeometryPaths64*>(handle);
        delete ptr;
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_paths64_add_path_coords(
    anigma_geometry_paths64_t handle,
    const int64_t* coords,
    size_t count,
    bool closed,
    anigma_capsule_error_t* err
) {
    if (!handle || !coords) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPaths64* ptr = reinterpret_cast<GeometryPaths64*>(handle);
        Clipper2Lib::Path64 path;
        path.reserve(count);
        for (size_t i = 0; i < count; ++i) {
            path.emplace_back(coords[2*i], coords[2*i+1]);
        }
        ptr->paths.push_back(std::move(path));
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_paths64_clear(
    anigma_geometry_paths64_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPaths64* ptr = reinterpret_cast<GeometryPaths64*>(handle);
        ptr->paths.clear();
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

static anigma_status_t boolean_op_64(
    anigma_geometry_paths64_t subject,
    anigma_geometry_paths64_t clip,
    anigma_geometry_fillrule_t fillrule,
    Clipper2Lib::ClipType cliptype,
    anigma_geometry_paths64_t* out_result
) {
    if (!subject || !clip || !out_result) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPaths64* s = reinterpret_cast<GeometryPaths64*>(subject);
        GeometryPaths64* c = reinterpret_cast<GeometryPaths64*>(clip);
        
        Clipper2Lib::Paths64 result = Clipper2Lib::BooleanOp(
            cliptype,
            to_fillrule(fillrule),
            s->paths,
            c->paths
        );
        
        GeometryPaths64* res_ptr = new GeometryPaths64();
        res_ptr->paths = std::move(result);
        *out_result = reinterpret_cast<anigma_geometry_paths64_t>(res_ptr);
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_intersect_64(
    anigma_geometry_paths64_t subject,
    anigma_geometry_paths64_t clip,
    anigma_geometry_fillrule_t fillrule,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
) {
    return boolean_op_64(subject, clip, fillrule, Clipper2Lib::ClipType::Intersection, out_result);
}

anigma_status_t anigma_geometry_union_64(
    anigma_geometry_paths64_t subject,
    anigma_geometry_paths64_t clip,
    anigma_geometry_fillrule_t fillrule,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
) {
    return boolean_op_64(subject, clip, fillrule, Clipper2Lib::ClipType::Union, out_result);
}

anigma_status_t anigma_geometry_difference_64(
    anigma_geometry_paths64_t subject,
    anigma_geometry_paths64_t clip,
    anigma_geometry_fillrule_t fillrule,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
) {
    return boolean_op_64(subject, clip, fillrule, Clipper2Lib::ClipType::Difference, out_result);
}

anigma_status_t anigma_geometry_xor_64(
    anigma_geometry_paths64_t subject,
    anigma_geometry_paths64_t clip,
    anigma_geometry_fillrule_t fillrule,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
) {
    return boolean_op_64(subject, clip, fillrule, Clipper2Lib::ClipType::Xor, out_result);
}

anigma_status_t anigma_geometry_inflate_paths_64(
    anigma_geometry_paths64_t paths,
    double delta,
    anigma_geometry_jointype_t jointype,
    anigma_geometry_endtype_t endtype,
    double miter_limit,
    double arc_tolerance,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!paths || !out_result) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPaths64* p = reinterpret_cast<GeometryPaths64*>(paths);
        Clipper2Lib::Paths64 result = Clipper2Lib::InflatePaths(
            p->paths,
            delta,
            to_jointype(jointype),
            to_endtype(endtype),
            miter_limit,
            arc_tolerance
        );
        
        GeometryPaths64* res_ptr = new GeometryPaths64();
        res_ptr->paths = std::move(result);
        *out_result = reinterpret_cast<anigma_geometry_paths64_t>(res_ptr);
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_paths64_count(
    anigma_geometry_paths64_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_count) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPaths64* ptr = reinterpret_cast<GeometryPaths64*>(handle);
        *out_count = ptr->paths.size();
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_paths64_path_count(
    anigma_geometry_paths64_t handle,
    size_t path_index,
    size_t* out_count,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_count) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPaths64* ptr = reinterpret_cast<GeometryPaths64*>(handle);
        if (path_index >= ptr->paths.size()) return ANIGMA_STATUS_OUT_OF_BOUNDS;
        *out_count = ptr->paths[path_index].size();
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_paths64_get_path(
    anigma_geometry_paths64_t handle,
    size_t path_index,
    int64_t* out_coords,
    size_t buffer_size,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_coords) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPaths64* ptr = reinterpret_cast<GeometryPaths64*>(handle);
        if (path_index >= ptr->paths.size()) return ANIGMA_STATUS_OUT_OF_BOUNDS;
        const auto& path = ptr->paths[path_index];
        if (buffer_size < path.size()) return ANIGMA_STATUS_BUFFER_TOO_SMALL;
        
        for (size_t i = 0; i < path.size(); ++i) {
            out_coords[2*i] = path[i].x;
            out_coords[2*i+1] = path[i].y;
        }
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

// -----------------------------------------------------------------------------
// PathsD Implementation
// -----------------------------------------------------------------------------

anigma_status_t anigma_geometry_paths_d_create(
    anigma_geometry_paths_d_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPathsD* ptr = new GeometryPathsD();
        *out_handle = reinterpret_cast<anigma_geometry_paths_d_t>(ptr);
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
}

anigma_status_t anigma_geometry_paths_d_destroy(
    anigma_geometry_paths_d_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_OK;
    try {
        GeometryPathsD* ptr = reinterpret_cast<GeometryPathsD*>(handle);
        delete ptr;
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_paths_d_add_path_coords(
    anigma_geometry_paths_d_t handle,
    const double* coords,
    size_t count,
    anigma_capsule_error_t* err
) {
    if (!handle || !coords) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPathsD* ptr = reinterpret_cast<GeometryPathsD*>(handle);
        Clipper2Lib::PathD path;
        path.reserve(count);
        for (size_t i = 0; i < count; ++i) {
            path.emplace_back(coords[2*i], coords[2*i+1]);
        }
        ptr->paths.push_back(std::move(path));
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

static anigma_status_t boolean_op_d(
    anigma_geometry_paths_d_t subject,
    anigma_geometry_paths_d_t clip,
    anigma_geometry_fillrule_t fillrule,
    int precision,
    Clipper2Lib::ClipType cliptype,
    anigma_geometry_paths_d_t* out_result
) {
    if (!subject || !clip || !out_result) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPathsD* s = reinterpret_cast<GeometryPathsD*>(subject);
        GeometryPathsD* c = reinterpret_cast<GeometryPathsD*>(clip);
        
        Clipper2Lib::PathsD result = Clipper2Lib::BooleanOp(
            cliptype,
            to_fillrule(fillrule),
            s->paths,
            c->paths,
            precision
        );
        
        GeometryPathsD* res_ptr = new GeometryPathsD();
        res_ptr->paths = std::move(result);
        *out_result = reinterpret_cast<anigma_geometry_paths_d_t>(res_ptr);
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_intersect_d(
    anigma_geometry_paths_d_t subject,
    anigma_geometry_paths_d_t clip,
    anigma_geometry_fillrule_t fillrule,
    int precision,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
) {
    return boolean_op_d(subject, clip, fillrule, precision, Clipper2Lib::ClipType::Intersection, out_result);
}

anigma_status_t anigma_geometry_union_d(
    anigma_geometry_paths_d_t subject,
    anigma_geometry_paths_d_t clip,
    anigma_geometry_fillrule_t fillrule,
    int precision,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
) {
    return boolean_op_d(subject, clip, fillrule, precision, Clipper2Lib::ClipType::Union, out_result);
}

anigma_status_t anigma_geometry_difference_d(
    anigma_geometry_paths_d_t subject,
    anigma_geometry_paths_d_t clip,
    anigma_geometry_fillrule_t fillrule,
    int precision,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
) {
    return boolean_op_d(subject, clip, fillrule, precision, Clipper2Lib::ClipType::Difference, out_result);
}

anigma_status_t anigma_geometry_xor_d(
    anigma_geometry_paths_d_t subject,
    anigma_geometry_paths_d_t clip,
    anigma_geometry_fillrule_t fillrule,
    int precision,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
) {
    return boolean_op_d(subject, clip, fillrule, precision, Clipper2Lib::ClipType::Xor, out_result);
}

anigma_status_t anigma_geometry_inflate_paths_d(
    anigma_geometry_paths_d_t paths,
    double delta,
    anigma_geometry_jointype_t jointype,
    anigma_geometry_endtype_t endtype,
    double miter_limit,
    int precision,
    double arc_tolerance,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
) {
    if (!paths || !out_result) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPathsD* p = reinterpret_cast<GeometryPathsD*>(paths);
        Clipper2Lib::PathsD result = Clipper2Lib::InflatePaths(
            p->paths,
            delta,
            to_jointype(jointype),
            to_endtype(endtype),
            miter_limit,
            precision,
            arc_tolerance
        );
        
        GeometryPathsD* res_ptr = new GeometryPathsD();
        res_ptr->paths = std::move(result);
        *out_result = reinterpret_cast<anigma_geometry_paths_d_t>(res_ptr);
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_paths_d_count(
    anigma_geometry_paths_d_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_count) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPathsD* ptr = reinterpret_cast<GeometryPathsD*>(handle);
        *out_count = ptr->paths.size();
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_paths_d_path_count(
    anigma_geometry_paths_d_t handle,
    size_t path_index,
    size_t* out_count,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_count) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPathsD* ptr = reinterpret_cast<GeometryPathsD*>(handle);
        if (path_index >= ptr->paths.size()) return ANIGMA_STATUS_OUT_OF_BOUNDS;
        *out_count = ptr->paths[path_index].size();
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_geometry_paths_d_get_path(
    anigma_geometry_paths_d_t handle,
    size_t path_index,
    double* out_coords,
    size_t buffer_size,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_coords) return ANIGMA_ERR_INVALID_ARG;
    try {
        GeometryPathsD* ptr = reinterpret_cast<GeometryPathsD*>(handle);
        if (path_index >= ptr->paths.size()) return ANIGMA_STATUS_OUT_OF_BOUNDS;
        const auto& path = ptr->paths[path_index];
        if (buffer_size < path.size()) return ANIGMA_STATUS_BUFFER_TOO_SMALL;
        
        for (size_t i = 0; i < path.size(); ++i) {
            out_coords[2*i] = path[i].x;
            out_coords[2*i+1] = path[i].y;
        }
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

} // extern "C"
