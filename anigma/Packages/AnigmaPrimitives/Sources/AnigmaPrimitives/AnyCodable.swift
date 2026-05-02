import Foundation

/// A type-erased wrapper for heterogeneous Codable values (e.g., JSON).
/// Canonicalized to prevent 'signal 4' compiler crashes by enforcing 'indirect'
/// on recursive cases.
public enum AnyCodable: Codable, @unchecked Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    indirect case array([AnyCodable])
    indirect case dictionary([String: AnyCodable])
    case null
    
    public init(_ value: Any) {
        if let v = value as? String { self = .string(v) }
        else if let v = value as? Int { self = .int(v) }
        else if let v = value as? Double { self = .double(v) }
        else if let v = value as? Bool { self = .bool(v) }
        else if let v = value as? Date { self = .date(v) }
        else if let v = value as? [Any] { self = .array(v.map { AnyCodable($0) }) }
        else if let v = value as? [String: Any] { self = .dictionary(v.mapValues { AnyCodable($0) }) }
        else if let v = value as? AnyCodable { self = v }
        else { self = .null }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let date = try? container.decode(Date.self) {
            self = .date(date)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown value type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .date(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .dictionary(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
    
    public var value: Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .date(let v): return v
        case .array(let v): return v.map { $0.value }
        case .dictionary(let v): return v.mapValues { $0.value }
        case .null: return NSNull()
        }
    }
    
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    public var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    public var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    public var dateValue: Date? {
        if case .date(let v) = self { return v }
        return nil
    }

    public var arrayValue: [AnyCodable]? {
        if case .array(let v) = self { return v }
        return nil
    }

    public var dictionaryValue: [String: AnyCodable]? {
        if case .dictionary(let v) = self { return v }
        return nil
    }
    
    // Hashable & Equatable for inner value map
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let l), .bool(let r)): return l == r
        case (.int(let l), .int(let r)): return l == r
        case (.double(let l), .double(let r)): return l == r
        case (.string(let l), .string(let r)): return l == r
        case (.date(let l), .date(let r)): return l == r
        case (.array(let l), .array(let r)): return l == r
        case (.dictionary(let l), .dictionary(let r)): return l == r
        default: return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null: hasher.combine(0)
        case .bool(let v): hasher.combine(v)
        case .int(let v): hasher.combine(v)
        case .double(let v): hasher.combine(v)
        case .string(let v): hasher.combine(v)
        case .date(let v): hasher.combine(v)
        case .array(let v): hasher.combine(v)
        case .dictionary(let v): hasher.combine(v)
        }
    }
}
