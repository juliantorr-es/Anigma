/// GeometryCapsuleInternal.swift
/// Internal implementation for GeometryCapsule
/// 3D geometry operations with spatial calculations and transformations

import Foundation
import CoreGraphics
import simd

/// 3D point structure
public struct Point3D: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let z: Double
    
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// 3D vector structure
public struct Vector3D: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let z: Double
    
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public var magnitude: Double {
        return sqrt(x*x + y*y + z*z)
    }
    
    public var normalized: Vector3D {
        let mag = magnitude
        guard mag > 0 else { return Vector3D(x: 0, y: 0, z: 0) }
        return Vector3D(x: x/mag, y: y/mag, z: z/mag)
    }
}

/// 3D bounding box
public struct BoundingBox3D: Sendable {
    public let min: Point3D
    public let max: Point3D
    
    public init(min: Point3D, max: Point3D) {
        self.min = min
        self.max = max
    }
    
    public var center: Point3D {
        return Point3D(
            x: (min.x + max.x) / 2,
            y: (min.y + max.y) / 2,
            z: (min.z + max.z) / 2
        )
    }
    
    public var volume: Double {
        return (max.x - min.x) * (max.y - min.y) * (max.z - min.z)
    }
    
    public func intersects(_ other: BoundingBox3D) -> Bool {
        return (min.x <= other.max.x && max.x >= other.min.x) &&
               (min.y <= other.max.y && max.y >= other.min.y) &&
               (min.z <= other.max.z && max.z >= other.min.z)
    }
    
    public func contains(_ point: Point3D) -> Bool {
        return point.x >= min.x && point.x <= max.x &&
               point.y >= min.y && point.y <= max.y &&
               point.z >= min.z && point.z <= max.z
    }
}

/// Triangle mesh structure
public struct TriangleMesh: Sendable {
    public let vertices: [Point3D]
    public let normals: [Vector3D]?
    public let indices: [Int]
    
    public init(vertices: [Point3D], normals: [Vector3D]? = nil, indices: [Int]) {
        self.vertices = vertices
        self.normals = normals
        self.indices = indices
    }
    
    public var boundingBox: BoundingBox3D {
        guard !vertices.isEmpty else {
            return BoundingBox3D(
                min: Point3D(x: 0, y: 0, z: 0),
                max: Point3D(x: 0, y: 0, z: 0)
            )
        }
        
        let minX = vertices.map(\.x).min()!
        let maxX = vertices.map(\.x).max()!
        let minY = vertices.map(\.y).min()!
        let maxY = vertices.map(\.y).max()!
        let minZ = vertices.map(\.z).min()!
        let maxZ = vertices.map(\.z).max()!
        
        return BoundingBox3D(
            min: Point3D(x: minX, y: minY, z: minZ),
            max: Point3D(x: maxX, y: maxY, z: maxZ)
        )
    }
}

/// Transformation matrix (4x4)
public struct Transform3D: Sendable {
    public let matrix: simd_double4x4
    
    public init(matrix: simd_double4x4) {
        self.matrix = matrix
    }
    
    public static var identity: Transform3D {
        return Transform3D(matrix: simd_double4x4(diagonal: simd_double4(1, 1, 1, 1)))
    }
    
    public static func translation(x: Double, y: Double, z: Double) -> Transform3D {
        var matrix = simd_double4x4(diagonal: simd_double4(1, 1, 1, 1))
        matrix[3, 0] = x
        matrix[3, 1] = y
        matrix[3, 2] = z
        return Transform3D(matrix: matrix)
    }
    
    public static func rotation(angle: Double, axis: Vector3D) -> Transform3D {
        let axisNormalized = axis.normalized
        let cos = cos(angle)
        let sin = sin(angle)
        let oneMinusCos = 1 - cos
        
        var matrix = simd_double4x4(diagonal: simd_double4(1, 1, 1, 1))
        matrix[0, 0] = cos + axisNormalized.x * axisNormalized.x * oneMinusCos
        matrix[0, 1] = axisNormalized.x * axisNormalized.y * oneMinusCos - axisNormalized.z * sin
        matrix[0, 2] = axisNormalized.x * axisNormalized.z * oneMinusCos + axisNormalized.y * sin
        matrix[1, 0] = axisNormalized.y * axisNormalized.x * oneMinusCos + axisNormalized.z * sin
        matrix[1, 1] = cos + axisNormalized.y * axisNormalized.y * oneMinusCos
        matrix[1, 2] = axisNormalized.y * axisNormalized.z * oneMinusCos - axisNormalized.x * sin
        matrix[2, 0] = axisNormalized.z * axisNormalized.x * oneMinusCos - axisNormalized.y * sin
        matrix[2, 1] = axisNormalized.z * axisNormalized.y * oneMinusCos + axisNormalized.x * sin
        matrix[2, 2] = cos + axisNormalized.z * axisNormalized.z * oneMinusCos
        matrix[3, 3] = 1
        
        return Transform3D(matrix: matrix)
    }
    
