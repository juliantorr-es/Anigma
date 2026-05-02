> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Architectural Gap: Multi-Agent and Sidecar Transport

**Gap ID:** multi-agent-sidecar-transport  
**Severity:** High  
**Scope:** Agent coordination, local IPC, transport choice

## Gap statement

The multi-agent docs identify blackboard-style coordination, but the transport layer still needs a concrete strategy for high-performance and audit-friendly message movement between agents and sidecars.

## Research evidence

### Industry / official
- **gRPC** is the standard RPC layer for distributed service APIs.
- **OpenTelemetry context propagation** and **W3C Trace Context** provide standard trace correlation across services.
- Existing repo research already recommends blackboard-first coordination and unified trace provenance.

### Academic / systems basis
- Blackboard architectures reduce duplicated reasoning and keep shared state visible.
- Bounded, pull-based coordination patterns avoid the “telephone game” failure mode of sequential agent hops.

## What industry does

Typical production architecture:

- gRPC for control-plane APIs
- shared-memory or zero-copy IPC for co-located hot paths
- blackboard or shared-state coordination for reasoning-heavy multi-agent work
- trace context and baggage for lineage

## Recommended solution

Create a **hybrid coordination stack**:

| Layer | Pattern | Purpose |
|---|---|---|
| Coordination | Blackboard | shared reasoning state |
| Control plane | gRPC | explicit APIs, observability |
| Hot data plane | zero-copy IPC / shared memory | local high-throughput payloads |
| Provenance | Trace Context + Baggage | lineage and audit |

Add a **turn-based checkpoint protocol**:

- agents publish reasoning state to the blackboard
- orchestrator assigns the next specialist
- checkpoints are compacted into long-term memory after completion

## Design constraints

- No agent should only know local history when shared truth exists.
- Transport must not duplicate large payloads unnecessarily.
- Every hop must preserve trace and principal context.

## Acceptance criteria

- Multi-agent sessions are reconstructable from the blackboard.
- High-volume data paths avoid unnecessary serialization.
- Agents can checkpoint and resume across turns.
- Sidecar traffic is observable without bloating the control plane.