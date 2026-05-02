# Harmonia Module Migration Ledger

This document details the migration of components and systems from the legacy `OrchestrumCore` project into the `Anigma` ecosystem's `HarmoniaModule`.

## I. Overview

The primary goal of this migration is to integrate the AI-assisted code orchestration capabilities of `OrchestrumCore` into the modular Entity-Component-System (ECS) architecture of `Anigma`. This ledger records the status of migrated elements, renaming conventions, and key architectural decisions to ensure semantic consistency and maintain clear module boundaries.

## II. Migrated Components

The following components have been successfully migrated from `/Users/user/Developer/GitHub/Harmonia/Sources/OrchestrumCore/ECS/Components.swift` to `Anigma/Sources/HarmoniaModule/Components/`.

For each component, the migration involved:
*   Changing `import OrchestrumCore` to `import AnigmaCore`.
*   Ensuring conformance to `AnigmaCore.Component` and `Codable`.
*   Replacing `ModelKind` enum references with `String` for portability (where applicable).

### List of Migrated Components:

*   **`SlotComponent`**: Manages concurrency slots for AI models.
*   **`RequestComponent`**: Represents an inference request.
*   **`SessionComponent`**: Manages user sessions.
*   **`MetricsComponent`**: Aggregates AI model performance metrics.
*   **`ConcurrencyStateComponent`**: Tracks the current state of concurrency for models.
*   **`HealthComponent`**: Represents the health status of a subsystem.
*   **`ThroughputSampleComponent`**: Records time-series samples for throughput tracking.

## III. Migrated Systems

The following systems have been migrated from `/Users/user/Developer/GitHub/Harmonia/Sources/OrchestrumCore/ECS/Systems.swift` (or inferred equivalent) to `Anigma/Sources/HarmoniaModule/Systems/`.

For each system, the migration involved:
*   Changing `import OrchestrumCore` to `import AnigmaCore`.
*   Adapting `world.query` and other ECS interactions to `AnigmaCore`'s API.
*   Replacing `ModelKind` enum references with `String` or correctly interacting with the `ModelConcurrencyController`'s `ModelKind` enum.

### List of Migrated Systems:

*   **`MetricsAggregationSystem`**: Aggregates metrics from completed requests.
*   **`HealthCheckSystem`**: Monitors subsystem health.
*   **`SlotManagementSystem`**: This system was migrated from `ConcurrencySyncSystem` in `OrchestrumCore/Sources/OrchestrumCore/ECS/Systems.swift`. Its responsibilities closely align with the originally intended `SlotManagementSystem` from the migration checklist (managing concurrency slots and synchronizing with a `ModelConcurrencyController`).

### Missing System: `RequestRoutingSystem`

The `RequestRoutingSystem`, as listed in the original migration checklist in `HarmoniaModule.swift`, could not be located in the legacy `OrchestrumCore` project through `grep` searches.
*   **Status**: Not found.
*   **Possible Reasons**: It may have been renamed, its responsibilities absorbed by other systems, or it was a planned but unimplemented feature in the legacy codebase.
*   **Invariant Consideration**: Its functionality (routing inference requests) is critical for AI orchestration. Future semantic validation will need to verify how this responsibility is handled in the integrated `HarmoniaModule`.

## IV. Updated Module Registration

The `register` function within `Anigma/Sources/HarmoniaModule/HarmoniaModule.swift` has been updated to include the migrated systems.

*   **Changes**: Uncommented `await world.registerSystem(SlotManagementSystem(controller: controller))` and added `await world.registerSystem(MetricsAggregationSystem())` and `await world.registerSystem(HealthCheckSystem())`.
*   **Dependencies**: The `register` function now requires a `ModelConcurrencyController` instance to be passed, reflecting the dependency of `SlotManagementSystem`.
*   **Workflows**: Workflow registration calls (`CodeRefactorWorkflow`, `BatchRunWorkflow`) remain commented out, indicating they are not yet migrated or integrated.

## V. Build Error Resolution Log

During the migration and subsequent build attempts, several errors were encountered and resolved:

*   **Missing Module `SecurityEventsManager`**: Resolved by identifying `SecurityEventsManager` as an internal file within `HarmoniaModule` and removing the erroneous `import SecurityEventsManager` statement from `TrustScoreCalculator.swift`.
*   **Duplicate `@main` Attributes**: Removed the `@main` attribute from `InspirationCLI.swift` as `HarmoniaCLI` is the designated main executable.
*   **`invalid redeclaration of 'StatusCommand'`**: Removed a duplicate definition of `StatusCommand` within `InspirationCLI.swift`.
*   **Missing `gatekeeper` Argument**: Added the `gatekeeper: InspirationGatekeeper(indexStore: indexStore)` argument to the `InspirationPipelineService` initializer in `InspirationCLI.swift`.
*   **`async` Context Mismatches**:
    *   Made the `InspirationCommands` initializer `async throws`.
    *   Added `await` to all calls of `InspirationCommands()` within `InspirationCLI.swift`'s subcommands.
