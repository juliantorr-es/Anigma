# SURFACE.WorkBoardProviding

## Surface Definition
**Surface Name**: WorkBoardProviding  
**Authority Boundary**: Core Governance Layer (ContractsCore intents + Harmonia policy gates)  
**Implementation Location**: Capability Module (PragmaModule/Capability/WorkBoard) with adapters to PragmaModule/Services  
**Lease Required**: Yes - changes to this surface require a surface lease.

**Related Surfaces**:
- `Docs/governance/contract-artifacts/SURFACE.ExecutorProfileProviding.md`
- `Docs/governance/contract-artifacts/SURFACE.WorkBoardMCPBridge.md`

## Contract Requirements

### Core Interface
All implementations MUST conform to `WorkBoardProviding`:

```swift
public protocol WorkBoardProviding: Sendable {
    func boardSnapshot(scope: WorkBoardScope, trustTier: TrustTier) async throws -> WorkBoardSnapshot
    func boardStream(scope: WorkBoardScope, trustTier: TrustTier) -> AsyncThrowingStream<WorkBoardSnapshot, Error>
    func submitIntent(_ intent: WorkBoardIntent) async throws -> WorkBoardIntentResult
    func canSubmitIntent(_ intent: WorkBoardIntent) async throws -> Bool
}
```

### Work Board IR (Domain)
The Work Board IR is a domain snapshot that renderers consume to build UI. It is NOT a mutable source of truth.
- Projects and tasks MUST be projections of `ProjectComponent` and `TaskComponent` from `PragmaModule`.
- Attempts, worktrees, and review artifacts are Work Board additions and must not replace Pragma work items.

```swift
public struct WorkBoardScope: Sendable, Codable {
    public let projectId: WorkItemId?
    public let taskIds: [WorkItemId]?
    public let includeArchived: Bool
}

public struct WorkBoardSnapshot: Sendable, Codable {
    public let snapshotId: String
    public let generatedAt: Date
    public let scope: WorkBoardScope
    public let projects: [WorkBoardProject]
    public let tasks: [WorkBoardTask]
    public let attempts: [WorkBoardAttempt]
    public let artifacts: [WorkBoardArtifact]
    public let reviewThreads: [WorkBoardReviewThread]
    public let columns: [WorkBoardColumn]
}

public struct WorkBoardProject: Sendable, Codable {
    public let id: WorkItemId
    public let keyPrefix: String
    public let name: String
    public let status: ProjectStatus
}

public struct WorkBoardTask: Sendable, Codable {
    public let id: WorkItemId
    public let key: String
    public let title: String
    public let statusId: String
    public let priority: WorkPriority
    public let latestAttemptId: AttemptId?
}

public struct WorkBoardAttempt: Sendable, Codable {
    public let id: AttemptId
    public let taskId: WorkItemId
    public let executorProfileId: String
    public let status: AttemptStatus
    public let worktree: WorktreeRef?
    public let startedAt: Date?
    public let completedAt: Date?
    public let receipts: [ReceiptRef]
    public let diffSummaryArtifactId: ArtifactId?
}

public struct WorkBoardArtifact: Sendable, Codable {
    public let id: ArtifactId
    public let attemptId: AttemptId
    public let kind: ArtifactKind
    public let uri: String
    public let sha256: String
}

public struct WorkBoardReviewThread: Sendable, Codable {
    public let attemptId: AttemptId
    public let comments: [WorkBoardReviewComment]
}

public struct WorkBoardReviewComment: Sendable, Codable {
    public let id: UUID
    public let attemptId: AttemptId
    public let authorId: String
    public let body: String
    public let filePath: String?
    public let line: Int?
    public let createdAt: Date
}

public struct WorkBoardColumn: Sendable, Codable {
    public let status: AttemptStatus
    public let attemptIds: [AttemptId]
}

public struct AttemptId: Hashable, Sendable, Codable { public let raw: UUID }
public struct ArtifactId: Hashable, Sendable, Codable { public let raw: UUID }

public struct WorktreeRef: Sendable, Codable {
    public let id: String
    public let baseRef: String
    public let baseCommit: String
    public let displayName: String
}

public enum AttemptStatus: String, Sendable, Codable {
    case pending = "pending"
    case running = "running"
    case inReview = "in_review"
    case merged = "merged"
    case failed = "failed"
    case cancelled = "cancelled"
    case quarantined = "quarantined"
}

public enum ArtifactKind: String, Sendable, Codable {
    case receipt = "receipt"
    case log = "log"
    case diff = "diff"
    case diffSummary = "diff_summary"
    case patch = "patch"
    case evidence = "evidence"
}
```

### Derived State Requirements
- `columns` MUST be derived from `AttemptStatus` and not directly set by renderers.
- `snapshotId` is authority minted and MUST match `WorkBoardIntent.header.irSnapshotId`.
- Worktree paths MUST NOT be exposed to renderers; only `WorktreeRef` is surfaced.

