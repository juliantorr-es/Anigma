# Ticket 009 – Color Contract: Semantic Palette & Intentional Usage

**Title**: Migrate all UI surfaces to use semantic color tokens for intent and status

**Description**:
- Define a strict `SemanticPalette` in `DesignSystem.swift` that maps colors to roles:
    - Primary: `accent`
    - Destructive: `error`
    - Warning: `warning`
    - Success: `success`
    - Info: `running` / `info`
- Audit and replace all references to `Color.red`, `Color.blue`, etc., with semantic tokens.
- Ensure the Color Contract supports:
    - High-contrast modes.
    - Status-based state in `OperationResult` (e.g., failure = error color).
    - Importance-based hierarchy (dimmed for secondary, bright for primary).
- Add lint rules to prevent the use of `SwiftUI.Color` constants directly in views.

**Definition of Done**:
1. Global search for native SwiftUI color constants outside of `DesignSystem` returns zero results.
2. `ArtifactInspector` and `ActivityView` colors are derived entirely from `OperationResult` states.
3. Contrast audit passes for all semantic combinations.
4. Colorblind accessibility check passed for status indicators (using icons in addition to color).

**Acceptance Criteria**:
- ✅ Color is used intentionally to convey status or importance.
- ✅ The UI remains accessible to users with color vision deficiencies.
- ✅ Semantic roles are consistently applied across app modes.

**Metrics**:
- Color token coverage: 100%.
- Contrast audit pass rate: 100%.

**References**:
- Contract definition in `priority_matrix.md` (section 3 - Color).

---

*Ticket created automatically on 2026-01-07.*
