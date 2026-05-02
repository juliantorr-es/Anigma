import AnigmaNativeShims
import CapsuleCore
import Compression
import Foundation

public enum CompressionAlgorithm: Sendable, Hashable {
  case zstd
  case brotli
  case lz4

  fileprivate var frameworkAlgorithm: compression_algorithm {
    switch self {
    case .zstd:
      return COMPRESSION_LZFSE
    case .brotli:
      return COMPRESSION_ZLIB
    case .lz4:
      return COMPRESSION_LZ4
    }
  }
}

public enum CompressionMode: Sendable {
  case streaming
  case deterministic
  case optimized
}

public enum CompressionLevel: Sendable {
  case `default`
  case fast
  case best
}

public struct CompressionConfig: Sendable {
  public let algorithm: CompressionAlgorithm
  public let mode: CompressionMode
  public let level: CompressionLevel
  public let bufferPoolSize: Int
  public let determinismTier: UInt32

  public init(
    algorithm: CompressionAlgorithm,
    mode: CompressionMode,
    level: CompressionLevel,
    bufferPoolSize: Int = 16,
    determinismTier: UInt32 = 1
  ) {
    self.algorithm = algorithm
    self.mode = mode
    self.level = level
    self.bufferPoolSize = bufferPoolSize
    self.determinismTier = determinismTier
  }
}

extension CompressionConfig {
  public static func defaultConfiguration(for algorithm: CompressionAlgorithm) -> CompressionConfig
  {
    CompressionConfig(
      algorithm: algorithm,
      mode: .deterministic,
      level: .default,
      bufferPoolSize: 16,
      determinismTier: 1
    )
  }
}

public struct CompressionDictionaryConfig: Sendable {
  public let dictionarySize: Int
  public let minSampleSize: Int
  public let maxSampleSize: Int
  public let maxSamples: Int

  public init(
    dictionarySize: Int,
    minSampleSize: Int = 0,
    maxSampleSize: Int = 0,
    maxSamples: Int = 0
  ) {
    self.dictionarySize = dictionarySize
    self.minSampleSize = minSampleSize
    self.maxSampleSize = maxSampleSize
    self.maxSamples = maxSamples
  }
}

public enum CompressionCapsuleError: LocalizedError, Sendable {
  case unsupportedDictionaryTraining
  case invalidCompressedPayload
  case compressionFailed
  case decompressionFailed

  public var errorDescription: String? {
    switch self {
    case .unsupportedDictionaryTraining:
      return "Dictionary training is not supported on the Compression.framework pro path."
    case .invalidCompressedPayload:
      return "Compressed payload is missing the Anigma compression header."
    case .compressionFailed:
      return "Compression.framework failed to compress the payload."
    case .decompressionFailed:
      return "Compression.framework failed to decompress the payload."
    }
  }
}

