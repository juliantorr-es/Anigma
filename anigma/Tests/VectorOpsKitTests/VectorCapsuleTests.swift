import XCTest
@testable import VectorOpsKit
import Foundation

final class VectorCapsuleTests: XCTestCase {
    
    var vectorOps: VectorOps!
    
    override func setUp() {
        super.setUp()
        vectorOps = VectorCapsuleWrapper()
    }
    
    override func tearDown() {
        vectorOps = nil
        super.tearDown()
    }
    
    // MARK: - Boolean Operations Tests
    
    func testBooleanOperations() throws {
        let square = "M0,0 L100,0 L100,100 L0,100 Z"
        let circle = "M50,0 A50,50 0 0,1 50,100 A50,50 0 0,1 50,0"
        
        let unionResult = try vectorOps.union(pathA: square, pathB: circle)
        XCTAssertFalse(unionResult.isEmpty)
        
        let intersectionResult = try vectorOps.intersection(pathA: square, pathB: circle)
        XCTAssertFalse(intersectionResult.isEmpty)
        
        let differenceResult = try vectorOps.difference(pathA: square, pathB: circle)
        XCTAssertFalse(differenceResult.isEmpty)
        
        let xorResult = try vectorOps.xor(pathA: square, pathB: circle)
        XCTAssertFalse(xorResult.isEmpty)
    }
    
    // MARK: - Path Simplification Tests
    
    func testDouglasPeuckerSimplification() throws {
        let complexPath = "M0,0 L10,5 L20,2 L30,8 L40,3 L50,7 L60,1 L70,9 L80,4 L90,6 L100,0"
        
        let simplifiedPath = try vectorOps.douglasPeuckerSimplify(path: complexPath, tolerance: 1.0)
        XCTAssertFalse(simplifiedPath.isEmpty)
        XCTAssertNotEqual(complexPath, simplifiedPath)
    }
    
    func testVisvalingamSimplification() throws {
        let complexPath = "M0,0 L10,5 L20,2 L30,8 L40,3 L50,7 L60,1 L70,9 L80,4 L90,6 L100,0"
        
        let simplifiedPath = try vectorOps.visvalingamSimplify(path: complexPath, tolerance: 1.0)
        XCTAssertFalse(simplifiedPath.isEmpty)
        XCTAssertNotEqual(complexPath, simplifiedPath)
    }
    
    // MARK: - Transformation Tests
    
    func testTranslation() throws {
        let originalPath = "M0,0 L10,0 L10,10 L0,10 Z"
        let translatedPath = try vectorOps.translate(path: originalPath, dx: 5, dy: 3)
        
        XCTAssertFalse(translatedPath.isEmpty)
        XCTAssertNotEqual(originalPath, translatedPath)
    }
    
    func testRotation() throws {
        let originalPath = "M10,0 L20,0 L20,10 L10,10 Z"
        let rotatedPath = try vectorOps.rotate(path: originalPath, angle: .pi / 4, centerX: 15, centerY: 5)
        
        XCTAssertFalse(rotatedPath.isEmpty)
        XCTAssertNotEqual(originalPath, rotatedPath)
    }
    
    func testScaling() throws {
        let originalPath = "M0,0 L10,0 L10,10 L0,10 Z"
        let scaledPath = try vectorOps.scale(path: originalPath, sx: 2, sy: 1.5)
        
        XCTAssertFalse(scaledPath.isEmpty)
        XCTAssertNotEqual(originalPath, scaledPath)
    }
    
    func testSkew() throws {
        let originalPath = "M0,0 L10,0 L10,10 L0,10 Z"
        let skewedPath = try vectorOps.skew(path: originalPath, skewX: 0.2, skewY: 0.1)
        
        XCTAssertFalse(skewedPath.isEmpty)
        XCTAssertNotEqual(originalPath, skewedPath)
    }
    
