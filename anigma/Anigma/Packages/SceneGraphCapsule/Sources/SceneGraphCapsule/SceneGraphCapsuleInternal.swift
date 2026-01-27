/// SceneGraphCapsuleInternal.swift
/// Internal implementation for SceneGraphCapsule
/// 3D scene graph operations with spatial indexing and lighting

import Foundation
import CoreGraphics
import simd

// MARK: - Core 3D Data Structures

/// 3D point structure
public struct Point3D: Sendable, Codable, Hashable {
    public let x: Double
    public let y: Double
    public let z: Double
    
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public static let zero = Point3D(x: 0, y: 0, z: 0)
}

/// 3D vector structure
public struct Vector3D: Sendable, Codable, Hashable {
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
    
    public static func +(lhs: Vector3D, rhs: Vector3D) -> Vector3D {
        return Vector3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
    
    public static func -(lhs: Vector3D, rhs: Vector3D) -> Vector3D {
        return Vector3D(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }
    
    public static func *(lhs: Vector3D, scalar: Double) -> Vector3D {
        return Vector3D(x: lhs.x * scalar, y: lhs.y * scalar, z: lhs.z * scalar)
    }
    
    public static let zero = Vector3D(x: 0, y: 0, z: 0)
    public static let up = Vector3D(x: 0, y: 1, z: 0)
    public static let right = Vector3D(x: 1, y: 0, z: 0)
    public static let forward = Vector3D(x: 0, y: 0, z: 1)
}

/// 3D bounding box
public struct BoundingBox3D: Sendable, Codable {
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
    
    public var size: Vector3D {
        return Vector3D(
            x: max.x - min.x,
            y: max.y - min.y,
            z: max.z - min.z
        )
    }
    
    public var volume: Double {
        return (max.x - min.x) * (max.y - min.y) * (max.z - min.z)
    }
    
    public func contains(_ point: Point3D) -> Bool {
        return point.x >= min.x && point.x <= max.x &&
               point.y >= min.y && point.y <= max.y &&
               point.z >= min.z && point.z <= max.z
    }
    
    public func intersects(_ other: BoundingBox3D) -> Bool {
        return (min.x <= other.max.x && max.x >= other.min.x) &&
               (min.y <= other.max.y && max.y >= other.min.y) &&
               (min.z <= other.max.z && max.z >= other.min.z)
    }
}

/// Transformation matrix (4x4)
public struct Transform3D: Sendable, Codable {
    public let matrix: simd_double4x4
    
    public init(matrix: simd_double4x4) {
        self.matrix = matrix
    }
    
    public static var identity: Transform3D {
        return Transform3D(matrix: simd_double4x4(diagonal: [1, 1, 1, 1]))
    }
    
    public static func translation(x: Double, y: Double, z: Double) -> Transform3D {
        var matrix = simd_double4x4(diagonal: [1, 1, 1, 1])
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
        
        var matrix = simd_double4x4()
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
        var matrix = simd_double4x4(diagonal: [1, 1, 1, 1])
        matrix[0, 0] = x
        matrix[1, 1] = y
        matrix[2, 2] = z
        return Transform3D(matrix: matrix)
    }
    
    public static func *(lhs: Transform3D, rhs: Transform3D) -> Transform3D {
        return Transform3D(matrix: lhs.matrix * rhs.matrix)
    }
}

// MARK: - Scene Graph Structures

/// Scene node identifier
public struct NodeID: Sendable, Codable, Hashable {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
}

/// Scene node types
public enum NodeType: String, Sendable, Codable, CaseIterable {
    case transform = "transform"
    case mesh = "mesh"
    case light = "light"
    case camera = "camera"
    case group = "group"
}

/// Component types for scene nodes
public enum ComponentType: String, Sendable, Codable, CaseIterable {
    case transform = "transform"
    case mesh = "mesh"
    case material = "material"
    case light = "light"
    case camera = "camera"
    case boundingBox = "boundingBox"
}

/// Scene graph node
public struct SceneNode: Sendable, Codable {
    public let id: NodeID
    public let type: NodeType
    public let name: String
    public let parentID: NodeID?
    public let childIDs: [NodeID]
    public let components: [ComponentType: Any]
    
    public init(id: NodeID, type: NodeType, name: String, parentID: NodeID? = nil, childIDs: [NodeID] = [], components: [ComponentType: Any] = [:]) {
        self.id = id
        self.type = type
        self.name = name
        self.parentID = parentID
        self.childIDs = childIDs
        self.components = components
    }
    
    public func with<T>(component type: ComponentType, as componentType: T.Type) -> T? {
        return components[type] as? T
    }
}

/// Triangle mesh structure
public struct TriangleMesh: Sendable, Codable {
    public let vertices: [Point3D]
    public let normals: [Vector3D]?
    public let indices: [Int]
    public let materialID: String?
    
    public init(vertices: [Point3D], normals: [Vector3D]? = nil, indices: [Int], materialID: String? = nil) {
        self.vertices = vertices
        self.normals = normals
        self.indices = indices
        self.materialID = materialID
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

// MARK: - Lighting Structures

/// Light types
public enum LightType: String, Sendable, Codable, CaseIterable {
    case directional = "directional"
    case point = "point"
    case spot = "spot"
    case ambient = "ambient"
}

/// Light component
public struct Light: Sendable, Codable {
    public let type: LightType
    public let color: Vector3D
    public let intensity: Double
    public let position: Point3D?
    public let direction: Vector3D?
    public let range: Double?
    public let innerConeAngle: Double?
    public let outerConeAngle: Double?
    
    public init(
        type: LightType,
        color: Vector3D,
        intensity: Double,
        position: Point3D? = nil,
        direction: Vector3D? = nil,
        range: Double? = nil,
        innerConeAngle: Double? = nil,
        outerConeAngle: Double? = nil
    ) {
        self.type = type
        self.color = color
        self.intensity = intensity
        self.position = position
        self.direction = direction
        self.range = range
        self.innerConeAngle = innerConeAngle
        self.outerConeAngle = outerConeAngle
    }
}

/// Material properties
public struct Material: Sendable, Codable {
    public let id: String
    public let baseColor: Vector3D
    public let metallic: Double
    public let roughness: Double
    public let emissive: Vector3D
    public let opacity: Double
    
    public init(
        id: String,
        baseColor: Vector3D,
        metallic: Double = 0.0,
        roughness: Double = 1.0,
        emissive: Vector3D = Vector3D.zero,
        opacity: Double = 1.0
    ) {
        self.id = id
        self.baseColor = baseColor
        self.metallic = metallic
        self.roughness = roughness
        self.emissive = emissive
        self.opacity = opacity
    }
}

// MARK: - Spatial Indexing

/// Octree node for spatial indexing
public struct OctreeNode: Sendable {
    public let boundingBox: BoundingBox3D
    public let objects: [SceneObject]
    public let children: [OctreeNode]?
    
    public init(boundingBox: BoundingBox3D, objects: [SceneObject] = [], children: [OctreeNode]? = nil) {
        self.boundingBox = boundingBox
        self.objects = objects
        self.children = children
    }
}

/// Scene object for spatial indexing
public struct SceneObject: Sendable {
    public let id: NodeID
    public let boundingBox: BoundingBox3D
    public let data: Any
    
    public init(id: NodeID, boundingBox: BoundingBox3D, data: Any) {
        self.id = id
        self.boundingBox = boundingBox
        self.data = data
    }
}

/// KD-tree node
public struct KDTreeNode: Sendable {
    public let axis: Int
    public let point: Point3D
    public let left: KDTreeNode?
    public let right: KDTreeNode?
    public let objects: [SceneObject]
    
    public init(axis: Int, point: Point3D, left: KDTreeNode? = nil, right: KDTreeNode? = nil, objects: [SceneObject] = []) {
        self.axis = axis
        self.point = point
        self.left = left
        self.right = right
        self.objects = objects
    }
}

/// Spatial grid
public struct SpatialGrid: Sendable {
    public let cellSize: Vector3D
    public let origin: Point3D
    public let cells: [String: [SceneObject]]
    
    public init(cellSize: Vector3D, origin: Point3D, cells: [String: [SceneObject]] = [:]) {
        self.cellSize = cellSize
        self.origin = origin
        self.cells = cells
    }
}

// MARK: - Scene Graph

/// Complete scene graph
public struct SceneGraph: Sendable, Codable {
    public let nodes: [NodeID: SceneNode]
    public let materials: [String: Material]
    public let rootID: NodeID
    
    public init(nodes: [NodeID: SceneNode], materials: [String: Material] = [:], rootID: NodeID) {
        self.nodes = nodes
        self.materials = materials
        self.rootID = rootID
    }
    
    public var nodeCount: Int {
        return nodes.count
    }
    
    public func node(withID id: NodeID) -> SceneNode? {
        return nodes[id]
    }
    
    public func children(of nodeID: NodeID) -> [SceneNode] {
        guard let node = nodes[nodeID] else { return [] }
        return node.childIDs.compactMap { nodes[$0] }
    }
    
    public func parent(of nodeID: NodeID) -> SceneNode? {
        guard let node = nodes[nodeID], let parentID = node.parentID else { return nil }
        return nodes[parentID]
    }
    
    public func material(withID id: String) -> Material? {
        return materials[id]
    }
}

// MARK: - Ray Casting

/// Ray for intersection testing
public struct Ray: Sendable, Codable {
    public let origin: Point3D
    public let direction: Vector3D
    
    public init(origin: Point3D, direction: Vector3D) {
        self.origin = origin
        self.direction = direction.normalized
    }
}

/// Ray intersection result
public struct RayIntersection: Sendable {
    public let point: Point3D
    public let normal: Vector3D
    public let distance: Double
    public let objectID: NodeID?
    
    public init(point: Point3D, normal: Vector3D, distance: Double, objectID: NodeID? = nil) {
        self.point = point
        self.normal = normal
        self.distance = distance
        self.objectID = objectID
    }
}

// MARK: - Errors

/// Scene graph specific errors
public enum SceneGraphError: LocalizedError, Sendable {
    case invalidNode(String)
    case invalidTransform(String)
    case invalidGeometry(String)
    case calculationFailed(String)
    case indexingFailed(String)
    case lightingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidNode(let message):
            return "Invalid node: \(message)"
        case .invalidTransform(let message):
            return "Invalid transform: \(message)"
        case .invalidGeometry(let message):
            return "Invalid geometry: \(message)"
        case .calculationFailed(let message):
            return "Calculation failed: \(message)"
        case .indexingFailed(let message):
            return "Indexing failed: \(message)"
        case .lightingFailed(let message):
            return "Lighting calculation failed: \(message)"
        }
    }
}

// MARK: - Internal Implementation

/// Internal implementation of the SceneGraphCapsule processing logic.
/// Marked as Sendable to comply with Swift 6 concurrency requirements.
internal final class SceneGraphCapsuleInternal: Sendable {
    
    /// Initialize the internal implementation.
    internal init() {}
    
    // MARK: - Basic 3D Operations
    
    /// Calculate distance between two 3D points
    internal func distance(from point1: Point3D, to point2: Point3D) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        let dz = point2.z - point1.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    /// Calculate dot product of two 3D vectors
    internal func dotProduct(_ vector1: Vector3D, _ vector2: Vector3D) -> Double {
        return vector1.x * vector2.x + vector1.y * vector2.y + vector1.z * vector2.z
    }
    
    /// Calculate cross product of two 3D vectors
    internal func crossProduct(_ vector1: Vector3D, _ vector2: Vector3D) -> Vector3D {
        return Vector3D(
            x: vector1.y * vector2.z - vector1.z * vector2.y,
            y: vector1.z * vector2.x - vector1.x * vector2.z,
            z: vector1.x * vector2.y - vector1.y * vector2.x
        )
    }
    
    /// Apply transformation to a 3D point
    internal func transformPoint(_ point: Point3D, with transform: Transform3D) -> Point3D {
        let vector = simd_double4(point.x, point.y, point.z, 1.0)
        let transformed = transform.matrix * vector
        return Point3D(x: transformed.x, y: transformed.y, z: transformed.z)
    }
    
    /// Apply transformation to a 3D vector (direction only)
    internal func transformVector(_ vector: Vector3D, with transform: Transform3D) -> Vector3D {
        let simdVector = simd_double4(vector.x, vector.y, vector.z, 0.0)
        let transformed = transform.matrix * simdVector
        return Vector3D(x: transformed.x, y: transformed.y, z: transformed.z)
    }
    
    // MARK: - Scene Graph Operations
    
    /// Create a new scene graph
    internal func createSceneGraph(rootNode: SceneNode) -> SceneGraph {
        return SceneGraph(nodes: [rootNode.id: rootNode], rootID: rootNode.id)
    }
    
    /// Add a node to the scene graph
    internal func addNode(_ node: SceneNode, to sceneGraph: SceneGraph) -> SceneGraph {
        var newNodes = sceneGraph.nodes
        newNodes[node.id] = node
        
        // Update parent's child list if parent exists
        if let parentID = node.parentID, var parent = newNodes[parentID] {
            parent = SceneNode(
                id: parent.id,
                type: parent.type,
                name: parent.name,
                parentID: parent.parentID,
                childIDs: parent.childIDs + [node.id],
                components: parent.components
            )
            newNodes[parentID] = parent
        }
        
        return SceneGraph(nodes: newNodes, materials: sceneGraph.materials, rootID: sceneGraph.rootID)
    }
    
    /// Remove a node from the scene graph
    internal func removeNode(_ nodeID: NodeID, from sceneGraph: SceneGraph) -> SceneGraph {
        guard sceneGraph.nodes[nodeID] != nil else { return sceneGraph }
        
        var newNodes = sceneGraph.nodes
        
        // Remove node from parent's child list
        if let node = newNodes[nodeID], let parentID = node.parentID, var parent = newNodes[parentID] {
            parent = SceneNode(
                id: parent.id,
                type: parent.type,
                name: parent.name,
                parentID: parent.parentID,
                childIDs: parent.childIDs.filter { $0 != nodeID },
                components: parent.components
            )
            newNodes[parentID] = parent
        }
        
        // Remove node and all its descendants
        func removeRecursively(_ id: NodeID) {
            guard let node = newNodes[id] else { return }
            for childID in node.childIDs {
                removeRecursively(childID)
            }
            newNodes.removeValue(forKey: id)
        }
        
        removeRecursively(nodeID)
        
        return SceneGraph(nodes: newNodes, materials: sceneGraph.materials, rootID: sceneGraph.rootID)
    }
    
    /// Get world transform for a node
    internal func getWorldTransform(for nodeID: NodeID, in sceneGraph: SceneGraph) -> Transform3D? {
        var currentTransform = Transform3D.identity
        var currentNodeID = nodeID
        
        while let node = sceneGraph.nodes[currentNodeID] {
            if let transform = node.components[.transform] as? Transform3D {
                currentTransform = transform * currentTransform
            }
            guard let parentID = node.parentID else { break }
            currentNodeID = parentID
        }
        
        return currentTransform
    }
    
    /// Calculate bounding box for a node and all its children
    internal func calculateNodeBoundingBox(_ nodeID: NodeID, in sceneGraph: SceneGraph) -> BoundingBox3D? {
        guard let node = sceneGraph.nodes[nodeID] else { return nil }
        
        var boundingBoxes: [BoundingBox3D] = []
        
        // Add node's own bounding box if it has mesh
        if let mesh = node.components[.mesh] as? TriangleMesh {
            boundingBoxes.append(mesh.boundingBox)
        }
        
        // Add children's bounding boxes
        for childID in node.childIDs {
            if let childBox = calculateNodeBoundingBox(childID, in: sceneGraph) {
                // Transform child box to world space
                if let worldTransform = getWorldTransform(for: childID, in: sceneGraph) {
                    let transformedMin = transformPoint(childBox.min, with: worldTransform)
                    let transformedMax = transformPoint(childBox.max, with: worldTransform)
                    boundingBoxes.append(BoundingBox3D(min: transformedMin, max: transformedMax))
                } else {
                    boundingBoxes.append(childBox)
                }
            }
        }
        
        // Merge all bounding boxes
        guard !boundingBoxes.isEmpty else { return nil }
        
        let minX = boundingBoxes.map(\.min.x).min()!
        let maxX = boundingBoxes.map(\.max.x).max()!
        let minY = boundingBoxes.map(\.min.y).min()!
        let maxY = boundingBoxes.map(\.max.y).max()!
        let minZ = boundingBoxes.map(\.min.z).min()!
        let maxZ = boundingBoxes.map(\.max.z).max()!
        
        return BoundingBox3D(
            min: Point3D(x: minX, y: minY, z: minZ),
            max: Point3D(x: maxX, y: maxY, z: maxZ)
        )
    }
    
    // MARK: - Spatial Indexing
    
    /// Build an octree for spatial indexing
    internal func buildOctree(objects: [SceneObject], boundingBox: BoundingBox3D, maxDepth: Int = 8, maxObjectsPerNode: Int = 10) -> OctreeNode {
        return buildOctreeRecursive(objects: objects, boundingBox: boundingBox, depth: 0, maxDepth: maxDepth, maxObjectsPerNode: maxObjectsPerNode)
    }
    
    private func buildOctreeRecursive(objects: [SceneObject], boundingBox: BoundingBox3D, depth: Int, maxDepth: Int, maxObjectsPerNode: Int) -> OctreeNode {
        // Base case: leaf node
        if objects.count <= maxObjectsPerNode || depth >= maxDepth {
            return OctreeNode(boundingBox: boundingBox, objects: objects)
        }
        
        // Split into 8 octants
        let center = boundingBox.center
        let size = boundingBox.size * 0.5
        
        let octants = [
            BoundingBox3D(min: Point3D(x: center.x - size.x, y: center.y - size.y, z: center.z - size.z), max: center),
            BoundingBox3D(min: Point3D(x: center.x, y: center.y - size.y, z: center.z - size.z), max: Point3D(x: center.x + size.x, y: center.y, z: center.z)),
            BoundingBox3D(min: Point3D(x: center.x - size.x, y: center.y, z: center.z - size.z), max: Point3D(x: center.x, y: center.y + size.y, z: center.z)),
            BoundingBox3D(min: center, max: Point3D(x: center.x + size.x, y: center.y + size.y, z: center.z + size.z)),
            BoundingBox3D(min: Point3D(x: center.x - size.x, y: center.y - size.y, z: center.z), max: Point3D(x: center.x, y: center.y, z: center.z + size.z)),
            BoundingBox3D(min: Point3D(x: center.x, y: center.y - size.y, z: center.z), max: Point3D(x: center.x + size.x, y: center.y, z: center.z + size.z)),
            BoundingBox3D(min: Point3D(x: center.x - size.x, y: center.y, z: center.z), max: Point3D(x: center.x, y: center.y + size.y, z: center.z + size.z)),
            BoundingBox3D(min: center, max: Point3D(x: center.x + size.x, y: center.y + size.y, z: center.z + size.z))
        ]
        
        var children: [OctreeNode] = []
        for octant in octants {
            let octantObjects = objects.filter { $0.boundingBox.intersects(octant) }
            if !octantObjects.isEmpty {
                children.append(buildOctreeRecursive(objects: octantObjects, boundingBox: octant, depth: depth + 1, maxDepth: maxDepth, maxObjectsPerNode: maxObjectsPerNode))
            }
        }
        
        return OctreeNode(boundingBox: boundingBox, objects: [], children: children.isEmpty ? nil : children)
    }
    
    /// Build a KD-tree for spatial indexing
    internal func buildKDTree(objects: [SceneObject], depth: Int = 0) -> KDTreeNode? {
        guard !objects.isEmpty else { return nil }
        
        let axis = depth % 3
        let sortedObjects = objects.sorted { obj1, obj2 in
            let coord1 = axis == 0 ? obj1.boundingBox.center.x : (axis == 1 ? obj1.boundingBox.center.y : obj1.boundingBox.center.z)
            let coord2 = axis == 0 ? obj2.boundingBox.center.x : (axis == 1 ? obj2.boundingBox.center.y : obj2.boundingBox.center.z)
            return coord1 < coord2
        }
        
        let medianIndex = sortedObjects.count / 2
        let medianObject = sortedObjects[medianIndex]
        let medianPoint = medianObject.boundingBox.center
        
        let leftObjects = Array(sortedObjects[..<medianIndex])
        let rightObjects = Array(sortedObjects[(medianIndex + 1)...])
        
        let leftChild = leftObjects.isEmpty ? nil : buildKDTree(objects: leftObjects, depth: depth + 1)
        let rightChild = rightObjects.isEmpty ? nil : buildKDTree(objects: rightObjects, depth: depth + 1)
        
        return KDTreeNode(
            axis: axis,
            point: medianPoint,
            left: leftChild,
            right: rightChild,
            objects: [medianObject]
        )
    }
    
    /// Build a spatial grid for indexing
    internal func buildSpatialGrid(objects: [SceneObject], cellSize: Vector3D, origin: Point3D) -> SpatialGrid {
        var cells: [String: [SceneObject]] = [:]
        
        for object in objects {
            let minCell = cellCoordinate(for: object.boundingBox.min, cellSize: cellSize, origin: origin)
            let maxCell = cellCoordinate(for: object.boundingBox.max, cellSize: cellSize, origin: origin)
            
            for x in minCell.x...maxCell.x {
                for y in minCell.y...maxCell.y {
                    for z in minCell.z...maxCell.z {
                        let cellKey = "\(x),\(y),\(z)"
                        if cells[cellKey] == nil {
                            cells[cellKey] = []
                        }
                        cells[cellKey]?.append(object)
                    }
                }
            }
        }
        
        return SpatialGrid(cellSize: cellSize, origin: origin, cells: cells)
    }
    
    private func cellCoordinate(for point: Point3D, cellSize: Vector3D, origin: Point3D) -> Point3D {
        return Point3D(
            x: Int((point.x - origin.x) / cellSize.x),
            y: Int((point.y - origin.y) / cellSize.y),
            z: Int((point.z - origin.z) / cellSize.z)
        )
    }
    
    // MARK: - Ray Casting
    
    /// Perform ray-box intersection test
    internal func rayBoxIntersection(_ ray: Ray, boundingBox: BoundingBox3D) -> RayIntersection? {
        let min = boundingBox.min
        let max = boundingBox.max
        
        let invDir = Vector3D(x: 1.0 / ray.direction.x, y: 1.0 / ray.direction.y, z: 1.0 / ray.direction.z)
        
        var t1 = (min.x - ray.origin.x) * invDir.x
        var t2 = (max.x - ray.origin.x) * invDir.x
        var tmin = min(t1, t2)
        var tmax = max(t1, t2)
        
        t1 = (min.y - ray.origin.y) * invDir.y
        t2 = (max.y - ray.origin.y) * invDir.y
        tmin = max(tmin, min(t1, t2))
        tmax = min(tmax, max(t1, t2))
        
        t1 = (min.z - ray.origin.z) * invDir.z
        t2 = (max.z - ray.origin.z) * invDir.z
        tmin = max(tmin, min(t1, t2))
        tmax = min(tmax, max(t1, t2))
        
        if tmax >= max(0, tmin) {
            let point = Point3D(
                x: ray.origin.x + ray.direction.x * tmin,
                y: ray.origin.y + ray.direction.y * tmin,
                z: ray.origin.z + ray.direction.z * tmin
            )
            return RayIntersection(point: point, normal: Vector3D.up, distance: tmin)
        }
        
        return nil
    }
    
    /// Perform ray-triangle intersection test
    internal func rayTriangleIntersection(_ ray: Ray, triangle: (Point3D, Point3D, Point3D)) -> RayIntersection? {
        let (v0, v1, v2) = triangle
        
        let edge1 = Vector3D(x: v1.x - v0.x, y: v1.y - v0.y, z: v1.z - v0.z)
        let edge2 = Vector3D(x: v2.x - v0.x, y: v2.y - v0.y, z: v2.z - v0.z)
        
        let h = crossProduct(ray.direction, edge2)
        let a = dotProduct(edge1, h)
        
        if abs(a) < 0.00001 { return nil } // Ray parallel to triangle
        
        let f = 1.0 / a
        let s = Vector3D(x: ray.origin.x - v0.x, y: ray.origin.y - v0.y, z: ray.origin.z - v0.z)
        let u = f * dotProduct(s, h)
        
        if u < 0.0 || u > 1.0 { return nil }
        
        let q = crossProduct(s, edge1)
        let v = f * dotProduct(ray.direction, q)
        
        if v < 0.0 || u + v > 1.0 { return nil }
        
        let t = f * dotProduct(edge2, q)
        
        if t > 0.00001 {
            let point = Point3D(
                x: ray.origin.x + ray.direction.x * t,
                y: ray.origin.y + ray.direction.y * t,
                z: ray.origin.z + ray.direction.z * t
            )
            let normal = crossProduct(edge1, edge2).normalized
            return RayIntersection(point: point, normal: normal, distance: t)
        }
        
        return nil
    }
    
    // MARK: - Lighting Calculations
    
    /// Calculate lighting for a point using Phong shading
    internal func calculatePhongLighting(
        point: Point3D,
        normal: Vector3D,
        viewDirection: Vector3D,
        material: Material,
        lights: [Light]
    ) -> Vector3D {
        let normalizedNormal = normal.normalized
        let normalizedViewDir = viewDirection.normalized
        
        var ambient = material.baseColor * 0.1 // Ambient term
        var diffuse = Vector3D.zero
        var specular = Vector3D.zero
        
        for light in lights {
            switch light.type {
            case .ambient:
                ambient = ambient + (material.baseColor * light.color * light.intensity * 0.2)
                
            case .directional:
                if let lightDir = light.direction {
                    let lightIntensity = max(0, dotProduct(normalizedNormal, lightDir.normalized * -1))
                    diffuse = diffuse + (material.baseColor * light.color * light.intensity * lightIntensity)
                    
                    // Specular term
                    let reflectDir = reflect(lightDir.normalized * -1, normal: normalizedNormal)
                    let specIntensity = pow(max(0, dotProduct(normalizedViewDir, reflectDir)), 32.0)
                    specular = specular + (light.color * light.intensity * specIntensity * material.metallic)
                }
                
            case .point:
                if let lightPos = light.position {
                    let lightDir = Vector3D(x: lightPos.x - point.x, y: lightPos.y - point.y, z: lightPos.z - point.z)
                    let distance = lightDir.magnitude
                    
                    let attenuation = light.range.map { max(0, 1 - distance / $0) } ?? 1.0
                    let lightIntensity = max(0, dotProduct(normalizedNormal, lightDir.normalized)) * attenuation
                    
                    diffuse = diffuse + (material.baseColor * light.color * light.intensity * lightIntensity)
                    
                    // Specular term
                    let reflectDir = reflect(lightDir.normalized * -1, normal: normalizedNormal)
                    let specIntensity = pow(max(0, dotProduct(normalizedViewDir, reflectDir)), 32.0)
                    specular = specular + (light.color * light.intensity * specIntensity * material.metallic * attenuation)
                }
                
            case .spot:
                if let lightPos = light.position, let lightDir = light.direction {
                    let toLight = Vector3D(x: lightPos.x - point.x, y: lightPos.y - point.y, z: lightPos.z - point.z)
                    let distance = toLight.magnitude
                    
                    let spotEffect = dotProduct((lightDir.normalized * -1), toLight.normalized)
                    let innerCone = light.innerConeAngle ?? cos(0.1)
                    let outerCone = light.outerConeAngle ?? cos(0.3)
                    
                    let spotIntensity = smoothstep(innerCone, outerCone, spotEffect)
                    let attenuation = light.range.map { max(0, 1 - distance / $0) } ?? 1.0
                    let lightIntensity = max(0, dotProduct(normalizedNormal, toLight.normalized)) * spotIntensity * attenuation
                    
                    diffuse = diffuse + (material.baseColor * light.color * light.intensity * lightIntensity)
                    
                    // Specular term
                    let reflectDir = reflect(toLight.normalized * -1, normal: normalizedNormal)
                    let specIntensity = pow(max(0, dotProduct(normalizedViewDir, reflectDir)), 32.0)
                    specular = specular + (light.color * light.intensity * specIntensity * material.metallic * spotIntensity * attenuation)
                }
            }
        }
        
        // Combine terms
        let finalColor = ambient + diffuse * (1 - material.metallic) + specular + material.emissive
        return finalColor * material.opacity
    }
    
    private func reflect(_ incident: Vector3D, normal: Vector3D) -> Vector3D {
        return incident - normal * (2 * dotProduct(incident, normal))
    }
    
    private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}