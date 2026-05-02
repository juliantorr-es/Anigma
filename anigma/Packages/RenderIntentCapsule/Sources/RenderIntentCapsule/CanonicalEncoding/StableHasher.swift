import CryptoKit
import Foundation

/// Incremental SHA-256 hasher for stable, deterministic hash generation.
/// Uses CryptoKit's SHA-256 implementation with proper canonical encoding.
public struct StableHasher: Sendable {
    private var context: SHA256
    private var data = Data()
    
    /// Create a new StableHasher.
    public init() {
        self.context = SHA256()
    }
    
    /// Update the hash with raw bytes.
    public mutating func update(with bytes: Data) {
        context.update(data: bytes)
        data.append(bytes)
    }
    
    /// Update the hash with a string (UTF-8 encoded, NFC normalized).
    public mutating func update(with string: String) {
        // NFC normalize for Unicode determinism
        let normalized = string.precomposedStringWithCanonicalMapping
        if let utf8Data = normalized.data(using: .utf8) {
            update(with: utf8Data)
        } else {
            // Fallback: encode as UTF-8 with replacement character
            let utf8Bytes = Array(normalized.utf8)
            update(with: Data(utf8Bytes))
        }
    }
    
    /// Update the hash with an integer in big-endian format.
    public mutating func update<T: FixedWidthInteger>(with integer: T) {
        var bigEndian = integer.bigEndian
        withUnsafeBytes(of: &bigEndian) { bytes in
            update(with: Data(bytes))
        }
    }
    
    /// Update the hash with a floating-point value (normalized).
    public mutating func update<T: BinaryFloatingPoint>(with float: T) {
        let normalized = Bytes.normalizeFloat(float)
        var copy = normalized
        withUnsafeBytes(of: &copy) { bytes in
            update(with: Data(bytes))
        }
    }
    
    /// Update the hash with a boolean value.
    public mutating func update(with bool: Bool) {
        let byte: UInt8 = bool ? 1 : 0
        update(with: Data([byte]))
    }
    
    /// Update the hash with an IntentID.
    public mutating func update(with intentID: IntentID) {
        update(with: intentID.bytes)
    }
    
    /// Update the hash with optional data.
    public mutating func update<T>(with optional: T?, using updater: (inout StableHasher, T) -> Void) {
        update(with: optional != nil)
        if let value = optional {
            updater(&self, value)
        }
    }
    
    /// Update the hash with an array of items.
    public mutating func update<T>(with array: [T], using updater: (inout StableHasher, T) -> Void) {
        update(with: UInt64(array.count))
        for item in array {
            updater(&self, item)
        }
    }
    
    /// Update the hash with a dictionary of key-value pairs.
    public mutating func update<K, V>(
        with dictionary: [K: V],
        using keyUpdater: (inout StableHasher, K) -> Void,
        valueUpdater: (inout StableHasher, V) -> Void
    ) where K: Comparable {
        // Sort keys for deterministic ordering
        let sortedKeys = dictionary.keys.sorted()
        update(with: UInt64(sortedKeys.count))
        
        for key in sortedKeys {
            keyUpdater(&self, key)
            if let value = dictionary[key] {
                valueUpdater(&self, value)
            }
        }
    }
    
    /// Finalize the hash and return the IntentID.
    public mutating func finalize() -> IntentID {
        let digest = context.finalize()
        
        // SHA-256 produces 32 bytes, we need 16 bytes for IntentID
        // Use first 16 bytes of the digest
        let digestData = Data(digest)
        let highBytes = digestData.prefix(8)
        let lowBytes = digestData.dropFirst(8).prefix(8)
        
        let high: UInt64 = Bytes.bigEndianFromData(Data(highBytes), at: 0)
        let low: UInt64 = Bytes.bigEndianFromData(Data(lowBytes), at: 0)
        
        return IntentID(high: high, low: low)
    }
    
    /// Reset the hasher to its initial state.
    public mutating func reset() {
        context = SHA256()
        data.removeAll(keepingCapacity: true)
    }
    
    /// Get the raw data that has been hashed so far.
    public var hashedData: Data {
        data
    }
}

// MARK: - Convenience Methods

extension StableHasher {
    /// Create an IntentID from a single string.
    public static func hash(_ string: String) -> IntentID {
        var hasher = StableHasher()
        hasher.update(with: string)
        return hasher.finalize()
    }
    
    /// Create an IntentID from raw bytes.
    public static func hash(_ data: Data) -> IntentID {
        var hasher = StableHasher()
        hasher.update(with: data)
        return hasher.finalize()
    }
    
    /// Create an IntentID from multiple values using a closure.
    public static func hash(using block: (inout StableHasher) -> Void) -> IntentID {
        var hasher = StableHasher()
        block(&hasher)
        return hasher.finalize()
    }
}



// MARK: - String Extensions for NFC Normalization

extension String {
    /// Returns the string with canonical (NFC) Unicode normalization applied.
    var precomposedStringWithCanonicalMapping: String {
        // Use Foundation's precomposedStringWithCanonicalMapping
        // This ensures consistent Unicode representation
        (self as NSString).precomposedStringWithCanonicalMapping
    }
}

// MARK: - Hashable Conformance Helper

/// Protocol for types that can provide a stable hash via StableHasher.
public protocol StableHashable {
    /// Update the hasher with this value's canonical representation.
    func updateHasher(_ hasher: inout StableHasher)
}

extension StableHashable {
    /// Generate a stable IntentID for this value.
    public var stableHash: IntentID {
        StableHasher.hash { hasher in
            updateHasher(&hasher)
        }
    }
}

// MARK: - Common Type Conformances

extension String: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: self)
    }
}

extension Int: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: Int64(self))
    }
}

extension Int64: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: self)
    }
}

extension UInt64: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: self)
    }
}

extension Double: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: self)
    }
}

extension Float: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: self)
    }
}

extension Bool: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: self)
    }
}

extension IntentID: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: self)
    }
}

extension Array: StableHashable where Element: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: self) { hasher, element in
            element.updateHasher(&hasher)
        }
    }
}

extension Dictionary: StableHashable where Key: StableHashable & Comparable, Value: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        hasher.update(with: self,
                     using: { $1.updateHasher(&$0) },
                     valueUpdater: { $1.updateHasher(&$0) })
    }
}