    func testCustomTransform() throws {
        let originalPath = "M0,0 L10,0 L10,10 L0,10 Z"
        let matrix = TransformationMatrix(a: 1, b: 0.1, c: 0.2, d: 1, e: 5, f: 3)
        let transformedPath = try vectorOps.transform(path: originalPath, matrix: matrix)
        
        XCTAssertFalse(transformedPath.isEmpty)
        XCTAssertNotEqual(originalPath, transformedPath)
    }
    
    // MARK: - Geometric Primitives Tests
    
    func testBezierCurveCreation() throws {
        let start = Point(x: 0, y: 0)
        let control1 = Point(x: 10, y: 20)
        let control2 = Point(x: 30, y: 20)
        let end = Point(x: 40, y: 0)
        
        let bezierPath = try vectorOps.createBezierCurve(start: start, control1: control1, control2: control2, end: end)
        XCTAssertFalse(bezierPath.isEmpty)
        XCTAssertTrue(bezierPath.contains("C"))
    }
    
    func testArcCreation() throws {
        let center = Point(x: 50, y: 50)
        let radius = 25.0
        
        let arcPath = try vectorOps.createArc(center: center, radius: radius, startAngle: 0, endAngle: .pi)
        XCTAssertFalse(arcPath.isEmpty)
    }
    
    func testCircleCreation() throws {
        let center = Point(x: 50, y: 50)
        let radius = 25.0
        
        let circlePath = try vectorOps.createCircle(center: center, radius: radius)
        XCTAssertFalse(circlePath.isEmpty)
    }
    
    // MARK: - Geometric Predicates Tests
    
    func testPointInPolygon() throws {
        let squarePath = "M0,0 L100,0 L100,100 L0,100 Z"
        
        let insidePoint = Point(x: 50, y: 50)
        let outsidePoint = Point(x: 150, y: 150)
        
        XCTAssertTrue(try vectorOps.pointInPolygon(point: insidePoint, path: squarePath))
        XCTAssertFalse(try vectorOps.pointInPolygon(point: outsidePoint, path: squarePath))
    }
    
    func testLineIntersection() throws {
        let line1 = LineSegment(start: Point(x: 0, y: 0), end: Point(x: 100, y: 100))
        let line2 = LineSegment(start: Point(x: 0, y: 100), end: Point(x: 100, y: 0))
        
        let intersection = try vectorOps.lineIntersection(line1: line1, line2: line2)
        XCTAssertNotNil(intersection)
        XCTAssertEqual(intersection?.x, 50, accuracy: 0.1)
        XCTAssertEqual(intersection?.y, 50, accuracy: 0.1)
    }
    
    func testDistanceCalculations() {
        let point1 = Point(x: 0, y: 0)
        let point2 = Point(x: 3, y: 4)
        
        let distance = vectorOps.distance(point1: point1, point2: point2)
        XCTAssertEqual(distance, 5.0, accuracy: 0.01)
    }
    
    func testDistanceToLine() throws {
        let point = Point(x: 5, y: 5)
        let line = LineSegment(start: Point(x: 0, y: 0), end: Point(x: 10, y: 0))
        
        let distance = try vectorOps.distanceToLine(point: point, line: line)
        XCTAssertEqual(distance, 5.0, accuracy: 0.01)
    }
    
    // MARK: - Utility Operations Tests
    
    func testGetBounds() throws {
        let trianglePath = "M0,0 L100,0 L50,100 Z"
        
        let bounds = try vectorOps.getBounds(path: trianglePath)
        XCTAssertEqual(bounds.minX, 0, accuracy: 0.1)
        XCTAssertEqual(bounds.minY, 0, accuracy: 0.1)
        XCTAssertEqual(bounds.maxX, 100, accuracy: 0.1)
        XCTAssertEqual(bounds.maxY, 100, accuracy: 0.1)
        
        XCTAssertEqual(bounds.width, 100, accuracy: 0.1)
        XCTAssertEqual(bounds.height, 100, accuracy: 0.1)
        XCTAssertEqual(bounds.center.x, 50, accuracy: 0.1)
        XCTAssertEqual(bounds.center.y, 50, accuracy: 0.1)
    }
    
