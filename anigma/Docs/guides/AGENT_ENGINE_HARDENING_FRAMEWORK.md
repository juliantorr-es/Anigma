# Agent Engine Hardening Framework

Status: roadmap-backed stabilization track.

Primary TD epic: `td-e5142b` Agent engine hardening: evaluation trust policy and feedback loops.

Last reviewed: 2026-04-12.

## Purpose

Anigma's engine should not only make agents faster or more autonomous. It should make agent work measurable, source-grounded, policy-governed, reversible, and reviewable.

The key hardening question is:

> Can Anigma tell whether an agent action was useful, valid, trusted, reversible, and worth repeating?

The answer cannot come from model confidence alone. It requires a backend substrate that joins task state, trace evidence, payload references, policy decisions, build/test outcomes, review results, memory provenance, and operator decisions.

## Research Basis

This framework translates current AI, observability, supply-chain, policy, and data-quality practice into Anigma's ECS/data-oriented backend architecture.

### NIST AI Risk Management Framework

NIST AI RMF centers risk work around govern, map, measure, and manage. For Anigma this means agent capability should be governed by explicit policy, mapped to assets and trust boundaries, measured through evals and runtime evidence, and managed through mitigations, review, and rollback.

References:

- https://www.nist.gov/itl/ai-risk-management-framework
- https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-generative-artificial-intelligence

### OWASP LLM And Agent Security Risks

OWASP's LLM risk model is directly relevant to coding agents: prompt injection, sensitive information disclosure, supply-chain risk, excessive agency, insecure output handling, and unbounded action authority all map to Anigma's agent runtime.

Anigma-specific interpretation:

- never treat retrieved/source text as trusted instruction
- require capability and payload-access checks before mutating actions
- detect tool-output/action mismatches and excessive agency
- record evidence for investigation and feedback

Reference:

- https://owasp.org/www-project-top-10-for-large-language-model-applications/

### OpenTelemetry GenAI And Performance Guidance

OpenTelemetry GenAI conventions provide a useful vocabulary for model/tool spans, while OpenTelemetry performance guidance reinforces bounded memory, nonblocking instrumentation, batching, and explicit overload behavior.

Anigma-specific interpretation:

- structural trace metadata should be cheap and default-on
- prompt/context/tool payloads should move through governed payload references
- hot event ingestion must be bounded and backpressure-aware
- high-cardinality investigation facts belong in spans/evidence, not metric labels

References:

- https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/
- https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-events/
- https://opentelemetry.io/docs/specs/otel/performance/

### Provenance And Attestation

SLSA provenance and in-toto style attestations show the shape Anigma should use for agent mutation receipts: who/what produced an artifact, from which inputs, under which builder/tool/runtime, with which parameters.

Anigma-specific interpretation:

- code edits, memory writes, generated docs, eval runs, build artifacts, and policy changes need mutation receipts
- receipts should include preconditions, inputs, outputs, tool/runtime identity, policy verdict, and rollback availability
- generated/inferred artifacts must remain distinguishable from user-authored or build-derived truth

References:

- https://slsa.dev/spec/v1.2/provenance
- https://github.com/in-toto/attestation

### Policy As Code

Open Policy Agent demonstrates a useful separation between policy decision logic and application code. Anigma does not need to adopt OPA directly, but it should adopt the principle: high-risk agent decisions should be tested policy decisions, not scattered `if` statements or prose-only rules.

Reference:

- https://www.openpolicyagent.org/docs

### Evaluation Frameworks

OpenAI Evals and SWE-bench demonstrate the operational need for replayable evaluation sets. For Anigma, "agent got better" must be measured through repeatable coding-agent scenarios, not vibes or single successful demos.

Anigma-specific eval dimensions:

- build repair success
- review-finding resolution
- architecture-claim grounding
- regression rate
- unnecessary code churn
- tool-cost and runtime cost per useful change
- evidence coverage and abstention behavior

References:

- https://github.com/openai/evals
- https://www.swebench.com/

### Data Quality And Lineage

OpenLineage and Great Expectations point to an important lesson: memory, eval corpora, summaries, embeddings, and generated docs are data products. They need lineage and quality gates, or they become a source of agent confusion.

References:

- https://openlineage.io/docs/spec/object-model/
- https://docs.greatexpectations.io/docs/core/introduction/try_gx/

## Design Premise

The Agent Observability Spine (`td-16ca40`) records what happened. Tiered Truth Storage (`td-40d410`) keeps evidence and memory bounded. This hardening framework uses those substrates to decide:

- what evidence is authoritative
- which actions are allowed
- which changes are risky
- which outcomes teach the engine
- which mutations can be rolled back
- which evals prove improvement
- which operator decisions are needed

## Hardening Pillars

### 1. Evaluation As A Product Contract

Build passing is necessary but not sufficient. Anigma needs replayable coding-agent evals that can be run before and after engine changes.

Minimum eval suites:

- build repair
- review-finding resolution
- canonical type ownership
- architecture-claim grounding
- stale or conflicting documentation
- prompt-injected tool output
- task-state and review-state correctness
- long-run continuity across compaction/resume
- unnecessary code churn

Each eval run should record:

- task/eval id
- model/runtime/tool versions
- input artifacts and hashes
- retrieved context references
- generated actions and mutation receipts
- build/test/review outcome
- evidence coverage
- resource cost
- final score and reviewer verdict

### 2. Authority And Trust Labels

Agents fail when every text fragment looks equally trustworthy. Anigma should label each context artifact with source kind, authority, freshness, and lineage.

Initial authority order:

