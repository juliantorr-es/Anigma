import Foundation
import ContractsCore

/// Protocol for tokenizers that convert text into token buffers.
///
/// The tokenizer is responsible for applying the tokenization policy (padding, truncation)
/// and producing a `TokenBuffer` suitable for accelerated computation (Metal/MPS).
public protocol Tokenizing: Sendable {
    /// Tokenize a single text string.
    func tokenize(text: String) throws -> TokenBuffer
    /// Tokenize a batch of text strings (optional).
    func tokenizeBatch(texts: [String]) throws -> [TokenBuffer]
}

extension Tokenizing {
    public func tokenizeBatch(texts: [String]) throws -> [TokenBuffer] {
        try texts.map { try tokenize(text: $0) }
    }
}
