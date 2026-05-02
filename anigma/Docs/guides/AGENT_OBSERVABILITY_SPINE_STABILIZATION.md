# Agent Observability Spine Stabilization

Status: roadmap-backed stabilization track.

Primary TD epic: `td-16ca40` Agent observability spine for ECS runtime.

Last reviewed: 2026-04-11.

## Purpose

Anigma should be able to answer investigation and detection questions about agent behavior without turning ordinary logs into a sensitive prompt and tool-output dump.

The target is not "more logs." The target is a canonical agent observability spine that joins:

- trace metadata for execution structure
- immutable evidence events for facts
- governed payload artifacts for sensitive or large prompt/context/tool I/O
- ECS projections for high-throughput query and detection
- security findings for response and review

The operating question is:

> If an MCP tool, retrieved document, prompt injection, model action, or policy failure causes an agent to do something unsafe, can Anigma reconstruct what happened and detect the same class of behavior again?

This spine is also the evidence substrate for the Agent Engine Hardening track (`td-e5142b`). Observability records what happened; engine hardening uses that evidence for replayable evals, authority/trust labels, executable policy gates, structured feedback loops, change-impact modeling, rollback receipts, data-quality gates, resource scheduling, and operator risk review.

## Current Gap

Anigma already has useful pieces:

- `TelemetryCore`
- `CapsuleDiagnostics`
- daemon correlation IDs
- CLI receipts
- security events
- Harmonia evidence chains
- Contextum telemetry components
- Observatorium source trees

The missing backend contract is a single causal spine that makes those pieces joinable across agent runs, tool calls, payload artifacts, receipts, and security findings.

The gap should be treated as a backend stabilization problem, not a product dashboard problem.

## Research Basis

### t3code Agent Runtime Reference

The `pingdotgg/t3code` repository is a useful reference for the operational shape Anigma should copy, not for its product scope or TypeScript stack.

Relevant patterns:

- server-authoritative orchestration: the backend owns agent/runtime truth and clients consume typed projections
- append-only orchestration events plus rebuildable projections
- strict separation between client-submittable commands and internal/system commands
- provider-neutral runtime adapters for Codex, Claude, and future agent runtimes
- ordered push streams with sequence-aware replay and recovery
- deterministic runtime receipts and drainable async workers for integration tests
- local NDJSON trace files as durable investigation artifacts, with OTLP/SIEM export remaining optional
- high-cardinality facts on spans/evidence records, not metric labels
- remote runtime modeling that separates execution environment, known environment, access endpoint, and launch method

Anigma-specific interpretation:

- the daemon/ECS backend should own agent execution truth
- immutable evidence events are the source of truth; ECS components are rebuildable projections
- Observatorium, MCP, CLI, and app surfaces should subscribe by sequence cursor and recover gaps through replay
- provider-specific behavior belongs behind an agent runtime adapter contract
- persistent investigation facts belong in trace/evidence records with payload references and hashes, not ordinary logs

Reference:

- https://github.com/pingdotgg/t3code/tree/934037cb66d6c4874e1a47c374569c110e71d669

### OpenTelemetry GenAI

OpenTelemetry GenAI semantic conventions define spans for model and tool activity and include tool call identifiers, tool names, tool arguments, and tool results. Tool arguments and results are marked opt-in because they can contain sensitive information.

Production pattern:

- record structural trace metadata by default
- store large or sensitive prompt/context/tool payloads externally
- record references and hashes on spans/events
- tune batching/export behavior for high-volume payload handling

Reference:

- https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/
- https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-events/

### W3C Trace Context

Trace context gives the propagation model Anigma should align with at subsystem boundaries: continue an incoming trace when one exists, otherwise create a new trace and parent operation.

Reference:

- https://www.w3.org/TR/trace-context/

### CloudEvents

CloudEvents provides a stable event envelope model with metadata separated from payload data. That maps cleanly to agent evidence events where routing, indexing, retention, and payload access should not require deserializing sensitive content.

Reference:

- https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md

### OpenTelemetry Performance Guidance

Instrumentation should not block the application by default and should not consume unbounded memory. Overload behavior must be explicit: preserve all information when configured for forensics, or drop/sample with warning and effective sampling metrics when configured for hot production paths.

Reference:

- https://opentelemetry.io/docs/specs/otel/performance/

### Data-Oriented Runtime Fit

ECS separates identity, component data, and systems. That is a good fit for agent observability because immutable events can remain the truth layer while systems project them into queryable run, span, tool, payload, and detection components.

Reference:

- https://docs.unity.cn/Packages/com.unity.entities%400.9/manual/ecs_core.html

For very hot event paths, a bounded ring/batch ingestion design should be evaluated before adding actor or database writes directly to agent hot paths.

