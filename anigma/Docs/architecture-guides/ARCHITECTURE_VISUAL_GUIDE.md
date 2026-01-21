# Anigma Architecture Visual Guide

**Date:** January 9, 2026
**Purpose:** Visual reference for understanding system structure and data flow

---

## 1. System Layers Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    APP SHELLS (User Interfaces)                          │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────────┐│
│  │ AnigmaAppMac   │  │ HarmoniaCLI    │  │ AnigmaMCPServer            ││
│  │ (SwiftUI)      │  │ (CLI REPL)     │  │ (IDE Integration)          ││
│  └────────┬────────┘  └────────┬───────┘  └──────────┬─────────────────┘│
└───────────┼─────────────────────┼──────────────────────┼──────────────────┘
            │                     │                      │
            └─────────────────────┼──────────────────────┘
                                  │ create ONE PlatformRuntime
                                  ▼
┌──────────────────────────────────────────────────────────────────────────┐
│        TIER 3: CAPABILITY MODULES (Domain Logic, Features)               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ HarmoniaModule   │ DiaplasionModule │ AccessumModule │ Outlineum     │ │
│  │ (AI Assistant)   │ (Documents)      │ (Accessibility) │ (Art)         │ │
│  └────────┬────────┘  └────────┬───────┘  └───────┬──────┘  └─────┬──────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │ Pragma       │  │ Conexus      │  │ ContextumModule                 │
│  │ (Projects)   │  │ (Networking) │  │ (Context)                       │
│  └──────┬───────┘  └──────┬───────┘  └───────┬──────┘                   │
│                                                                          │
│  Module Registration: await Module.register(runtime: PlatformRuntime)  │
│  ├─ Register workflows                                                  │
│  ├─ Register systems                                                    │
│  └─ Register schemas (database tables)                                  │
└────────────────────────────┬─────────────────────────────────────────────┘
                             │ submit workflows
                             ▼
┌──────────────────────────────────────────────────────────────────────────┐
│   TIER 2: PLATFORM RUNTIME (Integration & Governance Enforcement)        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ PlatformRuntime Actor (THE ONLY execution path for all ops)     │   │
│  │ ├─ ExecutionAuthority: Run workflows/jobs with governance check │   │
│  │ ├─ EvidenceAuthority: Record cryptographic evidence             │   │
│  │ ├─ DatabaseAuthority: Governed database mutations               │   │
│  │ ├─ ArtifactAuthority: Unified artifact storage                  │   │
│  │ └─ World: ONE ECS instance per app                              │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Infrastructure (Just Enhanced):                                        │
│  ├─ MCPExecutionCoordinator: Tool execution hub                        │
│  ├─ MCPToolHandler: Base handler with metrics/streaming               │
│  ├─ MCPParallelization: Bounded concurrency (AsyncSemaphore)         │
│  └─ MCPStructuredErrors: Error codes with recovery hints              │
│                                                                          │
│  Every mutation checked against Tier 1 governance:                      │
│  1. Check KillSwitch: isWriteAllowed()?                                │
│  2. Check AccessController: hasCapability(principal)?                  │
│  3. Check WriteGate: qualityCheck(operation)?                          │
│  4. Execute operation                                                   │
│  5. Record evidence                                                     │
└────────────────────────────┬─────────────────────────────────────────────┘
                             │ evaluate policies
                             ▼