*   **Duplicate `NameComponent` and `TagComponent`**: Removed `PlaceholderComponents.swift` from `Anigma/Sources/AnigmaCore/` as `NameComponent` and `TagComponent` were already defined in `SharedComponents.swift`.
*   **Missing `ModelConcurrencyController`**:
    *   Located `ModelConcurrencyController.swift` in the legacy project.
    *   Migrated its code into `Anigma/Sources/HarmoniaModule/Models/ModelConcurrencyController.swift`, including its supporting types (`ModelKind`, `ConcurrencyLimits`, `ConcurrencyStats`).
*   **`ModelKind` Type Mismatches in `SlotManagementSystem.swift`**: Modified `SlotManagementSystem.swift` to correctly use `kind.rawValue` when interacting with `ConcurrencyStateComponent` and `NameComponent`, and for comparisons.
*   **Doctrine/Trust Enum & Type Mismatches**:
    *   Identified `DoctrineDomain`, `DoctrineSeverity`, and `CheckType` definitions in `DoctrineCore/DoctrineTypes.swift`.
    *   Added `import DoctrineCore` to `VersionedDoctrinePacks.swift`.
    *   Updated enum member references in `VersionedDoctrinePacks.swift` to use the fully qualified `DoctrineCore.DoctrineSeverity.<member>` and `DoctrineCore.CheckType.<member>`.
    *   Replaced `DoctrineCore.CheckType` with `DoctrineRule.RuleImplementation` in `VersionedDoctrinePacks.swift` where `DoctrineRule` expected its internal enum.
    *   Removed duplicate enum definitions (`DoctrineSeverity`, `StaticDoctrineRule`, `DoctrineViolation`) from `HarmoniaModule/Doctrine/DoctrinePacks.swift` to resolve conflicts and ensure `DoctrineCore` is the canonical source.
    *   Replaced all occurrences of `DoctrineTrustTier` with `TrustTier` in `VersionedDoctrinePacks.swift` to unify trust tier types.
*   **`InspirationScout` Protocol Conformance**:
    *   Removed the conflicting `InspirationScoutProtocol` definition from `InspirationScoutRegistry.swift`.
    *   Modified `InspirationScoutRegistry` to directly use the `InspirationScout` protocol (defined in `InspirationScout.swift`).
    *   Updated the `init()` method in `InspirationScoutRegistry` to be `async` and `await` the `registerDefaultScouts()` call.
    *   Modified `registerDefaultScouts()` to be `async` and `await` all `register()` calls.
    *   For each `*Scout` struct (`ArchitectureScout`, `ASTTraversalScout`, `RuleDesignScout`, `PipelineScout`, `CachingScout`, `CLIScout`, `ConfigScout`, `ToolingScout`, `TestingScout`, `DocumentationScout`) within `InspirationScoutRegistry.swift`:
        *   Changed `let name = "..."` to `public let id = "..."`.
        *   Changed `let description = "..."` to `public let displayName = "..."`.
        *   Updated the `scan` function signature to match `func scan(repo: InspirationRepo, projectRoot: String, indexStore: InspirationIndexStore) async throws -> [InspirationPattern]`.

## VI. Invariants and Semantic Considerations

### System Semantics:
*   **`SlotManagementSystem`**: Now responsible for managing `SlotComponent` states and synchronizing with `ModelConcurrencyController`. An invariant to validate is that `SlotManagementSystem` remains the sole system directly modifying `SlotComponent`s. Further testing would be required to ensure that the system correctly updates the world state based on `ModelConcurrencyController`'s feedback and that entities with `SlotComponent` accurately reflect concurrency status.

### Governance Semantics:
*   **Module Boundaries**: The process of unifying `DoctrineSeverity`, `DoctrineDomain`, and `TrustTier` definitions by making `DoctrineCore` the canonical source is critical for maintaining clear governance semantics. This ensures that policy definitions are centralized and consistently applied.
*   **`TrustScoreCalculator`, `DoctrineGuards`, `ResearchGate`**: These modules are intended to enforce governance. Their current implementations in `Anigma` should interact with runtime state primarily through explicit interfaces (like the `securityEvents` manager and the `database` actor), minimizing direct "rummaging" in unrelated modules. Continued vigilance is needed to prevent circular dependencies or accidental direct access to internal components. The migration has primarily focused on enabling compilation; deeper semantic review and dedicated tests for governance rules are essential next steps.

## VII. Next Steps Proposed

1.  **Semantic Validation (Smoke Test)**: Implement a small test harness that spins up a minimal `World`, registers the migrated systems, creates entities, runs a tick, and confirms expected state transitions. This will ensure semantic correctness beyond compilation.
2.  **`RequestRoutingSystem` Clarification**: Revisit the absence of `RequestRoutingSystem`. If its responsibilities were absorbed or renamed, explicitly document where this functionality resides and how it integrates into the new architecture.
3.  **Refine Governance Invariants**: Explicitly define and test invariants related to governance modules to ensure they interact via narrow, auditable interfaces.
4.  **Continue Migration of Workflows**: Migrate `CodeRefactorWorkflow` and `BatchRunWorkflow` from `OrchestrumCore/Sources/OrchestrumCore/Jobs/` to `HarmoniaModule/Pipelines/` and integrate them into `HarmoniaModule.swift`.
5.  **Address Remaining Warnings**: Systematically address the remaining warnings (e.g., unused variables, unreachable catch blocks).

This ledger will be kept up-to-date as further migration and development occurs.