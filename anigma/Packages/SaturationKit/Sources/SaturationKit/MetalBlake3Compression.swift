import Foundation
import SaturationKitCore

#if canImport(Metal)
  @preconcurrency import Metal
#endif

public enum MetalBlake3CompressionStatus: Sendable, Equatable {
  case unavailable
  case shaderLibraryCompiled
}

public enum MetalBlake3CompressionError: Error, Sendable, Equatable {
  case chunkCountExceedsUInt32(Int)
  case metalFunctionUnavailable(String)
  case metalBufferCreationFailed
  case metalCommandEncodingFailed
  case metalCommandFailed(Int)
}

public struct MetalBlake3Compression {
  public static let kernelFunctionName = "anigma_saturation_blake3_chunk_chaining_values"
  public static let parentKernelFunctionName = "anigma_saturation_blake3_parent_chaining_values"

  public init() {}

  /// Compression block primitive only. This is not a full BLAKE3 hash API.
  public func compressBlock(
    chainingValue: [UInt32],
    block: Data,
    counter: UInt64,
    blockLength: UInt32,
    flags: UInt32
  ) -> [UInt32] {
    compressBlock(
      chainingValue: chainingValue,
      blockBytes: [UInt8](block),
      counter: counter,
      blockLength: blockLength,
      flags: flags
    )
  }

  /// Compression block primitive only. This is not a full BLAKE3 hash API.
  public func compressBlock(
    chainingValue: [UInt32],
    blockBytes: [UInt8],
    counter: UInt64,
    blockLength: UInt32,
    flags: UInt32
  ) -> [UInt32] {
    let words = Blake3CompressionCore.loadBlockWordsLE(from: blockBytes)
    return Blake3CompressionCore.compressBlock(
      chainingValue: chainingValue,
      blockWords: words,
      counter: counter,
      blockLength: blockLength,
      flags: flags
    )
  }

  /// Computes one chaining value per 1024-byte chunk from the input stream.
  /// The final chunk may be partial.
  public func chunkChainingValues(
    inputBytes: [UInt8],
    startChunkCounter: UInt64 = 0,
    useGPUIfAvailable: Bool = true
  ) throws -> [[UInt32]] {
    if !useGPUIfAvailable {
      return try cpuChunkChainingValues(inputBytes: inputBytes, startChunkCounter: startChunkCounter)
    }

    #if canImport(Metal)
      guard let device = MTLCreateSystemDefaultDevice(),
        let commandQueue = device.makeCommandQueue()
      else {
        return try cpuChunkChainingValues(inputBytes: inputBytes, startChunkCounter: startChunkCounter)
      }
      return try gpuChunkChainingValues(
        inputBytes: inputBytes,
        startChunkCounter: startChunkCounter,
        device: device,
        commandQueue: commandQueue
      )
    #else
      return try cpuChunkChainingValues(inputBytes: inputBytes, startChunkCounter: startChunkCounter)
    #endif
  }

  /// Computes an unkeyed BLAKE3 digest. Chunk chaining values are computed on GPU when available.
  /// Parent reduction stages use GPU pairwise reduction when available and explicit CPU fallback for odd tails and root output.
  public func digest(
    inputBytes: [UInt8],
    useGPUIfAvailable: Bool = true
  ) throws -> [UInt8] {
    let chunkCount = max(
      1,
      (inputBytes.count + Blake3Digest.chunkByteCount - 1) / Blake3Digest.chunkByteCount
    )

    if chunkCount == 1 {
      // Single-chunk root finalization needs block-level output state not recoverable from chunk CV alone.
      return Blake3Digest.digest(inputBytes)
    }

    var currentLevel = try chunkChainingValues(
      inputBytes: inputBytes,
      startChunkCounter: 0,
      useGPUIfAvailable: useGPUIfAvailable
    )

    while currentLevel.count > 2 {
      let pairCount = currentLevel.count / 2
      let oddTail = (currentLevel.count & 1) == 1 ? currentLevel.last : nil
      let pairedInput = Array(currentLevel.prefix(pairCount * 2))

      let reducedPairs: [[UInt32]]
      if useGPUIfAvailable {
        #if canImport(Metal)
          if let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue()
          {
            reducedPairs = try gpuParentChainingValues(
              childChainingValues: pairedInput,
              device: device,
              commandQueue: commandQueue
            )
          } else {
            reducedPairs = cpuParentChainingValues(childChainingValues: pairedInput)
          }
        #else
          reducedPairs = cpuParentChainingValues(childChainingValues: pairedInput)
        #endif
      } else {
        reducedPairs = cpuParentChainingValues(childChainingValues: pairedInput)
      }

      var nextLevel = reducedPairs
      if let oddTail {
        nextLevel.append(oddTail)
      }
      currentLevel = nextLevel
    }

    return rootDigestBytes(
      leftChildCV: currentLevel[0],
      rightChildCV: currentLevel[1]
    )
  }