1. Direct user instruction in the current session.
2. `td` task state, blockers, dependencies, and review status.
3. Current code, package manifests, tests, and build output.
4. Architecture decisions and canonical docs.
5. Recent reviewed handoffs and review findings.
6. External research with citations and retrieval timestamp.
7. Generated summaries and agent memory.
8. Unreviewed inference.

Generated memory can help retrieval, but it must not silently outrank TD, code, build evidence, or canonical ADRs.

### 3. Executable Policy Gates

Policy should become an execution boundary. Any high-risk action proposal should pass through a policy evaluator before execution.

Initial policy gates:

- no agent approves its own implementation task
- no build-status doc claims "passing" without current build evidence
- no duplicate canonical wire-value owner
- no public foundation API change without TD/architecture approval
- no raw sensitive payload access without payload permission
- no memory promotion without source lineage and quality gates
- no high-risk file/network action without capability and scope
- no parallel write when the impact model finds overlapping write sets

Every policy decision should emit an evidence event and receipt.

### 4. Feedback Learning Loop

Rejected reviews, failed builds, policy denials, detector findings, and incident outcomes should become structured feedback.

Feedback records should link:

- TD issue
- agent run
- trace/span/tool ids
- policy decision
- build/test artifact
- review finding
- root cause label
- corrective rule or eval candidate

The goal is not automatic self-modification. The goal is to convert repeated failures into proposed policy rules, eval cases, retrieval warnings, or documentation updates.

### 5. Change Impact And Blast Radius

Before editing, Anigma should estimate impact.

The model should consider:

- package target graph
- public API ownership
- linked TD files and dependencies
- recent build failures
- module fan-in/fan-out
- review state
- write-set conflicts with parallel sessions
- required verification commands

Action proposals should carry expected affected targets, tests, policies, and rollback strategy.

### 6. Reversibility

Agent systems need rollback as a first-class protocol, not a last-minute git command.

Mutation receipts should record:

- precondition hash or state version
- touched files/entities/artifacts
- forward action
- inverse action or compensation path
- actor and policy verdict
- validation command
- rollback safety status

Non-reversible actions should be labeled before execution and generally require stronger approval.

### 7. Data Quality And Lineage

Memory, eval data, source chunks, embeddings, and generated docs should be validated before they become trusted inputs.

Initial quality gates:

- missing provenance
- stale source revision
- duplicate payload or embedding
- conflicting summary
- incomplete handoff
- malformed payload reference
- low OCR/layout/source fidelity
- generated doc without supporting evidence
- eval case without expected outcome

Failures should emit evidence and block promotion to trusted memory or trusted eval datasets.

### 8. Resource Cost Scheduling

Anigma should decide how much intelligence to spend.

Scheduling decisions should account for:

- task priority and risk
- required evidence depth
- local hardware pressure
- model/session memory budgets
- expected build/test cost
- current parallel workload
- whether a cheaper model/tool can do the job
- whether work is duplicate or stale

The scheduler should record expected cost, actual cost, quality outcome, and whether the decision should change next time.

### 9. Operator Control Surface

The human-facing layer should show evidence and risk, not just logs.

Minimum operator view:

- what changed
- why the agent thought it should change
- which evidence supports the action
- which policy checks passed or failed
- what build/test/review evidence exists
- what is risky or unverified
- whether rollback is available
- what payloads exist and who may inspect them
- what next task is recommended

The UI should read from trace/evidence/projection state, not bespoke log parsing.

## Sequencing

This track is not ahead of backend build stabilization.

Recommended order:

1. Finish compilation-surface and contract cleanup.
2. Land Agent Observability Spine contracts (`td-16ca40`).
3. Land Tiered Truth Storage memory residency (`td-40d410`).
4. Add replayable coding-agent evals and authority labels.
5. Add executable policy gates and mutation receipts.
6. Add feedback-loop learning records.
7. Add impact modeling and resource scheduling.
8. Surface evidence/risk in operator UI.

Some documentation and static policy work can begin earlier, but runtime enforcement depends on canonical trace/evidence/payload and memory-residency contracts.

## TD Breakdown

Epic:

- `td-e5142b`: Agent engine hardening: evaluation trust policy and feedback loops

Child tasks:

- `td-cfe558`: Build replayable coding-agent evaluation harness
- `td-ab16d6`: Define authority and trust labels for agent context
- `td-cd1576`: Implement executable policy gates for agent actions
- `td-41b071`: Add feedback loop from review build and incident outcomes
- `td-ee0c2f`: Model change impact and blast radius before agent edits
- `td-c88390`: Define rollback and reversibility protocol for agent mutations
- `td-33a4e9`: Add data quality and lineage gates for agent memory and eval data
- `td-edba51`: Add resource cost scheduler for agent workloads
- `td-433119`: Design operator review surface for agent evidence and risk

## Acceptance Criteria

This track is complete when:

- agent effectiveness can be measured with replayable evals
- every agent context artifact has authority, trust, freshness, and lineage metadata
- high-risk agent actions pass through executable policy gates
- policy decisions and mutation receipts are durable evidence
- rejected reviews, build failures, and incidents produce structured feedback records
- pre-edit impact estimates drive verification selection and parallel write-set safety
- rollback/compensation exists for supported mutation classes
- memory/eval/summary data is blocked from trusted promotion when quality gates fail
- resource scheduling records expected cost, actual cost, and outcome quality
- operator surfaces show evidence, risk, permissions, rollback status, and recommended next action

## Non-Goals

- Do not build a generic MLOps platform before Anigma's own agent loops are measured.
- Do not auto-train or auto-edit policies from raw feedback without review.
- Do not treat model confidence as a substitute for evidence coverage.
- Do not let generated memory outrank TD, code, build evidence, or ADRs.
- Do not require full UI work before backend evidence and policy contracts exist.
