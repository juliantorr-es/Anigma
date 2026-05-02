> **⚠️ SATURATED REVIEW PENDING**  
> This ADR is pending review for compatibility with the **Saturated Autonomous** architecture. Use with caution.

# ADR-0006: Three-Tier Runtime Architecture

## Status
**PROPOSED** - 2026-01-08

## Context

### Current State

Anigma has a documented two-tier architecture (Governance Layer + Capability Modules), but runtime behavior reveals a different reality:

**Documented Architecture:**
- Tier 1: AnigmaCore (ECS + Jobs + Governance)
- Tier 2: Capability Modules (Harmonia, Cathedral, Diaplasion, etc.)
- Integration: Shared `World`, enforced governance, unified evidence

**Actual Runtime Behavior:**
- Each capability module operates independently
- No shared `World` instance in production
- Governance primitives exist but aren't called in mutation paths
- Evidence storage is fragmented across 3+ systems:
  - `ReceiptEngine` (ExecutionCore)
  - `CathedralModule.EvidenceStore`
  - `HarmoniaModule.EvidenceRecorder`
- Database is the only true integration point (via `DatabaseActor`)
- Modules create tables ad-hoc without coordination

**Problems:**
1. **Governance Gap**: `KillSwitch` and `WriteGate` are defined but not enforced
2. **Evidence Fragmentation**: Multiple overlapping evidence systems
3. **No Forcing Function**: Modules can bypass all governance/evidence infrastructure
4. **Multi-Platform Risk**: Adding iOS/web will multiply this chaos per platform

### The Missing Middle

The two-tier model assumes modules will "do the right thing" and use governance/evidence voluntarily. They don't, because there's no architectural enforcement. We need a **third tier** that is the only path for mutations, job execution, and evidence creation.

## Decision

We will transition to a **three-tier architecture** with a new **Platform Runtime** layer that owns execution, state management, evidence, and governance enforcement.

### Tier 1: Governance & Identity (Constitutional Layer)

**Location:** `AnigmaCore/Governance/`

**What it owns:**
- Policy definitions and evaluation logic
- Trust zones, capability tokens, ABAC rules
- Evidence *requirements* and *formats* (not storage)
- Operating modes (readOnly, assistive, autopilot)
- Governance primitives: `KillSwitch`, `WriteGate`, `AccessController`, `LifecycleManager`

**What it does NOT know:**
- Where evidence is stored
- How jobs are executed
- Platform specifics (macOS, iOS, web)
- Domain concepts (PDF, ML model, code analysis)

**Key invariant:** Governance is pure policy. It answers "is this allowed?" but doesn't execute or store.

### Tier 2: Platform Runtime (Integration Layer)

**Location:** `AnigmaCore/Runtime/` (new)

**What it owns:**
- **Single World Lifecycle**: ONE `World` instance per runtime
- **Execution Authority**: The only way to run workflows/jobs
- **Evidence Authority**: Unified evidence recording (consolidates 3 systems)
- **Database Authority**: Governed database access (wraps `DatabaseActor`)
- **Artifact Authority**: Unified artifact storage (consolidates `VaultAuthority`)
- **Scheduler**: Job queue and execution pipeline

**Core Contract:**
```swift
public actor PlatformRuntime {
    // Core authorities
    public let governance: GovernanceController
    public let evidence: EvidenceAuthority
    public let database: DatabaseAuthority
    public let artifacts: ArtifactAuthority
    public let execution: ExecutionAuthority

    // THE ONLY World
    private let world: World

    // THE ONLY way to execute work
    public func execute<W: Workflow>(
        _ workflow: W,
        context: ExecutionContext
    ) async throws -> Receipt
}
```

**Enforcement Rules:**
- Capability modules CANNOT create `World` instances
- Capability modules CANNOT call `DatabaseActor.execute()` directly
- Capability modules CANNOT write evidence directly
- Capability modules CANNOT store artifacts directly
- Capability modules CANNOT bypass governance

**Migration Path:**
- Phase 1: Create authorities as wrappers around existing infrastructure
- Phase 2: Wire governance into authority mutation paths
- Phase 3: Migrate modules to use authorities instead of direct access
- Phase 4: Make direct access impossible (remove public APIs)

