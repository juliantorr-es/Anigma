//
//  DatabaseParameter+Extensions.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

// Error type for JSON encoding failures
public enum DatabaseParameterEncodingError: Error {
    case invalidUTF8
}

// Generic JSON encoding helper for any Codable type
@inline(__always)
public func dbpJSON<T: Codable>(_ value: T) throws -> DatabaseParameter {
    let data = try JSONEncoder().encode(value)
    guard let json = String(data: data, encoding: .utf8) else {
        throw DatabaseParameterEncodingError.invalidUTF8
    }
    return .text(json)
}

// Legacy function for string arrays
@inline(__always)
public func dbpJSON(_ strings: [String]) throws -> DatabaseParameter {
    let data = try JSONEncoder().encode(strings)
    guard let json = String(data: data, encoding: .utf8) else {
        throw DatabaseParameterEncodingError.invalidUTF8
    }
    return .text(json)
}

// Parameter conversion functions - unique signatures
@inline(__always)
public func dbp(_ v: String?) -> DatabaseParameter { v.map { .text($0) } ?? .null }

@inline(__always)
public func dbp(_ v: Int?) -> DatabaseParameter { v.map { .int($0) } ?? .null }

@inline(__always)
public func dbp(_ v: Double?) -> DatabaseParameter { v.map { .double($0) } ?? .null }

@inline(__always)
public func dbpTime(_ v: TimeInterval?) -> DatabaseParameter { v.map { .double($0) } ?? .null }

@inline(__always)
public func dbp(_ v: String) -> DatabaseParameter { .text(v) }

@inline(__always)
public func dbp(_ v: Substring) -> DatabaseParameter { .text(String(v)) }

@inline(__always)
public func dbp(_ v: Int) -> DatabaseParameter { .int(v) }

@inline(__always)
public func dbp(_ v: Int64) -> DatabaseParameter { .int(Int(v)) }

@inline(__always)
public func dbp(_ v: Double) -> DatabaseParameter { .double(v) }

@inline(__always)
public func dbp(_ v: Data) -> DatabaseParameter { .blob(v) }

@inline(__always)
public func dbp(_ v: Date) -> DatabaseParameter { .date(v) }

@inline(__always)
public func dbp(_ v: Date?) -> DatabaseParameter { v.map { .date($0) } ?? .null }