    public static func scale(x: Double, y: Double, z: Double) -> Transform3D {
        var matrix = simd_double4x4(diagonal: simd_double4(1, 1, 1, 1))
        matrix[0, 0] = x
        matrix[1, 1] = y
        matrix[2, 2] = z
        return Transform3D(matrix: matrix)
    }
}

/// Geometry operation result
public struct GeometryOperationResult: Sendable {
    public let success: Bool
    public let operationTime: TimeInterval
    public let errorMessage: String?
    
    public init(success: Bool, operationTime: TimeInterval, errorMessage: String? = nil) {
        self.success = success
        self.operationTime = operationTime
        self.errorMessage = errorMessage
    }
}

/// Internal implementation of the GeometryCapsule processing logic.
/// Marked as Sendable to comply with Swift 6 concurrency requirements.
internal final class GeometryCapsuleInternal: Sendable {
    
    /// Initialize the internal implementation.
    internal init() {}
    
    /// Calculate distance between two 3D points
    /// - Parameters:
    ///   - point1: First point
    ///   - point2: Second point
    /// - Returns: Distance between points
    internal func distance(from point1: Point3D, to point2: Point3D) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        let dz = point2.z - point1.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    /// Calculate dot product of two 3D vectors
    /// - Parameters:
    ///   - vector1: First vector
    ///   - vector2: Second vector
    /// - Returns: Dot product
    internal func dotProduct(_ vector1: Vector3D, _ vector2: Vector3D) -> Double {
        return vector1.x * vector2.x + vector1.y * vector2.y + vector1.z * vector2.z
    }
    
    /// Calculate cross product of two 3D vectors
    /// - Parameters:
    ///   - vector1: First vector
    ///   - vector2: Second vector
    /// - Returns: Cross product vector
    internal func crossProduct(_ vector1: Vector3D, _ vector2: Vector3D) -> Vector3D {
        return Vector3D(
            x: vector1.y * vector2.z - vector1.z * vector2.y,
            y: vector1.z * vector2.x - vector1.x * vector2.z,
            z: vector1.x * vector2.y - vector1.y * vector2.x
        )
    }
    
    /// Apply transformation to a 3D point
    /// - Parameters:
    ///   - point: Point to transform
    ///   - transform: Transformation to apply
    /// - Returns: Transformed point
    internal func transformPoint(_ point: Point3D, with transform: Transform3D) throws -> Point3D {
        let vector = simd_double4(point.x, point.y, point.z, 1.0)
        let transformed = transform.matrix * vector
        
        // Check for NaN
        if transformed.x.isNaN || transformed.y.isNaN || transformed.z.isNaN {
             throw GeometryError.calculationFailed("Transformation resulted in NaN")
        }
        
        return Point3D(x: transformed.x, y: transformed.y, z: transformed.z)
    }
    
    /// Apply transformation to a triangle mesh
    /// - Parameters:
    ///   - mesh: Mesh to transform
    ///   - transform: Transformation to apply
    /// - Returns: Transformed mesh
    internal func transformMesh(_ mesh: TriangleMesh, with transform: Transform3D) throws -> TriangleMesh {
        var transformedVertices = [Point3D]()
        transformedVertices.reserveCapacity(mesh.vertices.count)
        
        for vertex in mesh.vertices {
             transformedVertices.append(try transformPoint(vertex, with: transform))
        }
        
        let transformedNormals: [Vector3D]? = mesh.normals?.compactMap { normal in
            let normalVector = simd_double4(normal.x, normal.y, normal.z, 0.0)
            let transformed = transform.matrix * normalVector
            let v = Vector3D(x: transformed.x, y: transformed.y, z: transformed.z)
            // Renormalize
            let mag = v.magnitude
            return mag > 0 ? v.normalized : nil
        }
        
        return TriangleMesh(
            vertices: transformedVertices,
            normals: transformedNormals,
            indices: mesh.indices
        )
    }
    
    /// Calculate bounding box for a set of points
    /// - Parameter points: Array of 3D points
    /// - Returns: Bounding box containing all points
    internal func calculateBoundingBox(for points: [Point3D]) throws -> BoundingBox3D {
        guard !points.isEmpty else {
            throw GeometryError.invalidGeometry("Cannot calculate bounding box for empty points")
        }
        
        let minX = points.map(\.x).min()!
        let maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!
        let minZ = points.map(\.z).min()!
        let maxZ = points.map(\.z).max()!
        
        return BoundingBox3D(
            min: Point3D(x: minX, y: minY, z: minZ),
            max: Point3D(x: maxX, y: maxY, z: maxZ)
        )
    }
    
