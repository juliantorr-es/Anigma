/// SceneGraphCapsuleGoldenTests.swift
/// Golden tests for SceneGraphCapsule
/// Verifies deterministic behavior with known inputs and outputs

import XCTest
@testable import SceneGraphCapsule
import CapsuleCore
import TelemetryCore

final class SceneGraphCapsuleGoldenTests: XCTestCase {
    
    var capsule: SceneGraphCapsule!
    
    override func setUp() async throws {
        try await super.setUp()
        capsule = try SceneGraphCapsule(id: "golden-test-capsule")
    }
    
    override func tearDown() async throws {
        capsule = nil
        try await super.tearDown()
    }
    
    // MARK: - Golden Test Data
    
    private struct GoldenTestData {
        static let point1 = Point3D(x: 0, y: 0, z: 0)
        static let point2 = Point3D(x: 3, y: 4, z: 0)
        static let expectedDistance = 5.0
        
        static let transformPoint = Point3D(x: 1, y: 2, z: 3)
        static let translationTransform = Transform3D.translation(x: 5, y: -3, z: 2)
        static let expectedTranslatedPoint = Point3D(x: 6, y: -1, z: 5)
        
        static let rotationPoint = Point3D(x: 1, y: 0, z: 0)
        static let rotationTransform = Transform3D.rotation(angle: .pi / 2, axis: .up)
        static let expectedRotatedPoint = Point3D(x: 0, y: 0, z: -1)
        
        static let scalePoint = Point3D(x: 2, y: 3, z: 4)
        static let scaleTransform = Transform3D.scale(x: 2, y: 0.5, z: -1)
        static let expectedScaledPoint = Point3D(x: 4, y: 1.5, z: -4)
        
        static let rayOrigin = Point3D(x: -2, y: 0, z: 0)
        static let rayDirection = Vector3D(x: 1, y: 0, z: 0)
        static let ray = Ray(origin: rayOrigin, direction: rayDirection)
        static let boundingBox = BoundingBox3D(
            min: Point3D(x: -1, y: -1, z: -1),
            max: Point3D(x: 1, y: 1, z: 1)
        )
        static let expectedIntersectionPoint = Point3D(x: -1, y: 0, z: 0)
        static let expectedIntersectionDistance = 1.0
        
        static let lightingPoint = Point3D(x: 0, y: 0, z: 0)
        static let lightingNormal = Vector3D.up
        static let lightingViewDirection = Vector3D(x: 0, y: 0, z: 1)
        static let lightingMaterial = Material(
            id: "golden-material",
            baseColor: Vector3D(x: 0.8, y: 0.6, z: 0.4),
            metallic: 0.2,
            roughness: 0.8
        )
        static let ambientLight = Light(
            type: .ambient,
            color: Vector3D(x: 0.2, y: 0.2, z: 0.2),
            intensity: 1.0
        )
        static let directionalLight = Light(
            type: .directional,
            color: Vector3D(x: 1, y: 1, z: 1),
            intensity: 0.8,
            direction: Vector3D(x: 0, y: -1, z: -1).normalized
        )
    }
    
    // MARK: - Distance Calculation Golden Tests
    
    func testGoldenDistanceCalculation() async throws {
        let distance = try await capsule.calculateDistance(
            from: GoldenTestData.point1,
            to: GoldenTestData.point2
        )
        
        XCTAssertEqual(distance, GoldenTestData.expectedDistance, accuracy: 0.0001)
    }
    
    func testGoldenDistanceCalculationReversed() async throws {
        // Distance should be the same regardless of order
        let distance = try await capsule.calculateDistance(
            from: GoldenTestData.point2,
            to: GoldenTestData.point1
        )
        
        XCTAssertEqual(distance, GoldenTestData.expectedDistance, accuracy: 0.0001)
    }
    
    // MARK: - Transform Golden Tests
    
