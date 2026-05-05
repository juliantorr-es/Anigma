# Validator Constitution

**Document ID:** VALIDATOR-CONSTITUTION-2026-001  
**Version:** 1.0  
**Status:** ACTIVE  
**Owner:** Architecture / Governance  
**Last Updated:** 2026-05-05

## Purpose

The Validator Constitution defines the authority model for Anigma repository scripts.
It establishes what a script is allowed to do, what it must not do, how it may use baselines, when it may gate review, and how its evidence should be interpreted.

Validators are not convenience scripts. They are governance instruments.

## Core Principle

Validators must make architectural risk visible, distinguish known debt from new regressions, and produce reviewable evidence.

A validator may tolerate known debt through an explicit baseline.
It must not silently normalize regressions, hide failures, or mutate governance state without declaring that authority up front.

## Authority Classes

### Class 0: Utility Script

Utility scripts support local developer workflow.

May:
- inspect files
- format output
- wrap other tools for convenience
- assist with local workflow

Must not:
- gate review
- mutate canonical governance state
- update baselines
- claim architectural truth

Mutation:
- may mutate only if the mutation is explicitly part of a non-governance local helper and is declared as such

Baseline access:
- read-only at most

Review gating:
- no

Phases:
- local
- ad hoc developer workflow

### Class 1: Advisory Analyzer

Advisory analyzers detect possible risk but do not gate the repository.

May:
- emit warnings and reports
- classify or suggest risk
- inspect source and derived artifacts

Must not:
- change repository state
- update baselines
- fail as a governance gate, except for script/runtime crashes or invalid invocation

Mutation:
- no

Baseline access:
- read-only, if any

Review gating:
- no

Phases:
- local advisory
- exploratory analysis

### Class 2: Gate Validator

Gate validators enforce architectural, safety, or governance invariants.

May:
- fail with a nonzero exit code when governed violations appear
- compare findings against explicit baselines
- emit deterministic review evidence

Must not:
- mutate canonical state
- silently update baselines
- hide new violations inside accepted debt

Mutation:
- no

Baseline access:
- read-only in gate mode

Review gating:
- yes

Phases:
- validate
- review

### Class 3: Baseline Manager

Baseline managers create, update, or compare known-debt baselines.

May:
- write baseline files
- retire explicitly reviewed findings
- record why a baseline changed

Must not:
- run implicitly during normal validation
- suppress regressions without proof
- rewrite baseline history without explanation

Mutation:
- yes, but only in explicit baseline mode

Baseline access:
- read/write only in explicit baseline maintenance workflows

Review gating:
- not by default

Phases:
- baseline maintenance

### Class 4: Renderer / Generator

Renderers convert canonical source artifacts into derived artifacts.

May:
- write generated outputs
- derive Markdown, JSON, CSV, diagrams, or manifests from source-of-truth inputs
- support check/diff modes for staleness detection

Must not:
- confuse derived output with canonical source
- mutate source artifacts implicitly
- rewrite unrelated files

Mutation:
- yes, only to declared generated outputs

Baseline access:
- usually read-only

Review gating:
- only if the generated artifact is itself part of a review gate

Phases:
- render
- generate
- check

### Class 5: State Synchronizer

State synchronizers bridge two representations of project state.

May:
- read from one canonical source
- write to a declared destination
- report created, updated, deleted, and skipped records

Must not:
- create dual-source-of-truth drift
- mutate without a declared source and destination
- hide conflict policy

Mutation:
- yes, in explicit sync mode

Baseline access:
- read-only unless the synchronizer explicitly manages baseline state

Review gating:
- usually no

Phases:
- sync
- reconcile

### Class 6: Mutator / Migration Script

Mutators intentionally change canonical repository content.

May:
- apply scoped mechanical changes
- perform migrations or repairs
- write files under explicit task scope

Must not:
- masquerade as validation
- run implicitly during passive diagnosis
- rewrite broad swaths of the repository without declared scope

Mutation:
- yes

Baseline access:
- only if the migration explicitly needs baseline comparison

Review gating:
- no, unless paired with a separate gate validator

Phases:
- migration

### Diagnostic Aggregator

Diagnostic aggregators orchestrate other scripts and collate evidence.

May:
- call validators and analyzers
- aggregate outputs into summaries and bundles
- preserve underlying failures

Must not:
- weaken or suppress validator failures
- mutate baselines
- mutate canonical docs during passive diagnosis
- become the sole source of truth for validator status

Mutation:
- no, unless a dedicated mode explicitly changes that authority and declares it

Baseline access:
- read-only

