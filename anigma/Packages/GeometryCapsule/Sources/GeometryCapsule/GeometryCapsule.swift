import Foundation
import GeometryNative
import CapsuleCore
import AnigmaNativeShims

public enum GeometryFillRule: Int {
    case evenOdd = 0
    case nonZero = 1
    case positive = 2
    case negative = 3
    
    var native: anigma_geometry_fillrule_t {
        return anigma_geometry_fillrule_t(rawValue: UInt32(self.rawValue))
    }
}

public enum GeometryJoinType: Int {
    case square = 0
    case round = 1
    case miter = 2
    
    var native: anigma_geometry_jointype_t {
        return anigma_geometry_jointype_t(rawValue: UInt32(self.rawValue))
    }
}

public enum GeometryEndType: Int {
    case square = 0
    case round = 1
    case butt = 2
    case polygon = 3
    
    var native: anigma_geometry_endtype_t {
        return anigma_geometry_endtype_t(rawValue: UInt32(self.rawValue))
    }
}

public final class GeometryPaths64 {
    internal let handle: CapsuleHandle<AnyObject>
    
    public init() throws {
        var raw: anigma_geometry_paths64_t?
        var err = anigma_capsule_error_t()
        let status = anigma_geometry_paths64_create(&raw, &err)
        guard status == ANIGMA_OK, let h = raw else {
            throw capsuleError(status: status, error: err)
        }
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: h,
            destroyFunction: capsuleDestroyer(anigma_geometry_paths64_destroy)
        )
    }
    
    internal init(handle: CapsuleHandle<AnyObject>) {
        self.handle = handle
    }
    
    public func addPath(coords: [Int64], closed: Bool = true) throws {
        var err = anigma_capsule_error_t()
        try handle.withHandle { h in
            let status = coords.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return ANIGMA_OK } // Empty path
                return anigma_geometry_paths64_add_path_coords(h, base, coords.count / 2, closed, &err)
            }
            if status != ANIGMA_OK {
                throw capsuleError(status: status, error: err)
            }
        }
    }
    
    public func clear() throws {
        var err = anigma_capsule_error_t()
        try handle.withHandle { h in
            let status = anigma_geometry_paths64_clear(h, &err)
            if status != ANIGMA_OK {
                throw capsuleError(status: status, error: err)
            }
        }
    }
    
    public var count: Int {
        var c: Int = 0
        var err = anigma_capsule_error_t()
        // We catch errors but property cannot throw easily, default to 0
        try? handle.withHandle { h in
             _ = anigma_geometry_paths64_count(h, &c, &err)
        }
        return c
    }
    
    public func getPath(index: Int) throws -> [Int64] {
        var err = anigma_capsule_error_t()
        var pathSize: Int = 0
        
        return try handle.withHandle { h in
            var status = anigma_geometry_paths64_path_count(h, index, &pathSize, &err)
            if status != ANIGMA_OK { throw capsuleError(status: status, error: err) }
            
            var buffer = [Int64](repeating: 0, count: pathSize * 2)
            if pathSize > 0 {
                status = buffer.withUnsafeMutableBufferPointer { ptr in
                    anigma_geometry_paths64_get_path(h, index, ptr.baseAddress, ptr.count, &err)
                }
                if status != ANIGMA_OK { throw capsuleError(status: status, error: err) }
            }
            return buffer
        }
    }
    
    private typealias BooleanOpFunc = (anigma_geometry_paths64_t?, anigma_geometry_paths64_t?, anigma_geometry_fillrule_t, UnsafeMutablePointer<anigma_geometry_paths64_t?>?, UnsafeMutablePointer<anigma_capsule_error_t>?) -> anigma_status_t
    
    private func performBooleanOp(_ other: GeometryPaths64, fillRule: GeometryFillRule, op: BooleanOpFunc) throws -> GeometryPaths64 {
        var resultRaw: anigma_geometry_paths64_t?
        var err = anigma_capsule_error_t()
        
        try handle.withHandle { myH in
            try other.handle.withHandle { otherH in
                let status = op(myH, otherH, fillRule.native, &resultRaw, &err)
                if status != ANIGMA_OK {
                    throw capsuleError(status: status, error: err)
                }
            }
        }
        
        guard let r = resultRaw else { throw capsuleError(status: ANIGMA_ERR_INTERNAL, error: err) }
        
        let newHandle = CapsuleHandle<AnyObject>(
            rawHandle: r,
            destroyFunction: capsuleDestroyer(anigma_geometry_paths64_destroy)
        )
        return GeometryPaths64(handle: newHandle)
    }
    
    public func intersect(_ other: GeometryPaths64, fillRule: GeometryFillRule) throws -> GeometryPaths64 {
        return try performBooleanOp(other, fillRule: fillRule, op: anigma_geometry_intersect_64)
    }
    
    public func union(_ other: GeometryPaths64, fillRule: GeometryFillRule) throws -> GeometryPaths64 {
        return try performBooleanOp(other, fillRule: fillRule, op: anigma_geometry_union_64)
    }
    
    public func difference(_ other: GeometryPaths64, fillRule: GeometryFillRule) throws -> GeometryPaths64 {
        return try performBooleanOp(other, fillRule: fillRule, op: anigma_geometry_difference_64)
    }
    
    public func xor(_ other: GeometryPaths64, fillRule: GeometryFillRule) throws -> GeometryPaths64 {
        return try performBooleanOp(other, fillRule: fillRule, op: anigma_geometry_xor_64)
    }
    
    public func inflate(delta: Double, joinType: GeometryJoinType, endType: GeometryEndType, miterLimit: Double = 2.0, arcTolerance: Double = 0.0) throws -> GeometryPaths64 {
        var resultRaw: anigma_geometry_paths64_t?
        var err = anigma_capsule_error_t()
        
        try handle.withHandle { h in
            let status = anigma_geometry_inflate_paths_64(h, delta, joinType.native, endType.native, miterLimit, arcTolerance, &resultRaw, &err)
            if status != ANIGMA_OK {
                throw capsuleError(status: status, error: err)
            }
        }
        
        guard let r = resultRaw else { throw capsuleError(status: ANIGMA_ERR_INTERNAL, error: err) }
        
        let newHandle = CapsuleHandle<AnyObject>(
            rawHandle: r,
            destroyFunction: capsuleDestroyer(anigma_geometry_paths64_destroy)
        )
        return GeometryPaths64(handle: newHandle)
    }
}

