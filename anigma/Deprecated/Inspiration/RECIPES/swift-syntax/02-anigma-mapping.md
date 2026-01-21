# Anigma Mapping for swift-syntax

This file provides a direct mapping from concepts found in swift-syntax to Anigma's modules and architectural layers. This ensures that new ideas are integrated without inventing parallel frameworks.

## Mapping Table

| Inspiration Repo Concept | Anigma Module / Layer | Notes / Rationale |
|--------------------------|-----------------------|-------------------|
| Immutable Syntax Tree | AnigmaCore (ECS Entities) | Represent AST nodes as ECS entities with `SyntaxNodeComponent`. Immutability via entity versioning; parent/child relationships via `ParentComponent`/`ChildrenComponent`. |
| SyntaxVisitor | AnigmaASTServices (Visitor System) | Generate type-safe visitor stubs for each node type; integrate with `SwiftAstLens` for caching and traversal. |
| SyntaxRewriter | AnigmaASTServices (Rewrite System) | Extend existing `RewriteRule` protocol with `ASTRewriter` that transforms ECS entities; track changes as `SourceEditComponent`. |
| SourceLocationConverter | AnigmaCore (FileLocation) | Extend `FileLocation` with line/column mapping; cache line maps for performance. |
| IncrementalParseTransition | AnigmaASTServices (Caching) | Enhance `SwiftAstLens` with incremental parsing using content hashing and subtree caching; store cache in HarmoniaMemory. |
| Diagnostic / FixIt | ContractsCore (Governance Events) | Extend `GovernanceEvent` to include AST diagnostics; use `FixIt` as prototype for transformation receipts. |
| RawSyntaxArena / BumpPtrAllocator | AnigmaPrimitives (Memory Allocator) | Create `ArenaAllocator` for high-performance AST construction in ML worker; integrate with `UnsafeBufferPointer`. |
| SyntaxClassifier | AnigmaASTServices (Classification) | Add syntax classification for code search and pattern matching; output as `TokenRoleComponent`. |
| OperatorTable | ContractsCore (DSL Support) | Use for custom query language in code search; maintain precedence/associativity as contract artifact. |
| Syntax+LexicalContext | AnigmaASTServices (Macro Integration) | Provide context for macro expansions in Anigma's macro system; integrate with `MacroExpansionComponent`. |
| SwiftBasicFormat | AnigmaASTServices (Formatting) | Implement code formatting as rewrite rules; integrate with Harmonia's style guide enforcement. |
| SwiftParser | AnigmaASTServices (Parsing) | Wrap SwiftSyntax's parser behind `ASTLensProtocol`; isolate parser dependency to prevent leakage. |
| SwiftDiagnostics | ContractsCore (Error Reporting) | Structured error reporting for contract violations; integrate with Harmonia's audit trail. |
| SwiftIDEUtils | AnigmaASTServices (Tooling) | IDE‑like features (rename, find references) as governed tools; require trust tier and receipts. |
| SwiftOperators | ContractsCore (Operator Precedence) | Manage operator precedence for DSLs; enforce via contract boundaries. |
| SwiftSyntaxMacros | AnigmaASTServices (Macro Support) | Macro expansion infrastructure; integrate with Anigma's governance macros. |

## Module-Specific Implementation Plans

### AnigmaASTServices
- **ASTLensProtocol**: Define contract for queryable AST views with caching, location lookup, and visitor support.
- **SwiftAstLens Enhancement**: Add incremental parsing, parent references, and visitor integration.
- **RewriteRule Extension**: Add `ASTRewriter` base class with precise change tracking and arena allocation.
- **Syntax Analysis**: Provide APIs for finding nodes by type, location, or pattern; integrate with `AgSearchService`.
- **Macro Integration**: Support for macro expansion contexts and lexical scoping.