┌──────────────────────────────────────────────────────────────────────────┐
│    TIER 1: GOVERNANCE & IDENTITY (Constitutional, Pure Policy)           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ OperatingMode   │ KillSwitch   │ WriteGate      │ AccessController  │ │
│  │ • readOnly      │ (Emergency   │ (Quality       │ (RBAC/ABAC)       │ │
│  │ • assistive     │  halt)       │  checks)       │ • 40+ capabilities│ │
│  │ • autopilot     │              │                │ • Trust tiers     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                                          │
│  ┌──────────────┐                                                       │
│  │ LifecycleManager  → Data retention policies                         │
│  └──────────────┘                                                       │
│                                                                          │
│  KEY INVARIANT: Pure policy - no execution, no storage, no platform     │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│           FOUNDATION: CORE INFRASTRUCTURE (Tier 1 & 2 Support)           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ AnigmaCore   │  │ DatabaseCore │  │ ContractsCore│  │ StorageCore   │ │
│  │ • ECS        │  │ • SQLite     │  │ • Workflows  │  │ • File I/O    │ │
│  │ • Jobs       │  │ • GRDB       │  │ • Contracts  │  │ • Sandboxing  │ │
│  │ • Scheduler  │  │ • Migrations │  │ • Types      │  │ • Permissions │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │ AnigmaPrimitives │ SecurityCore  │ TelemetryCore │                   │
│  │ • Basic types    │ • Auth        │ • Metrics     │                   │
│  │ • Protocols      │ • Encryption  │ • Tracing     │                   │
│  └──────────────┘  └──────────────┘  └──────────────┘                   │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Entity-Component-System (ECS) Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    World (Central ECS Container)                │
│                    public actor World                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  EntityId → Component1 → Component2 → Component3               │
│  (UUID)     Data      Data           Data                       │
│                                                                 │
│  Example:                                                       │
│  JobId("abc-123") →  JobComponent  →  ProgressComponent        │
│                      {                 {                        │
│                       id: "build"       percent: 45%             │
│                       status: running   phase: "linking"        │
│                      }                 }                        │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  Systems observe components and perform logic:                 │
│                                                                 │
│  public actor BuildSystem: AsyncSystem {                       │
│      func update(world: World) async throws {                  │
│          let jobs = await world.entities(with: JobComponent.self)
│          for jobId in jobs {                                   │
│              let component = await world.component(JobComponent.self, for: jobId)
│              // Process job...                                 │
│          }                                                     │
│      }                                                         │
│  }                                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Query Examples:
═══════════════════════════════════════════════════════════════════

// Single component query
let jobs = await world.entities(with: JobComponent.self)
// O(1) component lookup, returns [EntityId]

// Multi-component query (join)
let activeJobs = await world.entities(with: JobComponent.self, ProgressComponent.self)
// Returns entities that have BOTH components

// Modify components
try await world.setComponent(JobComponent(...), for: jobId)
// Triggers observers for JobComponent changes

// Remove entity (cascade deletes all components)
try await world.removeEntity(jobId)
```

---

## 3. Job System & Workflow Execution

```
Job Creation (User/Module)
         │
         ▼
┌────────────────────────────────────────────┐
│ Job Enqueued with properties:              │
│ ├─ ID: JobId (UUID)                        │
│ ├─ Type: "harmonia.refactor"               │
│ ├─ Status: pending                         │
│ ├─ Payload: AnyCodable(user input)         │
│ ├─ Priority: high/normal/low               │
│ ├─ RetryPolicy: exponential backoff        │
│ └─ Stored in: Database, as JobComponent   │
└────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────┐
│ Scheduler.process()                        │
│ Picks next job by priority                 │
│ Updates status: pending → scheduled        │
└────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────┐
│ MCPExecutionCoordinator                    │
│ ├─ Check Governance                        │
│ │  ├─ KillSwitch.isWriteAllowed()?        │
│ │  ├─ AccessController.hasCapability()?   │
│ │  └─ WriteGate.evaluate()?               │
│ ├─ Status: pending → running              │
│ └─ Stream progress events                 │
└────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────┐
│ WorkflowRegistry.lookup(jobType)           │
│ Finds corresponding Workflow<Input,Output> │
│ Extracts input from job.payload            │
└────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────┐
│ Workflow.execute(input, context)           │
│ ├─ Perform domain logic                    │
│ ├─ May submit sub-jobs                     │
│ └─ Returns Output                          │
└────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────┐
│ Result Handling                            │
│ ├─ Success: Status → completed, store result │
│ ├─ Failure: Status → failed, check retry   │
│ │   ├─ Retryable? → Schedule retry         │
│ │   └─ Not retryable? → User error         │
│ └─ Evidence recorded automatically        │
└────────────────────────────────────────────┘

