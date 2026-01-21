# Anigma: Governance and LLM Behavior

Harmonia's Governance Model ensures safe, auditable, and policy-driven AI interactions, transforming AI from a black box into a transparent, accountable system. (see Docs/concepts/governance-model.md)

## Key Governance Components

1.  **Playbook Evaluator**: Central policy engine evaluating every proposed AI action against rules in "Playbooks" (`harmonia.personality.toml`). Actions can be Allowed, Denied, or Require Confirmation. (see Docs/concepts/governance-model.md)
2.  **Write Gate Service**: Critical safety mechanism preventing AI from writing code if quality checks (e.g., unit tests, linters) fail. Enforces "build-before-write" or "test-before-write." (see Docs/concepts/governance-model.md)
3.  **Kill Switch**: A fail-safe for immediate suspension of all AI write operations, globally or per-project. Prioritizes safety over automation. (see Docs/concepts/governance-model.md)
4.  **Provenance & Audit Trails**: Comprehensive logging of every significant AI action, decision, and interaction (governance decisions, AI-generated commits, memory modifications) for full auditability and accountability. (see Docs/concepts/governance-model.md)

## Governance Spine: Three-Layer Control

Anigma operates with a three-layer governance model for autonomous software maintenance:
1.  **Security Layer (What can the AI do?)**: Capability-based control with Trust Tiers (Bronze, Silver, Gold, Platinum) and Security Zones (Untrusted, Sandboxed, etc.). Enforced by `CapabilityValidator` with CCTV logging. (see Docs/architecture/governance_summary.md, Docs/paper-scaffolding.md)
2.  **Doctrine Layer (How should it do it?)**: Enforces architectural and quality standards via `DoctrineGuards` using AST patterns, complexity limits, and architectural rules. Severity levels (Critical, Error, Warning) lead to blocking or advisory. (see Docs/architecture/governance_summary.md, Docs/paper-scaffolding.md)
3.  **Research Layer (Why should it do it?)**: Requires evidence-based justification for changes. `ResearchGate` blocks module creation without adequate `ResearchBundles` (papers, docs). Creates `ResearchDebtTask` for missing literature. (see Docs/architecture/governance_summary.md, Docs/paper-scaffolding.md)

## Observability (CCTV)

The `security_events` SQLite table records all governance decisions (blocked/granted capabilities, doctrine violations, research inadequacy, trust changes, mode changes) with severity and metadata. CLI tools (`harmonia security status`, `doctrine status`, etc.) surface this data. (see Docs/architecture/governance_summary.md)

## Rules for AI Agents Touching Code (LLM Behavior)

AI assistants working on Anigma must adhere to strict guidelines:

*   **Before You Start**: Read `Docs/AnigmaConstitution.md`, `Docs/Roadmap.md`, relevant `Docs/ADR/`, and `Docs/ImplementationRules.md`. (see Docs/LLM-Guidelines.md)
*   **AnigmaCore is the Only ECS**: Never create parallel ECS frameworks (e.g., `protocol MyComponent`, `class MyWorld` in modules). Use `AnigmaCore` for all ECS types. (see Docs/LLM-Guidelines.md)
*   **No Python, No Node**: Never use `Process.run("python3", ...)` or `Process.run("node", ...)` in code. Re-implement external tool functionality in Swift. (see Docs/LLM-Guidelines.md)
*   **Lab Code is Reference Only**: External repos are for studying patterns, learning algorithms, and extracting requirements. Do NOT copy code directly; re-design in Swift fitting the AnigmaCore model. (see Docs/LLM-Guidelines.md)
*   **Check ADRs First**: Before modifying ECS, Jobs, or Workflows, check `Docs/ADR/`. Propose a new ADR if your change conflicts or is a major decision. (see Docs/LLM-Guidelines.md)
*   **Prefer Convergence**: Converge duplicate patterns to `AnigmaCore` definitions (e.g., `JobStatus`). (see Docs/LLM-Guidelines.md)
*   **Document Migration Source**: Note the source of ported code (e.g., "Ported from: `harmonia_dsps_altmedia_engine/ocr_pipeline.py`"). (see Docs/LLM-Guidelines.md)
*   **Forbidden Patterns**: Do not use `import MyModuleECS`, `class World` in module, `shell("python", ...)`, `require('tool')`, or copy-pasting from lab repos. (see Docs/LLM-Guidelines.md)
*   **Daily Workflow**: Anigma proposes, Governance reviews, creates debt tasks, Human approves escalations, CCTV logs everything. Opencode is a consultant for explanation/design review, not a primary agent. (see Docs/workflow-anigma-first.md)
*   **Handling Blockages**: Do not bypass. Check CCTV, understand why, and address properly (research, fix violation, request trust escalation). (see Docs/workflow-anigma-first.md)
*   **Governance Logging Discipline**: After each session, update `docs/governance-logbook.md` with a snapshot of `harmonia security/doctrine/research status` and notes on interactions. (see Docs/workflow-anigma-first.md)

## Governance as an API: Explicit Contracts and Proofs

While Anigma's governance model is conceptually strong, future development should make "Governance as an API" brutally explicit. This means defining a formal schema for action proposals, required evidence fields, and a minimal log record that every decision must emit. This approach treats governance like a testable protocol, providing proofs of compliance and denial. **This formalization defines a protocol that can be unit-tested and fuzz-tested.** (feedback from review)

*   **Action Proposals**: Should have a formal schema outlining the proposed action, context, and required evidence.
*   **Logging Requirements**: Every significant decision (allowed, denied, escalated) must emit a minimal, structured log record including the proposal, decision, and rationale.
*   **Proof of Denial**: For denied actions, the system must be able to prove *why* a denial was correct based on explicit rules and provided evidence.
*   **Fuzz Testing**: The formalization allows for fuzz-testing the governance protocol to ensure robust and predictable behavior.
