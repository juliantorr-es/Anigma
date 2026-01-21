# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
│  └─────────────────┬─────────────────────────────────┘  │
│                    │ enforce, record                     │
│                    ▼                                     │
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

**Enforcement Rules:**
- Capability modules CANNOT create `World` instances
- Capability modules CANNOT call `DatabaseActor` directly
- Capability modules CANNOT write evidence directly
- Capability modules CANNOT bypass governance
- All mutations MUST go through `PlatformRuntime` authorities

### Tier 1: Governance & Identity (Constitutional Layer)

**Location:** `AnigmaCore/Governance/`

The pure policy layer that defines what is allowed:

- **Policy Definitions**: Operating modes, trust zones, ABAC rules
- **KillSwitch**: Emergency halt for all write operations
- **WriteGate**: Quality checks before mutations
- **AccessController**: Role/attribute-based access control
- **LifecycleManager**: Data retention and expiration policies

**Key Invariant:** Governance evaluates "is this allowed?" but does NOT execute or store.

### Tier 2: Platform Runtime (Integration Layer)

**Location:** `AnigmaCore/Runtime/`

The runtime integration layer and THE ONLY execution path for all operations:

- **PlatformRuntime Actor**: Owns the ONE World instance and all authorities
- **ExecutionAuthority**: The only way to run workflows/jobs (enforces governance)
- **EvidenceAuthority**: Unified evidence recording (consolidates 3 previous systems)
- **DatabaseAuthority**: Governed database access (wraps DatabaseActor with governance)
- **ArtifactAuthority**: Unified artifact storage

**Critical Pattern:**
```swift
// Create runtime (ONE per app instance)
let runtime = try await PlatformRuntime.local(config: .production)

// Register modules
try await HarmoniaModule.register(runtime: runtime)

// Execute workflow (governance enforced, evidence recorded)
let context = ExecutionContext(principal: user)
let receipt = try await runtime.execute(MyWorkflow(), context: context)
```

**Enforcement:**
- Every mutation checks `KillSwitch` and `WriteGate` before execution
- Evidence is recorded automatically for all operations
- Modules CANNOT bypass governance (no direct DatabaseActor access)

### Tier 3: Capability Modules (Feature Layer)

Domain-specific functionality that registers with the runtime:

**Module Registration Pattern:**
```swift
public enum MyModule {
    public static func register(runtime: PlatformRuntime) async throws {
        // 1. Register schemas (runtime manages migrations)
        try await runtime.registerSchema(MySchema.tables)

        // 2. Register workflows
        await runtime.registerWorkflow(MyWorkflow.self)

        // 3. Register systems (optional)
        try await runtime.registerSystem(MySystem())
    }
}
```

**Current Capability Modules:**

- **HarmoniaModule**: AI coding assistant with safety kernel
  - Themis Orchestrator: Governed inference entry point
  - Bonkers++ Inference: Institution-grade AI with tri-memory architecture
  - Radically Legible AI: Cryptographically signed operation receipts
  - Safety Analysis: Pre-flight checking of code changes

- **DiaplasionModule**: Document transformation (PDF, EPUB, alt-media)
- **AccessumModule**: Accessibility tools (DSPS integration)
- **OutlineumModule**: Artwork outlines, zines, print production
- **CathedralModule**: Evidence storage and verification (being consolidated into EvidenceAuthority)
- **ContextumModule**: Context management for AI operations
- **ModelRegistryModule**: ML model lifecycle management
- **ArtifactStoreModule**: Build artifact storage (being consolidated into ArtifactAuthority)

### Core Infrastructure (AnigmaCore)

The foundation of the entire system (Tier 1 + Tier 2), providing:

- **Entity-Component-System (ECS)**: Data-oriented architecture for all operations
  - `World` actor: Central entity/component storage
  - `EntityId`: Unique identifier for entities
  - `Component` protocol: Data containers
  - `System`/`AsyncSystem`: Logic processors

- **Job System**: Asynchronous task scheduling and workflow orchestration
  - `Job`: Unit of work with priority, retry policy, payload
  - `Workflow` protocol: Multi-step operations
  - `Scheduler` actor: Job queue management

- **Governance System**: Policy-driven behavior control
  - `KillSwitch`: Emergency halt for all write operations
  - `WriteGate`: Quality checks before mutations
  - `AccessController`: Role/attribute-based access control
  - `LifecycleManager`: Data retention and expiration
  - `OperatingMode`: readOnly, assistive, autopilot

### Capability Modules

Domain-specific functionality built on AnigmaCore:

- **HarmoniaModule**: AI coding assistant with safety kernel
  - Themis Orchestrator: Governed inference entry point
  - Bonkers++ Inference: Institution-grade AI with tri-memory architecture
  - Radically Legible AI: Cryptographically signed operation receipts
  - Safety Analysis: Pre-flight checking of code changes

