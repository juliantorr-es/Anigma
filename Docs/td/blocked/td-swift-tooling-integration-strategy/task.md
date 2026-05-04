# Research Swift tooling integration strategy for self-hosted Anigma agents

**Priority:** P1 after backend normalization

**Parent / dependency:**
This task must not start until the backend normalization lane is complete and reviewed.

## Purpose
Determine whether Anigma should vendor, depend on, wrap, or shell out to Swift tooling so self-hosted Anigma agents can perform Swift development with reliable internal tools.

## Core question
Should Anigma integrate SwiftPM, SwiftSyntax, swift-driver, llbuild, and related Swift tooling as:
1. external CLI tools invoked through governed executors,
2. library dependencies in tooling-only modules,
3. vendored source snapshots,
4. sidecar services,
5. or a hybrid model?

## Initial recommendation to test
Do not vendor the whole Swift toolchain into Anigma runtime. Prefer:
- SwiftPM / swift build / swift test as governed external executors.
- SwiftPM JSON outputs normalized into Anigma-owned graph/receipt schemas.
- SwiftSyntax as a dependency for source-aware validators.
- swift-driver and llbuild studied as design references or optional tooling-sidecar dependencies, not runtime dependencies.
- No dependency on unstable SwiftPM internals in Anigma core runtime.