Reference:

- https://lmax-exchange.github.io/disruptor/disruptor.html

## Architecture

### Plane 1: Trace Metadata

Trace metadata explains run structure. It is safe-by-default and should flow through daemon, workers, CLI, MCP, retrieval, model calls, guardrails, handoffs, checkpoints, and resume/replan boundaries.

Required identifiers:

- `trace_id`
- `span_id`
- `parent_span_id`
- `group_id`
- `run_id`
- `subgoal_id`
- `checkpoint_id`
- `tool_call_id`
- `agent_id`
- `workflow_id`

Required span classes:

- `agent.run`
- `model.generation`
- `tool.invocation`
- `handoff`
- `guardrail.evaluation`
- `retrieval.package`
- `memory.write`
- `checkpoint.compaction`
- `resume.replan`
- `artifact.write`
- `policy.decision`
- `detection.finding`

### Plane 2: Immutable Evidence Events

Agent evidence events are append-only facts. They should use a CloudEvents-style envelope while preserving Anigma-native governance and receipt fields.

Minimum envelope:

```text
event_id
event_type
source
subject
time
schema_version
trace_id
span_id
parent_span_id
group_id
run_id
subgoal_id
checkpoint_id
tool_call_id
entity_id
sequence
stream_id
stream_version
command_id
causation_event_id
correlation_id
actor_kind
payload_ref
payload_hash
previous_hash
receipt_id
security_class
retention_class
```

Minimum event types:

- `agent.run.started`
- `agent.run.completed`
- `model.generation.started`
- `model.generation.completed`
- `tool.invoked`
- `tool.completed`
- `guardrail.evaluated`
- `retrieval.package.built`
- `memory.write`
- `checkpoint.created`
- `resume.started`
- `replan.created`
- `policy.denied`
- `artifact.written`
- `detection.finding`

### Plane 3: Governed Payload Artifacts

Prompts, retrieved context, tool arguments, tool outputs, model outputs, diffs, command output, and document excerpts should not be placed directly in OSLog or high-volume telemetry by default.

Payload capture should go through a content-addressed artifact model:

```text
payload_id
content_hash
byte_count
mime_type
producer
trace_id
run_id
span_id
tool_call_id
redaction_class
retention_class
access_policy
sanitized_preview
artifact_uri
created_at
```

Capture modes:

- `off`: record no payload reference
- `hash_only`: record only hash and size
- `redacted`: store redacted payload and hash full payload if available
- `full`: store full payload under explicit access/retention policy

Default mode should be `hash_only` or `redacted` for production and `full` only for local forensic/debug configurations with explicit consent.

Payload artifacts are also a memory-residency boundary. Agent traces, tool outputs, retrieved context, command output, diffs, and model output should not become hot ECS fields or long-lived in-memory arrays by default. Hot trace/projection state should carry payload references, byte counts, hashes, redaction class, and sanitized previews; loading the full payload should require a governed access check and an explicit load ticket.

## ECS Projection Model

Immutable evidence events remain the source of truth. ECS components are rebuildable projections optimized for query, rollup, and detection.

Initial components:

- `AgentRunComponent`
- `TraceSpanComponent`
- `ToolCallComponent`
- `GuardrailDecisionComponent`
- `PayloadReferenceComponent`
- `DetectionFindingComponent`
- `TraceRollupComponent`

Initial systems:

- `AgentEvidenceIngestSystem`
- `TraceProjectionSystem`
- `ToolCallProjectionSystem`
- `PayloadReferenceProjectionSystem`
- `DetectionProjectionSystem`
- `TraceRollupSystem`

Projection systems must declare read/write component sets and support deterministic replay from the event log plus payload references.

Each projection should persist or expose its last applied event sequence. Subscribers must treat sequence gaps as a recovery condition: defer out-of-order events where possible, otherwise replay from the immutable event store or a trusted snapshot plus event tail.

### Runtime Adapter Boundary

Agent runtimes should be accessed through a provider-neutral adapter contract. The adapter owns translation between provider-specific sessions, tool events, approvals, transcripts, rollbacks, and Anigma's canonical commands/events.

Minimum adapter surface:

- provider identity and capabilities
- start session
- send turn
- interrupt turn
- respond to approval/request
- respond to user input
- stop session
- list/read sessions
- rollback thread or run state when supported
- stream canonical runtime events

Client-submittable commands should stay separate from internal orchestration commands. Clients can request a turn, approval response, cancellation, or trace query. Only the backend should emit internal commands such as persist evidence event, advance projection, mark checkpoint, record policy verdict, or publish detection finding.

### Local Trace Artifact