### Intent Surface (Mutations)
All mutations MUST be expressed as intents. Renderers do not mutate state directly.

```swift
public struct WorkBoardIntent: Sendable, Codable {
    public let header: ActionIntent.Header
    public let action: WorkBoardAction
    public let parameters: [String: BindingValue]
}

public enum WorkBoardAction: String, Sendable, Codable {
    case createTask = "create_task"
    case startAttempt = "start_attempt"
    case attachWorktree = "attach_worktree"
    case recordOutput = "record_output"
    case submitReviewComment = "submit_review_comment"
    case requestRerun = "request_rerun"
    case mergeAttempt = "merge_attempt"
    case cancelAttempt = "cancel_attempt"
}

public struct WorkBoardIntentResult: Sendable, Codable {
    public let receipt: ReceiptRef
    public let snapshotId: String
    public let status: Receipt.Status
    public let message: String?
}
```

Intent parameter schemas MUST include the relevant identifiers:
- `createTask`: `projectId`, `title`, `description`, `tags`
- `startAttempt`: `taskId`, `executorProfileId`, `baseRef`, `baseCommit`, `allowUnattendedExecution`
- `attachWorktree`: `attemptId`, `worktreeId`, `baseRef`, `baseCommit`
- `recordOutput`: `attemptId`, `artifactKind`, `uri`, `sha256`, `summary`
- `submitReviewComment`: `attemptId`, `body`, `filePath`, `line`
- `requestRerun`: `attemptId`, `reason`
- `mergeAttempt`: `attemptId`, `mergeStrategy`, `expectedHeadCommit`
- `cancelAttempt`: `attemptId`, `reason`

`mergeStrategy` MUST use `HarmoniaModule.MergeStrategy` raw values.

### Governance Integration
All intent handling MUST evaluate governance before mutation:
1. **SecurityEnforcer** - quarantine and scope checks
2. **PolicyRegistry** - action policy and trust tier validation
3. **Gatekeeper** - per task and per attempt write gates
4. **EventSink** - record allow/deny decisions

All successful intents MUST produce `Receipt` entries in Accessum and attach `ReceiptRef` to attempts.

### Workspace Capability Requirements
- Worktree operations MUST go through governed Git tooling (`GitEngine` or `GitToolRuntime`).
- Authority mints a workspace capability per attempt; renderers never receive filesystem paths.
- Unattended execution MUST be an explicit, policy gated capability.

### Concurrency Model
- WorkBoard services MUST be actor isolated.
- Intent processing MUST serialize per task to avoid conflicting transitions.
- Snapshots are immutable; updates always produce a new snapshot.
- All public types are Sendable.

### Error Handling
Implementations MUST return deterministic errors:
- `WorkBoardError.accessDenied(reason:)`
- `WorkBoardError.staleSnapshot(expected:actual:)`
- `WorkBoardError.invalidTransition(from:to:)`
- `WorkBoardError.attemptNotFound(id:)`
- `WorkBoardError.worktreeUnavailable(id:)`
- `WorkBoardError.governanceViolation(code:message:)`

## Stop Conditions
- Policy denial or trust tier mismatch
- Stale snapshot id or missing capability token
- Worktree creation/attachment failure
- Merge conflict or failed diff generation
- Quarantine or kill switch enabled

## Acceptance Tests
- Snapshot pinning rejects stale intents with deterministic errors.
- Columns are derived from attempt status and cannot be directly mutated.
- Worktree isolation: each attempt has a unique worktree id; paths are never exposed.
- Receipt creation on every successful intent; receipts are immutable.
- Unattended execution is blocked without explicit policy allow.

## Migration Plan (Ordered)
1. Contract artifact (this file).
2. Adapter over existing `PragmaModule` components to emit WorkBoardSnapshot.
3. Add `AttemptComponent`, `WorktreeComponent`, and `ArtifactComponent` in `PragmaModule/Components`.
4. Implement intent handling with governance + receipts; wire to Git tooling for worktrees.
5. Add review comment support by reusing `CommentComponent` with a Work Board comment type.
6. Expose MCP tools via a local-only WorkBoard MCP server (see `Docs/governance/contract-artifacts/SURFACE.WorkBoardMCPBridge.md`).
7. Add unit tests for intent validation and snapshot derivation; add a Harmonia surface scenario.

## Versioning and Compatibility
- Major: breaking changes to WorkBoard IR or intent parameters.
- Minor: new optional fields, intents, or artifacts.
- Patch: validation or performance improvements with no surface break.

---
**Contract Status**: DRAFT  
**Last Updated**: 2026-01-01  
**Authority**: Core Governance Layer  
**Implementation**: PragmaModule (Work Board capability)
