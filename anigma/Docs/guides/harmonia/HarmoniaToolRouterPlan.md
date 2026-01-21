# Harmonia Tool Router Implementation Plan

> **Context:** We've stabilized the Swift6 migration spine: AST/regex paths are traced durably to SQLite, concurrency is hardened (WAL + busy_timeout + IMMEDIATE transactions + retries), circuit breaker exists for verification storms, and JSON envelopes are consistent. Next: turn Harmonia into a tool router that agents must use, with loop prevention and session DB support so agents stop getting stuck in repetitive tool-call loops.

---

## Goal

Implement a **"Harmonia Tool Router"** layer that exposes specialized, versioned tools (read/edit/build/test/git/trace) behind strict contracts, enforces loop-breaking policy, records evidence/decisions to SQLite, and supports disposable per-session databases that can be merged into a master ledger.

---

## Constraints

- **Keep Sigma gate light**: Do not pull doctrine/security-heavy targets into MigrationPipelineTests
- **No external runtime dependencies**: No Node/Python runtime requirement at execution time
- **JSON-first outputs**: Keep outputs stable and machine-readable
- **Prefer AnigmaPrimitives**: Add new primitives to AnigmaPrimitives and implementations to HarmoniaSpine/HarmoniaCLI
- **No string-match edit APIs**: Favor unified diff or byte-range patch with precondition hash

---

## Work Plan (Commit-Sized, In Order)

### Commit T1: Tool Contracts + Versioning Primitives

**Add `Sources/AnigmaPrimitives/ToolContracts/` with:**

```swift
// Core contract definition
public struct ToolContract: Codable, Sendable {
    public let name: String
    public let version: String
    public let inputSchema: JSONSchema
    public let outputSchema: JSONSchema
    public let requiredCapabilities: [String]
    public let loopBreakerConfig: LoopBreakerConfig
}

// Loop breaking configuration
public struct LoopBreakerConfig: Codable, Sendable {
    public let threshold: Int
    public let windowSeconds: Int
    public let cooldownSeconds: Int
    public let requiredRecoveryStrategy: RecoveryStrategy
}

// Recovery strategy definitions
public enum RecoveryStrategy: String, Codable, Sendable {
    case require_unified_diff
    case require_byte_range_patch
    case require_fresh_read_delta
    case escalate_to_human
}
```

**Implementation Tasks:**
- [ ] Add JSON encode/decode helpers with explicit contractVersion
- [ ] Add lightweight "tool registry" data structure that HarmoniaCLI can render as JSON
- [ ] Create unit tests for contract serialization/deserialization

**Acceptance:**
```bash
swift package describe
swift test --filter MigrationPipelineTests
```

---

### Commit T2: Loop Breaker for Tool Calls

**Add `Sources/HarmoniaSpine/Tools/ToolCallLoopBreaker.swift`:**

```swift
public actor ToolCallLoopBreaker {
    private var callHistory: [String: [CallSignature]] = [:]
    
    public struct CallSignature: Codable, Sendable {
        let toolName: String
        let filePath: String?
        let errorSignature: String?
        let contentHash: String?
        let timestamp: Int
    }
    
    public func checkLoopRisk(
        toolName: String, 
        filePath: String?, 
        errorSignature: String?, 
        contentHash: String?
    ) -> LoopRiskAssessment
}
```

**Key Features:**
- [ ] Track signatures: (toolName, filePath?, errorSignature, contentHash?) within sessionId
- [ ] Block after N repeats within time window; emit structured BlockReason including requiredRecoveryStrategy
- [ ] Special-case "no-op edit" loops: block immediately and require unified diff
- [ ] Persist loop events as trace/evidence rows using existing DB layer (new table: `tool_call_blocks`)
- [ ] Add tests in MigrationPipelineTests that simulate repeated blocked calls and assert DB rows + structured JSON response

**Acceptance:**
```bash
swift test --filter MigrationPipelineTests
```

---

### Commit T3: Tool Router Plumbing + Evidence Recording

**Add `Sources/HarmoniaSpine/Tools/ToolRouter.swift`:**

```swift
public actor ToolRouter {
    private let dbActor: DatabaseActor
    private let loopBreaker: ToolCallLoopBreaker
    private let toolRegistry: ToolRegistry
    
    public func executeToolCall(
        toolName: String,
        parameters: [String: Any],
        sessionId: String
    ) async throws -> ToolCallResponse
}
```

**Core Flow:**
1. [ ] Validate tool call against ToolContract
2. [ ] Run loop breaker preflight
3. [ ] Execute tool implementation
4. [ ] Record start/end + status + artifacts + errorSignature in SQLite (new tables: `tool_calls` + `tool_call_artifacts`)
5. [ ] Return ToolCallResponse JSON (success/result/error/blocked/evidenceId)

**CLI Integration:**
```bash
harmonia tool call --tool <name> --json '<params>'
harmonia tool contracts --format json
harmonia tool calls --session-id ... --limit ... --format json
```

**Acceptance:**
```bash
swift build --target HarmoniaCLI
swift test --filter MigrationPipelineTests
```

---

### Commit T4: Implement Specialized Tools (Minimum Viable Set)

**Implement tool handlers behind ToolRouter:**

