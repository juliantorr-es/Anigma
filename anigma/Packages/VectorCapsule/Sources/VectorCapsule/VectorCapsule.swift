import Foundation
import AnigmaNativeShims
import CapsuleCore

public struct Point: Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct BoundingBox: Sendable {
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double
    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
}

public final class VectorCapsule: Sendable {
    public init() {}
    
    public func exportSVG() throws -> String {
        return ""
    }
    
    public func simplify(tolerance: Double) throws -> VectorCapsule {
        return VectorCapsule()
    }
    
    public func union(pathA: String, pathB: String) throws -> String {
        return pathA // Stub
    }
    
    public func intersection(pathA: String, pathB: String) throws -> String {
        return pathA // Stub
    }
    
    public func douglasPeuckerSimplify(path: String, tolerance: Double) throws -> String {
        return path // Stub
    }
    
    public func pointInPolygon(point: Point, path: String) throws -> Bool {
        return false // Stub
    }
    
    public func getBounds(path: String) throws -> BoundingBox {
        return BoundingBox(minX: 0, minY: 0, maxX: 0, maxY: 0) // Stub
    }
}
