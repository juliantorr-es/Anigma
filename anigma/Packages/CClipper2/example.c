/*
 * Example usage of Clipper2 C wrapper.
 * Compile with:
 *   clang -I. -I./Clipper2/CPP/Clipper2Lib/include -I./Clipper2/CPP/Utils example.c clipper2_wrapper.cpp -lstdc++ -lm
 */

#include "clipper2_wrapper.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    printf("Clipper2 C wrapper example\n");
    
    // Create subject paths
    clipper2_paths64_t* subj = clipper2_paths64_create();
    clipper2_path64_t* path1 = clipper2_path64_create();
    clipper2_path64_add_point(path1, 10, 10);
    clipper2_path64_add_point(path1, 100, 10);
    clipper2_path64_add_point(path1, 100, 100);
    clipper2_path64_add_point(path1, 10, 100);
    clipper2_paths64_add_path(subj, path1);
    clipper2_path64_destroy(path1);
    
    // Create clip paths
    clipper2_paths64_t* clip = clipper2_paths64_create();
    clipper2_path64_t* path2 = clipper2_path64_create();
    clipper2_path64_add_point(path2, 50, 50);
    clipper2_path64_add_point(path2, 150, 50);
    clipper2_path64_add_point(path2, 150, 150);
    clipper2_path64_add_point(path2, 50, 150);
    clipper2_paths64_add_path(clip, path2);
    clipper2_path64_destroy(path2);
    
    // Perform union operation
    clipper2_paths64_t* result = clipper2_union_64(subj, clip, CLIPPER2_FILLRULE_EVEN_ODD);
    if (!result) {
        printf("Union operation failed\n");
        clipper2_paths64_destroy(subj);
        clipper2_paths64_destroy(clip);
        return 1;
    }
    
    // Print result
    size_t num_paths = clipper2_paths64_size(result);
    printf("Union produced %zu path(s)\n", num_paths);
    for (size_t i = 0; i < num_paths; ++i) {
        const clipper2_path64_t* path = clipper2_paths64_get_path(result, i);
        if (!path) continue;
        size_t num_points = clipper2_path64_size(path);
        printf("  Path %zu has %zu points:\n", i, num_points);
        for (size_t j = 0; j < num_points; ++j) {
            clipper2_point64_t pt = clipper2_path64_get_point(path, j);
            printf("    (%lld, %lld)\n", (long long)pt.x, (long long)pt.y);
        }
    }
    
    // Clean up
    clipper2_paths64_destroy(result);
    clipper2_paths64_destroy(subj);
    clipper2_paths64_destroy(clip);
    
    printf("Example completed successfully.\n");
    return 0;
}