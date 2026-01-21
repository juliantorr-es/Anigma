# Anigma UI Kernel

The UI kernel is not a renderer. It is the governed, versioned contract that defines UI meaning, semantics, and permitted actions. Renderers are adapters that translate the kernel’s outputs into native controls; they never own behavior, governance, or provenance.

## Why it exists

Renderers only stay “relatively simple” when the heavy logic lives in one place. Painting pixels, wiring layouts, and routing input against a declarative schema lets each platform reuse its own toolkit. The kernel owns the schema, the reconciler, and the action/runtime bridge that together keep the UI deterministic, governed, and auditable.

## Kernel components

- **Schema (UISchema):** Defines node type, stable ID, props, layout intent, semantics, bindings, and action descriptors (capability, provenance intent). Every node is a typed object; nothing is inferred from host widgets.
- **Reconciler:** Compares consecutive RenderTrees and emits patches (insert/move/update/remove). Given the same app state + schema + environment, it must produce the same tree and patch so behavior is testable and explainable.
- **Action Runtime:** Actions are structured requests carrying action ID, parameters, capability requirements, provenance metadata, rate limits, and optional UI context. The runtime enforces capability gates, logs denials, and dispatches approved work to Harmonia/Accessum flows.

## Kernel responsibilities

- **Meaning, not pixels:** The kernel owns layout intent, semantics, accessibility metadata, binding state, capability wiring, and provenance hooks. Renderers implement the pixel mapping.
- **Contracts and invariants:** Stable run IDs, capability declarations, audit trails, retention rules, and governance invariants live here. Every action must produce a trace, and replays validate hashes before any effects run.
- **Capability enforcement:** Missing capability is a hard denial. The kernel decides what runs. Renderers only request.
- **Provenance hooks:** Each ActionInvocation emits an event with actionId, nodeId, timestamp, build SHA, runId, actor identity, capability decision, and artifact pointers. These events feed Docs/status and audit logs.

## Interaction pattern

Input: AppModel snapshot, UISchema, Environment (platform traits, locale, accessibility settings, capabilities).  
Output: RenderTree (platform-agnostic nodes), AccessibilityTree, ActionSurface (capability-gated actions).  
Renderer: consumes these outputs, maps to SwiftUI/AppKit/WinUI/COSMIC controls, and routes user events back into the action runtime.

## Scope

The kernel keeps pixel plumbing away from governance. Phase 1 implementation should support text, stack layout, buttons, lists, and detail panels, with full action governance and provenance. Complex input, custom layout, and animation can arrive later when the schema and action contracts prove stable.

## Harmonia ownership

This belongs in Harmonia because Harmonia already owns truth, governance, and the ledger. The UI kernel feeds actions through Harmonia’s command surface, consumes state updates, and contributes to the same provenance trail that keeps jobs and transforms auditable. The renderer becomes a thin fiber, the kernel remains the real toolkit.

## Documentation & verification

Document the kernel’s supported schema version, node types, actions, and capability names. Validate those claims in CI using Docs/status artifacts so the UI surface is always aligned with the governance story.

## Research-worthy differentiator

The kernel is not just a portability abstraction. It’s where accessibility, governance, provenance, and replay become mechanical properties. That means:

- Every screen can be serialized, hashed, and diffed for drift.
- Every interaction produces a canonical, auditable event with capability gating.
- Every action logs denial details when policy refuses it.
- Every build records a “last verified” stamp that ties the doc claims to a commit SHA.

Composing those guarantees with the renderer boundary is what makes the approach research-worthy. Others (Flutter, Adaptive Cards, Compose Multiplatform, Avalonia) separate frameworks from engines, but Anigma fuses that separation with ledger-backed governance.

## How to document it

Write the kernel like a protocol: modules, inputs, outputs, invariants, renderer expectations, event log schema, verification gates. Keep the promises small and mechanically checkable. The docs stop being inspirational prose and become governing contracts.

## Native rendering trust

