# Procedural UI Schema

Anigma treats procedurally generated UI as an **engine capability**, not a toolkit dialect. The canonical truth is the schema that the engine emits for a screen, job graph, or governance prompt; every renderer (SwiftUI/AppKit, COSMIC, etc.) merely projects that truth with fidelity while delegating intent, policy, and provenance back to the engine.

## Schema as the product

- A screen is a tree of nodes (DocumentPreview, ArtifactTable, JobTimeline, PolicyDecisionPanel, CommandPalette, DiffViewer, LogStream, GraphView, InspectorPane, etc.) with explicit semantics: what it needs, what it shows, what it can do, and what it is allowed to do.
- Nodes declare capabilities and emit action requests rather than calling subsystems directly. The engine evaluates those requests, enforces policy, executes the work, logs the outcome, and responds with approval or denial that the renderer displays.
- This keeps UI as a controlled client of the engine, not a sovereign graph of widgets with hidden state or bespoke view models.

## Layout as data

- Define toolkit-neutral layout atoms—stack, split, grid, min/max sizing, resizability, docking regions, responsive rules (e.g., collapse sidebar below width X), etc.—and keep them compact.
- A renderer applies its native widgets to those atoms so the same intent can be implemented across SwiftUI, COSMIC, or future shells without diverging pixel-for-pixel.
- Avoid “design religion” tricks; focus on a small, expressive set of layout primitives that match the game you are already playing.

## Accessibility metadata

- Every node carries accessibility semantics: role, label, hint, value text, focus order, keyboard navigation, and announcement behavior for dynamic changes.
- Validate accessibility invariants at the schema level (“actionable nodes have names,” “focus escapes traps,” “critical errors announce,” “color is never the only signal”), before anything renders.
- This keeps the accessibility story consistent instead of treating it as a per-toolkit patchwork.

## Capability-gated actions

- An action is a capability request (export artifact, delete job run, connect network, read file, open microphone, share workspace, approve policy exception, elevate trust, etc.).
- The engine evaluates requests against policy, trust score, provenance, governance mode, etc. If denied, renderers show the engine-provided reason; if allowed, the engine executes and emits an event result.
- UI misuse becomes mechanically hard because every interaction asks the engine for permission and the response is logged.

## Provenance and auditability

- Every UI event carries a provenance envelope: selected artifacts, workflow definitions that produced the button, policy gates evaluated, chosen settings, renderer origin, etc.
- The engine stores that metadata alongside job runs, outputs, hashes, and policy decisions so “why did this output exist?” has receipts instead of vibes.
- Schema-driven UI funnels everything through the same event/log pipeline, shrinking side doors compared to hand-built UI.

## Renderers as replaceable shells

- With schema as truth, a renderer is an adapter that:
    - Renders the node tree into native widgets, layout, and theming.
    - Translates platform input (clicks, keyboard, drag/drop) into engine action requests.
    - Subscribes to engine state updates and re-renders.
- SwiftUI/AppKit remains the primary renderer for macOS, but COSMIC can coexist as a strategic shell that reads the same schema, enforces the same action contract, and talks to the same engine.
- The engine doesn’t care whether it is SwiftUI, COSMIC, web view, or terminal UI; it emits schema + accepts action requests so any compliant renderer can plug in.

## Procedural generation

- Workflow definitions declare inputs, options, constraints, and outputs, letting the engine generate forms, inspectors, timelines, and result views.
- Artifact schemas give each type its own inspectors, previews, and actions automatically.
- Job graphs define canonical status visualizations, retry controls, logs, and diff views in data form.
- Governance policy can adjust UI friction or visibility depending on trust mode without duplicating logic in the renderer.
- Because it is data, you can also safely generate schema proposals via LLMs: they suggest transformations that rules validate, instead of scribbling SwiftUI.

-## Renderer maturity model

- Start with a minimal renderer that maps the schema’s basic nodes (text, buttons, lists, form fields, splits) to native widgets, relies on the host toolkit for layout/accessibility, and forwards action intents to Harmonia’s governed runtime. SwiftUI/WinUI/libcosmic provide measurement, focus, keyboard handling, and the accessibility tree, so the renderer stays a thin adapter.
- Gradually add features only when the contract proves it needs them: consistent keyboard shortcuts, focus model invariants, capability-gated proposal dialogs, provenance event hooks, and performance tuning. When those claims grow, treat them as higher-level requirements and keep them above the renderer so you never rewrite every platform just to stay consistent.
- If you need pixel-perfect parity, custom layout, or host-toolkit-agnostic animations, that’s a different project (a UI toolkit). Accept the tradeoff: the renderer is only “relatively simple” while it remains a node-to-native adapter with governed action wiring.

## Renderer portability

- Supporting a new platform becomes “add a renderer” instead of “port the app.” SwiftUI/AppKit stays macOS-first, COSMIC can be a Linux shell, and web/terminal renderers simply obey the same schema.
- Renderers stay dumb: they render nodes, forward events, and display engine state while the engine retains the brain, governance, and provenance.
- Accessibility and capability gating travel with the schema, so each renderer maps the same roles, labels, focus order, and policy decisions to its native APIs.
- Version and test the schema as a contract; resist grafting platform-specific hacks into it. Once you let quirks leak in, you have N different UIs again, just described in data instead of code.

## Keep it declarative

- The schema describes intent and permitted actions, not a full scripting runtime. Expressions for visibility or derived text are fine, but keep them constrained.
- Complex logic belongs in the engine where it is testable, auditable, and governed.
- Avoid turning the schema into a second programming language; otherwise you rebuild the same dashboard mess, only now in JSON.

## Outcome

You get portability without a rewrite, governance without duct tape, accessibility you can validate, and a UI surface that evolves procedurally along with Anigma. The renderer becomes a faithful shell, provenance becomes audit-grade, and COSMIC (or any future shell) is just another renderer plugging into the engine’s schema contract.
