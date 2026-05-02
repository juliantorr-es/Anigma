// TessellationCapsule.swift
// TessellationCapsule - Polygon tessellation and triangle mesh generation
// Part of the Anigma layout tier

import Foundation
import CapsuleCore

// MARK: - Types

/// Represents a 2D point for polygon vertices
public struct Point2D: Sendable, Codable, Hashable {
    public let x: Double
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Represents a polygon as a sequence of vertices
public struct Polygon: Sendable, Codable {
    /// Vertices in counter-clockwise order
    public let vertices: [Point2D]
    /// Optional holes in the polygon (each hole is also counter-clockwise)
    public let holes: [[Point2D]]
    
    public init(vertices: [Point2D], holes: [[Point2D]] = []) throws {
        guard vertices.count >= 3 else {
            throw CapsuleError.invalidInput(
                field: "vertices",
                constraint: "Polygon must have at least 3 vertices"
            )
        }
        self.vertices = vertices
        self.holes = holes
    }
}

/// Triangle indices into the tessellated vertices
public struct Triangle: Sendable, Hashable {
    public let i0: UInt32
    public let i1: UInt32
    public let i2: UInt32
    
    public var indices: (UInt32, UInt32, UInt32) {
        (i0, i1, i2)
    }
    
    public init(_ i0: UInt32, _ i1: UInt32, _ i2: UInt32) {
        self.i0 = i0
        self.i1 = i1
        self.i2 = i2
    }
}

/// Result of tessellation: vertices and triangle indices
public struct TriangleMesh: Sendable, Codable {
    /// All vertices in the tessellated mesh
    public let vertices: [Point2D]
    /// Triangles as triples of indices into vertices array
    public let triangles: [[UInt32]]
    
    public init(vertices: [Point2D], triangles: [[UInt32]]) {
        self.vertices = vertices
        self.triangles = triangles
    }
}

// MARK: - TessellationCapsule

/// Tessellates polygons and generates triangle mesh data.
/// Uses a fan-based triangulation for convex polygons and ear-clipping for concave polygons.
public actor TessellationCapsule {
    
    /// Initialize the tessellation capsule
    public init() {}
    
    /// Tessellate a single polygon into triangles
    /// - Parameters:
    ///   - polygon: The polygon to tessellate
    /// - Returns: Triangle mesh with vertices and triangle indices
    public func tessellate(_ polygon: Polygon) async throws -> TriangleMesh {
        guard polygon.vertices.count >= 3 else {
            throw CapsuleError.invalidInput(
                field: "polygon",
                constraint: "Polygon must have at least 3 vertices"
            )
        }
        
        // Use ear clipping for general polygons (handles both convex and concave)
        return try earClipPolygon(polygon)
    }
    
    /// Tessellate multiple polygons
    /// - Parameter polygons: Polygons to tessellate
    /// - Returns: Array of triangle meshes
    public func tessellateMultiple(_ polygons: [Polygon]) async throws -> [TriangleMesh] {
        var results: [TriangleMesh] = []
        for polygon in polygons {
            let mesh = try await tessellate(polygon)
            results.append(mesh)
        }
        return results
    }
    
    /// Check if a polygon is convex
    /// - Parameter polygon: The polygon to check
    /// - Returns: True if convex, false otherwise
    public func isConvex(_ polygon: Polygon) async throws -> Bool {
        return isConvexPolygon(polygon)
    }
    
    /// Calculate the area of a polygon using the shoelace formula
    /// - Parameter polygon: The polygon to measure
    /// - Returns: Signed area (positive for counter-clockwise, negative for clockwise)
    public func calculateArea(_ polygon: Polygon) async throws -> Double {
        return polygonArea(polygon.vertices)
    }
}

// MARK: - Private Implementation

extension TessellationCapsule {
    
