# Ticket 005 – Affordance Contract: Intent‑Clear Controls

**Title**: Standardize affordance for all interactive controls

**Description**:
- Define semantic SwiftUI button styles (`PrimaryButton`, `SecondaryButton`, `DestructiveButton`, `LinkButton`) in `Sources/AnigmaAppMac/Components/ButtonStyles.swift`.
- Each style conveys purpose visually *and semantically* (e.g., destructive role, primary default action).
- Document when to use each style; ban custom per-button modifier piles that recreate them.
- Refactor interactive elements in `Sources/AnigmaAppMac/Surfaces` to use these styles.
- UI tests verify correct style/role application based on action semantics.

**Definition of Done**:
1. Button style module exists and is imported wherever a button is used.
2. No raw `Button` with custom modifiers that duplicate the style logic.
3. Visual regression tests confirm the appearance of each button type.
4. VoiceOver announces the button’s purpose (e.g., "Delete" button reads as "Delete, destructive button").

**Acceptance Criteria**:
- ✅ All actionable UI elements use the standardized button styles.
- ✅ The visual affordance matches the intended action (primary, secondary, destructive).
- ✅ Accessibility labels include the button’s role.

**Metrics**:
- UI component lint violations: 0.
- Visual regression test pass rate: 100 %.
- Accessibility audit: no missing role announcements.

**References**:
- `priority_matrix.md` – Affordance principle (rank 4).
- Existing UI code: `Sources/AnigmaAppMac/Surfaces/*.swift`.

---

*Ticket created automatically on 2026‑01‑07.*
