# Anigma Code Doctrine

**Document ID:** CODE-DOCTRINE-2026-001  
**Version:** 1.0  
**Status:** ACTIVE  
**Owner:** Architecture Team  
**Last Updated:** 2026-05-03

---

## Purpose

Canonical home for code-level doctrine that affects how Anigma interprets source, validates behavior, and decides when upstream tooling evidence is strong enough to justify implementation.

## SwiftSyntax Validator Strategy

**Rule:** Code validations must leverage SwiftSyntax AST parsing rather than regex-based source checking.

**Rationale:**
SwiftSyntax provides high-fidelity representations of Swift code without requiring a full compiler invocation. 
- **Import Declarations:** Validators should inspect `ImportDeclSyntax` nodes to prevent `@_exported` import leakage across architectural tier boundaries (e.g., Tier 1).
- **Actor Isolation:** `ActorDeclSyntax` nodes should be visited to ensure proper Sendable conformances and isolated contexts inside AnigmaGovernance.
- **Test Compliance:** Receipts and test macros should be validated via AST visitor passes.

**Implementation Policy:**
Validators using SwiftSyntax must remain independent tooling scripts or non-production dependencies. Do not vendor SwiftSyntax into Anigma daemon runtime logic. Regex may be used as a cheap prefilter only; final doctrine enforcement should come from syntax-aware inspection where practical.