### Tier 3: Capability Modules (Feature Layer)

**Location:** `Packages/` and `Sources/` (existing)

**What they can do:**
- Register systems/workflows with the runtime
- Submit jobs for execution
- Query database through `DatabaseAuthority`
- Request artifacts from `ArtifactAuthority`
- Emit events/receipts to `EvidenceAuthority`

**What they cannot do:**
- Mutate state without governance checks
- Create database tables directly (register schemas instead)
- Write evidence directly (emit to authority instead)
- Run external processes directly (submit to execution authority)

**Module Registration Pattern:**
```swift
public enum HarmoniaModule {
    public static func register(runtime: PlatformRuntime) async throws {
        // Register workflows
        await runtime.registerWorkflow(CodeAnalysisWorkflow.self)

        // Register systems
        await runtime.registerSystem(ConcurrencySyncSystem.self)

        // Register schemas (runtime manages migrations)
        try await runtime.registerSchema(HarmoniaSchema.sessions)
    }
}
```

**Workflow Execution Pattern:**
```swift
public struct CodeAnalysisWorkflow: Workflow {
    public func execute(
        context: WorkflowContext,
        runtime: PlatformRuntime
    ) async throws -> Receipt {
        // Query through authority (governed)
        let files = try await runtime.database.query(...)

        // Mutate through authority (governed + evidenced)
        try await runtime.database.mutate(mutation, context: context)

        // Runtime automatically records evidence
        return context.receipt
    }
}
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  App Shells (UI Layer)                   │
│  AnigmaAppMac, AnigmaAppIOS, HarmoniaCLI, AnigmaDaemon  │
│             Each creates ONE PlatformRuntime             │
└──────────────────────┬──────────────────────────────────┘
                       │ submit jobs, render results
                       ▼
┌─────────────────────────────────────────────────────────┐
│          Tier 3: Capability Modules (Features)          │
│    HarmoniaModule, DiaplasionModule, AccessumModule     │
│     Register workflows/systems, emit events/receipts    │
└──────────────────────┬──────────────────────────────────┘
                       │ register, submit, query, mutate
                       ▼
┌─────────────────────────────────────────────────────────┐
│      Tier 2: Platform Runtime (Integration Layer)       │
│  ┌───────────────────────────────────────────────────┐  │
│  │ PlatformRuntime Actor                             │  │
│  │  - World (ONE instance)                           │  │
│  │  - ExecutionAuthority (workflow/job runner)       │  │
│  │  - EvidenceAuthority (unified evidence)           │  │
│  │  - DatabaseAuthority (governed mutations)         │  │
│  │  - ArtifactAuthority (unified storage)            │  │
│  │  - Scheduler (job queue)                          │  │
│  └─────────────────┬─────────────────────────────────┘  │
│                    │ consult, record                     │
│                    ▼                                     │
│  ┌─────────────────────────────────────────────────┐    │
│  │ GovernanceController (from Tier 1)              │    │
│  │  - KillSwitch, WriteGate, AccessController      │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────┬──────────────────────────────────┘
                       │ evaluate policies
                       ▼
┌─────────────────────────────────────────────────────────┐
│     Tier 1: Governance & Identity (Constitutional)      │
│    Policy definitions, trust zones, evidence formats    │
│           NO execution, NO storage, NO platform         │
└─────────────────────────────────────────────────────────┘
```

## Authority Contracts

### EvidenceAuthority

**Purpose:** Consolidate `ReceiptEngine`, `CathedralModule.EvidenceStore`, and `HarmoniaModule.EvidenceRecorder` into ONE evidence system.

```swift
public actor EvidenceAuthority {
    /// Record evidence for an operation
    /// - Enforces evidence format requirements from Tier 1
    /// - Stores in unified schema
    /// - Returns cryptographically signed receipt
    public func record(
        operation: OperationType,
        principal: Principal,
        payload: EvidencePayload,
        governance: GovernanceDecision
    ) async throws -> Receipt

    /// Query evidence with access control
    public func query(
        filter: EvidenceFilter,
        principal: Principal
    ) async throws -> [EvidenceBundle]

    /// Verify evidence chain integrity
    public func verify(
        receiptId: ReceiptID
    ) async throws -> VerificationResult
}
```

