#include "include/geometry.h"
#include <algorithm>
#include <stdexcept>
#include <unordered_set>

namespace GeometryCapsule {

// Helper functions
namespace {
    constexpr double EPSILON = 1e-10;
    
    double crossProduct(const Point2D& a, const Point2D& b, const Point2D& c) {
        return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    }
    
    double distanceSquared(const Point2D& a, const Point2D& b) {
        double dx = a.x - b.x;
        double dy = a.y - b.y;
        return dx * dx + dy * dy;
    }
    
    bool pointsEqual(const Point2D& a, const Point2D& b) {
        return std::abs(a.x - b.x) < EPSILON && std::abs(a.y - b.y) < EPSILON;
    }
    
    Point2D circumcenter(const Point2D& a, const Point2D& b, const Point2D& c) {
        double d = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
        if (std::abs(d) < EPSILON) {
            throw std::runtime_error("Points are collinear");
        }
        
        double ux = ((a.x * a.x + a.y * a.y) * (b.y - c.y) + 
                    (b.x * b.x + b.y * b.y) * (c.y - a.y) + 
                    (c.x * c.x + c.y * c.y) * (a.y - b.y)) / d;
        double uy = ((a.x * a.x + a.y * a.y) * (c.x - b.x) + 
                    (b.x * b.x + b.y * b.y) * (a.x - c.x) + 
                    (c.x * c.x + c.y * c.y) * (b.x - a.x)) / d;
        
        return Point2D(ux, uy);
    }
    
    bool pointInCircumcircle(const Point2D& p, const Triangle& triangle) {
        Point2D center = circumcenter(triangle[0], triangle[1], triangle[2]);
        double radiusSquared = distanceSquared(center, triangle[0]);
        return distanceSquared(p, center) < radiusSquared - EPSILON;
    }
}

// GeometryProcessor implementation
class GeometryProcessorImpl : public GeometryProcessor {
public:
    PolygonList booleanOperation(
        const PolygonList& subjects,
        const PolygonList& clips,
        BooleanOperation operation
    ) override {
        // Simplified Boolean operations - for Tier 1 implementation
        // In production, this would use Clipper2
        
        PolygonList result;
        
        switch (operation) {
            case BooleanOperation::Union:
                // Simplified union: merge all polygons
                result = subjects;
                result.insert(result.end(), clips.begin(), clips.end());
                break;
                
            case BooleanOperation::Intersection:
                // Simplified intersection: return subjects that intersect with any clip
                for (const auto& subject : subjects) {
                    for (const auto& clip : clips) {
                        if (polygonsIntersect(subject, clip)) {
                            result.push_back(subject);
                            break;
                        }
                    }
                }
                break;
                
            case BooleanOperation::Difference:
                // Simplified difference: return subjects that don't intersect with any clip
                for (const auto& subject : subjects) {
                    bool intersects = false;
                    for (const auto& clip : clips) {
                        if (polygonsIntersect(subject, clip)) {
                            intersects = true;
                            break;
                        }
                    }
                    if (!intersects) {
                        result.push_back(subject);
                    }
                }
                break;
                
            case BooleanOperation::Xor:
                // Simplified xor: union minus intersection
                for (const auto& subject : subjects) {
                    bool intersects = false;
                    for (const auto& clip : clips) {
                        if (polygonsIntersect(subject, clip)) {
                            intersects = true;
                            break;
                        }
                    }
                    if (!intersects) {
                        result.push_back(subject);
                    }
                }
                for (const auto& clip : clips) {
                    result.push_back(clip);
                }
                break;
        }
        
        return result;
    }
    
    Polygon convexHull(const std::vector<Point2D>& points) override {
        if (points.size() < 3) {
            return points;
        }
        
        // Find the point with lowest y-coordinate (and leftmost if tie)
        Point2D start = points[0];
        for (const auto& point : points) {
            if (point.y < start.y || (point.y == start.y && point.x < start.x)) {
                start = point;
            }
        }
        
        // Sort points by polar angle with respect to start point
        std::vector<Point2D> sortedPoints = points;
        std::sort(sortedPoints.begin(), sortedPoints.end(), 
            [&start](const Point2D& a, const Point2D& b) {
                if (pointsEqual(a, start)) return true;
                if (pointsEqual(b, start)) return false;
                
                double cross = crossProduct(start, a, b);
                if (std::abs(cross) > EPSILON) {
                    return cross > 0;
                }
                return distanceSquared(start, a) < distanceSquared(start, b);
            }
        );
        
        // Graham scan
        Polygon hull;
        for (const auto& point : sortedPoints) {
            while (hull.size() >= 2) {
                double cross = crossProduct(hull[hull.size() - 2], hull[hull.size() - 1], point);
                if (cross <= EPSILON) {
                    hull.pop_back();
                } else {
                    break;
                }
            }
            if (hull.empty() || !pointsEqual(hull.back(), point)) {
                hull.push_back(point);
            }
        }
        
        return hull;
    }
    
