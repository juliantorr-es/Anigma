# Research: Swarm Swift Orchestration Patterns

**Status:** Research / Reference  
**Source:** [github.com/christopherkarani/Swarm](https://github.com/christopherkarani/Swarm)  
**Relevance:** High (Local-first Swift orchestration, DAG-based execution, Workspace isolation)

## Architectural Observations

Swarm provides a robust model for local-first multi-agent coordination. Its design offers several "bridge" patterns that align with or extend Anigma's governance-first goals.

### 1. Resilient State via DAG Compilation
Swarm compiles agent workflows into a Directed Acyclic Graph (DAG).
- **Mechanism:** Steps are nodes; dependencies are edges. Execution state is persisted to a local workspace.
- **Anigma Application:** Anigma can "compile" `Docs/td/` YAML descriptors into an executable graph. This would allow `anigmad` (the Anigma daemon) to support crash-recovery: if a process is interrupted, it resumes by checking the last valid **Receipt** in the lane graph.

### 2. Workspace Separation (Hot vs. Cold State)
Swarm uses a `.swarm/` hidden directory for transient execution state.
- **Mechanism:** Stores PIDs, lockfiles, and temporary memory.
- **Anigma Application:** Anigma currently stores most state in `Docs/`. Adopting a `.anigma/` directory for "Hot" state (transient execution metadata) would keep `Docs/` reserved for "Cold" durable evidence (Proofs, Receipts, Doctrine).

### 3. Capability Discovery (Skills as Contracts)
Swarm treats "Skills" as discrete, discoverable units.
- **Mechanism:** The runtime audits the environment for available skills before execution.
- **Anigma Application:** This supports Anigma's **Native Executor Isolation**. Anigma can scan for native sidecars (e.g., `pdfium`) and register them as "Native Skills." If a skill is unavailable, the system marks the TD as `BLOCKED (Environment)` instead of failing at runtime.

### 4. Deterministic Handoffs (Receipt-Gated Control)
Swarm implements explicit handoffs between agents.
- **Mechanism:** Control is transferred based on state tokens or output patterns.
- **Anigma Application:** Anigma can use **Receipts as Handoff Tokens**. One Authority (e.g., `PDFSidecarAuthority`) produces a Receipt that acts as the required input token for the next Authority (e.g., `IngestionAuthority`) in the lane.

## Source Analysis Points

Study the following areas in `ExternalResearch/swift-tooling/swarm`:
- `Sources/Swarm/Core/State`: How transient state is managed.
- `Sources/Swarm/Core/Workspace`: How file-based memory and isolation are enforced.
- `Sources/Swarm/Core/Pipeline`: The DAG execution and step-transition logic.

## Recommended Boundaries

- **Adopt:** DAG-based task compilation, Hot/Cold state separation.
- **Avoid:** Swarm's specific implementation of agent "personalities" (keep Anigma's "Authority/Executor" model).
- **Refine:** Use Anigma's **Receipt** schema as the primary signal for DAG node completion.
