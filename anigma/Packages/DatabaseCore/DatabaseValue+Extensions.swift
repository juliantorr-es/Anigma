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

    public var asInt32: Int32? {
        if case .int(let i) = self { return Int32(i) }
        return nil
    }

    public var asDouble: Double? {
        if case .double(let d) = self { return d }
        return nil
    }

    public var asData: Data? {
        if case .blob(let d) = self { return d }
        if case .text(let base64) = self {
            return Data(base64Encoded: base64)
        }
        return nil
    }

    public var asDate: Date? {
        if case .date(let d) = self { return d }
        if case .text(let iso8601) = self {
            return ISO8601DateFormatter().date(from: iso8601)
        }
        return nil
    }
}

extension Optional where Wrapped == DatabaseValue {
    public var string: String? { self?.asString }
    public var int64: Int64? { self?.asInt64 }
    public var int: Int? { self?.asInt }
    public var int32: Int32? { self?.asInt32 }
    public var double: Double? { self?.asDouble }
    public var data: Data? { self?.asData }
    public var date: Date? { self?.asDate }
}

public extension DatabaseRow {
    func int32(for column: String) -> Int32? {
        value(for: column)?.asInt32
    }

    func bool(for column: String) -> Bool? {
        guard let stringValue = string(for: column)?.lowercased() else { return nil }
        switch stringValue {
        case "t", "true", "yes", "1": return true
        case "f", "false", "no", "0": return false
        default: return nil
        }
    }
}
