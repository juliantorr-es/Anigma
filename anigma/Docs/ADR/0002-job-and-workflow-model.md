# ADR-0002: Job and Workflow Model (SUPERSEDED)

> **⚠️ SUPERSEDED BY THE SATURATED MISSION MODEL**  
> This ADR defines the legacy "Coordination-Bound" Job and Workflow model. While it remains valid for non-critical, CPU-bound tasks, all high-performance AI execution has transitioned to **Saturated Autonomous Missions** (See `anigma/Docs/root-docs/concepts/execution-model.md`).

> **Status:** Superseded  
> **Date:** 2025-12-06  
> **Superseded by:** Saturated Mission Model (2026-04-16)

---

## Context

The legacy repositories had varying approaches to job management:

- **Harmonia**: `HarmoniaJob` with status tracking, batch runner for pipelines
- **Outlineum**: JobTracker with artifacts, FastAPI-based job creation
- **AltMedia**: Pipeline-centric with step tracking
- **Apertum Accesum**: Minimal job concept, more event-driven

We need a unified job and workflow model that:
- Tracks units of work with inputs, outputs, and status
- Supports workflow-based system sequencing
- Enables scheduling with priorities and retries
- Works across all domain modules

---

## Decision

**AnigmaCore provides a unified Job and Workflow model.**

### Job Model

```swift
public struct Job: Identifiable, Codable, Sendable {
    public let id: JobId
    public let typeId: String              // e.g., "outlineum.outline"
    public let inputRefs: [EntityId]       // Entities to process
    public var outputRefs: [EntityId]      // Entities produced
    public var status: JobStatus
    public var priority: JobPriority
    public var metadata: [String: String]
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var errorInfo: String?
    public var retryCount: Int
    public var maxRetries: Int
    public var label: String?
}
```

### JobStatus

```swift
public enum JobStatus: String, Codable, Sendable {
    case pending    // In queue, not started
    case running    // Currently executing
    case completed  // Finished successfully
    case failed     // Finished with error
    case cancelled  // Manually cancelled
    case retrying   // Failed but will retry
}
```

### Workflow Model

```swift
public protocol Workflow: Sendable {
    var name: String { get }
    var jobTypeId: String { get }
    var systemNames: [String] { get }
    
    func prepare(job: Job, world: World) async throws
    func finalize(job: Job, world: World, result: JobResult) async throws
}
```

### Scheduler

Actor-based scheduler managing job queues:
- Priority ordering (critical > high > normal > low > background)
- Retry logic with configurable max retries
- Job lifecycle tracking

### WorkflowRunner

Connects jobs to system execution:
- Looks up workflow by job type
- Runs systems in order
- Reports success/failure

---

## Rationale

### Why Unified Jobs?

1. **Observability**: One place to see all work in progress
2. **Scheduling**: Single queue with priority handling
3. **Persistence**: Jobs can be saved/restored consistently
4. **Cross-module**: Same job model for OCR, outlines, refactoring, etc.

### Why Entity References?

Jobs reference entities, not raw files:
- Entities carry component state
- Systems operate on entities
- Outputs are entities that can be further processed

### Why Workflow Abstraction?

- Decouples job types from system implementations
- Modules register workflows, core executes them
- Supports prepare/finalize hooks for validation

### Alternatives Considered

1. **Per-module job models**: Rejected (same problems as per-module ECS)
2. **File-based inputs/outputs**: Rejected (loses component state)
3. **Hardcoded pipelines**: Rejected (not extensible)

---

## Consequences

### Positive

- Unified job tracking across all modules
- Priority scheduling works out of the box
- Retry logic is consistent
- Jobs are serializable for persistence

### Negative

- More ceremony to create a job vs. just running systems
- Workflow registration required at startup

### Neutral

- Job metadata is stringly-typed (flexible but less type-safe)

---

## Migration

### From Harmonia

```swift
// Before
let job = HarmoniaJob(type: .refactor, repoId: repo)
BatchRunner.run(job)

// After
let job = Job(
    typeId: "harmonia.refactor",
    inputRefs: [repoEntity]
)
await scheduler.enqueue(job)
```

### From Outlineum

```swift
// Before (Python)
job_id = job_tracker.create_job([entity_id])
world.run_systems(context)
job_tracker.update_status(job_id, "complete")

// After (Swift)
let job = Job(typeId: "outlineum.outline", inputRefs: [entity])
await scheduler.enqueue(job)
// Scheduler + WorkflowRunner handle the rest
```

---

## References

- Constitution: `Docs/AnigmaConstitution.md` Section 2.1
- Job types: `Sources/AnigmaCore/Jobs/Job.swift`
- Workflow types: `Sources/AnigmaCore/Jobs/Workflow.swift`
- Scheduler: `Sources/AnigmaCore/Jobs/Scheduler.swift`
