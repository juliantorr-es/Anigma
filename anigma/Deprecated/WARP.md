# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## 1. Essential References for Agents

When operating in this repo, treat these documents as primary:

- `AGENTS.md` – Anigma Agent Contract: two-tier architecture, Harmonia-only governance surface, "search before create" requirements, governed toolchain, and emergency security procedures.
- `Docs/ImplementationRules.md` – Practical rules for ECS, jobs/workflows, concurrency, module boundaries, testing, stubs, docs, and CI enforcement invariants.
- `Docs/llm-context/README.md` – Index for LLM-specific guidance; read at least:
  - `00-two-tier-architecture-guide.md`
  - `01-core-governance-deep-dive.md`
  - `02-capability-modules-development.md`
  - `03-agent-workflows-procedures.md`
  - `04-security-governance-compliance.md`
- `Docs/governance/contract-artifacts/README.md` – Rules for SURFACE.* contract artifacts for any cross-module or public-surface change.
- `agent.md` – High-level description of the governed patch pipeline (inspect → generate → propose → validate → apply) and how custom tools/receipts fit together.
- `agent_tools.md` – Verbatim implementation of the `.opencode/tool` helpers (gates, patch pipeline, binary build tools, etc.).
- `README.md` – Product/architecture overview, module map, and user-facing quick-start commands.

Future Warp agents should align behavior with these documents and prefer using the governed toolchain over ad-hoc shell commands whenever possible.

## 2. Common Commands (Build, Test, Docs)

### 2.1 SwiftPM build & test (human baseline)

The repo is a SwiftPM package (see `Package.swift`). Human developers typically use:

```bash
swift build          # Build all products
swift test           # Run the full test suite
```

To run a subset of tests:

```bash
# Single test target
swift test --target AnigmaCoreTests

# Filter by XCTest case or method
swift test --target HarmoniaModuleTests --filter SessionListingTests
swift test --target HarmoniaModuleTests --filter SessionListingTests/testHybridListing
```

Agent-specific constraints from `AGENTS.md` and `Docs/llm-context/00-two-tier-architecture-guide.md`:

- Automated agents should avoid invoking `swift build`, `swift test`, `swift run`, or direct `.build/.../harmonia` binaries on their own.
- Prefer the governed tools described in `agent.md` / `agent_tools.md` (e.g., `swiftpm`, `gates`, `ci_all`) so builds/tests run under the project’s enforcement and receipt chain.
- If you must suggest raw SwiftPM commands, clearly mark them as **for human use** and keep agent automation on the governed path.

### 2.2 Governed test/build helpers in `Tools/`

These scripts wrap SwiftPM in project-specific governance:

- `Tools/run_governed_tests.sh`
  - Builds `GovernedMigrationCoreTests` as a compilation gate for the governed-core layer.
  - Use before changes to `GovernedMigrationCore` or its tests to ensure the core governance tests still compile.

- `Tools/install_harmonia.sh`
  - Builds the `harmonia` SwiftPM product in release mode and installs it to `.tools/bin/harmonia` using repo-local caches.
  - Intended for setting up a stable Harmonia CLI binary on the developer machine.

- `Tools/verify_harmonia_output.sh`
  - Builds the Harmonia CLI, checks that scripts do not invoke `harmonia` directly, and verifies the JSON envelope contract for commands like `trust bounds` and `security status`.
  - Useful when changing Harmonia CLI surfaces or JSON schemas.

Agents should reference these scripts instead of inventing new build/test shell pipelines.

### 2.3 Helper Scripts Suite (Phase 5+)

After Phase 5, use the helper scripts in `Scripts/helpers/` to interact with production infrastructure:

#### 2.3.1 Essential Helper Scripts

- **`Scripts/helpers/setup.sh`** – One-time environment initialization: makes helpers executable, updates PATH in shell profile, verifies binary installation.
- **`Scripts/helpers/build-verify.sh`** – Build completeness verification and auto-install of all 9 binaries to `~/.local/bin`. Test before complex operations.
- **`Scripts/helpers/daemon-manager.sh`** – Accessum daemon lifecycle (status/start/stop/restart/logs/check). Use before any long-running operation.
- **`Scripts/helpers/harmonia-session.sh`** – Harmonia session management (start/end/list/merge). Creates local receipt tracking; use session boundaries for sprint work.
- **`Scripts/helpers/accessum-quick-run.sh`** – Quick Accessum flow execution with artifact verification. Use for deterministic run and replay validation.
- **`Scripts/helpers/test-runner.sh`** – Test fixture executor (`diaplasion`, `outlineum`, `all`). Validates deterministic artifacts; use after code changes.
- **`Scripts/helpers/governed-patch.sh`** – Governed patch pipeline workflow helper (inspect → generate → propose → validate → apply). Use for making changes with full governance tracking and receipt chain.
- **`Scripts/helpers/gated-ci.sh`** – Governance gates and CI validation helper. Runs phase contracts, Swift 6 compliance, type authority, and dependency checks. Use to validate patches before committing.
- **`Scripts/helpers/harmonia-receipts.sh`** – Enhanced session management with local receipt tracking. Extends harmonia-session.sh with receipt ledger integration and governance tracking.
- **`Scripts/helpers/validate-system.sh`** – System validation and acceptance testing. Comprehensive check that all critical components work together. Validates Phase 5 acceptance criteria.

