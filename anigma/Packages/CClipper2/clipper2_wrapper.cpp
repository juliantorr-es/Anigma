#include "clipper2_wrapper.h"

#include <vector>
#include <memory>
#include <cstring>
#include <stdexcept>
#include <string>

// Clipper2 headers (assumes include paths are set correctly)
#include <clipper2/clipper.h>
#include <clipper2/clipper.offset.h>
#include <clipper.svg.h>
#include <clipper.svg.utils.h>

// -----------------------------------------------------------------------------
// Internal type definitions
// -----------------------------------------------------------------------------

struct clipper2_paths64 {
    std::vector<Clipper2Lib::Path64> paths;
};

struct clipper2_path64 {
    Clipper2Lib::Path64 path;
};

struct clipper2_paths_d {
    std::vector<Clipper2Lib::PathD> paths;
};

struct clipper2_path_d {
    Clipper2Lib::PathD path;
};

// Rect structures not used yet but defined for completeness
struct clipper2_rect64 {
    Clipper2Lib::Rect64 rect;
};

struct clipper2_rect_d {
    Clipper2Lib::RectD rect;
};

// -----------------------------------------------------------------------------
// Utility conversion functions
// -----------------------------------------------------------------------------

static Clipper2Lib::FillRule to_fillrule(clipper2_fillrule_t fr) {
    switch (fr) {
        case CLIPPER2_FILLRULE_EVEN_ODD:   return Clipper2Lib::FillRule::EvenOdd;
        case CLIPPER2_FILLRULE_NON_ZERO:   return Clipper2Lib::FillRule::NonZero;
        case CLIPPER2_FILLRULE_POSITIVE:   return Clipper2Lib::FillRule::Positive;
        case CLIPPER2_FILLRULE_NEGATIVE:   return Clipper2Lib::FillRule::Negative;
        default:                           return Clipper2Lib::FillRule::EvenOdd;
    }
}


static Clipper2Lib::JoinType to_jointype(clipper2_jointype_t jt) {
    switch (jt) {
        case CLIPPER2_JOINTYPE_SQUARE: return Clipper2Lib::JoinType::Square;
        case CLIPPER2_JOINTYPE_ROUND:  return Clipper2Lib::JoinType::Round;
        case CLIPPER2_JOINTYPE_MITER:  return Clipper2Lib::JoinType::Miter;
        default:                       return Clipper2Lib::JoinType::Square;
    }
}

static Clipper2Lib::EndType to_endtype(clipper2_endtype_t et) {
    switch (et) {
        case CLIPPER2_ENDTYPE_SQUARE:  return Clipper2Lib::EndType::Square;
        case CLIPPER2_ENDTYPE_ROUND:   return Clipper2Lib::EndType::Round;
        case CLIPPER2_ENDTYPE_BUTT:    return Clipper2Lib::EndType::Butt;
        case CLIPPER2_ENDTYPE_POLYGON: return Clipper2Lib::EndType::Polygon;
        default:                       return Clipper2Lib::EndType::Square;
    }
}

// -----------------------------------------------------------------------------
// Memory management functions
// -----------------------------------------------------------------------------

void clipper2_paths64_destroy(clipper2_paths64_t* paths) {
    if (paths) delete reinterpret_cast<clipper2_paths64*>(paths);
}

void clipper2_path64_destroy(clipper2_path64_t* path) {
    if (path) delete reinterpret_cast<clipper2_path64*>(path);
}

void clipper2_paths_d_destroy(clipper2_paths_d_t* paths) {
    if (paths) delete reinterpret_cast<clipper2_paths_d*>(paths);
}

void clipper2_path_d_destroy(clipper2_path_d_t* path) {
    if (path) delete reinterpret_cast<clipper2_path_d*>(path);
}

// -----------------------------------------------------------------------------
// Creation functions
// -----------------------------------------------------------------------------

clipper2_paths64_t* clipper2_paths64_create(void) {
    try {
        return reinterpret_cast<clipper2_paths64_t*>(new clipper2_paths64);
    } catch (...) {
        return nullptr;
    }
}

