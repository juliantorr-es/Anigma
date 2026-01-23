import Foundation
import AnigmaPrimitives
import CapsuleCore

/// High-level interface for deterministic vector geometry operations.
public final class VectorCapsule {
    private let wrapper: VectorCapsuleWrapper
    
    public init() throws {
        self.wrapper = try VectorCapsuleWrapper()
    }
    
    /// Create a path from an SVG string.
    public func path(fromSVG svg: String) throws -> VectorPath {
        let handle = try wrapper.createPath(fromSVG: svg)
        return VectorPath(handle: handle, wrapper: wrapper)
    }
    
    /// Create a rectangular path.
    public func rectangle(x: Double, y: Double, width: Double, height: Double) throws -> VectorPath {
        let handle = try wrapper.createRectangle(x: x, y: y, width: width, height: height)
        return VectorPath(handle: handle, wrapper: wrapper)
    }
    
    /// Create a circular path.
    public func circle(centerX: Double, centerY: Double, radius: Double, segments: Int = 32) throws -> VectorPath {
        let handle = try wrapper.createCircle(centerX: centerX, centerY: centerY, radius: radius, segments: segments)
        return VectorPath(handle: handle, wrapper: wrapper)
    }
    
    /// Create a polygon path.
    public func polygon(points: [(Double, Double)]) throws -> VectorPath {
        let handle = try wrapper.createPolygon(from: points)
        return VectorPath(handle: handle, wrapper: wrapper)
    }
}

/// Represents a vector path or shape.
public final class VectorPath {
    internal let handle: CapsuleHandle<AnyObject>
    private let wrapper: VectorCapsuleWrapper
    
    internal init(handle: CapsuleHandle<AnyObject>, wrapper: VectorCapsuleWrapper) {
        self.handle = handle
        self.wrapper = wrapper
    }
    
    /// Export path to SVG string.
    public func toSVG() throws -> String {
        return try wrapper.exportToSVG(handle)
    }
    
    /// Check if path is empty.
    public var isEmpty: Bool {
        return (try? wrapper.isEmpty(handle)) ?? true
    }
    
    /// Get path bounding box.
    public var bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        return (try? wrapper.getBounds(handle)) ?? (0, 0, 0, 0)
    }
    
    /// Simplify path using Douglas-Peucker algorithm.
    public func simplify(tolerance: Double) throws -> VectorPath {
        let resultHandle = try wrapper.simplifyDouglasPeucker(handle, tolerance: tolerance)
        return VectorPath(handle: resultHandle, wrapper: wrapper)
    }
    
    // MARK: - Boolean Operations
    
    public func union(_ other: VectorPath) throws -> VectorPath {
        let resultHandle = try wrapper.union(self.handle, other.handle)
        return VectorPath(handle: resultHandle, wrapper: wrapper)
    }
    
    public func intersection(_ other: VectorPath) throws -> VectorPath {
        let resultHandle = try wrapper.intersection(self.handle, other.handle)
        return VectorPath(handle: resultHandle, wrapper: wrapper)
    }
    
    public func difference(_ other: VectorPath) throws -> VectorPath {
        let resultHandle = try wrapper.difference(self.handle, other.handle)
        return VectorPath(handle: resultHandle, wrapper: wrapper)
    }
    
    public func xor(_ other: VectorPath) throws -> VectorPath {
        let resultHandle = try wrapper.xor(self.handle, other.handle)
        return VectorPath(handle: resultHandle, wrapper: wrapper)
    }
}
