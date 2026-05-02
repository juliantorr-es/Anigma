# Backend Execution Hardening Framework

This guide defines how backend work must be executed so that completion means production readiness, not documentation completeness.

`td` remains the source of truth for status and dependency order. This framework defines the evidence required before core backend work is considered complete.

## Core Rule

No backend epic or production-facing backend task is done based only on:

- a design document
- a partial implementation
- a manual one-off check
- a narrative handoff

Backend work is complete only when it has reviewable evidence across implementation, verification, operations, and approval.

## Required Evidence Classes

### 1. Design Evidence

The task defines:

- canonical owner and boundaries
- failure modes
- dependencies and compatibility assumptions
- residual risks

Design evidence can live in the task description, linked guide, ADR, or audit.

### 2. Implementation Evidence

The task leaves behind a real backend artifact such as:

- code on the supported path
- a validator
- a migration
- a repair command
- an operator surface
- a compatibility fixture

Prototype-only scaffolding, stubs, and simulated paths do not satisfy this alone.

### 3. Verification Evidence

The task is exercised through one or more repeatable checks such as:

- automated tests
- integration tests
- replayable drills
- migration/rollback exercises
- failure-injection runs
- compatibility checks
- measured budgets against instrumentation

If the behavior matters in production, it must be validated on realistic backend state or realistic backend surfaces.

### 4. Operations Evidence

The task leaves behind an operable path for people other than the implementer. Examples:

- runbook
- recovery steps
- inspection command/API
- metric/log surface
- escalation rule
- cutover notes

If a task affects runtime behavior, persistence, or recovery, someone must be able to operate it without tribal knowledge.

### 5. Approval Evidence

The work is reviewed by a different session/person against the actual evidence above. Approval should check:

- what was implemented
- how it was validated
- how it is operated
- what risks remain

Implementation is not approval.

## Completion Template For Backend Epics

Every major backend epic should be driven through the same lifecycle:

1. Design
   - define contract, ownership, failure modes, and boundaries
2. Implementation
   - land the supported backend path
3. Verification
   - run tests, drills, or measured validation
4. Operations
   - produce operator-facing inspection/recovery/runbook material
5. Approval
   - review against evidence, not only task prose

If any stage is missing, the epic is not complete.

## Production Gate Rules

The following categories must not close as doc-only work:

- configuration
- secrets and credentials
- migrations and rollback
- backup and restore
- repair and reindex
- crash recovery
- backpressure and retry behavior
- API/event compatibility
- performance budgets and SLOs
- long-run state and compaction

Each of these must have both a policy and an exercised implementation path.

## Signal 4 Compilation Rule

Signal 4 / SIGILL / illegal-instruction failures during compilation are treated as a module surface-area failure until proven otherwise.

Default response:

1. Identify the module or target that triggers Signal 4.
2. Reduce that module's exposed compilation surface before adding more implementation.
3. Re-run the smallest affected build command.
4. Escalate to toolchain, dependency, or hardware investigation only after surface reduction does not change behavior.

Acceptable surface-reduction actions include:

- removing duplicate source roots from `Package.swift`
- excluding examples, archives, backups, generated files, or stranded source trees from the target
- splitting oversized Swift files that force pathological type-checking
- narrowing public APIs to minimal protocols or adapters
- moving implementation details behind `internal` or `private` boundaries
- replacing broad module imports with targeted dependencies where practical

The reason for this rule is pragmatic: in this codebase, Signal 4 has historically appeared around large or messy exposed Swift compilation surfaces. Agents should not treat it as a cue to add compatibility stubs or deepen the module unless TD explicitly says so.

## Minimum Backend Exit Evidence

Before the backend is treated as production-ready enough to shift primary focus to UI/UX, the backend program should have:

- clean rebuild evidence for the core blocked binaries
- real integration tests for critical backend flows
- migration and rollback drills on realistic state
- restore validation on realistic state
- crash/restart recovery validation
- config validation with fail-fast behavior
- secrets handling and redaction validation
- repair or reindex workflows that do not require raw DB surgery
- measured performance budgets tied to observability surfaces
- a deployment/cutover runbook usable by someone other than the implementer

## TD Policy Mapping

For major backend tasks, `td` acceptance criteria should require evidence in these buckets:

- implementation artifact
- verification artifact
- operations artifact
- approval by a different session

Examples:

- Config contract:
  - implementation: canonical loader/validator
  - verification: failure-path tests
  - operations: documented env/file-path matrix
- Migration drill:
  - implementation: real migration path
  - verification: forward + rollback + restore drill
  - operations: cutover and recovery steps
- Repair workflow:
  - implementation: supported repair path
  - verification: replay/rebuild exercised
  - operations: escalation rules and safe-use boundaries

## Anti-Patterns

Do not mark backend work complete when:

- the policy exists but the system does not enforce it
- the implementation exists but cannot be tested repeatably
- the behavior works only on empty/dev state
- the recovery path is "manual DB edit"
- only the implementer knows how to operate it
- "done" means "we have a doc now"

## Relationship To Other Backend Docs

- [Backend Consolidation Checklist](./BACKEND_CONSOLIDATION_CHECKLIST.md): defines the backend readiness gates
- [Enterprise Backend Foundation Standard](./ENTERPRISE_BACKEND_FOUNDATION_STANDARD.md): defines the non-negotiable production-quality standards for Anigma's backend foundation
- [Backend Observability Plan](./BACKEND_OBSERVABILITY_PLAN.md): defines logging, metrics, and debugging surfaces
- [Database Consolidation Plan](./DATABASE_CONSOLIDATION_PLAN.md): defines the persistence hardening path
- [Long-Run Agent Runtime Model](./LONG_RUN_AGENT_RUNTIME_MODEL.md): defines execution-state and compaction architecture

Use this framework to turn those design/checklist documents into evidence-backed execution work.
