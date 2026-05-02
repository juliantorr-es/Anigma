# Backend Observability Plan

> Dated implementation plan as of 2026-04-09.
>
> Source of truth for active execution state:
> - `td`
>
> This document defines the follow-on observability plan for backend debugging and performance optimization after the logging migration groundwork is in place.

## Goal

Make the integrated backend diagnosable and optimizable across daemon, workers, event flow, export, retrieval, and CLI bridges.

For agentic systems, observability has to answer more than ordinary service questions. It also has to explain:

- which agent or workflow was active
- which subgoal or branch was executing
- which tool calls, handoffs, or guardrails fired
- what memory or evidence packet was used
- how compaction or resume changed the active context
- whether the run failed because of data, policy, planning, or execution

The objective is to support answers to questions like:

- where did a request or job fail
- which subsystem added latency
- which fallback path triggered
- whether queueing, inference, storage, or export is the dominant bottleneck
- whether a regression is systemic, workload-specific, or data-specific

## Existing Foundation

The repository already has useful observability primitives:

- `TelemetryCore` sinks and client plumbing
- redacted telemetry events
- `CorrelationIDContext`
- span-based diagnostics via `CapsuleDiagnostics`
- some timing-oriented code in daemon and capsule paths

Examples:

- `Sources/TelemetryCore/TelemetrySink.swift`
- `Packages/TelemetryCore/Sources/TelemetryCore/CapsuleDiagnostics.swift`
- `Packages/CoreUtilities/Sources/CapsuleRegistry/CapsuleRegistry.swift`
- `Packages/CoreUtilities/Sources/Capsules/EventAggregatorCapsule/EventAggregatorCapsule.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/VerticalSlicePipeline.swift`

The plan should extend this foundation instead of creating a separate tracing system.

Recent external guidance reinforces this direction:

- OpenTelemetry emphasizes correlated signals across traces, metrics, and logs
- OpenTelemetry GenAI conventions define model/tool spans, opt-in tool arguments/results, and production patterns for storing sensitive prompt/context/tool payloads externally by reference
- W3C Trace Context defines the boundary behavior for continuing or creating traces across subsystems
- CloudEvents provides a portable event envelope for immutable evidence facts
- OpenTelemetry performance guidance requires instrumentation to avoid default blocking and unbounded memory
- the OpenAI Agents SDK tracing model treats runs as traces and captures generations, tool calls, guardrails, handoffs, and custom spans
- Microsoft's agent observability guidance extends OpenTelemetry with multi-agent semantic conventions and emphasizes unified tracing for quality, performance, safety, and cost
- `pingdotgg/t3code` provides a concrete agent-runtime reference for server-authoritative orchestration, append-only runtime events, rebuildable projections, provider adapters, ordered replay/recovery, local NDJSON traces, and deterministic runtime receipts

For Anigma, that means backend observability should evolve into agent observability rather than remaining service-observability-only.

## Observability Layers

### 1. Structured logs

Purpose:

- lifecycle transitions
- failures
- fallback paths
- state changes
- phase boundary markers

Prerequisite:

- backend logging migration onto `OSLog` and `Logger`

### 2. Metrics

Purpose:

- trend and bottleneck visibility
- throughput and latency tracking
- capacity and queue pressure tracking
- regression detection

Primary metric families:

- request and job counts
- success and failure counts
- queue depth
- queue wait duration
- execution duration by phase
- retry count
- fallback count
- cache hit and miss rate
- bytes processed
- memory pressure and resource throttling

### 3. Correlation and spans

Purpose:

- follow one request or job across subsystem boundaries
- attribute failures and latency to the right phase
- reconstruct critical path for slow or failed executions

Primary concepts:

- correlation ID propagated across daemon, workers, event bus, retrieval, export, and CLI bridge
- nested spans for major phases
- phase status and duration emitted consistently
- group/run identifiers that link multiple traces from the same conversation or long-running execution
- agentic spans for generations, tool calls, guardrails, handoffs, and compaction/resume boundaries

## Agentic Trace Contract

For agentic backends, the trace model should expose at least:

- `trace_id`: one end-to-end workflow or run attempt
- `group_id`: shared identifier linking related traces across one conversation, session, or long-running execution lineage
- `run_id`: canonical execution-state identifier when distinct from trace identity
- `subgoal_id` or equivalent branch identifier
- `checkpoint_id` for compaction or resume boundaries
- `tool_call_id` where relevant
- agent or workflow name
- parent/child span relationships

The main agentic span types should cover:

- agent or workflow run
- model generation
- tool invocation
- handoff
- guardrail or verifier pass
- retrieval package assembly
- memory write or promotion
- checkpoint/compaction
- resume/replan

This is the minimum needed to answer "what happened in this long run?" instead of only "which service was slow?"

## Agent Observability Spine

The follow-on stabilization track is `td-16ca40`: Agent observability spine for ECS runtime.

This track makes the agentic trace contract operational by separating observability into three planes:

