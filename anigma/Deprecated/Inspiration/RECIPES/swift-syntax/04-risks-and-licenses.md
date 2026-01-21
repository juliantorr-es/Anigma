# Risks and Licenses for swift-syntax

This file details the licensing terms, dependency risks, and overall security posture concerns related to swift-syntax. This information is critical for Anigma's compliance and "agent-safe" posture.

## Licensing Analysis

*   **Original License**: Apache License 2.0
*   **Compatibility with Anigma's Allowlist**: Yes. Apache 2.0 is explicitly allowed (see Docs/AnigmaConstitution.md). It is permissive, compatible with MIT, and allows commercial use, modification, distribution, and patent grants.
*   **Notes**: 
    - SwiftSyntax is part of the Swift project, which uses Apache 2.0 with Swift Runtime Library Exception for linking.
    - The "Runtime Library Exception" permits linking the library with proprietary software without requiring the proprietary software to be open source.
    - Anigma's use case (library dependency, not modification) falls under normal usage; no licensing conflicts expected.
    - However, Anigma's governance requires that **no code be copied directly**; only architectural patterns are to be adapted. This avoids any license contamination.

## Dependency Risks

*   **External Dependencies**: 
    - SwiftSyntax itself depends on the Swift compiler (`swift-syntax` is a standalone library but requires a Swift toolchain).
    - It has *no* external third‑party dependencies (no Python, Node.js, etc.).
    - Build‑time: Requires Swift 5.9+ and CMake/Bazel for building from source (already vendored in `Tools/Vendor/swift-syntax`).
*   **Vulnerability Concerns**:
    - As part of the Swift project, security vulnerabilities are tracked and patched promptly.
    - The library parses arbitrary source code; maliciously crafted source files could cause excessive memory usage or crashes (denial‑of‑service). Anigma must implement sandboxing and resource limits.
    - No known critical CVEs for SwiftSyntax as of December 2025.
*   **Build-time vs. Runtime Dependencies**:
    - Runtime: Pure Swift library; no external runtime dependencies.
    - Build‑time: Swift compiler, CMake, Bazel (only needed when rebuilding the vendored library). Anigma already vendors a pre‑built binary, so build‑time dependencies are irrelevant for end‑users.

## Security Posture Concerns

*   **Trust Model**: 
    - SwiftSyntax has no built‑in trust model; it is a low‑level library that assumes caller is responsible for security.
    - Anigma must wrap all calls with governance checks (trust tiers, policy validation, audit logging).
    - The library is not designed for multi‑tenant isolation; Anigma must enforce isolation at the Harmonia layer.
*   **Data Handling**: 
    - SwiftSyntax reads source code into memory; it does not persist data externally.
    - Privacy concern: Source code could contain sensitive information (keys, passwords). Anigma must ensure AST caching does not leak data across sessions (clear cache per‑session, encrypt cache at rest).
    - The library does not transmit data over network; all processing is local.
*   **Access Control**:
    - No internal access control; any code can call any API.
    - Anigma must enforce capability‑based access via `ToolDescriptor` and `ToolRegistry`; only authorized tools may invoke AST transformations.
*   **Code Quality**:
    - High quality, maintained by Apple and the Swift community.
    - Extensive test suite (unit, integration, fuzzing).
    - Written in Swift with strict concurrency checking (Swift 6).
    - Potential anti‑pattern: Heavy use of generated code (over 100k lines) can be difficult to audit. Anigma's adaptation should generate only minimal necessary stubs.
    - Large surface area (hundreds of public APIs) increases risk of misuse. Anigma should expose only a curated subset via `ASTLensProtocol`.

## Integration Risks

1. **Compiler Version Lock‑In**: SwiftSyntax is tied to Swift compiler versions; upgrading Swift may require upgrading SwiftSyntax. Anigma must pin to a compatible version and have a migration plan.
2. **Binary Size**: The library adds ~10 MB to the binary. Acceptable for desktop but may be heavy for embedded ML worker. Consider conditional compilation (omit when not needed).
3. **Performance Overhead**: Parsing large codebases can be CPU/memory intensive. Mitigation: incremental parsing, caching, background indexing.
4. **Thread Safety**: SwiftSyntax trees are immutable and thread‑safe, but parsing is not. Anigma must isolate parsing in actors and ensure proper synchronization.
5. **Error Handling**: SwiftSyntax can throw parsing errors on invalid source. Anigma must catch and convert to governance events (CCTV) rather than crashing.
6. **License Compliance**: Although Apache 2.0 is compatible, Anigma must ensure no direct copying of code (only patterns). Document all adaptations with provenance notes.

## Mitigation Strategies

- **Sandboxing**: Run AST parsing in a separate process with resource limits (CPU, memory, wall‑time).
- **Input Validation**: Reject source files above size limit, detect malicious patterns (e.g., billion laughs attack via nested comments).
- **Cache Encryption**: Encrypt AST cache at rest using Harmonia‑managed keys.
- **Audit Logging**: Log every parse and transformation with file hash (not content) for non‑repudiation.
- **Graceful Degradation**: If SwiftSyntax fails, fall back to simple regex‑based analysis (with reduced capabilities) and emit CCTV warning.
- **Version Pinning**: Vendor a specific SwiftSyntax release and update only after thorough testing and governance review.

## Legal Review Checklist

- [ ] Confirm Apache 2.0 compatibility with Anigma's legal counsel.
- [ ] Document that no code is copied—only architectural patterns are adapted.
- [ ] Add NOTICE file attribution for vendored SwiftSyntax binary (required by Apache 2.0).
- [ ] Ensure all derived work (e.g., generated visitor stubs) is clearly marked as Anigma's own implementation.
- [ ] Review Swift Runtime Library Exception for any implications on distribution.

By addressing these risks and complying with licensing terms, Anigma can safely leverage swift‑syntax's robust architecture while maintaining its security and governance standards.