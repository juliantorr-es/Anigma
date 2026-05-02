#include "include/geometry_bridge.h"
#include "include/geometry.h"
#include <cstdlib>
#include <cstring>

using namespace GeometryCapsule;

// Helper conversion functions
static CPoint2D toCPoint(const Point2D& point) {
    return {point.x, point.y};
}

static Point2D fromCPoint(const CPoint2D& point) {
    return Point2D(point.x, point.y);
}

static CPolygon toCPolygon(const Polygon& polygon) {
    CPoint2D* points = static_cast<CPoint2D*>(malloc(sizeof(CPoint2D) * polygon.size()));
    for (size_t i = 0; i < polygon.size(); ++i) {
        points[i] = toCPoint(polygon[i]);
    }
    return {points, polygon.size()};
}

static Polygon fromCPolygon(const CPolygon& polygon) {
    Polygon result;
    for (size_t i = 0; i < polygon.count; ++i) {
        result.push_back(fromCPoint(polygon.points[i]));
    }
    return result;
}

static CPolygonList toCPolygonList(const PolygonList& polygonList) {
    CPolygon* polygons = static_cast<CPolygon*>(malloc(sizeof(CPolygon) * polygonList.size()));
    for (size_t i = 0; i < polygonList.size(); ++i) {
        polygons[i] = toCPolygon(polygonList[i]);
    }
    return {polygons, polygonList.size()};
}

static PolygonList fromCPolygonList(const CPolygonList& polygonList) {
    PolygonList result;
    for (size_t i = 0; i < polygonList.count; ++i) {
        result.push_back(fromCPolygon(polygonList.polygons[i]));
    }
    return result;
}

static CTriangleList toCTriangleList(const std::vector<Triangle>& triangles) {
    CTriangle* triangleArray = static_cast<CTriangle*>(malloc(sizeof(CTriangle) * triangles.size()));
    for (size_t i = 0; i < triangles.size(); ++i) {
        CPoint2D* points = static_cast<CPoint2D*>(malloc(sizeof(CPoint2D) * 3));
        for (int j = 0; j < 3; ++j) {
            points[j] = toCPoint(triangles[i][j]);
        }
        triangleArray[i] = {points, 3};
    }
    return {triangleArray, triangles.size()};
}

// C API implementation
extern "C" {

GeometryProcessorRef geometry_processor_create() {
    try {
        return createGeometryProcessor().release();
    } catch (...) {
        return nullptr;
    }
}

void geometry_processor_destroy(GeometryProcessorRef processor) {
    delete static_cast<GeometryProcessor*>(processor);
}

CPolygonList geometry_processor_boolean_operation(
    GeometryProcessorRef processor,
    const CPolygonList* subjects,
    const CPolygonList* clips,
    CBooleanOperation operation
) {
    if (!processor || !subjects || !clips) {
        return {nullptr, 0};
    }
    
    try {
        auto* impl = static_cast<GeometryProcessor*>(processor);
        PolygonList subjectPolys = fromCPolygonList(*subjects);
        PolygonList clipPolys = fromCPolygonList(*clips);
        
        BooleanOperation op;
        switch (operation) {
            case CBooleanOperation_Union:
                op = BooleanOperation::Union;
                break;
            case CBooleanOperation_Intersection:
                op = BooleanOperation::Intersection;
                break;
            case CBooleanOperation_Difference:
                op = BooleanOperation::Difference;
                break;
            case CBooleanOperation_Xor:
                op = BooleanOperation::Xor;
                break;
        }
        
        PolygonList result = impl->booleanOperation(subjectPolys, clipPolys, op);
        return toCPolygonList(result);
    } catch (...) {
        return {nullptr, 0};
    }
}

CPolygon geometry_processor_convex_hull(
    GeometryProcessorRef processor,
    const CPoint2D* points,
    size_t point_count
) {
    if (!processor || !points || point_count == 0) {
        return {nullptr, 0};
    }
    
    try {
        auto* impl = static_cast<GeometryProcessor*>(processor);
        std::vector<Point2D> pointVector;
        for (size_t i = 0; i < point_count; ++i) {
            pointVector.push_back(fromCPoint(points[i]));
        }
        
        Polygon hull = impl->convexHull(pointVector);
        return toCPolygon(hull);
    } catch (...) {
        return {nullptr, 0};
    }
}

CTriangleList geometry_processor_delaunay_triangulation(
    GeometryProcessorRef processor,
    const CPoint2D* points,
    size_t point_count
) {
    if (!processor || !points || point_count < 3) {
        return {nullptr, 0};
    }
    
    try {
        auto* impl = static_cast<GeometryProcessor*>(processor);
        std::vector<Point2D> pointVector;
        for (size_t i = 0; i < point_count; ++i) {
            pointVector.push_back(fromCPoint(points[i]));
        }
        
        std::vector<Triangle> triangles = impl->delaunayTriangulation(pointVector);
        return toCTriangleList(triangles);
    } catch (...) {
        return {nullptr, 0};
    }
}

double geometry_processor_polygon_area(
    GeometryProcessorRef processor,
    const CPolygon* polygon
) {
    if (!processor || !polygon) {
        return 0.0;
    }
    
    try {
        auto* impl = static_cast<GeometryProcessor*>(processor);
        Polygon poly = fromCPolygon(*polygon);
        return impl->polygonArea(poly);
    } catch (...) {
        return 0.0;
    }
}

bool geometry_processor_point_in_polygon(
    GeometryProcessorRef processor,
    const CPoint2D* point,
    const CPolygon* polygon
) {
    if (!processor || !point || !polygon) {
        return false;
    }
    
    try {
        auto* impl = static_cast<GeometryProcessor*>(processor);
        Point2D pt = fromCPoint(*point);
        Polygon poly = fromCPolygon(*polygon);
        return impl->pointInPolygon(pt, poly);
    } catch (...) {
        return false;
    }
}

// Memory management functions
void cpolygon_list_destroy(CPolygonList* list) {
    if (list && list->polygons) {
        for (size_t i = 0; i < list->count; ++i) {
            if (list->polygons[i].points) {
                free(list->polygons[i].points);
            }
        }
        free(list->polygons);
        list->polygons = nullptr;
        list->count = 0;
    }
}

void cpolygon_destroy(CPolygon* polygon) {
    if (polygon && polygon->points) {
        free(polygon->points);
        polygon->points = nullptr;
        polygon->count = 0;
    }
}

void ctriangle_list_destroy(CTriangleList* list) {
    if (list && list->triangles) {
        for (size_t i = 0; i < list->count; ++i) {
            if (list->triangles[i].points) {
                free(list->triangles[i].points);
            }
        }
        free(list->triangles);
        list->triangles = nullptr;
        list->count = 0;
    }
}

} // extern "C"