#### 2.3.2 Daily Sprint Workflow Pattern

For all sprints (Phase 5+), establish session boundaries with:
```bash
# 1. Verify environment
./Scripts/helpers/daemon-manager.sh check

# 2. Start a session for the sprint
./Scripts/helpers/harmonia-receipts.sh start <session-id>

# 3. Execute governed patch workflow for changes
./Scripts/helpers/governed-patch.sh inspect
./Scripts/helpers/governed-patch.sh full "Sources/Core/*" "Add new validation logic"

# 4. Validate using governance gates
./Scripts/helpers/gated-ci.sh gates

# 5. Execute flows/tests as needed
./Scripts/helpers/accessum-quick-run.sh
./Scripts/helpers/test-runner.sh all

# 6. Monitor if issues arise
./Scripts/helpers/daemon-manager.sh logs

# 7. Save session receipts at end
./Scripts/helpers/harmonia-receipts.sh audit <session-id>
./Scripts/helpers/harmonia-receipts.sh merge <session-id>
```

#### 2.3.3 System Validation

For complete system validation and acceptance testing:
```bash
# Full validation of all components
./Scripts/helpers/validate-system.sh full

# Check specific components
./Scripts/helpers/validate-system.sh binaries
./Scripts/helpers/validate-system.sh acceptance-criteria
./Scripts/helpers/validate-system.sh daemon
```

Use this helper to verify Phase 5 production readiness and that all acceptance criteria are met.

#### 2.3.4 Build Automation Integration

Before any major code changes or sprint start:
```bash
./Scripts/helpers/build-verify.sh --release
```
Detects missing binaries and installs to `~/.local/bin`. All helpers expect binaries from Phase 5 production installation.

### 2.6 Documentation site (VitePress)

Project documentation is maintained under `Docs/` as a VitePress site.

From the repo root:

```bash
cd Docs
npm install          # First time only or when dependencies change
npm run docs:dev     # Start VitePress dev server
npm run docs:build   # Build static docs
```

Key entrypoints:

- `Docs/index.md` and `Docs/Overview.md` – high-level project documentation.
- `Docs/architecture/` – detailed architecture, including module diagrams and system overviews.

### 2.5 Web assets

Optional JS/TS front-ends live under `web-assets/` (see `web-assets/README.md` for details). Each subproject (e.g., `web-assets/ergasterion-monaco`, `web-assets/anigma-dashboard`) is a standalone Node project with its own `package.json`.

Typical pattern for one of these projects:

```bash
cd web-assets/ergasterion-monaco
npm install
npm run build
```

Node is build-time only; no Node runtime is expected in production deployments.

## 4. High-Level Architecture

### 4.1 Two-tier architecture

Anigma is organized as a two-tier system:

1. **Core Governance Layer** – production-hardened, court-safe substrate.
2. **Capability Modules Layer** – domain-focused feature modules that depend on Core via explicit contracts.

The separation is enforced via documentation (`AGENTS.md`, `Docs/llm-context/*`, contract artifacts) and by scripts/tools that check boundaries.

### 4.2 Core Governance Layer (selected modules)

Core-oriented targets live under `Sources/` and are intended to be reusable, security-focused infrastructure:

- `AnigmaCore/`
  - ECS primitives (`World`, `EntityId`, `Component`, `System`, `Scheduler`).
  - Job/workflow model (`Job`, `JobStatus`, `Workflow`, `WorkflowRegistry`, `WorkflowRunner`).
  - Concurrency model: `World` and `Scheduler` are actors; components are `Sendable` and usually `Codable`.
- `DatabaseCore/`
  - Encapsulates SQLite access behind `DatabaseActor` for safe, concurrent DB use.
  - Core place to evolve database access patterns instead of ad-hoc SQLite usage.
- `ContractsCore/`
  - Shared definition point for cross-module contracts and surfaces, tied to contract artifacts in `Docs/governance/contract-artifacts/`.
