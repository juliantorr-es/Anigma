#include "../include/anigma_vector_capsule.h"
#include <unordered_map>
#include <vector>
#include <chrono>
#include <algorithm>
#include <cstring>
#include <memory>
#include <sstream>
#include <cmath>

using std::vector;
using std::unordered_map;

// Internal path storage with fixed-point coordinates
struct InternalPath {
    vector<double> points;  // x1, y1, x2, y2, ...
    bool closed;
    
    InternalPath() : closed(false) {}
    
    // Calculate area (deterministic)
    double area() const {
        if (points.size() < 6) return 0.0;  // Need at least 3 points
        
        double area = 0.0;
        size_t n = points.size() / 2;
        for (size_t i = 0; i < n; ++i) {
            size_t j = (i + 1) % n;
            double x1 = points[2 * i];
            double y1 = points[2 * i + 1];
            double x2 = points[2 * j];
            double y2 = points[2 * j + 1];
            area += (x2 - x1) * (y2 + y1);
        }
        return area / 2.0;
    }
    
    // Calculate centroid (deterministic)
    double centroid_x() const {
        if (points.empty()) return 0.0;
        double sum = 0.0;
        for (size_t i = 0; i < points.size(); i += 2) {
            sum += points[i];
        }
        return sum / (points.size() / 2);
    }
    
    double centroid_y() const {
        if (points.empty()) return 0.0;
        double sum = 0.0;
        for (size_t i = 1; i < points.size(); i += 2) {
            sum += points[i];
        }
        return sum / (points.size() / 2);
    }
};

struct VectorCapsule {
    uint64_t next_path_id;
    unordered_map<uint64_t, std::unique_ptr<InternalPath>> paths;
    uint32_t determinism_tier;
    
    VectorCapsule() : next_path_id(1), determinism_tier(1) {}
    
    // Normalize path for deterministic output
    void normalize_path(InternalPath& path) {
        if (path.points.size() < 6) return;  // Need at least 3 points
        
        // Remove duplicate last point for closed paths
        if (path.closed && path.points.size() >= 4) {
            if (path.points[0] == path.points[path.points.size() - 2] &&
                path.points[1] == path.points[path.points.size() - 1]) {
                path.points.pop_back();
                path.points.pop_back();
            }
        }
        
        // Simplify collinear segments (basic implementation)
        bool changed;
        do {
            changed = false;
            vector<double> new_points;
            new_points.reserve(path.points.size());
            
            if (path.points.size() >= 6) {
                new_points.push_back(path.points[0]);
                new_points.push_back(path.points[1]);
                
                for (size_t i = 2; i < path.points.size() - 2; i += 2) {
                    double x1 = path.points[i - 2];
                    double y1 = path.points[i - 1];
                    double x2 = path.points[i];
                    double y2 = path.points[i + 1];
                    double x3 = path.points[i + 2];
                    double y3 = path.points[i + 3];
                    
                    // Check if three points are collinear
                    double cross = (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1);
                    if (std::abs(cross) > 1e-10) {
                        new_points.push_back(x2);
                        new_points.push_back(y2);
                    } else {
                        changed = true;
                    }
                }
                
                new_points.push_back(path.points[path.points.size() - 2]);
                new_points.push_back(path.points[path.points.size() - 1]);
                
                if (new_points.size() < path.points.size()) {
                    path.points = new_points;
                }
            }
        } while (changed);
    }
    
    // Deterministic path sorting for output
    struct PathComparator {
        bool operator()(const InternalPath* a, const InternalPath* b) const {
            if (!a || !b) return a < b;
            
            // Sort by area first
            double area_a = a->area();
            double area_b = b->area();
            if (std::abs(area_a - area_b) > 1e-10) return area_a < area_b;
            
            // Then by centroid
            double cx_a = a->centroid_x();
            double cy_a = a->centroid_y();
            double cx_b = b->centroid_x();
            double cy_b = b->centroid_y();
            
            if (std::abs(cx_a - cx_b) > 1e-10) return cx_a < cx_b;
            if (std::abs(cy_a - cy_b) > 1e-10) return cy_a < cy_b;
            
            // Finally by start point
            if (a->points.size() >= 2 && b->points.size() >= 2) {
                if (std::abs(a->points[0] - b->points[0]) > 1e-10) {
                    return a->points[0] < b->points[0];
                }
                return a->points[1] < b->points[1];
            }
            
            return a < b;
        }
    };
    
