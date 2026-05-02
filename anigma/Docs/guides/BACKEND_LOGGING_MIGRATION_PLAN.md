# Backend Logging Migration Plan

> Dated implementation plan as of 2026-04-09.
>
> Source of truth for active execution state:
> - `td`
>
> This document is a migration guide and rollout plan. It does not override `td` for current sequencing or blockers.

## Goal

Consolidate backend operational diagnostics onto `OSLog` and `Logger` while preserving intentional user-facing stdout/stderr behavior.

This is not a blanket `print` removal project. The objective is to improve backend observability across the daemon, shared runtime modules, event flow, and reintegration stubs without breaking CLI UX.

## Why This Pays Off

For the backend, structured logging provides:

- subsystem and category filtering across multiple binaries
- severity levels suitable for daemon and module diagnostics
- better Console.app and unified logging visibility
- safer handling of sensitive fields through privacy annotations
- a path to correlate daemon, worker, event, and export failures during reintegration

The main long-term value is operational observability during backend consolidation, not style cleanup.

## Current Audit Snapshot

Observed on 2026-04-09:

- repo-wide Swift `print(...)` sites: about `4265`
- repo-wide Swift `Logger` or `OSLog` sites: about `403`
- backend-adjacent filtered `print(...)` sites excluding tests/tools/vendor/docs: about `3245`
- backend-adjacent filtered `Logger` or `OSLog` sites: about `381`

This repo already has a structured logging foundation in:

