import Foundation
import CryptoKit
import FoundationContracts

/// A simple word‑level tokenizer for testing and prototyping.
///
/// Splits text on whitespace and maps each word to a deterministic 32‑bit hash
/// derived from SHA‑256. Applies padding and truncation as specified by the policy.
public struct SimpleWordTokenizer: Tokenizing {
    /// The tokenization policy governing padding, truncation, and maximum length.
    public let policy: TokenizationPolicy

    /// Create a word tokenizer with the given policy.
    public init(policy: TokenizationPolicy) {
        self.policy = policy
    }

    public func tokenize(text: String) throws -> TokenBuffer {
        let words: [String] = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var tokenIds: [Int32] = words.map { word in
            // swiftlint:disable:next redundant_type_annotation
            let data: Data = Data(word.utf8)
            let hash: SHA256.Digest = SHA256.hash(data: data)
            // Take first 4 bytes and convert to Int32 (signed)
            let prefix: ArraySlice<UInt8> = Array(hash).prefix(4)
            let value: Int32 = prefix.reduce(0) { ($0 << 8) | Int32($1) }
            return value
        }
        // swiftlint:disable:next redundant_type_annotation
        var attentionMask: [UInt8] = [UInt8](repeating: 1, count: tokenIds.count)

        // Apply truncation
        switch policy.truncation {
        case .none:
            break
        case .longestFirst:
            // Not implemented for single sequence
            break
        case .onlyFirst, .onlySecond:
            // Not applicable for single sequence
            break
        }
        if tokenIds.count > policy.maxLength {
            tokenIds = Array(tokenIds.prefix(policy.maxLength))
            attentionMask = Array(attentionMask.prefix(policy.maxLength))
        }

        // Apply padding
        switch policy.padding {
        case .none:
            break
        case .maxLength:
            let targetLength: Int = policy.maxLength
            if tokenIds.count < targetLength {
                let padCount: Int = targetLength - tokenIds.count
                tokenIds.append(contentsOf: [Int32](repeating: 0, count: padCount))
                attentionMask.append(contentsOf: [UInt8](repeating: 0, count: padCount))
            }
        case .fixed(let length):
            let targetLength: Int = length
            if tokenIds.count < targetLength {
                let padCount: Int = targetLength - tokenIds.count
                tokenIds.append(contentsOf: [Int32](repeating: 0, count: padCount))
                attentionMask.append(contentsOf: [UInt8](repeating: 0, count: padCount))
            } else if tokenIds.count > targetLength {
                tokenIds = Array(tokenIds.prefix(targetLength))
                attentionMask = Array(attentionMask.prefix(targetLength))
            }
        }

        return TokenBuffer(
            tokenIds: tokenIds,
            attentionMask: attentionMask,
            tokenTypeIds: nil
        )
    }
}
