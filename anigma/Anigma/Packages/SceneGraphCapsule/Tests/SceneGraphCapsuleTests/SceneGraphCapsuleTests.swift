/// SceneGraphCapsuleTests.swift
/// Comprehensive tests for SceneGraphCapsule
/// Tests all 3D scene graph operations, spatial indexing, and lighting

import XCTest
@testable import SceneGraphCapsule
import CapsuleCore
import TelemetryCore

final class SceneGraphCapsuleTests: XCTestCase {
    
    var capsule: SceneGraphCapsule!
    var mockDiagnostics: MockDiagnostics!
    
    override func setUp() async throws {
        try await super.setUp()
        mockDiagnostics = MockDiagnostics()
        capsule = try SceneGraphCapsule(id: "test-capsule", diagnostics: mockDiagnostics)
    }
    
    override func tearDown() async throws {
        capsule = nil
        mockDiagnostics = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic 3D Operations Tests
    
    func testCalculateDistance() async throws {
        let point1 = Point3D(x: 0, y: 0, z: 0)
        let point2 = Point3D(x: 3, y: 4, z: 0)
        
        let distance = try await capsule.calculateDistance(from: point1, to: point2)
        
        XCTAssertEqual(distance, 5.0, accuracy: 0.001)
    }
    
    func testTransformPoint() async throws {
        let point = Point3D(x: 1, y: 0, z: 0)
        let transform = Transform3D.translation(x: 2, y: 3, z: 4)
        
        let result = try await capsule.transformPoint(point, with: transform)
        
        XCTAssertEqual(result.x, 3.0, accuracy: 0.001)
        XCTAssertEqual(result.y, 3.0, accuracy: 0.001)
        XCTAssertEqual(result.z, 4.0, accuracy: 0.001)
    }
    
    func testTransformPointWithRotation() async throws {
        let point = Point3D(x: 1, y: 0, z: 0)
        let transform = Transform3D.rotation(angle: .pi / 2, axis: .up)
        
        let result = try await capsule.transformPoint(point, with: transform)
        
        XCTAssertEqual(result.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.z, -1.0, accuracy: 0.001)
    }
    
    func testTransformPointWithScale() async throws {
        let point = Point3D(x: 1, y: 2, z: 3)
        let transform = Transform3D.scale(x: 2, y: 3, z: 4)
        
        let result = try await capsule.transformPoint(point, with: transform)
        
        XCTAssertEqual(result.x, 2.0, accuracy: 0.001)
        XCTAssertEqual(result.y, 6.0, accuracy: 0.001)
        XCTAssertEqual(result.z, 12.0, accuracy: 0.001)
    }
    
    // MARK: - Scene Graph Operations Tests
    
    func testCreateSceneGraph() async throws {
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root Node"
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        XCTAssertEqual(sceneGraph.nodeCount, 1)
        XCTAssertEqual(sceneGraph.rootID, rootNode.id)
        XCTAssertNotNil(sceneGraph.node(withID: rootNode.id))
    }
    
    func testAddNodeToSceneGraph() async throws {
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root Node"
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        let childNode = SceneNode(
            id: NodeID("child"),
            type: .mesh,
            name: "Child Node",
            parentID: rootNode.id
        )
        
        let updatedSceneGraph = try await capsule.addNode(childNode, to: sceneGraph)
        
        XCTAssertEqual(updatedSceneGraph.nodeCount, 2)
        XCTAssertNotNil(updatedSceneGraph.node(withID: childNode.id))
        
        let updatedRoot = updatedSceneGraph.node(withID: rootNode.id)!
        XCTAssertTrue(updatedRoot.childIDs.contains(childNode.id))
    }
    
    func testRemoveNodeFromSceneGraph() async throws {
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root Node"
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        let childNode = SceneNode(
            id: NodeID("child"),
            type: .mesh,
            name: "Child Node",
            parentID: rootNode.id
        )
        
        let sceneGraphWithChild = try await capsule.addNode(childNode, to: sceneGraph)
        let updatedSceneGraph = try await capsule.removeNode(childNode.id, from: sceneGraphWithChild)
        
        XCTAssertEqual(updatedSceneGraph.nodeCount, 1)
        XCTAssertNil(updatedSceneGraph.node(withID: childNode.id))
        
        let updatedRoot = updatedSceneGraph.node(withID: rootNode.id)!
        XCTAssertFalse(updatedRoot.childIDs.contains(childNode.id))
    }
    
    func testGetWorldTransform() async throws {
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root Node",
            components: [.transform: Transform3D.translation(x: 1, y: 0, z: 0)]
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        let childNode = SceneNode(
            id: NodeID("child"),
            type: .mesh,
            name: "Child Node",
            parentID: rootNode.id,
            components: [.transform: Transform3D.translation(x: 2, y: 0, z: 0)]
        )
        
        let sceneGraphWithChild = try await capsule.addNode(childNode, to: sceneGraph)
        let worldTransform = try await capsule.getWorldTransform(for: childNode.id, in: sceneGraphWithChild)
        
        let testPoint = Point3D(x: 0, y: 0, z: 0)
        let transformedPoint = try await capsule.transformPoint(testPoint, with: worldTransform)
        
        XCTAssertEqual(transformedPoint.x, 3.0, accuracy: 0.001) // 1 + 2
        XCTAssertEqual(transformedPoint.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(transformedPoint.z, 0.0, accuracy: 0.001)
    }
    
    func testCalculateNodeBoundingBox() async throws {
        let mesh = TriangleMesh(
            vertices: [
                Point3D(x: -1, y: -1, z: -1),
                Point3D(x: 1, y: -1, z: -1),
                Point3D(x: 0, y: 1, z: -1)
            ],
            indices: [0, 1, 2]
        )
        
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .mesh,
            name: "Root Node",
            components: [.mesh: mesh]
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        let boundingBox = try await capsule.calculateNodeBoundingBox(rootNode.id, in: sceneGraph)
        
        XCTAssertEqual(boundingBox.min.x, -1.0, accuracy: 0.001)
        XCTAssertEqual(boundingBox.min.y, -1.0, accuracy: 0.001)
        XCTAssertEqual(boundingBox.min.z, -1.0, accuracy: 0.001)
        XCTAssertEqual(boundingBox.max.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(boundingBox.max.y, 1.0, accuracy: 0.001)
        XCTAssertEqual(boundingBox.max.z, -1.0, accuracy: 0.001)
    }
    
    // MARK: - Spatial Indexing Tests
    
    func testBuildOctree() async throws {
        let objects = [
            SceneObject(
                id: NodeID("object1"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: -1, y: -1, z: -1),
                    max: Point3D(x: 1, y: 1, z: 1)
                ),
                data: "test1"
            ),
            SceneObject(
                id: NodeID("object2"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: 2, y: 2, z: 2),
                    max: Point3D(x: 4, y: 4, z: 4)
                ),
                data: "test2"
            )
        ]
        
        let boundingBox = BoundingBox3D(
            min: Point3D(x: -2, y: -2, z: -2),
            max: Point3D(x: 5, y: 5, z: 5)
        )
        
        let octree = try await capsule.buildOctree(
            objects: objects,
            boundingBox: boundingBox,
            maxDepth: 4,
            maxObjectsPerNode: 2
        )
        
        XCTAssertNotNil(octree)
        XCTAssertEqual(octree.boundingBox.min.x, -2.0, accuracy: 0.001)
        XCTAssertEqual(octree.boundingBox.max.x, 5.0, accuracy: 0.001)
    }
    
    func testBuildKDTree() async throws {
        let objects = [
            SceneObject(
                id: NodeID("object1"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: -1, y: -1, z: -1),
                    max: Point3D(x: 1, y: 1, z: 1)
                ),
                data: "test1"
            ),
            SceneObject(
                id: NodeID("object2"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: 2, y: 2, z: 2),
                    max: Point3D(x: 4, y: 4, z: 4)
                ),
                data: "test2"
            )
        ]
        
