import Foundation

public enum BLAKE3DigestError: Error, Equatable {
  case invalidOutputLength(Int)
  case invalidKeyLength(Int)
  case chunkTooLarge(Int)
}

public enum BLAKE3Digest {
  public static let digestByteCount = 32
  public static let chunkByteCount = 1024

  public static func hex(of data: Data) -> String {
    digestHex(data)
  }

  public static func hex(of string: String) -> String {
    hex(of: Data(string.utf8))
  }

  public static func digest(_ input: Data) -> [UInt8] {
    digest([UInt8](input))
  }

  public static func digest(_ input: [UInt8]) -> [UInt8] {
    let output = hashOutputNode(for: input, mode: .default)
    return output.rootOutputBytes(outputByteCount: digestByteCount)
  }

  public static func digestHex(_ input: Data) -> String {
    digestHex([UInt8](input))
  }

  public static func digestHex(_ input: [UInt8]) -> String {
    hexString(digest(input))
  }

  public static func digest(_ input: Data, outputByteCount: Int) throws -> [UInt8] {
    try digest([UInt8](input), outputByteCount: outputByteCount)
  }

  public static func digest(_ input: [UInt8], outputByteCount: Int) throws -> [UInt8] {
    guard outputByteCount >= 0 else {
      throw BLAKE3DigestError.invalidOutputLength(outputByteCount)
    }

    let output = hashOutputNode(for: input, mode: .default)
    return output.rootOutputBytes(outputByteCount: outputByteCount)
  }

  public static func keyedDigest(_ input: Data, key: [UInt8]) throws -> [UInt8] {
    try keyedDigest([UInt8](input), key: key)
  }

  public static func keyedDigest(_ input: [UInt8], key: [UInt8]) throws -> [UInt8] {
    try keyedDigest(input, key: key, outputByteCount: digestByteCount)
  }

  public static func keyedDigest(_ input: Data, key: [UInt8], outputByteCount: Int) throws -> [UInt8] {
    try keyedDigest([UInt8](input), key: key, outputByteCount: outputByteCount)
  }

  public static func keyedDigest(_ input: [UInt8], key: [UInt8], outputByteCount: Int) throws -> [UInt8] {
    guard outputByteCount >= 0 else {
      throw BLAKE3DigestError.invalidOutputLength(outputByteCount)
    }

    let mode = try HashMode.keyed(keyBytes: key)
    let output = hashOutputNode(for: input, mode: mode)
    return output.rootOutputBytes(outputByteCount: outputByteCount)
  }

  public static func deriveKeyDigest(_ input: Data, context: String) -> [UInt8] {
    deriveKeyDigest([UInt8](input), context: context)
  }

  public static func deriveKeyDigest(_ input: [UInt8], context: String) -> [UInt8] {
    let mode = deriveKeyMaterialMode(context: context)
    let output = hashOutputNode(for: input, mode: mode)
    return output.rootOutputBytes(outputByteCount: digestByteCount)
  }

  public static func deriveKeyDigest(_ input: Data, context: String, outputByteCount: Int) throws -> [UInt8] {
    try deriveKeyDigest([UInt8](input), context: context, outputByteCount: outputByteCount)
  }

  public static func deriveKeyDigest(_ input: [UInt8], context: String, outputByteCount: Int) throws -> [UInt8]
  {
    guard outputByteCount >= 0 else {
      throw BLAKE3DigestError.invalidOutputLength(outputByteCount)
    }

    let mode = deriveKeyMaterialMode(context: context)
    let output = hashOutputNode(for: input, mode: mode)
    return output.rootOutputBytes(outputByteCount: outputByteCount)
  }

  public static func chunkChainingValue(chunkBytes: [UInt8], chunkCounter: UInt64 = 0) throws -> [UInt32]
  {
    guard chunkBytes.count <= chunkByteCount else {
      throw BLAKE3DigestError.chunkTooLarge(chunkBytes.count)
    }

    return chunkOutputNode(chunkBytes: chunkBytes, chunkCounter: chunkCounter, mode: .default).chainingValue
  }

  private struct HashMode {
    let keyWords: [UInt32]
    let flags: UInt32

    static let `default` = HashMode(
      keyWords: BLAKE3CompressionCore.iv,
      flags: 0
    )

