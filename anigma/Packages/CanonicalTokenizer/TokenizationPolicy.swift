import Foundation

/// Strategy for padding token sequences to a uniform length.
public enum PaddingStrategy: Sendable, Codable, Hashable {
    /// No padding applied.
    case none
    /// Pad to the maximum length specified in the policy.
    case maxLength
    /// Pad to a fixed length.
    case fixed(Int)
}

/// Strategy for truncating token sequences that exceed the maximum length.
public enum TruncationStrategy: Sendable, Codable, Hashable {
    /// No truncation applied.
    case none
    /// Truncate the longer sequence first (for paired sequences).
    case longestFirst
    /// Truncate only the first sequence (for paired sequences).
    case onlyFirst
    /// Truncate only the second sequence (for paired sequences).
    case onlySecond
}

/// A policy that defines tokenization parameters and captures tokenizer identity via hash.
///
/// The policy's hash combines all fields to uniquely identify a tokenizer configuration
/// for receipt governance. The `tokenizerHash` should be a cryptographic hash of the
/// tokenizer's weights and configuration.
public struct TokenizationPolicy: Sendable, Codable, Hashable {
    /// Cryptographic hash of tokenizer weights and configuration.
    public let tokenizerHash: String
    /// Maximum sequence length (in tokens).
    public let maxLength: Int
    /// Padding strategy.
    public let padding: PaddingStrategy
    /// Truncation strategy.
    public let truncation: TruncationStrategy

    public init(
        tokenizerHash: String,
        maxLength: Int,
        padding: PaddingStrategy = .none,
        truncation: TruncationStrategy = .none
    ) {
        self.tokenizerHash = tokenizerHash
        self.maxLength = maxLength
        self.padding = padding
        self.truncation = truncation
}

}
