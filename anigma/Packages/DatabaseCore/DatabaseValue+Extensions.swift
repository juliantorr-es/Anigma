//
//  DatabaseValue+Extensions.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

// Safe decoding helpers for DatabaseValue? so callers stop force-casting and
// Swift stops yelling "this cast will always fail" (because it will).
//
// Matches DatabaseValue enum with cases: .text(String), .int(Int), .double(Double), .null

extension DatabaseValue {
    public var asString: String? {
        if case .text(let s) = self { return s }
        return nil
    }

    public var asInt64: Int64? {
        if case .int(let i) = self { return Int64(i) }
        return nil
    }

    public var asInt: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    public var asDouble: Double? {
        if case .double(let d) = self { return d }
        return nil
    }

    public var asData: Data? {
        if case .text(let base64) = self {
            return Data(base64Encoded: base64)
        }
        return nil
    }
}

extension Optional where Wrapped == DatabaseValue {
    public var string: String? { self?.asString }
    public var int64: Int64? { self?.asInt64 }
    public var int: Int? { self?.asInt }
    public var double: Double? { self?.asDouble }
    public var data: Data? { self?.asData }
}