    static func keyed(keyBytes: [UInt8]) throws -> HashMode {
      HashMode(
        keyWords: try keyWordsFromBytes(keyBytes),
        flags: BLAKE3CompressionCore.Flags.keyedHash
      )
    }
  }

  private struct OutputNode {
    let inputChainingValue: [UInt32]
    let blockWords: [UInt32]
    let counter: UInt64
    let blockLength: UInt32
    let flags: UInt32

    var chainingValue: [UInt32] {
      Array(compressOutputWords(counter: counter, flags: flags).prefix(BLAKE3CompressionCore.chainingValueWordCount))
    }

    func rootOutputBytes(outputByteCount: Int) -> [UInt8] {
      var output = [UInt8]()
      output.reserveCapacity(outputByteCount)

      var outputCounter: UInt64 = 0
      while output.count < outputByteCount {
        let words = compressOutputWords(
          counter: outputCounter,
          flags: flags | BLAKE3CompressionCore.Flags.root
        )

        for word in words {
          for shift in stride(from: 0, through: 24, by: 8) {
            if output.count == outputByteCount {
              return output
            }
            output.append(UInt8(truncatingIfNeeded: word >> shift))
          }
        }

        outputCounter &+= 1
      }

      return output
    }

    private func compressOutputWords(counter: UInt64, flags: UInt32) -> [UInt32] {
      BLAKE3CompressionCore.compressBlock(
        chainingValue: inputChainingValue,
        blockWords: blockWords,
        counter: counter,
        blockLength: blockLength,
        flags: flags
      )
    }
  }

  public static func digestAsync(_ input: [UInt8]) async -> [UInt8] {
    let output = await hashOutputNodeAsync(for: input, mode: .default)
    return output.rootOutputBytes(outputByteCount: digestByteCount)
  }

  public static func digestHexAsync(_ input: [UInt8]) async -> String {
    await hexString(digestAsync(input))
  }

  public static func digestAsync(_ input: [UInt8], outputByteCount: Int) async throws -> [UInt8] {
    guard outputByteCount >= 0 else {
      throw BLAKE3DigestError.invalidOutputLength(outputByteCount)
    }

    let output = await hashOutputNodeAsync(for: input, mode: .default)
    return output.rootOutputBytes(outputByteCount: outputByteCount)
  }

  public static func keyedDigestAsync(_ input: [UInt8], key: [UInt8], outputByteCount: Int) async throws -> [UInt8] {
    guard outputByteCount >= 0 else {
      throw BLAKE3DigestError.invalidOutputLength(outputByteCount)
    }

    let mode = try HashMode.keyed(keyBytes: key)
    let output = await hashOutputNodeAsync(for: input, mode: mode)
    return output.rootOutputBytes(outputByteCount: outputByteCount)
  }

  public static func deriveKeyDigestAsync(_ input: [UInt8], context: String) async -> [UInt8] {
    let mode = await deriveKeyMaterialModeAsync(context: context)
    let output = await hashOutputNodeAsync(for: input, mode: mode)
    return output.rootOutputBytes(outputByteCount: digestByteCount)
  }

  private static func hashOutputNodeAsync(for input: [UInt8], mode: HashMode) async -> OutputNode {
    let chunkCount = max(1, (input.count + chunkByteCount - 1) / chunkByteCount)

    if chunkCount == 1 {
      return chunkOutputNode(chunkBytes: input, chunkCounter: 0, mode: mode)
    }

    // Parallel chunk processing
    let chunkCVs: [[UInt32]] = await withTaskGroup(of: (Int, [UInt32]).self) { group in
      for chunkIndex in 0..<chunkCount {
        group.addTask {
          let rangeStart = chunkIndex * chunkByteCount
          let rangeEnd = min(rangeStart + chunkByteCount, input.count)
          let chunkBytes = Array(input[rangeStart..<rangeEnd])
          let cv = chunkOutputNode(
            chunkBytes: chunkBytes,
            chunkCounter: UInt64(chunkIndex),
            mode: mode
          ).chainingValue
          return (chunkIndex, cv)
        }
      }

      var results = Array(repeating: [UInt32](), count: chunkCount)
      for await (index, cv) in group {
        results[index] = cv
      }
      return results
    }

    // Build tree
    return await reduceTreeAsync(chunkCVs, mode: mode)
  }

