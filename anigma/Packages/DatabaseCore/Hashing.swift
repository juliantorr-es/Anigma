//
//  Hashing.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation
import CryptoKit
import AnigmaPrimitives

public enum Hashing {
    public static func blake3Hex(_ s: String) -> String {
        return BLAKE3Digest.hex(of: s)
    }

    public static func blake3Hex(_ data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }
}

public struct SQLIn {
    public let clause: String
    public let params: [DatabaseParameter]
}

public func sqlIn(_ values: [String]) -> SQLIn {
    let placeholders = values.map { _ in "?" }.joined(separator: ",")
    return SQLIn(clause: "(\(placeholders))", params: values.map(dbp))
}