**Storage:** Uses `DatabaseAuthority` for persistence (not direct `DatabaseActor`).

### DatabaseAuthority

**Purpose:** Wrap `DatabaseActor` with governance enforcement and schema management.

```swift
public actor DatabaseAuthority {
    /// Register a module schema (called during module registration)
    /// Runtime performs migrations, not modules
    public func registerSchema(_ schema: ModuleSchema) async throws

    /// Execute a governed query (read-only, no governance needed)
    public func query<T>(
        _ request: DatabaseRequest<T>
    ) async throws -> [T]

    /// Execute a governed mutation (write-gate + kill-switch checked)
    /// - Checks governance before execution
    /// - Records evidence after execution
    /// - Returns receipt
    public func mutate(
        _ mutation: DatabaseMutation,
        context: ExecutionContext
    ) async throws -> MutationReceipt

    /// Execute in transaction (all mutations governed)
    public func transaction(
        _ block: @Sendable (DatabaseAuthority) async throws -> Void
    ) async throws
}
```

**Enforcement:** EVERY `mutate()` call checks `KillSwitch` and `WriteGate` before executing.

### ArtifactAuthority

**Purpose:** Consolidate `VaultAuthority` and scattered artifact storage into ONE system.

```swift
public actor ArtifactAuthority {
    /// Store an artifact with evidence
    /// - Enforces storage policies from governance
    /// - Records evidence of storage
    /// - Returns content-addressed ID
    public func store(
        _ artifact: Artifact,
        evidence: Receipt,
        context: ExecutionContext
    ) async throws -> ArtifactID

    /// Retrieve artifact with access control
    public func retrieve(
        _ id: ArtifactID,
        principal: Principal
    ) async throws -> Artifact

    /// List artifacts matching criteria
    public func list(
        filter: ArtifactFilter,
        principal: Principal
    ) async throws -> [ArtifactMetadata]
}
```

### ExecutionAuthority

**Purpose:** Own workflow/job execution pipeline with governance and evidence enforcement.

```swift
public actor ExecutionAuthority {
    /// Execute a workflow with full governance
    /// 1. Check governance (can this principal run this workflow?)
    /// 2. Execute workflow steps
    /// 3. Record evidence for each mutation
    /// 4. Return comprehensive receipt
    public func execute<W: Workflow>(
        _ workflow: W,
        context: ExecutionContext
    ) async throws -> Receipt

    /// Submit a job to the scheduler
    public func submit(_ job: Job) async throws -> JobID

    /// Get job status
    public func jobStatus(_ id: JobID) async throws -> JobRecord
}
```

## Execution Flow (Full Stack)

### Example: Harmonia Code Analysis

```
1. User Action (App Shell)
   ├─ AnigmaAppMac receives "analyze file" command
   └─ Creates ExecutionContext(principal: user, project: "myapp")

2. Workflow Submission (Tier 3 → Tier 2)
   ├─ App submits: runtime.execute(CodeAnalysisWorkflow(), context)
   └─ ExecutionAuthority receives request

3. Governance Check (Tier 2 → Tier 1)
   ├─ ExecutionAuthority asks: governance.canWrite(proposal)
   │  ├─ KillSwitch.isWriteAllowed() → true
   │  ├─ WriteGate.evaluate() → allowed
   │  └─ AccessController.canExecute() → true
   └─ If denied: throw GovernanceError.writeBlocked

4. Workflow Execution (Tier 2 → Tier 3 → Tier 2)
   ├─ CodeAnalysisWorkflow.execute(context, runtime)
   │  ├─ Query: runtime.database.query(FileQuery(...))
   │  │  └─ DatabaseAuthority → DatabaseActor (no governance for reads)
   │  ├─ Analysis: analyzeCode(files) [pure computation]
   │  └─ Mutate: runtime.database.mutate(AnalysisResultMutation(...))
   │     ├─ DatabaseAuthority checks governance AGAIN
   │     ├─ DatabaseActor.execute(SQL)
   │     └─ EvidenceAuthority.record(operation: .databaseMutation)
   └─ Workflow returns result

5. Evidence Recording (Tier 2)
   ├─ ExecutionAuthority records workflow evidence:
   │  ├─ Operation: "harmonia.code_analysis"
   │  ├─ Principal: user
   │  ├─ Inputs: [file entity IDs]
   │  ├─ Outputs: [analysis entity IDs]
   │  ├─ Governance decision: logged
   │  └─ Hash: BLAKE3(evidence bundle)
   └─ EvidenceAuthority.record() → Receipt

6. Receipt Return (Tier 2 → App Shell)
   ├─ ExecutionAuthority returns Receipt to app
   └─ App displays: "Analysis complete. Receipt: abc123..."
```

