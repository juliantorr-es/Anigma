# td-0dfb09 - Phase 4: Implement anigma-mcp warm pool with Unix domain sockets

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P0  
> **Lane**: daemon-runtime-isolation  
> **Epic**: [p0-004](../)  
> **Worktree**: `anigma/`

---

## Goal

See acceptance criteria

## Context

No description available.

## Scope

## Acceptance Criteria

- MCPWorkerPool for JSON-RPC communication
- UnixDomainSocketIPC for low-latency IPC
- Streaming MCP request handling in SubprocessManager
- MCPPoolMetrics for pool observability
- JSON-RPC request/response structures defined


## Non-Goals

## Non-Goals

- Actual MCP server implementation
- External MCP client integration


## Implementation Shape

## Source Files

- anigma/Packages/SubprocessPooling/Sources/MCPWorker.swift
- anigma/Packages/SubprocessPooling/Sources/IPC/UnixDomainSocketIPC.swift
- anigma/Packages/SubprocessPooling/Sources/SubprocessManager.swift
- Docs/proofs/p0-004-anigmad-subprocess-pooling.md


## Acceptance Criteria

## Criteria

- MCPWorkerPool for JSON-RPC communication
- UnixDomainSocketIPC for low-latency IPC
- Streaming MCP request handling in SubprocessManager
- MCPPoolMetrics for pool observability
- JSON-RPC request/response structures defined


## Validation Commands

## Validation Commands

*None*


## Proof Requirements

## Proof

*No proof artifacts*


---

*Task ID: td-0dfb09*  
*Created: 2026-01-01*
