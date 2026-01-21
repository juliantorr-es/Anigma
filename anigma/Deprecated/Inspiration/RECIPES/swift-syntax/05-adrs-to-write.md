# ADRs to Write for swift-syntax Integration

This file lists Architecture Decision Records (ADRs) that Anigma should write if it decides to adopt major ideas or architectural changes inspired by swift-syntax.

## Proposed ADRs

*   **ADR-XXXX: Adoption of Immutable AST with Parent References**
    *   **Context**: Anigma currently uses SwiftSyntax's mutable `SourceFileSyntax` directly, which makes caching and concurrent access difficult. SwiftSyntax's immutable tree with parent references enables efficient traversal, caching, and thread safety.
    *   **Decision**: Represent AST nodes as immutable ECS entities with `ParentComponent` and `ChildrenComponent`. All transformations produce new entity versions; old versions remain for undo/rollback.
    *   **Rationale**: Immutability simplifies caching, enables concurrent analysis, and aligns with functional transformation patterns. Parent references allow efficient upward traversal (e.g., finding enclosing function). SwiftSyntax's proven design reduces risk.
    *   **Reference**: See `01-what-to-steal.md` section "Immutable Syntax Tree with Parent References" and `02-anigma-mapping.md` mapping for AnigmaCore.

*   **ADR-YYYY: Standardization of AST Lens Protocol**
    *   **Context**: Multiple Anigma modules (`AgSearchService`, `RewritePipeline`, `SwiftAstLens`) need to query ASTs, but each uses ad‑hoc APIs. SwiftSyntax's `SyntaxProtocol` and `SourceLocationConverter` provide a unified query interface.
    *   **Decision**: Define `ASTLensProtocol` in ContractsCore, specifying methods for location lookup, type‑based search, caching, and incremental parsing. All AST access must go through this protocol.
    *   **Rationale**: Centralized contract ensures governance hooks (policy checks, CCTV events) are applied consistently. Enables swapping SwiftSyntax backend for other parsers (e.g., tree‑sitter). Improves testability via mocking.
    *   **Reference**: See `00-summary.md` "Target Modules" and `02-anigma-mapping.md` mapping for AnigmaASTServices.

*   **ADR-ZZZZ: Governed Rewrite Rule Protocol with Receipts**
    *   **Context**: Anigma's existing `RewriteRule` protocol lacks precise change tracking and evidence generation. SwiftSyntax's `SyntaxRewriter` and `SourceEdit` provide exact change descriptions; its `Diagnostic`/`FixIt` framework models evidence.
    *   **Decision**: Extend `RewriteRule` to `RewriteRuleProtocol` with mandatory `SourceChange` reporting and `TransformationReceipt` generation. All transformations must produce a signed receipt before commit.
    *   **Rationale**: Court‑safe evidence requires cryptographic receipts. Precise change tracking enables rollback, audit, and collaborative editing. SwiftSyntax's battle‑tested transformation patterns reduce implementation bugs.
    *   **Reference**: See `00-summary.md` "Contract Surface" and `01-what-to-steal.md` section "Rewrite Rule Protocol".

*   **ADR-AAAA: Incremental Parsing and Caching Strategy**
    *   **Context**: Parsing large codebases on every change is expensive. SwiftSyntax's `IncrementalParseTransition` reuses unchanged subtrees, dramatically improving performance.
    *   **Decision**: Implement incremental AST caching in `SwiftAstLens` using content hashing and subtree reuse. Cache persisted in `HarmoniaMemory` SQLite with LRU eviction.
    *   **Rationale**: Essential for interactive performance in IDEs and batch analysis of large repositories. SwiftSyntax's incremental algorithm is proven in Xcode and SwiftPM. Reduces CPU and memory overhead.
    *   **Reference**: See `01-what-to-steal.md` section "Incremental Parsing and Caching" and `03-integration-plan.md` Phase 4.