Job Status State Machine:
═══════════════════════════════════════════════════════════════════

pending ─────────► scheduled ────────► running
   ▲                                       │
   │                                       ├─► completed (success)
   │                                       │
   │                                       ├─► failed
   │                                       │   ├─► (retryable? → pending)
   │                                       │   └─► (not retryable? → error)
   │                                       │
   │                                       ├─► cancelled (user stop)
   │                                       │
   └────────── deferred ◄─────────────────┘
   (wait for timeout/resource)

   expired (exceeded timeout)
```

---

## 4. Governance Decision Flow

```
                        Operation Request
                               │
                               ▼
                    ┌──────────────────────┐
                    │ KillSwitch Check     │
                    │ isWriteAllowed()?    │
                    └──────────┬───────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
                YES │                     │ NO
                    ▼                     ▼
        ┌──────────────────┐    ┌──────────────────┐
        │ Access Control   │    │ BLOCK OPERATION  │
        │ Check            │    │ (Kill switch is  │
        │ hasCapability()? │    │  activated)      │
        └────────┬─────────┘    └──────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
     YES│                 │NO
        ▼                 ▼
    ┌────────────┐   ┌──────────────────┐
    │ WriteGate  │   │ DENY ACCESS      │
    │ evaluate() │   │ (No capability)  │
    │ Quality    │   └──────────────────┘
    │ checks?    │
    └────┬───────┘
         │
    ┌────┴────────────────────┐
    │                         │
 YES│ (passes all checks)     │NO (fails quality check)
    ▼                         ▼
┌────────────────┐     ┌──────────────────┐
│ ALLOW          │     │ Evaluation based │
│ OPERATION      │     │ on check type:   │
│                │     │ • Blocking → DENY│
│ Record to DB   │     │ • Advisory → WARN│
│ & Evidence     │     │ (may still allow)│
└────────────────┘     └──────────────────┘

Example Scenarios:
═════════════════════════════════════════════════════════════════

Scenario 1: HarmoniaModule wants to write file
─────────────────────────────────────────────
KillSwitch: ON (normal) ✓
Capability: fs.writeProject ✓
WriteGate: "No .swiftpm edits" (advisory) ⚠️ → Allow with warning
Result: ALLOW (write to project files)

Scenario 2: Code makes system call
──────────────────────────────────
KillSwitch: OFF (emergency halt) ✗
Result: BLOCK immediately (no further checks)

Scenario 3: Bronze-tier model tries inference
──────────────────────────────────────────────
KillSwitch: ON ✓
Capability: inferenceRemote ✓
WriteGate: "No external API calls for unvetted models" (blocking) ✗
Result: DENY (model not trusted enough for API access)
```

---

## 5. Database & Evidence Flow

```
Operation Execution
        │
        ▼
┌──────────────────────────┐
│ Governance Checks       │
│ (described above)       │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ DatabaseActor            │
│ (SQLite WAL mode)        │
│                          │
│ Transaction {            │
│  1. Acquire lock        │
│  2. Execute mutation    │
│  3. Commit to DB        │
│  4. Write to WAL        │
│  5. Release lock        │
│ }                        │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ EvidenceAuthority        │
│                          │
│ Create Evidence {        │
│  operationId: UUID       │
│  type: "patch.apply"     │
│  principal: user         │
│  timestamp: now          │
│  input: {...}           │
│  output: {...}          │
│  duration: 234ms        │
│  hash: BLAKE3(bundle)   │
│ }                        │
│                          │
│ Store in CathedralModule│
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Return Result to Caller  │
│ (User/Module)           │
└──────────────────────────┘

