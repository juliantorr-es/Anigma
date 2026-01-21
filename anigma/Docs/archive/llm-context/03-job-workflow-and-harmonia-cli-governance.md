# Anigma: Job, Workflow, and Harmonia CLI Governance

AnigmaCore provides a unified Job and Workflow model, crucial for consistent unit-of-work tracking and system sequencing across all domain modules. Harmonia acts as the intelligent governance machine, orchestrating AI-driven tasks and enforcing policies. (see ADR/0002-job-and-workflow-model.md, Docs/architecture/governance_summary.md)

## Job and Workflow Primitives

*   **Job**: A unit of work, represented by a `Job` struct (`id`, `typeId`, `inputRefs`, `outputRefs`, `status`, `priority`, `metadata`, etc.). Jobs reference entities (not raw files) to maintain component state. (see ADR/0002-job-and-workflow-model.md)
    *   **JobStatus**: Enum for job lifecycle (`pending`, `running`, `completed`, `failed`, `cancelled`, `retrying`).
    *   **JobPriority**: Enum for ordering (`critical`, `high`, `normal`, `low`, `background`).
*   **Workflow**: A `Workflow` protocol defines an ordered sequence of `System` execution for a specific `Job` type (`name`, `jobTypeId`, `systemNames`). Modules register workflows with `WorkflowRegistry`, and AnigmaCore executes them. (see ADR/0002-job-and-workflow-model.md)
*   **Scheduler**: An actor-based component responsible for managing job queues, priority ordering, retry logic, and job lifecycle tracking. Currently, scheduler persistence is in-memory only, which is a known technical debt. (see ADR/0002-job-and-workflow-model.md, Docs/TechDebt.md)
*   **WorkflowRunner**: Connects jobs to system execution, looking up workflows by job type, running systems in order, and reporting success/failure. (see ADR/0002-job-and-workflow-model.md)

## Harmonia as Governed Refactoring and Migration Harness

Harmonia is the intelligent backend that orchestrates AI-driven workflows under strict governance. It provides a "stable front door" for governed operations, especially for tasks like Swift 6 migrations. (see Docs/architecture/governance_summary.md)

*   **GovernedMigrationCore**: Extracted as a clean target, it acts as a security-aware migration engine factory with trust integration and security events. It offers a narrow API (`runSwift6DiscoveryAndTaskCreation`, `runSwift6Steps`, `currentGovernanceSnapshot`). (see Docs/architecture/governance_summary.md)
*   **HarmoniaCLI**: Depends on `GovernedMigrationCore` (not the full `HarmoniaModule`) and exposes `swift6`, `security`, `trust`, and `governance` commands. These commands use the governed path and show status without raw DB access. (see Docs/architecture/governance_summary.md)

## Swift 6 Migration Pipeline Status

The Swift 6 migration pipeline is a key application of Harmonia's governance. (see Docs/Swift6Migration_Pipeline_Status.md)

*   **Phase 0 (Completed)**: Focused on data pipeline fixes, scout finding persistence, UUID/Date handling, task ID fixes, and regex-based file transformations (e.g., `applySendableConformance`).
*   **Phase 1 (TODO - AST Infrastructure)**: Planned to replace regex transformations with AST-based rules using `SwiftSyntax` for more robust and precise code modifications. Anchor points include `SwiftAstLens` (AST lookup), `RewriteRule` protocol, `RewritePipeline`, and `AgSearchService` (fast code search).
*   **Governance Integration**: Rule activation by trust tier (`.system`, `.trusted`, `.full`), version-tagged rule sets (`swift6-migration`), and bandit metrics track rule success/failure rates.

## "Anigma First, Opencode Second" Workflow

This workflow redefines roles: Anigma (via Harmonia) is the primary engine for governed automation; Opencode (human developer or un-governed AI) is an "expensive consultant." (see Docs/workflow-anigma-first.md)

*   **Anigma's Role**: Creating tasks (`harmonia scout`), running migrations (`harmonia swift6 step`), proposing modules (`harmonia module propose`), checking governance (`harmonia security status`), managing debt (`harmonia doctrine debt`). All code changes to Anigma's codebase should go through Anigma.
*   **Opencode's Role**: "Explain this file/symbol," "Show me a diff," "Sanity-check this design," "General programming questions unrelated to Anigma." Opencode should *not* be used for writing code in Anigma's codebase directly.
*   **Workflow**: Anigma proposes, Governance reviews, creates debt tasks if blocked, Human approves escalations, CCTV logs everything. (see Docs/workflow-anigma-first.md)
*   **Handling Blockages**: Don't bypass governance. Check CCTV, understand why, and address properly (research, fix violation, request trust escalation). (see Docs/workflow-anigma-first.md)
