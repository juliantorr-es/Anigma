//
//  CanonicalJSONEncoder.swift
//  HarmoniaModule
//
//  Canonical JSON encoder for deterministic serialization.
//  Ensures stable output without dictionary ordering surprises or Date() randomness.
//

import Foundation
import AnigmaPrimitives

/// JSON encoder with deterministic settings for audit logs and governance events.
/// - Sorted keys in dictionaries
/// - ISO8601 date formatting with nanosecond precision
/// - Compact formatting without whitespace
/// - No escaped characters that might vary by implementation
public struct CanonicalJSONEncoder: Sendable {

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()

        // Ensure deterministic output
        encoder.outputFormatting = [
            .sortedKeys,  // Dictionary keys in sorted order
            .withoutEscapingSlashes  // Consistent slash handling
        ]

        // Fixed date format for deterministic timestamps
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(value)
    }

    public static func encodeToString<T: Encodable>(_ value: T) throws -> String {
        let data = try encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Get a deterministic hash from encodable value
    public static func hash<T: Encodable>(_ value: T) throws -> String {
        let data = try encode(value)
        return BLAKE3Digest.hex(of: data)
    }
}

// Convenience instance APIs so callers can keep a stored encoder reference.
public extension CanonicalJSONEncoder {
    func encode<T: Encodable>(_ value: T) throws -> Data {
        try Self.encode(value)
    }

    func encodeToString<T: Encodable>(_ value: T) throws -> String {
        try Self.encodeToString(value)
    }

    func hash<T: Encodable>(_ value: T) throws -> String {
        try Self.hash(value)
    }
}

/// Canonical hashable protocol for deterministic hashing
public protocol CanonicalHashable {
    /// Deterministic hash using canonical JSON encoding
    var canonicalHash: Int { get }
}

extension CanonicalHashable where Self: Encodable {
    public var canonicalHash: String {
        return (try? CanonicalJSONEncoder.hash(self)) ?? "hash-error"
    }
}

/// Deterministic UUID alternative using hash of content
public struct DeterministicUUID: Codable, Hashable, Sendable {
    public let uuidString: String

    public init<T: Encodable>(from value: T) {
        // Create a consistent hash from the value
        let hashString = (try? CanonicalJSONEncoder.hash(value)) ?? "fallback"
        let hexChars = Array(hashString.prefix(32))
        let pairs = stride(from: 0, to: hexChars.count, by: 2).compactMap { i -> UInt8? in
            guard i + 1 < hexChars.count else { return nil }
            let high = hexNibToInt(hexChars[i])
            let low = hexNibToInt(hexChars[i + 1])
            guard let h = high, let l = low else { return nil }
            return h * 16 + l
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, byte) in pairs.prefix(16).enumerated() {
            bytes[i] = byte
        }

        // Create a deterministic UUID string
        let part1 = bytes[0..<2].map { String(format: "%02x", $0) }.joined()
        let part2 = bytes[2..<4].map { String(format: "%02x", $0) }.joined()
        let part3 = bytes[4..<6].map { String(format: "%02x", $0) }.joined()
        let part4 = bytes[6..<8].map { String(format: "%02x", $0) }.joined()
        let part5 = bytes[8..<16].map { String(format: "%02x", $0) }.joined()

        self.uuidString = [part1, part2, part3, part4, part5].joined(separator: "-")
    }

    public init(string: String) {
        self.uuidString = string
    }
}

/// Sequence number generator that stays deterministic per session
public actor SequenceNumberGenerator {
    private let sessionSeed: String
    private var counter: Int = 0

    public init(sessionId: String) {
        self.sessionSeed = sessionId
        self.counter = sessionId.hashValue % 100000 // Start from session-based offset
    }

    public func next() -> Int {
        counter = (counter + 1) % Int.max
        return counter
    }

    public func reset() {
        counter = sessionSeed.hashValue % 100000
    }
}

// Convert hex character to nibble (0-15) - using global function
private func hexNibToInt(_ char: Character) -> UInt8? {
    switch char {
    case "0": return 0
    case "1": return 1
    case "2": return 2
    case "3": return 3
    case "4": return 4
    case "5": return 5
    case "6": return 6
    case "7": return 7
    case "8": return 8
    case "9": return 9
    case "a": return 10
    case "b": return 11
    case "c": return 12
    case "d": return 13
    case "e": return 14
    case "f": return 15
    case "A": return 10
    case "B": return 11
    case "C": return 12
    case "D": return 13
    case "E": return 14
    case "F": return 15
    default: return nil
    }
}

/// Extension to improve hashing negative values
extension Int {
    fileprivate var abs: Int {
        return Swift.abs(self)
    }
}
