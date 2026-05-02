import Foundation

/// Protocol for types that can be encoded to a canonical binary format.
/// Canonical formats are stable, deterministic, and suitable for receipts.
public protocol CanonicalEncodable {
    /// Encode to canonical binary data.
    /// - Returns: Canonical binary representation
    /// - Throws: If encoding fails
    func encodeCanonical() throws -> Data
    
    /// Decode from canonical binary data.
    /// - Parameter data: Canonical binary representation
    /// - Throws: If decoding fails
    static func decodeCanonical(_ data: Data) throws -> Self
}

/// Protocol for capsules that produce canonical outputs.
public protocol CanonicalCapsule {
    /// The canonical output type.
    associatedtype CanonicalOutput: CanonicalEncodable
    
    /// Produce canonical output from the capsule's internal state.
    /// - Returns: Canonical output
    /// - Throws: If canonicalization fails
    func produceCanonicalOutput() throws -> CanonicalOutput
}

/// A canonical binary encoder that ensures deterministic output.
public struct CanonicalEncoder {
    private init() {}
    
    /// Encode a fixed-width integer in little-endian format.
    public static func encode<T: FixedWidthInteger>(_ value: T) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }
    
    /// Encode a floating-point number in IEEE 754 little-endian format.
    public static func encode<T: FloatingPoint>(_ value: T) -> Data where T: BinaryFloatingPoint {
        // Convert to a canonical representation (e.g., fixed-point for determinism)
        // For Tier 1 determinism, we might need to use integer arithmetic.
        // This is a placeholder that uses raw bytes (not deterministic across platforms).
        var copy = value
        return withUnsafeBytes(of: &copy) { Data($0) }
    }
    
    /// Encode a string as UTF-8 bytes with length prefix.
    public static func encode(_ string: String) -> Data {
        let utf8 = string.utf8
        var data = encode(UInt32(utf8.count))
        data.append(contentsOf: utf8)
        return data
    }
    
    /// Encode an array of canonical encodable items.
    public static func encode<T: CanonicalEncodable>(_ array: [T]) throws -> Data {
        var data = encode(UInt32(array.count))
        for item in array {
            data.append(try item.encodeCanonical())
        }
        return data
    }
    
    /// Encode a dictionary with canonical keys and values.
    public static func encode<K: CanonicalEncodable & Hashable, V: CanonicalEncodable>(_ dict: [K: V]) throws -> Data {
        // Sort keys for deterministic ordering
        let sortedKeys = dict.keys.sorted { a, b in
            let dataA = try! a.encodeCanonical()
            let dataB = try! b.encodeCanonical()
            return dataA.lexicographicallyPrecedes(dataB)
        }
        
        var data = encode(UInt32(dict.count))
        for key in sortedKeys {
            guard let value = dict[key] else { continue }
            data.append(try key.encodeCanonical())
            data.append(try value.encodeCanonical())
        }
        return data
    }
}

/// A canonical binary decoder.
public struct CanonicalDecoder {
    private var data: Data
    private var offset: Int = 0
    
    public init(_ data: Data) {
        self.data = data
    }
    
    /// Decode a fixed-width integer.
    public mutating func decode<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let size = MemoryLayout<T>.size
        guard offset + size <= data.count else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Insufficient data")
            )
        }
        
        let value = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: T.self)
        }
        offset += size
        return T(littleEndian: value)
    }
    
    /// Decode a floating-point number.
    public mutating func decode<T: FloatingPoint>(_ type: T.Type) throws -> T where T: BinaryFloatingPoint {
        let size = MemoryLayout<T>.size
        guard offset + size <= data.count else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Insufficient data")
            )
        }
        
        let value = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: T.self)
        }
        offset += size
        return value
    }
    
    /// Decode a string.
    public mutating func decodeString() throws -> String {
        let length = try decode(UInt32.self)
        guard offset + Int(length) <= data.count else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "String length exceeds available data")
            )
        }
        
        let stringData = data[offset..<offset + Int(length)]
        guard let string = String(data: stringData, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Invalid UTF-8 data")
            )
        }
        
        offset += Int(length)
        return string
    }
    
    /// Decode an array of canonical encodable items.
    public mutating func decodeArray<T: CanonicalEncodable>(_ elementType: T.Type) throws -> [T] {
        let count = try decode(UInt32.self)
        var array: [T] = []
        array.reserveCapacity(Int(count))
        
        for _ in 0..<count {
            // TRACKED STUB: Array decoding requires self-delimiting elements or length prefix per element
            // Current implementation throws NotImplementedError with clear context
            // Production fix: Either add per-element length prefix or modify element encoding to be self-delimiting
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "Array element decoding not implemented (Tier 1 stub). " +
                        "Requires either self-delimiting elements or per-element length prefix. " +
                        "See CanonicalEncoder.encode<T: CanonicalEncodable>(_ array:)"
                )
            )
        }
        
        return array
    }
    
    /// Get the remaining data.
    public var remainingData: Data {
        data[offset...]
    }
}

// MARK: - Common Canonical Types

/// Canonical representation of a 2D point.
public struct CanonicalPoint: CanonicalEncodable, Hashable {
    public let x: Double
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    public func encodeCanonical() throws -> Data {
        var data = CanonicalEncoder.encode(x)
        data.append(CanonicalEncoder.encode(y))
        return data
    }
    
    public static func decodeCanonical(_ data: Data) throws -> Self {
        var decoder = CanonicalDecoder(data)
        let x = try decoder.decode(Double.self)
        let y = try decoder.decode(Double.self)
        return CanonicalPoint(x: x, y: y)
    }
}

/// Canonical representation of a path (series of points).
public struct CanonicalPath: CanonicalEncodable {
    public let points: [CanonicalPoint]
    
    public init(points: [CanonicalPoint]) {
        self.points = points
    }
    
    public func encodeCanonical() throws -> Data {
        var data = CanonicalEncoder.encode(UInt32(points.count))
        for point in points {
            data.append(try point.encodeCanonical())
        }
        return data
    }
    
    public static func decodeCanonical(_ data: Data) throws -> Self {
        var decoder = CanonicalDecoder(data)
        let count = try decoder.decode(UInt32.self)
        var points: [CanonicalPoint] = []
        points.reserveCapacity(Int(count))
        
        for _ in 0..<count {
            // TRACKED STUB: Path decoding blocked by array element decoding limitation
            // Cannot deserialize points without size information for each point
            // Production fix: Modify CanonicalDecoder to track element boundaries
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "Path element decoding not fully implemented (Tier 1 stub). " +
                        "Blocked by CanonicalDecoder.decodeArray limitation. " +
                        "Requires per-element offset tracking or self-delimiting point encoding."
                )
            )
        }
        
        return CanonicalPath(points: points)
    }
}

// MARK: - Error Types

public enum CanonicalEncodingError: Error {
    case unsupportedType
    case determinismViolation
    case sizeExceeded
}