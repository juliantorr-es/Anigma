# MarkdownCapsule

A comprehensive Swift actor-based capsule for parsing and rendering CommonMark markdown with full AST generation and visitor pattern support.

## Features

- **Full CommonMark Compliance**: Parse markdown according to the CommonMark specification
- **AST Generation**: Complete abstract syntax tree with node types and position information
- **Visitor Pattern**: Traverse and manipulate AST nodes with customizable visitors
- **Multiple Render Formats**: Output to HTML, plain text, and more
- **Syntax Highlighting**: Integrated syntax highlighting for code blocks
- **Error Recovery**: Graceful handling of malformed markdown
- **Observability**: Full diagnostics and span tracking integration
- **Swift 6 Ready**: Strict concurrency and Sendable compliance

## Supported Features

### Markdown Elements
- Headers (H1-H6)
- Paragraphs and line breaks
- Emphasis and strong emphasis
- Links and images
- Code spans and code blocks
- Blockquotes
- Lists (ordered and unordered)
- Horizontal rules
- HTML blocks and inline HTML

### AST Operations
- Complete node type enumeration
- Position tracking (line/column)
- Child/sibling traversal
- Custom visitor implementations
- Node metadata extraction

### Rendering Formats
- HTML (semantic markup)
- Plain text (format-stripped)
- CommonMark (normalized)
- XML (structured representation)

## Usage

```swift
import MarkdownCapsule
import TelemetryCore

let diagnostics = DefaultCapsuleDiagnostics()
let capsule = MarkdownCapsule(diagnostics: diagnostics)

// Parse markdown
let markdown = """
# Hello World

This is **bold** text with *italic* and a [link](https://example.com).

```swift
func greet() {
    print("Hello, World!")
}
```
"""

let document = try await capsule.parse(markdown)

// Extract links
let links = await capsule.extractLinks(from: document)
print("Links found: \(links)")

// Render to HTML
let html = try await capsule.render(document: document, to: .html)
print(html)

// Use visitor pattern
class LinkCollector: MarkdownVisitor {
    var links: [String] = []
    
    func visit(node: MarkdownNode) -> MarkdownVisitResult {
        if node.type == .link, let url = node.content {
            links.append(url)
        }
        return .continueVisit
    }
    
    func enter(node: MarkdownNode) -> MarkdownVisitResult { .continueVisit }
    func leave(node: MarkdownNode) -> MarkdownVisitResult { .continueVisit }
}

let collector = LinkCollector()
await capsule.visit(document: document, using: collector)
print("Collected links: \(collector.links)")
```

## Architecture

### Core Components

1. **MarkdownCapsule Actor**: Thread-safe main API
2. **MarkdownNative C Library**: Core parsing engine based on cmark
3. **AST Types**: Swift representation of markdown nodes
4. **Visitor Pattern**: Extensible node traversal system
5. **Renderers**: Multiple output format support

### Error Handling

All errors are mapped to canonical `CapsuleError` types:
- `invalidInput`: Malformed markdown
- `parseFailed`: Parsing errors
- `renderFailed`: Rendering failures
- `resourceExhausted`: Memory limits
- `internalError`: Implementation bugs

### Diagnostics Integration

The capsule emits detailed diagnostic spans for:
- Parse operations with timing
- Render operations with output size
- Validation with error details
- Visitor traversal statistics

## Performance

- **Memory Efficient**: Streaming parser for large documents
- **Concurrent Safe**: Actor-based isolation
- **Lazy Rendering**: On-demand output generation
- **Caching**: Token and node reuse where possible

## Testing

Comprehensive test suite includes:
- Unit tests for all parsing operations
- Golden tests for output verification
- Error handling validation
- Performance benchmarks
- Memory leak detection

Run tests:
```bash
swift test --package-path Packages/MarkdownCapsule
```

## Integration

### CapsuleCore Protocol Compliance

```swift
extension MarkdownCapsule: CapsuleLifecycle {
    public func activate() async throws {
        // Initialization logic
    }

    public func deactivate() async {
        // Cleanup logic
    }
}
```

### Telemetry Integration

```swift
let span = diagnostics.beginSpan(
    name: "markdown.parse",
    category: "MarkdownCapsule",
    tags: ["format": "commonmark"]
)
// ... parsing logic
span.end(status: .ok)
```

## Version History

### v1.0.0
- Initial Tier 1 implementation
- Full CommonMark compliance
- AST generation and visitor pattern
- Multi-format rendering
- Comprehensive diagnostics

## License

This capsule is part of the Anigma project and follows the same licensing terms.