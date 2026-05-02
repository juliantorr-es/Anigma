#ifndef GEOMETRY_H
#define GEOMETRY_H

#include <vector>
#include <memory>
#include <array>
#include <cstdint>
#include <cmath>

namespace GeometryCapsule {

// Point/Vector2D structure
struct Point2D {
    double x;
    double y;
    
    Point2D() : x(0.0), y(0.0) {}
    Point2D(double x_, double y_) : x(x_), y(y_) {}
    
    // Comparison operators for sorting
    bool operator==(const Point2D& other) const {
        return std::abs(x - other.x) < 1e-10 && std::abs(y - other.y) < 1e-10;
    }
    
    bool operator<(const Point2D& other) const {
        if (std::abs(x - other.x) < 1e-10) return y < other.y;
        return x < other.x;
    }
};

// Triangle representation
using Triangle = std::array<Point2D, 3>;

// Polygon representation
using Polygon = std::vector<Point2D>;
using PolygonList = std::vector<Polygon>;

// Boolean operation types
enum class BooleanOperation : std::uint8_t {
    Union,
    Intersection,
    Difference,
    Xor
};

// Geometry processing interface
class GeometryProcessor {
public:
    virtual ~GeometryProcessor() = default;
    
    // Boolean operations (simplified implementation)
    virtual PolygonList booleanOperation(
        const PolygonList& subjects,
        const PolygonList& clips,
        BooleanOperation operation
    ) = 0;
    
    // Convex hull using Graham scan
    virtual Polygon convexHull(const std::vector<Point2D>& points) = 0;
    
    // Delaunay triangulation using Bowyer-Watson algorithm
    virtual std::vector<Triangle> delaunayTriangulation(
        const std::vector<Point2D>& points
    ) = 0;
    
    // Utility functions
    virtual double polygonArea(const Polygon& polygon) = 0;
    virtual bool pointInPolygon(const Point2D& point, const Polygon& polygon) = 0;
};

// Factory function
std::unique_ptr<GeometryProcessor> createGeometryProcessor();

} // namespace GeometryCapsule

#endif // GEOMETRY_H