  public func digest(input: Data, useGPUIfAvailable: Bool = true) throws -> [UInt8] {
    try digest(inputBytes: [UInt8](input), useGPUIfAvailable: useGPUIfAvailable)
  }

  private func cpuChunkChainingValues(
    inputBytes: [UInt8],
    startChunkCounter: UInt64
  ) throws -> [[UInt32]] {
    let chunkCount = max(
      1,
      (inputBytes.count + Blake3Digest.chunkByteCount - 1) / Blake3Digest.chunkByteCount
    )
    var output = [[UInt32]]()
    output.reserveCapacity(chunkCount)

    for chunkIndex in 0..<chunkCount {
      let start = chunkIndex * Blake3Digest.chunkByteCount
      let end = min(start + Blake3Digest.chunkByteCount, inputBytes.count)
      let chunk = start < end ? Array(inputBytes[start..<end]) : []
      let chunkCounter = startChunkCounter &+ UInt64(chunkIndex)
      output.append(try Blake3Digest.chunkChainingValue(chunkBytes: chunk, chunkCounter: chunkCounter))
    }

    return output
  }

  private func cpuParentChainingValues(childChainingValues: [[UInt32]]) -> [[UInt32]] {
    precondition((childChainingValues.count & 1) == 0, "Parent reduction expects an even child count")

    var output = [[UInt32]]()
    output.reserveCapacity(childChainingValues.count / 2)

    var index = 0
    while index < childChainingValues.count {
      let leftChildCV = childChainingValues[index]
      let rightChildCV = childChainingValues[index + 1]
      output.append(parentChainingValue(leftChildCV: leftChildCV, rightChildCV: rightChildCV))
      index += 2
    }
    return output
  }

  private func parentChainingValue(leftChildCV: [UInt32], rightChildCV: [UInt32]) -> [UInt32] {
    var blockWords = [UInt32](repeating: 0, count: Blake3CompressionCore.blockWordCount)
    blockWords[0..<Blake3CompressionCore.chainingValueWordCount] =
      leftChildCV[0..<Blake3CompressionCore.chainingValueWordCount]
    blockWords[Blake3CompressionCore.chainingValueWordCount..<Blake3CompressionCore.blockWordCount] =
      rightChildCV[0..<Blake3CompressionCore.chainingValueWordCount]

    let outputWords = Blake3CompressionCore.compressBlock(
      chainingValue: Blake3CompressionCore.iv,
      blockWords: blockWords,
      counter: 0,
      blockLength: UInt32(Blake3CompressionCore.blockByteCount),
      flags: Blake3CompressionCore.Flags.parent
    )
    return Array(outputWords.prefix(Blake3CompressionCore.chainingValueWordCount))
  }

  private func rootDigestBytes(leftChildCV: [UInt32], rightChildCV: [UInt32]) -> [UInt8] {
    var blockWords = [UInt32](repeating: 0, count: Blake3CompressionCore.blockWordCount)
    blockWords[0..<Blake3CompressionCore.chainingValueWordCount] =
      leftChildCV[0..<Blake3CompressionCore.chainingValueWordCount]
    blockWords[Blake3CompressionCore.chainingValueWordCount..<Blake3CompressionCore.blockWordCount] =
      rightChildCV[0..<Blake3CompressionCore.chainingValueWordCount]

    let rootWords = Blake3CompressionCore.compressBlock(
      chainingValue: Blake3CompressionCore.iv,
      blockWords: blockWords,
      counter: 0,
      blockLength: UInt32(Blake3CompressionCore.blockByteCount),
      flags: Blake3CompressionCore.Flags.parent | Blake3CompressionCore.Flags.root
    )

    var digestBytes = [UInt8]()
    digestBytes.reserveCapacity(Blake3Digest.digestByteCount)
    for word in rootWords {
      for shift in stride(from: 0, through: 24, by: 8) {
        if digestBytes.count == Blake3Digest.digestByteCount {
          return digestBytes
        }
        digestBytes.append(UInt8(truncatingIfNeeded: word >> shift))
      }
    }
    return digestBytes
  }

