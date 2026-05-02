import Foundation

/// A 128-bit identifier for render intents with proper alignment handling.
/// Uses big-endian byte order for canonical encoding.
public struct IntentID: Hashable, Equatable, Sendable {
    /// The high 64 bits of the ID.
    public let high: UInt64
    /// The low 64 bits of the ID.
    public let low: UInt64
    
    /// Create an IntentID from high and low 64-bit values.
    @inlinable
    public init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }
    

    
    /// Create an IntentID from raw bytes (16 bytes expected).
    /// - Parameter bytes: 16 bytes in big-endian order
    /// - Throws: If bytes count is not 16
    public init(bytes: Data) throws {
        guard bytes.count == 16 else {
            throw IntentIDError.invalidByteCount(bytes.count)
        }
        
        self.high = Bytes.bigEndianFromData(bytes, at: 0)
        self.low = Bytes.bigEndianFromData(bytes, at: 8)
    }
    
    /// Create a zero IntentID.
    @inlinable
    public static var zero: IntentID {
        IntentID(high: 0, low: 0)
    }
    
    /// Convert to raw bytes in big-endian order.
    @inlinable
    public var bytes: Data {
        var data = Data()
        data.appendBigEndian(high)
        data.appendBigEndian(low)
        return data
    }
    
    /// Convert to tuple of high and low 64-bit integers.
    @inlinable
    public var parts: (high: UInt64, low: UInt64) {
        (high, low)
    }
    
    /// String representation in hexadecimal format.
    public var hexString: String {
        String(format: "%016llX%016llX", high, low)
    }
    
    /// Short string representation (first 8 chars).
    public var shortHex: String {
        String(hexString.prefix(8))
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension IntentID: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt64) {
        self.init(high: 0, low: value)
    }
}

// MARK: - CustomStringConvertible

extension IntentID: CustomStringConvertible {
    public var description: String {
        "IntentID(\(shortHex))"
    }
}

// MARK: - Codable

extension IntentID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hexString = try container.decode(String.self)
        
        guard hexString.count == 32,
              let high = UInt64(hexString.prefix(16), radix: 16),
              let low = UInt64(hexString.suffix(16), radix: 16) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Invalid hex string for IntentID: \(hexString)")
            )
        }
        
        self.init(high: high, low: low)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}

// MARK: - Comparable

extension IntentID: Comparable {
    public static func < (lhs: IntentID, rhs: IntentID) -> Bool {
        if lhs.high != rhs.high {
            return lhs.high < rhs.high
        }
        return lhs.low < rhs.low
    }
}

// MARK: - UInt128 Type

/// 128-bit unsigned integer for IntentID calculations.
public struct UInt128: ExpressibleByIntegerLiteral, Comparable, Hashable {
    public let high: UInt64
    public let low: UInt64
    
    @inlinable
    public init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }
    
    @inlinable
    public init(integerLiteral value: UInt64) {
        self.init(high: 0, low: value)
    }
    
    @inlinable
    public init(_ value: UInt64) {
        self.init(high: 0, low: value)
    }
    
    @inlinable
    public static func == (lhs: UInt128, rhs: UInt128) -> Bool {
        lhs.high == rhs.high && lhs.low == rhs.low
    }
    
    @inlinable
    public static func < (lhs: UInt128, rhs: UInt128) -> Bool {
        if lhs.high != rhs.high {
            return lhs.high < rhs.high
        }
        return lhs.low < rhs.low
    }
    
    @inlinable
    public static func + (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let (low, carry) = lhs.low.addingReportingOverflow(rhs.low)
        let high = lhs.high &+ rhs.high &+ (carry ? 1 : 0)
        return UInt128(high: high, low: low)
    }
    
    @inlinable
    public static func & (lhs: UInt128, rhs: UInt128) -> UInt128 {
        UInt128(high: lhs.high & rhs.high, low: lhs.low & rhs.low)
    }
    
    @inlinable
    public static func | (lhs: UInt128, rhs: UInt128) -> UInt128 {
        UInt128(high: lhs.high | rhs.high, low: lhs.low | rhs.low)
    }
    
    @inlinable
    public static func ^ (lhs: UInt128, rhs: UInt128) -> UInt128 {
        UInt128(high: lhs.high ^ rhs.high, low: lhs.low ^ rhs.low)
    }
    
    @inlinable
    public static func << (lhs: UInt128, rhs: Int) -> UInt128 {
        guard rhs >= 0 && rhs < 128 else {
            return rhs < 0 ? lhs >> -rhs : UInt128(high: 0, low: 0)
        }
        
        if rhs == 0 {
            return lhs
        } else if rhs < 64 {
            let high = (lhs.high << rhs) | (lhs.low >> (64 - rhs))
            let low = lhs.low << rhs
            return UInt128(high: high, low: low)
        } else {
            let high = lhs.low << (rhs - 64)
            return UInt128(high: high, low: 0)
        }
    }
    
    @inlinable
    public static func >> (lhs: UInt128, rhs: Int) -> UInt128 {
        guard rhs >= 0 && rhs < 128 else {
            return rhs < 0 ? lhs << -rhs : UInt128(high: 0, low: 0)
        }
        
        if rhs == 0 {
            return lhs
        } else if rhs < 64 {
            let low = (lhs.low >> rhs) | (lhs.high << (64 - rhs))
            let high = lhs.high >> rhs
            return UInt128(high: high, low: low)
        } else {
            let low = lhs.high >> (rhs - 64)
            return UInt128(high: 0, low: low)
        }
    }
}

// MARK: - Errors

public enum IntentIDError: Error {
    case invalidByteCount(Int)
}

// MARK: - Foundation Extensions

extension IntentID {
    /// Create an IntentID from a UUID.
    public init(uuid: UUID) {
        let uuidBytes = withUnsafeBytes(of: uuid.uuid) { Data($0) }
        // UUID is already 16 bytes, but we need to ensure big-endian order
        self.high = Bytes.bigEndianFromData(uuidBytes, at: 0)
        self.low = Bytes.bigEndianFromData(uuidBytes, at: 8)
    }
    
    /// Convert to UUID.
    public var uuid: UUID {
        var bytes = bytes
        return bytes.withUnsafeBytes { buffer in
            UUID(uuid: buffer.load(as: uuid_t.self))
        }
    }
}