clipper2_path64_t* clipper2_path64_create(void) {
    try {
        return reinterpret_cast<clipper2_path64_t*>(new clipper2_path64);
    } catch (...) {
        return nullptr;
    }
}

clipper2_paths_d_t* clipper2_paths_d_create(void) {
    try {
        return reinterpret_cast<clipper2_paths_d_t*>(new clipper2_paths_d);
    } catch (...) {
        return nullptr;
    }
}

clipper2_path_d_t* clipper2_path_d_create(void) {
    try {
        return reinterpret_cast<clipper2_path_d_t*>(new clipper2_path_d);
    } catch (...) {
        return nullptr;
    }
}

// -----------------------------------------------------------------------------
// Path operations
// -----------------------------------------------------------------------------

void clipper2_path64_add_point(clipper2_path64_t* path, int64_t x, int64_t y) {
    if (!path) return;
    auto p = reinterpret_cast<clipper2_path64*>(path);
    p->path.emplace_back(x, y);
}

void clipper2_path_d_add_point(clipper2_path_d_t* path, double x, double y) {
    if (!path) return;
    auto p = reinterpret_cast<clipper2_path_d*>(path);
    p->path.emplace_back(x, y);
}

void clipper2_paths64_add_path(clipper2_paths64_t* paths, const clipper2_path64_t* path) {
    if (!paths || !path) return;
    auto ps = reinterpret_cast<clipper2_paths64*>(paths);
    const auto p = reinterpret_cast<const clipper2_path64*>(path);
    ps->paths.push_back(p->path);
}

void clipper2_paths_d_add_path(clipper2_paths_d_t* paths, const clipper2_path_d_t* path) {
    if (!paths || !path) return;
    auto ps = reinterpret_cast<clipper2_paths_d*>(paths);
    const auto p = reinterpret_cast<const clipper2_path_d*>(path);
    ps->paths.push_back(p->path);
}

// -----------------------------------------------------------------------------
// Access functions for paths
// -----------------------------------------------------------------------------

size_t clipper2_paths64_size(const clipper2_paths64_t* paths) {
    if (!paths) return 0;
    const auto ps = reinterpret_cast<const clipper2_paths64*>(paths);
    return ps->paths.size();
}

size_t clipper2_path64_size(const clipper2_path64_t* path) {
    if (!path) return 0;
    const auto p = reinterpret_cast<const clipper2_path64*>(path);
    return p->path.size();
}

clipper2_point64_t clipper2_path64_get_point(const clipper2_path64_t* path, size_t index) {
    if (!path) return {0, 0};
    const auto p = reinterpret_cast<const clipper2_path64*>(path);
    if (index >= p->path.size()) return {0, 0};
    const auto& pt = p->path[index];
    return {pt.x, pt.y};
}

const clipper2_path64_t* clipper2_paths64_get_path(const clipper2_paths64_t* paths, size_t index) {
    if (!paths) return nullptr;
    const auto ps = reinterpret_cast<const clipper2_paths64*>(paths);
    if (index >= ps->paths.size()) return nullptr;
    // Since clipper2_path64 is a struct with a single Path64 member,
    // we can reinterpret the address of the Path64 element as a pointer to clipper2_path64.
    // This is safe because the struct is standard layout and the member is first.
    const Clipper2Lib::Path64& internal_path = ps->paths[index];
    return reinterpret_cast<const clipper2_path64_t*>(&internal_path);
}

size_t clipper2_paths_d_size(const clipper2_paths_d_t* paths) {
    if (!paths) return 0;
    const auto ps = reinterpret_cast<const clipper2_paths_d*>(paths);
    return ps->paths.size();
}

size_t clipper2_path_d_size(const clipper2_path_d_t* path) {
    if (!path) return 0;
    const auto p = reinterpret_cast<const clipper2_path_d*>(path);
    return p->path.size();
}