    func testGoldenTranslationTransform() async throws {
        let result = try await capsule.transformPoint(
            GoldenTestData.transformPoint,
            with: GoldenTestData.translationTransform
        )
        
        XCTAssertEqual(result.x, GoldenTestData.expectedTranslatedPoint.x, accuracy: 0.0001)
        XCTAssertEqual(result.y, GoldenTestData.expectedTranslatedPoint.y, accuracy: 0.0001)
        XCTAssertEqual(result.z, GoldenTestData.expectedTranslatedPoint.z, accuracy: 0.0001)
    }
    
    func testGoldenRotationTransform() async throws {
        let result = try await capsule.transformPoint(
            GoldenTestData.rotationPoint,
            with: GoldenTestData.rotationTransform
        )
        
        XCTAssertEqual(result.x, GoldenTestData.expectedRotatedPoint.x, accuracy: 0.0001)
        XCTAssertEqual(result.y, GoldenTestData.expectedRotatedPoint.y, accuracy: 0.0001)
        XCTAssertEqual(result.z, GoldenTestData.expectedRotatedPoint.z, accuracy: 0.0001)
    }
    
    func testGoldenScaleTransform() async throws {
        let result = try await capsule.transformPoint(
            GoldenTestData.scalePoint,
            with: GoldenTestData.scaleTransform
        )
        
        XCTAssertEqual(result.x, GoldenTestData.expectedScaledPoint.x, accuracy: 0.0001)
        XCTAssertEqual(result.y, GoldenTestData.expectedScaledPoint.y, accuracy: 0.0001)
        XCTAssertEqual(result.z, GoldenTestData.expectedScaledPoint.z, accuracy: 0.0001)
    }
    
    // MARK: - Scene Graph Golden Tests
    