Anigma should keep a local NDJSON trace/evidence artifact as a first-class backend output for agent runs. This is not a replacement for OSLog, metrics, or optional OTLP export.

Policy:

- logs are human-facing operational output
- durable investigation facts are trace/evidence records
- completed spans and evidence events should include trace/span/parent IDs, timing, attributes, events, exit status, payload references, hashes, and redaction metadata
- high-cardinality values such as run IDs, command IDs, file paths, tool IDs, MCP server IDs, and payload references belong on spans/evidence records, not metric labels

## High-Throughput Ingestion

Agent hot paths should not synchronously block on database writes or large payload serialization.

Required ingestion properties:

- bounded queue or ring buffer
- batch persistence
- explicit overflow policy
- producer nonblocking by default
- preserve-all forensic mode
- effective sampling/drop counters
- warning event when loss starts
- recovery event when loss stops
- backpressure metrics exported to observability rollups

The first implementation can be actor-based if measured load is low. A specialized ring/batch path should only be added after benchmarking proves actor/database contention on agent event ingest.

Do not use unbounded queues for production hot paths. Test-only receipt buses may retain milestone events, but production ingestion must have bounded memory, explicit overflow behavior, and forensic preserve-all mode as a deliberate configuration.

## Deterministic Runtime Testing

The spine should include deterministic async test hooks. Tests should wait for named runtime receipts or drainable worker milestones instead of sleeping or polling.

Initial receipt milestones:

- run started
- turn started
- model generation completed
- tool invocation completed
- payload artifact written
- checkpoint written
- projection applied
- detection finding emitted
- run completed

Security-relevant receipts remain durable evidence. Test receipt buses can add retention/pubsub behavior for deterministic integration tests without changing production hot-path semantics.

## Detection Scope

The first detection systems should be narrow and actionable.

Initial detectors:

- malicious tool-output instruction detector
- unexpected file or network write detector
- policy-denial cluster detector
- tool loop or cost runaway detector
- audit/log tamper attempt detector
- sensitive payload egress indicator
- tool-result/action mismatch detector

Every detector must emit:

- `DetectionFindingComponent`
- `SecurityEventsManager` event
- trace/run/tool references
- evidence event references
- payload references when permitted
- severity and confidence
- recommended operator action

## Investigation Workflow

`trace_query` should become the operator and MCP investigation entrypoint.

Minimum supported questions:

- what did this agent see?
- what tool calls happened?
- what did each tool return?
- which payloads exist and who can inspect them?
- which guardrails or policy checks fired?
- which files, artifacts, receipts, or external calls changed?
- what detection findings were produced?
- can this run be replayed?

Access policy must be enforced at query time. A user without payload permission should still receive structural trace metadata and payload hashes/references.

## TD Breakdown

Epic:

- `td-16ca40`: Agent observability spine for ECS runtime

Child tasks:

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

Dependency stance:

- This track depends on backend truth and contract cleanup, especially manifest-stranded module reintegration, Observatorium canonical disposition, and typealias consolidation.
- This track should not preempt compilation-surface stabilization.
- It should shape Observatorium, TelemetryCore, SecurityEventsManager, MCP, CLI receipts, daemon jobs, and Harmonia evidence convergence once backend build boundaries are stable.
- `td-e5142b` depends on this track for canonical trace/evidence/payload data; avoid implementing hardening checks from bespoke logs or provider-specific transcripts.

## Acceptance Criteria

This stabilization track is complete when:

- one agent run can be reconstructed from trace, event, receipt, and artifact references
- parent/child spans exist for model, tool, guardrail, retrieval, checkpoint, handoff, and resume boundaries
- tool arguments and tool results are captured through governed artifact references or explicit hash-only policy
- MCP, CLI, daemon, and Harmonia tool paths emit the same canonical event family
- provider-specific runtime behavior is isolated behind an adapter contract
- event subscribers recover sequence gaps through replay rather than accepting partial live state
- local NDJSON trace/evidence artifacts exist for completed spans and evidence events
- async runtime tests wait on receipts or drainable workers rather than sleeps
- Observatorium consumes ECS projections rather than bespoke partial logs
- at least five first-pass detections produce linked security findings
- `trace_query` answers investigation questions without exposing unauthorized payload content
- overload behavior is measured and explicit
- replay tests can rebuild projections from immutable evidence events

## Non-Goals

- Do not build a SIEM clone.
- Do not put raw prompts, tool outputs, credentials, or document payloads into OSLog.
- Do not keep raw prompts, tool outputs, model outputs, retrieved context, or diffs resident in hot ECS projections by default.
- Do not optimize ECS storage globally before benchmarking.
- Do not treat Observatorium dashboards as proof of investigation readiness.
- Do not make payload capture mandatory for all users or all environments.
