import Foundation

public enum Blake3CompressionCore {
  public static let blockByteCount = 64
  public static let blockWordCount = 16
  public static let chainingValueWordCount = 8
  public static let outputWordCount = 16
  public static let rounds = 7

  public static let iv: [UInt32] = [
    0x6A09_E667, 0xBB67_AE85, 0x3C6E_F372, 0xA54F_F53A,
    0x510E_527F, 0x9B05_688C, 0x1F83_D9AB, 0x5BE0_CD19,
  ]

  public enum Flags {
    public static let chunkStart: UInt32 = 1 << 0
    public static let chunkEnd: UInt32 = 1 << 1
    public static let parent: UInt32 = 1 << 2
    public static let root: UInt32 = 1 << 3
    public static let keyedHash: UInt32 = 1 << 4
    public static let deriveKeyContext: UInt32 = 1 << 5
    public static let deriveKeyMaterial: UInt32 = 1 << 6
  }

  public static func loadBlockWordsLE(from blockBytes: [UInt8]) -> [UInt32] {
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

  public static func compressBlock(
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

extension UInt32 {
  fileprivate func rotatedRight(_ distance: UInt32) -> UInt32 {
    (self >> distance) | (self << (32 - distance))
  }
}