Database Schema Example (BuildDiagnostics):
═════════════════════════════════════════════════════════════════════

jobs
├─ id (TEXT PRIMARY KEY)
├─ type (TEXT)
├─ status (TEXT)
├─ created_at (INTEGER)
└─ completed_at (INTEGER)

workflows
├─ id (TEXT PRIMARY KEY)
├─ job_id (TEXT, FOREIGN KEY)
├─ workflow_type (TEXT)
└─ input/output (BLOB)

evidence_bundles
├─ id (TEXT PRIMARY KEY)
├─ operation_type (TEXT)
├─ principal_id (TEXT)
├─ timestamp (INTEGER)
├─ content_hash (TEXT)
├─ signature (BLOB)
└─ verified (BOOLEAN)

build_cache (NEW - just added)
├─ file_path (TEXT)
├─ file_hash (TEXT)
├─ object_artifact_id (TEXT)
├─ cache_hit_rate (REAL)
└─ last_accessed (INTEGER)
```

---

## 6. Tool Execution Pipeline

```
MCP Protocol Message (JSON-RPC)
│ { "jsonrpc": "2.0",
│   "method": "tools/call",
│   "params": {
│     "name": "read_file",
│     "arguments": { "path": "src/main.swift" }
│   }
│ }
▼
AnigmaMCPServer.process()
│
▼
┌────────────────────────────────────────┐
│ MCPExecutionCoordinator                │
│ (Central tool execution hub)           │
│ ├─ Check governance (KillSwitch, etc.) │
│ ├─ Look up tool handler                │
│ ├─ Create execution context            │
│ └─ Invoke handler with streaming       │
└────────────────┬──────────────────────┘
                 │
                 ▼
         ┌──────────────────┐
         │ Tool Handler     │
         │ (MCPToolHandler) │
         │                  │
         │ • Extract args   │
         │ • Validate input │
         │ • Collect metrics│
         └────────┬─────────┘
                  │
                  ▼
        ┌────────────────────────┐
        │ Tool Implementation    │
        │ (e.g., ReadFileTool)   │
        │ ├─ Read file content   │
        │ ├─ Apply permissions   │
        │ ├─ Detect language     │
        │ └─ Return structured   │
        │   result               │
        └────────┬───────────────┘
                 │
                 ▼
        ┌──────────────────────┐
        │ Result Streaming     │
        │ ├─ Progress events   │
        │ ├─ Partial results   │
        │ ├─ Metrics recorded  │
        │ └─ Evidence logging  │
        └────────┬─────────────┘
                 │
                 ▼
        MCP Response (streamed)
        { "jsonrpc": "2.0",
          "result": {
            "content": [ ... ],
            "metrics": { ... }
          }
        }

MCPParallelization Pattern (New):
════════════════════════════════════════════════════════════════════

For handling 100s of tool calls:

┌─────────────────────────────────────┐
│ AsyncSemaphore(maxConcurrent: 4)    │
│ ├─ Limits concurrent operations     │
│ ├─ Queues excess operations         │
│ └─ Releases slots automatically     │
└────────────┬────────────────────────┘
             │
             ▼
    ┌─────────────────────┐
    │ executeConcurrently │
    │ (parallel batch)    │
    │ • Distribute work   │
    │ • Collect results   │
    └────────┬────────────┘
             │
             ▼
    ┌─────────────────────┐
    │ executeInChunks     │
    │ (10K+ items)        │
    │ • Process in chunks │
    │ • Control memory    │
    └────────┬────────────┘
             │
             ▼
    ┌─────────────────────┐
    │ executeWithRetry    │
    │ (exponential backoff)│
    │ • Retry failures    │
    │ • Track attempts    │
    └─────────────────────┘
```

---

## 7. Module Integration Pattern

```
Module Registration Flow:

1. App Startup
   └─► PlatformRuntime.local(config: .production)

