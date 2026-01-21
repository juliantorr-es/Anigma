# SURFACE.WorkBoardMCPBridge

## Surface Definition
**Surface Name**: WorkBoardMCPBridge  
**Authority Boundary**: Core Governance Layer (WorkBoard intents + MCP transport)  
**Implementation Location**: Capability Module (PragmaModule/Capability/WorkBoardMCP)  
**Lease Required**: Yes - changes to this surface require a surface lease.

## Contract Requirements

### Purpose
Expose Work Board operations via MCP tools while preserving the same intent-based governance rules.
The MCP bridge MUST be local-only by default and MAY only be exposed remotely through explicit
policy and trust tier configuration.

### Tool Mapping
All MCP tools map 1:1 to `WorkBoardProviding` reads or `WorkBoardIntent` mutations.
Tool inputs and outputs are canonical JSON.

Read tools:
- `work_board.snapshot` -> input: `scope` output: `WorkBoardSnapshot`
- `work_board.get_diff_summary` -> input: `attemptId` output: `summary`, `artifactId`
- `work_board.get_receipts` -> input: `attemptId` output: `receipts`

Mutation tools (must return `WorkBoardIntentResult`):
- `work_board.create_task` -> input: `actorId`, `capabilityToken`, `irSnapshotId`, `projectId`, `title`, `description`, `tags`
- `work_board.start_attempt` -> input: `actorId`, `capabilityToken`, `irSnapshotId`, `taskId`, `executorProfileId`, `baseRef`, `baseCommit`, `allowUnattendedExecution`
- `work_board.attach_worktree` -> input: `actorId`, `capabilityToken`, `irSnapshotId`, `attemptId`, `worktreeId`, `baseRef`, `baseCommit`
- `work_board.record_output` -> input: `actorId`, `capabilityToken`, `irSnapshotId`, `attemptId`, `artifactKind`, `uri`, `sha256`, `summary`
- `work_board.submit_review_comment` -> input: `actorId`, `capabilityToken`, `irSnapshotId`, `attemptId`, `body`, `filePath`, `line`
- `work_board.request_rerun` -> input: `actorId`, `capabilityToken`, `irSnapshotId`, `attemptId`, `reason`
- `work_board.merge_attempt` -> input: `actorId`, `capabilityToken`, `irSnapshotId`, `attemptId`, `mergeStrategy`, `expectedHeadCommit`
- `work_board.cancel_attempt` -> input: `actorId`, `capabilityToken`, `irSnapshotId`, `attemptId`, `reason`

### Header Mapping
The MCP bridge MUST construct `ActionIntent.Header` using:
- `surfaceId`: stable id bound to the MCP session
- `actorId`: provided in tool input
- `capabilityToken`: provided in tool input
- `irSnapshotId`: provided in tool input
- `timestamp` and `nonce`: minted by the bridge

### Session Binding
Read tools MUST derive `trustTier`, `securityZone`, and `actorId` from the MCP session binding rather than tool inputs.
All session-bound tools MUST be non-destructive (read-only) and MUST NOT mutate Work Board state.
Mutation tools still require explicit `actorId` and `capabilityToken` inputs to construct `ActionIntent.Header`.

### Governance Integration
- All mutation tools MUST call `WorkBoardProviding.canSubmitIntent` before `submitIntent`.
- Policy gates and receipts MUST match the WorkBoard surface behavior.
- Remote MCP exposure requires explicit policy allow and must be recorded as evidence.

### Concurrency Model
- The MCP server MUST be actor isolated or use a serial event loop.
- Each MCP session binds to a single `SurfaceId` and capability context.
- Tool calls are processed deterministically with canonical JSON output.

### Error Handling
Implementations MUST return deterministic errors:
- `MCPBridgeError.accessDenied(reason:)`
- `MCPBridgeError.staleSnapshot(expected:actual:)`
- `MCPBridgeError.invalidRequest(code:message:)`
- `MCPBridgeError.governanceViolation(code:message:)`

## Stop Conditions
- Local-only constraint violated without policy allow
- Missing capability token or actor id
- Stale snapshot id or invalid intent parameters
- WorkBoard governance denial or quarantine

## Acceptance Tests
- All tool outputs are valid JSON and stable across identical requests.
- Mutation tools produce receipts and update snapshots deterministically.
- Snapshot pinning rejects stale `irSnapshotId` inputs.
- Remote binding fails without explicit policy allow.

## Migration Plan (Ordered)
1. Contract artifact (this file).
2. Implement MCP tool handlers wired to `WorkBoardProviding`.
3. Add local-only binding enforcement and policy gates for remote exposure.
4. Add tests for tool mapping, receipts, and snapshot pinning.
5. Add a Harmonia surface scenario to validate MCP bridge behavior.

---
**Contract Status**: DRAFT  
**Last Updated**: 2026-01-01  
**Authority**: Core Governance Layer  
**Implementation**: PragmaModule (Work Board MCP bridge)