public actor CompressionCapsule {
  private static let magic = [UInt8]("ANIGCMP1".utf8)
  private let config: CompressionConfig

  public init(config: CompressionConfig) throws {
    try Self.validate(config: config)
    self.config = config
  }

  public init(algorithm: CompressionAlgorithm) throws {
    try self.init(config: CompressionConfig.defaultConfiguration(for: algorithm))
  }

  public static func validate(config: CompressionConfig) throws {
    precondition(config.bufferPoolSize >= 0)
  }

  public func acquireBuffer(size: Int) throws -> CapsuleBuffer {
    CapsuleBuffer(callerAllocatedOutput: size)
  }

  public func releaseBuffer(_ buffer: consuming CapsuleBuffer) throws {
    buffer.markReleased()
  }

  public func estimateCompressedSize(inputSize: Int) throws -> Int {
    max(64, inputSize + 64)
  }

  public func compress(_ input: Data) throws -> Data {
    if input.isEmpty {
      return Self.makePayload(compressed: Data(), originalSize: 0)
    }

    return try input.withUnsafeBytes { inputBytes in
      guard let inputBase = inputBytes.bindMemory(to: UInt8.self).baseAddress else {
        return Self.makePayload(compressed: Data(), originalSize: 0)
      }

      var outputCapacity = max(64, input.count + input.count / 2 + 64)
      for _ in 0..<4 {
        var output = Data(count: outputCapacity)
        let encodedCount = output.withUnsafeMutableBytes { outputBytes in
          compression_encode_buffer(
            outputBytes.bindMemory(to: UInt8.self).baseAddress!,
            outputCapacity,
            inputBase,
            input.count,
            nil,
            config.algorithm.frameworkAlgorithm
          )
        }

        if encodedCount > 0 {
          output.removeSubrange(encodedCount..<output.count)
          return Self.makePayload(compressed: output, originalSize: input.count)
        }
        outputCapacity *= 2
      }

      throw CompressionCapsuleError.compressionFailed
    }
  }

  public func decompress(_ input: Data) throws -> Data {
    let payload = try Self.parsePayload(input)
    if payload.originalSize == 0 {
      return Data()
    }

    return try payload.compressed.withUnsafeBytes { inputBytes in
      guard let inputBase = inputBytes.bindMemory(to: UInt8.self).baseAddress else {
        throw CompressionCapsuleError.invalidCompressedPayload
      }

      var output = Data(count: payload.originalSize)
      let decodedCount = output.withUnsafeMutableBytes { outputBytes in
        compression_decode_buffer(
          outputBytes.bindMemory(to: UInt8.self).baseAddress!,
          payload.originalSize,
          inputBase,
          payload.compressed.count,
          nil,
          config.algorithm.frameworkAlgorithm
        )
      }

      guard decodedCount == payload.originalSize else {
        throw CompressionCapsuleError.decompressionFailed
      }
      return output
    }
  }

  public func beginCompressStream() throws -> CompressionStreamHandle {
    CompressionStreamHandle(capsule: self, mode: .compress)
  }

  public func beginDecompressStream() throws -> CompressionStreamHandle {
    CompressionStreamHandle(capsule: self, mode: .decompress)
  }

  public func trainDictionary(
    config: CompressionDictionaryConfig,
    samples: [Data]
  ) throws -> Data {
    throw CompressionCapsuleError.unsupportedDictionaryTraining
  }

  public func loadDictionary(_ dictionary: Data) throws {
    throw CompressionCapsuleError.unsupportedDictionaryTraining
  }

  private static func makePayload(compressed: Data, originalSize: Int) -> Data {
    var payload = Data(magic)
    var size = UInt64(originalSize).littleEndian
    withUnsafeBytes(of: &size) { payload.append(contentsOf: $0) }
    payload.append(compressed)
    return payload
  }

  private static func parsePayload(_ input: Data) throws -> (compressed: Data, originalSize: Int) {
    let headerCount = magic.count + MemoryLayout<UInt64>.size
    guard input.count >= headerCount, Array(input.prefix(magic.count)) == magic else {
      throw CompressionCapsuleError.invalidCompressedPayload
    }

    var rawSize: UInt64 = 0
    for (index, byte) in input[magic.count..<headerCount].enumerated() {
      rawSize |= UInt64(byte) << UInt64(index * 8)
    }
    let originalSize = Int(UInt64(littleEndian: rawSize))
    return (input.dropFirst(headerCount), originalSize)
  }
}

public final class CompressionStreamHandle: @unchecked Sendable {
  public enum Mode: Sendable {
    case compress
    case decompress
  }

  private let capsule: CompressionCapsule
  private let mode: Mode

  fileprivate init(capsule: CompressionCapsule, mode: Mode) {
    self.capsule = capsule
    self.mode = mode
  }

  public func stream(_ input: Data?, flush: Bool = false) async throws -> Data {
    guard let input else { return Data() }
    switch mode {
    case .compress:
      return try await capsule.compress(input)
    case .decompress:
      return try await capsule.decompress(input)
    }
  }

  public func decompressStream(_ input: Data?) async throws -> Data {
    guard let input else { return Data() }
    return try await capsule.decompress(input)
  }
}
