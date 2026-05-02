//
//  TokenBuffer.swift
//  ContractsCore
//
//  Canonical token buffer representation for transport between governed Swift code
//  and accelerated compute backends (Metal/MPS). Following "Swift governs, compute computes."
//

import AnigmaPrimitives
import Foundation

/// A buffer of token IDs with attention mask, suitable for efficient transport to compute backends.
/// This is the canonical representation of tokenized text that preserves governance boundaries:
/// tokenization happens in Swift (governed), embedding computation happens in compute backends.
public struct TokenBuffer: Sendable, Codable, Hashable {
    /// Token IDs (vocabulary indices).
    public let tokenIds: [Int32]
    /// Attention mask (1 for real tokens, 0 for padding).
    public let attentionMask: [UInt8]
    /// Optional token type IDs (segment embeddings).
    public let tokenTypeIds: [Int32]?

    /// Create a token buffer.
    /// - Parameters:
    ///   - tokenIds: Token IDs (vocabulary indices).
    ///   - attentionMask: Attention mask (1 for real tokens, 0 for padding).
    ///   - tokenTypeIds: Optional token type IDs (segment embeddings).
    /// - Precondition: `tokenIds.count == attentionMask.count`
    /// - Precondition: If `tokenTypeIds` is not nil, `tokenIds.count == tokenTypeIds.count`
    public init(
        tokenIds: [Int32],
        attentionMask: [UInt8],
        tokenTypeIds: [Int32]? = nil
    ) {
        precondition(tokenIds.count == attentionMask.count, "tokenIds and attentionMask must have same length")
        if let tokenTypeIds = tokenTypeIds {
            precondition(tokenIds.count == tokenTypeIds.count, "tokenIds and tokenTypeIds must have same length")
        }
        self.tokenIds = tokenIds
        self.attentionMask = attentionMask
        self.tokenTypeIds = tokenTypeIds
    }

    /// Number of tokens in the buffer (including padding).
    public var count: Int {
        tokenIds.count
    }

    /// Create a token buffer with a single sequence (no token type IDs).
    public static func singleSequence(_ tokenIds: [Int32], attentionMask: [UInt8]) -> TokenBuffer {
        TokenBuffer(tokenIds: tokenIds, attentionMask: attentionMask, tokenTypeIds: nil)
    }

    /// Create a token buffer with token type IDs for two segments (e.g., question/answer).
    public static func twoSegment(
        tokenIds: [Int32],
        attentionMask: [UInt8],
        segmentLengths: (Int, Int)
    ) -> TokenBuffer {
        let (firstLen, secondLen): (Int, Int) = segmentLengths
        precondition(firstLen + secondLen == tokenIds.count, "Segment lengths must sum to tokenIds count")

        var tokenTypeIds: [Int32] = [Int32](repeating: 0, count: tokenIds.count)
        for i in firstLen..<tokenIds.count {
            tokenTypeIds[i] = 1
        }
        return TokenBuffer(tokenIds: tokenIds, attentionMask: attentionMask, tokenTypeIds: tokenTypeIds)
    }
}
