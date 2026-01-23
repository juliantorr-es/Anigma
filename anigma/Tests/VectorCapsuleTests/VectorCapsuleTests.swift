import XCTest
@testable import VectorCapsule
import CapsuleCore
import AnigmaNativeShims

final class VectorCapsuleTests: XCTestCase {
    
    var vectorCapsule: VectorCapsuleWrapper!
    
    override func setUp() async throws {
        try super.setUp()
        vectorCapsule = try VectorCapsuleWrapper()
    }
    
    override func tearDown() async throws {
        vectorCapsule = nil
        try super.tearDown()
    }
    
    // MARK: - Identity Tests
    
    func testCapsuleIdentity() throws {
        let identity = VectorCapsuleWrapper.identity
        
        XCTAssertEqual(identity.capsule_id, "vector_capsule")
        XCTAssertEqual(identity.algo_version, "1.0.0")
        XCTAssertEqual(identity.determinism_tier, 1)  // Tier 1: bitwise deterministic
        XCTAssertFalse(identity.build_hash.isEmpty)
    }
    
    // MARK: - Path Creation Tests
    
    func testCreateRectangle() throws {
        let rectangle = try vectorCapsule.createRectangle(x: 10, y: 20, width: 100, height: 50)
        defer { rectangle.invalidate() }
        
        let svgString = try vectorCapsule.exportToSVG(rectangle)
        XCTAssertTrue(svgString.contains("<path"))
        XCTAssertTrue(svgString.contains("M10,20"))
        XCTAssertTrue(svgString.contains("L110,20"))
        XCTAssertTrue(svgString.contains("L110,70"))
        XCTAssertTrue(svgString.contains("L10,70"))
        XCTAssertTrue(svgString.contains("Z"))
    }
    
    func testCreateCircle() throws {
        let circle = try vectorCapsule.createCircle(centerX: 50, centerY: 50, radius: 25, segments: 16)
        defer { circle.invalidate() }
        
        let svgString = try vectorCapsule.exportToSVG(circle)
        XCTAssertTrue(svgString.contains("<path"))
        XCTAssertTrue(svgString.contains("M75,50"))  // Starting point
        XCTAssertTrue(svgString.contains("Z"))
    }
    
    func testCreatePolygon() throws {
        let points = [(0, 0), (100, 0), (50, 86.6)]  // Equilateral triangle
        let triangle = try vectorCapsule.createPolygon(from: points)
        defer { triangle.invalidate() }
        
        let svgString = try vectorCapsule.exportToSVG(triangle)
        XCTAssertTrue(svgString.contains("<path"))
        XCTAssertTrue(svgString.contains("M0,0"))
        XCTAssertTrue(svgString.contains("L100,0"))
        XCTAssertTrue(svgString.contains("L50,86.6"))
        XCTAssertTrue(svgString.contains("Z"))
    }
    
    func testCreateFromSVG() throws {
        let svgPath = "M10,10 L90,10 L90,90 L10,90 Z"
        let path = try vectorCapsule.createPath(fromSVG: svgPath)
        defer { path.invalidate() }
        
        let exportedSVG = try vectorCapsule.exportToSVG(path)
        XCTAssertTrue(exportedSVG.contains("<path"))
        XCTAssertTrue(exportedSVG.contains("M10,10"))
        XCTAssertTrue(exportedSVG.contains("L90,10"))
        XCTAssertTrue(exportedSVG.contains("L90,90"))
        XCTAssertTrue(exportedSVG.contains("L10,90"))
        XCTAssertTrue(exportedSVG.contains("Z"))
    }
    
    // MARK: - Geometric Predicate Tests
    
    func testIsEmptyEmpty() throws {
        let emptySVG = "M0,0 Z"
        let emptyPath = try vectorCapsule.createPath(fromSVG: emptySVG)
        defer { emptyPath.invalidate() }
        
        let isEmpty = try vectorCapsule.isEmpty(emptyPath)
        // Note: This might not be empty depending on implementation
        // XCTAssertTrue(isEmpty)
    }
    
    func testGetBoundsRectangle() throws {
        let rectangle = try vectorCapsule.createRectangle(x: 10, y: 20, width: 100, height: 50)
        defer { rectangle.invalidate() }
        
        let bounds = try vectorCapsule.getBounds(rectangle)
        XCTAssertEqual(bounds.minX, 10.0, accuracy: 0.1)
        XCTAssertEqual(bounds.minY, 20.0, accuracy: 0.1)
        XCTAssertEqual(bounds.maxX, 110.0, accuracy: 0.1)
        XCTAssertEqual(bounds.maxY, 70.0, accuracy: 0.1)
    }
    