- `Packages/AnigmaCore/Sources/AnigmaCore/Utilities/Logging.swift`
- `Packages/AnigmaEvents/Sources/AnigmaEvents/EventLogger.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
- `Sources/anigmad/main.swift`

The migration should extend and standardize that foundation instead of introducing a second logging abstraction.

Recent agent-framework guidance also implies a stronger boundary:

- traces should carry run structure such as tool calls, handoffs, and guardrails
- logs should carry local operational explanation and failures
- metrics should carry fleet-level reliability, latency, and cost signals

For Anigma, structured logging should therefore be designed to complement agent traces, not compete with them.

## Policy Boundary

### Convert to structured logging

Use `Logger` or `OSLog` for:

- daemon lifecycle events
- backend worker execution
- module registration and startup checkpoints
- IPC, session, queue, and event-flow diagnostics
- reintegration stubs and placeholder execution warnings
- error reporting inside shared backend libraries
- local explanations of tool execution, guardrail outcome, checkpoint/resume events, and degraded runtime behavior

### Keep as stdout or stderr

Keep `print` or direct terminal rendering for:

- intentional CLI command output
- interactive TUI rendering
- machine-readable CLI stdout payloads
- demos, examples, and benchmarks unless promoted into production paths

### Mixed files

If a file mixes user-visible output with operational diagnostics:

- keep user-facing output on stdout or stderr
- move operational status, warnings, and debug traces to structured logging

## Subsystem And Category Rules

Use stable subsystem names aligned to executable or package ownership:

- `com.anigma.daemon`
- `com.anigma.core`
- `com.anigma.events`
- `com.anigma.mcp`
- `com.anigma.cli`
- `com.anigma.contextum`
- `com.anigma.harmonia`
- `com.anigma.runtime`

Category rules:

- prefer module or service names, not vague buckets like `misc`
- use one category per operational unit, for example `DaemonServer`, `job-processing`, `session`, `vault`, `runtime`, `event-qos`
- keep category names stable to preserve filtering value over time
- prefer categories that align with traceable agent units such as `tool-call`, `guardrail`, `handoff`, `retrieval-package`, `checkpoint`, `resume`

## Severity Rules

- `debug`: high-volume traces, startup checkpoints, retry details
- `info`: lifecycle transitions, successful state changes, registrations
- `warning`: degraded behavior, fallback path taken, stub invoked
- `error`: request, job, or component failure
- `fault`: invariant break or severe corruption risk

Agentic additions:

- log compaction/resume decisions at `info` or `debug` depending on volume
- log guardrail or verifier denials at `warning` unless they indicate corruption/invariant break
- log unexpected handoff failure or branch reconciliation failure at `error`

Do not log normal hot-path activity at `info` if it will flood unified logging.

## Privacy Rules

- default to privacy-safe logging for paths, payloads, prompts, tokens, and user content
- only mark fields as `.public` when they are operationally safe
- never log raw credentials, access tokens, API keys, or full sensitive payloads
- prefer structured metadata fields over concatenated debug dumps
- do not assume trace systems will capture sensitive content safely; logs should remain privacy-safe even when traces are disabled or payload-redacted

## Agentic Logging Contract

When backend code participates in agent execution, structured logs should carry stable identifiers that make local events joinable to traces:

- `trace_id` when available
- `group_id` when available
- `run_id`
- `subgoal_id` or branch identifier
- `tool_call_id` when relevant
- `checkpoint_id` for compaction/resume events

Logs should avoid duplicating full prompt or document payloads. The useful pattern is:

- one concise operational message
- stable identifiers
- safe categorical metadata

Examples of high-value agentic log events:

- tool selected and tool finished
- guardrail denied execution
- retrieval package built with stale/conflicted evidence
- branch folded into parent run
- resume from checkpoint succeeded or failed

## Priority Migration Buckets

### Phase 1: Backend operational prints

Highest value. Convert backend prints that currently act as daemon or runtime diagnostics.

Primary targets:

- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
- `Packages/AnigmaDaemonCore/Processing/DaemonServer+Processing.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Session.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Vault.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/JobQueueCompatibility.swift`
- `Packages/AnigmaDaemonCore/Jobs/AccessumWorker.swift`
- `Packages/AnigmaDaemonCore/Jobs/GovernanceWorker.swift`
- `Packages/AnigmaDaemonCore/Utils/DaemonInferenceAuthority.swift`
- `Packages/AnigmaDaemonCore/Utils/DaemonASTAuthority.swift`
- `Sources/ContextumModule/Systems/AgentStatsAggregateSystem.swift`
- `Sources/ContextumModule/Database/ContextumDatabase.swift`
- `Sources/ContextumModule/Database/ContextumDatabase+Incremental.swift`
- `Sources/ContextumModule/Workflows/ForensicsWorkflows.swift`
- `Packages/AnigmaEvents/Sources/AnigmaEvents/EventQoS.swift`

Expected outcome:

- daemon and shared backend modules stop writing operational diagnostics via bare stdout
- stub warnings become searchable and filterable in unified logs

### Phase 2: Shared logging standardization

Normalize how backend modules obtain and use loggers.

Tasks:

- document preferred logger construction pattern
- decide whether backend modules should use direct `OSLog.Logger` or AnigmaCore logging wrappers by default
- remove duplicate ad hoc logging helpers when a shared one already exists
- align subsystem and category naming

Expected outcome:

- new backend code stops inventing its own logging style
- logs become coherent across daemon, events, and runtime modules
- logs become coherent with the trace taxonomy used for agent runs

### Phase 3: CLI mixed-output cleanup

Separate user output from operational logging in CLI code that currently mixes both.

Primary targets:

- `Packages/HarmoniaCLI/DaemonCommand.swift`
- `Sources/AnigmaCLI/main.swift`
- `Sources/AnigmaCLI/CLI/CLIConfiguration.swift`
- `Packages/AnigmaCLI/Providers/CloudProviders.swift`

Policy:

- keep command results and interactive UX on stdout or stderr
- move debug, fallback, and backend-facing warnings to structured logging

Expected outcome:

- CLI remains usable and scriptable
- backend diagnostics stop leaking into user-facing output paths

### Phase 4: Deferred cleanup

Only after the backend frontier stabilizes:

- demos
- harnesses
- benchmarks
- example files
- archival or duplicate source trees

This phase is intentionally not part of the initial migration payoff.

## Rollout Strategy

1. Start with files on the daemon and shared-backend critical path.
2. Replace helper `print` checkpoints with named loggers and stable categories.
3. Convert stub warnings next, because they currently produce noisy but important diagnostics.
4. Separate mixed CLI files after backend paths are clean.
5. Leave demos, tests, benchmarks, and vendor code alone unless they enter production paths.

## Review Rules

For migration PRs or review passes:

- reject blanket mechanical rewrites that convert user-visible CLI output into logs
- reject new raw `print` in backend library code unless it is deliberate test or demo behavior
- verify privacy annotations on interpolated values
- verify severity choice matches operational importance
- verify logger subsystem and category match module ownership
- verify logs carry stable run/trace identifiers where the code participates in long-running agent execution
- reject logs that duplicate large prompt, retrieval, or tool payloads better handled by controlled trace content recording

## Suggested TD Breakdown

- task: phase 1 backend operational logging cleanup
- task: phase 2 logging standardization and conventions
- task: phase 3 CLI mixed-output separation

If build recovery remains the dominant blocker, keep implementation behind the active backend unblock chain, but keep the plan tracked now so new print debt does not continue to accumulate.