2. Module Auto-Registration (via Package.swift plugins)
   └─► HarmoniaModule.register(runtime: runtime)
       │
       ├─ await runtime.registerSchema(HarmoniaSchema.tables)
       │  └─ Migrations applied automatically
       │
       ├─ await runtime.registerWorkflow(HarmoniaWorkflow.self)
       │  └─ Workflow added to registry
       │
       ├─ try await runtime.registerSystem(BuildSystem())
       │  └─ System added to World
       │
       └─ await runtime.registerTool(ReadFileTool())
          └─ Tool added to ToolRouter

3. Runtime Initialization
   └─ All systems get ONE World instance
   └─ Jobs scheduler starts
   └─ Governance checks installed

4. User Request (via MCP/CLI)
   └─ MCPExecutionCoordinator.execute(request)
      ├─ Check governance
      ├─ Route to appropriate tool
      ├─ Stream results
      └─ Record evidence

Module File Structure:
════════════════════════════════════════════════════════════════════

MyModule/
├─ Sources/
│  ├─ MyModule.swift                    ← Public API
│  ├─ MyWorkflow.swift
│  ├─ MySystem.swift
│  ├─ MyComponent.swift
│  ├─ Tools/
│  │  ├─ MyTool1.swift
│  │  └─ MyTool2.swift
│  └─ Schemas/
│     └─ MySchema.swift
│
└─ Tests/
   └─ MyModuleTests.swift
```

---

## 8. Data Flow: Real Example (File Edit)

```
User Request (MCP):
┌────────────────────────────────────────────────────────┐
│ { "method": "tools/call",                              │
│   "params": {                                           │
│     "name": "edit_file",                               │
│     "arguments": {                                      │
│       "path": "Sources/main.swift",                     │
│       "edits": [{"line": 10, "text": "let x = 42"}]   │
│     }                                                   │
│   }                                                     │
│ }                                                       │
└──────────────────────┬─────────────────────────────────┘
                       │
                       ▼
              AnigmaMCPServer receives request
                       │
                       ▼
         MCPExecutionCoordinator.execute()
         │
         ├─► 1. Governance Checks
         │   ├─ KillSwitch.isWriteAllowed() → true
         │   ├─ AccessController.hasCapability("fs.writeProject") → true
         │   └─ WriteGate.evaluate("edit_file") → pass
         │
         ├─► 2. Tool Lookup
         │   └─ ToolRouter → EditFileTool
         │
         ├─► 3. Metrics Collection
         │   ├─ Start timer
         │   └─ Create execution context
         │
         ├─► 4. Tool Execution
         │   ├─ EditFileTool.execute(input, context)
         │   │  ├─ Load file
         │   │  ├─ Parse AST
         │   │  ├─ Apply edits
         │   │  ├─ Format code
         │   │  ├─ Verify syntax
         │   │  └─ Write to disk
         │   │
         │   └─ Stream progress events
         │       ├─ "parsing file"
         │       ├─ "applying edits (1/1)"
         │       └─ "formatting code"
         │
         ├─► 5. Result Structuring
         │   └─ Success result with:
         │       ├─ new_content
         │       ├─ diff
         │       └─ byte_count
         │
         ├─► 6. Metrics Recording
         │   └─ MCPMetrics.record()
         │       ├─ duration: 234ms
         │       ├─ bytes_written: 1024
         │       └─ success: true
         │
         ├─► 7. Evidence Recording
         │   └─ EvidenceAuthority.record()
         │       ├─ operationType: "edit_file"
         │       ├─ principal: "user"
         │       ├─ input: {path, edits}
         │       ├─ output: {diff, success}
         │       └─ hash: BLAKE3(bundle)
         │
         └─► 8. Return Response
             │
             ▼
         MCP Response (with streaming):
         ┌────────────────────────────────────────────────┐
         │ { "jsonrpc": "2.0",                            │
         │   "result": {                                  │
         │     "content": [{                              │
         │       "type": "text",                          │
         │       "text": "Edited file successfully..."    │
         │     }],                                        │
         │     "metadata": {                              │
         │       "diff": "...",                           │
         │       "duration_ms": 234,                      │
         │       "evidence_id": "evt-123"                 │
         │     }                                          │
         │   }                                            │
         │ }                                              │
         └────────────────────────────────────────────────┘
                       │
                       ▼
            User sees result in Claude Desktop