clipper2_point_d_t clipper2_path_d_get_point(const clipper2_path_d_t* path, size_t index) {
    if (!path) return {0.0, 0.0};
    const auto p = reinterpret_cast<const clipper2_path_d*>(path);
    if (index >= p->path.size()) return {0.0, 0.0};
    const auto& pt = p->path[index];
    return {pt.x, pt.y};
}

const clipper2_path_d_t* clipper2_paths_d_get_path(const clipper2_paths_d_t* paths, size_t index) {
    if (!paths) return nullptr;
    const auto ps = reinterpret_cast<const clipper2_paths_d*>(paths);
    if (index >= ps->paths.size()) return nullptr;
    const Clipper2Lib::PathD& internal_path = ps->paths[index];
    return reinterpret_cast<const clipper2_path_d_t*>(&internal_path);
}

// -----------------------------------------------------------------------------
// Boolean operations (64-bit integer)
// -----------------------------------------------------------------------------

static clipper2_paths64_t* boolean_op_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule,
    Clipper2Lib::ClipType cliptype)
{
    if (!subjects || !clips) return nullptr;
    try {
        const auto subj = reinterpret_cast<const clipper2_paths64*>(subjects);
        const auto clip = reinterpret_cast<const clipper2_paths64*>(clips);
        Clipper2Lib::Paths64 result = Clipper2Lib::BooleanOp(
            cliptype,
            to_fillrule(fillrule),
            subj->paths,
            clip->paths);
        auto* out = new clipper2_paths64;
        out->paths = std::move(result);
        return reinterpret_cast<clipper2_paths64_t*>(out);
    } catch (...) {
        return nullptr;
    }
}

clipper2_paths64_t* clipper2_intersect_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule)
{
    return boolean_op_64(subjects, clips, fillrule, Clipper2Lib::ClipType::Intersection);
}

clipper2_paths64_t* clipper2_union_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule)
{
    return boolean_op_64(subjects, clips, fillrule, Clipper2Lib::ClipType::Union);
}

clipper2_paths64_t* clipper2_difference_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule)
{
    return boolean_op_64(subjects, clips, fillrule, Clipper2Lib::ClipType::Difference);
}

clipper2_paths64_t* clipper2_xor_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule)
{
    return boolean_op_64(subjects, clips, fillrule, Clipper2Lib::ClipType::Xor);
}

// -----------------------------------------------------------------------------
// Boolean operations (double precision)
// -----------------------------------------------------------------------------

static clipper2_paths_d_t* boolean_op_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision,
    Clipper2Lib::ClipType cliptype)
{
    if (!subjects || !clips) return nullptr;
    try {
        const auto subj = reinterpret_cast<const clipper2_paths_d*>(subjects);
        const auto clip = reinterpret_cast<const clipper2_paths_d*>(clips);
        Clipper2Lib::PathsD result = Clipper2Lib::BooleanOp(
            cliptype,
            to_fillrule(fillrule),
            subj->paths,
            clip->paths,
            precision);
        auto* out = new clipper2_paths_d;
        out->paths = std::move(result);
        return reinterpret_cast<clipper2_paths_d_t*>(out);
    } catch (...) {
        return nullptr;
    }
}

clipper2_paths_d_t* clipper2_intersect_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision)
{
    return boolean_op_d(subjects, clips, fillrule, precision, Clipper2Lib::ClipType::Intersection);
}

clipper2_paths_d_t* clipper2_union_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision)
{
    return boolean_op_d(subjects, clips, fillrule, precision, Clipper2Lib::ClipType::Union);
}

clipper2_paths_d_t* clipper2_difference_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision)
{
    return boolean_op_d(subjects, clips, fillrule, precision, Clipper2Lib::ClipType::Difference);
}

clipper2_paths_d_t* clipper2_xor_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision)
{
    return boolean_op_d(subjects, clips, fillrule, precision, Clipper2Lib::ClipType::Xor);
}

// -----------------------------------------------------------------------------
// Inflate (offset) operations
// -----------------------------------------------------------------------------