    func testIsEmpty() throws {
        let emptyPath = ""
        let validPath = "M0,0 L10,0 L10,10 L0,10 Z"
        
        XCTAssertTrue(try vectorOps.isEmpty(path: emptyPath))
        XCTAssertFalse(try vectorOps.isEmpty(path: validPath))
    }
    
    func testPathLength() throws {
        let linePath = "M0,0 L100,0"
        let length = try vectorOps.pathLength(path: linePath)
        XCTAssertEqual(length, 100.0, accuracy: 0.1)
    }
    
    func testSmoothPath() throws {
        let jaggedPath = "M0,0 L10,10 L20,0 L30,10 L40,0"
        
        let smoothedPath = try vectorOps.smoothPath(path: jaggedPath, factor: 0.5)
        XCTAssertFalse(smoothedPath.isEmpty)
        XCTAssertNotEqual(jaggedPath, smoothedPath)
    }
    
    // MARK: - Performance Tests
    
    func testBooleanOperationPerformance() throws {
        let complexPath1 = "M\(Array(0..<100).map { "M\($0),\(sin(Double($0)) * 50)" }.joined(separator: " "))"
        let complexPath2 = "M\(Array(0..<100).map { "M\($0),\(cos(Double($0)) * 50)" }.joined(separator: " "))"
        
        measure {
            do {
                _ = try vectorOps.union(pathA: complexPath1, pathB: complexPath2)
            } catch {
                XCTFail("Performance test failed with error: \(error)")
            }
        }
    }
    
