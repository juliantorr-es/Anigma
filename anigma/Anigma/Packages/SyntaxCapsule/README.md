# SyntaxCapsule

A comprehensive Swift actor-based capsule for multi-language syntax highlighting, tokenization, and AST generation with error recovery.

## Features

- **Multi-Language Support**: Swift, Python, C++, Rust, JavaScript, TypeScript, JSON, HTML, CSS, Markdown
- **Tokenization**: Complete lexical analysis with position tracking
- **AST Generation**: Abstract syntax tree with rich metadata
- **Language Detection**: Automatic language identification
- **HTML Highlighting**: Syntax-highlighted HTML output with theming
- **Error Recovery**: Graceful handling of malformed code
- **Observability**: Full diagnostics and span tracking integration
- **Swift 6 Ready**: Strict concurrency and Sendable compliance

## Supported Languages

| Language | Extensions | Keywords | Identifiers | Strings | Comments |
|----------|------------|----------|-------------|---------|----------|
| Swift | `.swift` | ✅ | ✅ | ✅ | ✅ |
| Python | `.py`, `.pyw` | ✅ | ✅ | ✅ | ✅ |
| C++ | `.cpp`, `.cc`, `.cxx`, `.h`, `.hpp` | ✅ | ✅ | ✅ | ✅ |
| Rust | `.rs` | ✅ | ✅ | ✅ | ✅ |
| JavaScript | `.js`, `.mjs` | ✅ | ✅ | ✅ | ✅ |
| TypeScript | `.ts`, `.tsx` | ✅ | ✅ | ✅ | ✅ |
| JSON | `.json` | ✅ | ✅ | ✅ | ✅ |
| HTML | `.html`, `.htm` | ✅ | ✅ | ✅ | ✅ |
| CSS | `.css` | ✅ | ✅ | ✅ | ✅ |
| Markdown | `.md`, `.markdown` | ✅ | ✅ | ✅ | ✅ |

## Token Types

- **keyword**: Language keywords (if, for, class, etc.)
- **identifier**: Variable names, function names, type names
- **string**: String literals with quotes
- **number**: Numeric literals (integer, float)
- **comment**: Comments and documentation
- **operator**: Mathematical and logical operators
- **punctuation**: Brackets, parentheses, separators
- **error**: Malformed tokens

## Usage

```swift
import SyntaxCapsule
import TelemetryCore

let diagnostics = DefaultCapsuleDiagnostics()
let capsule = SyntaxCapsule(diagnostics: diagnostics)

// Detect language
let language = try await capsule.detectLanguage("func hello() { print(\"Hi\") }")
print("Detected: \(language)") // .swift

// Parse source code
let swiftCode = """
import Foundation

class Greeter {
    func sayHello(name: String) {
        print("Hello, \\(name)!")
    }
}
"""

let result = try await capsule.parse(swiftCode, language: .swift)

// Extract tokens by type
let keywords = capsule.extractTokens(from: result, ofType: .keyword)
print("Keywords: \(keywords.map { $0.text })")

// Extract identifiers
let identifiers = capsule.extractIdentifiers(from: result)
print("Identifiers: \(identifiers)")

// Extract string literals
let strings = capsule.extractStringLiterals(from: result)
print("Strings: \(strings)")

// Highlight to HTML
let html = try await capsule.highlightToHTML(swiftCode, language: .swift, theme: "github")
print(html)
```

## Advanced Usage

### Custom Token Analysis

```swift
class TokenAnalyzer {
    let result: SyntaxParseResult
    
    init(result: SyntaxParseResult) {
        self.result = result
    }
    
    func getComplexityMetrics() -> (statements: Int, functions: Int, loops: Int) {
        let keywords = capsule.extractTokens(from: result, ofType: .keyword)
        let statements = keywords.filter { ["if", "switch", "return", "throw"].contains($0.text) }.count
        let functions = keywords.filter { ["func", "def", "fn"].contains($0.text) }.count
        let loops = keywords.filter { ["for", "while", "do"].contains($0.text) }.count
        return (statements, functions, loops)
    }
    
    func getUnusedIdentifiers(usedIdentifiers: Set<String>) -> [String] {
        let allIdentifiers = Set(capsule.extractIdentifiers(from: result))
        return Array(allIdentifiers.subtracting(usedIdentifiers)).sorted()
    }
}

let analyzer = TokenAnalyzer(result: result)
let metrics = analyzer.getComplexityMetrics()
print("Statements: \(metrics.statements), Functions: \(metrics.functions), Loops: \(metrics.loops)")
```