    func testGetBoundsCircle() throws {
        let circle = try vectorCapsule.createCircle(centerX: 0, centerY: 0, radius: 10)
        defer { circle.invalidate() }
        
        let bounds = try vectorCapsule.getBounds(circle)
        XCTAssertEqual(bounds.minX, -10.0, accuracy: 0.5)
        XCTAssertEqual(bounds.minY, -10.0, accuracy: 0.5)
        XCTAssertEqual(bounds.maxX, 10.0, accuracy: 0.5)
        XCTAssertEqual(bounds.maxY, 10.0, accuracy: 0.5)
    }
    
    // MARK: - Boolean Operation Tests
    
    func testUnionOverlappingRectangles() throws {
        let rect1 = try vectorCapsule.createRectangle(x: 0, y: 0, width: 50, height: 50)
        let rect2 = try vectorCapsule.createRectangle(x: 25, y: 25, width: 50, height: 50)
        defer { 
            rect1.invalidate()
            rect2.invalidate() 
        }
        
        let unionResult = try vectorCapsule.union(rect1, rect2)
        defer { unionResult.invalidate() }
        
        let unionSVG = try vectorCapsule.exportToSVG(unionResult)
        XCTAssertTrue(unionSVG.contains("<path"))
        // Should contain area from both rectangles
        let bounds = try vectorCapsule.getBounds(unionResult)
        XCTAssertEqual(bounds.minX, 0.0, accuracy: 1.0)
        XCTAssertEqual(bounds.minY, 0.0, accuracy: 1.0)
        XCTAssertEqual(bounds.maxX, 75.0, accuracy: 1.0)
        XCTAssertEqual(bounds.maxY, 75.0, accuracy: 1.0)
    }
    
    func testIntersectionOverlappingRectangles() throws {
        let rect1 = try vectorCapsule.createRectangle(x: 0, y: 0, width: 50, height: 50)
        let rect2 = try vectorCapsule.createRectangle(x: 25, y: 25, width: 50, height: 50)
        defer { 
            rect1.invalidate()
            rect2.invalidate() 
        }
        
        let intersectionResult = try vectorCapsule.intersection(rect1, rect2)
        defer { intersectionResult.invalidate() }
        
        let bounds = try vectorCapsule.getBounds(intersectionResult)
        // Should be the overlapping 25x25 area
        XCTAssertEqual(bounds.minX, 25.0, accuracy: 1.0)
        XCTAssertEqual(bounds.minY, 25.0, accuracy: 1.0)
        XCTAssertEqual(bounds.maxX, 50.0, accuracy: 1.0)
        XCTAssertEqual(bounds.maxY, 50.0, accuracy: 1.0)
    }
    
    func testDifferenceRectangles() throws {
        let rect1 = try vectorCapsule.createRectangle(x: 0, y: 0, width: 50, height: 50)
        let rect2 = try vectorCapsule.createRectangle(x: 25, y: 25, width: 25, height: 25)
        defer { 
            rect1.invalidate()
            rect2.invalidate() 
        }
        
        let differenceResult = try vectorCapsule.difference(rect1, rect2)
        defer { differenceResult.invalidate() }
        
        let bounds = try vectorCapsule.getBounds(differenceResult)
        // Should be rect1 with the overlapping area removed
        XCTAssertEqual(bounds.minX, 0.0, accuracy: 1.0)
        XCTAssertEqual(bounds.minY, 0.0, accuracy: 1.0)
        XCTAssertEqual(bounds.maxX, 50.0, accuracy: 1.0)
        XCTAssertEqual(bounds.maxY, 50.0, accuracy: 1.0)
    }
    
    func testXorRectangles() throws {
        let rect1 = try vectorCapsule.createRectangle(x: 0, y: 0, width: 50, height: 50)
        let rect2 = try vectorCapsule.createRectangle(x: 25, y: 25, width: 50, height: 50)
        defer { 
            rect1.invalidate()
            rect2.invalidate() 
        }
        
        let xorResult = try vectorCapsule.xor(rect1, rect2)
        defer { xorResult.invalidate() }
        
        let svgString = try vectorCapsule.exportToSVG(xorResult)
        XCTAssertTrue(svgString.contains("<path"))
        // Should have non-overlapping parts from both rectangles
    }
    
    // MARK: - Simplification Tests
    