#### read_file
```swift
public struct ReadFileResponse: Codable {
    let content: String
    let hash: String
    let size: Int64
    let mtime: Int
    let artifactPath: String
}
```

#### apply_patch
```swift
public struct ApplyPatchRequest: Codable {
    let patchType: PatchType  // unified_diff | byte_range
    let patch: String
    let preconditionHash: String
    let targetPath: String
}

public struct ApplyPatchResponse: Codable {
    let newHash: String
    let appliedChangeCount: Int
    let artifactPaths: [String]
    let success: Bool
    let errorMessage: String?
}
```

#### swift_build / swift_test
```swift
public struct SwiftBuildResponse: Codable {
    let status: BuildStatus
    let logsArtifactPath: String
    let buildArtifactPath: String?
    let durationMs: Int
}
```

#### git_diff / trace_query
- [ ] Standardized JSON responses with artifact paths
- [ ] Per-tool artifact capture under `Artifacts/tool-router/<sessionId>/<requestId>/...`

**Acceptance:**
```bash
swift test --filter MigrationPipelineTests
# Manual smoke: run read_file then apply_patch then swift_build and inspect JSON + artifacts
```

---

### Commit T5: Session DBs + Merge-to-Master

**Add DatabaseConfiguration support for session DB paths:**
```swift
public struct DatabaseConfiguration {
    public static func sessionDatabasePath(sessionId: String) -> String {
        return "Data/sessions/\(sessionId).sqlite"
    }
    
    public static func masterDatabasePath() -> String {
        return "Data/master.sqlite"
    }
}
```

**CLI Commands:**
```bash
harmonia session start --id <uuid> --db <path?>
harmonia session merge --id <uuid> --into <masterDbPath>
harmonia session end --id <uuid> --delete-db
```

**Merge Implementation using ATTACH DATABASE:**
```sql
-- Only merge append-only tables
INSERT OR IGNORE INTO master.tool_calls 
SELECT * FROM session.tool_calls;

INSERT OR IGNORE INTO master.tool_call_artifacts 
SELECT * FROM session.tool_call_artifacts;

INSERT OR IGNORE INTO master.tool_call_blocks 
SELECT * FROM session.tool_call_blocks;

INSERT OR IGNORE INTO master.session_lifecycle 
SELECT * FROM session.session_lifecycle;
```

**Key Features:**
- [ ] Idempotent inserts with stable primary keys (request_id/evidence_id)
- [ ] After merge: mark merged rows, then optionally delete session DB
- [ ] Do not "merge read models"; recompute derived views from master after merge
- [ ] Tests: Create session DB, write tool call rows, merge into temp master DB, assert counts and idempotence

**Acceptance:**
```bash
swift test --filter MigrationPipelineTests
```

---

### Commit T6: "Snap Out of Loop" Recovery UX

**Enhance blocked ToolCallResponse:**
```swift
public struct ToolCallResponse: Codable {
    let status: ResponseStatus  // success | error | blocked
    let result: [String: Any]?
    let error: String?
    let blocked: BlockedCallInfo?
    let evidenceId: String?
}

public struct BlockedCallInfo: Codable {
    let reason: String
    let minimalDiagnosis: String
    let requiredRecoveryStrategy: RecoveryStrategy
    let nextActionTemplate: String
    let evidenceId: String
}
```

**Recovery Template Example:**
```json
{
  "nextActionTemplate": "Call read_file, then submit unified diff with preconditionHash={preconditionHash}; no further apply_patch until hash changes."
}
```

**CLI Helper:**
```bash
harmonia tool explain-block --evidence-id <id> --format json
```

**Acceptance:**
```bash
swift test --filter MigrationPipelineTests
```

---

### Commit T7: BuildIngest Recovery via Tools

**Refactor BuildIngest to consume ToolRouter operations:**
- [ ] Replace ad-hoc process calls with ToolRouter.executeToolCall()
- [ ] Fix remaining Swift 6 issues in Sources/BuildIngest/*
- [ ] Emit BuildSession + SwiftDiagnostic cleanly through tool evidence system
- [ ] Add integration test that runs tiny build ingestion against fixture and records tool_calls rows

**Acceptance:**
```bash
swift build --target BuildIngest
swift test --filter MigrationPipelineTests
```

---

## Definition of Done

- ✅ **Agents can only perform filesystem/build/test mutations through Harmonia tools**
- ✅ **Looping "Edit oldString==newString" is blocked deterministically** and returns recovery instruction
- ✅ **Parallel agents can use session DBs**, then merge append-only records into a master DB and delete sessions
- ✅ **All outputs are stable JSON** suitable for automation. No reliance on logs for truth
- ✅ **Sigma gate remains green**

---

## Implementation Strategy

**Start with Commit T1 and proceed sequentially; do not skip tests between commits.**

Each commit should:
1. **Pass all tests**: `swift test --filter MigrationPipelineTests`
2. **Build successfully**: `swift build`
3. **Maintain Sigma gate compliance**: No heavy doctrine/security dependencies
4. **Preserve JSON-first contract**: All interfaces stable and machine-readable

This approach ensures incremental progress with continuous validation while building the foundation for governed agent interactions in Anigma.