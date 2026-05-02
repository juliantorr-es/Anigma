# Backend Readiness Audit 2026-04-09

> Dated backend readiness snapshot for 2026-04-09.
>
> Source of truth for active execution state:
> - `td`
>
> Supporting live evidence:
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`
>
> This file is an audit and readiness matrix. It does not override `td` for what should be worked on next.

## Scope

This audit evaluates backend readiness across:

- lifecycle
- contracts
- retries and idempotency
- backpressure
- integration tests
- operability surfaces

The goal is to identify what exists, what is missing, and what still blocks the backend from being reliable after it becomes fully integrated.

## Summary

The backend is not missing these concepts entirely. In every category there is already at least one meaningful primitive in the codebase.

The actual problem is unevenness:

- lifecycle and contracts have useful building blocks but are not yet proven as one backend-wide execution contract
- retries and backpressure exist in selected subsystems but are not yet consistently applied across the main daemon path
- integration-test coverage is the weakest area
- operability surfaces exist, but they are split across HTTP routes, app UI, and partial health models instead of being one coherent operator surface

## Readiness Matrix

| Area | Current State | Evidence | Main Gap | Recommended Next Move |
|------|---------------|----------|----------|------------------------|
| Lifecycle | Partial | `DaemonServer` init and health handlers, queue shutdown, app-side connection recovery, daemon start/stop loops | Lifecycle behavior is not yet one canonical backend contract; shutdown and partial-start behavior are uneven across implementations | Define and test startup, shutdown, restart, and recovery semantics for the main daemon path |
| Contracts | Partial | Codable request/response and receipt types, daemon HTTP routing, Contextum XPC protocol, governance and contract models | There are many contracts, but not enough end-to-end verification that module seams agree semantically | Add contract verification for daemon requests, job payloads, event flow, and receipt surfaces |
| Retries / Idempotency | Weak to Partial | Queue worker retries, scheduler retries, replay engine, receipt chains, selected retry policies in modules | Retry exists, but idempotency and replay safety are not clearly enforced across side effects | Define retryable operations, idempotency expectations, and receipt-backed replay boundaries |
| Backpressure | Partial | Queue capacity limits, worker counts, resource thresholds, MCP throttle logic, daemon rate limiter | Limits are local rather than unified; queue pressure and overload behavior are not one backend-wide policy | Define backpressure policy across daemon, workers, MCP, and resource monitors |
| Integration Tests | Weak | Governance wiring tests, capsule contract tests, isolated module tests | Very little evidence of real daemon-to-module backend integration coverage | Create a small but real backend integration suite covering session, submit, status, receipt, and health flows |
| Operability Surfaces | Partial | `/health`, `/status`, app connection monitor, receipt inspector, job/activity views, HealthManager | Useful surfaces exist, but there is no compact operator/debugging contract for backend triage | Define supported backend operator surfaces for health, queue state, recent failures, and receipt/correlation inspection |

## Detailed Findings

### Lifecycle

What exists:

- daemon lifecycle handlers and HTTP routing in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/`
- queue startup and shutdown semantics in `Packages/CoreUtilities/Sources/QueueManager/QueueManager.swift`
- app-side daemon recovery logic in `Sources/AnigmaAppMac/ConnectionMonitor.swift`
- explicit health modeling in `Packages/AnigmaSystemSpine/HealthManager.swift`

Evidence:

- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+HTTPRouting.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Session.swift`
- `Packages/CoreUtilities/Sources/QueueManager/QueueManager.swift`
- `Sources/anigmad/main.swift`
- `Sources/AnigmaAppMac/ConnectionMonitor.swift`

Gap:

- multiple daemon or lifecycle implementations exist in parallel
- shutdown semantics are present in subsystems, but not yet clearly verified across the real integrated backend path
- partial initialization and restart behavior are not yet covered by a focused readiness test surface

Assessment:

- lifecycle primitives exist
- backend-wide lifecycle correctness is not yet proven

### Contracts

What exists:

- structured Codable request and response types
- governance and receipt models
- daemon HTTP routing surfaces
- Contextum XPC protocol models
- capsule and telemetry span models

Evidence:

- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+HTTPRouting.swift`
- `Sources/ContextumModule/XPC/ContextDaemonProtocol.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/AnigmaDaemonCore.swift`
- `Packages/GovernanceCore/GovernanceMechanisms.swift`
- `Packages/ExecutionCore/AIReceiptTypes.swift`
- `Packages/AnigmaSystemSpine/ConnectorProtocol.swift`

