# Anigma: Demos, Aerodrome-9, and Anigma in Practice

Anigma is designed to enable practical, governed, AI-driven solutions for complex workflows. The Aerodrome-9 demo and the "Anigma First, Opencode Second" workflow provide concrete examples of Anigma's capabilities in action and its intended use.

## Aerodrome-9: Anigma ECS Game Demo Spec

Aerodrome-9 is a small, self-contained narrative tactics demo showcasing Anigma’s ECS architecture, governance-driven session harness, and dynamic, locally generated dialogue via MLX-powered models. (see Docs/Aerodrome9_Demo_Spec.md)

*   **Concept**: "Foundation meets Jules Verne" on a floating "balloon world." A single crisis: Will the Windwright Guild cut imperial relay access during a storm?
*   **Player Experience**: Low-resolution character on a 2D tile map, inspecting devices, talking to NPCs. Investigation phases (Examine, Listen, Probe) reveal facts, consume action points.
*   **ECS Data Model**: All game state expressed through ECS components (`Position`, `Sprite`, `ActorRole`, `FactionAlignment`, `Interactable`, `SceneState`, `WorldState`, `ChoiceHistory`) and systems (`InputSystem`, `MovementSystem`, `RenderingSystem`, `InteractionSystem`, `DialogueSystem`, `SceneResolutionSystem`, `PsychohistorySystem`, `UISystem`).
*   **Dynamic Dialogue via Local MLX LLM**: Dialogue content generated at runtime using a local MLX model (mlx-swift). The `DialogueEngine` operates behind a strict interface, proposing effects that are run through the governance system, not freely changing state.
*   **Integration with Harmonia Harness**: The demo is treated as a normal harness session, governed by trust tiers and config. Scene runs produce `SessionReport` with `GovernanceTrace` and metrics.

## Anigma in Practice: "Anigma First, Opencode Second" Workflow

This workflow emphasizes Anigma (via Harmonia) as the primary engine for governed automation, with Opencode (human developer or un-governed AI) acting as a consultant. (see Docs/workflow-anigma-first.md)

*   **Role Shift**: Anigma *proposes* things, Governance *reviews* them, *creates debt tasks* if blocked, and Human *approves escalations*. CCTV logs everything.
*   **Anigma's Use Cases**: Creating tasks (`harmonia scout`), running migrations (`harmonia swift6 step`), proposing modules (`harmonia module propose`), checking governance (`harmonia security status`), managing debt. This covers *any code change to Anigma's codebase*.
*   **Opencode's Use Cases**: Limited to "Explain this file/symbol," "Show me a diff," "Sanity-check this design," "General programming questions unrelated to Anigma." *Not* for direct code writing.
*   **Governance Discipline**: After each session, update `Docs/governance-logbook.md` with governance snapshots and notes.
*   **Handling Blockages**: Don't bypass. Use CCTV to understand *why* a blockage occurred (Research, Doctrine, Security) and follow the proper process to address it (e.g., do literature review, fix violation, request trust escalation).

## How Demos Relate to Anigma's Principles

*   **Governance**: Aerodrome-9 explicitly integrates with the governance system (e.g., dialogue effects are run through governance). The "Anigma First" workflow is entirely predicated on governance. (see Docs/Aerodrome9_Demo_Spec.md, Docs/workflow-anigma-first.md)
*   **MLX & Local-First AI**: Aerodrome-9 utilizes local MLX LLMs for dynamic dialogue, showcasing privacy and performance benefits of on-device AI. This aligns with Anigma's MLX strategy. (see Docs/Aerodrome9_Demo_Spec.md, Docs/architecture/mlx-strategy.md)
*   **Accessibility**: While Aerodrome-9 isn't directly an accessibility app, its ECS framework is shared with Accessibility-focused modules like Diaplasion and Accessum. The core principles of transparent, auditable interactions apply. (see Docs/Overview.md, Docs/public/atlas/index.html)
*   **Institutional Adoption**: The demos reinforce that Anigma can deliver "ship experiences" (Aerodrome-9) and provide controlled, auditable development processes ("Anigma First"), appealing to institutional needs for control and compliance. (see Docs/Aerodrome9_Demo_Spec.md, Docs/strategy/market-positioning.md)

## Anigma in Production (Alpha Release Context)

The `Anigma Core Alpha Release` (2025-12-06) indicates the core ECS, job, workflow, and several modules (Diaplasion, Harmonia, Outlineum) are stable and implemented, with MLX audio integration validated. This forms the foundation upon which practical applications like demos and governed workflows are built. (see Docs/releases/anigma-core-alpha.md)

## Aerodrome-9 as a Regression Harness

Aerodrome-9 is not "just a demo"; it acts as a vertical slice that forces the ECS, governance, and MLX boundaries to behave under interactive pressure. This makes it an effective regression harness for governance semantics, allowing the project to catch failures in the architectural and governance layers long before they manifest in higher-stakes accessibility workflows. The "dialogue proposes effects that governance approves" pattern within Aerodrome-9 is a key example of the desired governed interaction model. (feedback from review)