clipper2_paths64_t* clipper2_inflate_paths_64(
    const clipper2_paths64_t* paths,
    double delta,
    clipper2_jointype_t jointype,
    clipper2_endtype_t endtype,
    double miter_limit,
    double arc_tolerance)
{
    if (!paths) return nullptr;
    try {
        const auto p = reinterpret_cast<const clipper2_paths64*>(paths);
        Clipper2Lib::Paths64 result = Clipper2Lib::InflatePaths(
            p->paths,
            delta,
            to_jointype(jointype),
            to_endtype(endtype),
            miter_limit,
            arc_tolerance);
        auto* out = new clipper2_paths64;
        out->paths = std::move(result);
        return reinterpret_cast<clipper2_paths64_t*>(out);
    } catch (...) {
        return nullptr;
    }
}

clipper2_paths_d_t* clipper2_inflate_paths_d(
    const clipper2_paths_d_t* paths,
    double delta,
    clipper2_jointype_t jointype,
    clipper2_endtype_t endtype,
    double miter_limit,
    int precision,
    double arc_tolerance)
{
    if (!paths) return nullptr;
    try {
        const auto p = reinterpret_cast<const clipper2_paths_d*>(paths);
        Clipper2Lib::PathsD result = Clipper2Lib::InflatePaths(
            p->paths,
            delta,
            to_jointype(jointype),
            to_endtype(endtype),
            miter_limit,
            precision,
            arc_tolerance);
        auto* out = new clipper2_paths_d;
        out->paths = std::move(result);
        return reinterpret_cast<clipper2_paths_d_t*>(out);
    } catch (...) {
        return nullptr;
    }
}

// -----------------------------------------------------------------------------
// SVG import/export
// -----------------------------------------------------------------------------

clipper2_paths64_t* clipper2_svg_load_paths64(const char* filename) {
    if (!filename) return nullptr;
    try {
        Clipper2Lib::SvgReader reader(filename);
        // Convert PathsD to Paths64 using ScalePaths with scale 1.0
        int error_code = 0;
        Clipper2Lib::Paths64 paths64 = Clipper2Lib::ScalePaths<int64_t, double>(
            reader.paths, 1.0, 1.0, error_code);
        if (error_code != 0) {
            return nullptr;
        }
        auto* out = new clipper2_paths64;
        out->paths = std::move(paths64);
        return reinterpret_cast<clipper2_paths64_t*>(out);
    } catch (...) {
        return nullptr;
    }
}

clipper2_paths_d_t* clipper2_svg_load_paths_d(const char* filename) {
    if (!filename) return nullptr;
    try {
        Clipper2Lib::SvgReader reader(filename);
        auto* out = new clipper2_paths_d;
        out->paths = reader.paths;
        return reinterpret_cast<clipper2_paths_d_t*>(out);
    } catch (...) {
        return nullptr;
    }
}

bool clipper2_svg_save_paths64(const char* filename, const clipper2_paths64_t* paths,
    int max_width, int max_height, int margin)
{
    if (!filename || !paths) return false;
    try {
        const auto p = reinterpret_cast<const clipper2_paths64*>(paths);
        Clipper2Lib::SvgWriter writer;
        writer.AddPaths(p->paths, false, Clipper2Lib::FillRule::EvenOdd,
            0xFF0000FF, 0xFF000000, 1.0, false);
        return writer.SaveToFile(filename, max_width, max_height, margin);
    } catch (...) {
        return false;
    }
}

bool clipper2_svg_save_paths_d(const char* filename, const clipper2_paths_d_t* paths,
    int max_width, int max_height, int margin)
{
    if (!filename || !paths) return false;
    try {
        const auto p = reinterpret_cast<const clipper2_paths_d*>(paths);
        Clipper2Lib::SvgWriter writer;
        writer.AddPaths(p->paths, false, Clipper2Lib::FillRule::EvenOdd,
            0xFF0000FF, 0xFF000000, 1.0, false);
        return writer.SaveToFile(filename, max_width, max_height, margin);
    } catch (...) {
        return false;
    }
}