    /// Check if two bounding boxes intersect
    /// - Parameters:
    ///   - box1: First bounding box
    ///   - box2: Second bounding box
    /// - Returns: True if boxes intersect
    internal func boundingBoxesIntersect(_ box1: BoundingBox3D, _ box2: BoundingBox3D) -> Bool {
        return box1.intersects(box2)
    }
    
    /// Calculate volume of a triangle mesh (simplified)
    /// - Parameter mesh: Triangle mesh
    /// - Returns: Volume of mesh
    internal func calculateMeshVolume(_ mesh: TriangleMesh) throws -> Double {
        // Validation
        if mesh.vertices.count < 3 { return 0.0 }
        
        // Signed volume of tetrahedron
        // This calculates the exact volume if the mesh is closed and orientable
        var volume: Double = 0.0
        
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard i + 2 < mesh.indices.count else { break }
            
            let v0 = mesh.vertices[mesh.indices[i]]
            let v1 = mesh.vertices[mesh.indices[i+1]]
            let v2 = mesh.vertices[mesh.indices[i+2]]
            
            volume += signedVolumeOfTriangle(v0, v1, v2)
        }
        
        return abs(volume)
    }
    
    private func signedVolumeOfTriangle(_ p1: Point3D, _ p2: Point3D, _ p3: Point3D) -> Double {
        let v321 = p3.x * p2.y * p1.z
        let v231 = p2.x * p3.y * p1.z
        let v312 = p3.x * p1.y * p2.z
        let v132 = p1.x * p3.y * p2.z
        let v213 = p2.x * p1.y * p3.z
        let v123 = p1.x * p2.y * p3.z
        
        return (1.0/6.0) * (-v321 + v231 + v312 - v132 - v213 + v123)
    }
    
    /// Calculate surface area of a triangle mesh
    /// - Parameter mesh: Triangle mesh
    /// - Returns: Surface area of mesh
    internal func calculateMeshSurfaceArea(_ mesh: TriangleMesh) -> Double {
        var totalArea: Double = 0
        
        // Calculate area for each triangle
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard i + 2 < mesh.indices.count else { break }
            
            let i0 = mesh.indices[i]
            let i1 = mesh.indices[i + 1]
            let i2 = mesh.indices[i + 2]
            
            guard i0 < mesh.vertices.count && i1 < mesh.vertices.count && i2 < mesh.vertices.count else { continue }
            
            let v0 = mesh.vertices[i0]
            let v1 = mesh.vertices[i1]
            let v2 = mesh.vertices[i2]
            
            // Calculate triangle area using cross product
            let edge1 = Vector3D(x: v1.x - v0.x, y: v1.y - v0.y, z: v1.z - v0.z)
            let edge2 = Vector3D(x: v2.x - v0.x, y: v2.y - v0.y, z: v2.z - v0.z)
            let cross = crossProduct(edge1, edge2)
            let area = 0.5 * cross.magnitude
            
            totalArea += area
        }
        
        return totalArea
    }
    
    /// Perform ray-triangle intersection test
    /// - Parameters:
    ///   - rayOrigin: Origin of ray
    ///   - rayDirection: Direction of ray (normalized)
    ///   - triangle: Array of 3 triangle vertices
    /// - Returns: Distance to intersection or nil if no intersection
    internal func rayTriangleIntersection(
        rayOrigin: Point3D,
        rayDirection: Vector3D,
        triangle: [Point3D]
    ) -> Double? {
        guard triangle.count == 3 else { return nil }
        
        // Möller–Trumbore intersection algorithm
        let edge1 = Vector3D(
            x: triangle[1].x - triangle[0].x,
            y: triangle[1].y - triangle[0].y,
            z: triangle[1].z - triangle[0].z
        )
        let edge2 = Vector3D(
            x: triangle[2].x - triangle[0].x,
            y: triangle[2].y - triangle[0].y,
            z: triangle[2].z - triangle[0].z
        )
        
        let h = crossProduct(rayDirection, edge2)
        let a = dotProduct(edge1, h)
        
        if abs(a) < 0.00001 { return nil } // Ray parallel to triangle
        
        let f = 1.0 / a
        let s = Vector3D(
            x: rayOrigin.x - triangle[0].x,
            y: rayOrigin.y - triangle[0].y,
            z: rayOrigin.z - triangle[0].z
        )
        let u = f * dotProduct(s, h)
        
        if u < 0.0 || u > 1.0 { return nil }
        
        let q = crossProduct(s, edge1)
        let v = f * dotProduct(rayDirection, q)
        
        if v < 0.0 || u + v > 1.0 { return nil }
        
        let t = f * dotProduct(edge2, q)
        
        return t > 0.00001 ? t : nil
    }
}

