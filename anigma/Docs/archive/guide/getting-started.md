# Getting Started with Anigma

This guide walks through setting up the current Anigma stack on an Apple Silicon Mac. The repository already contains the governed inference layer (Harmonia) plus all domain modules; no external repos are required to compile and test the stack.

## 1) Prerequisites

- Xcode 15+ (Swift 5.9 or newer). Verify with `swift --version`.
- Node.js 18+ for the VitePress docs. Verify with `node -v` and `npm -v`.
- Git for cloning/updating the repo.

## 2) Clone the repo

```bash
git clone <ANIGMA_REPO_URL>
cd Anigma
```

## 3) Build the Swift packages

```bash
swift build                         # Build all products
swift test                          # Run all core + module tests
swift test --filter Diaplasion      # Run a specific module’s tests
swift build --product AnigmaCore    # Build a single product
```

The package includes `AnigmaCore` plus Harmonia, Diaplasion, Accessum, Outlineum, Pragma, Conexus, Codex, Transcriptum, Observatorium, and Polytropos.

## 4) Wire a minimal stack in code

```swift
import AnigmaCore
import HarmoniaModule
import DiaplasionModule

let world = World()
let registry = WorkflowRegistry()

let auditLog = AuditLog(storage: InMemoryAuditLogStorage())
let governance = GovernanceController(auditLog: auditLog)
let telemetry = TelemetryService()

try await HarmoniaModule.register(world: world, registry: registry, telemetry: telemetry)
try await DiaplasionModule.register(world: world, registry: registry)

let runner = WorkflowRunner(world: world, registry: registry)
await runner.enqueue(job: Job(typeId: DiaplasionJobType.documentToEPUB, inputRefs: []))
await runner.runNext()
```

## 5) Run the documentation site

```bash
npm install          # One-time, installs VitePress
npm run dev          # Serves Docs/ on http://localhost:5173 (default)
```

## 6) Optional: local inference tooling

- Harmonia’s Themis/Bonkers++ layer is embedded; if you want to exercise local inference routing, install `ollama` or a `llama.cpp` build and point Themis at them. MLX is preferred for Apple Silicon.
- No Python runtime is required; all pipelines are Swift-first.

## Troubleshooting

- **Missing SDKs:** Re-run `xcode-select --install` if SwiftPM cannot find SDK headers.
- **Case-sensitive FS:** The docs scripts expect `Docs/` (macOS default is case-insensitive, but `docs` will fail on case-sensitive volumes).
- **Slow first build:** SwiftPM will compile all modules; subsequent builds are incremental.

## 7) Harmonia Governance Tools

The Harmonia governance layer provides deterministic, receipt-based validation:

```bash
# Build with Swift 6 strict concurrency checks
Scripts/harmonia.sh swift6

# Run security validation
Scripts/harmonia.sh security

# Run trust/evidence checks
Scripts/harmonia.sh trust
```

See [AGENTS.md](../../AGENTS.md) for complete governance workflow details and the governed patch toolchain.