  private static func reduceTreeAsync(_ cvs: [[UInt32]], mode: HashMode) async -> OutputNode {
    var currentLevelCVs = cvs
    
    while currentLevelCVs.count > 2 {
      let nextLevelCount = (currentLevelCVs.count + 1) / 2
      currentLevelCVs = await withTaskGroup(of: (Int, [UInt32]).self) { group in
        for i in 0..<nextLevelCount {
          group.addTask {
            let leftIndex = i * 2
            let rightIndex = leftIndex + 1
            
            if rightIndex < currentLevelCVs.count {
              return (i, parentOutputNode(
                leftChildCV: currentLevelCVs[leftIndex],
                rightChildCV: currentLevelCVs[rightIndex],
                mode: mode
              ).chainingValue)
            } else {
              return (i, currentLevelCVs[leftIndex])
            }
          }
        }
        
        var results = Array(repeating: [UInt32](), count: nextLevelCount)
        for await (index, cv) in group {
          results[index] = cv
        }
        return results
      }
    }
    
    return parentOutputNode(
      leftChildCV: currentLevelCVs[0],
      rightChildCV: currentLevelCVs[1],
      mode: mode
    )
  }

  private static func deriveKeyMaterialModeAsync(context: String) async -> HashMode {
    let contextBytes = [UInt8](context.utf8)
    let contextMode = HashMode(
      keyWords: BLAKE3CompressionCore.iv,
      flags: BLAKE3CompressionCore.Flags.deriveKeyContext
    )
    let contextOutput = await hashOutputNodeAsync(for: contextBytes, mode: contextMode)
    let contextKeyBytes = contextOutput.rootOutputBytes(outputByteCount: digestByteCount)
    let contextKeyWords = wordsFromBytesLE32(contextKeyBytes)

    return HashMode(
      keyWords: contextKeyWords,
      flags: BLAKE3CompressionCore.Flags.deriveKeyMaterial
    )
  }

  private static func hashOutputNode(for input: [UInt8], mode: HashMode) -> OutputNode {
    let chunkCount = max(1, (input.count + chunkByteCount - 1) / chunkByteCount)

    if chunkCount == 1 {
      return chunkOutputNode(chunkBytes: input, chunkCounter: 0, mode: mode)
    }

    var cvStack = [[UInt32]]()
    cvStack.reserveCapacity(chunkCount)

    if chunkCount > 1 {
      for chunkIndex in 0..<(chunkCount - 1) {
        let rangeStart = chunkIndex * chunkByteCount
        let rangeEnd = rangeStart + chunkByteCount
        let chunkBytes = Array(input[rangeStart..<rangeEnd])
        let chunkCV = chunkOutputNode(
          chunkBytes: chunkBytes,
          chunkCounter: UInt64(chunkIndex),
          mode: mode
        ).chainingValue
        addChunkChainingValue(
          chunkCV,
          totalChunks: chunkIndex + 1,
          cvStack: &cvStack,
          mode: mode
        )
      }
    }

    let lastChunkStart = (chunkCount - 1) * chunkByteCount
    let lastChunkBytes = Array(input[lastChunkStart..<input.count])
    var output = chunkOutputNode(
      chunkBytes: lastChunkBytes,
      chunkCounter: UInt64(chunkCount - 1),
      mode: mode
    )

    while let leftChildCV = cvStack.popLast() {
      output = parentOutputNode(
        leftChildCV: leftChildCV,
        rightChildCV: output.chainingValue,
        mode: mode
      )
    }

    return output
  }

  private static func addChunkChainingValue(
    _ newChunkCV: [UInt32],
    totalChunks: Int,
    cvStack: inout [[UInt32]],
    mode: HashMode
  ) {
    var mergedCV = newChunkCV
    var chunks = totalChunks

    while (chunks & 1) == 0 {
      let leftChildCV = cvStack.removeLast()
      mergedCV = parentOutputNode(
        leftChildCV: leftChildCV,
        rightChildCV: mergedCV,
        mode: mode
      ).chainingValue
      chunks >>= 1
    }

    cvStack.append(mergedCV)
  }