/// Geometry specific errors
public enum GeometryError: LocalizedError, Sendable {
    case invalidGeometry(String)
    case calculationFailed(String)
    case transformationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidGeometry(let message):
            return "Invalid geometry: \(message)"
        case .calculationFailed(let message):
            return "Calculation failed: \(message)"
        case .transformationFailed(let message):
            return "Transformation failed: \(message)"
        }
    }
}

// MARK: - Spatial Indexing (Octree)

/// A node in the Octree
internal final class OctreeNode: Sendable {
    let bounds: BoundingBox3D
    // Storing triangle indices
    var triangles: [Int] = []
    var children: [OctreeNode]? = nil
    
    init(bounds: BoundingBox3D) {
        self.bounds = bounds
    }
    
    func isLeaf() -> Bool {
        return children == nil
    }
}

/// Octree implementation for spatial indexing
public final class Octree: Sendable {
    private let root: OctreeNode
    private let maxDepth: Int
    private let maxTrianglesPerNode: Int
    
    // Original mesh data for reference
    private let meshVertices: [Point3D]
    private let meshIndices: [Int]
    
    public init(mesh: TriangleMesh, maxDepth: Int = 8, maxTrianglesPerNode: Int = 20) {
        self.maxDepth = maxDepth
        self.maxTrianglesPerNode = maxTrianglesPerNode
        self.meshVertices = mesh.vertices
        self.meshIndices = mesh.indices
        
        // Calculate root bounds
        self.root = OctreeNode(bounds: mesh.boundingBox)
        
        // Build the tree
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            insert(triangleIndex: i, into: root, depth: 0)
        }
    }
    
    private func insert(triangleIndex: Int, into node: OctreeNode, depth: Int) {
        if node.isLeaf() {
            if node.triangles.count < maxTrianglesPerNode || depth >= maxDepth {
                node.triangles.append(triangleIndex)
            } else {
                split(node)
                // Re-insert existing triangles
                for idx in node.triangles {
                    insertToChildren(triangleIndex: idx, node: node, depth: depth)
                }
                node.triangles.removeAll()
                // Insert new triangle
                insertToChildren(triangleIndex: triangleIndex, node: node, depth: depth)
            }
        } else {
            insertToChildren(triangleIndex: triangleIndex, node: node, depth: depth)
        }
    }
    
    private func insertToChildren(triangleIndex: Int, node: OctreeNode, depth: Int) {
        guard let children = node.children else { return }
        let triBounds = getTriangleBounds(index: triangleIndex)
        
        for child in children {
            if child.bounds.intersects(triBounds) {
                // Optimization: Check exact triangle-box intersection here if needed
                insert(triangleIndex: triangleIndex, into: child, depth: depth + 1)
            }
        }
    }
    
    private func split(_ node: OctreeNode) {
        let min = node.bounds.min
        let max = node.bounds.max
        let center = node.bounds.center
        
        let subBounds = [
            BoundingBox3D(min: min, max: center),
            BoundingBox3D(min: Point3D(x: center.x, y: min.y, z: min.z), max: Point3D(x: max.x, y: center.y, z: center.z)),
            BoundingBox3D(min: Point3D(x: min.x, y: center.y, z: min.z), max: Point3D(x: center.x, y: max.y, z: center.z)),
            BoundingBox3D(min: Point3D(x: center.x, y: center.y, z: min.z), max: Point3D(x: max.x, y: max.y, z: center.z)),
            BoundingBox3D(min: Point3D(x: min.x, y: min.y, z: center.z), max: Point3D(x: center.x, y: center.y, z: max.z)),
            BoundingBox3D(min: Point3D(x: center.x, y: min.y, z: center.z), max: Point3D(x: max.x, y: center.y, z: max.z)),
            BoundingBox3D(min: Point3D(x: min.x, y: center.y, z: center.z), max: Point3D(x: center.x, y: max.y, z: max.z)),
            BoundingBox3D(min: Point3D(x: center.x, y: center.y, z: center.z), max: max)
        ]
        
        node.children = subBounds.map { OctreeNode(bounds: $0) }
    }
    
    private func getTriangleBounds(index: Int) -> BoundingBox3D {
        let v1 = meshVertices[meshIndices[index]]
        let v2 = meshVertices[meshIndices[index+1]]
        let v3 = meshVertices[meshIndices[index+2]]
        
        let minX = min(v1.x, min(v2.x, v3.x))
        let minY = min(v1.y, min(v2.y, v3.y))
        let minZ = min(v1.z, min(v2.z, v3.z))
        
        let maxX = max(v1.x, max(v2.x, v3.x))
        let maxY = max(v1.y, max(v2.y, v3.y))
        let maxZ = max(v1.z, max(v2.z, v3.z))
        
        return BoundingBox3D(
            min: Point3D(x: minX, y: minY, z: minZ),
            max: Point3D(x: maxX, y: maxY, z: maxZ)
        )
    }
}
