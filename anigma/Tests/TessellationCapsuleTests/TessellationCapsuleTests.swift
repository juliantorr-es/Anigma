// TessellationCapsuleTests.swift
import XCTest
import CapsuleCore
@testable import TessellationCapsule

final class TessellationCapsuleTests: XCTestCase {
    var capsule: TessellationCapsule!
    
    override func setUp() {
        super.setUp()
        capsule = TessellationCapsule()
    }
    
    // MARK: - Basic Tessellation Tests
    
    func testTessellateSimpleTriangle() async throws {
        let triangle = try Polygon(vertices: [
            Point2D(x: 0, y: 0),
            Point2D(x: 1, y: 0),
            Point2D(x: 0.5, y: 1)
        ])
        
        let mesh = try await capsule.tessellate(triangle)
        
        XCTAssertEqual(mesh.vertices.count, 3)
        XCTAssertEqual(mesh.triangles.count, 1)
        XCTAssertEqual(mesh.triangles[0], [0, 1, 2])
    }
    
    func testTessellateSquare() async throws {
        let square = try Polygon(vertices: [
            Point2D(x: 0, y: 0),
            Point2D(x: 1, y: 0),
            Point2D(x: 1, y: 1),
            Point2D(x: 0, y: 1)
        ])
        
        let mesh = try await capsule.tessellate(square)
        
        XCTAssertEqual(mesh.vertices.count, 4)
        XCTAssertEqual(mesh.triangles.count, 2)
    }
    
    func testGoldenSquare() async throws {
        let square = try Polygon(vertices: [
            Point2D(x: 0, y: 0),
            Point2D(x: 1, y: 0),
            Point2D(x: 1, y: 1),
            Point2D(x: 0, y: 1)
        ])
        
        let mesh = try await capsule.tessellate(square)
        
        var output = "Vertices:\n"
        for v in mesh.vertices {
            output += String(format: "(%.1f, %.1f)\n", v.x, v.y)
        }
        output += "Triangles:\n"
        for t in mesh.triangles {
            output += "[\(t[0]), \(t[1]), \(t[2])]\n"
        }
        
        // Read golden file
        // Relative: ../Golden/square_mesh.golden
        let goldenURL = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("Golden/square_mesh.golden")
        
        let goldenData = try Data(contentsOf: goldenURL)
        var goldenString = String(data: goldenData, encoding: .utf8)!
        
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        goldenString = goldenString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        XCTAssertEqual(output, goldenString)
    }
}
