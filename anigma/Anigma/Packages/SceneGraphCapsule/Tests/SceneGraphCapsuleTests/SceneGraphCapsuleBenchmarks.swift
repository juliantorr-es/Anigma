/// SceneGraphCapsuleBenchmarks.swift
/// Performance benchmarks for SceneGraphCapsule
/// Tests performance of all major operations with various data sizes

import XCTest
@testable import SceneGraphCapsule
import CapsuleCore
import TelemetryCore

final class SceneGraphCapsuleBenchmarks: XCTestCase {
    
    var capsule: SceneGraphCapsule!
    
    override func setUp() async throws {
        try await super.setUp()
        capsule = try SceneGraphCapsule(id: "benchmark-capsule")
    }
    
    override func tearDown() async throws {
        capsule = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Operations Benchmarks
    
    func benchmarkCalculateDistance(iterations: Int) async throws {
        let point1 = Point3D(x: 0, y: 0, z: 0)
        let point2 = Point3D(x: 100, y: 200, z: 300)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = try await capsule.calculateDistance(from: point1, to: point2)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("Calculate Distance (\(iterations) iterations): \(duration * 1000)ms total, \((duration / Double(iterations)) * 1000)ms avg")
    }
    
    func benchmarkTransformPoint(iterations: Int) async throws {
        let point = Point3D(x: 1, y: 2, z: 3)
        let transform = Transform3D.rotation(angle: .pi / 4, axis: Vector3D(x: 1, y: 1, z: 1).normalized)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = try await capsule.transformPoint(point, with: transform)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("Transform Point (\(iterations) iterations): \(duration * 1000)ms total, \((duration / Double(iterations)) * 1000)ms avg")
    }
    
    // MARK: - Scene Graph Benchmarks
    
    func benchmarkSceneGraphCreation(nodeCount: Int) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var sceneGraph: SceneGraph?
        for i in 0..<nodeCount {
            let rootNode = SceneNode(
                id: NodeID("root_\(i)"),
                type: .group,
                name: "Root Node \(i)"
            )
            sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("Scene Graph Creation (\(nodeCount) nodes): \(duration * 1000)ms total, \((duration / Double(nodeCount)) * 1000)ms avg")
    }
    
    func benchmarkSceneGraphHierarchy(depth: Int, childrenPerNode: Int) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        func addChildren(parentID: NodeID, currentDepth: Int) async throws {
            guard currentDepth < depth else { return }
            
            for i in 0..<childrenPerNode {
                let childNode = SceneNode(
                    id: NodeID("node_\(currentDepth)_\(i)"),
                    type: .mesh,
                    name: "Node \(currentDepth)-\(i)",
                    parentID: parentID
                )
                sceneGraph = try await capsule.addNode(childNode, to: sceneGraph)
                try await addChildren(parentID: childNode.id, currentDepth: currentDepth + 1)
            }
        }
        
        try await addChildren(parentID: rootNode.id, currentDepth: 0)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        let totalNodes = Int(pow(Double(childrenPerNode), Double(depth + 1)) - 1) / (childrenPerNode - 1)
        print("Scene Graph Hierarchy (depth: \(depth), children: \(childrenPerNode), total nodes: \(totalNodes)): \(duration * 1000)ms")
    }
    
    func benchmarkWorldTransformCalculation(nodeCount: Int) async throws {
        // Create a deep hierarchy
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root",
            components: [.transform: Transform3D.translation(x: 1, y: 0, z: 0)]
        )
        
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        var lastNodeID = rootNode.id
        