        let kdTree = try await capsule.buildKDTree(objects: objects)
        
        XCTAssertNotNil(kdTree)
        XCTAssertEqual(kdTree?.axis, 0) // First axis (x)
    }
    
    func testBuildSpatialGrid() async throws {
        let objects = [
            SceneObject(
                id: NodeID("object1"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: 0.5, y: 0.5, z: 0.5),
                    max: Point3D(x: 1.5, y: 1.5, z: 1.5)
                ),
                data: "test1"
            )
        ]
        
        let cellSize = Vector3D(x: 1, y: 1, z: 1)
        let origin = Point3D(x: 0, y: 0, z: 0)
        
        let spatialGrid = try await capsule.buildSpatialGrid(
            objects: objects,
            cellSize: cellSize,
            origin: origin
        )
        
        XCTAssertNotNil(spatialGrid)
        XCTAssertEqual(spatialGrid.cellSize.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(spatialGrid.cellSize.y, 1.0, accuracy: 0.001)
        XCTAssertEqual(spatialGrid.cellSize.z, 1.0, accuracy: 0.001)
    }
    
    // MARK: - Ray Casting Tests
    
    func testRayBoxIntersection() async throws {
        let ray = Ray(
            origin: Point3D(x: -2, y: 0, z: 0),
            direction: Vector3D(x: 1, y: 0, z: 0)
        )
        
        let boundingBox = BoundingBox3D(
            min: Point3D(x: -1, y: -1, z: -1),
            max: Point3D(x: 1, y: 1, z: 1)
        )
        
        let intersection = try await capsule.rayBoxIntersection(ray, boundingBox: boundingBox)
        
        XCTAssertNotNil(intersection)
        XCTAssertEqual(intersection?.point.x, -1.0, accuracy: 0.001)
        XCTAssertEqual(intersection?.point.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(intersection?.point.z, 0.0, accuracy: 0.001)
        XCTAssertEqual(intersection?.distance, 1.0, accuracy: 0.001)
    }
    
    func testRayBoxIntersectionMiss() async throws {
        let ray = Ray(
            origin: Point3D(x: -2, y: 0, z: 0),
            direction: Vector3D(x: 0, y: 1, z: 0)
        )
        
        let boundingBox = BoundingBox3D(
            min: Point3D(x: 1, y: 1, z: 1),
            max: Point3D(x: 2, y: 2, z: 2)
        )
        
        let intersection = try await capsule.rayBoxIntersection(ray, boundingBox: boundingBox)
        
        XCTAssertNil(intersection)
    }
    
    // MARK: - Lighting Tests
    
    func testCalculatePhongLighting() async throws {
        let point = Point3D(x: 0, y: 0, z: 0)
        let normal = Vector3D.up
        let viewDirection = Vector3D(x: 0, y: 0, z: 1)
        
        let material = Material(
            id: "test-material",
            baseColor: Vector3D(x: 1, y: 1, z: 1),
            metallic: 0.0,
            roughness: 1.0
        )
        
        let ambientLight = Light(
            type: .ambient,
            color: Vector3D(x: 0.2, y: 0.2, z: 0.2),
            intensity: 1.0
        )
        
        let directionalLight = Light(
            type: .directional,
            color: Vector3D(x: 1, y: 1, z: 1),
            intensity: 1.0,
            direction: Vector3D(x: 0, y: -1, z: -1)
        )
        
        let color = try await capsule.calculatePhongLighting(
            point: point,
            normal: normal,
            viewDirection: viewDirection,
            material: material,
            lights: [ambientLight, directionalLight]
        )
        
        XCTAssertGreaterThan(color.x, 0.0)
        XCTAssertGreaterThan(color.y, 0.0)
        XCTAssertGreaterThan(color.z, 0.0)
    }
    
    func testCalculatePhongLightingWithPointLight() async throws {
        let point = Point3D(x: 0, y: 0, z: 0)
        let normal = Vector3D.up
        let viewDirection = Vector3D(x: 0, y: 0, z: 1)
        
        let material = Material(
            id: "test-material",
            baseColor: Vector3D(x: 1, y: 0, z: 0), // Red material
            metallic: 0.0,
            roughness: 1.0
        )
        
        let pointLight = Light(
            type: .point,
            color: Vector3D(x: 1, y: 1, z: 1),
            intensity: 1.0,
            position: Point3D(x: 0, y: 1, z: 1),
            range: 10.0
        )
        
        let color = try await capsule.calculatePhongLighting(
            point: point,
            normal: normal,
            viewDirection: viewDirection,
            material: material,
            lights: [pointLight]
        )
        
        // Should have red contribution from material
        XCTAssertGreaterThan(color.x, 0.0)
        XCTAssertEqual(color.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(color.z, 0.0, accuracy: 0.001)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidConfiguration() {
        XCTAssertThrowsError(try SceneGraphCapsule(id: "")) { error in
            XCTAssertTrue(error is CapsuleError)
            if case .invalidConfiguration(let reason) = error as! CapsuleError {
                XCTAssertEqual(reason, "Capsule ID cannot be empty")
            } else {
                XCTFail("Expected invalidConfiguration error")
            }
        }
    }
    
    func testGetWorldTransformForNonExistentNode() async throws {
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root Node"
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        await XCTAssertThrowsError(try capsule.getWorldTransform(for: NodeID("nonexistent"), in: sceneGraph)) { error in
            XCTAssertTrue(error is CapsuleError)
            if case .invalidInput(let field, _) = error as! CapsuleError {
                XCTAssertEqual(field, "nodeID")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }
    }
    
    func testCalculateBoundingBoxForNonExistentNode() async throws {
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root Node"
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        await XCTAssertThrowsError(try capsule.calculateNodeBoundingBox(NodeID("nonexistent"), in: sceneGraph)) { error in
            XCTAssertTrue(error is CapsuleError)
            if case .invalidInput(let field, _) = error as! CapsuleError {
                XCTAssertEqual(field, "nodeID")
            } else {
                XCTFail("Expected invalidInput error")
            }
        }
    }
    
    // MARK: - Health Status Tests
    
    func testHealthStatus() {
        let health = capsule.healthStatus()
        
        XCTAssertEqual(health["capsule_id"], capsule.id)
        XCTAssertEqual(health["status"], "healthy")
        XCTAssertEqual(health["tier"], "1")
        XCTAssertEqual(health["capabilities"], "scene_graph,spatial_indexing,lighting,transformations")
        XCTAssertNotNil(health["timestamp"])
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceCalculateDistance() async throws {
        let point1 = Point3D(x: 0, y: 0, z: 0)
        let point2 = Point3D(x: 100, y: 200, z: 300)
        
        measure {
            Task {
                _ = try? await capsule.calculateDistance(from: point1, to: point2)
            }
        }
    }
    
    func testPerformanceTransformPoint() async throws {
        let point = Point3D(x: 1, y: 2, z: 3)
        let transform = Transform3D.rotation(angle: .pi / 4, axis: Vector3D(x: 1, y: 1, z: 1).normalized)
        
        measure {
            Task {
                _ = try? await capsule.transformPoint(point, with: transform)
            }
        }
    }
    
    func testPerformanceSceneGraphOperations() async throws {
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root Node"
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        measure {
            Task {
                var currentGraph = sceneGraph
                for i in 0..<100 {
                    let childNode = SceneNode(
                        id: NodeID("child_\(i)"),
                        type: .mesh,
                        name: "Child \(i)",
                        parentID: rootNode.id
                    )
                    currentGraph = try? await capsule.addNode(childNode, to: currentGraph)
                }
            }
        }
    }
    
    func testPerformanceOctreeConstruction() async throws {
        var objects: [SceneObject] = []
        
        for i in 0..<1000 {
            let x = Double.random(in: -10...10)
            let y = Double.random(in: -10...10)
            let z = Double.random(in: -10...10)
            
            let object = SceneObject(
                id: NodeID("object_\(i)"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: x - 0.5, y: y - 0.5, z: z - 0.5),
                    max: Point3D(x: x + 0.5, y: y + 0.5, z: z + 0.5)
                ),
                data: "test_\(i)"
            )
            objects.append(object)
        }
        
        let boundingBox = BoundingBox3D(
            min: Point3D(x: -11, y: -11, z: -11),
            max: Point3D(x: 11, y: 11, z: 11)
        )
        
        measure {
            Task {
                _ = try? await capsule.buildOctree(
                    objects: objects,
                    boundingBox: boundingBox,
                    maxDepth: 6,
                    maxObjectsPerNode: 10
                )
            }
        }
    }
    
    func testPerformanceLightingCalculation() async throws {
        let point = Point3D(x: 0, y: 0, z: 0)
        let normal = Vector3D.up
        let viewDirection = Vector3D(x: 0, y: 0, z: 1)
        
        let material = Material(
            id: "test-material",
            baseColor: Vector3D(x: 1, y: 1, z: 1),
            metallic: 0.5,
            roughness: 0.5
        )
        
        var lights: [Light] = []
        
        for i in 0..<10 {
            let light = Light(
                type: .point,
                color: Vector3D(x: 1, y: 1, z: 1),
                intensity: 1.0,
                position: Point3D(
                    x: Double.random(in: -5...5),
                    y: Double.random(in: -5...5),
                    z: Double.random(in: -5...5)
                ),
                range: 10.0
            )
            lights.append(light)
        }
        
        measure {
            Task {
                _ = try? await capsule.calculatePhongLighting(
                    point: point,
                    normal: normal,
                    viewDirection: viewDirection,
                    material: material,
                    lights: lights
                )
            }
        }
    }
}