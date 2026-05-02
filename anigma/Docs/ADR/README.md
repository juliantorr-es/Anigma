# ADR Index

> **Status:** Live index
> **Date:** 2026-04-20
> **TD:** `td-0393a8`

This index is the navigation layer for Anigma ADRs. Individual ADR files remain the source for each decision, but this index states which doctrine is live, proposed, superseded, duplicate, or pending cleanup.

## Live Architecture Thesis

Anigma is a governed, local-first, hardware-saturating runtime with strict semantic boundaries between policy, execution, storage, and product-facing capabilities.

Current doctrine:

- policy decides and constrains
- execution runs bounded work and emits receipts
- relational storage coordinates queryable truth
- sealed artifacts preserve immutable binary truth
- memory-mapped atlases provide hot execution layout
- runtime projections serve UI, GPU, and session views

See [Live Architecture Map](../architecture/live-architecture-map.md) for the current stack.

## Status Rules

- **Accepted**: live doctrine.
- **Proposed**: active design, not yet binding.
- **Superseded**: historical context only. Do not use as current authority.
- **Pending Review**: useful but not yet compatible with the current saturated/runtime doctrine.
- **Duplicate Cleanup**: keep readable for now, but consolidate into one canonical ADR.

No new ADR may reuse an existing number. If a duplicate exists, the index must identify the canonical file and the file to retire.

## Canonical ADRs

| ADR | Status | Role | Notes |
| --- | --- | --- | --- |
| [0001 Single ECS in AnigmaCore](0001-single-ecs-in-anigmacore.md) | Accepted | ECS foundation | Canonical ECS doctrine. |
| [0002 Job and Workflow Model](0002-job-and-workflow-model.md) | Superseded | Legacy work model | Historical only; superseded by saturated mission/runtime execution doctrine. |
| [0003 No Python or Node at Runtime](0003-no-python-or-node-at-runtime.md) | Accepted | Runtime dependency policy | Canonical deployment/auditability rule. |
| [0004 Module Boundaries](0004-module-boundaries.md) | Accepted | Module spine | Canonical boundary discipline. |
| [0005 Diaplasion Rename](0005-diaplasion-rename.md) | Accepted | Naming | Low-risk historical naming decision. |
| [0006 Atlasum Visual Atlas Engine](0006-atlasum-visual-atlas-engine.md) | Accepted | Documentation visualization | Duplicate number. Keep as product/doc visualization ADR until renumbered or archived. |
| [0006 Three-Tier Runtime Architecture](0006-three-tier-runtime-architecture.md) | Proposed, Pending Review | Runtime authority model | Duplicate number. Treat as proposed until canonized under a new number. |
| [0007 Modular Build System with Feature Flags](0007-modular-build-system-with-feature-flags.md) | Proposed | Build composition | Use only after current runtime/module boundaries are stable. |
| [0008 Import/Export Plugin System](0008-import-export-plugin-system.md) | Proposed | Plugin boundary | Needs strict contract review before acceptance. |
| [0009 TelemetryCore Unification](0009-telemetrycore-unification.md) | Accepted | Telemetry and privacy surface | Canonical telemetry consolidation direction. |
| [0011 Evidence Protocol Unification](0011-evidence-protocol-unification.md) | Accepted | Evidence receipts | Canonical evidence cleanup direction. |
| [0013 UI Projection System](0013-ui-projection-system.md) | Proposed | Product projection boundary | Strong live candidate; prevents UI from contaminating ECS/runtime truth. |
| [0014 Tiered Truth Storage Substrate](0014-tiered-truth-storage.md) | Proposed | Storage substrate | Must remain budgeted and bounded; not license for endless background refinement. |
| [0015 PostgreSQL Unified Stack](0015-postgresql-unified-stack.md) | Proposed | Relational truth and coordination | Scope-limited: Postgres coordinates atlases/artifacts, does not own hot binary lanes. |
| [0017 Single Master PostgreSQL System](0017-single-master-postgresql-system.md) | Proposed | Relational truth and coordination | Canonical single-backend target; bounded schemas/namespaces on top. |
| [0018 PostgreSQL Connection and Transaction Contract](0018-postgresql-connection-and-transaction-contract.md) | Proposed | Runtime database contract | Shared connection, transaction, savepoint, and retry semantics. |
| [0019 PostgreSQL Schema Bootstrap and Migration Contract](0019-postgresql-schema-bootstrap-and-migration-contract.md) | Proposed | Runtime migration contract | Shared bootstrap, migration, validation, and rollback model. |
| [0020 PostgreSQL Embeddings and Vector Strategy](0020-postgresql-embeddings-vector-strategy.md) | Proposed | Embeddings and retrieval | Canonical vector/search strategy for database-backed embeddings. |
| [0021 PostgreSQL Boundary and Instantiation Rule](0021-postgresql-boundary-and-instantiation-rule.md) | Proposed | Module boundary discipline | Composition-root-only instantiation rule for the low-level actor. |
| [0016 PDF Page Atlas Execution Substrate](0016-pdf-page-atlas.md) | Proposed | PDF execution substrate | Strong live candidate for mmap/SoA page rendering architecture. |
| [ADR-0010 ExecutionCore Rails](ADR-0010-ExecutionCore-Rails-Without-Policy.md) | Superseded | Historical execution rails | Historical only; superseded by pre-signed saturated mission model. |
| [ADR-0012 Segment IR Multimodal](ADR-0012-SEGMENT-IR-MULTIMODAL.md) | Accepted | Segment substrate | Canonical content identity and multimodal segment direction. |
| [ADR-0042 Model Contract System](ADR-0042-Model-Contract-System.md) | Accepted | Model/task boundary | Canonical model contract ADR. |
| [ADR Model Contract System](ADR-MODEL-CONTRACT-SYSTEM.md) | Duplicate Cleanup | Model/task boundary | Merge or retire in favor of ADR-0042. |

## Cleanup Backlog

1. Resolve duplicate `0006` numbering.
2. Move superseded ADRs to an archive folder or keep them indexed as historical only.
3. Merge or retire `ADR-MODEL-CONTRACT-SYSTEM.md` in favor of `ADR-0042-Model-Contract-System.md`.
4. Convert "saturated review pending" warnings into explicit Accepted, Proposed, Superseded, or Historical states.
5. Add ownership, non-ownership, budget, failure, and verification sections to ambitious substrate ADRs before acceptance.