  private static func chunkOutputNode(chunkBytes: [UInt8], chunkCounter: UInt64, mode: HashMode) -> OutputNode {
    let blockCount = max(1, (chunkBytes.count + BLAKE3CompressionCore.blockByteCount - 1) / BLAKE3CompressionCore.blockByteCount)
    var chainingValue = mode.keyWords

    for blockIndex in 0..<blockCount {
      let blockOffset = blockIndex * BLAKE3CompressionCore.blockByteCount
      let blockLength = min(BLAKE3CompressionCore.blockByteCount, max(chunkBytes.count - blockOffset, 0))
      var block = [UInt8](repeating: 0, count: BLAKE3CompressionCore.blockByteCount)
      if blockLength > 0 {
        block[0..<blockLength] = chunkBytes[blockOffset..<(blockOffset + blockLength)]
      }

      let blockWords = BLAKE3CompressionCore.loadBlockWordsLE(from: block)
      var flags: UInt32 = 0
      if blockIndex == 0 {
        flags |= BLAKE3CompressionCore.Flags.chunkStart
      }
      if blockIndex == blockCount - 1 {
        flags |= BLAKE3CompressionCore.Flags.chunkEnd
      }
      flags |= mode.flags

      if blockIndex == blockCount - 1 {
        return OutputNode(
          inputChainingValue: chainingValue,
          blockWords: blockWords,
          counter: chunkCounter,
          blockLength: UInt32(blockLength),
          flags: flags
        )
      }

      let output = BLAKE3CompressionCore.compressBlock(
        chainingValue: chainingValue,
        blockWords: blockWords,
        counter: chunkCounter,
        blockLength: UInt32(blockLength),
        flags: flags
      )
      chainingValue = Array(output.prefix(BLAKE3CompressionCore.chainingValueWordCount))
    }

    return OutputNode(
      inputChainingValue: chainingValue,
      blockWords: [UInt32](repeating: 0, count: BLAKE3CompressionCore.blockWordCount),
      counter: chunkCounter,
      blockLength: 0,
      flags: BLAKE3CompressionCore.Flags.chunkStart | BLAKE3CompressionCore.Flags.chunkEnd
        | mode.flags
    )
  }

  private static func parentOutputNode(leftChildCV: [UInt32], rightChildCV: [UInt32], mode: HashMode) -> OutputNode {
    var blockWords = [UInt32](repeating: 0, count: BLAKE3CompressionCore.blockWordCount)
    blockWords[0..<BLAKE3CompressionCore.chainingValueWordCount] = leftChildCV[0..<BLAKE3CompressionCore.chainingValueWordCount]
    blockWords[BLAKE3CompressionCore.chainingValueWordCount..<BLAKE3CompressionCore.blockWordCount] =
      rightChildCV[0..<BLAKE3CompressionCore.chainingValueWordCount]

    return OutputNode(
      inputChainingValue: mode.keyWords,
      blockWords: blockWords,
      counter: 0,
      blockLength: UInt32(BLAKE3CompressionCore.blockByteCount),
      flags: BLAKE3CompressionCore.Flags.parent | mode.flags
    )
  }

  private static func deriveKeyMaterialMode(context: String) -> HashMode {
    let contextBytes = [UInt8](context.utf8)
    let contextMode = HashMode(
      keyWords: BLAKE3CompressionCore.iv,
      flags: BLAKE3CompressionCore.Flags.deriveKeyContext
    )
    let contextOutput = hashOutputNode(for: contextBytes, mode: contextMode)
    let contextKeyBytes = contextOutput.rootOutputBytes(outputByteCount: digestByteCount)
    let contextKeyWords = wordsFromBytesLE32(contextKeyBytes)

    return HashMode(
      keyWords: contextKeyWords,
      flags: BLAKE3CompressionCore.Flags.deriveKeyMaterial
    )
  }

  private static func keyWordsFromBytes(_ keyBytes: [UInt8]) throws -> [UInt32] {
    guard keyBytes.count == digestByteCount else {
      throw BLAKE3DigestError.invalidKeyLength(keyBytes.count)
    }
    return wordsFromBytesLE32(keyBytes)
  }

  private static func wordsFromBytesLE32(_ bytes: [UInt8]) -> [UInt32] {
    precondition(bytes.count == 32, "Expected exactly 32 bytes")
    var words = [UInt32]()
    words.reserveCapacity(BLAKE3CompressionCore.chainingValueWordCount)

    for index in stride(from: 0, to: bytes.count, by: 4) {
      words.append(
        UInt32(bytes[index])
          | (UInt32(bytes[index + 1]) << 8)
          | (UInt32(bytes[index + 2]) << 16)
          | (UInt32(bytes[index + 3]) << 24)
      )
    }

    return words
  }

  private static func hexString(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
  }
}