    std::vector<Triangle> delaunayTriangulation(
        const std::vector<Point2D>& points
    ) override {
        if (points.size() < 3) {
            return {};
        }
        
        // Create super triangle
        double minX = points[0].x, maxX = points[0].x;
        double minY = points[0].y, maxY = points[0].y;
        
        for (const auto& point : points) {
            minX = std::min(minX, point.x);
            maxX = std::max(maxX, point.x);
            minY = std::min(minY, point.y);
            maxY = std::max(maxY, point.y);
        }
        
        double dx = maxX - minX;
        double dy = maxY - minY;
        double deltaMax = std::max(dx, dy) * 10.0;
        
        Point2D p1(minX - deltaMax, minY - deltaMax);
        Point2D p2(minX + 2 * deltaMax, minY - deltaMax);
        Point2D p3(minX + dx / 2.0, minY + 2 * deltaMax);
        
        Triangle superTriangle = {p1, p2, p3};
        std::vector<Triangle> triangles = {superTriangle};
        
        // Bowyer-Watson algorithm
        for (const auto& point : points) {
            std::vector<Triangle> badTriangles;
            
            // Find triangles whose circumcircle contains the point
            for (const auto& triangle : triangles) {
                if (pointInCircumcircle(point, triangle)) {
                    badTriangles.push_back(triangle);
                }
            }
            
            // Find boundary of the polygonal hole
            std::vector<std::array<Point2D, 2>> polygon;
            for (const auto& triangle : badTriangles) {
                for (int i = 0; i < 3; ++i) {
                    std::array<Point2D, 2> edge = {triangle[i], triangle[(i + 1) % 3]};
                    bool shared = false;
                    
                    for (const auto& otherTriangle : badTriangles) {
                        if (&triangle == &otherTriangle) continue;
                        
                        for (int j = 0; j < 3; ++j) {
                            std::array<Point2D, 2> otherEdge = {
                                otherTriangle[j], 
                                otherTriangle[(j + 1) % 3]
                            };
                            
                            if ((pointsEqual(edge[0], otherEdge[1]) && pointsEqual(edge[1], otherEdge[0])) ||
                                (pointsEqual(edge[0], otherEdge[0]) && pointsEqual(edge[1], otherEdge[1]))) {
                                shared = true;
                                break;
                            }
                        }
                        
                        if (shared) break;
                    }
                    
                    if (!shared) {
                        polygon.push_back(edge);
                    }
                }
            }
            
            // Remove bad triangles
            triangles.erase(
                std::remove_if(triangles.begin(), triangles.end(),
                    [&badTriangles](const Triangle& t) {
                        return std::find_if(badTriangles.begin(), badTriangles.end(),
                            [&t](const Triangle& bt) {
                                return std::equal(t.begin(), t.end(), bt.begin(),
                                    [](const Point2D& a, const Point2D& b) {
                                        return pointsEqual(a, b);
                                    });
                            }) != badTriangles.end();
                    }
                ),
                triangles.end()
            );
            
            // Create new triangles
            for (const auto& edge : polygon) {
                triangles.push_back({edge[0], edge[1], point});
            }
        }
        
        // Remove triangles that share vertices with super triangle
        triangles.erase(
            std::remove_if(triangles.begin(), triangles.end(),
                [&superTriangle](const Triangle& triangle) {
                    for (const auto& vertex : triangle) {
                        for (const auto& superVertex : superTriangle) {
                            if (pointsEqual(vertex, superVertex)) {
                                return true;
                            }
                        }
                    }
                    return false;
                }
            ),
            triangles.end()
        );
        
        return triangles;
    }
    
    double polygonArea(const Polygon& polygon) override {
        if (polygon.size() < 3) return 0.0;
        
        double area = 0.0;
        for (size_t i = 0; i < polygon.size(); ++i) {
            const Point2D& current = polygon[i];
            const Point2D& next = polygon[(i + 1) % polygon.size()];
            area += (current.x * next.y) - (next.x * current.y);
        }
        
        return std::abs(area) * 0.5;
    }
    
    bool pointInPolygon(const Point2D& point, const Polygon& polygon) override {
        if (polygon.size() < 3) return false;
        
        bool inside = false;
        for (size_t i = 0, j = polygon.size() - 1; i < polygon.size(); j = i++) {
            const Point2D& vi = polygon[i];
            const Point2D& vj = polygon[j];
            
            if (((vi.y > point.y) != (vj.y > point.y)) &&
                (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x)) {
                inside = !inside;
            }
        }
        
        return inside;
    }
    
private:
    bool polygonsIntersect(const Polygon& a, const Polygon& b) {
        // Simple intersection test: check if any vertex of a is inside b or vice versa
        for (const auto& point : a) {
            if (pointInPolygon(point, b)) return true;
        }
        for (const auto& point : b) {
            if (pointInPolygon(point, a)) return true;
        }
        return false;
    }
};

// Factory function implementation
std::unique_ptr<GeometryProcessor> createGeometryProcessor() {
    return std::make_unique<GeometryProcessorImpl>();
}

} // namespace GeometryCapsule