        for i in 0..<nodeCount {
            let childNode = SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: lastNodeID,
                components: [.transform: Transform3D.translation(x: 1, y: 0, z: 0)]
            )
            sceneGraph = try await capsule.addNode(childNode, to: sceneGraph)
            lastNodeID = childNode.id
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        _ = try await capsule.getWorldTransform(for: lastNodeID, in: sceneGraph)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("World Transform Calculation (depth: \(nodeCount)): \(duration * 1000)ms")
    }
    
    func benchmarkBoundingBoxCalculation(nodeCount: Int) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        // Add nodes with meshes
        for i in 0..<nodeCount {
            let mesh = TriangleMesh(
                vertices: [
                    Point3D(x: Double(i), y: Double(i), z: Double(i)),
                    Point3D(x: Double(i) + 1, y: Double(i), z: Double(i)),
                    Point3D(x: Double(i), y: Double(i) + 1, z: Double(i))
                ],
                indices: [0, 1, 2]
            )
            
            let childNode = SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: rootNode.id,
                components: [.mesh: mesh]
            )
            sceneGraph = try await capsule.addNode(childNode, to: sceneGraph)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let creationDuration = endTime - startTime
        
        let calculationStartTime = CFAbsoluteTimeGetCurrent()
        
        _ = try await capsule.calculateNodeBoundingBox(rootNode.id, in: sceneGraph)
        
        let calculationEndTime = CFAbsoluteTimeGetCurrent()
        let calculationDuration = calculationEndTime - calculationStartTime
        
        print("Bounding Box Calculation (\(nodeCount) nodes): Creation: \(creationDuration * 1000)ms, Calculation: \(calculationDuration * 1000)ms")
    }
    
    // MARK: - Spatial Indexing Benchmarks
    
    func benchmarkOctreeConstruction(objectCount: Int) async throws {
        var objects: [SceneObject] = []
        
        for i in 0..<objectCount {
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
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        _ = try await capsule.buildOctree(
            objects: objects,
            boundingBox: boundingBox,
            maxDepth: 8,
            maxObjectsPerNode: 10
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("Octree Construction (\(objectCount) objects): \(duration * 1000)ms")
    }
    
    func benchmarkKDTreeConstruction(objectCount: Int) async throws {
        var objects: [SceneObject] = []
        
        for i in 0..<objectCount {
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
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        _ = try await capsule.buildKDTree(objects: objects)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("KD-Tree Construction (\(objectCount) objects): \(duration * 1000)ms")
    }
    
    func benchmarkSpatialGridConstruction(objectCount: Int) async throws {
        var objects: [SceneObject] = []
        
        for i in 0..<objectCount {
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
        
        let cellSize = Vector3D(x: 2, y: 2, z: 2)
        let origin = Point3D(x: -10, y: -10, z: -10)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        _ = try await capsule.buildSpatialGrid(
            objects: objects,
            cellSize: cellSize,
            origin: origin
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("Spatial Grid Construction (\(objectCount) objects): \(duration * 1000)ms")
    }
    
    // MARK: - Ray Casting Benchmarks
    
    func benchmarkRayBoxIntersection(iterations: Int) async throws {
        let ray = Ray(
            origin: Point3D(x: -5, y: 0, z: 0),
            direction: Vector3D(x: 1, y: 0, z: 0)
        )
        
        let boundingBox = BoundingBox3D(
            min: Point3D(x: -1, y: -1, z: -1),
            max: Point3D(x: 1, y: 1, z: 1)
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = try await capsule.rayBoxIntersection(ray, boundingBox: boundingBox)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("Ray-Box Intersection (\(iterations) iterations): \(duration * 1000)ms total, \((duration / Double(iterations)) * 1000)ms avg")
    }
    
    // MARK: - Lighting Benchmarks
    
    func benchmarkPhongLighting(iterations: Int, lightCount: Int) async throws {
        let point = Point3D(x: 0, y: 0, z: 0)
        let normal = Vector3D.up
        let viewDirection = Vector3D(x: 0, y: 0, z: 1)
        
        let material = Material(
            id: "benchmark-material",
            baseColor: Vector3D(x: 0.8, y: 0.6, z: 0.4),
            metallic: 0.3,
            roughness: 0.7
        )
        
        var lights: [Light] = []
        
        for i in 0..<lightCount {
            let lightType = LightType.allCases[i % LightType.allCases.count]
            let light = Light(
                type: lightType,
                color: Vector3D(
                    x: Double.random(in: 0.5...1),
                    y: Double.random(in: 0.5...1),
                    z: Double.random(in: 0.5...1)
                ),
                intensity: Double.random(in: 0.5...1),
                position: lightType == .point ? Point3D(
                    x: Double.random(in: -5...5),
                    y: Double.random(in: -5...5),
                    z: Double.random(in: -5...5)
                ) : nil,
                direction: lightType == .directional ? Vector3D(
                    x: Double.random(in: -1...1),
                    y: Double.random(in: -1...1),
                    z: Double.random(in: -1...1)
                ).normalized : nil,
                range: lightType == .point ? Double.random(in: 5...15) : nil
            )
            lights.append(light)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = try await capsule.calculatePhongLighting(
                point: point,
                normal: normal,
                viewDirection: viewDirection,
                material: material,
                lights: lights
            )
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        print("Phong Lighting (\(iterations) iterations, \(lightCount) lights): \(duration * 1000)ms total, \((duration / Double(iterations)) * 1000)ms avg")
    }
    
    // MARK: - Comprehensive Benchmark Suite
    
    func testComprehensiveBenchmarkSuite() async throws {
        print("\n=== SceneGraphCapsule Performance Benchmarks ===\n")
        
        // Basic Operations
        try await benchmarkCalculateDistance(iterations: 10000)
        try await benchmarkTransformPoint(iterations: 10000)
        
        // Scene Graph Operations
        try await benchmarkSceneGraphCreation(nodeCount: 1000)
        try await benchmarkSceneGraphHierarchy(depth: 5, childrenPerNode: 3)
        try await benchmarkWorldTransformCalculation(nodeCount: 100)
        try await benchmarkBoundingBoxCalculation(nodeCount: 100)
        
        // Spatial Indexing
        try await benchmarkOctreeConstruction(objectCount: 1000)
        try await benchmarkKDTreeConstruction(objectCount: 1000)
        try await benchmarkSpatialGridConstruction(objectCount: 1000)
        
        // Ray Casting
        try await benchmarkRayBoxIntersection(iterations: 10000)
        
        // Lighting
        try await benchmarkPhongLighting(iterations: 1000, lightCount: 1)
        try await benchmarkPhongLighting(iterations: 1000, lightCount: 4)
        try await benchmarkPhongLighting(iterations: 1000, lightCount: 8)
        
        print("\n=== Benchmark Suite Complete ===\n")
    }
    
    // MARK: - Scalability Tests
    
    func testScalabilityBenchmark() async throws {
        print("\n=== Scalability Tests ===\n")
        
        let objectCounts = [100, 500, 1000, 5000, 10000]
        
        for objectCount in objectCounts {
            print("Testing with \(objectCount) objects:")
            try await benchmarkOctreeConstruction(objectCount: objectCount)
            try await benchmarkKDTreeConstruction(objectCount: objectCount)
            try await benchmarkSpatialGridConstruction(objectCount: objectCount)
            print("")
        }
        
        print("=== Scalability Tests Complete ===\n")
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageBenchmark() async throws {
        print("\n=== Memory Usage Tests ===\n")
        
        let startMemory = mach_task_basic_info()
        
        // Test large scene graph
        let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        for i in 0..<10000 {
            let mesh = TriangleMesh(
                vertices: [
                    Point3D(x: Double(i), y: 0, z: 0),
                    Point3D(x: Double(i) + 1, y: 0, z: 0),
                    Point3D(x: Double(i), y: 1, z: 0)
                ],
                indices: [0, 1, 2]
            )
            
            let childNode = SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: rootNode.id,
                components: [.mesh: mesh]
            )
            sceneGraph = try await capsule.addNode(childNode, to: sceneGraph)
        }
        
        let endMemory = mach_task_basic_info()
        let memoryUsed = Double(endMemory.resident_size - startMemory.resident_size) / 1024 / 1024
        
        print("Memory used for 10,000 nodes: \(memoryUsed) MB")
        print("Average memory per node: \((memoryUsed * 1024) / 10000) KB")
        
        print("\n=== Memory Usage Tests Complete ===\n")
    }
    
    private func mach_task_basic_info() -> mach_task_basic_info_data_t {
        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info : mach_task_basic_info_data_t()
    }
}