### Multi-Language Processing

```swift
let mixedCode = """
// Swift code
let swiftCode = "func example() {}"

# Python code
def python_example():
    pass

/* C++ code */
int cpp_example() { return 0; }
"""

// Process each language separately
let swiftResult = try await capsule.parse(swiftCode, language: .swift)
let pythonResult = try await capsule.parse(pythonCode, language: .python)
let cppResult = try await capsule.parse(cppCode, language: .cpp)

let allTokens = swiftResult.tokens + pythonResult.tokens + cppResult.tokens
print("Total tokens: \(allTokens.count)")
```

### Custom Theming

```swift
extension SyntaxCapsule {
    func highlightWithCustomTheme(
        _ code: String,
        language: SupportedLanguage,
        theme: String
    ) async throws -> String {
        let result = try await parse(code, language: language)
        
        var html = "<pre class=\"\(theme)-highlight\"><code>"
        for token in result.tokens {
            let cssClass = "\(theme)-\(token.type.name)"
            let escapedText = escapeHTML(token.text)
            html += "<span class=\"\(cssClass)\">\(escapedText)</span>"
        }
        html += "</code></pre>"
        return html
    }
}

let customHTML = try await capsule.highlightWithCustomTheme(
    swiftCode,
    language: .swift,
    theme: "monokai"
)
```

## Architecture

### Core Components

1. **SyntaxCapsule Actor**: Thread-safe main API
2. **SyntaxNative C++ Library**: Core parsing engine
3. **Token Types**: Swift representation of lexical tokens
4. **Language Detection**: Automatic and hint-based detection
5. **HTML Renderer**: Syntax-highlighted output generation

### Error Handling

All errors are mapped to canonical `CapsuleError` types:
- `invalidInput`: Empty or malformed source code
- `parseFailed`: Lexical analysis failures
- `unsupportedLanguage`: Language not supported
- `resourceExhausted`: Memory limits exceeded
- `internalError`: Implementation bugs

### Position Tracking

Each token includes precise position information:
```swift
struct Position {
    let startLine: UInt32
    let startColumn: UInt32
    let endLine: UInt32
    let endColumn: UInt32
}
```

### Language Detection Algorithm

1. **File Extension**: Primary hint from filename
2. **Content Patterns**: Keyword and syntax detection
3. **Fallback**: Unknown if no patterns match

## Performance

- **Streaming Parser**: Process large files efficiently
- **Memory Efficient**: Token pooling and reuse
- **Concurrent Safe**: Actor-based isolation
- **Lazy Highlighting**: On-demand HTML generation

## Testing

Comprehensive test suite includes:
- Unit tests for all supported languages
- Token extraction validation
- Language detection accuracy
- HTML output verification
- Error handling validation
- Performance benchmarks

Run tests:
```bash
swift test --package-path Packages/SyntaxCapsule
```

## Integration

### CapsuleCore Protocol Compliance

```swift
extension SyntaxCapsule: CapsuleLifecycle {
    public func activate() async throws {
        // Initialize language parsers
    }

    public func deactivate() async {
        // Cleanup resources
    }
}
```

### Telemetry Integration

```swift
let span = diagnostics.beginSpan(
    name: "syntax.parse",
    category: "SyntaxCapsule",
    tags: [
        "language": language.name,
        "token_count": "\(result.metadata.tokenCount)"
    ]
)
// ... parsing logic
span.end(status: .ok)
```

## Version History

### v1.0.0
- Initial Tier 1 implementation
- Support for 10 programming languages
- Complete tokenization with position tracking
- HTML syntax highlighting with theming
- Language detection and error recovery
- Comprehensive diagnostics integration

## License

This capsule is part of Anigma project and follows the same licensing terms.