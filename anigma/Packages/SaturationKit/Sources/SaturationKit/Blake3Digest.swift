import Foundation
import AnigmaPrimitives

public typealias Blake3DigestError = BLAKE3DigestError

public enum Blake3Digest {
  public static let digestByteCount = BLAKE3Digest.digestByteCount
  public static let chunkByteCount = BLAKE3Digest.chunkByteCount

  public static func digest(_ input: Data) -> [UInt8] {
    BLAKE3Digest.digest(input)
  }

  public static func digest(_ input: [UInt8]) -> [UInt8] {
    BLAKE3Digest.digest(input)
  }

  public static func digestHex(_ input: Data) -> String {
    BLAKE3Digest.digestHex(input)
  }

  public static func digestHex(_ input: [UInt8]) -> String {
    BLAKE3Digest.digestHex(input)
  }

  public static func digest(_ input: Data, outputByteCount: Int) throws -> [UInt8] {
    try BLAKE3Digest.digest(input, outputByteCount: outputByteCount)
  }

  public static func digest(_ input: [UInt8], outputByteCount: Int) throws -> [UInt8] {
    try BLAKE3Digest.digest(input, outputByteCount: outputByteCount)
  }

  public static func keyedDigest(_ input: Data, key: [UInt8]) throws -> [UInt8] {
    try BLAKE3Digest.keyedDigest(input, key: key)
  }

  public static func keyedDigest(_ input: [UInt8], key: [UInt8]) throws -> [UInt8] {
    try BLAKE3Digest.keyedDigest(input, key: key)
  }

  public static func keyedDigest(_ input: Data, key: [UInt8], outputByteCount: Int) throws -> [UInt8] {
    try BLAKE3Digest.keyedDigest(input, key: key, outputByteCount: outputByteCount)
  }

  public static func keyedDigest(_ input: [UInt8], key: [UInt8], outputByteCount: Int) throws -> [UInt8] {
    try BLAKE3Digest.keyedDigest(input, key: key, outputByteCount: outputByteCount)
  }

  public static func deriveKeyDigest(_ input: Data, context: String) -> [UInt8] {
    BLAKE3Digest.deriveKeyDigest(input, context: context)
  }

  public static func deriveKeyDigest(_ input: [UInt8], context: String) -> [UInt8] {
    BLAKE3Digest.deriveKeyDigest(input, context: context)
  }

  public static func deriveKeyDigest(_ input: Data, context: String, outputByteCount: Int) throws -> [UInt8] {
    try BLAKE3Digest.deriveKeyDigest(input, context: context, outputByteCount: outputByteCount)
  }

  public static func deriveKeyDigest(_ input: [UInt8], context: String, outputByteCount: Int) throws -> [UInt8]
  {
    try BLAKE3Digest.deriveKeyDigest(input, context: context, outputByteCount: outputByteCount)
  }

  public static func chunkChainingValue(chunkBytes: [UInt8], chunkCounter: UInt64 = 0) throws -> [UInt32]
  {
    try BLAKE3Digest.chunkChainingValue(chunkBytes: chunkBytes, chunkCounter: chunkCounter)
  }
}