**Key Points:**
- **TWO governance checks**: One for workflow execution, one for mutation
- **Evidence at every level**: Workflow execution + each mutation
- **No bypass possible**: Modules CANNOT call DatabaseActor directly
- **Unified trail**: All evidence in one system (EvidenceAuthority)

## Migration Strategy

### Phase 1: Create Runtime Skeleton (Non-Breaking)
**Goal:** Add PlatformRuntime and authorities as wrappers around existing infrastructure.

**Tasks:**
1. Create `AnigmaCore/Runtime/PlatformRuntime.swift`
2. Create authority protocols and initial implementations:
   - `EvidenceAuthority` (wraps existing systems)
   - `DatabaseAuthority` (wraps DatabaseActor)
   - `ArtifactAuthority` (wraps VaultAuthority)
   - `ExecutionAuthority` (wraps job queue)
3. Make authorities delegate to existing systems (backward-compatible)
4. Add tests for authority contracts

**Success Criteria:**
- PlatformRuntime can be instantiated
- Authorities work alongside existing direct access
- No breaking changes to existing code

### Phase 2: Wire Governance (Breaking but Localized)
**Goal:** Enforce governance in authority mutation paths.

**Tasks:**
1. Add governance checks to `DatabaseAuthority.mutate()`
2. Add governance checks to `EvidenceAuthority.record()`
3. Add governance checks to `ExecutionAuthority.execute()`
4. Update one module (HarmoniaModule) to use authorities
5. Prove governance enforcement works end-to-end

**Success Criteria:**
- KillSwitch actually blocks mutations
- WriteGate evaluations appear in audit log
- HarmoniaModule cannot bypass governance

### Phase 3: Migrate Modules (One at a Time)
**Goal:** Move all capability modules to use runtime authorities.

**Tasks:**
1. Migrate HarmoniaModule to register with runtime
2. Migrate CathedralModule (consolidate into EvidenceAuthority)
3. Migrate DiaplasionModule, AccessumModule, OutlineumModule, etc.
4. Remove duplicate evidence systems (ReceiptEngine, HarmoniaModule.EvidenceRecorder)

**Success Criteria:**
- All modules use `PlatformRuntime` APIs
- No direct `DatabaseActor.execute()` calls in modules
- Evidence is unified in EvidenceAuthority

### Phase 4: Update App Shells
**Goal:** App shells create and own the PlatformRuntime.

**Tasks:**
1. Update `AnigmaDaemon` to host runtime
2. Update `AnigmaAppMac` to create single runtime
3. Update `HarmoniaCLI` to use runtime (local or remote)
4. Add runtime lifecycle management (startup, shutdown)

**Success Criteria:**
- ONE runtime per app instance
- All work flows through the runtime
- Multi-platform ready (same runtime contract everywhere)

### Phase 5: Cleanup and Lockdown
**Goal:** Remove escape hatches, enforce architecture.

**Tasks:**
1. Make `DatabaseActor.execute()` internal (not public)
2. Remove direct evidence table creation from modules
3. Update CLAUDE.md to reflect three-tier architecture
4. Add architecture tests that fail if modules bypass runtime
5. Document migration guide for future modules

**Success Criteria:**
- Modules CANNOT bypass runtime (compile-time enforcement)
- Architecture tests pass
- Documentation matches reality

## Multi-Platform Impact

### With Three-Tier Architecture

Each platform creates ONE runtime with the same contract:

