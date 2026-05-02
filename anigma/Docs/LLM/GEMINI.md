# GEMINI.md

## Mandatory: TD + Sidecar Workflow (ready, start, log/heartbeat, handoff, finish)

This repository uses Sidecar `td` for task and session coordination. Reference: https://sidecar.haplab.com/docs/td
...

1. Start of every conversation/context window (or after `/clear`):
   ```bash
   td usage --new-session
   ```
2. Use a quiet status check after setup:
   ```bash
   td usage -q
   ```
3. Start implementation on a tracked issue:
   ```bash
   td start <issue-id>
   # Multi-issue work:
   td ws start "<work-session-name>"
   td ws tag <issue-id> [issue-id...]
   ```
4. Log progress as you go:
   ```bash
   td log "<progress note>"
   # or: td ws log "<progress note>"
   ```
5. Before ending context, record handoff (required):
   ```bash
   td handoff <issue-id> \
     --done "<completed and tested work>" \
     --remaining "<specific pending tasks>" \
     --decision "<why this approach was chosen>" \
     --uncertain "<open questions>"
   # or: td ws handoff
   ```
6. Completion flow: implementer runs `td review <issue-id>`; a different session runs `td approve <issue-id>`.
7. Never use `td close` for completed implementation work. Use `td close` only for admin closures (duplicate/won't-fix/cleanup).
8. Do not start a new session mid-work unless you are intentionally beginning a new context.

**Last Updated**: 2026-01-11

This file provides guidance to Gemini (the AI assistant) when working with code in this repository.

> [!WARNING]
> **Documentation Drift**: Some high-level documentation (e.g., `ANIGMA_CLI_COMPLETE_STATUS.md`) may reflect the *intended end-state* of a sprint rather than the literal current implementation. Always verify "✅ Complete" claims by checking for stubs or placeholders (e.g., `throw Error("Not Available")`) in the codebase before assuming a feature is production-ready.

## Project Overview

**Anigma** is a governed, local-first Swift stack for institutional AI, built as a macOS application. It provides a comprehensive platform for high-assurance data work, governance, and agentic workflows. The system is designed for institutional environments (e.g., educational institutions like CCSF DSPS) where AI operations require radical transparency, safety guarantees, and compliance with governance policies.

## Build & Development Commands

### Building the Project

```bash
# Build all targets in release mode
swift build -c release

# Build specific executable products
swift build -c release --product anigma-app
swift build -c release --product harmonia
swift build -c release --product anigmad
swift build -c release --product ml-worker
swift build -c release --product doctrine

# Build the Mac app bundle (includes all binaries)
Scripts/build_mac_app.sh

# Build installer package
Scripts/build_installer.sh
```

### Testing

```bash
# Run all tests
swift test

# Run tests for a specific module
swift test --filter AnigmaCoreTests
swift test --filter DatabaseCoreTests
swift test --filter HarmoniaCLITests

# Run tests in parallel
swift test --parallel
```

### Running Executables

```bash
# Run the daemon
.build/release/anigmad

# Run Harmonia CLI (AI coding assistant)
.build/release/harmonia --help

# Run ML worker
.build/release/ml-worker --help

# Run doctrine (policy enforcement)
.build/release/doctrine --help
```

### Code Quality

```bash
# Format Swift code (uses .swift-format.json config)
swift format -i -r Sources/ Packages/

# Run SwiftLint (uses .swiftlint.yml config)
swiftlint lint

# Check for strict concurrency issues
swift build -Xswiftc -strict-concurrency=complete
```

## High-Level Architecture

### Three-Tier Architecture

Anigma follows a **strict three-tier architecture** (see ADR-0006):

```
┌─────────────────────────────────────────────────────────┐
│            Tier 0: App Shells (UI Layer)                │
│  AnigmaAppMac, AnigmaAppIOS, HarmoniaCLI, AnigmaDaemon  │
│             Each creates ONE PlatformRuntime             │
└──────────────────────┬──────────────────────────────────┘
                       │ submit workflows, render results
                       ▼
┌─────────────────────────────────────────────────────────┐
│       Tier 3: Capability Modules (Feature Layer)        │
│    HarmoniaModule, DiaplasionModule, AccessumModule     │
│     Register workflows/systems, emit events/receipts    │
└──────────────────────┬──────────────────────────────────┘
                       │ register, execute, mutate
                       ▼
┌─────────────────────────────────────────────────────────┐
│     Tier 2: Platform Runtime (Integration Layer)        │
│  ┌───────────────────────────────────────────────────┐  │
│  │ PlatformRuntime Actor - THE ONLY EXECUTION PATH  │  │
│  │  - World (ONE instance)                           │  │
│  │  - ExecutionAuthority (workflow/job runner)       │  │
│  │  - EvidenceAuthority (unified evidence)           │  │
│  │  - DatabaseAuthority (governed mutations)         │  │
│  │  - ArtifactAuthority (unified storage)            │  │
└──────────────────────┬──────────────────────────────────┘
                       │ enforce, record                     │
                       ▼                                     │
│  ┌─────────────────────────────────────────────────┐    │
│  │ GovernanceController (from Tier 1)              │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────┘
                       │ evaluate policies
                       ▼
┌─────────────────────────────────────────────────────────┐
│     Tier 1: Governance & Identity (Constitutional)      │
│    Policy definitions, KillSwitch, WriteGate, ABAC      │
│           NO execution, NO storage, NO platform         │
└─────────────────────────────────────────────────────────┘
```

**Dependency Rules:**
1. **Tier 0** (App Shells) depends on Tier 2 + Tier 3
2. **Tier 3** (Capability Modules) depends on Tier 2 + Tier 1, but NOT on each other
3. **Tier 2** (Platform Runtime) depends on Tier 1 only
4. **Tier 1** (Governance) depends on nothing (pure policy)

### Core Infrastructure (AnigmaCore)

The foundation of the entire system (Tier 1 + Tier 2), providing:

- **Entity-Component-System (ECS)**: Data-oriented architecture for all operations
- **Job System**: Asynchronous task scheduling and workflow orchestration
- **Governance System**: Policy-driven behavior control
  - `KillSwitch`: Emergency halt for all write operations
  - `WriteGate`: Quality checks before mutations
  - `AccessController`: Role/attribute-based access control
  - `LifecycleManager`: Data retention and expiration
  - `OperatingMode`: readOnly, assistive, autopilot

## Key Architectural Patterns

### Actor-Based Concurrency

The entire codebase uses **strict concurrency** with Swift 6 actor isolation. All core infrastructure is actor-isolated.

### Governed Writes

**All mutations** go through the governance system:
1. Check `KillSwitch.isWriteAllowed()`
2. Evaluate `WriteGate` checks
3. Verify `AccessController` permissions
4. Execute mutation
5. Log to audit trail

### Evidence-Based Operations

Critical operations store cryptographic evidence in `EvidenceAuthority` (previously `CathedralModule`).

## Directory Structure

```
Anigma/
├── App/MacApp/               # macOS application entry point
├── Sources/
│   ├── AnigmaAppMac/         # Main app executable
│   ├── CathedralModule/      # Evidence storage
│   ├── ContextumModule/      # Context management
│   ├── ArtifactStoreModule/  # Artifact storage
│   └── ModelRegistryModule/  # Model registry
├── Packages/                 # SwiftPM modules
│   ├── AnigmaCore/           # ECS, Jobs, Governance
│   ├── AnigmaPrimitives/     # Fundamental types
│   ├── DatabaseCore/         # Database abstractions (GRDB)
│   ├── ContractsCore/        # Workflow contracts
│   ├── HarmoniaModule/       # AI coding assistant
│   └── [60+ other modules]
├── Native/Shims/             # C/C++ native code
├── Tests/                    # Test suites
├── Scripts/                  # Build and automation scripts
└── Package.swift             # SwiftPM manifest
```

## Important Conventions

- **Concurrency**: Use `actor` for shared mutable state. All components MUST conform to `Sendable`. Use `async/await` for I/O.
- **Error Handling**: Use typed errors conforming to `Error`. NEVER silently swallow errors.
- **Naming**: Modules suffixed with "Module" or "Core"; Actors with "Controller", "Manager", or "Service"; Components with "Component"; Systems with "System".
- **Modularization (The Playbook)**:
    - **Indirect Enums**: Recursive `Codable` enums (like JSON trees or AnyCodable) MUST use `indirect` on recursive cases to prevent `emit-module` signal 4 (Illegal Instruction) compiler crashes.
    - **Contract Isolation**: Protocols and DTOs MUST live in leaf targets (e.g., `*Contracts`) to minimize rebuild cascades.
    - **Facade Pattern**: When splitting modules, maintain backward compatibility using `@_exported import` in the original target.
    - **Dependency Isolation**: Isolate heavy frameworks (CoreML, MLX, CryptoKit) into "Integration" targets to prevent build-time "infection" of the core stack.

## Parallelism vs. Concurrency (Architectural North Star)

Anigma distinguishes between **Coordination (Concurrency)** and **Saturation (Parallelism)**:

- **Concurrency (Current Baseline)**: Focuses on non-blocking UI, async daemon jobs, and safe state transitions using Swift actors.
- **Parallelism (Target State)**: Focuses on hardware saturation (CPU/GPU/ANE) by partitioning data and ownership.

### Parallelism Playbook:
1.  **Declare System Access Sets**: ECS systems must declare `readComponents` and `writeComponents` to allow the scheduler to run non-conflicting systems in parallel.
2.  **Separate Control Plane from Data Plane**: Use Actors for control-plane logic (policy, receipts, lifecycle) but move data-plane work (ingestion, OCR, embeddings, vector scoring) toward batch-oriented, parallel systems.
3.  **Data-Oriented ECS (DOD)**: Eliminate the "Serialization Wall" by using Structure-of-Arrays (SoA) at rest. Store heavy data (vectors, tensors) in contiguous "Binary Atlases" to enable 100% memory coalescing and zero-copy mapping into GPU/ANE address space.
4.  **Multiplayer Governance (Nexus DSL)**: Eliminate the "Network Wall" (Serial JSON tax) by using a specialized **Nexus DSL** for RDMA-style peer-to-peer sync. Instances coordinate via **Federated Evidence Spines**, syncing hardware heartbeats and pre-signed missions with <1ms latency.
5.  **Partitionable Projections**: The Agent Observability Spine should support parallel rebuilds by partitioning events by `run_id`, `trace_id`, or time window.
6.  **Lane Scheduling**: Implement explicit hardware lanes (Control, Evidence, Inference, Native) with backpressure and degradation behavior.

### Eliminating Architectural Walls
To achieve true hardware-saturated autonomy, Anigma rigorously identifies and eliminates "Walls" that starve high-performance execution:
- **Governance Wall**: Move from real-time policy evaluation to **Pre-Signed Missions**.
- **Evidence Wall**: Implement **In-Kernel Evidence (SIMD-Blake3)** to eliminate the hashing tax.
- **I/O Wall**: Implement **Predictive Pre-fetching** to minimize page-fault latency during DSL missions.
- **Scheduling Wall**: Transition to **Shared-Memory Job Queues** to eliminate actor-based dispatch latency.

### The Hardware Saturation Lane (Megakernel Strategy)
To achieve true hardware saturation on Apple Silicon, Anigma implements "Saturation Lanes" that eliminate the "Coordination Tax" of CPU-GPU round-trips:
1.  **Inference Megakernels**: Fuse discrete AI operations (Normalization, Attention, MLP, Selection) into single, stateful Metal compute dispatches.
2.  **Decoupled Execution**: Move the inner inference loop out of the Swift Actor coordination space and into autonomous Metal Indirect Command Buffers (ICBs).
3.  **Intelligence-per-Watt**: Prioritize peak efficiency (Ops/Joule) by leveraging persistent GPU state (Registers/Threadgroup) to minimize RAM fetches.
4.  **Governed Missions**: Tier 1 Governance signs "Mission Descriptors" that the GPU executes autonomously, writing tamper-evident heartbeats directly to EvidenceAuthority buffers.

## Backend Build Stabilization Plan

The following targets are identified for prioritized modularization to reduce compiler pressure and improve incremental build times:

1. **ContractsCore (P0)**: Split into `FoundationContracts`, `IntelligenceContracts`, and `GovernanceContracts`.
2. **AnigmaCore (P1)**: Decompose Tier 2 monolith into `AnigmaFoundation`, `AnigmaGovernance`, `AnigmaJobs`, and `AnigmaPipeline`.
3. **HarmoniaModule (P1)**: Isolate AI inference logic into `HarmoniaInference` and `HarmoniaSecurity`.
4. **ModelRegistry (P2)**: Separate conversion logic into `ModelConversionKit`.

## Gemini Specific Instructions

- **Codebase Analysis**: PRIORITIZE using local CLI tools (rg, fd, just, sg, universal-ctags, sourcekitten) for codebase analysis and investigation.
- **Context Retrieval**: Use `kb-query` for project-specific context. Use 'anigma-mcp' tools (e.g., 'context_search', 'trace_query') as a secondary source of truth or for high-level operations.
- **Tool Usage**: Prefer using `run_shell_command` for building and testing as defined in the commands section.
- **Code Modifications**: When modifying code, ensure compliance with Swift 6 strict concurrency rules.
- **Verification**: Always run `swift build -Xswiftc -strict-concurrency=complete` after significant changes to ensure no concurrency violations were introduced.

## Architectural Doctrine: Dependency Hardening
- **ContractsCore**: Must define or import only constitutional contracts. Must NOT re-export implementation modules or serve as a project-wide umbrella.
- **Explicit Imports**: Every target must import its direct semantic dependencies explicitly.
- **Cyclic Decoupling**: If two implementation modules need each other, they must depend on an intermediate contract target, never each other directly.
- **Enforcement Gates**: All builds must pass:
  -  (enforces @_exported ban/allowlist)
  -  (enforces graph-level cycle checks via `swift package describe --type json`)
  -  (enforces tier-based layering)
- **Workflow**: Run 'anigma doctor' (running validation scripts + build) before and after changes affecting the dependency graph.

## Architectural Doctrine: Dependency Hardening
- **ContractsCore**: Must define or import only constitutional contracts. Must NOT re-export implementation modules or serve as a project-wide umbrella.
- **Explicit Imports**: Every target must import its direct semantic dependencies explicitly.
- **Cyclic Decoupling**: If two implementation modules need each other, they must depend on an intermediate contract target, never each other directly.
- **Enforcement Gates**: All builds must pass:
  - `Scripts/validate_exported_imports.py` (enforces @_exported ban/allowlist)
  - `Scripts/validate_no_cycles.py` (enforces graph-level cycle checks via `swift package describe --type json`)
  - `Scripts/validate_tiers.py` (enforces tier-based layering)
- **Workflow**: Run 'anigma doctor' (running validation scripts + build) before and after changes affecting the dependency graph.

## Governance Architecture: Anigma Control Plane
Anigma acts as the governed control plane orchestrating standard Swift/Apple tooling. Interaction follows a strict "Ask -> Patch -> Prove" flow rather than raw shell execution.

### Authority Hierarchy
- **Tool Authority**: Wraps external tools (SwiftPM, SwiftLint, DocC, etc.).
- **Graph Authority**: Owns dependency manifests (), cycle detection, and target tier classification.
- **Doctrine Authority**: Enforces project-specific invariants (e.g., banned , contract-only module rules, import fan-out budgets).
- **Evidence Authority**: Generates machine-readable receipts (td - A minimalist local task and session management CLI designed for AI-assisted development workflows.

Optimized for session continuity—capturing working state so new context windows can resume where previous ones stopped.

Usage:
  td [command]

Core Commands:
  board                 Manage issue boards
  create, add, new      Create a new issue
  delete                Soft-delete one or more issues
  epic                  Shortcuts for working with epics
  list, ls              List issues matching given filters
  restore               Restore soft-deleted issues
  show, context, view, get Display full details of one or more issues
  task                  Shortcuts for working with tasks
  update, edit          Update one or more fields on existing issues

Workflow Commands:
  approve               Approve and close one or more issues
  block                 Mark issue(s) as blocked
  close, done, complete Close one or more issues without review
  comment               Add a comment to an issue (alias for 'comments add')
  comments              List comments for an issue
  dep                   Manage dependencies between issues
  handoff               Capture structured working state
  log                   Append a log entry to the current issue
  reject                Reject and return to in_progress
  reopen                Reopen closed issues
  review, submit, finish Submit one or more issues for review
  start, begin          Begin work on issue(s)
  unblock               Unblock issue(s) back to open status
  unstart, stop         Revert issue(s) from in_progress to open

Query Commands:
  blocked-by            Show what issues are waiting on this issue
  critical-path         Show the sequence of issues that unblocks the most work
  depends-on, deps, dependencies Show what issues this issue depends on
  query                 Search issues with TDQ query language
  search                Full-text search across issues
  tree                  Visualize parent/child relationships

Shortcuts:
  blocked               List blocked issues
  deleted               Show soft-deleted issues
  in-review, ir         List all issues currently in review
  next                  Show highest-priority open issue
  ready                 List open issues sorted by priority
  reviewable            Show issues awaiting review that you can review

Session Commands:
  check-handoff         Check if handoff is needed before exiting (returns error if yes)
  focus                 Set the current working issue
  resume                Show context and set focus
  session               Name session, or --new at context start (not mid-work—bypasses review)
  status, current       Show dashboard: session, focus, reviews, blocked, ready issues
  unfocus               Clear focus
  usage                 Generate optimized context block for AI agents
  whoami                Show current session identity
  ws, worksession       Work session commands

File Commands:
  files                 List linked files with change status
  link                  Link files to an issue
  unlink                Remove file associations

System Commands:
  completion            Generate the autocompletion script for the specified shell
  debug-stats           Output runtime memory and goroutine statistics (JSON)
  errors                View failed td command attempts
  export                Export database
  feature               Manage experimental feature flags
  help                  Help about any command
  import                Import issues
  info, stats           Show database statistics and project overview
  init                  Initialize a new td project
  last                  Show the last action performed
  monitor               Live TUI dashboard for observing agent activity
  security              View security exception log (self-close exceptions)
  stats                 View usage statistics, security events, and errors
  undo                  Undo the last action
  upgrade               Run database migrations
  version               Show version and check for updates
  workflow              Show issue status workflow

Flags:
  -h, --help      help for td
  -v, --version   version for td

Use "td [command] --help" for more information about a command. tasks, patch hashes, test summaries) for agent progress verification.

### Operational Protocol
1. **anigma doctor --issue <id>**: Validates the workspace against current graph and doctrine status.
2. **anigma agent-context --issue <id>**: Produces a minimal, canonical operating packet for the agent.
3. **anigma proof --issue <id>**: Captures and bundles all evidence (patches, validator output, test results) for review.

All agents MUST utilize the Doctor/Proof protocol for all architectural changes.

## Governance Architecture: Anigma Control Plane
Anigma acts as the governed control plane orchestrating standard Swift/Apple tooling. Interaction follows a strict "Ask -> Patch -> Prove" flow rather than raw shell execution.

### Authority Hierarchy
- **Tool Authority**: Wraps external tools (SwiftPM, SwiftLint, DocC, etc.).
- **Graph Authority**: Owns dependency manifests (`swift package describe`), cycle detection, and target tier classification.
- **Doctrine Authority**: Enforces project-specific invariants (e.g., banned `@_exported`, contract-only module rules, import fan-out budgets).
- **Evidence Authority**: Generates machine-readable receipts (`td` tasks, patch hashes, test summaries) for agent progress verification.

### Operational Protocol
1. **anigma doctor --issue <id>**: Validates the workspace against current graph and doctrine status.
2. **anigma agent-context --issue <id>**: Produces a minimal, canonical operating packet for the agent.
3. **anigma proof --issue <id>**: Captures and bundles all evidence (patches, validator output, test results) for review.

All agents MUST utilize the Doctor/Proof protocol for all architectural changes.

## Standardized CLI Tooling Stack
To ensure high-performance, predictable, and governor-friendly codebase operations, agents MUST utilize the following toolchain (Standardized for macOS/Homebrew):

### Discovery & Search
- **`fd`**: Fast file finding. Replace `find` for all simple lookups.
- **`rg` (ripgrep)**: Canonical codebase search. Use for all text/regex lookups.
- **`ast-grep`**: Structural code search. Mandatory for architectural pattern matching (e.g., finding all usages of a specific protocol).
- **`git grep`**: Repo-aware search when history/branch-context matters.
- **`ctags`**: Symbol mapping for high-level code navigation.

### Diffing & Review
- **`difftastic`**: Syntax-aware diffs for PR reviews and state change verification.
- **`git-delta`**: High-readability diff output.

### Refactoring & Editing
- **`sd`**: Optimized search-and-replace.
- **`comby`**: Structural find-replace for complex refactors (e.g., re-wiring dependency injection).

### Automation & Benchmarking
- **`jq`/`yq`**: Mandatory for interacting with SwiftPM JSON output, YAML config, and JSON-based evidence receipts.
- **`hyperfine`**: Benchmarking for Anigma performance claims.
- **`watchexec`**: Triggering validator scripts or build runs upon file changes.

### Anigma-Native Wrappers
Agents MUST favor the `anigma` toolchain wrapper over raw bash wherever defined:
- `anigma search` (Wrapper for rg/ast-grep)
- `anigma patch propose/apply` (Governed editing)
- `anigma evidence attach` (Progress receipt generation)
- `anigma td ...` (Task management)

**Note**: Raw shell remains available for emergencies, but must be reported as a deviation from the Doctor/Proof protocol.