  #if canImport(Metal)
    public func compileCompressionLibrary(device: MTLDevice) throws -> MetalBlake3CompressionStatus
    {
      _ = try device.makeLibrary(source: Self.compressionShaderSource, options: nil)
      return .shaderLibraryCompiled
    }

    public func compileProbeLibrary(device: MTLDevice) throws -> MetalBlake3CompressionStatus {
      try compileCompressionLibrary(device: device)
    }

    private func gpuChunkChainingValues(
      inputBytes: [UInt8],
      startChunkCounter: UInt64,
      device: MTLDevice,
      commandQueue: MTLCommandQueue
    ) throws -> [[UInt32]] {
      let chunkCount = max(
        1,
        (inputBytes.count + Blake3Digest.chunkByteCount - 1) / Blake3Digest.chunkByteCount
      )
      guard chunkCount <= Int(UInt32.max) else {
        throw MetalBlake3CompressionError.chunkCountExceedsUInt32(chunkCount)
      }

      let paddedByteCount = chunkCount * Blake3Digest.chunkByteCount
      var paddedInputBytes = [UInt8](repeating: 0, count: paddedByteCount)
      if !inputBytes.isEmpty {
        paddedInputBytes[0..<inputBytes.count] = inputBytes[0..<inputBytes.count]
      }

      var chunkLengths = [UInt32](repeating: 0, count: chunkCount)
      for chunkIndex in 0..<chunkCount {
        let start = chunkIndex * Blake3Digest.chunkByteCount
        let end = min(start + Blake3Digest.chunkByteCount, inputBytes.count)
        chunkLengths[chunkIndex] = UInt32(end - start)
      }

      let keyWords = Blake3CompressionCore.iv
      let counterWords: [UInt32] = [
        UInt32(truncatingIfNeeded: startChunkCounter),
        UInt32(truncatingIfNeeded: startChunkCounter >> 32),
      ]
      var baseFlags: UInt32 = 0
      var mutableChunkCount = UInt32(chunkCount)

      let library = try device.makeLibrary(source: Self.compressionShaderSource, options: nil)
      guard let function = library.makeFunction(name: Self.kernelFunctionName) else {
        throw MetalBlake3CompressionError.metalFunctionUnavailable(Self.kernelFunctionName)
      }
      let pipeline = try device.makeComputePipelineState(function: function)

      guard
        let chunkBytesBuffer = device.makeBuffer(
          bytes: paddedInputBytes,
          length: paddedInputBytes.count,
          options: []
        ),
        let chunkLengthsBuffer = device.makeBuffer(
          bytes: chunkLengths,
          length: MemoryLayout<UInt32>.size * chunkLengths.count,
          options: []
        ),
        let keyWordsBuffer = device.makeBuffer(
          bytes: keyWords,
          length: MemoryLayout<UInt32>.size * keyWords.count,
          options: []
        ),
        let outputBuffer = device.makeBuffer(
          length: MemoryLayout<UInt32>.size * chunkCount * Blake3CompressionCore.chainingValueWordCount,
          options: []
        )
      else {
        throw MetalBlake3CompressionError.metalBufferCreationFailed
      }

      guard
        let commandBuffer = commandQueue.makeCommandBuffer(),
        let encoder = commandBuffer.makeComputeCommandEncoder()
      else {
        throw MetalBlake3CompressionError.metalCommandEncodingFailed
      }

      encoder.setComputePipelineState(pipeline)
      encoder.setBuffer(chunkBytesBuffer, offset: 0, index: 0)
      encoder.setBuffer(chunkLengthsBuffer, offset: 0, index: 1)
      encoder.setBuffer(keyWordsBuffer, offset: 0, index: 2)
      counterWords.withUnsafeBytes { bytes in
        encoder.setBytes(bytes.baseAddress!, length: bytes.count, index: 3)
      }
      encoder.setBytes(&baseFlags, length: MemoryLayout<UInt32>.size, index: 4)
      encoder.setBuffer(outputBuffer, offset: 0, index: 5)
      encoder.setBytes(&mutableChunkCount, length: MemoryLayout<UInt32>.size, index: 6)

      let threadsPerThreadgroup = max(1, min(pipeline.maxTotalThreadsPerThreadgroup, chunkCount))
      encoder.dispatchThreads(
        MTLSize(width: chunkCount, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: threadsPerThreadgroup, height: 1, depth: 1)
      )
      encoder.endEncoding()

      commandBuffer.commit()
      commandBuffer.waitUntilCompleted()
      guard commandBuffer.status == .completed else {
        throw MetalBlake3CompressionError.metalCommandFailed(Int(commandBuffer.status.rawValue))
      }

      let wordCount = chunkCount * Blake3CompressionCore.chainingValueWordCount
      let pointer = outputBuffer.contents().bindMemory(to: UInt32.self, capacity: wordCount)
      let flatWords = Array(UnsafeBufferPointer(start: pointer, count: wordCount))

      var output = [[UInt32]]()
      output.reserveCapacity(chunkCount)
      for chunkIndex in 0..<chunkCount {
        let start = chunkIndex * Blake3CompressionCore.chainingValueWordCount
        let end = start + Blake3CompressionCore.chainingValueWordCount
        output.append(Array(flatWords[start..<end]))
      }
      return output
    }