private enum BLAKE3CompressionCore {
  static let blockByteCount = 64
  static let blockWordCount = 16
  static let chainingValueWordCount = 8
  static let outputWordCount = 16

  static let iv: [UInt32] = [
    0x6A09_E667, 0xBB67_AE85, 0x3C6E_F372, 0xA54F_F53A,
    0x510E_527F, 0x9B05_688C, 0x1F83_D9AB, 0x5BE0_CD19,
  ]

  enum Flags {
    static let chunkStart: UInt32 = 1 << 0
    static let chunkEnd: UInt32 = 1 << 1
    static let parent: UInt32 = 1 << 2
    static let root: UInt32 = 1 << 3
    static let keyedHash: UInt32 = 1 << 4
    static let deriveKeyContext: UInt32 = 1 << 5
    static let deriveKeyMaterial: UInt32 = 1 << 6
  }

  static func loadBlockWordsLE(from blockBytes: [UInt8]) -> [UInt32] {
    precondition(
      blockBytes.count == blockByteCount,
      "BLAKE3 compression requires exactly \(blockByteCount) bytes"
    )

    var words = Array(repeating: UInt32(0), count: 16)
    for i in 0..<16 {
      let offset = i * 4
      words[i] = UInt32(blockBytes[offset])
        | (UInt32(blockBytes[offset + 1]) << 8)
        | (UInt32(blockBytes[offset + 2]) << 16)
        | (UInt32(blockBytes[offset + 3]) << 24)
    }
    return words
  }

  static func compressBlock(
    chainingValue: [UInt32],
    blockWords: [UInt32],
    counter: UInt64,
    blockLength: UInt32,
    flags: UInt32
  ) -> [UInt32] {
    var state = [
      chainingValue[0], chainingValue[1], chainingValue[2], chainingValue[3],
      chainingValue[4], chainingValue[5], chainingValue[6], chainingValue[7],
      iv[0], iv[1], iv[2], iv[3],
      UInt32(truncatingIfNeeded: counter),
      UInt32(truncatingIfNeeded: counter >> 32),
      blockLength,
      flags,
    ]

    var m = blockWords
    let perm = [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8]

    for _ in 0..<7 {
      round(&state, m)
      var nextM = Array(repeating: UInt32(0), count: 16)
      for j in 0..<16 {
        nextM[j] = m[perm[j]]
      }
      m = nextM
    }

    var output = Array(repeating: UInt32.zero, count: outputWordCount)
    for index in 0..<chainingValueWordCount {
      output[index] = state[index] ^ state[index + 8]
      output[index + 8] = state[index + 8] ^ chainingValue[index]
    }
    return output
  }

  private static func round(_ state: inout [UInt32], _ m: [UInt32]) {
    g(&state, a: 0, b: 4, c: 8, d: 12, mx: m[0], my: m[1])
    g(&state, a: 1, b: 5, c: 9, d: 13, mx: m[2], my: m[3])
    g(&state, a: 2, b: 6, c: 10, d: 14, mx: m[4], my: m[5])
    g(&state, a: 3, b: 7, c: 11, d: 15, mx: m[6], my: m[7])
    g(&state, a: 0, b: 5, c: 10, d: 15, mx: m[8], my: m[9])
    g(&state, a: 1, b: 6, c: 11, d: 12, mx: m[10], my: m[11])
    g(&state, a: 2, b: 7, c: 8, d: 13, mx: m[12], my: m[13])
    g(&state, a: 3, b: 4, c: 9, d: 14, mx: m[14], my: m[15])
  }

  private static func g(
    _ state: inout [UInt32],
    a: Int,
    b: Int,
    c: Int,
    d: Int,
    mx: UInt32,
    my: UInt32
  ) {
    state[a] = state[a] &+ state[b] &+ mx
    state[d] = (state[d] ^ state[a]).rotatedRight(16)
    state[c] = state[c] &+ state[d]
    state[b] = (state[b] ^ state[c]).rotatedRight(12)
    state[a] = state[a] &+ state[b] &+ my
    state[d] = (state[d] ^ state[a]).rotatedRight(8)
    state[c] = state[c] &+ state[d]
    state[b] = (state[b] ^ state[c]).rotatedRight(7)
  }
}

private extension UInt32 {
  func rotatedRight(_ distance: UInt32) -> UInt32 {
    (self >> distance) | (self << (32 - distance))
  }
}