Review gating:
- indirectly, by orchestrating gate validators

Phases:
- baseline
- validate
- review
- diff
- index

## Mutation Rules

- `validate`, `check`, and `diagnose` modes must be non-mutating unless a mode explicitly says otherwise and declares its authority class.
- Baseline writes require explicit dangerous flags.
- Renderers must distinguish canonical source from derived output.
- Mutators must never be hidden inside passive diagnosis.
- Diagnostic aggregators may call validators, but they must not weaken failures.

## Baseline Discipline

- Baselines represent known debt, not suppression.
- Baseline updates require proof artifacts.
- Baseline writes must never occur during ordinary validation.
- New regressions must not be hidden inside baseline changes.
- Debt retirement and false-positive reclassification must be documented.

## Exit Code Semantics

- `0` = pass
- `1` = governed violation
- `2` = invocation/configuration error
- `3` = environment/tooling error
- `4` = schema/baseline incompatibility
- `5` = unsafe mutation refused

## Evidence Requirements

Gate validators must produce reviewable evidence.

At minimum:
- command executed
- script path
- scope
- total findings
- new findings
- baseline findings
- ignored or false-positive findings, if any
- exit code
- affected files where applicable

## `anigma_diagnose.py` Role

`Scripts/anigma_diagnose.py` is a diagnostic aggregator, not the sole source of truth.

It may orchestrate validators, but it must:
- preserve underlying failures
- report skipped validators and reasons
- avoid mutating baselines
- avoid mutating canonical docs during passive diagnosis
- document which phase each validator belongs to

## Recommended Phases

### Local Advisory Phase

Runs fast, broad, non-mutating checks.

Typical classes:
- Utility Script
- Advisory Analyzer

### Validate Phase

Runs deterministic gates required before review.

Typical classes:
- Gate Validator
- Renderer / Generator in `--check` mode

### Review Phase

Runs stricter governance checks and proof verification.

Typical classes:
- Gate Validator
- Renderer / Generator in `--check` mode
- State Synchronizer in dry-run mode only

### Baseline Maintenance Phase

Runs only when explicitly requested by a human or task brief.

Typical classes:
- Baseline Manager

### Migration Phase

Runs only under a scoped TD task.

Typical classes:
- Mutator / Migration Script

## Script Header Standard

Every governed script should include a header declaring:

- Authority Class
- Mutation Behavior
- Canonical Inputs
- Generated Outputs
- Baseline Behavior
- CI/Review Usage
- Failure Semantics
- Owner Doctrine

Example:

```text
Authority Class: Class 2 Gate Validator
Mutation Behavior: Non-mutating
Canonical Inputs: Swift package graph, Scripts/ validator allowlists
Generated Outputs: stdout/stderr report only
Baseline Behavior: Reads baseline; never writes baseline in gate mode
CI/Review Usage: validate and review phases
Failure Semantics: exit 1 on new violation, exit 2 on invalid invocation
Owner Doctrine: Dependency & Module Graph; System Architecture & Tiering
```

## Naming Rules

Preferred suffixes:
- `_validate.py`
- `_audit.py`
- `_render.py`
- `_sync.py`
- `_migrate.py`
- `_diagnose.py`

Dangerous modes must require explicit flags such as:
- `--write`
- `--apply`
- `--update-baseline`
- `--mutate`
- `--repair`

## Anti-Patterns

A validator must not:

- silently rewrite files
- silently update baselines
- hide new findings inside known-debt counts
- use nondeterministic report ordering
- pass because a dependency failed to run
- classify everything as advisory to avoid blocking
- classify everything as critical to create noise
- mix canonical and generated artifacts without labels
- require the full app build when a scoped target check is enough
- mutate TD state during passive diagnosis

## New Validator Acceptance Standard

A new validator is acceptable only if it answers these questions:

- What doctrine does it enforce?
- What failure mode does it catch?
- Is it advisory or gating?
- Can it distinguish known debt from new regressions?
- Does it produce reviewable evidence?
- Can it run deterministically on another machine?
- Does it mutate anything?
- Where does it belong in `anigma_diagnose.py`?
- What proof artifact validates its introduction?

## Relationship to Existing Doctrine

This constitution supports Anigma’s existing governance:

- tier isolation
- cycle prevention
- god-module prohibition
- zero-copy proof discipline
- executable consolidation safety
- TD evidence requirements
- documentation-as-code integrity

The constitution governs validators themselves so that repository governance does not become another source of ungoverned complexity.

## Final Rule

A validator that cannot explain its authority is not allowed to govern the repository.
