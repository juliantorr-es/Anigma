import Foundation

/// Safe byte operations for canonical encoding with proper alignment handling.
/// Uses `memcpy` for safe unaligned reads/writes instead of `load(as:)`.
public enum Bytes {
    /// Copy bytes from source to destination using memcpy for safe unaligned access.
    @inlinable
    public static func copy<T>(_ value: T, to pointer: UnsafeMutableRawPointer) {
        withUnsafeBytes(of: value) { sourceBytes in
            _ = memcpy(pointer, sourceBytes.baseAddress!, MemoryLayout<T>.size)
        }
    }
    
    /// Load bytes from pointer using memcpy for safe unaligned access.
    @inlinable
    public static func load<T>(from pointer: UnsafeRawPointer, as type: T.Type) -> T {
        var value: T = unsafeBitCast((), to: T.self) // Zero-initialized
        memcpy(&value, pointer, MemoryLayout<T>.size)
        return value
    }
    
    /// Load bytes from Data at offset using memcpy for safe unaligned access.
    @inlinable
    public static func load<T>(from data: Data, at offset: Int, as type: T.Type) -> T {
        precondition(offset + MemoryLayout<T>.size <= data.count, "Insufficient data")
        return data.withUnsafeBytes { buffer in
            load(from: buffer.baseAddress!.advanced(by: offset), as: type)
        }
    }
    
    /// Store bytes to Data at offset using memcpy for safe unaligned access.
    @inlinable
    public static func store<T>(_ value: T, to data: inout Data, at offset: Int) {
        precondition(offset + MemoryLayout<T>.size <= data.count, "Insufficient capacity")
        data.withUnsafeMutableBytes { buffer in
            copy(value, to: buffer.baseAddress!.advanced(by: offset))
        }
    }
    
    /// Convert integer to big-endian bytes.
    @inlinable
    public static func toBigEndian<T: FixedWidthInteger>(_ value: T) -> T {
        value.bigEndian
    }
    
    /// Convert integer from big-endian bytes.
    @inlinable
    public static func fromBigEndian<T: FixedWidthInteger>(_ value: T) -> T {
        T(bigEndian: value)
    }
    
    /// Normalize floating-point value for canonical encoding.
    /// - Converts -0.0 to +0.0
    /// - Uses canonical NaN representation
    /// - Note: Colors must be linear sRGB floats (caller's responsibility)
    @inlinable
    public static func normalizeFloat<T: BinaryFloatingPoint>(_ value: T) -> T {
        // Convert -0.0 to +0.0
        if value == -0.0 {
            return 0.0
        }
        
        // For NaN, use a canonical representation
        // This ensures all NaNs encode to the same bytes
        if value.isNaN {
            // Use quiet NaN with zero payload
            // For simplicity, use the platform's default NaN
            // This is acceptable because we're hashing the bytes, not the bit pattern
            return T.nan
        }
        
        return value
    }
    
    /// Create Data from integer in big-endian format.
    @inlinable
    public static func dataFromBigEndian<T: FixedWidthInteger>(_ value: T) -> Data {
        var bigEndianValue = toBigEndian(value)
        return withUnsafeBytes(of: &bigEndianValue) { Data($0) }
    }
    
    /// Read integer from Data in big-endian format.
    @inlinable
    public static func bigEndianFromData<T: FixedWidthInteger>(_ data: Data, at offset: Int) -> T {
        let rawValue: T = load(from: data, at: offset, as: T.self)
        return fromBigEndian(rawValue)
    }
    
    /// Append integer in big-endian format to Data.
    @inlinable
    public static func appendBigEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        let bytes = dataFromBigEndian(value)
        data.append(bytes)
    }
    
    /// Append floating-point value with normalization.
    @inlinable
    public static func appendNormalizedFloat<T: BinaryFloatingPoint>(_ value: T, to data: inout Data) {
        let normalized = normalizeFloat(value)
        var copy = normalized
        data.append(Data(bytes: &copy, count: MemoryLayout<T>.size))
    }
    
    /// Read normalized floating-point value from Data.
    @inlinable
    public static func readNormalizedFloat<T: BinaryFloatingPoint>(from data: Data, at offset: Int) -> T {
        let value: T = load(from: data, at: offset, as: T.self)
        // Note: Normalization is applied during encoding, not decoding
        // The decoded value should match what was encoded
        return value
    }
}

// MARK: - Data Extensions

extension Data {
    /// Append integer in big-endian format.
    @inlinable
    public mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        Bytes.appendBigEndian(value, to: &self)
    }
    
    /// Append floating-point value with normalization.
    @inlinable
    public mutating func appendNormalizedFloat<T: BinaryFloatingPoint>(_ value: T) {
        Bytes.appendNormalizedFloat(value, to: &self)
    }
    
    /// Read integer in big-endian format.
    @inlinable
    public func readBigEndian<T: FixedWidthInteger>(at offset: Int) -> T {
        Bytes.bigEndianFromData(self, at: offset)
    }
    
    /// Read normalized floating-point value.
    @inlinable
    public func readNormalizedFloat<T: BinaryFloatingPoint>(at offset: Int) -> T {
        Bytes.readNormalizedFloat(from: self, at: offset)
    }
}