*   **ADR-BBBB: Arena Allocation for High‑Performance AST Construction**
    *   **Context**: Swift's ARC overhead can dominate AST transformation performance. SwiftSyntax's `RawSyntaxArena` and `BumpPtrAllocator` provide arena allocation, reducing ARC traffic and improving locality.
    *   **Decision**: Create `ArenaAllocator` in `AnigmaPrimitives` for AST node allocation. Use `UnsafeBufferPointer` and manual memory management for transformation‑heavy workloads (ML worker).
    *   **Rationale**: Performance critical for ML‑driven transformations on large codebases. Arena allocation is a known pattern for compiler‑like workloads; SwiftSyntax's implementation is optimized for Swift's memory model.
    *   **Reference**: See `01-what-to-steal.md` section "Arena Allocation for Syntax Nodes" and `02-anigma-mapping.md` mapping for AnigmaPrimitives.

*   **ADR-CCCC: Structured Diagnostics and FixIts as Governance Events**
    *   **Context**: Current error reporting in Anigma is unstructured (strings). SwiftSyntax's `Diagnostic` and `FixIt` provide machine‑readable error descriptions with suggested edits.
    *   **Decision**: Extend `GovernanceEvent` to include `ASTDiagnostic` and `FixIt` payloads. Use for transformation feedback, policy violations, and user‑friendly suggestions.
    *   **Rationale**: Structured diagnostics enable automated handling (e.g., auto‑apply fixes with user approval). `FixIt` model aligns with receipt‑based rewriting (evidence of suggested vs. applied changes). Improves user experience and auditability.
    *   **Reference**: See `01-what-to-steal.md` section "Diagnostic and FixIt Framework" and `02-anigma-mapping.md` mapping for ContractsCore.

*   **ADR-DDDD: Macro Integration via Lexical Context**
    *   **Context**: Anigma's macro system needs AST context for expansion (e.g., surrounding scope, visibility). SwiftSyntax's `Syntax+LexicalContext` provides this context.
    *   **Decision**: Add `LexicalContextComponent` to AST entities, populated during parsing. Use for macro expansion, name resolution, and governance policy injection.
    *   **Rationale**: Macros are powerful and require precise context to avoid hygiene issues. SwiftSyntax's approach is used by Swift's own macro system, ensuring correctness. Enables governance macros (e.g., `@Governed` attribute).
    *   **Reference**: See `01-what-to-steal.md` section "Macro Integration Points" and `02-anigma-mapping.md` mapping for AnigmaASTServices.

*   **ADR-EEEE: Syntax Classification for Semantic Search**
    *   **Context**: Code search currently relies on text matching; semantic search (e.g., "find all function calls") requires token classification. SwiftSyntax's `SyntaxClassifier` assigns roles (keyword, identifier, literal).
    *   **Decision**: Integrate syntax classification into `AgSearchService`. Store token roles as `TokenRoleComponent` for fast querying.
    *   **Rationale**: Enables more accurate code search (e.g., distinguish between `print` as function call vs. variable name). Foundation for advanced IDE features (highlighting, refactoring). Leverages SwiftSyntax's built‑in classifier.
    *   **Reference**: See `01-what-to-steal.md` section "Syntax Classification and Highlighting" and `02-anigma-mapping.md` mapping for AnigmaASTServices.

## ADR Prioritization

1. **High Priority**: ADR-YYYY (AST Lens Protocol) and ADR-ZZZZ (Governed Rewrite Rule Protocol) – these define the core contracts and must be agreed before implementation.
2. **Medium Priority**: ADR-XXXX (Immutable AST) and ADR-AAAA (Incremental Parsing) – performance and correctness foundations.
3. **Lower Priority**: ADR-BBBB (Arena Allocation), ADR-CCCC (Structured Diagnostics), ADR-DDDD (Macro Integration), ADR-EEEE (Syntax Classification) – advanced optimizations and features.

## ADR Template References

Each ADR should follow the standard template in `Docs/ADR/template.md` and include:

- **Status**: Proposed (until approved)
- **Decision Drivers**: Performance, governance, correctness, developer experience
- **Considered Options**: List alternatives (e.g., keep current mutable AST, use third‑party parser)
- **Consequences**: Positive (improved performance, auditability) and negative (complexity, learning curve)
- **Compliance**: How the decision aligns with Anigma Constitution and governance principles
- **Evidence**: Links to swift‑syntax source files, benchmarks, and prior art

By writing these ADRs, Anigma can make informed, documented decisions about integrating swift‑syntax's patterns while maintaining architectural coherence and governance compliance.