## Why this needs research
SwiftPM can be used as a library, but official docs warn that the libSwiftPM API is unstable and may change at any time. Swift forum discussion also says libSwiftPM does not maintain a stable semver-style API for third-party clients. That makes vendoring or depending directly on SwiftPM internals risky for Anigma core. ([docs.swift.org](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/swiftpmasalibrary/), [forums.swift.org](https://forums.swift.org/t/how-do-you-depend-on-swiftpm-as-a-library/68574))

## Known useful tooling surfaces
- **SwiftSyntax:**
  The swift-syntax package works on a source-accurate SwiftSyntax tree and is the backbone of Swift macros, making it a strong candidate for Anigma source-aware validators. ([github.com](https://github.com/swiftlang/swift-syntax))
- **swift-driver:**
  The Swift driver coordinates compilation of Swift source into executables, libraries, object files, Swift modules, and interfaces, and is often invoked by SwiftPM or Swift Build. Useful for research and diagnostics, but probably not a core runtime dependency yet. ([github.com](https://github.com/swiftlang/swift-driver))
- **SwiftPM CLI outputs:**
  Anigma already uses `swift package describe --type json` and `swift package show-dependencies --format json` as graph evidence surfaces. Keep this as the first integration layer unless research proves a better stable interface. Keep in mind the SwiftPM products/targets distinction: targets are compiled into modules or test suites, and products are assembled from one or more target build artifacts.
- **llbuild:**
  Study as an incremental build/evidence graph model, but do not vendor unless Anigma is intentionally building its own build engine.

## Non-goals
- Do not implement this during backend normalization.
- Do not vendor SwiftPM, swift-driver, llbuild, or the Swift compiler into Anigma in this task.
- Do not make Anigma runtime depend on unstable SwiftPM internals.
- Do not replace the current package graph audit script prematurely.
- Do not introduce toolchain dependencies into production runtime targets.
- Do not broaden Package.swift dependencies without graph evidence.
- Do not create `@_exported` imports or umbrella modules to hide tool dependencies.

## Research deliverables
1. **Research doc:**
   `Docs/research/swift-tooling-integration/README.md`
2. **Detailed research files:**
   - `Docs/research/swift-tooling-integration/swiftpm-integration-options.md`
   - `Docs/research/swift-tooling-integration/swiftsyntax-validator-dependency.md`
   - `Docs/research/swift-tooling-integration/swift-driver-diagnostics.md`
   - `Docs/research/swift-tooling-integration/llbuild-evidence-graph.md`
   - `Docs/research/swift-tooling-integration/tooling-sidecar-vs-runtime-dependency.md`
   - `Docs/research/swift-tooling-integration/licensing-and-versioning.md`
3. **Doctrine proposal:**
   `Docs/governance/SWIFT_TOOLING_INTEGRATION_DOCTRINE.md`
4. **Proof artifact:**
   `Docs/proofs/swift-tooling-integration-research.md`

## Research questions
1. Which Swift tooling should Anigma invoke externally through governed executors?
2. Which Swift tooling is safe to use as a library dependency?
3. Which tooling should remain research-only?
4. Should SwiftSyntax live in:
   - Anigma validator target,
   - Anigma developer tooling package,
   - daemon sidecar,
   - or external CLI wrapper?
5. Should Anigma ever depend directly on libSwiftPM?
6. If not, what Anigma-owned schemas should wrap SwiftPM outputs?
7. Should swift-driver be used through logs/CLI output only, or as a library in a tooling sidecar?
8. Should llbuild concepts inform Anigma evidence graphs without importing llbuild?
9. What toolchain version pinning strategy is needed?
10. How should self-hosted Anigma agents discover available Swift tools?
11. How should agent tool use be governed?
12. What are the security risks of letting agents run SwiftPM/compiler tools?
13. What should be in the runtime versus developer-tooling layer?
14. Which package targets would be allowed to depend on SwiftSyntax?
15. Which targets must never depend on SwiftSyntax/SwiftPM/driver/llbuild?

## Required architecture framing
Use this model unless research disproves it:

**AnigmaSwiftToolingContracts:**
- PackageGraphSnapshot
- BuildDiagnosticReceipt
- SwiftSyntaxFinding
- TargetGraphViolation
- ToolchainVersionReceipt
- SymbolGraphSnapshot
- SourceValidationFinding

**AnigmaSwiftToolingExecutors:**
- SwiftPMDescribeExecutor
- SwiftPMShowDependenciesExecutor
- SwiftPMBuildExecutor
- SwiftPMTestExecutor
- SwiftPMDumpSymbolGraphExecutor
- SwiftSyntaxValidatorExecutor
- SwiftDriverLogExecutor

**External host tools:**
- `swift package describe --type json`
- `swift package show-dependencies --format json`
- `swift build`
- `swift test`
- `swift package dump-symbol-graph`
- `swiftc` / `swift-driver` outputs

## Governance requirements
- All tool execution must go through governed executors.
- Every command must produce a receipt.
- Every graph/build/test result must be normalized into Anigma-owned JSON.
- Agents must not get ambient shell access.
- Agents request capabilities, not raw tools.
- Runtime targets must not depend on unstable SwiftPM internals.
- Tooling targets may depend on SwiftSyntax if justified.
- Any SwiftPM library dependency must be explicitly marked experimental/tooling-only.

## Research commands
Use local cloned repos if available:
`ExternalResearch/swift-tooling/swift-package-manager`
`ExternalResearch/swift-tooling/swift-syntax`
`ExternalResearch/swift-tooling/swift-driver`
`ExternalResearch/swift-tooling/swift-llbuild`
`ExternalResearch/swift-tooling/swift-build`

If not present, clone shallow copies into `ExternalResearch/swift-tooling`.

**Inspect:**
- SwiftPM library API stability docs
- SwiftSyntax README and package products
- swift-driver README and package products
- llbuild architecture docs/source
- SwiftPM PackageDescription and PackagePlugin stable surfaces
- SwiftPM CLI JSON outputs already consumed by Anigma

## Required source discipline
For every substantive claim, cite:
- upstream repository or official documentation source
- commit hash if source-derived
- file path and symbol where applicable
- whether the source is stable public API, unstable internal API, CLI output, or design reference

## Decision matrix
Produce a table with columns:
| Tool | Integration Option | Stability | Runtime Risk | Agent Value | Recommended Boundary | Decision |
Rows:
- SwiftPM CLI
- libSwiftPM
- SwiftSyntax
- swift-driver CLI/logs
- swift-driver library
- llbuild
- Swift compiler source
- swift package dump-symbol-graph
- PackageDescription
- PackagePlugin

## Expected initial decisions
- SwiftPM CLI: use through governed executor
- libSwiftPM: avoid in runtime; possibly research/tooling-only, unstable
- SwiftSyntax: allow in validator/tooling target
- swift-driver CLI/logs: consume as evidence
- swift-driver library: research only or sidecar later
- llbuild: design reference only for now
- Swift compiler source: research only
- PackageDescription/PackagePlugin: stable public SwiftPM surfaces, useful for plugin/tooling research

## Validation
- No production Anigma runtime code changes.
- No Package.swift runtime dependencies added.
- No vendoring performed.
- Research docs clearly distinguish recommendation from implementation.
- Doctrine proposal includes allowed/forbidden targets.
- Follow-up implementation TDs created, not executed.

## Acceptance criteria
- Research explains why vendoring the whole Swift toolchain is not recommended unless a specific future need is proven.
- Research identifies SwiftSyntax as the strongest candidate for library dependency in tooling/validator targets.
- Research identifies SwiftPM CLI JSON as the preferred stable graph evidence path.
- Research defines runtime/tooling/sidecar boundaries.
- Research defines self-hosted agent tool access through governed executors and receipts.
- Research creates follow-up TDs for:
  1. SwiftSyntax validator prototype
  2. Swift toolchain version receipt
  3. SwiftPM executor hardening
  4. Symbol graph API drift detector
  5. Swift diagnostics classifier
ling/sidecar boundaries.
- Research defines self-hosted agent tool access through governed executors and receipts.
- Research creates follow-up TDs for:
  1. SwiftSyntax validator prototype
  2. Swift toolchain version receipt
  3. SwiftPM executor hardening
  4. Symbol graph API drift detector
  5. Swift diagnostics classifier