Platform-agnostic does not mean platform-indifferent. The kernel owns the truth—structure, semantics, actions—while renderers earn trust by translating intent into native affordances:

- **Interaction semantics:** Keyboard navigation, focus, text selection, IME, scroll physics, context menus, and accessibility should leverage native controls (hybrid renderers are often the sane default). The kernel requests actions; the renderer supplies the native plumbing.
- **Visual language:** Style tokens describe roles, not pixels. macOS maps to San Francisco + standard spacing; Windows maps to Segoe/Fluent density; COSMIC uses its theme. Same semantics, different skin.
- **Platform affordances:** Toolbar areas, command bars, share sheets, file pickers, and chrome placement remain renderer decisions. The kernel labels primary/secondary actions and capabilities; the renderer chooses how the platform surfaces them.

The counterproductive outcome is confusing “single source of truth” with “single look and feel.” Keep the truth centralized and let renderers behave like respectful guests on each platform, not jealous dictators. That keeps governance, accessibility, and maintainability intact while delivering native experiences.

## Platform perks belong to the host adapter

Anigma’s UI is “procedurally generated,” so you keep portability by splitting responsibilities: the kernel owns meaning, the renderer owns presentation, and the platform host owns perks (Keychain, DPAPI, share sheets, notifications, system prompts, biometric dialogs, background execution rules, etc.).

The kernel defines capability contracts (“I need SecretStore.write with non-exportable policy,” “this action requires user presence,” “request notification permission and log consent”) without naming platform APIs. Renderers act as dumb diplomats that forward those capability requests to platform host adapters and reflect the outcomes using native prompts and UI states.

Perks require three checks on every request:

1. **Availability** – does the OS provide the service (Keychain vs secret service vs capability-not-available)?
2. **Authorization** – does policy/user permission allow it (biometric denied, enterprise blocks export, requires user presence fails)?
3. **Provenance** – can the kernel explain what happened (capability requested, host adapter chosen, policy enforcement outcome) without leaking secrets?

Harmonia emits structured events for capability requests, grants/denials, and host implementations, tying them to runId and artifact hashes. That makes your docs truthful and the UI auditable.

Example: the kernel declares a SecretStore.write policy requiring non-exportable storage and user presence. Each platform adapter fulfills it using native services (Keychain access controls, DPAPI prompts, Android Keystore StrongBox, Secret Service) or returns CapabilityUnavailable when it cannot meet the policy. Renderers display native prompts/errors, while the kernel logs the capability result.

The renderer’s error vocabulary (CapabilityUnavailable, PermissionDenied, PolicyUnsatisfied, UserCancelled, TransientFailure, MisconfiguredHost) stays platform-agnostic, but the UI can show native dialogs with platform-specific phrasing. That keeps the kernel portable while making the experience native-feeling.

## Contracts that improve with age

A contract that outlives people and platforms is versioned, backwards-compatible, and explicit about semantics. Treat the UI kernel schema like a file format:

- **Version, never mutate meanings.** Add fields, deprecate slowly, and support older versions through adapters. A screen defined in schema `1.3` should still replay when the codebase lands at `1.6`.
- **Capabilities have deterministic semantics.** `SecretStore.write` must mean “non-exportable, user-presence enforced” everywhere. A platform that cannot meet the policy returns a predictable failure code instead of silently downgrading.
- **Provenance is first-class.** Log every capability request/resolve/deny with stable IDs (runId, schemaVersion, adapterVersion, actionId). That ledger is how future contributors debug behavior they didn’t write.
- **Docs/tests treat the contract as law.** Your docs gate validates schema versions, capability invariants, and artifact evidence so claims must line up with what the runtime emits. When the schema evolves, the CI gating that fail builds until adapters update prevents creeping drift.

This is the “time proof” part: stuck-in-platfrom-churn, data-migrated, team-rotus-resistant longevity. Replaceable renderers plus capability-based host adapters let the UI kernel age gracefully instead of rotting into haunted spaghetti.
