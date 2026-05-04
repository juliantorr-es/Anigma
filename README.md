# Anigma

**Anigma is a governance-first local orchestration platform for document processing, cognitive workflows, and evidence-backed automation.**

It is designed around a simple premise: autonomous systems should not just perform work — they should leave behind verifiable evidence of what they did, why they did it, what changed, and which architectural boundaries were crossed.

Anigma is currently experimental. The repository is under active architecture, governance, and runtime development.

---

## What Anigma Is

Anigma is a local-first runtime and architecture framework for building governed automation systems.

It combines:
- **Governance-first execution** — workflows pass through explicit authority, policy, and readiness boundaries.
- **Evidence-backed operations** — important actions produce receipts, proofs, logs, or graph artifacts.
- **Doctrine-driven architecture** — system rules live in canonical documentation under `Docs/`.
- **Local-first processing** — orchestration is designed to run on local machines where data integrity and auditability matter.
- **Native executor isolation** — platform-specific or linker-heavy capabilities are isolated behind contracts, executors, or sidecars.
- **Graph-based validation** — package and dependency structure are treated as reviewable architecture evidence.

Anigma is not a generic SaaS backend, a chat wrapper, or a loose collection of scripts. It is an attempt to build a runtime where automation, evidence, architecture, and review gates are part of the same system.

---

## Project Status

Anigma is in **experimental / research** maturity.

Current focus areas include:
- backend readiness normalization
- SwiftPM package graph diagnostics
- contract / executor / sidecar boundary enforcement
- deterministic test and build receipts
- architecture proof artifacts
- local document and media processing pipelines
- heterogeneous / copy-minimized execution research

Some architectural debt is intentionally tracked in `Docs/` rather than hidden. Boundary violations, readiness gaps, and follow-up tasks are documented as part of the development process.

---

## Core Ideas

### Governance First
Anigma treats orchestration as something that must be governed, not merely executed.
Capabilities are expected to pass through explicit contracts, authorities, readiness checks, and receipts. This is especially important for agents, sidecars, native executors, and write-capable workflows.

### Evidence Over Vibes
The repository favors evidence artifacts over informal claims.
Examples include:
- SwiftPM package graph snapshots
- alignment diagnostic matrices
- build-status classifications
- proof artifacts under `Docs/proofs/`
- deterministic JSON receipts
- TD task records
- validation logs

A build is not simply “successful.” It is classified precisely:
- **FAILED** — nonzero exit code
- **CLEAN** — exit code `0` and zero warnings
- **CONTAMINATED** — exit code `0` with warnings
- **PASSED** — exit code `0`, warning status unknown

### Portable by Contract, Native by Executor
Portable contract surfaces should not expose platform-native details.
Native functionality belongs in implementation targets, governed executors, or sidecar products. This keeps generic runtime and readiness paths from accidentally depending on platform-specific libraries, linker settings, or optional native capabilities.

### Copy-Minimized by Default
Anigma avoids casual “zero-copy” claims.
The default architectural claim is **copy-minimized**. A path may only be called **zero-copy** when receipts or instrumentation prove that no materialized copy occurred across the relevant boundary.

---

## Repository Structure

```text
Docs/
  architecture/        Canonical doctrine index and architecture references
  governance/          Governance, build, testing, and architecture doctrine
  proofs/              Curated proof artifacts and validation records
  research/            Source-grounded architecture and tooling research
  schemas/             JSON schemas for receipts and proof artifacts
  td/                  Task documentation, reviews, handoffs, and task registry
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

## Architecture Documentation

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

For architecture-sensitive work, agents and contributors are expected to capture:
* pre-change graph evidence
* package graph diffs
* build/test logs
* warning/error classification
* proof artifacts
* follow-up TDs when work is blocked or out of scope

The goal is to make architectural drift visible before it becomes runtime failure.

---

## Current Validation Notes

Anigma uses a tiered architecture and tracks known boundary violations as architectural debt.

Some validation tools may report known pre-existing violations. These should be treated as tracked debt unless a task specifically claims to resolve them.

Backend and sidecar readiness are intentionally separate:
* generic backend readiness should not require optional native sidecars
* sidecar executables have their own readiness lanes
* missing native dependencies should be diagnosed in the sidecar lane, not hidden inside generic backend validation

---

## Requirements

Anigma is currently developed on macOS with SwiftPM.

Some capabilities may require local services or native dependencies, such as:
* PostgreSQL for database-backed flows
* vendored or discoverable native libraries for sidecar products
* Apple platform frameworks for native executor paths

Because the project is experimental, setup requirements may change. Check `Docs/` and task records before assuming a lane is production-ready.

---

## License

Anigma is dual-licensed.

The public source code in this repository is licensed under the GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later).

Commercial, private, embedded, proprietary, or non-AGPL use is available only under a separate written commercial license from the copyright holder.

Unless a file states otherwise, all source files in this repository are covered by the AGPL-3.0-or-later public license.
