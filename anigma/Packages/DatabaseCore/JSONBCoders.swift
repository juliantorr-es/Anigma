//
//  JSONBCoders.swift
//  DatabaseCore
//
//  Type-safe coders for PostgreSQL JSONB columns.
//
//  See td-fbcd6c: Create typed decoders for JSONB columns
//

import Foundation
import AnigmaPrimitives

public protocol JSONBValue: Codable, Sendable {
    func toDatabaseValue() -> DatabaseValue
    static func fromDatabaseValue(_ value: DatabaseValue) throws -> Self
}

public struct JSONB<T: Codable & Sendable>: Codable, Sendable, JSONBValue {
    public let value: T
    
    public init(_ value: T) { self.value = value }
    
    public func toDatabaseValue() -> DatabaseValue {
        do {
            let data = try JSONEncoder().encode(value)
            return .blob(data)
        } catch {
            return .null
        }
    }
    
    public static func fromDatabaseValue(_ value: DatabaseValue) throws -> JSONB<T> {
        switch value {
        case let .blob(data):
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return JSONB(decoded)
        case let .text(string):
            guard let data = string.data(using: .utf8) else { throw JSONBError.invalidString }
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return JSONB(decoded)
        default:
            throw JSONBError.invalidDatabaseValue
        }
    }
}

public enum JSONBError: Error, CustomStringConvertible {
    case invalidString
    case invalidDatabaseValue
    case typeMismatch
    
    public var description: String {
        switch self {
        case .invalidString: return "Invalid JSONB string"
        case .invalidDatabaseValue: return "Invalid DatabaseValue for JSONB"
        case .typeMismatch: return "JSONB type mismatch"
        }
    }
}

public struct JSONBDecoder: Sendable {
    public static let shared = JSONBDecoder()
    
    public func decode<T: Decodable & Sendable>(_ type: T.Type, from value: DatabaseValue) throws -> T {
        switch value {
        case let .blob(data): return try JSONDecoder().decode(T.self, from: data)
        case let .text(string):
            guard let data = string.data(using: .utf8) else { throw JSONBError.invalidString }
            return try JSONDecoder().decode(T.self, from: data)
        default: throw JSONBError.invalidDatabaseValue
        }
    }
}

public struct JSONBEncoder: Sendable {
    public static let shared = JSONBEncoder()
    
    public func encode<T: Encodable & Sendable>(_ value: T) -> DatabaseValue {
        do {
            let data = try JSONEncoder().encode(value)
            return .blob(data)
        } catch {
            return .null
        }
    }
}

public extension DatabaseRow {
    func jsonb<T: Decodable & Sendable>(for column: String) throws -> T {
        guard let value = self[column] else { throw JSONBError.invalidDatabaseValue }
        return try JSONBDecoder.shared.decode(T.self, from: value)
    }
    
    func jsonbIfPresent<T: Decodable & Sendable>(for column: String) throws -> T? {
        guard let value = self[column] else { return nil }
        return try JSONBDecoder.shared.decode(T.self, from: value)
    }
}

public typealias JSONBStringArray = [String]
public typealias JSONBIntArray = [Int]
public typealias JSONBDoubleArray = [Double]
public typealias JSONBObject = [String: AnyCodable]
public typealias JSONBVector = [Float]
