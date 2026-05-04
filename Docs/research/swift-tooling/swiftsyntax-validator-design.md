# SwiftSyntax Validator Design

**Source Repository:** `swiftlang/swift-syntax`
**Commit:** `51c8c237beea1baa9cac64ef83cec68c6790506c`
**Key Files:** `Sources/SwiftSyntax/generated/syntaxNodes/SyntaxNodesGHI.swift` and `SyntaxNodesAB.swift`
**Key Symbols:** `ImportDeclSyntax` (L2939), `ActorDeclSyntax` (L1416)

## Structure and Capabilities
SwiftSyntax provides a full fidelity AST of Swift code without requiring a compiler invocation. The nodes `ImportDeclSyntax` and `ActorDeclSyntax` are heavily code-generated structures that map directly to the Swift AST. For instance, `ImportDeclSyntax` correctly tracks attributes like `@_exported`.

## 2. Context7 API Documentation Insights
Querying the Context7 API for `swiftlang/swift-syntax` provides additional context on the design goals of SwiftSyntax:
- SwiftSyntax encodes the production rules of the Swift grammar into a tree-shaped data structure. Nodes represent grammatical productions, with properties corresponding to their child productions.
- The syntax tree reflects both lexical structure (whitespace/positions) and syntactic structure, which is crucial for robust validators.
- **Resilience:** The syntax tree is resilient and can represent well-formed and ill-formed code, using a `SourcePresence/missing` presence. This allows Anigma validators to fail gracefully on malformed ASTs without crashing the tooling orchestrator.

## Anigma Doctrine Takeaways
- **Validator Strategy:** Anigma validators (e.g., for tier isolation, contract purity, or test receipt compliance) should use SwiftSyntax AST visitors.
- **Import Hygiene:** `ImportDeclSyntax` can be natively visited to ensure no `@_exported` leakage occurs across Tier 1 boundary walls, entirely bypassing fragile regex.
- **Actor Isolation:** `ActorDeclSyntax` can be validated to ensure proper Sendable and isolation conformances in AnigmaGovernance.
- **No Vendor Policy:** Do not vendor SwiftSyntax into Anigma; use it as a standard package dependency for tooling/scripts.
