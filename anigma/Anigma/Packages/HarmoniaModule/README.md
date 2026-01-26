# HarmoniaModule

AI orchestration engine coordinating multi-step workflows across registered services with dependency resolution, retry logic, and state tracking.

## Invariants

- **Service Registry Uniqueness**: Each registered service must have unique ID; duplicate registration throws `serviceAlreadyRegistered` error
- **Workflow State Machine**: Workflows transition through states (pending → running → completed/failed/cancelled) with no direct backward transitions
- **Dependency Resolution**: Steps execute only when all dependencies are completed; circular dependencies detected and rejected before execution
- **Retry Enforcement**: Failed steps retry up to configured count before marking workflow as failed; retry delays follow exponential backoff policy

## Entry Points

- **HarmoniaCoordinator** — singleton actor orchestrating all workflows; `submitWorkflow()` enqueues execution, `getWorkflowStatus()` queries state, `cancelWorkflow()` stops in-flight work
- **ServiceRegistry** — thread-safe service discovery; `register()` adds services with their capabilities, `getServicesByCapability()` routes work to appropriate handlers
- **WorkflowDefinition** — immutable workflow specification with steps, dependencies, parallelization flag; defines what actions to invoke and in what order
- **WorkflowExecutor** — executes workflow steps with timeout/retry/dependency management; builds dependency graph, schedules parallel execution when permitted, tracks step outputs

## Build & Test

```bash
# Build module with dependencies
swift build -c release

# Run integration tests
swift test

# Run specific test
swift test HarmoniaModuleTests.HarmoniaCoordinatorTests
```

Tests verify: workflow submission, dependency resolution, parallel execution, error handling, retry logic, state transitions.

## Links

- **Coordinator**: `Coordinator/HarmoniaCoordinator.swift` (230 lines) — main orchestration actor
- **Registry**: `Services/ServiceRegistry.swift` (180 lines) — service discovery and capability tracking
- **Executor**: `Services/WorkflowExecutor.swift` (320 lines) — step execution with retry/timeout
- **Models**: `Models/WorkflowModels.swift` (280 lines) — state machines, execution records, codable helpers
- **Unit Tests**: `Tests/HarmoniaModuleTests/`
- **Related Packages**: AccessumModule, ObservatoriumModule (registered services), AnigmaDaemonCore (HTTP API integration)
- **Minimum Platform**: macOS 14+, iOS 17+
