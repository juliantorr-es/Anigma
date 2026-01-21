# Implementation Rules

> Derived from `AnigmaConstitution.md` and ADRs. Last updated: 2025-12-06

Practical do/don't rules for working on the Anigma codebase.

---

## Agent Rules

- ✅ **Read `AGENTS.md`**: All AI agents must operate according to the Anigma Agent Contract defined in `AGENTS.md`.

---

## ECS Rules

### DO

- ✅ Import `AnigmaCore` for all ECS types
- ✅ Define domain components as structs conforming to `Component`
- ✅ Define domain systems as structs conforming to `System`
- ✅ Use `World.query()` for component iteration
- ✅ Use `World.addComponent()` / `getComponent()` / `removeComponent()` APIs
- ✅ Keep systems stateless; store state in components
- ✅ Make components `Codable` for persistence compatibility

### DON'T

- ❌ Define a second `World` or `Engine` type in modules
- ❌ Create module-specific `EntityId` or `Component` protocols
- ❌ Store mutable state in system structs
- ❌ Access component storage directly; use World APIs
- ❌ Couple systems to specific World implementations

---

## Job and Workflow Rules

### DO

- ✅ Use `AnigmaCore.Job` for all job tracking
- ✅ Use `AnigmaCore.JobStatus` enum for status
- ✅ Define workflows as structs conforming to `Workflow`
- ✅ Register workflows with `WorkflowRegistry` at module init
- ✅ Use `Scheduler` for job queue management
- ✅ Include meaningful `label` and `metadata` in jobs

### DON'T

- ❌ Define module-specific job status enums
- ❌ Create parallel scheduler implementations
- ❌ Hardcode job type strings; use `JobType` protocol
- ❌ Run systems directly without workflow context (except tests)

---

## Concurrency Rules

### DO

- ✅ Treat `World` as an actor; always `await` its methods
- ✅ Treat `Scheduler` as an actor
- ✅ Make components `Sendable`
- ✅ Use async/await for system updates
- ✅ Use `@MainActor` only for UI code, not core logic

### DON'T

- ❌ Use locks or manual synchronization in components
- ❌ Share mutable state between systems
- ❌ Block async contexts with synchronous waits
- ❌ Assume systems run on any particular thread

---

## Language and Dependency Rules

### DO

- ✅ Write all runtime code in Swift
- ✅ Use system frameworks (Foundation, CoreImage, etc.)
- ✅ Use permissively-licensed dependencies only
- ✅ Check license before adding any dependency

### DON'T

- ❌ Add Python files or Python dependencies
- ❌ Require Node.js at runtime
- ❌ Use AGPL/GPL-licensed libraries
- ❌ Shell out to external tools in production code (lab tools OK for reference)

---

## Module Boundary Rules

### DO

- ✅ Keep domain components in `{Module}/Components/`
- ✅ Keep domain systems in `{Module}/Systems/`
- ✅ Keep domain workflows in `{Module}/Pipelines/`
- ✅ Export module registration function (e.g., `OutlineumModule.register()`)
- ✅ Document which Python/lab code each Swift type replaces

### DON'T

- ❌ Put generic infrastructure in modules
- ❌ Reference other modules' internal types directly
- ❌ Create circular dependencies between modules
- ❌ Put UI code in modules (UI goes in app shells)

---

## Code Style Rules

### DO

- ✅ Use Swift naming conventions (camelCase, etc.)
- ✅ Add doc comments to public APIs
- ✅ Note the source of ported code (e.g., "Ported from: X.py")
- ✅ Keep files focused; one major type per file
- ✅ Write tests for components, systems, and workflows

### DON'T

- ❌ Over-comment obvious code
- ❌ Leave TODO comments without tracking
- ❌ Create god objects or massive files
- ❌ Skip tests for "simple" code

---

## Testing Rules

### DO

- ✅ Test components in isolation
- ✅ Test systems with mock World state
- ✅ Test workflows with fixture data
- ✅ Run `swift test` before committing

### DON'T

- ❌ Depend on external services in unit tests
- ❌ Skip tests because "it works"
- ❌ Test implementation details; test behavior

---

## Stub and Scaffolding Rules

### DO

- ✅ Add `#warning("STUB: ...")` for compile-time visibility of stubs
- ✅ Add `// STUB_TRACK: {Module} – {Description}. See Docs/TechDebt.md.` comments
- ✅ Add corresponding entries in `Docs/TechDebt.md` for every stub
- ✅ Link stubs to roadmap phases in TechDebt entries
- ✅ Use `fatalError("STUB: ...")` for code paths that must not silently succeed
- ✅ Run `./Scripts/list_stubs.sh` to audit stubs before releases

### DON'T

- ❌ Leave silent stubs without markers
- ❌ Add stubs without TechDebt.md entries
- ❌ Ship stubs to production without explicit feature flags
- ❌ Delete STUB_TRACK comments before implementing the stub

