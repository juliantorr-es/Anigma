# Integration Plan for swift-syntax Concepts

This file outlines a phased implementation plan for adapting valuable concepts from swift-syntax into Anigma's architecture. It distinguishes between what already exists in Anigma and what would need to be built.

## Phase 1: Initial Porting / Proof of Concept

*   **Goal**: Implement core AST lens service with caching and location lookup.
*   **Existing Anigma Components**: 
    - `SwiftAstLens` (basic caching, location lookup)
    - `RewriteRule` protocol (trust tier integration)
    - `AgSearchService` (fast code search prefilter)
    - `HarmoniaMemory` (persistent storage)
*   **New Anigma Components/Systems Needed**:
    - `ASTLensProtocol` contract artifact
    - `SyntaxNodeComponent`, `ParentComponent`, `ChildrenComponent` ECS components
    - `IncrementalParseTransition`-inspired caching system
    - `SourceLocationConverter` integration with `FileLocation`
*   **Challenges**: 
    - Integrating SwiftSyntax's immutable tree model with ECS mutable entities.
    - Ensuring thread safety across actor‑isolated cache and parser.
    - Maintaining precise source locations after transformations.

## Phase 2: Feature Integration

*   **Goal**: Integrate rewrite rule protocol with precise change tracking and receipt generation.
*   **Existing Anigma Workflow**: 
    - Code search → AST analysis → rule application → commit (governed by Harmonia).
    - `RewritePipeline` chains rules; each rule validated against trust tier.
*   **Harmonia Integration**: 
    - Policy checks before/after each transformation (trust tier, project policies).
    - CCTV events for each `SourceEdit` with before/after state.
    - Receipt validation (hash chain, Accessum signature) before commit.
*   **MLX Integration**: 
    - Use ML models to suggest rewrite rules (e.g., auto‑refactoring patterns).
    - Local inference for privacy‑sensitive codebases.
    - ML‑generated transformations require higher trust tiers and additional validation.

## Phase 3: Hardening & Production Readiness

*   **Goal**: Ensure AST transformation subsystem meets Anigma's production standards (court‑safe, performant, governable).
*   **Testing**:
    - Unit tests: AST round‑trip validation, visitor/rewriter correctness.
    - Integration tests: End‑to‑end rewrite workflows with receipt verification.
    - Performance tests: Incremental parsing under load, cache eviction, memory usage.
    - Security tests: Injection attacks via malicious source code, privilege escalation.
*   **CCTV Logging**:
    - Every AST parse → `AstParsedEvent` (file hash, duration, cache hit/miss).
    - Every rewrite rule application → `RuleAppliedEvent` (rule name, trust tier, changed lines).
    - Every receipt generation → `ReceiptCreatedEvent` (receipt hash, signer, timestamp).
    - Every receipt validation → `ReceiptValidatedEvent` (valid/invalid, reason).
*   **Policy & Governance**:
    - Define `ASTTransformationPolicy` with trust tier requirements per rule type.
    - Enforce memory limits for AST caches (eviction policies, monitoring).
    - Require dual‑signature for high‑risk transformations (gold/platinum tiers).
    - Implement rollback capability via receipt chain (undo transformations).

## Phase 4: Advanced Features & Optimization

*   **Goal**: Add incremental parsing, arena allocation, and macro integration.
*   **Existing Anigma Components**:
    - `HarmoniaMemory` SQLite backend for persistent cache.
    - `ArenaAllocator` prototype in `AnigmaPrimitives`.
    - `MacroExpansionComponent` for governance macros.
*   **New Components/Systems Needed**:
    - `IncrementalParseTransition` system that reuses unchanged subtrees.
    - `RawSyntaxArena`‑style allocator for high‑performance AST construction.
    - `SyntaxClassifier` for token‑level semantic analysis.
    - `OperatorTable` for DSL precedence/associativity.
*   **Challenges**:
    - Incremental parsing requires accurate position mapping across edits.
    - Arena allocation must integrate with Swift's memory model and ARC.
    - Macro expansion must respect governance boundaries (no arbitrary code execution).

## Phase 5: Documentation & Ecosystem

*   **Goal**: Document patterns, create examples, and integrate with broader Anigma ecosystem.
*   **Documentation**:
    - Update `AGENTS.md` with AST transformation capabilities.
    - Create `Docs/architecture/ast-transformation.md` detailing design decisions.
    - Write tutorial: "Building a Governed Rewrite Rule in Anigma."
*   **Examples**:
    - Demo: Automated Swift 6 migration rule (add `@Sendable` where required).
    - Demo: Code style enforcement (formatting, naming conventions).
    - Demo: Security linting (detect unsafe patterns, suggest fixes).
*   **Ecosystem Integration**:
    - Plug into `AnigmaCLI` as `anigma ast` subcommands (parse, query, transform).
    - Integrate with `AtlasumWeb` for browser‑based code analysis.
    - Connect to `Observatorium` for real‑time transformation monitoring.

## Success Metrics

1. **Performance**: 90% cache hit rate for incremental parsing; sub‑second AST queries on 10k‑line files.
2. **Governance**: 100% of transformations generate CCTV events and signed receipts.
3. **Reliability**: Zero data loss in cache; rollback works for any applied transformation.
4. **Usability**: At least three production‑ready rewrite rules (e.g., `AddSendableToValueTypesRule`).
5. **Security**: No privilege escalation via malicious AST injection; all receipts cryptographically verifiable.

## Rollout Strategy

1. **Alpha**: Internal testing with synthetic codebases; gather performance baselines.
2. **Beta**: Pilot with trusted external contributors on small open‑source Swift projects.
3. **GA**: Full rollout to all Anigma users; enable by trust tier (bronze → platinum).
4. **Post‑GA**: Continuous monitoring, optimization, and rule marketplace (community‑contributed rules with governance review).

By following this plan, Anigma can systematically adopt swift‑syntax's robust patterns while maintaining its core governance principles and production‑hardened security.