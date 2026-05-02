//
//  NativeWire.swift
//  ContractsCore
//
//  Binary struct layer for hardware-saturated, native boundaries.
//  Implements the "Serialization Wall" for hot-path I/O.
//

import Foundation

/// Unique identifiers for native payload kinds
public enum NativeRecordKind: UInt16, Sendable {
  case saturatedSearchRequest = 0x0001
  case saturatedSearchResponse = 0x0002
  case mlWorkerEmbedRequest = 0x0003
  case mlWorkerEmbedResponse = 0x0004
  case mathOCRRequest = 0x0100
  case mathOCRResponse = 0x0101
  case tableExtractionRequest = 0x0102
  case tableExtractionResponse = 0x0103
  case citationExtractionRequest = 0x0104
  case citationExtractionResponse = 0x0105
  // Reserve space for other native hot-path payloads
  case unknown = 0xFFFF
}

/// A strictly defined, little-endian binary header for all native boundary records.
/// Provides determinism, easy mmap boundaries, and protection against memory sludge.
public struct RecordHeader: Sendable, Equatable {
  /// Magic bytes for identifying the record type/system: "ANIG" (0x474E4941)
  public static let magicValue: UInt32 = 0x474E_4941
  public static let serializedByteCount =
    MemoryLayout<UInt32>.size + MemoryLayout<UInt16>.size + MemoryLayout<UInt16>.size +
    MemoryLayout<UInt32>.size + MemoryLayout<UInt32>.size + MemoryLayout<UInt32>.size

  public var magic: UInt32
  public var version: UInt16
  public var kind: UInt16
  public var byteLength: UInt32
  public var flags: UInt32
  public var checksum: UInt32

  public init(
    version: UInt16 = 1,
    kind: NativeRecordKind,
    byteLength: UInt32,
    flags: UInt32 = 0,
    checksum: UInt32 = 0
  ) {
    self.magic = Self.magicValue
    self.version = version
    self.kind = kind.rawValue
    self.byteLength = byteLength
    self.flags = flags
    self.checksum = checksum
  }

  public func serialize(to data: inout Data) {
    NativeWire.append(magic, to: &data)
    NativeWire.append(version, to: &data)
    NativeWire.append(kind, to: &data)
    NativeWire.append(byteLength, to: &data)
    NativeWire.append(flags, to: &data)
    NativeWire.append(checksum, to: &data)
  }

  public func serializedData() -> Data {
    var data = Data()
    data.reserveCapacity(Self.serializedByteCount)
    serialize(to: &data)
    return data
  }

  public init(serializedData: Data) throws {
    if serializedData.count < Self.serializedByteCount {
      throw NativeWireError.corruptedHeader
    }

    self.magic = try NativeWire.read(from: serializedData, at: 0)
    self.version = try NativeWire.read(from: serializedData, at: 4)
    self.kind = try NativeWire.read(from: serializedData, at: 6)
    self.byteLength = try NativeWire.read(from: serializedData, at: 8)
    self.flags = try NativeWire.read(from: serializedData, at: 12)
    self.checksum = try NativeWire.read(from: serializedData, at: 16)

    if magic != Self.magicValue {
      throw NativeWireError.corruptedHeader
    }
  }
}

/// Represents a validated, zero-copy (where possible) view of a native record.
public struct BinaryEnvelope: Sendable {
  public let header: RecordHeader
  public let payload: Data  // Can be backed by a mapped memory span

  public init(header: RecordHeader, payload: Data) {
    self.header = header
    self.payload = payload
  }

  /// Returns the complete binary representation (Header + Payload)
  public func serialize() -> Data {
    var data = Data()
    data.reserveCapacity(RecordHeader.serializedByteCount + payload.count)
    header.serialize(to: &data)
    data.append(payload)
    return data
  }
}

/// Protocol for the "Two-Representation" system.
/// Bridges Swift domain types to Native hot-path layouts.
public protocol NativeBoundaryContract: SaturatedContractSpec {
  /// The canonical native record kind for this contract's hot path.
  static var nativeRecordKind: NativeRecordKind { get }

  /// Packs the domain input into a binary envelope for the native boundary.
  static func packNative(input: ArtifactEnvelope<Input>) throws -> BinaryEnvelope

  /// Unpacks a binary envelope from the native boundary into the domain output.
  static func unpackNative(envelope: BinaryEnvelope) throws -> ArtifactEnvelope<Output>
}

// MARK: - Packing Helpers

public enum NativeWire {
  /// Writes a value to Data in little-endian format.
  public static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var le = value.littleEndian
    withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
  }

  /// Reads a little-endian integer from Data at a fixed byte offset.
  public static func read<T: FixedWidthInteger>(
    from data: Data,
    at offset: Int,
    as _: T.Type = T.self
  ) throws -> T {
    let width = MemoryLayout<T>.size
    let end = offset + width
    if offset < 0 || end > data.count {
      throw NativeWireError.corruptedHeader
    }

    var raw: T = 0
    _ = withUnsafeMutableBytes(of: &raw) {
      data.copyBytes(to: $0, from: offset..<end)
    }
    return T(littleEndian: raw)
  }

  /// Writes a Float32 to Data in little-endian bit pattern.
  public static func append(_ value: Float32, to data: inout Data) {
    var le = value.bitPattern.littleEndian
    withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
  }

  /// Writes a UUID to Data as a raw 16-byte uuid_t.
  public static func append(_ value: UUID, to data: inout Data) {
    var uuid = value.uuid
    withUnsafeBytes(of: &uuid) { data.append(contentsOf: $0) }
  }

  /// Writes a null-terminated UTF-8 string to Data.
  public static func append(_ value: String, to data: inout Data) throws {
    guard let stringData = value.data(using: .utf8) else {
      throw NativeWireError.invalidEncoding
    }
    data.append(stringData)
    data.append(0)
  }
}

public enum NativeWireError: Error, Sendable {
  case invalidEncoding
  case corruptedHeader
  case lengthMismatch
  case kindMismatch
}