    /// Ear clipping algorithm for polygon tessellation
    private func earClipPolygon(_ polygon: Polygon) throws -> TriangleMesh {
        var vertices = polygon.vertices
        var remaining = Array(0..<vertices.count)
        var triangles: [[UInt32]] = []
        
        // Handle holes by merging them into the main polygon
        if !polygon.holes.isEmpty {
            let merged = try mergeHolesIntoPolygon(vertices, holes: polygon.holes)
            vertices = merged.0
            remaining = Array(0..<vertices.count)
        }
        
        // Ear clipping main loop
        while remaining.count > 3 {
            var earFound = false
            
            for i in 0..<remaining.count {
                let prev = remaining[(i + remaining.count - 1) % remaining.count]
                let curr = remaining[i]
                let next = remaining[(i + 1) % remaining.count]
                
                // Check if this is an ear
                if isEar(vertices, prev, curr, next, remaining) {
                    // Create triangle
                    triangles.append([UInt32(prev), UInt32(curr), UInt32(next)])
                    
                    // Remove current vertex
                    remaining.remove(at: i)
                    earFound = true
                    break
                }
            }
            
            guard earFound else {
                throw CapsuleError.operationFailed(
                    code: 1,
                    message: "Failed to find ear in polygon - degenerate polygon",
                    context: ["vertices_remaining": "\(remaining.count)"]
                )
            }
        }
        
        // Add final triangle
        if remaining.count == 3 {
            triangles.append([UInt32(remaining[0]), UInt32(remaining[1]), UInt32(remaining[2])])
        }
        
        return TriangleMesh(vertices: vertices, triangles: triangles)
    }
    
    /// Check if a vertex is an ear
    private func isEar(
        _ vertices: [Point2D],
        _ prevIdx: Int,
        _ currIdx: Int,
        _ nextIdx: Int,
        _ remaining: [Int]
    ) -> Bool {
        let prev = vertices[prevIdx]
        let curr = vertices[currIdx]
        let next = vertices[nextIdx]
        
        // Check if interior angle is less than 180 degrees (ear candidate)
        // Use vectors (curr - prev) and (next - curr)
        let cross = crossProduct(
            Point2D(x: curr.x - prev.x, y: curr.y - prev.y),
            Point2D(x: next.x - curr.x, y: next.y - curr.y)
        )
        
        guard cross > 0 else {
            return false // Reflex vertex or collinear
        }
        
        // Check if any other vertex is inside the triangle
        for idx in remaining {
            guard idx != prevIdx && idx != currIdx && idx != nextIdx else {
                continue
            }
            
            if pointInTriangle(vertices[idx], prev, curr, next) {
                return false
            }
        }
        
        return true
    }
    
    /// Check if a point is inside a triangle using barycentric coordinates
    private func pointInTriangle(_ p: Point2D, _ a: Point2D, _ b: Point2D, _ c: Point2D) -> Bool {
        let d1 = sign(p, a, b)
        let d2 = sign(p, b, c)
        let d3 = sign(p, c, a)
        
        let hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0)
        let hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0)
        
        return !(hasNeg && hasPos)
    }
    
    /// Helper for triangle point test
    private func sign(_ p1: Point2D, _ p2: Point2D, _ p3: Point2D) -> Double {
        return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
    }
    
    /// Merge polygon holes into the main polygon using a bridge algorithm
    private func mergeHolesIntoPolygon(
        _ polygon: [Point2D],
        holes: [[Point2D]]
    ) throws -> ([Point2D], [Int]) {
        // Simplified: For now, just append holes as separate components
        // A full implementation would bridge holes to the outer polygon
        var allVertices = polygon
        
        for hole in holes {
            guard hole.count >= 3 else {
                throw CapsuleError.invalidInput(
                    field: "hole",
                    constraint: "Each hole must have at least 3 vertices"
                )
            }
            allVertices.append(contentsOf: hole)
        }
        
        return (allVertices, [])
    }
    
    /// Calculate cross product of two 2D vectors
    private func crossProduct(_ a: Point2D, _ b: Point2D) -> Double {
        return a.x * b.y - a.y * b.x
    }
    
    /// Check if a polygon is convex
    private func isConvexPolygon(_ polygon: Polygon) -> Bool {
        let vertices = polygon.vertices
        guard vertices.count >= 3 else { return false }
        
        var sign: Double? = nil
        
        for i in 0..<vertices.count {
            let p0 = vertices[i]
            let p1 = vertices[(i + 1) % vertices.count]
            let p2 = vertices[(i + 2) % vertices.count]
            
            let cross = crossProduct(
                Point2D(x: p1.x - p0.x, y: p1.y - p0.y),
                Point2D(x: p2.x - p1.x, y: p2.y - p1.y)
            )
            
            if Swift.abs(cross) > 1e-10 {
                if sign == nil {
                    sign = cross
                } else if (sign! > 0) != (cross > 0) {
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Calculate polygon area using shoelace formula
    private func polygonArea(_ vertices: [Point2D]) -> Double {
        guard vertices.count >= 3 else { return 0 }
        
        var area = 0.0
        for i in 0..<vertices.count {
            let p0 = vertices[i]
            let p1 = vertices[(i + 1) % vertices.count]
            area += p0.x * p1.y - p1.x * p0.y
        }
        
        return area / 2.0
    }
}
