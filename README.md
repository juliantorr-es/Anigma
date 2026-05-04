# Anigma

**Anigma is a governance-first local orchestration platform for document processing, cognitive workflows, and evidence-backed automation.**

Anigma explores how autonomous systems can perform work while also leaving behind verifiable evidence: what changed, why it changed, which tools ran, and which architectural boundaries were crossed.

The project is experimental and under active architecture, governance, and runtime development.

---

## What Anigma Is

Anigma is a local-first runtime and architecture framework for governed automation.

It combines:
- **Governed execution** — workflows pass through explicit policy, authority, and readiness boundaries.
- **Evidence-backed operations** — important actions produce receipts, proofs, logs, or graph artifacts.
- **Doctrine-driven architecture** — system rules live in canonical documentation under `Docs/`.
- **Native executor isolation** — platform-specific capabilities are isolated behind contracts, executors, or sidecars.
- **Graph-based validation** — package structure and dependency boundaries are treated as reviewable architecture evidence.

---

## Project Status

Anigma is currently **experimental / research-stage**.

Active work includes:
- backend readiness normalization
- SwiftPM package graph diagnostics
- contract / executor / sidecar boundary enforcement
- deterministic test and build receipts
- local document and media processing pipelines
- heterogeneous / copy-minimized execution research

Known architectural debt is tracked in `Docs/` rather than hidden.

---

## Core Principles

### Governance First
Automation should not only execute. It should be governed.
Anigma routes capabilities through explicit contracts, authorities, readiness checks, and receipts.

### Evidence Over Assumption
Anigma favors evidence artifacts over informal claims.
Examples include SwiftPM graph snapshots, proof artifacts, deterministic JSON receipts, validation logs, and task records.

### Portable by Contract, Native by Executor
Portable contract surfaces should stay platform-neutral.
Native functionality belongs in implementation targets, governed executors, or sidecar products.

### Copy-Minimized by Default
Anigma avoids casual “zero-copy” claims.
The default claim is **copy-minimized**. A path is only called **zero-copy** when receipts or instrumentation prove no materialized copy occurred across the relevant boundary.

---

## Repository Structure

```text
Docs/
  architecture/        Doctrine index and architecture references
  governance/          Governance, build, testing, and architecture doctrine
  proofs/              Curated proof artifacts and validation records
  research/            Source-grounded architecture and tooling research
  schemas/             JSON schemas for receipts and proof artifacts
  td/                  Task documentation, reviews, handoffs, and registry
Scripts/
  anigma_package_graph_audit.py
                       SwiftPM graph audit and alignment diagnostics
  test_backend_readiness.sh
                       Backend readiness validation lane
  test_pdf_sidecar_readiness.sh
                       PDF sidecar readiness validation lane
anigma/
  Package.swift        Swift package manifest
  Packages/            Modular Swift targets and implementation packages
```

---

## Documentation

Start here:

* [Docs/architecture/DOCTRINE_INDEX.md](Docs/architecture/DOCTRINE_INDEX.md)
* [Docs/governance/BUILD_TOOLING_DOCTRINE.md](Docs/governance/BUILD_TOOLING_DOCTRINE.md)
* [Docs/governance/TESTING_DOCTRINE.md](Docs/governance/TESTING_DOCTRINE.md)
* [Docs/proofs/](Docs/proofs/)

The documentation is part of the system. It is not an afterthought.

---

## Development Workflow

Anigma development follows an evidence-first workflow:

**research → hypothesis → implementation → validation → proof → review**

Architecture-sensitive work is expected to include graph evidence, validation logs, proof artifacts, and follow-up task records.

---

## Requirements

Anigma is currently developed on macOS with SwiftPM.

Some capabilities may require local services or native dependencies, including PostgreSQL, Apple platform frameworks, or vendored sidecar libraries.

Because the project is experimental, setup requirements may change. Check `Docs/` and task records before assuming a lane is production-ready.

---

## License

Anigma is dual-licensed.

The public source code in this repository is licensed under the GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later).

Commercial, private, embedded, proprietary, or non-AGPL use is available only under a separate written commercial license from the copyright holder.

Unless a file states otherwise, all source files in this repository are covered by the AGPL-3.0-or-later public license.