```

---

## 9. Concurrency Model (Swift 6)

```
┌────────────────────────────────────────────────────────┐
│ Mutable State MUST be Actor-Isolated                  │
└────────────────────────────────────────────────────────┘

❌ WRONG:
var globalState: Int = 0  // Data race!

✅ RIGHT:
actor StateManager {
    private var state: Int = 0

    func increment() {
        self.state += 1
    }
}

// Access only via async:
let manager = StateManager()
await manager.increment()

┌────────────────────────────────────────────────────────┐
│ All Public Types MUST be Sendable                     │
└────────────────────────────────────────────────────────┘

❌ WRONG:
public struct Job {
    public var mutableList: [String]  // Not Sendable
}

✅ RIGHT:
public struct Job: Sendable {
    public let id: JobId
    public let items: [String]  // Immutable, Sendable
}

┌────────────────────────────────────────────────────────┐
│ Async/Await for Long Operations                       │
└────────────────────────────────────────────────────────┘

async func processJob(_ job: Job) async throws -> Result {
    // Never blocks the thread
    // Scheduler can work on other tasks
    let result = try await executeWorkflow(job)
    return result
}

// Call from async context only:
let result = try await processJob(myJob)

Actor Isolation in Anigma:
════════════════════════════════════════════════════════════════════

┌──────────────┐
│ World        │ ← ONE per app, owns all entities/components
│ (actor)      │
└──────────────┘
       ▲
       │
   ┌───┴─────────────────────┐
   │                         │
┌──────────────┐   ┌──────────────────┐
│ Scheduler    │   │ DatabaseActor    │
│ (actor)      │   │ (actor)          │
└──────────────┘   └──────────────────┘
       │                   │
       └───────┬───────────┘
               │
         All write operations
         must be async/await
         through these actors
```

---

## Summary: System at a Glance

```
┌────────────────────────────────────────────────────────────┐
│ ANIGMA SYSTEM OVERVIEW                                    │
├────────────────────────────────────────────────────────────┤
│                                                            │
│ Entry Points:                                             │
│ • AnigmaAppMac - SwiftUI desktop app                      │
│ • HarmoniaCLI - Command-line REPL                         │
│ • AnigmaMCPServer - IDE integration (Claude Desktop)      │
│                                                            │
│ Core Architecture:                                         │
│ • ECS (Entity-Component-System) for data organization      │
│ • Actor-based concurrency (Swift 6)                       │
│ • Three-tier governance (Policy → Runtime → Modules)      │
│                                                            │
│ Storage:                                                  │
│ • SQLite with WAL for concurrent reads                    │
│ • Evidence recording (BLAKE3 signed)                      │
│ • Schema migrations on startup                            │
│                                                            │
│ Tool System:                                              │
│ • 20+ tools (read, edit, build, test, search, etc.)      │
│ • MCP-integrated for IDE support                          │
│ • Parallelization with bounded concurrency               │
│                                                            │
│ Governance:                                               │
│ • KillSwitch for emergency halt                           │
│ • WriteGate for quality checks                            │
│ • AccessController for RBAC/ABAC                          │
│ • Evidence recording for compliance                       │
│                                                            │
│ Features:                                                 │
│ • Local-first (no cloud dependencies)                     │
│ • Radical transparency (full audit trails)                │
│ • Institutional-grade (FERPA, HIPAA ready)               │
│ • Production-ready (Swift 6 safe)                         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

*Generated: January 9, 2026*
*Visual Guide Complete: Comprehensive architecture reference*