    private func gpuParentChainingValues(
      childChainingValues: [[UInt32]],
      device: MTLDevice,
      commandQueue: MTLCommandQueue
    ) throws -> [[UInt32]] {
      guard (childChainingValues.count & 1) == 0 else {
        preconditionFailure("GPU parent reduction requires even child count")
      }

      let parentCount = childChainingValues.count / 2
      guard parentCount <= Int(UInt32.max) else {
        throw MetalBlake3CompressionError.chunkCountExceedsUInt32(parentCount)
      }

      var flatChildWords = [UInt32]()
      flatChildWords.reserveCapacity(childChainingValues.count * Blake3CompressionCore.chainingValueWordCount)
      for cv in childChainingValues {
        flatChildWords.append(contentsOf: cv)
      }

      var mutableParentCount = UInt32(parentCount)

      let library = try device.makeLibrary(source: Self.compressionShaderSource, options: nil)
      guard let function = library.makeFunction(name: Self.parentKernelFunctionName) else {
        throw MetalBlake3CompressionError.metalFunctionUnavailable(Self.parentKernelFunctionName)
      }
      let pipeline = try device.makeComputePipelineState(function: function)

      guard
        let inputBuffer = device.makeBuffer(
          bytes: flatChildWords,
          length: MemoryLayout<UInt32>.size * flatChildWords.count,
          options: []
        ),
        let outputBuffer = device.makeBuffer(
          length: MemoryLayout<UInt32>.size * parentCount * Blake3CompressionCore.chainingValueWordCount,
          options: []
        )
      else {
        throw MetalBlake3CompressionError.metalBufferCreationFailed
      }

      guard
        let commandBuffer = commandQueue.makeCommandBuffer(),
        let encoder = commandBuffer.makeComputeCommandEncoder()
      else {
        throw MetalBlake3CompressionError.metalCommandEncodingFailed
      }

      encoder.setComputePipelineState(pipeline)
      encoder.setBuffer(inputBuffer, offset: 0, index: 0)
      encoder.setBuffer(outputBuffer, offset: 0, index: 1)
      encoder.setBytes(&mutableParentCount, length: MemoryLayout<UInt32>.size, index: 2)

      let threadsPerThreadgroup = max(1, min(pipeline.maxTotalThreadsPerThreadgroup, parentCount))
      encoder.dispatchThreads(
        MTLSize(width: parentCount, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: threadsPerThreadgroup, height: 1, depth: 1)
      )
      encoder.endEncoding()

      commandBuffer.commit()
      commandBuffer.waitUntilCompleted()
      guard commandBuffer.status == .completed else {
        throw MetalBlake3CompressionError.metalCommandFailed(Int(commandBuffer.status.rawValue))
      }

      let wordCount = parentCount * Blake3CompressionCore.chainingValueWordCount
      let pointer = outputBuffer.contents().bindMemory(to: UInt32.self, capacity: wordCount)
      let flatParents = Array(UnsafeBufferPointer(start: pointer, count: wordCount))

      var output = [[UInt32]]()
      output.reserveCapacity(parentCount)
      for parentIndex in 0..<parentCount {
        let start = parentIndex * Blake3CompressionCore.chainingValueWordCount
        let end = start + Blake3CompressionCore.chainingValueWordCount
        output.append(Array(flatParents[start..<end]))
      }

      return output
    }
  #else
    public func compileCompressionLibrary() -> MetalBlake3CompressionStatus {
      .unavailable
    }

