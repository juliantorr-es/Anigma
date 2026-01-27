/// SceneGraphCapsule.swift
/// Public API for SceneGraphCapsule
/// Tier 1: 3D scene graph operations with spatial indexing and lighting
///
/// This file provides:
/// - Contract 1: CapsuleError for all public failures
/// - Contract 2: CapsuleDiagnostics for observability
/// - Sendable compliance (Swift 6)
/// - 3D scene graph operations
/// - Spatial indexing (octree, KD-tree, grid)
/// - Lighting calculations
/// - Transformations and bounding boxes

import Foundation
import CapsuleCore
import TelemetryCore

/// The SceneGraphCapsule public API
/// 3D scene graph operations with spatial indexing and lighting
public final class SceneGraphCapsule: Sendable {
    /// Unique identifier for this capsule instance
    public let id: String
    
    /// Diagnostics for observability (correlation ID tracking, span timing)
    private let diagnostics: CapsuleDiagnostics
    
    /// Internal implementation (separated for clarity)
    private nonisolated let impl: SceneGraphCapsuleInternal
    
    /// Initialize a SceneGraphCapsule instance
    /// - Parameters:
    ///   - id: Unique identifier for this capsule (UUID recommended)
    ///   - diagnostics: Diagnostics collector for observability
    /// - Throws: `CapsuleError.invalidConfiguration` if id is empty or invalid
    public init(
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        // Validate configuration (Contract 1 gate)
        guard !id.isEmpty else {
            throw CapsuleError.invalidConfiguration(reason: "Capsule ID cannot be empty")
        }
        
        self.id = id
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        self.impl = SceneGraphCapsuleInternal()
        
        // Emit initialization event
        let span = self.diagnostics.beginSpan(
            name: "SceneGraphCapsule.init",
            category: "initialization",
            correlationID: nil,
            tags: ["capsule_id": id]
        )
        span.end(status: .ok)
    }
    
    // MARK: - Basic 3D Operations
    
