# SwiftPM Tooling Boundaries

## Official Sources
- **SwiftPM Documentation**: [swift.org](https://www.swift.org/package-manager/)

## Findings
SwiftPM strictly separates **targets** (modules) from **products** (libraries/executables).
- Targets are the basic building blocks.
- Products define what is exported to clients.

## Anigma Application
- **Graph Hygiene**: To enforce portable contracts, generic ECS-inspired data structures (components) must reside in targets that have **zero** dependencies on native executor targets (e.g., targets linking Metal, CUDA, or PDFium).
- **Containment**: Native linker settings (`.linkedLibrary`, `.unsafeFlags`) must be confined to leaf execution targets or sidecar executables.
- **Sidecar Isolation**: Heavy native dependencies (like an external Python ML environment or complex C++ integrations) should be compiled as separate executable products (sidecars) to prevent linker contamination of the core daemon.