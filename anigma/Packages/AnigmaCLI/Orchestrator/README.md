# AnigmaCLI - Orchestrator

## Responsibility
**Task coordination and execution management**.
The Orchestrator is the "brain" of the Anigma CLI, responsible for taking a high-level task intent and coordinating the planning, governance, and execution phases.

## Key Components

### 1. AnigmaCLIOrchestrator
The main entry point for planning and running tasks.
- **Planning**: Generates a `TaskContract` and determines the best `Provider` route.
- **Run**: Evaluates governance policies and manages the execution status.

### 2. LocalContractBuilder
Generates deterministic task contracts based on policy constraints.
- **Requirements**: Translates summary into actionable items.
- **Acceptance**: Injects banned patterns and completion markers.

### 3. CLIEventStream
Asynchronous event bus for real-time operation monitoring.
- **Transparency**: Emits fine-grained events for every stage of the lifecycle (contract built, route decided, governance approved, etc.).

## Execution Lifecycle
1.  **Intent**: Receive `TaskIntent`.
2.  **Plan**: Build `TaskContract` + Determine `Route`.
3.  **Govern**: Evaluate `WriteGate` and `KillSwitch` (via `GovernanceCore`).
4.  **Execute**: Dispatch to selected `Provider` (if approved).

## Maturity Level
**Level 5 (Golden)**: Strict concurrency enabled, full unit testing of coordination logic, event-driven architecture.
