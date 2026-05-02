#ifndef GEOMETRY_BRIDGE_H
#define GEOMETRY_BRIDGE_H

#include "geometry.h"
#include <cstdint>

extern "C" {

// C-compatible structures for Swift interoperability
typedef struct {
    double x;
    double y;
} CPoint2D;

typedef struct {
    CPoint2D* points;
    size_t count;
} CPolygon;

typedef struct {
    CPolygon* polygons;
    size_t count;
} CPolygonList;

typedef struct {
    CPoint2D* points;
    size_t count;
} CTriangle;

typedef struct {
    CTriangle* triangles;
    size_t count;
} CTriangleList;

// Boolean operation enumeration
typedef enum {
    CBooleanOperation_Union = 0,
    CBooleanOperation_Intersection = 1,
    CBooleanOperation_Difference = 2,
    CBooleanOperation_Xor = 3
} CBooleanOperation;

// Geometry processor handle
typedef void* GeometryProcessorRef;

// Factory and lifecycle
GeometryProcessorRef geometry_processor_create();
void geometry_processor_destroy(GeometryProcessorRef processor);

// Boolean operations
CPolygonList geometry_processor_boolean_operation(
    GeometryProcessorRef processor,
    const CPolygonList* subjects,
    const CPolygonList* clips,
    CBooleanOperation operation
);

// Convex hull
CPolygon geometry_processor_convex_hull(
    GeometryProcessorRef processor,
    const CPoint2D* points,
    size_t point_count
);

// Delaunay triangulation
CTriangleList geometry_processor_delaunay_triangulation(
    GeometryProcessorRef processor,
    const CPoint2D* points,
    size_t point_count
);

// Utility functions
double geometry_processor_polygon_area(
    GeometryProcessorRef processor,
    const CPolygon* polygon
);

bool geometry_processor_point_in_polygon(
    GeometryProcessorRef processor,
    const CPoint2D* point,
    const CPolygon* polygon
);

// Memory management for returned structures
void cpolygon_list_destroy(CPolygonList* list);
void cpolygon_destroy(CPolygon* polygon);
void ctriangle_list_destroy(CTriangleList* list);

} // extern "C"

#endif // GEOMETRY_BRIDGE_H