    func testGoldenSceneGraphCreation() async throws {
        let rootNode = SceneNode(
            id: NodeID("golden-root"),
            type: .group,
            name: "Golden Root Node"
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        XCTAssertEqual(sceneGraph.nodeCount, 1)
        XCTAssertEqual(sceneGraph.rootID.value, "golden-root")
        XCTAssertEqual(sceneGraph.node(withID: rootNode.id)?.name, "Golden Root Node")
    }
    
    func testGoldenSceneGraphHierarchy() async throws {
        let rootNode = SceneNode(
            id: NodeID("golden-root"),
            type: .group,
            name: "Golden Root Node"
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        let childNode1 = SceneNode(
            id: NodeID("golden-child-1"),
            type: .mesh,
            name: "Golden Child 1",
            parentID: rootNode.id
        )
        
        let childNode2 = SceneNode(
            id: NodeID("golden-child-2"),
            type: .light,
            name: "Golden Child 2",
            parentID: rootNode.id
        )
        
        let sceneGraphWithChild1 = try await capsule.addNode(childNode1, to: sceneGraph)
        let sceneGraphWithChildren = try await capsule.addNode(childNode2, to: sceneGraphWithChild1)
        
        XCTAssertEqual(sceneGraphWithChildren.nodeCount, 3)
        
        let updatedRoot = sceneGraphWithChildren.node(withID: rootNode.id)!
        XCTAssertEqual(updatedRoot.childIDs.count, 2)
        XCTAssertTrue(updatedRoot.childIDs.contains(childNode1.id))
        XCTAssertTrue(updatedRoot.childIDs.contains(childNode2.id))
        
        let retrievedChild1 = sceneGraphWithChildren.node(withID: childNode1.id)!
        XCTAssertEqual(retrievedChild1.parentID, rootNode.id)
        
        let retrievedChild2 = sceneGraphWithChildren.node(withID: childNode2.id)!
        XCTAssertEqual(retrievedChild2.parentID, rootNode.id)
    }
    
    func testGoldenWorldTransformCalculation() async throws {
        let rootNode = SceneNode(
            id: NodeID("golden-root"),
            type: .group,
            name: "Golden Root Node",
            components: [.transform: Transform3D.translation(x: 1, y: 2, z: 3)]
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        let childNode = SceneNode(
            id: NodeID("golden-child"),
            type: .mesh,
            name: "Golden Child Node",
            parentID: rootNode.id,
            components: [.transform: Transform3D.translation(x: 4, y: 5, z: 6)]
        )
        
        let sceneGraphWithChild = try await capsule.addNode(childNode, to: sceneGraph)
        let worldTransform = try await capsule.getWorldTransform(for: childNode.id, in: sceneGraphWithChild)
        
        let testPoint = Point3D(x: 0, y: 0, z: 0)
        let transformedPoint = try await capsule.transformPoint(testPoint, with: worldTransform)
        
        XCTAssertEqual(transformedPoint.x, 5.0, accuracy: 0.0001) // 1 + 4
        XCTAssertEqual(transformedPoint.y, 7.0, accuracy: 0.0001) // 2 + 5
        XCTAssertEqual(transformedPoint.z, 9.0, accuracy: 0.0001) // 3 + 6
    }
    
    // MARK: - Bounding Box Golden Tests
    
    func testGoldenBoundingBoxCalculation() async throws {
        let mesh = TriangleMesh(
            vertices: [
                Point3D(x: -2, y: -1, z: 0),
                Point3D(x: 3, y: 2, z: -1),
                Point3D(x: 1, y: -3, z: 2)
            ],
            indices: [0, 1, 2]
        )
        
        let rootNode = SceneNode(
            id: NodeID("golden-mesh-node"),
            type: .mesh,
            name: "Golden Mesh Node",
            components: [.mesh: mesh]
        )
        
        let sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        let boundingBox = try await capsule.calculateNodeBoundingBox(rootNode.id, in: sceneGraph)
        
        XCTAssertEqual(boundingBox.min.x, -2.0, accuracy: 0.0001)
        XCTAssertEqual(boundingBox.min.y, -3.0, accuracy: 0.0001)
        XCTAssertEqual(boundingBox.min.z, -1.0, accuracy: 0.0001)
        XCTAssertEqual(boundingBox.max.x, 3.0, accuracy: 0.0001)
        XCTAssertEqual(boundingBox.max.y, 2.0, accuracy: 0.0001)
        XCTAssertEqual(boundingBox.max.z, 2.0, accuracy: 0.0001)
    }
    
    // MARK: - Ray Casting Golden Tests
    
    func testGoldenRayBoxIntersection() async throws {
        let intersection = try await capsule.rayBoxIntersection(
            GoldenTestData.ray,
            boundingBox: GoldenTestData.boundingBox
        )
        
        XCTAssertNotNil(intersection)
        XCTAssertEqual(intersection?.point.x, GoldenTestData.expectedIntersectionPoint.x, accuracy: 0.0001)
        XCTAssertEqual(intersection?.point.y, GoldenTestData.expectedIntersectionPoint.y, accuracy: 0.0001)
        XCTAssertEqual(intersection?.point.z, GoldenTestData.expectedIntersectionPoint.z, accuracy: 0.0001)
        XCTAssertEqual(intersection?.distance, GoldenTestData.expectedIntersectionDistance, accuracy: 0.0001)
    }
    
    func testGoldenRayBoxIntersectionMiss() async throws {
        let missRay = Ray(
            origin: Point3D(x: -2, y: 0, z: 0),
            direction: Vector3D(x: 0, y: 1, z: 0)
        )
        
        let intersection = try await capsule.rayBoxIntersection(
            missRay,
            boundingBox: GoldenTestData.boundingBox
        )
        
        XCTAssertNil(intersection)
    }
    
    // MARK: - Lighting Golden Tests
    
    func testGoldenAmbientLighting() async throws {
        let color = try await capsule.calculatePhongLighting(
            point: GoldenTestData.lightingPoint,
            normal: GoldenTestData.lightingNormal,
            viewDirection: GoldenTestData.lightingViewDirection,
            material: GoldenTestData.lightingMaterial,
            lights: [GoldenTestData.ambientLight]
        )
        
        // Ambient lighting should contribute base color * ambient color * ambient intensity
        let expectedAmbient = Vector3D(
            x: 0.8 * 0.2 * 0.2,
            y: 0.6 * 0.2 * 0.2,
            z: 0.4 * 0.2 * 0.2
        )
        
        XCTAssertEqual(color.x, expectedAmbient.x, accuracy: 0.01)
        XCTAssertEqual(color.y, expectedAmbient.y, accuracy: 0.01)
        XCTAssertEqual(color.z, expectedAmbient.z, accuracy: 0.01)
    }
    
    func testGoldenDirectionalLighting() async throws {
        let color = try await capsule.calculatePhongLighting(
            point: GoldenTestData.lightingPoint,
            normal: GoldenTestData.lightingNormal,
            viewDirection: GoldenTestData.lightingViewDirection,
            material: GoldenTestData.lightingMaterial,
            lights: [GoldenTestData.directionalLight]
        )
        
        // Should have both diffuse and specular contributions
        XCTAssertGreaterThan(color.x, 0.0)
        XCTAssertGreaterThan(color.y, 0.0)
        XCTAssertGreaterThan(color.z, 0.0)
        
        // Color should be influenced by material base color
        XCTAssertGreaterThan(color.x, color.y) // Red component should be higher
        XCTAssertGreaterThan(color.y, color.z) // Green component should be higher than blue
    }
    
    func testGoldenMultipleLights() async throws {
        let pointLight = Light(
            type: .point,
            color: Vector3D(x: 0, y: 1, z: 0), // Green light
            intensity: 0.5,
            position: Point3D(x: 0, y: 1, z: 1),
            range: 10.0
        )
        
        let color = try await capsule.calculatePhongLighting(
            point: GoldenTestData.lightingPoint,
            normal: GoldenTestData.lightingNormal,
            viewDirection: GoldenTestData.lightingViewDirection,
            material: GoldenTestData.lightingMaterial,
            lights: [GoldenTestData.ambientLight, GoldenTestData.directionalLight, pointLight]
        )
        
        // Should have contributions from all three lights
        XCTAssertGreaterThan(color.x, 0.0)
        XCTAssertGreaterThan(color.y, 0.0)
        XCTAssertGreaterThan(color.z, 0.0)
        
        // Green light should boost the green component
        let ambientOnly = try await capsule.calculatePhongLighting(
            point: GoldenTestData.lightingPoint,
            normal: GoldenTestData.lightingNormal,
            viewDirection: GoldenTestData.lightingViewDirection,
            material: GoldenTestData.lightingMaterial,
            lights: [GoldenTestData.ambientLight]
        )
        
        XCTAssertGreaterThan(color.y, ambientOnly.y)
    }
    
    // MARK: - Spatial Indexing Golden Tests
    
    func testGoldenOctreeConstruction() async throws {
        let objects = [
            SceneObject(
                id: NodeID("golden-obj-1"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: -1, y: -1, z: -1),
                    max: Point3D(x: 0, y: 0, z: 0)
                ),
                data: "test1"
            ),
            SceneObject(
                id: NodeID("golden-obj-2"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: 1, y: 1, z: 1),
                    max: Point3D(x: 2, y: 2, z: 2)
                ),
                data: "test2"
            )
        ]
        
        let boundingBox = BoundingBox3D(
            min: Point3D(x: -2, y: -2, z: -2),
            max: Point3D(x: 3, y: 3, z: 3)
        )
        
        let octree = try await capsule.buildOctree(
            objects: objects,
            boundingBox: boundingBox,
            maxDepth: 3,
            maxObjectsPerNode: 1
        )
        
        XCTAssertNotNil(octree)
        XCTAssertEqual(octree.boundingBox.min.x, -2.0, accuracy: 0.0001)
        XCTAssertEqual(octree.boundingBox.max.x, 3.0, accuracy: 0.0001)
    }
    
    func testGoldenKDTreeConstruction() async throws {
        let objects = [
            SceneObject(
                id: NodeID("golden-obj-1"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: 0, y: 0, z: 0),
                    max: Point3D(x: 1, y: 1, z: 1)
                ),
                data: "test1"
            ),
            SceneObject(
                id: NodeID("golden-obj-2"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: 2, y: 2, z: 2),
                    max: Point3D(x: 3, y: 3, z: 3)
                ),
                data: "test2"
            ),
            SceneObject(
                id: NodeID("golden-obj-3"),
                boundingBox: BoundingBox3D(
                    min: Point3D(x: 1, y: 1, z: 1),
                    max: Point3D(x: 2, y: 2, z: 2)
                ),
                data: "test3"
            )
        ]
        