    public func compileProbeLibrary() -> MetalBlake3CompressionStatus {
      compileCompressionLibrary()
    }
  #endif

  public static let compressionShaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    constant uint BLAKE3_BLOCK_LEN = 64u;
    constant uint BLAKE3_CHUNK_LEN = 1024u;
    constant uint BLAKE3_CHUNK_START = 1u;
    constant uint BLAKE3_CHUNK_END = 2u;
    constant uint BLAKE3_PARENT = 4u;

    constant ushort MSG_PERMUTATION[16] = {
        2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8
    };

    inline uint rotr32(uint x, uint by) {
        return (x >> by) | (x << (32u - by));
    }

    inline void g(
        thread uint *v,
        uint a, uint b, uint c, uint d,
        uint mx, uint my
    ) {
        v[a] = v[a] + v[b] + mx;
        v[d] = rotr32(v[d] ^ v[a], 16u);
        v[c] = v[c] + v[d];
        v[b] = rotr32(v[b] ^ v[c], 12u);
        v[a] = v[a] + v[b] + my;
        v[d] = rotr32(v[d] ^ v[a], 8u);
        v[c] = v[c] + v[d];
        v[b] = rotr32(v[b] ^ v[c], 7u);
    }

    inline void round_fn(thread uint *v, thread uint *m) {
        g(v, 0u, 4u, 8u, 12u, m[0u], m[1u]);
        g(v, 1u, 5u, 9u, 13u, m[2u], m[3u]);
        g(v, 2u, 6u, 10u, 14u, m[4u], m[5u]);
        g(v, 3u, 7u, 11u, 15u, m[6u], m[7u]);
        g(v, 0u, 5u, 10u, 15u, m[8u], m[9u]);
        g(v, 1u, 6u, 11u, 12u, m[10u], m[11u]);
        g(v, 2u, 7u, 8u, 13u, m[12u], m[13u]);
        g(v, 3u, 4u, 9u, 14u, m[14u], m[15u]);
    }

    inline void compress_block(
        thread const uint *chaining_value,
        thread const uint *m_in,
        uint counter_low,
        uint counter_high,
        uint block_length,
        uint flags,
        thread uint *output_words
    ) {
        thread uint v[16];
        v[0] = chaining_value[0];
        v[1] = chaining_value[1];
        v[2] = chaining_value[2];
        v[3] = chaining_value[3];
        v[4] = chaining_value[4];
        v[5] = chaining_value[5];
        v[6] = chaining_value[6];
        v[7] = chaining_value[7];
        v[8] = 0x6A09E667u;
        v[9] = 0xBB67AE85u;
        v[10] = 0x3C6EF372u;
        v[11] = 0xA54FF53Au;
        v[12] = counter_low;
        v[13] = counter_high;
        v[14] = block_length;
        v[15] = flags;

        thread uint m[16];
        for (uint i = 0u; i < 16u; i++) {
            m[i] = m_in[i];
        }

        for (uint r = 0u; r < 7u; r++) {
            round_fn(v, m);
            uint next_m[16];
            for (uint j = 0u; j < 16u; j++) {
                next_m[j] = m[MSG_PERMUTATION[j]];
            }
            for (uint j = 0u; j < 16u; j++) {
                m[j] = next_m[j];
            }
        }

        for (uint i = 0u; i < 8u; i++) {
            output_words[i] = v[i] ^ v[i + 8u];
            output_words[i + 8u] = v[i + 8u] ^ chaining_value[i];
        }
    }