public final class GeometryPathsD {
    internal let handle: CapsuleHandle<AnyObject>
    
    public init() throws {
        var raw: anigma_geometry_paths_d_t?
        var err = anigma_capsule_error_t()
        let status = anigma_geometry_paths_d_create(&raw, &err)
        guard status == ANIGMA_OK, let h = raw else {
            throw capsuleError(status: status, error: err)
        }
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: h,
            destroyFunction: capsuleDestroyer(anigma_geometry_paths_d_destroy)
        )
    }
    
    internal init(handle: CapsuleHandle<AnyObject>) {
        self.handle = handle
    }
    
    public func addPath(coords: [Double]) throws {
        var err = anigma_capsule_error_t()
        try handle.withHandle { h in
            let status = coords.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return ANIGMA_OK }
                return anigma_geometry_paths_d_add_path_coords(h, base, coords.count / 2, &err)
            }
            if status != ANIGMA_OK {
                throw capsuleError(status: status, error: err)
            }
        }
    }
    
    public var count: Int {
        var c: Int = 0
        var err = anigma_capsule_error_t()
        try? handle.withHandle { h in
             _ = anigma_geometry_paths_d_count(h, &c, &err)
        }
        return c
    }
    
    public func getPath(index: Int) throws -> [Double] {
        var err = anigma_capsule_error_t()
        var pathSize: Int = 0
        
        return try handle.withHandle { h in
            var status = anigma_geometry_paths_d_path_count(h, index, &pathSize, &err)
            if status != ANIGMA_OK { throw capsuleError(status: status, error: err) }
            
            var buffer = [Double](repeating: 0, count: pathSize * 2)
            if pathSize > 0 {
                status = buffer.withUnsafeMutableBufferPointer { ptr in
                    anigma_geometry_paths_d_get_path(h, index, ptr.baseAddress, ptr.count, &err)
                }
                if status != ANIGMA_OK { throw capsuleError(status: status, error: err) }
            }
            return buffer
        }
    }
    
    private typealias BooleanOpFuncD = (anigma_geometry_paths_d_t?, anigma_geometry_paths_d_t?, anigma_geometry_fillrule_t, Int32, UnsafeMutablePointer<anigma_geometry_paths_d_t?>?, UnsafeMutablePointer<anigma_capsule_error_t>?) -> anigma_status_t
    
    private func performBooleanOp(_ other: GeometryPathsD, fillRule: GeometryFillRule, precision: Int, op: BooleanOpFuncD) throws -> GeometryPathsD {
        var resultRaw: anigma_geometry_paths_d_t?
        var err = anigma_capsule_error_t()
        
        try handle.withHandle { myH in
            try other.handle.withHandle { otherH in
                let status = op(myH, otherH, fillRule.native, Int32(precision), &resultRaw, &err)
                if status != ANIGMA_OK {
                    throw capsuleError(status: status, error: err)
                }
            }
        }
        
        guard let r = resultRaw else { throw capsuleError(status: ANIGMA_ERR_INTERNAL, error: err) }
        
        let newHandle = CapsuleHandle<AnyObject>(
            rawHandle: r,
            destroyFunction: capsuleDestroyer(anigma_geometry_paths_d_destroy)
        )
        return GeometryPathsD(handle: newHandle)
    }
    
    public func intersect(_ other: GeometryPathsD, fillRule: GeometryFillRule, precision: Int = 2) throws -> GeometryPathsD {
        return try performBooleanOp(other, fillRule: fillRule, precision: precision, op: anigma_geometry_intersect_d)
    }
    
    public func union(_ other: GeometryPathsD, fillRule: GeometryFillRule, precision: Int = 2) throws -> GeometryPathsD {
        return try performBooleanOp(other, fillRule: fillRule, precision: precision, op: anigma_geometry_union_d)
    }
    
    public func difference(_ other: GeometryPathsD, fillRule: GeometryFillRule, precision: Int = 2) throws -> GeometryPathsD {
        return try performBooleanOp(other, fillRule: fillRule, precision: precision, op: anigma_geometry_difference_d)
    }
    
    public func xor(_ other: GeometryPathsD, fillRule: GeometryFillRule, precision: Int = 2) throws -> GeometryPathsD {
        return try performBooleanOp(other, fillRule: fillRule, precision: precision, op: anigma_geometry_xor_d)
    }
    
    public func inflate(delta: Double, joinType: GeometryJoinType, endType: GeometryEndType, miterLimit: Double = 2.0, precision: Int = 2, arcTolerance: Double = 0.0) throws -> GeometryPathsD {
        var resultRaw: anigma_geometry_paths_d_t?
        var err = anigma_capsule_error_t()
        
        try handle.withHandle { h in
            let status = anigma_geometry_inflate_paths_d(h, delta, joinType.native, endType.native, miterLimit, Int32(precision), arcTolerance, &resultRaw, &err)
            if status != ANIGMA_OK {
                throw capsuleError(status: status, error: err)
            }
        }
        
        guard let r = resultRaw else { throw capsuleError(status: ANIGMA_ERR_INTERNAL, error: err) }
        
        let newHandle = CapsuleHandle<AnyObject>(
            rawHandle: r,
            destroyFunction: capsuleDestroyer(anigma_geometry_paths_d_destroy)
        )
        return GeometryPathsD(handle: newHandle)
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}