        let kdTree = try await capsule.buildKDTree(objects: objects)
        
        XCTAssertNotNil(kdTree)
        XCTAssertEqual(kdTree?.axis, 0) // Should split on x-axis first
        XCTAssertEqual(kdTree?.point.x, 1.0, accuracy: 0.0001) // Median point
    }
    
    // MARK: - Deterministic Behavior Tests
    
    func testDeterministicDistanceCalculation() async throws {
        // Run the same calculation multiple times and verify identical results
        var results: [Double] = []
        
        for _ in 0..<10 {
            let distance = try await capsule.calculateDistance(
                from: GoldenTestData.point1,
                to: GoldenTestData.point2
            )
            results.append(distance)
        }
        
        // All results should be identical
        let firstResult = results.first!
        for result in results {
            XCTAssertEqual(result, firstResult, accuracy: 0.0001)
        }
    }
    
    func testDeterministicTransformCalculation() async throws {
        // Run the same transform multiple times and verify identical results
        var results: [Point3D] = []
        
        for _ in 0..<10 {
            let result = try await capsule.transformPoint(
                GoldenTestData.transformPoint,
                with: GoldenTestData.translationTransform
            )
            results.append(result)
        }
        
        // All results should be identical
        let firstResult = results.first!
        for result in results {
            XCTAssertEqual(result.x, firstResult.x, accuracy: 0.0001)
            XCTAssertEqual(result.y, firstResult.y, accuracy: 0.0001)
            XCTAssertEqual(result.z, firstResult.z, accuracy: 0.0001)
        }
    }
    
    func testDeterministicLightingCalculation() async throws {
        // Run the same lighting calculation multiple times and verify identical results
        var results: [Vector3D] = []
        
        for _ in 0..<10 {
            let color = try await capsule.calculatePhongLighting(
                point: GoldenTestData.lightingPoint,
                normal: GoldenTestData.lightingNormal,
                viewDirection: GoldenTestData.lightingViewDirection,
                material: GoldenTestData.lightingMaterial,
                lights: [GoldenTestData.ambientLight, GoldenTestData.directionalLight]
            )
            results.append(color)
        }
        
        // All results should be identical
        let firstResult = results.first!
        for result in results {
            XCTAssertEqual(result.x, firstResult.x, accuracy: 0.0001)
            XCTAssertEqual(result.y, firstResult.y, accuracy: 0.0001)
            XCTAssertEqual(result.z, firstResult.z, accuracy: 0.0001)
        }
    }
    
    // MARK: - Edge Case Golden Tests
    
    func testGoldenZeroDistance() async throws {
        let point = Point3D(x: 1, y: 2, z: 3)
        let distance = try await capsule.calculateDistance(from: point, to: point)
        
        XCTAssertEqual(distance, 0.0, accuracy: 0.0001)
    }
    
    func testGoldenIdentityTransform() async throws {
        let point = Point3D(x: 1, y: 2, z: 3)
        let result = try await capsule.transformPoint(point, with: Transform3D.identity)
        
        XCTAssertEqual(result.x, point.x, accuracy: 0.0001)
        XCTAssertEqual(result.y, point.y, accuracy: 0.0001)
        XCTAssertEqual(result.z, point.z, accuracy: 0.0001)
    }
    
    func testGoldenZeroScaleTransform() async throws {
        let point = Point3D(x: 1, y: 2, z: 3)
        let transform = Transform3D.scale(x: 0, y: 0, z: 0)
        let result = try await capsule.transformPoint(point, with: transform)
        
        XCTAssertEqual(result.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(result.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(result.z, 0.0, accuracy: 0.0001)
    }
}