    kernel void anigma_saturation_blake3_chunk_chaining_values(
        device const uchar *chunk_bytes [[buffer(0)]],
        device const uint *chunk_lengths [[buffer(1)]],
        device const uint *key_words [[buffer(2)]],
        constant uint2 &start_counter_words [[buffer(3)]],
        constant uint &base_flags [[buffer(4)]],
        device uint *output_cvs [[buffer(5)]],
        constant uint &chunk_count [[buffer(6)]],
        uint id [[thread_position_in_grid]]
    ) {
        if (id >= chunk_count) {
            return;
        }

        uint chunk_length = min(chunk_lengths[id], BLAKE3_CHUNK_LEN);
        uint chunk_base = id * BLAKE3_CHUNK_LEN;

        ulong chunk_counter = (ulong(start_counter_words.y) << 32u) | ulong(start_counter_words.x);
        chunk_counter += ulong(id);
        uint counter_low = uint(chunk_counter);
        uint counter_high = uint(chunk_counter >> 32u);

        thread uint cv[8];
        for (uint i = 0u; i < 8u; i++) {
            cv[i] = key_words[i];
        }

        uint block_count = max(1u, (chunk_length + BLAKE3_BLOCK_LEN - 1u) / BLAKE3_BLOCK_LEN);

        for (uint block_index = 0u; block_index < block_count; block_index++) {
            uint block_offset = block_index * BLAKE3_BLOCK_LEN;
            uint remaining = chunk_length > block_offset ? (chunk_length - block_offset) : 0u;
            uint block_length = min(remaining, BLAKE3_BLOCK_LEN);

            thread uint m[16];
            for (uint word = 0u; word < 16u; word++) {
                uint byte_index = block_offset + word * 4u;
                uchar b0 = (byte_index + 0u < chunk_length) ? chunk_bytes[chunk_base + byte_index + 0u] : uchar(0);
                uchar b1 = (byte_index + 1u < chunk_length) ? chunk_bytes[chunk_base + byte_index + 1u] : uchar(0);
                uchar b2 = (byte_index + 2u < chunk_length) ? chunk_bytes[chunk_base + byte_index + 2u] : uchar(0);
                uchar b3 = (byte_index + 3u < chunk_length) ? chunk_bytes[chunk_base + byte_index + 3u] : uchar(0);
                m[word] = uint(b0) | (uint(b1) << 8u) | (uint(b2) << 16u) | (uint(b3) << 24u);
            }

            uint flags = base_flags;
            if (block_index == 0u) {
                flags |= BLAKE3_CHUNK_START;
            }
            if (block_index + 1u == block_count) {
                flags |= BLAKE3_CHUNK_END;
            }

            thread uint output_words[16];
            compress_block(
                cv,
                m,
                counter_low,
                counter_high,
                block_length,
                flags,
                output_words
            );

            for (uint i = 0u; i < 8u; i++) {
                cv[i] = output_words[i];
            }
        }

        uint output_base = id * 8u;
        for (uint i = 0u; i < 8u; i++) {
            output_cvs[output_base + i] = cv[i];
        }
    }

    kernel void anigma_saturation_blake3_parent_chaining_values(
        device const uint *child_cvs [[buffer(0)]],
        device uint *parent_cvs [[buffer(1)]],
        constant uint &parent_count [[buffer(2)]],
        uint id [[thread_position_in_grid]]
    ) {
        if (id >= parent_count) {
            return;
        }

        uint left_base = id * 16u;

        thread uint cv[8];
        cv[0] = 0x6A09E667u;
        cv[1] = 0xBB67AE85u;
        cv[2] = 0x3C6EF372u;
        cv[3] = 0xA54FF53Au;
        cv[4] = 0x510E527Fu;
        cv[5] = 0x9B05688Cu;
        cv[6] = 0x1F83D9ABu;
        cv[7] = 0x5BE0CD19u;

        thread uint m[16];
        for (uint i = 0u; i < 16u; i++) {
            m[i] = child_cvs[left_base + i];
        }

        thread uint output_words[16];
        compress_block(
            cv,
            m,
            0u,
            0u,
            BLAKE3_BLOCK_LEN,
            BLAKE3_PARENT,
            output_words
        );

        uint output_base = id * 8u;
        for (uint i = 0u; i < 8u; i++) {
            parent_cvs[output_base + i] = output_words[i];
        }
    }
    """

  public static let probeShaderSource = compressionShaderSource
}
