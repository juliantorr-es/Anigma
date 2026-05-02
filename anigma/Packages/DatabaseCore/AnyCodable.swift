//
//  AnyCodable.swift
//  DatabaseCore
//
//  Type-erased Codable value for dynamic JSON handling.
//

import Foundation

/// Type-erased Codable value for dynamic JSON handling
/// Used for query parameters and results that need to work with arbitrary schemas
public enum AnyCodable: Codable, Sendable, Equatable {
    case null
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let date = try? container.decode(Date.self) {
            self = .date(date)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dict)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .date(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.string(let l), .string(let r)): return l == r
        case (.int(let l), .int(let r)): return l == r
        case (.double(let l), .double(let r)): return l == r
        case (.bool(let l), .bool(let r)): return l == r
        case (.date(let l), .date(let r)): return l == r
        case (.array(let l), .array(let r)): return l == r
        case (.dictionary(let l), .dictionary(let r)): return l == r
        default: return false
        }
    }

    /// Get JSON string representation
    public func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? String(data: encoder.encode(self), encoding: .utf8)) ?? "{}"
    }

    /// Encode a dictionary to JSON string
    public static func encodeToJSON(_ value: [String: AnyCodable]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? String(data: encoder.encode(value), encoding: .utf8)) ?? "{}"
    }
}
