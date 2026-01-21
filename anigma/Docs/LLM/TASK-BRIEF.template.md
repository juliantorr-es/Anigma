# Anigma Agent Task Brief

## Task ID: [Unique ID, e.g., GH-Issue-XXX]

## Objective

[A concise, unambiguous statement of the task's goal. What should be achieved?]

## Scope

*   **Target Files/Directories**: [List specific files or directories involved, e.g., `Sources/HarmoniaModule/`, `Package.swift`]
*   **Excluded Files/Directories**: [List any files or directories explicitly out of scope]
*   **Module(s) Affected**: [e.g., AnigmaCore, GovernedMigrationCore]
*   **Time Estimate**: [e.g., "Small (1-2 hours)", "Medium (half day)", "Large (1-2 days)"]

## Context & Background

[Provide any necessary background information. Why is this task important? What problem does it solve?]

## Invariants

[Crucial properties or behaviors that must *always* remain true after the change. These are non-negotiable success criteria.]

*   [Example: "All existing unit tests in `Tests/GovernedMigrationCoreTests/` must pass."]
*   [Example: "The module must continue to build successfully on macOS."]
*   [Example: "No new runtime dependencies on Python or Node.js are allowed."]

## Relevant Documentation

*   **ADR(s) Affected/Referenced**: [List any relevant ADRs, e.g., `ADR/0004-module-boundaries.md`]
*   **Design Docs**: [Links to any design documents or specifications]
*   **Core Principles**: `Docs/AnigmaConstitution.md`, `AGENTS.md`

## Forbidden Actions/Patterns

[Explicitly list anything that should NOT be done or introduced. This reinforces negative constraints.]

*   [Example: "Do not introduce any new direct `SQLite3` C API calls."]
*   [Example: "Do not modify `Package.swift` to add AGPL/GPL dependencies."]
*   [Example: "Do not alter the `EntityId` structure."]

## Acceptance Criteria & Tests

[How will success be measured? What tests should pass or be created?]

*   [List specific existing tests that must pass.]
*   [Outline requirements for new unit/integration tests.]
*   [Describe expected manual verification steps, if any.]

## Deliverables

*   [List expected outputs: code changes, updated documentation, new tests, updated `Docs/TechDebt.md` entries if stubs are created/resolved.]

## Rollback Plan

[A brief description of how to revert the changes if something goes wrong.]

*   [Example: "Revert `git commit [commit-hash]`"]
*   [Example: "Delete new files and revert modifications."]