    /// Calculate distance between two 3D points
    /// - Parameters:
    ///   - point1: First point
    ///   - point2: Second point
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Distance between points
    /// - Throws: `CapsuleError` variants for calculation failures
    public func calculateDistance(
        from point1: Point3D,
        to point2: Point3D,
        correlationID: String? = nil
    ) async throws -> Double {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.calculateDistance",
            category: "distance_calculation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "point1": "(\(point1.x),\(point1.y),\(point1.z))",
                "point2": "(\(point2.x),\(point2.y),\(point2.z))"
            ]
        )
        
        diagnostics.event(
            level: .debug,
            category: "scenegraphcapsule.calculateDistance",
            message: "Calculating distance between points",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        let distance = impl.distance(from: point1, to: point2)
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.calculateDistance",
            message: "Distance calculation completed",
            correlationID: corrID,
            metadata: ["distance": "\(distance)"]
        )
        
        span.end(status: .ok)
        return distance
    }
    
    /// Apply transformation to a 3D point
    /// - Parameters:
    ///   - point: Point to transform
    ///   - transform: Transformation to apply
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Transformed point
    /// - Throws: `CapsuleError` variants for transformation failures
    public func transformPoint(
        _ point: Point3D,
        with transform: Transform3D,
        correlationID: String? = nil
    ) async throws -> Point3D {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.transformPoint",
            category: "point_transformation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "point": "(\(point.x),\(point.y),\(point.z))"
            ]
        )
        
        diagnostics.event(
            level: .debug,
            category: "scenegraphcapsule.transformPoint",
            message: "Transforming point",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let transformedPoint = impl.transformPoint(point, with: transform)
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.transformPoint",
                message: "Point transformation completed",
                correlationID: corrID,
                metadata: [
                    "result": "(\(transformedPoint.x),\(transformedPoint.y),\(transformedPoint.z))"
                ]
            )
            
            span.end(status: .ok)
            return transformedPoint
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.transformPoint",
                message: "Point transformation failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .invalidTransform, .invalidGeometry:
                throw CapsuleError.invalidInput(field: "transform", constraint: sceneError.localizedDescription)
            case .calculationFailed:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    // MARK: - Scene Graph Operations
    
    /// Create a new scene graph
    /// - Parameters:
    ///   - rootNode: Root node of the scene graph
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Created scene graph
    /// - Throws: `CapsuleError` variants for creation failures
    public func createSceneGraph(
        rootNode: SceneNode,
        correlationID: String? = nil
    ) async throws -> SceneGraph {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.createSceneGraph",
            category: "scene_graph_creation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "root_node_id": rootNode.id.value,
                "root_node_type": rootNode.type.rawValue
            ]
        )
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.createSceneGraph",
            message: "Creating scene graph with root node: \(rootNode.name)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let sceneGraph = impl.createSceneGraph(rootNode: rootNode)
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.createSceneGraph",
                message: "Scene graph created successfully",
                correlationID: corrID,
                metadata: ["node_count": "\(sceneGraph.nodeCount)"]
            )
            
            span.end(status: .ok)
            return sceneGraph
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.createSceneGraph",
                message: "Scene graph creation failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .invalidNode:
                throw CapsuleError.invalidInput(field: "rootNode", constraint: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Add a node to the scene graph
    /// - Parameters:
    ///   - node: Node to add
    ///   - sceneGraph: Scene graph to add node to
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Updated scene graph
    /// - Throws: `CapsuleError` variants for addition failures
    public func addNode(
        _ node: SceneNode,
        to sceneGraph: SceneGraph,
        correlationID: String? = nil
    ) async throws -> SceneGraph {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.addNode",
            category: "node_addition",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "node_id": node.id.value,
                "node_type": node.type.rawValue
            ]
        )
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.addNode",
            message: "Adding node to scene graph: \(node.name)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let updatedSceneGraph = impl.addNode(node, to: sceneGraph)
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.addNode",
                message: "Node added successfully",
                correlationID: corrID,
                metadata: ["new_node_count": "\(updatedSceneGraph.nodeCount)"]
            )
            
            span.end(status: .ok)
            return updatedSceneGraph
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.addNode",
                message: "Node addition failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .invalidNode:
                throw CapsuleError.invalidInput(field: "node", constraint: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Remove a node from the scene graph
    /// - Parameters:
    ///   - nodeID: ID of node to remove
    ///   - sceneGraph: Scene graph to remove node from
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Updated scene graph
    /// - Throws: `CapsuleError` variants for removal failures
    public func removeNode(
        _ nodeID: NodeID,
        from sceneGraph: SceneGraph,
        correlationID: String? = nil
    ) async throws -> SceneGraph {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.removeNode",
            category: "node_removal",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "node_id": nodeID.value
            ]
        )
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.removeNode",
            message: "Removing node from scene graph: \(nodeID.value)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let updatedSceneGraph = impl.removeNode(nodeID, from: sceneGraph)
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.removeNode",
                message: "Node removed successfully",
                correlationID: corrID,
                metadata: ["new_node_count": "\(updatedSceneGraph.nodeCount)"]
            )
            
            span.end(status: .ok)
            return updatedSceneGraph
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.removeNode",
                message: "Node removal failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .invalidNode:
                throw CapsuleError.invalidInput(field: "nodeID", constraint: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get world transform for a node
    /// - Parameters:
    ///   - nodeID: ID of node
    ///   - sceneGraph: Scene graph containing the node
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: World transform of the node
    /// - Throws: `CapsuleError` variants for lookup failures
    public func getWorldTransform(
        for nodeID: NodeID,
        in sceneGraph: SceneGraph,
        correlationID: String? = nil
    ) async throws -> Transform3D {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.getWorldTransform",
            category: "transform_lookup",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "node_id": nodeID.value
            ]
        )
        
        diagnostics.event(
            level: .debug,
            category: "scenegraphcapsule.getWorldTransform",
            message: "Getting world transform for node: \(nodeID.value)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        guard let worldTransform = impl.getWorldTransform(for: nodeID, in: sceneGraph) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "nodeID",
                constraint: "Node not found in scene graph"
            )
        }
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.getWorldTransform",
            message: "World transform retrieved successfully",
            correlationID: corrID,
            metadata: [:]
        )
        
        span.end(status: .ok)
        return worldTransform
    }
    
    /// Calculate bounding box for a node and all its children
    /// - Parameters:
    ///   - nodeID: ID of node
    ///   - sceneGraph: Scene graph containing the node
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Bounding box containing the node and its children
    /// - Throws: `CapsuleError` variants for calculation failures
    public func calculateNodeBoundingBox(
        _ nodeID: NodeID,
        in sceneGraph: SceneGraph,
        correlationID: String? = nil
    ) async throws -> BoundingBox3D {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.calculateNodeBoundingBox",
            category: "bounding_box_calculation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "node_id": nodeID.value
            ]
        )
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.calculateNodeBoundingBox",
            message: "Calculating bounding box for node: \(nodeID.value)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            guard let boundingBox = impl.calculateNodeBoundingBox(nodeID, in: sceneGraph) else {
                span.end(status: .error)
                throw CapsuleError.invalidInput(
                    field: "nodeID",
                    constraint: "Node not found in scene graph"
                )
            }
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.calculateNodeBoundingBox",
                message: "Bounding box calculation completed",
                correlationID: corrID,
                metadata: [
                    "volume": "\(boundingBox.volume)",
                    "center": "(\(boundingBox.center.x),\(boundingBox.center.y),\(boundingBox.center.z))"
                ]
            )
            
            span.end(status: .ok)
            return boundingBox
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.calculateNodeBoundingBox",
                message: "Bounding box calculation failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .invalidNode, .invalidGeometry:
                throw CapsuleError.invalidInput(field: "nodeID", constraint: sceneError.localizedDescription)
            case .calculationFailed:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    // MARK: - Spatial Indexing
    
    /// Build an octree for spatial indexing
    /// - Parameters:
    ///   - objects: Objects to index
    ///   - boundingBox: Bounding box for the octree
    ///   - maxDepth: Maximum depth of the octree (default: 8)
    ///   - maxObjectsPerNode: Maximum objects per node before splitting (default: 10)
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Built octree
    /// - Throws: `CapsuleError` variants for indexing failures
    public func buildOctree(
        objects: [SceneObject],
        boundingBox: BoundingBox3D,
        maxDepth: Int = 8,
        maxObjectsPerNode: Int = 10,
        correlationID: String? = nil
    ) async throws -> OctreeNode {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.buildOctree",
            category: "octree_construction",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "object_count": "\(objects.count)",
                "max_depth": "\(maxDepth)"
            ]
        )
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.buildOctree",
            message: "Building octree for \(objects.count) objects",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let octree = impl.buildOctree(
                objects: objects,
                boundingBox: boundingBox,
                maxDepth: maxDepth,
                maxObjectsPerNode: maxObjectsPerNode
            )
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.buildOctree",
                message: "Octree built successfully",
                correlationID: corrID,
                metadata: [:]
            )
            
            span.end(status: .ok)
            return octree
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.buildOctree",
                message: "Octree construction failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .indexingFailed:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Build a KD-tree for spatial indexing
    /// - Parameters:
    ///   - objects: Objects to index
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Built KD-tree
    /// - Throws: `CapsuleError` variants for indexing failures
    public func buildKDTree(
        objects: [SceneObject],
        correlationID: String? = nil
    ) async throws -> KDTreeNode? {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.buildKDTree",
            category: "kdtree_construction",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "object_count": "\(objects.count)"
            ]
        )
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.buildKDTree",
            message: "Building KD-tree for \(objects.count) objects",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let kdTree = impl.buildKDTree(objects: objects)
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.buildKDTree",
                message: "KD-tree built successfully",
                correlationID: corrID,
                metadata: [:]
            )
            
            span.end(status: .ok)
            return kdTree
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.buildKDTree",
                message: "KD-tree construction failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .indexingFailed:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Build a spatial grid for indexing
    /// - Parameters:
    ///   - objects: Objects to index
    ///   - cellSize: Size of each grid cell
    ///   - origin: Origin of the grid
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Built spatial grid
    /// - Throws: `CapsuleError` variants for indexing failures
    public func buildSpatialGrid(
        objects: [SceneObject],
        cellSize: Vector3D,
        origin: Point3D,
        correlationID: String? = nil
    ) async throws -> SpatialGrid {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.buildSpatialGrid",
            category: "spatial_grid_construction",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "object_count": "\(objects.count)",
                "cell_size": "(\(cellSize.x),\(cellSize.y),\(cellSize.z))"
            ]
        )
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.buildSpatialGrid",
            message: "Building spatial grid for \(objects.count) objects",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let spatialGrid = impl.buildSpatialGrid(
                objects: objects,
                cellSize: cellSize,
                origin: origin
            )
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.buildSpatialGrid",
                message: "Spatial grid built successfully",
                correlationID: corrID,
                metadata: [
                    "cell_count": "\(spatialGrid.cells.count)"
                ]
            )
            
            span.end(status: .ok)
            return spatialGrid
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.buildSpatialGrid",
                message: "Spatial grid construction failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .indexingFailed:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    // MARK: - Ray Casting
    
    /// Perform ray-box intersection test
    /// - Parameters:
    ///   - ray: Ray to cast
    ///   - boundingBox: Bounding box to test against
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Intersection result if hit
    /// - Throws: `CapsuleError` variants for intersection failures
    public func rayBoxIntersection(
        _ ray: Ray,
        boundingBox: BoundingBox3D,
        correlationID: String? = nil
    ) async throws -> RayIntersection? {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.rayBoxIntersection",
            category: "ray_intersection",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "ray_origin": "(\(ray.origin.x),\(ray.origin.y),\(ray.origin.z))"
            ]
        )
        
        diagnostics.event(
            level: .debug,
            category: "scenegraphcapsule.rayBoxIntersection",
            message: "Performing ray-box intersection test",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let intersection = impl.rayBoxIntersection(ray, boundingBox: boundingBox)
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.rayBoxIntersection",
                message: "Ray-box intersection test completed",
                correlationID: corrID,
                metadata: [
                    "hit": "\(intersection != nil)"
                ]
            )
            
            span.end(status: .ok)
            return intersection
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.rayBoxIntersection",
                message: "Ray-box intersection failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .calculationFailed:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    // MARK: - Lighting Calculations
    
    /// Calculate lighting for a point using Phong shading
    /// - Parameters:
    ///   - point: Point to light
    ///   - normal: Normal at the point
    ///   - viewDirection: Direction to viewer
    ///   - material: Material properties
    ///   - lights: Array of lights in the scene
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Calculated color
    /// - Throws: `CapsuleError` variants for lighting failures
    public func calculatePhongLighting(
        point: Point3D,
        normal: Vector3D,
        viewDirection: Vector3D,
        material: Material,
        lights: [Light],
        correlationID: String? = nil
    ) async throws -> Vector3D {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "SceneGraphCapsule.calculatePhongLighting",
            category: "lighting_calculation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "light_count": "\(lights.count)",
                "material_id": material.id
            ]
        )
        
        diagnostics.event(
            level: .info,
            category: "scenegraphcapsule.calculatePhongLighting",
            message: "Calculating Phong lighting for material: \(material.id)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let color = impl.calculatePhongLighting(
                point: point,
                normal: normal,
                viewDirection: viewDirection,
                material: material,
                lights: lights
            )
            
            diagnostics.event(
                level: .info,
                category: "scenegraphcapsule.calculatePhongLighting",
                message: "Phong lighting calculation completed",
                correlationID: corrID,
                metadata: [
                    "result_color": "(\(color.x),\(color.y),\(color.z))"
                ]
            )
            
            span.end(status: .ok)
            return color
        } catch let sceneError as SceneGraphError {
            diagnostics.event(
                level: .error,
                category: "scenegraphcapsule.calculatePhongLighting",
                message: "Phong lighting calculation failed: \(sceneError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "SceneGraphError"]
            )
            span.end(status: .error)
            
            switch sceneError {
            case .lightingFailed:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            default:
                throw CapsuleError.internalError(details: sceneError.localizedDescription)
            }
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get capsule health status
    /// - Returns: A dictionary with health metrics (sendable-safe)
    /// - Throws: Never (diagnostic-only method)
    public func healthStatus() -> [String: String] {
        return [
            "capsule_id": id,
            "status": "healthy",
            "tier": "1",
            "capabilities": "scene_graph,spatial_indexing,lighting,transformations",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
    }
}

// MARK: - Helper for Diagnostics Integration

/// Mock diagnostics implementation for testing
/// Can be replaced with actual daemon diagnostics when integrated
internal final class MockDiagnostics: CapsuleDiagnostics {
    public func beginSpan(
        name: String,
        category: String,
        correlationID: String? = nil,
        tags: [String: String] = [:]
    ) -> DiagnosticSpan {
        MockDiagnosticSpan()
    }
    
    public func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        // In tests, diagnostics are collected for assertions
    }
    
    public func getEvents(since: Date) -> [DiagnosticEvent] {
        []
    }
    
    public func getAllEvents() -> [DiagnosticEvent] {
        []
    }
    
    public func clearEvents() {
        // noop
    }
}

internal final class MockDiagnosticSpan: DiagnosticSpan {
    let spanID = UUID().uuidString
    let name = "mock"
    let category = "mock"
    let correlationID = UUID().uuidString
    let startTime = Date()
    
    var endTime: Date? { nil }
    var duration: TimeInterval? { nil }
    var status: SpanStatus? { nil }
    var tags: [String: String] { [:] }
    
    func end(status: SpanStatus) { }
    func addTag(key: String, value: String) { }
    func recordEvent(level: DiagnosticLevel, message: String) { }
}