```swift
// macOS app
let runtime = PlatformRuntime.local(config: .production)

// iOS app (same contract!)
let runtime = PlatformRuntime.local(config: .production)

// CLI (remote daemon)
let runtime = PlatformRuntime.remote(daemon: daemonURL)

// Daemon (authority host)
let runtime = PlatformRuntime.local(config: .daemon)
```

**Benefits:**
- Governance is platform-agnostic (enforced by runtime)
- Evidence is unified (one storage system)
- Modules work identically across platforms (same runtime APIs)
- iOS backgrounding can't break governance (runtime manages lifecycle)

### Without Three-Tier Architecture

Each platform would need to:
- Recreate governance enforcement
- Manage its own evidence storage
- Handle database access differently
- Risk drift between platforms

Result: "Five slightly different interpretations of Anigma."

## Consequences

### Positive
1. **Governance Actually Works**: KillSwitch and WriteGate are enforced, not optional
2. **Evidence is Unified**: One storage system, one schema, one truth
3. **Multi-Platform Ready**: Same runtime contract across macOS, iOS, web
4. **Architecture is Enforced**: Modules cannot bypass governance (compile-time + runtime)
5. **Debugging is Easier**: All operations flow through known choke points
6. **Testing is Simpler**: Mock the runtime, not 10 different subsystems

### Negative
1. **Migration Effort**: Need to update ~15 capability modules
2. **API Changes**: Modules must change from direct DB access to authority APIs
3. **Runtime Overhead**: Extra actor hops for governance checks (minimal in practice)
4. **Learning Curve**: Developers must understand three-tier model

### Neutral
1. **More Actors**: Runtime adds 4+ new actors to the system
2. **Larger API Surface**: Authority protocols add ~20 new public APIs
3. **Documentation Needs**: Requires updating CLAUDE.md, adding migration guide

## Alternatives Considered

### Alternative 1: Keep Two-Tier, Document Reality
**Description:** Update CLAUDE.md to say "modules are independent, database is integration layer."

**Pros:**
- No migration needed
- Matches current behavior

**Cons:**
- Governance remains unenforced
- Evidence stays fragmented
- Multi-platform will be chaos

**Verdict:** This is giving up on the governed AI vision.

### Alternative 2: Enforce Two-Tier with Linter
**Description:** Use SwiftLint rules to prevent direct DatabaseActor access.

**Pros:**
- No runtime overhead
- Compile-time enforcement

**Cons:**
- Linter can be disabled/bypassed
- Doesn't solve evidence fragmentation
- Doesn't provide integration layer for multi-platform
- Policy enforcement still manual

**Verdict:** This is architectural theater without substance.

### Alternative 3: Microservices Architecture
**Description:** Split each module into a separate service with gRPC APIs.

**Pros:**
- Strong isolation
- Independent scaling

**Cons:**
- Massive complexity increase
- Not suitable for local-first architecture
- Doesn't solve governance enforcement (each service still needs it)
- Deployment nightmare

**Verdict:** Wrong tool for a monolithic, local-first system.

## References

- **ADR-0001**: Single ECS in AnigmaCore (establishes World as integration point)
- **ADR-0002**: Job and Workflow Model (establishes execution patterns)
- **ADR-0004**: Module Boundaries (establishes dependency rules)
- **CLAUDE.md**: Documents two-tier architecture (needs update)
- **Backend Integration Analysis (2026-01-08)**: Analysis that revealed architectural drift

## Implementation Plan

See migration strategy (Phase 1-5) above.

**Start Date:** 2026-01-08
**Target Completion:** TBD (phased rollout)
**Breaking Changes:** Yes (Phase 2+)
**Backward Compatibility:** Phase 1 only

## Success Metrics

1. **Governance Enforcement**: 100% of mutations pass through WriteGate and KillSwitch
2. **Evidence Unification**: All evidence stored in one system (EvidenceAuthority)
3. **Module Compliance**: 0 direct `DatabaseActor.execute()` calls in capability modules
4. **Multi-Platform Readiness**: Same `PlatformRuntime` contract works on macOS, iOS
5. **Architecture Tests**: Tests fail if governance is bypassed

---

**Proposed by:** Claude Code (AI) + User
**Review Required:** Yes
**Impact:** High (affects all modules and app shells)