Gap:

- the repo has many contracts but no single place proving that the main daemon, shared runtime modules, and receipts all agree end to end
- semantic drift is still a real risk even when types compile

Assessment:

- contract modeling is stronger than test coverage
- the missing piece is end-to-end verification, not raw type definitions

### Retries And Idempotency

What exists:

- exponential retry logic in queue workers
- scheduler retry handling
- receipt chains and replay engine
- selected module-level retry policies

Evidence:

- `Packages/CoreUtilities/Sources/QueueManager/Worker.swift`
- `Packages/AnigmaCore/Sources/AnigmaCore/Jobs/Scheduler.swift`
- `Packages/ExecutionCore/ReplayEngine.swift`
- `Packages/AnigmaCore/Sources/AnigmaCore/Jobs/Job.swift`

Gap:

- retries exist, but idempotency expectations for side effects are not yet obviously encoded as one backend policy
- replay currently verifies chain structure more than full execution equivalence
- retry safety across job submission, event handling, exports, and persistence is not yet clearly audited

Assessment:

- retry mechanics exist
- idempotency and replay safety are still weaker than they need to be

### Backpressure

What exists:

- queue length limits and worker counts
- queue health snapshots
- daemon rate limiter
- MCP adaptive throttling and queue-load hints
- resource thresholds and worker-pool limits in daemon configuration

Evidence:

- `Packages/CoreUtilities/Sources/QueueManager/QueueManager.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift`
- `Sources/AnigmaMCPModule/MCPAdaptiveThrottle.swift`
- `Sources/AnigmaMCPModule/MCPRequestQueue.swift`

Gap:

- most limits are subsystem-local
- the backend does not yet read like it has one unified overload or degradation policy
- queue pressure, worker saturation, and resource exhaustion are not yet surfaced as one operator-facing story

Assessment:

- backpressure primitives exist
- integrated overload behavior is still underdefined

### Integration Tests

What exists:

- governance wiring tests
- module and capsule contract tests
- some Contextum unit tests

Evidence:

- `Tests/GovernanceCoreTests/GovernanceWiringTests.swift`
- `Tests/ContextumModuleTests/TextPreprocessingSystemTests.swift`
- capsule contract tests under `anigma/Anigma/Packages/*/Tests/`

Gap:

- little evidence of real daemon-to-module backend integration tests
- little evidence of tests that prove session opening, job submission, job status, receipts, and health checks work together

Assessment:

- this is the weakest category in the audit
- the backend needs a small real integration suite more than it needs more isolated unit tests

### Operability Surfaces

What exists:

- `/health` and `/status` daemon routes
- app-side daemon connection monitoring and recovery
- receipt inspection and job activity views in the app
- health snapshots for connector-oriented state

Evidence:

- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+HTTPRouting.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Session.swift`
- `Sources/AnigmaAppMac/ConnectionMonitor.swift`
- `App/MacApp/ReceiptInspector.swift`
- `App/MacApp/JobInspector.swift`
- `App/MacApp/Surfaces/ActivityView.swift`
- `Packages/AnigmaSystemSpine/HealthManager.swift`

Gap:

- useful surfaces exist, but they are scattered
- there is no clearly defined minimum operator surface for:
  - health
  - queue state
  - recent failed jobs
  - correlation or receipt lookup
  - debug guidance for active incidents

Assessment:

- operability is present in pieces
- it is not yet cohesive enough for intensive backend debugging

## What Is Most Likely Being Overlooked

The highest-risk overlooked area is not raw build failure anymore. It is semantic readiness:

- module contracts that compile but disagree in behavior
- retries without strong idempotency boundaries
- queue limits without a unified overload policy
- backend flows that have UI or route surfaces but no integrated test proof

If the backend reaches a point where the main binaries build, these are the areas most likely to cause the next class of failure.

## Recommended Work Order

1. keep the current backend unblock chain first
2. execute the backend logging migration
3. execute the observability contract work
4. harden lifecycle and contracts
5. define retry/idempotency and backpressure policy
6. add a small real backend integration suite
7. consolidate operability surfaces into a supported debug contract

## Relation To Current TD Work

This audit is intended to inform post-unblock backend hardening work. It should not supersede the current critical-path build blockers already tracked in `td`.