- **DiaplasionModule**: Document transformation (PDF, EPUB, alt-media)
- **AccessumModule**: Accessibility tools (DSPS integration)
- **OutlineumModule**: Artwork outlines, zines, print production
- **CathedralModule**: Evidence storage and verification
- **ContextumModule**: Context management for AI operations
- **ModelRegistryModule**: ML model lifecycle management
- **ArtifactStoreModule**: Build artifact storage

### Binary Distribution

The system produces multiple executable products:

- **anigma-app**: Main macOS application (SwiftUI/AppKit)
- **anigmad**: Background daemon for system services
- **harmonia**: CLI for AI coding assistance
- **ml-worker**: ML inference worker process
- **doctrine**: Policy enforcement CLI
- **anigma-ast-services**: Swift AST analysis service

All binaries are bundled into `Anigma.app` for distribution.

### MCP Server (anigma-mcp)

Additionally, **anigma-mcp** is a Model Context Protocol server that exposes 17 Anigma tools to external AI assistants:

- **Claude Desktop** ✅ Configured and working (16 tools auto-approved)
- **Codex CLI** ✅ Configured and working (all 17 tools)
- **Zed Editor** ✅ Native MCP support (ready to configure)
- **Gemini** 🔄 HTTP bridge in development (coming soon)

See [Docs/AI_TOOLS_INTEGRATION.md](Docs/AI_TOOLS_INTEGRATION.md) for complete setup and usage instructions.

## Key Architectural Patterns

### Actor-Based Concurrency

The entire codebase uses **strict concurrency** with Swift 6 actor isolation:

```swift
// All core infrastructure is actor-isolated
public actor World { ... }
public actor Scheduler { ... }
public actor GovernanceController { ... }

// Components must be Sendable
public protocol Component: Sendable { }

// Systems use async/await
public protocol AsyncSystem: Actor {
    func update(world: World, deltaTime: TimeInterval) async throws
}
```

### Governed Writes

**All mutations** go through the governance system:

1. Check `KillSwitch.isWriteAllowed()`
2. Evaluate `WriteGate` checks
3. Verify `AccessController` permissions
4. Execute mutation
5. Log to audit trail

### Evidence-Based Operations

Critical operations store cryptographic evidence in `CathedralModule`:

- What happened (operation type, parameters)
- When it happened (timestamp)
- Who authorized it (principal)
- What was the result (success/failure, outputs)
- Hash of the evidence bundle (BLAKE3)

### Database-First Architecture

Database schemas are the source of truth, located in `Packages/DatabaseCore/`:

- `Schema_Master.sql`: Central database schema
- `Schema_Evidence.sql`: Evidence storage
- `Schema_CourtSafe.sql`: Legal compliance records

All database access uses GRDB.swift with type-safe queries.

## Directory Structure

```
Anigma/
├── App/MacApp/               # macOS application entry point
├── Sources/
│   ├── AnigmaAppMac/         # Main app executable
│   ├── CathedralModule/      # Evidence storage (in Sources for production use)
│   ├── ContextumModule/      # Context management
│   ├── ArtifactStoreModule/  # Artifact storage
│   └── ModelRegistryModule/  # Model registry
├── Packages/                 # SwiftPM modules
│   ├── AnigmaCore/           # ECS, Jobs, Governance
│   ├── AnigmaPrimitives/     # Fundamental types
│   ├── DatabaseCore/         # Database abstractions (GRDB)
│   ├── ContractsCore/        # Workflow contracts
│   ├── HarmoniaModule/       # AI coding assistant
│   ├── AnigmaDaemonCore/     # Daemon infrastructure
│   ├── MLWorkerCommon/       # ML worker shared code
│   └── [60+ other modules]
├── Native/Shims/             # C/C++ native code
├── Tests/                    # Test suites
├── Scripts/                  # Build and automation scripts
├── Docs/                     # Architecture decision records
└── Package.swift             # SwiftPM manifest
```

## Important Conventions

### Naming

- **Modules**: Descriptive suffixed with "Module" or "Core" (e.g., `HarmoniaModule`, `AnigmaCore`)
- **Actors**: Suffixed with "Controller", "Manager", or "Service" (e.g., `GovernanceController`)
- **Components**: Suffixed with "Component" (e.g., `FileComponent`, `QAComponent`)
- **Systems**: Suffixed with "System" (e.g., `OCRExtractionSystem`)

### Module Boundaries

- **Core modules** (AnigmaCore, DatabaseCore, etc.) MUST NOT depend on capability modules
- **Capability modules** MAY depend on core modules but NOT on each other
- **App shells** MAY depend on any modules needed for functionality
- See `Docs/ADR/0004-module-boundaries.md` for enforcement

### Concurrency

- Use `actor` for shared mutable state
- All components MUST conform to `Sendable`
- Use `async/await` for I/O and long-running operations
- NEVER use `DispatchQueue` or `NSLock` directly

### Error Handling

- Use typed errors conforming to `Error`
- Log errors with context to telemetry
- NEVER silently swallow errors

### Testing