### ContractsCore
- **RewriteRuleProtocol**: Extend existing `RewriteRule` with governance hooks (trust tiers, policy checks, CCTV events).
- **TransformationReceiptProtocol**: Define receipt structure with before/after hashes, source edits, diagnostics, and Accessum signature.
- **SyntaxAnalysisContract**: New contract artifact specifying authority boundaries between parsing, analysis, and transformation.
- **Diagnostic Framework**: Structured error reporting with `FixIt` suggestions; integrate with governance events.

### AnigmaCore
- **ECS Representation**: `SyntaxNodeComponent`, `ParentComponent`, `ChildrenComponent`, `SourceEditComponent`, `TokenRoleComponent`.
- **World Integration**: AST transformations as ECS systems; use `Scheduler` for ordered rule application.
- **Memory Management**: `ArenaAllocator` for high‑performance AST construction; integrate with `HarmoniaMemory`.

### Harmonia
- **Policy Checks**: Validate AST transformations against trust tiers and project policies.
- **CCTV Events**: Emit audit events for each rewrite with before/after state and receipt hash.
- **Receipt Validation**: Verify transformation receipts (hash chain, signatures) before committing changes.
- **Cache Governance**: Enforce memory limits and eviction policies for AST caches.

### DatabaseCore
- **Persistent Cache**: Store AST cache in SQLite via `HarmoniaMemory` for incremental parsing across sessions.
- **Receipt Storage**: Archive transformation receipts for auditability and rollback support.
- **Change History**: Track source edits over time for code evolution analysis.

### ML Worker Integration
- **Receipt Signing**: Use Accessum hardware‑backed signing for transformation receipts.
- **Evidence Generation**: Produce court‑safe artifacts for each rewrite (legal timestamps, canonical serialization).
- **Model Integration**: Use ML models for intelligent code transformations (e.g., auto‑refactoring) with governance oversight.

## Authority Boundaries

1. **Parsing Boundary**: Only `AnigmaASTServices` may invoke SwiftSyntax parser; all other modules access AST via `ASTLensProtocol`.
2. **Transformation Boundary**: Only `ContractsCore`‑registered rewrite rules may modify AST; each transformation requires a receipt.
3. **Governance Boundary**: `Harmonia` must approve all transformations via policy checks and CCTV events.
4. **Evidence Boundary**: `ML Worker` signs receipts; `DatabaseCore` stores evidence; `Harmonia` validates.

## Cross‑Module Changes: Three‑Pass Pipeline

### Pass 1 (Contract)
- Add contract artifacts for `ASTLensProtocol`, `RewriteRuleProtocol`, `TransformationReceiptProtocol`.
- Define authority boundaries, surface API, concurrency model, stop conditions, acceptance tests, migration plan.

### Pass 2 (Implementation)
- Implement behind the surface inside `AnigmaASTServices` and `ContractsCore`.
- No new public APIs beyond the contract artifact.
- Mutable state must stay actor‑isolated.

### Pass 3 (Migration/Hardening)
- Swap call sites to the new surface.
- Add adapters only behind the surface.
- Add regression tests and logging/evidence hooks.
- Document quarantine/backstop behavior.

## Integration Timeline

### Phase 1 (Current Sprint)
- Create contract artifacts and mapping document (this recipe).
- Update `AGENTS.md` with AST transformation capabilities.
- Run governance gates to ensure compliance.

### Phase 2 (Next Sprint)
- Implement `ASTLensProtocol` and enhance `SwiftAstLens`.
- Extend `RewriteRule` protocol with governance hooks.
- Integrate receipt signing with Accessum.

### Phase 3 (Future Sprint)
- Add incremental parsing and caching.
- Implement `ASTRewriter` with arena allocation.
- Integrate with Harmonia policy checks and CCTV events.

### Phase 4 (Stabilization)
- Performance testing and optimization.
- Documentation and examples.
- Rollout to production with gradual trust tier escalation.

By following this mapping, Anigma can adopt swift‑syntax's proven patterns while maintaining strict governance boundaries and court‑safe evidence chains.