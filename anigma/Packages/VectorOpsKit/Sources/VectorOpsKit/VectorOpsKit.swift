//
//  VectorOpsKit.swift
//  VectorOpsKit
//
//  Boolean and path operations.
//

import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

public protocol VectorOps: Sendable {
    func union(pathA: String, pathB: String) throws -> String
    func intersection(pathA: String, pathB: String) throws -> String
    func difference(pathA: String, pathB: String) throws -> String
    func xor(pathA: String, pathB: String) throws -> String
}

extension VectorOps {
    /// The default vector operations implementation (uses capsule architecture).
    public static var `default`: VectorOps {
        VectorCapsuleWrapper()
    }
}

/// Thread-safe vector operations using native path boolean operations.
/// Use `VectorCapsuleWrapper` for better performance and determinism.
@available(*, deprecated, message: "Use VectorCapsuleWrapper instead for capsule architecture")
public final class NativeVectorOps: VectorOps, @unchecked Sendable {
    public init() {}

    public func union(pathA: String, pathB: String) throws -> String {
        return try perform(op: ANIGMA_OP_UNION, a: pathA, b: pathB)
    }
    
    public func intersection(pathA: String, pathB: String) throws -> String {
        return try perform(op: ANIGMA_OP_INTERSECTION, a: pathA, b: pathB)
    }
    
    public func difference(pathA: String, pathB: String) throws -> String {
        return try perform(op: ANIGMA_OP_DIFFERENCE, a: pathA, b: pathB)
    }
    
    public func xor(pathA: String, pathB: String) throws -> String {
        return try perform(op: ANIGMA_OP_XOR, a: pathA, b: pathB)
    }

    private func perform(op: anigma_path_op_t, a: String, b: String) throws -> String {
        var ctx = anigma_ctx_t()
        var outPtr: UnsafeMutablePointer<CChar>?

        let res = anigma_path_boolean_op(&ctx, op, a, b, &outPtr)
        guard res.status == ANIGMA_OK, let ptr = outPtr else {
            throw NativeError(status: Int32(res.status.rawValue), context: "path_op")
        }

        defer { free(ptr) } // shim uses malloc, we use free (bridged from C stdlib)
        return String(cString: ptr)
    }
}