### Stub Lifecycle

1. **Add stub**: Create `#warning`, `STUB_TRACK` comment, and TechDebt entry
2. **Implement**: Replace stub with real code
3. **Clean up**: Remove `#warning` and `STUB_TRACK`, update TechDebt entry to "Resolved"

---

## Documentation Rules

### DO

- ✅ Update `Roadmap.md` when completing milestones
- ✅ Create ADRs for significant architecture decisions
- ✅ Reference ADRs in code comments where relevant
- ✅ Keep `AnigmaConstitution.md` up to date

### DON'T

- ❌ Create parallel roadmaps in other files
- ❌ Make architecture changes without ADRs
- ❌ Let docs drift from reality

---

## Atlas Maintenance Rules

### DO

- ✅ Update `Docs/Atlas/anigma-atlas.md` when adding modules, major subsystems, or doc categories
- ✅ Regenerate the atlas after changes: `./Scripts/build_atlas.sh`
- ✅ Include links to relevant docs in atlas nodes
- ✅ Keep node labels short and descriptive
- ✅ Test that the generated HTML opens correctly in Safari/browser

### DON'T

- ❌ Treat the atlas as a source of truth (docs remain authoritative)
- ❌ Forget to regenerate after updating the source
- ❌ Add nodes without corresponding documentation
- ❌ Commit broken/outdated `anigma-atlas.html`

### Build Command

```bash
./Scripts/build_atlas.sh          # Build atlas (installs deps if needed)
./Scripts/build_atlas.sh --install # Force reinstall deps
open Docs/Atlas/anigma-atlas.html  # View in browser
```

---

## Quick Reference

| If you need to... | Use this... |
|-------------------|-------------|
| Create an entity | `await world.createEntity()` |
| Add a component | `await world.addComponent(entity, component)` |
| Query entities | `await world.query(ComponentType.self)` |
| Define a component | `struct X: Component, Codable` |
| Define a system | `struct X: System { var name: String; func update(world:) async }` |
| Define a workflow | `struct X: Workflow { var name, jobTypeId, systemNames }` |
| Submit a job | `await scheduler.enqueue(job)` |
| Register a workflow | `await registry.register(workflow)` |

---

## Policy-Pack as Canonical Source

`policy-pack.toml` (`Docs/LLM/policy-pack.toml`) is the canonical machine source of truth for repository policy. All automated checks and policy enforcement in CI and Harmonia must derive their rules from this file. (feedback from review)

*   **Consistency Check Script**: A CI job should enforce consistency between `policy-pack.toml` and other policy descriptions (e.g., in `AGENTS.md`) and fail if they drift.
*   **Policy Versioning**: Tools consuming policy should declare the policy version they implement, and CI should reject incompatible combinations.

---

## Continuous Integration (CI) Enforcement (Future)

The CI system will act as a "bad cop" to mechanically enforce the project's modus operandi, ensuring invariants are proven automatically every time. CI must fail if it detects any of the following (feedback from review):

*   **Preflight Run**: `Scripts/agent_preflight.sh` does not run and pass as the very first step of CI.
*   **Policy-Pack Loading**: `policy-pack.toml` cannot be loaded or is invalid.

### Schema Validation

*   **ActionProposal Schema**: Any `ActionProposal` submitted to the repo does not validate against `Docs/LLM/ActionProposal.schema.json`. This includes valid and invalid fixture files failing validation as expected.
*   **CCTVEvent Schema**: Any `CCTVEvent` generated does not validate against `Docs/LLM/CCTVEvent.schema.json`. This includes valid and invalid fixture files failing validation as expected.

### Core Doctrine Violations

*   **Forbidden Runtimes**: New `.py` files appear in production targets. `Process.run("python", ...)` or `Process.run("node", ...)` patterns appear in production targets outside approved build-time tool folders.
*   **ECS Inconsistency**: A second `World` or `Component` protocol/materialization appears outside `AnigmaCore`.
*   **Dependency Policy**: A dependency is added with a license not on the allowlist or has known vulnerabilities (requires dependency review gate).
*   **Module Boundaries**: A new module directory is introduced without an ADR reference.

### Code Quality & Debt

*   **Stub Tracking**: Untracked `STUB_TRACK` entries exist. Stubs are introduced without corresponding tracking entries in `Docs/TechDebt.md`.

### Governance Process

*   **ActionProposal Compliance**: An agent attempts to write code without a valid `ActionProposal` in the expected location or format (even if this is a convention at first, CI must enforce it).
*   **Logging Compliance**: Agent-attributed commits lack required `CCTVEvent` log artifacts or these artifacts are invalid.
*   **Contract Digest Drift**: The calculated `agent_contract_digest` (from `policy-pack.toml` and `AGENTS.md`) does not match any embedded references.
