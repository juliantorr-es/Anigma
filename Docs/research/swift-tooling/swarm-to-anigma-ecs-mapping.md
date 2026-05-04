# Mapping Swarm Orchestration to Anigma ECS Runtime

**Status:** Research / Mapping  
**Focus:** Translating Swarm's Durable Execution and multi-agent workflows into Anigma's Entity Component System (ECS).

## 1. Architectural Alignment

Swarm's `Workflow` and `WorkflowDurableEngine` provide high-level abstractions for sequential, parallel, and routed multi-agent steps. Anigma's ECS (`World`, `System`, `Component`) provides a low-level, high-performance runtime for managing thousands of stateful entities.

### Concept Mapping Table

| Swarm Concept | Anigma ECS Mapping | Rationale |
| :--- | :--- | :--- |
| `Workflow` | `PipelineEntity` (with `NodeGraphComponent`) | A workflow is a definition of a graph. |
| `Workflow.Step` | `NodeInstance` | Individual steps are nodes in the graph. |
| `WorkflowDurableEngine` | `PipelineExecutionSystem` | The system that drives the execution of the graph. |
| `Checkpoint` | `PipelineExecutionComponent` (Snapshot) | Execution state is stored as component data. |
| `HiveSchema` / `HiveChannel` | `Component` | State is decomposed into granular components. |
| `AgentRuntime` | `Executor` / `Authority` | The actual worker that performs the task. |

## 2. Patterns for Anigma ECS

### A. Durable Lane Execution (Checkpointing)
Swarm's `WorkflowDurableEngine` uses a cursor-based approach to resume execution.
- **ECS Pattern:** The `PipelineExecutionComponent` should track `currentNodeId` and `status`. 
- **Resiliency:** When `anigmad` starts, a `ResumptionSystem` queries all entities with `PipelineExecutionComponent` where `status == .running` and verifies if the actual process is still alive. If not, it triggers a restart from the last successful node.

### B. Reactive Lane Transitions
Swarm uses routers and fallbacks to manage control flow.
- **ECS Pattern:** Instead of a central engine loop, use **Component Signaling**. 
- **Mechanism:**
    1. A `TaskExecutorSystem` completes a task and adds a `TaskReceiptComponent` to the entity.
    2. A `LaneTransitionSystem` observes the `TaskReceiptComponent`, consults the `NodeGraphComponent`, and updates the `PipelineExecutionComponent` to point to the next node.
    3. The `TaskExecutorSystem` picks up the update and starts the next task.

### C. Capability-Based Execution (Skills)
Swarm treats agents as "Skills."
- **ECS Pattern:** Tag implementation entities with `CapabilityComponent`.
- **Anigma Application:** Before starting a `PipelineExecution`, a `ReadinessSystem` checks if all required `CapabilityComponents` are present in the `World`. If a native sidecar (`pdfium`) is missing, the execution entity is tagged with `BlockedComponent(reason: .missingCapability)`.

### D. Hot/Cold State Separation
- **Hot State (ECS):** Active execution data, temporary materialization pointers, and PIDs live as components in the `World`.
- **Cold State (Durable):** Completed `TaskReceipts`, `Proofs`, and `Doctrine` are serialized and moved to `Docs/proofs/` and the local SQLite database (`contextum.sqlite`).

## 3. Implementation Strategy: "The Receipt Component"

The core bridge between Swarm's "Handoff" and Anigma's "Governance" is the **Receipt**.

```swift
/// Anigma ECS Component for Swarm-style Handoffs
public struct TaskReceiptComponent: Component, Codable {
    public let receiptId: UUID
    public let authorityId: String
    public let inputHash: String
    public let outputHash: String
    public let signature: String
    public let status: TaskStatus
}
```

In Anigma's ECS runtime, the presence of a valid `TaskReceiptComponent` on an entity acts as the **Governance Gate**. No system can advance the `PipelineExecutionComponent` unless the `TaskReceiptComponent` for the current node passes signature and doctrine validation.

## 4. Next Steps for Research

1.  **Analyze `Swarm/Core/Execution`**: Understand how Swarm handles the actual async/await transitions.
2.  **Prototype `LaneTransitionSystem`**: Create a minimal ECS system that drives a 3-node sequential pipeline using components as signals.
3.  **Map HiveCore to ECS**: Swarm's durable engine depends on `HiveCore`. Investigate if Anigma's `DatabaseCore` (PostgreSQL) should act as the backing store for ECS component persistence.