    // Get microseconds timestamp
    uint64_t get_timestamp_us() {
        auto now = std::chrono::steady_clock::now();
        auto duration = now.time_since_epoch();
        return std::chrono::duration_cast<std::chrono::microseconds>(duration).count();
    }
};

// Global capsule registry
static unordered_map<anigma_vector_capsule_t*, std::unique_ptr<VectorCapsule>> g_capsules;
static anigma_vector_capsule_t g_next_handle = 1;

extern "C" {

// Get capsule identity
anigma_capsule_identity_t anigma_vector_capsule_get_identity(void) {
    static const anigma_capsule_identity_t identity = {
        "vector_capsule",
        "v1.0.0-deterministic",
        "1.0.0",
        1  // Tier 1: bitwise deterministic
    };
    return identity;
}

// Create capsule from SVG
anigma_status_t anigma_vector_capsule_create_from_svg(
    const char* svg_path,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!svg_path || !out_handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "svg_path and out_handle must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        // Create new capsule instance
        auto capsule = std::make_unique<VectorCapsule>();
        auto handle = g_next_handle++;
        
        // Parse SVG path to create internal path
        auto path = std::make_unique<InternalPath>();
        
        // Simple SVG path parser (M, L, Z commands only for now)
        std::string svg(svg_path);
        std::istringstream stream(svg);
        char command;
        double x, y;
        
        path->points.clear();
        
        size_t i = 0;
        while (i < svg.length()) {
            if (svg[i] == 'M' || svg[i] == 'm' || 
                svg[i] == 'L' || svg[i] == 'l' ||
                svg[i] == 'Z' || svg[i] == 'z') {
                
                command = svg[i];
                i++;
                
                // Skip whitespace
                while (i < svg.length() && (svg[i] == ' ' || svg[i] == ',')) {
                    i++;
                }
                
                if (command == 'Z' || command == 'z') {
                    path->closed = true;
                    continue;
                }
                
                // Parse coordinates
                while (i < svg.length()) {
                    // Try to parse x coordinate
                    char* end_x = nullptr;
                    x = std::strtod(&svg[i], &end_x);
                    if (end_x == &svg[i]) break;  // No number found
                    i = end_x - svg.data();
                    
                    // Skip whitespace and comma
                    while (i < svg.length() && (svg[i] == ' ' || svg[i] == ',')) {
                        i++;
                    }
                    
                    // Try to parse y coordinate
                    char* end_y = nullptr;
                    y = std::strtod(&svg[i], &end_y);
                    if (end_y == &svg[i]) break;  // No number found
                    i = end_y - svg.data();
                    
                    path->points.push_back(x);
                    path->points.push_back(y);
                    
                    // Skip whitespace and comma
                    while (i < svg.length() && (svg[i] == ' ' || svg[i] == ',')) {
                        i++;
                    }
                    
                    // For line commands, continue reading coordinates
                    // For move commands, break after first pair
                    if (command == 'M' || command == 'm') {
                        command = 'L';  // Subsequent coords are lines
                    }
                }
            } else {
                i++;
            }
        }
        
        // Normalize the path for deterministic output
        capsule->normalize_path(*path);
        
        // Store path with ID
        uint64_t path_id = capsule->next_path_id++;
        capsule->paths[path_id] = std::move(path);
        
        // Store capsule and return handle
        g_capsules[(anigma_vector_capsule_t*)handle] = std::move(capsule);
        *out_handle = (anigma_vector_capsule_t*)handle;
        
        return ANIGMA_OK;
        
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "SVG parsing failed";
            err->detail = e.what();
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

// Destroy capsule
anigma_status_t anigma_vector_capsule_destroy(
    anigma_vector_capsule_t handle,
    anigma_capsule_error_t* err
) {
    auto it = g_capsules.find(handle);
    if (it != g_capsules.end()) {
        g_capsules.erase(it);
        return ANIGMA_OK;
    }
    
    if (err) {
        err->code = ANIGMA_ERR_INVALID_ARG;
        err->message = "Invalid capsule handle";
        err->detail = "Handle not found in capsule registry";
        err->aux = 0;
    }
    return ANIGMA_ERR_INVALID_ARG;
}

// Boolean operations
anigma_status_t anigma_vector_capsule_boolean_op(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    auto subject_it = g_capsules.find(subject);
    auto clip_it = g_capsules.find(clip);
    
    if (subject_it == g_capsules.end() || clip_it == g_capsules.end() || !out_result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "Subject, clip, and out_result must be valid";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // For this demo, just copy the subject path (real implementation would use Clipper2)
    try {
        auto result_capsule = std::make_unique<VectorCapsule>();
        auto result_handle = g_next_handle++;
        
        // Copy paths from subject (simplified boolean op)
        for (const auto& pair : subject_it->second->paths) {
            auto result_path = std::make_unique<InternalPath>(*pair.second);
            uint64_t path_id = result_capsule->next_path_id++;
            result_capsule->paths[path_id] = std::move(result_path);
        }
        
        g_capsules[(anigma_vector_capsule_t*)result_handle] = std::move(result_capsule);
        *out_result = (anigma_vector_capsule_t*)result_handle;
        
        return ANIGMA_OK;
        
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Boolean operation failed";
            err->detail = e.what();
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

// Export to SVG
anigma_status_t anigma_vector_capsule_export_to_svg(
    anigma_vector_capsule_t handle,
    char** out_svg_string,
    anigma_capsule_error_t* err
) {
    auto it = g_capsules.find(handle);
    if (it == g_capsules.end() || !out_svg_string) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "Handle and out_svg_string must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        std::ostringstream svg_stream;
        svg_stream << "<svg xmlns=\"http://www.w3.org/2000/svg\">";
        
        // Export all paths in deterministic order
        vector<const InternalPath*> paths;
        for (const auto& pair : it->second->paths) {
            paths.push_back(pair.second.get());
        }
        std::sort(paths.begin(), paths.end(), VectorCapsule::PathComparator());
        
        for (const auto* path : paths) {
            if (path->points.size() < 2) continue;
            
            svg_stream << "<path d=\"";
            
            for (size_t i = 0; i < path->points.size(); i += 2) {
                double x = path->points[i];
                double y = path->points[i + 1];
                
                if (i == 0) {
                    svg_stream << "M " << x << " " << y;
                } else {
                    svg_stream << " L " << x << " " << y;
                }
            }
            
            if (path->closed) {
                svg_stream << " Z";
            }
            
            svg_stream << "\" fill=\"black\" stroke=\"none\"/>";
        }
        
        svg_stream << "</svg>";
        
        std::string svg_str = svg_stream.str();
        *out_svg_string = (char*)anigma_capsule_alloc_buffer(svg_str.size() + 1, err);
        if (!*out_svg_string) {
            return ANIGMA_ERR_INTERNAL;
        }
        
        std::strcpy(*out_svg_string, svg_str.c_str());
        return ANIGMA_OK;
        
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "SVG export failed";
            err->detail = e.what();
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

// Check if empty
anigma_status_t anigma_vector_capsule_is_empty(
    anigma_vector_capsule_t handle,
    bool* out_empty,
    anigma_capsule_error_t* err
) {
    auto it = g_capsules.find(handle);
    if (it == g_capsules.end() || !out_empty) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "Handle and out_empty must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    *out_empty = it->second->paths.empty() || 
                 std::all_of(it->second->paths.begin(), it->second->paths.end(),
                             [](const auto& pair) { return pair.second->points.empty(); });
    
    return ANIGMA_OK;
}

// Get bounds
anigma_status_t anigma_vector_capsule_get_bounds(
    anigma_vector_capsule_t handle,
    double* out_min_x,
    double* out_min_y,
    double* out_max_x,
    double* out_max_y,
    anigma_capsule_error_t* err
) {
    auto it = g_capsules.find(handle);
    if (it == g_capsules.end() || !out_min_x || !out_min_y || !out_max_x || !out_max_y) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "Handle and all output pointers must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (it->second->paths.empty()) {
        *out_min_x = *out_min_y = *out_max_x = *out_max_y = 0.0;
        return ANIGMA_OK;
    }
    
    bool first = true;
    double min_x = 0.0, min_y = 0.0, max_x = 0.0, max_y = 0.0;
    
    for (const auto& pair : it->second->paths) {
        for (size_t i = 0; i < pair.second->points.size(); i += 2) {
            double x = pair.second->points[i];
            double y = (i + 1 < pair.second->points.size()) ? pair.second->points[i + 1] : 0.0;
            
            if (first) {
                min_x = max_x = x;
                min_y = max_y = y;
                first = false;
            } else {
                min_x = std::min(min_x, x);
                max_x = std::max(max_x, x);
                min_y = std::min(min_y, y);
                max_y = std::max(max_y, y);
            }
        }
    }
    
    *out_min_x = min_x;
    *out_min_y = min_y;
    *out_max_x = max_x;
    *out_max_y = max_y;
    
    return ANIGMA_OK;
}

// Simplify Douglas-Peucker
anigma_status_t anigma_vector_capsule_simplify_douglas_peucker(
    anigma_vector_capsule_t handle,
    double tolerance,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
) {
    auto it = g_capsules.find(handle);
    if (it == g_capsules.end() || !out_result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "Handle and out_result must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto result_capsule = std::make_unique<VectorCapsule>();
        auto result_handle = g_next_handle++;
        
        // Simplify each path
        for (const auto& pair : it->second->paths) {
            const auto* path = pair.second.get();
            auto simplified_path = std::make_unique<InternalPath>(*path);
            
            // Apply Douglas-Peucker simplification (simplified version)
            if (path->points.size() > 4) {  // Need at least 2 line segments
                vector<double> simplified_points;
                simplified_points.push_back(path->points[0]);  // Keep first
                simplified_points.push_back(path->points[1]);
                
                for (size_t i = 2; i < path->points.size() - 2; i += 2) {
                    double x1 = simplified_points[simplified_points.size() - 2];
                    double y1 = simplified_points[simplified_points.size() - 1];
                    double x2 = path->points[i];
                    double y2 = path->points[i + 1];
                    double x3 = path->points[i + 2];
                    double y3 = path->points[i + 3];
                    
                    // Calculate distance from middle point to line
                    double A = y3 - y1;
                    double B = x1 - x3;
                    double C = x3 * y1 - y3 * x1;
                    
                    double denominator = A * A + B * B;
                    if (denominator > 0) {
                        double distance = std::abs(A * x2 + B * y2 + C) / std::sqrt(denominator);
                        
                        if (distance > tolerance) {
                            simplified_points.push_back(x2);
                            simplified_points.push_back(y2);
                        }
                    }
                }
                
                simplified_points.push_back(path->points[path->points.size() - 2]);  // Keep last
                simplified_points.push_back(path->points[path->points.size() - 1]);
                
                simplified_path->points = simplified_points;
            }
            
            uint64_t path_id = result_capsule->next_path_id++;
            result_capsule->paths[path_id] = std::move(simplified_path);
        }
        
        g_capsules[(anigma_vector_capsule_t*)result_handle] = std::move(result_capsule);
        *out_result = (anigma_vector_capsule_t*)result_handle;
        
        return ANIGMA_OK;
        
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Simplification failed";
            err->detail = e.what();
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

} // extern "C"