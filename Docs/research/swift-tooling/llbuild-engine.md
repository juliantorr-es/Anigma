# LLBuild Engine

**Source Repository:** `swiftlang/swift-llbuild`
**Commit:** `fd2284d2affcb33ed0ac88c1db861f73bc56a031`
**Key File:** `lib/Core/BuildEngine.cpp`
**Key Symbols:** `class BuildEngineImpl` (L65)

## Build Engine Architecture
Located in `lib/Core/BuildEngine.cpp` (L65), `BuildEngineImpl` acts as the `BuildDBDelegate`. It tracks state and coordinates tasks. The engine uses deterministic file signatures and records them in the build database to minimize redundant rebuilds. The upstream logic relies on this cryptographic tracking, not purely on file timestamps or text output.

## Anigma Doctrine Takeaways
- **Evidence Surfaces:** LLBuild relies heavily on file signatures and manifest matching for determinism. Anigma's build doctrines should leverage the incremental database/manifest context as source-grounded evidence of incremental state instead of blindly assuming `swift build` text output behavior.