- Unit tests in `Tests/{ModuleName}Tests/`
- Integration tests use `AnigmaTestSupport`
- Database tests use in-memory SQLite
- Mock heavy dependencies (ML models, network)

## Working with the Governance System

Before making any code changes that mutate state:

1. **Understand the Operating Mode**:
   - `readOnly`: No modifications allowed (read-only analysis)
   - `assistive`: Requires human confirmation before writes
   - `autopilot`: Autonomous execution with governance checks

2. **Check the Kill Switch**:
   - If activated, ALL writes are blocked system-wide
   - Used for emergency halts

3. **Register Write Checks**:
   - Quality checks run before mutations
   - Can be blocking (hard failure) or advisory (warning)

4. **Audit Everything**:
   - Use `AuditLogging` for all significant operations
   - Store evidence in `CathedralModule` for critical operations

## Working with ML Components

### Model Integration

- Models are registered in `ModelRegistryModule`
- Inference runs in separate `ml-worker` process
- Communication via gRPC (protobuf definitions in `AnigmaDaemonCore`)

### Local-First ML

- All ML inference happens **on-device** using MLX
- No cloud API dependencies at runtime
- Models are downloaded during setup, cached locally

### Memory Management

Harmonia uses **tri-memory architecture**:
- **Lethe**: Short-term context (single session)
- **Mnemosyne**: Long-term memory (cross-session patterns)
- **Archeion**: Persistent institutional knowledge

## Common Workflows

### Adding a New Capability Module

1. Create package in `Packages/{ModuleName}/`
2. Add product/target to `Package.swift`
3. Depend only on core modules (enforce with tests)
4. Register components/systems with `World`
5. Add integration tests in `Tests/{ModuleName}Tests/`

### Adding a New Component

```swift
// In {Module}/Components/MyComponent.swift
import AnigmaCore

public struct MyComponent: Component, Sendable {
    public let data: String

    public init(data: String) {
        self.data = data
    }
}
```

### Adding a New System

```swift
// In {Module}/Systems/MySystem.swift
import AnigmaCore

public actor MySystem: AsyncSystem {
    nonisolated public let id = "my.module.my.system"
    nonisolated public let priority = 100

    public init() {}

    public func update(world: World, deltaTime: TimeInterval) async throws {
        let entities = await world.entities(with: MyComponent.self)
        for entity in entities {
            // Process entities with MyComponent
        }
    }
}
```

### Running Database Migrations

Database schemas are versioned and managed via `DatabaseCore`:
- Schema files: `Packages/DatabaseCore/Schema_*.sql`
- Migrations are applied on first run
- Use GRDB's `DatabaseMigrator` for schema changes

## Claude Code Specific Instructions

- **MCP Integration**: PRIORITIZE using 'anigma-mcp' tools (e.g., 'read_file', 'context_search', 'trace_query') for codebase investigation and high-level operations. These tools are optimized for granular retrieval and structured schema access, helping to manage context window efficiency.
- **Tool Usage**: Prefer using `run_shell_command` for building and testing as defined in the commands section.
- **Verification**: Always run `swift build -Xswiftc -strict-concurrency=complete` after significant changes to ensure no concurrency violations were introduced.

## Troubleshooting

### Build Failures

- Ensure Xcode 15.0+ and macOS 14.0+
- Clean build folder: `swift package clean`
- Reset package cache: `rm -rf .build`
- Check for Swift version: `swift --version` (should be 5.9+)

### Concurrency Errors

- Enable strict concurrency: `-Xswiftc -strict-concurrency=complete`
- All shared state must be `actor` isolated
- Use `@MainActor` for UI code
- Use `nonisolated` for computed properties/constants

### Test Failures

- Check for race conditions (use `swift test --parallel` to expose)
- Ensure tests clean up properly (in-memory databases, temp files)
- Mock external dependencies (network, file system)

## Key Dependencies

- **swift-argument-parser**: CLI argument parsing
- **GRDB.swift**: Type-safe SQLite access
- **mlx-swift-lm**: Apple Silicon ML inference
- **grpc-swift**: gRPC for daemon communication
- **blake3-swift**: Fast cryptographic hashing
- **swift-syntax**: Swift AST manipulation
- **swift-tree-sitter**: Syntax tree parsing

## Architecture Decision Records (ADRs)

Important design decisions are documented in `Docs/ADR/`:

- **ADR-0001**: Single ECS in AnigmaCore
- **ADR-0002**: Job and Workflow Model
- **ADR-0003**: No Python or Node at Runtime
- **ADR-0004**: Module Boundaries (critical for development)
- **ADR-0005**: Diaplasion Rename

Always check for relevant ADRs before making architectural changes.

## Security Considerations

- All file system access goes through `StorageCore` (sandboxed)
- Code execution is governed and auditable
- Secrets never stored in code or commits
- Evidence cryptographically signed with BLAKE3
- Compliance with institutional policies (e.g., FERPA for DSPS)