    func testSimplificationPerformance() throws {
        let veryComplexPath = "M\(Array(0..<1000).map { "M\($0),\(sin(Double($0)) * 100)" }.joined(separator: " "))"
        
        measure {
            do {
                _ = try vectorOps.douglasPeuckerSimplify(path: veryComplexPath, tolerance: 1.0)
            } catch {
                XCTFail("Performance test failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidPathHandling() {
        let invalidPath = "INVALID_PATH_STRING"
        
        XCTAssertThrowsError(try vectorOps.union(pathA: invalidPath, pathB: invalidPath)) { error in
            XCTAssertTrue(error is CapsuleError)
        }
        
        XCTAssertThrowsError(try vectorOps.getBounds(path: invalidPath)) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    func testInvalidTransformationParameters() throws {
        let validPath = "M0,0 L10,0 L10,10 L0,10 Z"
        
        // Test with extreme values
        XCTAssertThrowsError(try vectorOps.scale(path: validPath, sx: Double.infinity, sy: 1.0))
        XCTAssertThrowsError(try vectorOps.rotate(path: validPath, angle: Double.nan, centerX: 5, centerY: 5))
    }
    
    // MARK: - Edge Cases Tests
    
    func testDegeneratePaths() throws {
        let pointPath = "M5,5"
        let linePath = "M0,0 L10,0"
        
        XCTAssertFalse(try vectorOps.isEmpty(path: pointPath))
        XCTAssertFalse(try vectorOps.isEmpty(path: linePath))
    }
    
    func testVerySmallPaths() throws {
        let tinyPath = "M0.001,0.001 L0.002,0.001 L0.002,0.002 L0.001,0.002 Z"
        
        let bounds = try vectorOps.getBounds(path: tinyPath)
        XCTAssertLessThan(bounds.width, 0.01)
        XCTAssertLessThan(bounds.height, 0.01)
    }
    
    func testConcurrentOperations() throws {
        let path1 = "M0,0 L100,0 L100,100 L0,100 Z"
        let path2 = "M50,0 A50,50 0 0,1 50,100 A50,50 0 0,1 50,0"
        
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 10
        
        for _ in 0..<10 {
            concurrentQueue.async {
                do {
                    _ = try self.vectorOps.union(pathA: path1, pathB: path2)
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent operation failed: \(error)")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentBooleanOperations() throws {
        let complexPath1 = createComplexTestPath()
        let complexPath2 = "M\(Array(0..<50).map { "M\($0 * 2),\(cos(Double($0)) * 50 + 50)" }.joined(separator: " "))"
        
        let concurrentQueue = DispatchQueue(label: "boolean.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var results: [String] = []
        let resultsQueue = DispatchQueue(label: "results.queue")
        
        for i in 0..<5 {
            group.enter()
            concurrentQueue.async {
                do {
                    let result = try self.vectorOps.union(pathA: complexPath1, pathB: complexPath2)
                    resultsQueue.async {
                        results.append(result)
                        group.leave()
                    }
                } catch {
                    XCTFail("Concurrent boolean operation \(i) failed: \(error)")
                    group.leave()
                }
            }
        }
        
        group.wait()
        XCTAssertEqual(results.count, 5)
        
        // Verify determinism - all results should be identical
        if let firstResult = results.first {
            let allIdentical = results.allSatisfy { $0 == firstResult }
            XCTAssertTrue(allIdentical, "Concurrent operations should produce identical results")
        }
    }
    
    func testConcurrentTransformations() throws {
        let originalPath = "M0,0 L10,0 L10,10 L0,10 Z"
        let transformations = [
            TransformationMatrix.translation(dx: 10, dy: 5),
            TransformationMatrix.rotation(angle: .pi/4, centerX: 5, centerY: 5),
            TransformationMatrix.scaling(sx: 2, sy: 1.5),
            TransformationMatrix.skew(skewX: 0.2, skewY: 0.1),
            TransformationMatrix(a: 1.2, b: 0.1, c: -0.1, d: 1.1, e: 3, f: 2)
        ]
        
        let concurrentQueue = DispatchQueue(label: "transform.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var transformedPaths: [String] = []
        let resultsQueue = DispatchQueue(label: "transform.results")
        
        for (index, matrix) in transformations.enumerated() {
            group.enter()
            concurrentQueue.async {
                do {
                    let result = try self.vectorOps.transform(path: originalPath, matrix: matrix)
                    resultsQueue.async {
                        transformedPaths.append(result)
                        group.leave()
                    }
                } catch {
                    XCTFail("Concurrent transformation \(index) failed: \(error)")
                    group.leave()
                }
            }
        }
        
        group.wait()
        XCTAssertEqual(transformedPaths.count, 5)
        
        // Verify all transformations produced valid results
        for (index, path) in transformedPaths.enumerated() {
            XCTAssertFalse(path.isEmpty, "Transformation \(index) should produce a valid path")
            XCTAssertNotEqual(path, originalPath, "Transformation \(index) should modify the original path")
        }
    }
    
    func testConcurrentGeometricPredicates() throws {
        let polygonPath = createComplexTestPath()
        let testPoints = Array(0..<20).map { i in
            Point(x: Double(i * 10), y: Double(i * 5))
        }
        
        let concurrentQueue = DispatchQueue(label: "predicates.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var pointInPolygonResults: [Bool] = []
        let resultsQueue = DispatchQueue(label: "predicates.results")
        
        for point in testPoints {
            group.enter()
            concurrentQueue.async {
                do {
                    let result = try self.vectorOps.pointInPolygon(point: point, path: polygonPath)
                    resultsQueue.async {
                        pointInPolygonResults.append(result)
                        group.leave()
                    }
                } catch {
                    XCTFail("Concurrent point-in-polygon test failed: \(error)")
                    group.leave()
                }
            }
        }
        
        group.wait()
        XCTAssertEqual(pointInPolygonResults.count, testPoints.count)
    }
    
    func testConcurrentPathAnalysis() throws {
        let testPaths = [
            createComplexTestPath(),
            "M0,0 L100,0 L100,100 L0,100 Z",
            "M50,0 A50,50 0 0,1 50,100 A50,50 0 0,1 50,0",
            createVeryComplexTestPath(),
            "M10,10 L20,20 L30,10 L40,20"
        ]
        
        let concurrentQueue = DispatchQueue(label: "analysis.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var boundsResults: [BoundingBox] = []
        var lengthResults: [Double] = []
        var emptyResults: [Bool] = []
        let resultsQueue = DispatchQueue(label: "analysis.results")
        
        for (index, path) in testPaths.enumerated() {
            group.enter()
            concurrentQueue.async {
                do {
                    let bounds = try self.vectorOps.getBounds(path: path)
                    let length = try self.vectorOps.pathLength(path: path)
                    let isEmpty = try self.vectorOps.isEmpty(path: path)
                    
                    resultsQueue.async {
                        boundsResults.append(bounds)
                        lengthResults.append(length)
                        emptyResults.append(isEmpty)
                        group.leave()
                    }
                } catch {
                    XCTFail("Concurrent path analysis \(index) failed: \(error)")
                    group.leave()
                }
            }
        }
        
        group.wait()
        XCTAssertEqual(boundsResults.count, testPaths.count)
        XCTAssertEqual(lengthResults.count, testPaths.count)
        XCTAssertEqual(emptyResults.count, testPaths.count)
        
        // Verify results are reasonable
        for (index, bounds) in boundsResults.enumerated() {
            XCTAssertLessThanOrEqual(bounds.minX, bounds.maxX, "Bounds \(index) should be valid")
            XCTAssertLessThanOrEqual(bounds.minY, bounds.maxY, "Bounds \(index) should be valid")
        }
        
        for (index, length) in lengthResults.enumerated() {
            XCTAssertGreaterThanOrEqual(length, 0, "Length \(index) should be non-negative")
        }
    }
    
    func testConcurrentPrimitiveCreation() throws {
        let bezierParams = Array(0..<10).map { i in
            (
                Point(x: Double(i), y: 0),
                Point(x: Double(i) + 25, y: 50),
                Point(x: Double(i) + 50, y: 50),
                Point(x: Double(i) + 75, y: 0)
            )
        }
        
        let concurrentQueue = DispatchQueue(label: "primitives.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var bezierPaths: [String] = []
        let resultsQueue = DispatchQueue(label: "primitives.results")
        
        for (index, params) in bezierParams.enumerated() {
            group.enter()
            concurrentQueue.async {
                do {
                    let bezierPath = try self.vectorOps.createBezierCurve(
                        start: params.0,
                        control1: params.1,
                        control2: params.2,
                        end: params.3
                    )
                    resultsQueue.async {
                        bezierPaths.append(bezierPath)
                        group.leave()
                    }
                } catch {
                    XCTFail("Concurrent Bezier creation \(index) failed: \(error)")
                    group.leave()
                }
            }
        }
        
        group.wait()
        XCTAssertEqual(bezierPaths.count, bezierParams.count)
        
        // Verify all paths are valid and contain curve commands
        for (index, path) in bezierPaths.enumerated() {
            XCTAssertFalse(path.isEmpty, "Bezier path \(index) should not be empty")
            XCTAssertTrue(path.contains("C"), "Bezier path \(index) should contain curve commands")
        }
    }
}

// MARK: - Supporting Types for Testing

extension VectorCapsuleTests {
    
    func createComplexTestPath() -> String {
        var points: [String] = []
        for i in 0..<100 {
            let x = Double(i)
            let y = sin(Double(i) * 0.1) * 50 + 50
            points.append("M\(x),\(y)")
        }
        return points.joined(separator: " L")
    }
    
    func createVeryComplexTestPath() -> String {
        var points: [String] = []
        for i in 0..<500 {
            let x = Double(i) * 2
            let y = sin(Double(i) * 0.05) * 100 + cos(Double(i) * 0.02) * 50 + 100
            points.append("M\(x),\(y)")
        }
        return points.joined(separator: " L")
    }
}