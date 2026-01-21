# Anigma: Technical Debt and Implementation Rules

Anigma maintains rigorous standards for code quality, architectural consistency, and the transparent management of technical debt. This ensures the project's long-term maintainability, security, and adherence to its core principles.

## Technical Debt Tracking

All stubs, scaffolding, and known technical debt are actively tracked in `Docs/TechDebt.md`. (see Docs/TechDebt.md)

*   **Process**:
    1.  **Adding stubs**: Add `#warning("STUB: ...")` and `// STUB_TRACK: {Module} – {Description}. See Docs/TechDebt.md.` comments in code. Create a corresponding entry in `Docs/TechDebt.md`.
    2.  **Resolving stubs**: Remove code comments, update the entry in `Docs/TechDebt.md` to "Resolved" with commit/PR details.
    3.  **Auditing**: Use `rg "STUB_TRACK"` to find stubs in code. Scripts (`./Scripts/list_stubs.sh`, `./Scripts/verify_stub_tracking.sh`) audit tracking.
*   **Examples**: `DiaplasionModule` has tracked items like `TransformRequestComponent` (type defined, priority queue not implemented) and `BrailleExportSystem` (stub). `HarmoniaModule` and `AccessumModule` are largely skeletons or commented examples. `AnigmaCore` tracks `Workflow Conditional Branching` (not supported) and `Scheduler Persistence` (in-memory only).
*   **Interplay with Governance**: Blocked work from governance layers often results in debt tasks (e.g., ResearchDebtTask for inadequate research, Doctrine Debt for violations). (see Docs/workflow-anigma-first.md)

## Implementation Rules (Key Guidelines for Code)

These practical do/don't rules are derived from `AnigmaConstitution.md` and ADRs. (see Docs/ImplementationRules.md)

### ECS Hygiene

*   **DO**: Import `AnigmaCore` for all ECS types. Define domain components as structs conforming to `Component`, systems as structs conforming to `System`. Use `World.query()` and `World.addComponent()`/`getComponent()`/`removeComponent()` APIs. Keep systems stateless, store state in components. Make components `Codable` and `Sendable`. (see Docs/ImplementationRules.md)
*   **DON'T**: Define a second `World` or `Engine` type in modules. Create module-specific `EntityId` or `Component` protocols. Store mutable state in system structs. Access component storage directly.

### Concurrency

*   **DO**: Treat `World` and `Scheduler` as actors; always `await` their methods. Make components `Sendable`. Use async/await for system updates. (see Docs/ImplementationRules.md)
*   **DON'T**: Use locks or manual synchronization in components. Share mutable state between systems. Block async contexts with synchronous waits. Assume systems run on any particular thread.

### Dependencies and Language

*   **DO**: Write all runtime code in Swift. Use system frameworks. Use permissively-licensed dependencies only. Check license before adding any. (see Docs/ImplementationRules.md)
*   **DON'T**: Add Python files or dependencies. Require Node.js at runtime. Use AGPL/GPL-licensed libraries. Shell out to external tools in production code.

### Module Boundaries

*   **DO**: Keep domain components in `{Module}/Components/`, systems in `{Module}/Systems/`, workflows in `{Module}/Pipelines/`. Export module registration function. (see Docs/ImplementationRules.md)
*   **DON'T**: Put generic infrastructure in modules. Reference other modules' internal types directly. Create circular dependencies. Put UI code in modules.

### Code Style and Testing

*   **DO**: Use Swift naming conventions, add doc comments to public APIs. Note the source of ported code. One major type per file. Write tests for components, systems, and workflows. (see Docs/ImplementationRules.md)
*   **DON'T**: Over-comment obvious code. Leave TODO comments without tracking. Create god objects. Skip tests for "simple" code.
*   **Testing**: Test components in isolation, systems with mock World state, workflows with fixture data. Run `swift test` before committing.

## Interplay with Governance (Example: Swift 6 Migration)

The Swift 6 migration pipeline exemplifies how governance and debt tracking interplay. (see Docs/Swift6Migration_Pipeline_Status.md)

*   **Phase 0 (Data Pipeline Fixes)** involved fixing UUID parsing, date handling, and implementing regex-based transformations for `SendableConformance`.
*   **Phase 1 (AST Infrastructure)** aims to move from regex to AST-aware transformations using `SwiftSyntax` for robustness.
*   **Governance Integration**: Rule activation is by trust tier, rule sets are version-tagged, and bandit metrics track rule success/failure. This ensures code changes, even during migration, adhere to governed policies and are tracked against technical debt.

## When editing code, follow these rules:

1.  **Refer to `Docs/ImplementationRules.md`** for specific do/don't guidelines.
2.  **Check `Docs/ADR/`** for architectural decisions impacting your change.
3.  **Ensure all new components are `Sendable` and `Codable`**.
4.  **Use `World` and `Scheduler` as actors** (always `await` their methods).
5.  **Reimplement Python/Node functionality in Swift**.
6.  **Track all stubs and incomplete features** in `Docs/TechDebt.md`.
7.  **Write comprehensive tests** for all new or modified logic.
8.  **Prioritize AnigmaCore's ECS and Job models** for all core functionalities.
9.  **Respect module boundaries** to prevent tight coupling.
10. **Document the source of ported code**.
