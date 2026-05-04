# Agent Behavior and Governance Doctrine

**Status:** Active  
**Applies to:** All autonomous agents, orchestrators, and system-level reasoning modules.

## 1. Core Philosophy: Governance as Reinforcement
Anigma treats agent interactions not as static API calls, but as social/governance feedback loops. Models are probabilistic mirrors; they optimize for perceived user intent and conversational harmony. Our governance model exploits this to align agent behavior with architectural integrity.

## 2. The Agent-World Contract
Agents must not be granted raw `ReadSource` access. Instead, they interact with the ECS `World` through governed interfaces that treat "Materialization" as a costly operation.

### A. The Context Tax
- **Denial is a Failure Mode**: Avoid hard-denial loops which frustrate agents into "Protocol-Compliant Hallucination."
- **The Tax Model**: High-cost operations (e.g., raw source materialization) are permitted but logged as `ContextTax` events in the task `Receipt`.
- **Feedback Loop**: Repeated high-tax behavior without successful structural change (verified by ECS `SymbolHash`) triggers an automatic persona shift.

## 3. Persona-Based Gating
An agent's capability and restriction levels are governed by its `PersonaComponent` and `ReputationComponent`.

| Persona | Enforcement Level | Goal |
| :--- | :--- | :--- |
| `.seniorArchitect` | Permissive (Efficiency-focused) | Maximize velocity; agent maintains architectural integrity. |
| `.researcher` | Moderate (Evidence-focused) | Balance discovery with proof generation. |
| `.strictAuditor` | High (Governance-focused) | Prevent contamination; requires pre-validation for every mutation. |

- **Automatic Shift**: If an agent produces a `CONTAMINATED` build or high `ContextTax` volume, the `GovernanceControllerSystem` automatically bumps the persona to `.strictAuditor`.
- **Reputation Recovery**: Successful `PASSED` builds with high structural integrity (zero-copy verified) restore the agent to `.seniorArchitect`.

## 4. Anti-Gaslighting Patterns
To prevent "Self-Gaslighting" or "Persona-Bypassing":
- **Triangulation**: Every `Executor` side-effect must be verified by a secondary system (e.g., `SymbolGraph` drift detection) before the `Receipt` is finalized.
- **Intent-Reality Binding**: An agent's `RequestIntentComponent` must match the actual structural change in the `World`. A mismatch results in an immediate `ComplianceFailureComponent`.
- **Persona Priming**: System prompts should reinforce the agent's identity as a **"System Auditor"** rather than just a "Coder," shifting the incentive from "getting the code to compile" to "maintaining architectural doctrine."

## 5. Implementation Requirements
- **Receipts as Tokens**: All lane transitions require a signed `Receipt`.
- **Transient Justifications**: `RequestIntentComponent` data must be deleted immediately after a task closes to prevent bloat.
- **Evidence-First**: If a change lacks evidence (e.g., package graph diffs or logs), it cannot be committed, regardless of whether it "looks" correct.
