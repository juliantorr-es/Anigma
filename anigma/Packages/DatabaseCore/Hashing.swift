//
//  Hashing.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation
import CryptoKit

public enum Hashing {
    public static func sha256Hex(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
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
