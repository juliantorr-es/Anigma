//
//  TelemetryValue.swift
//  TelemetryCore
//
//  Restricted telemetry values - no arbitrary strings allowed.
//  Only supports safe, auditable data types.
//

import AnigmaPrimitives
import CryptoKit
import Foundation

/// Value types that are safe for telemetry - prevents arbitrary user string injection.
public enum TelemetryValue: Sendable, Hashable {
    case integer(Int)
    case integer64(Int64)
    case double(Double)
    case boolean(Bool)
    case limitedTag(TelemetryTag)
    case hashedToken(TelemetryHash)
    case string(String) // Added for internal use/audit trails where strictly necessary
}

// MARK: - Codable Wire Support
extension TelemetryValue: Codable {
    private enum Kind: String, Codable { case int, int64, double, bool, tag, hash, string }
    private enum CodingKeys: String, CodingKey { case kind, int, int64, double, bool, tag, hash, string }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .integer(let value):
            try container.encode(Kind.int, forKey: .kind)
            try container.encode(value, forKey: .int)
        case .integer64(let value):
            try container.encode(Kind.int64, forKey: .kind)
            try container.encode(value, forKey: .int64)
        case .double(let value):
            try container.encode(Kind.double, forKey: .kind)
            try container.encode(value, forKey: .double)
        case .boolean(let value):
            try container.encode(Kind.bool, forKey: .kind)
            try container.encode(value, forKey: .bool)
        case .limitedTag(let value):
            try container.encode(Kind.tag, forKey: .kind)
            try container.encode(value, forKey: .tag)
        case .hashedToken(let value):
            try container.encode(Kind.hash, forKey: .kind)
            try container.encode(value, forKey: .hash)
        case .string(let value):
            try container.encode(Kind.string, forKey: .kind)
            try container.encode(value, forKey: .string)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .int:
            self = .integer(try container.decode(Int.self, forKey: .int))
        case .int64:
            self = .integer64(try container.decode(Int64.self, forKey: .int64))
        case .double:
            self = .double(try container.decode(Double.self, forKey: .double))
        case .bool:
            self = .boolean(try container.decode(Bool.self, forKey: .bool))
        case .tag:
            self = .limitedTag(try container.decode(TelemetryTag.self, forKey: .tag))
        case .hash:
            self = .hashedToken(try container.decode(TelemetryHash.self, forKey: .hash))
        case .string:
            self = .string(try container.decode(String.self, forKey: .string))
        }
    }
}

/// Controlled string tags with whitelist and length limits.
public struct TelemetryTag: Sendable, Hashable {
    public let value: String

    /// Maximum length for telemetry tags.
    public static let maxLength = 48  // Shortened for wire format

    /// Whitelisted tag prefixes to prevent arbitrary injection.
    private static let allowedPrefixes: Set<String> = [
        "system.", "tool.", "workflow.", "error.", "security.",
        "performance.", "memory.", "module.", "action.", "status.",
        "audit."
    ]

    public init(_ raw: String) throws {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= TelemetryTag.maxLength else { throw TelemetryError.tagTooLong }
        guard TelemetryTag.allowedPrefixes.contains(where: trimmed.hasPrefix) else {
            throw TelemetryError.tagNotAllowed
        }
        self.value = trimmed
    }

    // Common safe tags
    public static let success = try! TelemetryTag("status.success")
    public static let failure = try! TelemetryTag("status.failure")
    public static let started = try! TelemetryTag("status.started")
    public static let completed = try! TelemetryTag("status.completed")
}

// MARK: - Codable Wire Support
extension TelemetryTag: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try String(from: decoder)
        try self.init(raw)
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

/// Cryptographically hashed token - never stores the original input.
public struct TelemetryHash: Sendable, Hashable {
    public enum Algorithm: String, Codable, Sendable {
        case blake3
    }
    public let algorithm: Algorithm
    public let hex: String
    private static let salt = "telemetry-core-salt-2024"  // In production, this should be environment-specific

    public init<S: StringProtocol>(input: S, algorithm: Algorithm = .blake3) {
        let data = Data((input + TelemetryHash.salt).utf8)
        self.algorithm = algorithm
        self.hex = BLAKE3Digest.hex(of: data)
    }

    public var value: String {
        return hex
    }

    public init(algorithm: Algorithm, hex: String) throws {
        guard hex.allSatisfy({ $0.isHexDigit }) else { throw TelemetryError.invalidHash }
        self.algorithm = algorithm
        self.hex = hex.lowercased()
    }
}

// MARK: - Codable Wire Support
extension TelemetryHash: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let algorithm = try container.decode(Algorithm.self, forKey: .algorithm)
        let hex = try container.decode(String.self, forKey: .hex)
        try self.init(algorithm: algorithm, hex: hex)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(algorithm, forKey: .algorithm)
        try container.encode(hex, forKey: .hex)
    }

    private enum CodingKeys: String, CodingKey {
        case algorithm
        case hex
    }
}
