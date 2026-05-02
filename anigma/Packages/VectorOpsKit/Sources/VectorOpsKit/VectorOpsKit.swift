//
//  VectorOpsKit.swift
//  VectorOpsKit
//
//  Boolean and path operations - stub implementation for build.
//

import Foundation

public protocol VectorOps: Sendable {
    func union(pathA: String, pathB: String) throws -> String
    func intersection(pathA: String, pathB: String) throws -> String
    func difference(pathA: String, pathB: String) throws -> String
    func xor(pathA: String, pathB: String) throws -> String
    
    // Path simplification algorithms
    func douglasPeuckerSimplify(path: String, tolerance: Double) throws -> String
    func visvalingamSimplify(path: String, tolerance: Double) throws -> String
    
    // Transformation matrix operations
    func transform(path: String, matrix: TransformationMatrix) throws -> String
    func translate(path: String, dx: Double, dy: Double) throws -> String
    func rotate(path: String, angle: Double, centerX: Double, centerY: Double) throws -> String
    func scale(path: String, sx: Double, sy: Double) throws -> String
    func skew(path: String, skewX: Double, skewY: Double) throws -> String
    
    // Advanced geometric primitives
    func createBezierCurve(start: Point, control1: Point, control2: Point, end: Point) throws -> String
    func createArc(center: Point, radius: Double, startAngle: Double, endAngle: Double) throws -> String
    func createCircle(center: Point, radius: Double) throws -> String
    
    // Geometric predicates
    func pointInPolygon(point: Point, path: String) throws -> Bool
    func lineIntersection(line1: LineSegment, line2: LineSegment) throws -> Point?
    func distance(point1: Point, point2: Point) -> Double
    func distanceToLine(point: Point, line: LineSegment) throws -> Double
    
    // Utility operations
    func getBounds(path: String) throws -> BoundingBox
    func isEmpty(path: String) throws -> Bool
    func pathLength(path: String) throws -> Double
    func smoothPath(path: String, factor: Double) throws -> String
}

// MARK: - Supporting Types

public struct TransformationMatrix: Sendable {
    public let a, b, c, d, e, f: Double  // [a c e; b d f; 0 0 1]
    
    public init(a: Double = 1, b: Double = 0, c: Double = 0, d: Double = 1, e: Double = 0, f: Double = 0) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.e = e; self.f = f
    }
    
    public static let identity = TransformationMatrix()
    
    public static func translation(dx: Double, dy: Double) -> TransformationMatrix {
        TransformationMatrix(a: 1, b: 0, c: 0, d: 1, e: dx, f: dy)
    }
    
    public static func rotation(angle: Double, centerX: Double, centerY: Double) -> TransformationMatrix {
        let cos = cos(angle); let sin = sin(angle)
        return TransformationMatrix(
            a: cos, b: sin,
            c: -sin, d: cos,
            e: centerX * (1 - cos) + centerY * sin,
            f: centerY * (1 - cos) - centerX * sin
        )
    }
    
    public static func scaling(sx: Double, sy: Double) -> TransformationMatrix {
        TransformationMatrix(a: sx, b: 0, c: 0, d: sy, e: 0, f: 0)
    }
    
    public static func skew(skewX: Double, skewY: Double) -> TransformationMatrix {
        TransformationMatrix(a: 1, b: skewY, c: skewX, d: 1, e: 0, f: 0)
    }
}

public struct Point: Sendable {
    public let x, y: Double
    
    public init(x: Double, y: Double) {
        self.x = x; self.y = y
    }
}

public struct LineSegment: Sendable {
    public let start, end: Point
    
    public init(start: Point, end: Point) {
        self.start = start; self.end = end
    }
}

public struct BoundingBox: Sendable {
    public let minX, minY, maxX, maxY: Double
    
    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX; self.minY = minY; self.maxX = maxX; self.maxY = maxY
    }
    
    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var center: Point { Point(x: (minX + maxX) / 2, y: (minY + maxY) / 2) }
}

extension VectorOps {
    /// The default vector operations implementation.
    public static var `default`: VectorOps {
        StubVectorOps()
    }
}

/// Stub vector operations - returns inputs unchanged or default values.
/// Real implementation will use native capsule functions.
public final class StubVectorOps: VectorOps, @unchecked Sendable {
    public init() {}

    public func union(pathA: String, pathB: String) throws -> String { pathA }
    public func intersection(pathA: String, pathB: String) throws -> String { pathA }
    public func difference(pathA: String, pathB: String) throws -> String { pathA }
    public func xor(pathA: String, pathB: String) throws -> String { pathA }
    
    public func douglasPeuckerSimplify(path: String, tolerance: Double) throws -> String { path }
    public func visvalingamSimplify(path: String, tolerance: Double) throws -> String { path }
    
    public func transform(path: String, matrix: TransformationMatrix) throws -> String { path }
    public func translate(path: String, dx: Double, dy: Double) throws -> String { path }
    public func rotate(path: String, angle: Double, centerX: Double, centerY: Double) throws -> String { path }
    public func scale(path: String, sx: Double, sy: Double) throws -> String { path }
    public func skew(path: String, skewX: Double, skewY: Double) throws -> String { path }
    
    public func createBezierCurve(start: Point, control1: Point, control2: Point, end: Point) throws -> String {
        "M\(start.x),\(start.y) C\(control1.x),\(control1.y) \(control2.x),\(control2.y) \(end.x),\(end.y)"
    }
    public func createArc(center: Point, radius: Double, startAngle: Double, endAngle: Double) throws -> String {
        "M\(center.x + radius),\(center.y)"
    }
    public func createCircle(center: Point, radius: Double) throws -> String {
        "M\(center.x + radius),\(center.y)"
    }
    
    public func pointInPolygon(point: Point, path: String) throws -> Bool { false }
    public func lineIntersection(line1: LineSegment, line2: LineSegment) throws -> Point? { nil }
    public func distance(point1: Point, point2: Point) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return (dx * dx + dy * dy).squareRoot()
    }
    public func distanceToLine(point: Point, line: LineSegment) throws -> Double { 0 }
    
    public func getBounds(path: String) throws -> BoundingBox {
        BoundingBox(minX: 0, minY: 0, maxX: 100, maxY: 100)
    }
    public func isEmpty(path: String) throws -> Bool { path.isEmpty }
    public func pathLength(path: String) throws -> Double { 0 }
    public func smoothPath(path: String, factor: Double) throws -> String { path }
}
