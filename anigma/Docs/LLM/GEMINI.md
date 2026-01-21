# GEMINI.md

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

## Gemini Specific Instructions

- **MCP Integration**: PRIORITIZE using 'anigma-mcp' tools (e.g., 'read_file', 'context_search', 'trace_query') for codebase investigation and high-level operations. Use them to understand the system state before falling back to raw shell commands.
- **Tool Usage**: Prefer using `run_shell_command` for building and testing as defined in the commands section.
- **Code Modifications**: When modifying code, ensure compliance with Swift 6 strict concurrency rules.
- **Verification**: Always run `swift build -Xswiftc -strict-concurrency=complete` after significant changes to ensure no concurrency violations were introduced.
