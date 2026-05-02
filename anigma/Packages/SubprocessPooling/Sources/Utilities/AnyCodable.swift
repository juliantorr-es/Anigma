//
//  AnyCodable.swift
//  SubprocessPooling
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 5: On-Demand Subprocesses (td-73aea8)
//

import Foundation

/// Type-erased Codable wrapper for flexible JSON handling
/// 
/// This enum can wrap any Codable & Sendable value and allows
/// encoding/decoding of heterogeneous JSON structures.
/// Uses an enum to ensure Sendable conformance (Any is not Sendable).
public indirect enum AnyCodable: Codable, Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    case null
    
    /// Initialize with a Codable & Sendable value
    /// - Parameter value: The value to wrap
    public init<T: Codable & Sendable>(_ value: T) {
        // Attempt to wrap known types
        // This is a simplified approach - for full type safety, use the specific cases
        
        if let str = value as? String {
            self = .string(str)
        } else if let i = value as? Int {
            self = .int(i)
        } else if let d = value as? Double {
            self = .double(d)
        } else if let b = value as? Bool {
            self = .bool(b)
        } else if let arr = value as? [AnyCodable] {
            self = .array(arr)
        } else if let dict = value as? [String: AnyCodable] {
            self = .dictionary(dict)
        } else {
            // For unknown Sendable & Codable types, attempt to encode/decode
            // This is a fallback and may not preserve all type information
            do {
                let data = try JSONEncoder().encode(value)
                let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
                self = decoded
            } catch {
                // If all else fails, use string representation
                self = .string("\(value)")
            }
        }
    }
    
    /// Get the underlying value if it matches the expected type
    /// - Returns: The value cast to type T, or nil if type doesn't match
    public func get<T>() -> T? {
        switch self {
        case .string(let value):
            return value as? T
        case .int(let value):
            return value as? T
        case .double(let value):
            return value as? T
        case .bool(let value):
            return value as? T
        case .array(let value):
            return value as? T
        case .dictionary(let value):
            return value as? T
        case .null:
            return nil
        }
    }
    
    /// The actual value as Any (for compatibility, but loses Sendable guarantees)
    public var value: Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .array(let v): return v.map { $0.value }
        case .dictionary(let v): return v.mapValues { $0.value }
        case .null: return ()
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as various types
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode value"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs, rhs) {
        case (.string(let l), .string(let r)): return l == r
        case (.int(let l), .int(let r)): return l == r
        case (.double(let l), .double(let r)): return l == r
        case (.bool(let l), .bool(let r)): return l == r
        case (.array(let l), .array(let r)): return l == r
        case (.dictionary(let l), .dictionary(let r)): return l == r
        case (.null, .null): return true
        default: return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .string(let v): hasher.combine(v)
        case .int(let v): hasher.combine(v)
        case .double(let v): hasher.combine(v)
        case .bool(let v): hasher.combine(v)
        case .array(let v): hasher.combine(v)
        case .dictionary(let v): hasher.combine(v)
        case .null: hasher.combine(0)
        }
    }
}
