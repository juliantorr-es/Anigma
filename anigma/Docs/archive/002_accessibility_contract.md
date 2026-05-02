# Ticket 002 – UI Surface Contract: Accessibility

**Title**: Enforce Accessibility Contract across UI components

**Description**:
- Audit all SwiftUI views in `Sources/AnigmaAppMac/Surfaces` for missing accessibility labels, hints, focus order, and keyboard reachability.
- Add `.accessibilityLabel` / `.accessibilityHint` and ensure every interactive element is reachable via keyboard.
- Integrate an accessibility audit (axe‑core/AXAudit) into CI for core flows (import → inbox → open artifact → run operation).
- Use high‑contrast tokens (`accentHighContrast`, `errorHighContrast`, `textHighContrast`) where needed to meet WCAG AA.
- Bind async state/progress to `OperationResult` and announce state changes via the shared `OperationProgressView` (Ticket 004).

**Findings & Mapping**:
- **OmniBar placeholder** – ensure localized, accessible placeholder and proper labels/hints.
- **Toast messages** – migrate to typed `ToastMessage` with accessibility metadata.
- **Async surfaces** – use `OperationProgressView` instead of custom spinners; announce milestones/state.
- **Buttons/controls** – add missing hints/labels across `Surfaces/*.swift`; mark decorative elements hidden.

**Definition of Done**:
1. All core screens (`CompassView`, `ArtifactListView`, `ArtifactInspector`, etc.) have explicit accessibility metadata.
2. No accessibility violations reported by the CI accessibility audit.
3. UI unit tests verify focus order/keyboard reach for at least one representative flow (e.g., opening an artifact).
4. Documentation in `Docs/AccessibilityGuidelines.md` is updated with current tokens/flows.

**Acceptance Criteria**:
- ✅ All interactive controls expose a non‑empty `accessibilityLabel`.
- ✅ Keyboard‑only navigation can reach every actionable element.
- ✅ Contrast ratios meet WCAG AA.
- ✅ VoiceOver announces state changes for async operations (using the `OperationResult` envelope).

**Metrics**:
- Accessibility audit pass rate: 100 % on CI.
- Manual spot‑check coverage: 100 % of core screens.

**References**:
- Contract definition in `priority_matrix.md` (section 1).
- Existing UI components: `Sources/AnigmaAppMac/Surfaces/*.swift`.

---

*Ticket created automatically on 2026‑01‑07.*