- `GovernedMigrationCore/`
  - Governed migration engine and related tests (`Tests/GovernedMigrationCoreTests/`).
  - Guarded by `Tools/run_governed_tests.sh` as a compilation gate.
- `HarmoniaSpine/`, `HarmoniaCLI/`, `HarmoniaSurface/`
  - Core governance entrypoints and surfaces (CLI + surface testing harness).
  - All governance, trust, and security-state queries should flow through these rather than ad-hoc scripts.
- Other core-supporting modules such as `HarmoniaMemory/`, `SecurityEventsManager/`, `TelemetryCore/`, `ProvenanceSigning/`, `MLOutputCache/`, `MLWorkerCommon/`, and `MLWorkerExecutable/` support court-safe ML execution, telemetry, security event capture, and provenance.

Core code must not depend on Capability modules; Capability modules depend “downwards” on Core.

### 4.3 Capability Modules Layer (domain modules)

Capability modules live under `Sources/` with one module per domain.

- `HarmoniaModule/` – governed inference, policy enforcement, CI/CD gates, transparency/evidence bundles.
- `DiaplasionModule/` – alternative media workflows (OCR, EPUB/Braille/audio preparation).
- `AccessumModule/` and `AccessumFlow/` – Apertum Accesum-style intake/OCR/TTS/sync pipelines.
- `OutlineumModule/` and `OutlineumZine/` – outline/zine content generation and export workflows.
- `PragmaModule/` and `PraxisModule/` / `PraxisCore/` – work management, tasks, transitions, and execution logic.
- `ConexusModule/` – CRM/relationship management primitives (contacts, orgs, pipelines, activities).
- `CodexModule/` – documentation/knowledge spaces (spaces, pages, templates, comments, versions).
- `TranscriptumModule/` – academic records overlay (programs, courses, terms, enrollments, grades).
- `ObservatoriumModule/` – telemetry/metrics/alerts integration for dashboards and ops flows.
- `PolytroposModule/` – live-event video pipelines with native rendering and media workflows.
- `VectorumModule/`, `MLOutputCache/`, etc. – ML and retrieval-adjacent capability pieces.

Each module typically follows the pattern enforced by `Docs/ImplementationRules.md`:

- Components in `{Module}/Components/` (data),
- Systems in `{Module}/Systems/` (behavior over ECS world),
- Workflows/pipelines in `{Module}/Pipelines/`.

New domain work should extend existing modules where possible; creating new modules requires contract documentation and ADRs.

### 4.4 Tests

The `Tests/` tree mirrors the module structure:

- `Tests/AnigmaCoreTests/`, `Tests/DatabaseCoreTests/`, etc. – tests for core ECS, database, and governance primitives.
- `Tests/*Module*Tests/` – tests for each capability module (HarmoniaModule, DiaplasionModule, OutlineumModule, etc.).
- `Tests/GovernedMigrationCoreTests/` – governed-core tests compiled by `Tools/run_governed_tests.sh`.

When adding or modifying behavior in a module, add or update the corresponding `*Tests` target rather than creating ad-hoc test targets.

### 4.5 Governance, patch pipeline, and contracts

The repository is instrumented with a governed patch pipeline backed by receipts and JSONL ledgers under `.opencode/`:

- `agent.md` + `agent_tools.md` define tools such as:
  - `inspect_repo` – hash and record the files to be edited.
  - `generate_patch` – normalize a unified diff and store it under `.opencode/generated/` with a `patchHash`.
  - `propose_patch` / `validate_patch` – associate patches with phase IDs and acceptance criteria, then run gates and `git apply --check`.
  - `apply_patch` – apply only validated patches, enforcing base-file hashes and allow/deny path rules.
  - `gates` / `ci_all` / `swift6_check` / `type_authority_check` / `deps_check` – run governance and Swift 6 compliance gates.
  - `binary_build_preflight` / `build_binary` – preflight and produce release artifacts with SHA256 metadata.
  - `commit_changes` – integrator-only commit helper that ensures gates are green and forbidden paths untouched.

Cross-module or public-surface changes must also:

- Add or update a `SURFACE.<Name>.md` file under `Docs/governance/contract-artifacts/` describing boundaries, API, concurrency model, stop conditions, acceptance tests, and migration plan.

Warp agents should respect this flow conceptually: operate from a clean git state, work in terms of patches, and avoid mutating governance or contract files without corresponding artifacts and receipts.

---

This file intentionally focuses on the project-specific behaviors and architecture that are hard to infer from a single file. For deeper detail, consult the referenced documents and per-module README files under `Docs/` and `Sources/*/`.