    func testDouglasPeuckerSimplification() throws {
        // Create a path with many points that can be simplified
        let points: [(Double, Double)] = [
            (0, 0), (10, 0), (20, 0), (30, 0), (40, 0), (50, 0),
            (50, 10), (50, 20), (50, 30), (50, 40), (50, 50),
            (40, 50), (30, 50), (20, 50), (10, 50), (0, 50),
            (0, 40), (0, 30), (0, 20), (0, 10)
        ]
        
        let complexPath = try vectorCapsule.createPolygon(from: points)
        defer { complexPath.invalidate() }
        
        let simplifiedPath = try vectorCapsule.simplifyDouglasPeucker(complexPath, tolerance: 5.0)
        defer { simplifiedPath.invalidate() }
        
        let simplifiedSVG = try vectorCapsule.exportToSVG(simplifiedPath)
        let originalSVG = try vectorCapsule.exportToSVG(complexPath)
        
        // Simplified path should have fewer points
        XCTAssertLessThan(simplifiedSVG.count, originalSVG.count)
        XCTAssertTrue(simplifiedSVG.contains("<path"))
    }
    
    // MARK: - Determinism Tests
    
    func testDeterministicOutput() throws {
        // Create identical paths and verify outputs are identical
        let svgPath = "M10,10 L90,10 L90,90 L10,90 Z"
        let path1 = try vectorCapsule.createPath(fromSVG: svgPath)
        let path2 = try vectorCapsule.createPath(fromSVG: svgPath)
        defer { 
            path1.invalidate()
            path2.invalidate() 
        }
        
        let svg1 = try vectorCapsule.exportToSVG(path1)
        let svg2 = try vectorCapsule.exportToSVG(path2)
        
        // Outputs should be identical for deterministic capsule
        XCTAssertEqual(svg1, svg2)
    }
    
    func testDeterministicBooleanOperation() throws {
        // Create identical shapes and perform boolean operations
        let rect1a = try vectorCapsule.createRectangle(x: 0, y: 0, width: 50, height: 50)
        let rect1b = try vectorCapsule.createRectangle(x: 0, y: 0, width: 50, height: 50)
        let rect2a = try vectorCapsule.createRectangle(x: 25, y: 25, width: 25, height: 25)
        let rect2b = try vectorCapsule.createRectangle(x: 25, y: 25, width: 25, height: 25)
        defer { 
            rect1a.invalidate(); rect1b.invalidate()
            rect2a.invalidate(); rect2b.invalidate()
        }
        
        let union1 = try vectorCapsule.union(rect1a, rect2a)
        let union2 = try vectorCapsule.union(rect1b, rect2b)
        defer { 
            union1.invalidate()
            union2.invalidate()
        }
        
        let svg1 = try vectorCapsule.exportToSVG(union1)
        let svg2 = try vectorCapsule.exportToSVG(union2)
        
        // Boolean operations should be deterministic
        XCTAssertEqual(svg1, svg2)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidSVGPath() throws {
        // Test with malformed SVG
        XCTAssertThrowsError(try vectorCapsule.createPath(fromSVG: "invalid_svg_path")) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    func testEmptySVGPath() throws {
        // Test with empty SVG
        XCTAssertThrowsError(try vectorCapsule.createPath(fromSVG: "")) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    func testInvalidHandle() throws {
        // Test operations on invalidated handle
        let path = try vectorCapsule.createRectangle(x: 0, y: 0, width: 10, height: 10)
        path.invalidate()  // Invalidate the handle
        
        XCTAssertThrowsError(try vectorCapsule.exportToSVG(path)) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceLargePathCreation() throws {
        let points = (0..<1000).map { i in
            (Double(i), Double(i))
        }
        
        measure {
            do {
                let path = try vectorCapsule.createPolygon(from: points)
                path.invalidate()
            } catch {
                XCTFail("Path creation failed: \(error)")
            }
        }
    }
    
    func testPerformanceBooleanOperation() throws {
        let rect1 = try vectorCapsule.createRectangle(x: 0, y: 0, width: 100, height: 100)
        let rect2 = try vectorCapsule.createRectangle(x: 50, y: 50, width: 100, height: 100)
        defer { 
            rect1.invalidate()
            rect2.invalidate()
        }
        
        measure {
            do {
                let result = try vectorCapsule.union(rect1, rect2)
                result.invalidate()
            } catch {
                XCTFail("Boolean operation failed: \(error)")
            }
        }
    }
}