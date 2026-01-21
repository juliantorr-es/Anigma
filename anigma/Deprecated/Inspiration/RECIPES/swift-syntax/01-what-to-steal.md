# What to Steal from swift-syntax

This file identifies concrete patterns, APIs, data models, or system boundaries from the swift-syntax repository that are worth adapting or re-implementing in Anigma. Remember: "Interpret and re-design," not "copy and adapt."

## Key Patterns / Concepts

### 1. Immutable Syntax Tree with Parent References
- **Pattern**: Syntax nodes are immutable value types that retain references to parent nodes, enabling efficient traversal both up and down the tree.
- **Adaptation**: Represent AST nodes as ECS entities in AnigmaCore, with parent/child relationships as components. Immutability ensures thread safety and enables caching.

### 2. Visitor Pattern with Generated Double-Dispatch
- **Pattern**: `SyntaxVisitor` provides type-safe traversal via generated `visit` methods for each node type. Visitors can skip subtrees or stop early.
- **Adaptation**: Generate visitor stubs for Anigma's AST node types (using Sourcery or similar). Use protocol-oriented design to allow different traversal strategies (source-accurate, fixed-up).

### 3. Rewriter Pattern for Transformations
- **Pattern**: `SyntaxRewriter` is a visitor that rebuilds the tree, allowing node replacement, insertion, deletion. It uses arena allocation to minimize copying.
- **Adaptation**: Create `ASTRewriter` as an ECS system that transforms node components. Track changes as `SourceEdit` components for audit trails.

### 4. Source Location Mapping
- **Pattern**: `SourceLocationConverter` maps `AbsolutePosition` (byte offset) to `SourceLocation` (line, column, offset) and vice versa.
- **Adaptation**: Integrate with Anigma's `FileLocation` system. Cache line maps for efficient lookup across large files.

### 5. Incremental Parsing and Caching
- **Pattern**: `IncrementalParseTransition` reuses unchanged subtrees when a file is reparsed, using position mapping.
- **Adaptation**: Implement incremental AST updates in `SwiftAstLens` using content hashing and subtree caching. Use HarmoniaMemory for persistent cache.

### 6. Diagnostic and FixIt Framework
- **Pattern**: `Diagnostic` provides structured error/warning messages; `FixIt` suggests edits with source ranges.
- **Adaptation**: Extend Anigma's `GovernanceEvent` system to include AST diagnostics. Use `FixIt` as a prototype for transformation receipts.

### 7. Arena Allocation for Syntax Nodes
- **Pattern**: `RawSyntaxArena` and `BumpPtrAllocator` provide fast, deterministic memory allocation for syntax nodes.
- **Adaptation**: Use Swift's `UnsafeBufferPointer` and custom allocators for high-performance AST construction in memory-constrained environments (ML worker).

### 8. Syntax Classification and Highlighting
- **Pattern**: `SyntaxClassifier` assigns semantic roles (keyword, identifier, string literal) to tokens for syntax highlighting.
- **Adaptation**: Integrate with Anigma's code search and analysis services to improve pattern matching.

### 9. Operator Precedence and Associativity
- **Pattern**: `OperatorTable` manages operator precedence and associativity for expression parsing.
- **Adaptation**: Use for custom DSLs within Anigma (e.g., query language for code search).

### 10. Macro Integration Points
- **Pattern**: `Syntax+LexicalContext` provides context for macro expansions.
- **Adaptation**: Support for Anigma's macro system (e.g., governance macros that inject policy checks).

## Potential Adaptations for Anigma

### AST Lens Service
- **Current State**: `SwiftAstLens` provides basic caching and location lookup.
- **Adaptation**: Extend with incremental parsing, parent references, and visitor support. Implement `ASTLensProtocol` for contract compliance.
- **Governance Hooks**: Cache eviction policies, memory limits, audit logs for cache hits/misses.

### Rewrite Rule Protocol
- **Current State**: `RewriteRule` protocol exists with trust tier integration.
- **Adaptation**: Add `SyntaxRewriter`-style transformation with precise change tracking. Support composition and idempotency validation.
- **Governance Hooks**: Trust tier enforcement, Harmonia policy checks before/after transformation, CCTV events for each change.

### Transformation Receipts
- **Current State**: ML worker produces Accessum-signed artifacts.
- **Adaptation**: Create `TransformationReceipt` that includes before/after hashes, `SourceEdit` list, diagnostic messages, and Accessum signature.
- **Governance Hooks**: Receipt validation (hash chain), signature verification, expiry timestamps.

### Syntax Analysis Contract
- **Current State**: No explicit contract for syntax analysis.
- **Adaptation**: Define `SyntaxAnalysisContract` that specifies authority boundaries between parsing, analysis, and transformation.
- **Governance Hooks**: Contract enforcement via Harmonia, boundary tickets for cross-module calls.

## Design Principles to Adopt

1. **Immutability by Default**: All AST nodes are immutable; transformations produce new trees.
2. **Value Semantics**: Syntax nodes are value types, enabling efficient copying and sharing.
3. **Arena Allocation**: Use custom allocators for performance-critical tree construction.
4. **Incremental Updates**: Cache and reuse unchanged subtrees to minimize parsing overhead.
5. **Precise Source Mapping**: Maintain accurate line/column information for error reporting and tooling.
6. **Structured Diagnostics**: Provide machine-readable error messages with suggested fixes.
7. **Extensibility via Visitors**: Allow external tools to traverse and analyze the AST without modifying core.

## Patterns to Avoid

1. **Tight Coupling to Swift Compiler**: SwiftSyntax depends on Swift compiler internals; Anigma must remain compiler-agnostic.
2. **Complex Generated Code**: SwiftSyntax uses extensive code generation; we should generate only what's necessary.
3. **Parser Implementation**: Do not reimplement Swift parser; use SwiftSyntax as a library but wrap it behind contracts.
4. **Bazel/CMake Build System**: Stick to SwiftPM for simplicity.

## Integration Priorities

1. **AST Lens Service** (high): Needed for code search, analysis, and transformation.
2. **Rewrite Rule Protocol** (high): Foundation for automated code migrations and refactorings.
3. **Transformation Receipts** (medium): Required for court-safe evidence of changes.
4. **Incremental Parsing** (medium): Performance optimization for large codebases.
5. **Diagnostic Framework** (low): Nice-to-have for user feedback.

By focusing on these patterns and adapting them to Anigma's governance model, we can build a powerful, court-safe AST transformation subsystem that leverages SwiftSyntax's proven design without copying its implementation.