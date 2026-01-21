# swift-syntax Recipe for Anigma

## Overview

SwiftSyntax is Apple's Swift library for parsing, analyzing, and transforming Swift source code. It provides a complete abstract syntax tree (AST) representation of Swift code, with immutable value types, visitor and rewriter patterns, source location mapping, and diagnostic reporting. The library is used by Swift compiler tools, code formatters, refactoring tools, and IDE features.

Key features:
- **Immutable Syntax Trees**: Thread-safe, shareable AST nodes with parent references.
- **Visitor/Rewriter Patterns**: Type-safe traversal and transformation via generated visitor methods.
- **Source Location Mapping**: Precise line/column to node mapping with `SourceLocationConverter`.
- **Incremental Parsing**: Efficient updates to changed parts of syntax trees.
- **Diagnostic Framework**: Structured error messages with suggested fixes (`FixIt`).
- **Arena Allocation**: High-performance memory management for syntax nodes.

## Relevance to Anigma

SwiftSyntax provides architectural patterns for building governed AST transformation services in Anigma. Specifically:

1. **AST Lens Service**: Queryable AST views with caching and location lookup—essential for code analysis and search.
2. **Rewrite Rule Protocol**: Idempotent transformation rules with precise change tracking—foundational for automated code migrations.
3. **Receipt-Based Rewriting**: Diagnostic and `FixIt` frameworks provide a model for evidence collection and audit trails.

These patterns align with Anigma's governance requirements:
- **Policy Enforcement**: Transformations can be gated by trust tiers and Harmonia validation.
- **Audit Trails**: Every rewrite can generate CCTV events with before/after state.
- **Evidence Requirements**: Transformation receipts can be cryptographically signed by Accessum for court-safe provenance.

By adapting SwiftSyntax's patterns (not copying its code), Anigma can build a governed AST transformation subsystem that is production-hardened, court-safe, and integrated with Harmonia's trust framework.

## Target Modules
- **Primary**: AnigmaASTServices
- **Secondary**: ContractsCore

## Contract Surface
- **New Contracts**: 
  - ASTLensProtocol
  - RewriteRuleProtocol  
  - TransformationReceiptProtocol
- **Extended Contracts**:
  - Existing SyntaxAnalysisContract (to be created)
- **Authority Boundaries**: AST manipulation isolated in AnigmaASTServices, transformation rules governed by ContractsCore

## Governance Hooks Required
- **Policy Checks**: All AST transformations must pass through Harmonia validation
- **Audit Events**: Every rewrite generates CCTV event with before/after state
- **Evidence Requirements**: Transformation receipts with cryptographic hash, signed by Accessum

## Test Harness Strategy
- **Unit Tests**: AST roundtrip validation, transformation contract tests
- **Integration Tests**: End-to-end rewrite workflows with receipt verification
- **Invariant Validation**: Harmonia enforces "no unsigned AST mutations"

## Builder-Ready Work Package

### Phase 1: Contract Definition (Architect)
- Define ASTLensProtocol for queryable AST views
- Define RewriteRuleProtocol for deterministic transformations
- Define TransformationReceiptProtocol for evidence generation

### Phase 2: Implementation (Builder)
- Implement AST lens service in AnigmaASTServices
- Create rewrite rule registry in ContractsCore
- Integrate receipt generation with Accessum signing

### Phase 3: Validation (Validator)
- Contract compliance tests
- Harmonia governance integration tests
- Receipt verification workflow tests

### Phase 4: Documentation (Scribe)
- Update AGENTS.md with new AST transformation capabilities
- Document rewrite rule DSL in Architecture docs
- Create integration examples

## Explicit "Do Not Copy" Provenance Note
- **DO NOT COPY**: SwiftSyntax library dependencies, parsing pipelines, source file readers
- **DO NOT COPY**: Swift compiler integration, build system hooks
- **REIMPLEMENT REQUIRED**: AST tree structure as AnigmaCore entities, transformation logic as ECS systems

Focus on the architectural patterns:
1. **AST Lens Service** - Queryable AST views with contracts
2. **Rewrite Rule Protocol** - Deterministic transformation contracts  
3. **Receipt-Based Rewriting** - Every rewrite is an Action with evidence