1. **Trace metadata**: safe-by-default run structure and parent/child spans.
2. **Immutable evidence events**: append-only facts with trace/run/span IDs, sequence, payload reference, payload hash, previous hash, and receipt linkage.
3. **Governed payload artifacts**: content-addressed prompt/context/tool/model payload capture with hash-only, redacted, and full capture modes.

This separation is required because prompt contents, retrieved excerpts, tool inputs/outputs, command output, and model output are often both large and sensitive. Ordinary logs should not carry those payloads. Traces and evidence events should carry references and hashes so investigation can recover the content only through the right access and retention policy.

The ECS-facing projection layer should make immutable events queryable through rebuildable components:

- `AgentRunComponent`
- `TraceSpanComponent`
- `ToolCallComponent`
- `GuardrailDecisionComponent`
- `PayloadReferenceComponent`
- `DetectionFindingComponent`
- `TraceRollupComponent`

The full architecture is captured in `Docs/guides/AGENT_OBSERVABILITY_SPINE_STABILIZATION.md`.

The t3code study adds four implementation requirements that should stay in this track:

- **Provider adapter boundary**: provider-specific runtime behavior belongs behind a contract layer so the daemon, MCP, CLI, Harmonia, Observatorium, and ECS projections do not each learn provider-specific event semantics.
- **Sequence-aware replay**: every subscriber that consumes live agent events should track last applied sequence and recover missed windows from the event store or trusted snapshot plus event tail.
- **Local NDJSON trace artifact**: completed spans/evidence events should have a local durable artifact path; stdout/OSLog remains human-facing operational output, not the investigation database.
- **Deterministic receipts/tests**: integration tests should wait for runtime milestones such as tool completed, checkpoint written, projection applied, and finding emitted rather than sleeping or polling.

## Debugging Contract

Every backend request or job that crosses module boundaries should eventually expose:

- correlation ID
- job or request type
- start time
- terminal status
- total duration
- major phase durations
- failure reason or fallback reason when applicable

For long-running or queued work, also expose:

- enqueue time
- dequeue time
- queue wait duration
- worker identity if applicable
- retry count

For agentic flows, also expose when relevant:

- active agent or workflow name
- subgoal or branch identifier
- handoff target
- guardrail/verifier outcome
- memory package identifier or summary
- checkpoint/compaction boundary
- resume reason

## Priority Instrumentation Targets

### Phase 1: Correlation ID propagation

Standardize propagation of correlation IDs through:

- daemon request handling
- job submission and execution
- event publication and processing
- vertical slice pipeline
- export flow
- Contextum retrieval and indexing paths
- CLI to daemon bridge boundaries

Desired outcome:

- a single request or job can be followed across all major backend seams
- related traces from one conversation or long-run execution can be grouped coherently

### Phase 2: Phase timing and status markers

Instrument major boundaries with span start/end and stable timing fields.

Priority phase markers:

- daemon request accepted
- auth and session checks
- queue submit
- queue dequeue
- worker start and finish
- retrieval
- embedding
- ranking
- generation
- export render
- persistence and receipt emission
- guardrail evaluation
- tool call boundaries
- handoff start and finish
- compaction checkpoint
- resume and replan

Desired outcome:

- slow requests can be decomposed into a small number of meaningful durations

### Phase 3: Core metrics surface

Define and emit a minimum backend metrics contract.

Initial metrics:

- requests_total
- requests_failed_total
- jobs_submitted_total
- jobs_completed_total
- jobs_failed_total
- queue_depth
- queue_wait_ms
- job_duration_ms
- retrieval_duration_ms
- export_duration_ms
- fallback_total
- retry_total
- resource_throttle_total
- tool_calls_total
- guardrail_failures_total
- handoff_total
- resume_total
- compaction_total
- hot_ecs_resident_bytes
- payload_bytes_loaded
- payload_bytes_evicted
- active_payload_pins
- spill_total
- cache_hit_total
- cache_miss_total
- memory_budget_overrun_total

Desired outcome:

- backend regressions become measurable instead of anecdotal
- agentic regressions become attributable to planning, tooling, safety, or runtime continuity layers
- memory regressions become visible before hot ECS, retrieval packages, traces, projections, or model/session caches grow without bounds

### Phase 4: Debug and performance workflows

Create practical workflows for using the observability data.

Examples:

- trace one failing job by correlation ID
- identify p95 latency by phase
- find top fallback triggers
- identify queue pressure windows
- compare before and after optimization runs

Desired outcome:

- engineers and agents have a repeatable debugging workflow instead of ad hoc log scraping

## Logging And Telemetry Boundary

Use logs for:

- discrete events
- failures
- warnings
- fallback selection
- state transitions

Use telemetry or metrics for:

- counters
- durations
- queue depth
- throughput
- rate-oriented and aggregate measurements

Use spans for:

- request and job decomposition across phases
- tool, handoff, guardrail, compaction, and resume boundaries

Agentic systems add an extra rule:

