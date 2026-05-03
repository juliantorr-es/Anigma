# SwiftSyntax Validator Design

**Source Repository:** `swiftlang/swift-syntax`
**Commit:** `51c8c237beea1baa9cac64ef83cec68c6790506c`
**Key Files:** `Sources/SwiftSyntax/generated/syntaxNodes/SyntaxNodesGHI.swift` and `SyntaxNodesAB.swift`
**Key Symbols:** `ImportDeclSyntax` (L2939), `ActorDeclSyntax` (L1416)

## Structure and Capabilities
SwiftSyntax provides a full fidelity AST of Swift code without requiring a compiler invocation. The nodes `ImportDeclSyntax` and `ActorDeclSyntax` are heavily code-generated structures that map directly to the Swift AST. For instance, `ImportDeclSyntax` correctly tracks attributes like `@_exported`.

## Anigma Doctrine Takeaways
- **Validator Strategy:** Anigma validators (e.g., for tier isolation, contract purity, or test receipt compliance) should use SwiftSyntax AST visitors.
- **Import Hygiene:** `ImportDeclSyntax` can be natively visited to ensure no `@_exported` leakage occurs across Tier 1 boundary walls, entirely bypassing fragile regex.
- **Actor Isolation:** `ActorDeclSyntax` can be validated to ensure proper Sendable and isolation conformances in AnigmaGovernance.
- **No Vendor Policy:** Do not vendor SwiftSyntax into Anigma; use it as a standard package dependency for tooling/scripts.
