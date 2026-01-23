import XCTest
@testable import VectorOpsKit
import Foundation

final class VectorCapsuleBenchmarks: XCTestCase {
    
    var vectorOps: VectorOps!
    
    override func setUp() {
        super.setUp()
        vectorOps = VectorCapsuleWrapper()
    }
    
    override func tearDown() {
        vectorOps = nil
        super.tearDown()
    }
    
    // MARK: - Performance Benchmarks
    
    func testBooleanOperationsPerformance() {
        let complexPath1 = createComplexPolygonPath(sides: 8, radius: 100)
        let complexPath2 = createComplexPolygonPath(sides: 6, radius: 80)
        
        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric(),
            XCTStorageMetric()
        ]) {
            do {
                _ = try vectorOps.union(pathA: complexPath1, pathB: complexPath2)
            } catch {
                XCTFail("Union operation failed: \(error)")
            }
        }
    }
    
    func testPathSimplificationPerformance() {
        let veryComplexPath = createVeryComplexPath()
        
        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]) {
            do {
                _ = try vectorOps.douglasPeuckerSimplify(path: veryComplexPath, tolerance: 0.5)
            } catch {
                XCTFail("Simplification failed: \(error)")
            }
        }
    }
    
    func testTransformationPerformance() {
        let complexPath = createComplexPolygonPath(sides: 12, radius: 50)
        let matrix = TransformationMatrix(a: 1.2, b: 0.1, c: -0.1, d: 1.1, e: 10, f: 5)
        
        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]) {
            do {
                _ = try vectorOps.transform(path: complexPath, matrix: matrix)
            } catch {
                XCTFail("Transformation failed: \(error)")
            }
        }
    }
    
    func testGeometricPredicatesPerformance() {
        let complexPolygon = createComplexPolygonPath(sides: 100, radius: 1000)
        let testPoints = createTestPointGrid(size: 50, range: 2000)
        
        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]) {
            do {
                for point in testPoints {
                    _ = try vectorOps.pointInPolygon(point: point, path: complexPolygon)
                }
            } catch {
                XCTFail("Point-in-polygon test failed: \(error)")
            }
        }
    }
    
    func testBezierCreationPerformance() {
        let start = Point(x: 0, y: 0)
        let control1 = Point(x: 50, y: 100)
        let control2 = Point(x: 150, y: 100)
        let end = Point(x: 200, y: 0)
        
        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]) {
            do {
                _ = try vectorOps.createBezierCurve(start: start, control1: control1, control2: control2, end: end)
            } catch {
                XCTFail("Bezier creation failed: \(error)")
            }
        }
    }
    
    func testConcurrentOperationsPerformance() {
        let path1 = createComplexPolygonPath(sides: 8, radius: 100)
        let path2 = createComplexPolygonPath(sides: 6, radius: 80)
        let concurrentQueue = DispatchQueue(label: "bench.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric(),
            XCTStorageMetric()
        ]) {
            for i in 0..<10 {
                group.enter()
                concurrentQueue.async {
                    do {
                        _ = try self.vectorOps.union(pathA: path1, pathB: path2)
                        group.leave()
                    } catch {
                        XCTFail("Concurrent operation \(i) failed: \(error)")
                        group.leave()
                    }
                }
            }
            group.wait()
        }
    }
    
    func testMemoryUsageScaling() {
        let paths = [
            createComplexPolygonPath(sides: 4, radius: 10),   // Simple
            createComplexPolygonPath(sides: 8, radius: 50),   // Medium
            createComplexPolygonPath(sides: 16, radius: 100), // Complex
            createComplexPolygonPath(sides: 32, radius: 200)  // Very Complex
        ]
        
        for (index, path) in paths.enumerated() {
            measure(metrics: [
                XCTMemoryMetric(),
                XCTStorageMetric()
            ]) {
                do {
                    _ = try vectorOps.getBounds(path: path)
                } catch {
                    XCTFail("Bounds calculation failed for path \(index): \(error)")
                }
            }
        }
    }
    
    // MARK: - Scalability Tests
    
    func testPathComplexityScaling() {
        let complexities = [10, 50, 100, 500, 1000]
        
        for complexity in complexities {
            let path = createPathWithPoints(count: complexity)
            
            measure(metrics: [XCTClockMetric()]) {
                do {
                    _ = try vectorOps.pathLength(path: path)
                } catch {
                    XCTFail("Path length calculation failed for complexity \(complexity): \(error)")
                }
            }
        }
    }
    
    func testOperationChainingPerformance() {
        let originalPath = createComplexPolygonPath(sides: 6, radius: 100)
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            do {
                var currentPath = originalPath
                
                // Chain multiple operations
                currentPath = try vectorOps.translate(path: currentPath, dx: 10, dy: 10)
                currentPath = try vectorOps.rotate(path: currentPath, angle: .pi / 6, centerX: 0, centerY: 0)
                currentPath = try vectorOps.scale(path: currentPath, sx: 1.2, sy: 1.2)
                currentPath = try vectorOps.douglasPeuckerSimplify(path: currentPath, tolerance: 0.1)
                currentPath = try vectorOps.smoothPath(path: currentPath, factor: 0.5)
                
                _ = try vectorOps.getBounds(path: currentPath)
            } catch {
                XCTFail("Operation chaining failed: \(error)")
            }
        }
    }
    
    // MARK: - Stress Tests
    
    func testHighVolumeBooleanOperations() {
        let paths = (0..<100).map { i in
            createComplexPolygonPath(sides: 6, radius: 10 + Double(i))
        }
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            do {
                for i in 0..<99 {
                    _ = try vectorOps.union(pathA: paths[i], pathB: paths[i + 1])
                }
            } catch {
                XCTFail("High volume operations failed: \(error)")
            }
        }
    }
    
    func testExtremeTransformationStress() {
        let path = createComplexPolygonPath(sides: 8, radius: 100)
        let extremeTransformations: [(String, TransformationMatrix)] = [
            ("extreme_scale", TransformationMatrix(a: 1000, b: 0, c: 0, d: 1000, e: 0, f: 0)),
            ("extreme_skew", TransformationMatrix(a: 1, b: 10, c: 10, d: 1, e: 0, f: 0)),
            ("extreme_rotation", TransformationMatrix.rotation(angle: 100 * .pi, centerX: 0, centerY: 0)),
            ("tiny_scale", TransformationMatrix(a: 0.001, b: 0, c: 0, d: 0.001, e: 0, f: 0))
        ]
        
        for (name, matrix) in extremeTransformations {
            measure(metrics: [XCTClockMetric()]) {
                do {
                    _ = try vectorOps.transform(path: path, matrix: matrix)
                } catch {
                    // Some extreme transformations might fail, which is acceptable
                    print("Expected failure for \(name): \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createComplexPolygonPath(sides: Int, radius: Double) -> String {
        var path = "M"
        for i in 0...sides {
            let angle = 2.0 * Double.pi * Double(i) / Double(sides)
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            path += "\(x),\(y)"
            if i < sides {
                path += " L"
            }
        }
        path += " Z"
        return path
    }
    
    private func createVeryComplexPath() -> String {
        var path = "M"
        for i in 0..<1000 {
            let x = Double(i)
            let y = sin(Double(i) * 0.1) * 100 + cos(Double(i) * 0.05) * 50
            path += "\(x),\(y)"
            if i < 999 {
                path += " L"
            }
        }
        return path
    }
    
    private func createTestPointGrid(size: Int, range: Double) -> [Point] {
        var points: [Point] = []
        let step = range / Double(size)
        
        for i in 0..<size {
            for j in 0..<size {
                let x = -range/2 + Double(i) * step
                let y = -range/2 + Double(j) * step
                points.append(Point(x: x, y: y))
            }
        }
        return points
    }
    
    private func createPathWithPoints(count: Int) -> String {
        var path = "M"
        for i in 0..<count {
            let x = Double(i) * 10.0
            let y = sin(Double(i) * 0.1) * 50.0
            path += "\(x),\(y)"
            if i < count - 1 {
                path += " L"
            }
        }
        return path
    }
}

// MARK: - Performance Analysis Extensions

extension VectorCapsuleBenchmarks {
    
    func analyzePerformanceResults() {
        print("\n=== Vector Capsule Performance Analysis ===")
        print("Note: Run these benchmarks on target hardware for accurate results")
        print("Metrics to monitor:")
        print("- Clock time: Linear scaling expected for most operations")
        print("- Memory usage: Should be O(n) where n is path complexity")
        print("- Storage impact: Should be minimal for in-memory operations")
        print("- Concurrency: Should show near-linear speedup with multiple cores")
    }
    
    func validateDeterminism() {
        print("\n=== Determinism Validation ===")
        let path = createComplexPolygonPath(sides: 8, radius: 100)
        
        do {
            let results = try (0..<10).map { _ in
                try vectorOps.union(pathA: path, pathB: path)
            }
            
            let firstResult = results.first!
            let allIdentical = results.allSatisfy { $0 == firstResult }
            
            if allIdentical {
                print("✅ All operations returned identical results - DETERMINISTIC")
            } else {
                print("❌ Results vary - NON-DETERMINISTIC (this is a bug)")
            }
        } catch {
            print("❌ Determinism test failed: \(error)")
        }
    }
}