- logs should explain local events
- traces should explain run structure
- metrics should explain fleet behavior

Do not try to make logs carry the whole agent execution story by themselves.

## Privacy And Content Recording Rules

Agent traces can easily over-capture sensitive data. The policy should therefore distinguish:

- structural trace metadata that is safe to propagate broadly
- content payloads that require explicit recording policy

Safe-by-default structural fields:

- trace ID
- group ID
- run ID
- subgoal ID
- tool name
- guardrail/verifier status
- checkpoint ID

Sensitive or conditional fields:

- prompt contents
- retrieved document excerpts
- tool inputs/outputs
- credential-bearing payloads
- user-authored private content

Observability should support content-recording gates so traces remain useful even when payload capture is disabled.

## Agentic Debugging Workflows

In addition to the earlier workflows, agentic systems need repeatable ways to:

- reconstruct one run across multiple grouped traces
- inspect a failed handoff or tool chain
- compare pre- and post-compaction state for one run
- explain why a guardrail or verifier stopped progress
- correlate user feedback or evaluation outcomes with the originating trace

This is especially important once long-run execution and personal-context retrieval become core product behavior.

Do not rely on plain logs alone for optimization work. Logs explain incidents; metrics and spans explain performance.

## Performance Optimization Readiness

Before serious optimization work begins, the backend should have:

- stable correlation ID propagation
- phase timing for major backend seams
- a minimum metric contract
- a small set of supported debug queries or commands

Without that, optimization work will mostly produce guesswork and local anecdotes.

## Rollout Order

1. Finish backend operational logging migration.
2. Standardize correlation propagation through daemon and job paths.
3. Add parent/child span identity and agent trace IDs.
4. Add phase timing for request, queue, worker, retrieval, export, tool, guardrail, checkpoint, and resume boundaries.
5. Define the immutable agent evidence event envelope.
6. Add governed payload artifact capture for prompt/context/tool/model I/O.
7. Define provider-neutral runtime adapter and command boundaries.
8. Add sequence-aware replay/recovery for live subscribers and projections.
9. Add local NDJSON trace/evidence artifact sink.
10. Add deterministic runtime receipts for async integration tests.
11. Define and emit minimum backend metrics.
12. Project trace/evidence events into ECS query components.
13. Add first-pass detection systems and security findings.
14. Add operator and agent workflows for reading and acting on the data.

## Suggested TD Breakdown

Epic:

- `td-16ca40`: Agent observability spine for ECS runtime

Existing and follow-on task shape:

- `td-e07fd5`: Define canonical AgentTrace and span identity contract
- `td-38fe0e`: Add CloudEvents-style immutable agent evidence envelope
- `td-73d421`: Capture prompt context and tool I/O through governed payload artifacts
- `td-01b326`: Build nonblocking high-throughput agent event ingestion
- `td-d8312d`: Project agent traces into ECS query components
- `td-a52622`: Implement first-pass agent security detection systems
- `td-76ac32`: Replace MCP trace_query placeholder with trace-event-artifact joins
- `td-d55939`: Wire MCP CLI daemon and Harmonia tool paths to canonical agent events
- `td-590e9d`: Define provider-neutral agent runtime adapter contract
- `td-e317bc`: Add sequence-aware agent event replay and subscriber recovery
- `td-84ea46`: Add local NDJSON agent trace artifact sink
- `td-8661e6`: Add deterministic agent runtime receipts and drainable async test harness
- task: backend phase timing instrumentation
- task: minimum backend metrics contract
- task: debugging and performance workflow guide
- task: trace-linked evaluation and feedback workflow

This work should follow the logging migration rather than compete with the current backend unblock chain.

## Research Basis

This plan is additionally informed by:

- OpenTelemetry signals and baggage guidance
- OpenAI Agents SDK tracing guidance
- Microsoft Agent / Azure AI Foundry observability guidance for agentic systems

References:

- OpenTelemetry signals overview: https://opentelemetry.io/docs/reference/specification/overview/
- OpenTelemetry baggage concepts: https://opentelemetry.io/docs/concepts/signals/baggage/
- OpenTelemetry GenAI spans: https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/
- OpenTelemetry GenAI events: https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-events/
- OpenTelemetry performance guidance: https://opentelemetry.io/docs/specs/otel/performance/
- W3C Trace Context: https://www.w3.org/TR/trace-context/
- CloudEvents specification: https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md
- OpenAI Agents SDK tracing: https://openai.github.io/openai-agents-python/tracing/
- OpenAI Agents SDK tracing reference: https://openai.github.io/openai-agents-python/ref/tracing/
- Azure AI Foundry agent tracing: https://learn.microsoft.com/en-us/azure/ai-foundry/agents/concepts/tracing
- t3code reference commit: https://github.com/pingdotgg/t3code/tree/934037cb66d6c4874e1a47c374569c110e71d669
- Microsoft Agent Framework observability: https://learn.microsoft.com/en-us/agent-framework/user-guide/agents/agent-observability
