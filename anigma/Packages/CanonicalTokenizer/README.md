# CanonicalTokenizer

Canonical tokenization abstraction for Anigma's Metal/MPS integration plan.

## Purpose

Separates tokenization (CPU/governed) from embedding computation (accelerated). Implements the principle "Swift governs, compute computes."

## Components

- `TokenizationPolicy`: Hashable struct capturing tokenizer identity, max length, padding, and truncation strategies.
- `Tokenizing`: Protocol for tokenizers that produce `TokenBuffer`s.
- `TokenBuffer`: Sendable, Codable representation of token IDs, attention mask, and optional token type IDs.
- `SimpleWordTokenizer`: Example implementation for testing.

## Usage

```swift
import CanonicalTokenizer

let policy = TokenizationPolicy(
    tokenizerHash: "sha256:...",
    maxLength: 512,
    padding: .maxLength,
    truncation: .longestFirst
)

let tokenizer = SimpleWordTokenizer(policy: policy)
let buffer = try tokenizer.tokenize(text: "Hello world")
```

## Integration

This package is a standalone library with no external dependencies beyond Foundation and CryptoKit. It will later be implemented with HuggingFaceSwiftTokenizer for production tokenization.

The tokenization policy hash should capture all variance (tokenizer identity, configuration, weights) for receipt governance.