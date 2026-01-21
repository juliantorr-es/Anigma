# Native Library Intake Contract: tree-sitter

## Purpose
This library exists in Anigma to provide: fast incremental parsing across multiple languages for syntax tree-based symbol indexing.
It is used by: MakerEngineEnhancements module for RepoMapIndexer.
It must never be imported outside: Sources/MakerEngineEnhancements/Adapters/.

## Authority Boundary
Native surface owner: Sources/ExternalC/Parsing/tree-sitter  
Swift wrapper owner: Sources/MakerEngineEnhancements/Adapters/RepoMapIndexer  
Allowed call sites: MakerEngineEnhancements only (RepoMapIndexer, SymbolResolver)

Hard rule: no other target may import the native target directly.

## Distribution Strategy
Linking model: systemLibrary  
Acquisition: bundled language-specific grammars + system tree-sitter

Reproducibility requirement:
The exact version used must be identifiable from source control, build logs, and runtime metadata.

## Version Pin
Upstream project: tree-sitter  
Version/Tag: 0.22.6+  
Commit hash (if applicable): N/A (system library)  
Local patch policy: Language grammar versions pinned in Package.swift

## License and Compliance
License: MIT  
Attribution file: Docs/licenses/tree-sitter.txt  
App Store suitability: allowed

## Security Posture
Threat model: parsing malicious source code, pathological grammars  
Memory safety risks: owned pointers, tree traversal, node lifecycle  
Mitigations: Parser validates inputs, bounded recursion limits, actor isolation

## API Contract
Wrapper API must be:
- Deterministic for same inputs (parsing is deterministic)
- Threading model defined (RepoMapIndexer actor manages all parsing)
- Ownership model explicit (RepoMapIndexer owns parser instances)
- Incremental updates only

Error mapping:
Native errors map to typed ParseError enum; never leak raw error codes.

## Core Capabilities Required

### Fast Symbol Indexing
- `ts_parser_parse_string()` with language-specific grammars
- Symbol extraction via tree queries
- Cross-language symbol resolution

### Incremental Updates
- Tree editing with `ts_tree_edit()` for file changes
- Incremental re-parsing of modified regions
- Cache invalidation for dependent symbols

### Multi-Language Support
- Swift, TypeScript, Python, Rust, C++ grammars
- Language-agnostic symbol interface
- Grammar version pinning for reproducibility

## Build and Tooling
SwiftPM target name(s): tree-sitter (system library)  
Expected build flags: -DTREE_SITTER_ENABLE_STACK_USAGE_PROTECTION  
Platform support: macOS, iOS, Linux

CI requirements:
- Builds on CI with deterministic configuration  
- Version recorded in build logs via ts_tree_language_version()
- Test incremental parsing performance

## Governance Hooks
Forbidden paths: native targets must not write outside their sandbox.  
Receipt requirements: any parsing operation emits a "ParseOperation" receipt including file hash, grammar version, and symbol count.

## Acceptance Tests
Golden tests for correctness: RepoMapIndexerTests  
Fuzz/safety tests: Pathological source code test suite  
Performance sanity: Incremental parse under 10ms for <1000 line changes  
Language coverage: All supported grammars tested with sample code

## Integration Requirements
- Replace grep-based heuristics with syntax-aware indexing
- Provide symbol search with type information
- Generate parsing receipts for governance compliance
- Integration with existing candidate generation patterns
