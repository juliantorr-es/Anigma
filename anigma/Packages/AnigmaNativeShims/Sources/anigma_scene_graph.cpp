#include "anigma_scene_graph.h"
#include <stdlib.h>
#include <math.h>
#include <string.h>

extern "C" {

anigma_status_t anigma_scene_graph_batch_calculate_distances(
    const anigma_point3d_t* points_a,
    const anigma_point3d_t* points_b,
    double* out_distances,
    size_t count,
    anigma_capsule_error_t* err) {
    
    if (!points_a || !points_b || !out_distances) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Null pointer in batch distance calculation";
        }
        return ANIGMA_ERR_INTERNAL;
    }

    // In a real ANE implementation, this would be a single dispatch to a Metal shader or CoreML model.
    // For this hardened implementation, we use a vectorized-friendly loop with coordinate scaling.
    for (size_t i = 0; i < count; i++) {
        double dx = (double)(points_b[i].x - points_a[i].x) / ANIGMA_COORDINATE_SCALE;
        double dy = (double)(points_b[i].y - points_a[i].y) / ANIGMA_COORDINATE_SCALE;
        double dz = (double)(points_b[i].z - points_a[i].z) / ANIGMA_COORDINATE_SCALE;
        out_distances[i] = sqrt(dx * dx + dy * dy + dz * dz);
    }

    return ANIGMA_OK;
}

anigma_status_t anigma_scene_graph_batch_transform_points(
    const anigma_point3d_t* points,
    const anigma_transform_t* transform,
    anigma_point3d_t* out_points,
    size_t count,
    anigma_capsule_error_t* err) {
    
    if (!points || !transform || !out_points) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Null pointer in batch transform calculation";
        }
        return ANIGMA_ERR_INTERNAL;
    }

    // Simple 3x3 matrix multiplication (fixed-point)
    for (size_t i = 0; i < count; i++) {
        anigma_point3d_t p = points[i];
        anigma_point3d_t result;
        
        // Matrix multiplication with intermediate 64-bit precision to prevent overflow before scaling
        int64_t rx = ((int64_t)transform->m[0][0] * p.x + (int64_t)transform->m[0][1] * p.y + (int64_t)transform->m[0][2] * p.z) / ANIGMA_COORDINATE_SCALE;
        int64_t ry = ((int64_t)transform->m[1][0] * p.x + (int64_t)transform->m[1][1] * p.y + (int64_t)transform->m[1][2] * p.z) / ANIGMA_COORDINATE_SCALE;
        int64_t rz = ((int64_t)transform->m[2][0] * p.x + (int64_t)transform->m[2][1] * p.y + (int64_t)transform->m[2][2] * p.z) / ANIGMA_COORDINATE_SCALE;
        
        result.x = (anigma_coordinate_t)rx;
        result.y = (anigma_coordinate_t)ry;
        result.z = (anigma_coordinate_t)rz;
        
        out_points[i] = result;
    }

    return ANIGMA_OK;
}

} // extern "C"
