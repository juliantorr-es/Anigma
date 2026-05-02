# Ticket 011 – Affordance Contract: Interaction Clarity & Feedback

**Title**: Implement clear affordances and instant feedback for all interactive elements

**Description**:
- Ensure all interactive elements (buttons, links, inputs) have clear visual states:
    - Default, Hover, Active, Disabled, Focus
- Implement instant feedback for all user actions:
    - Button press animations (scale/color shift)
    - Loading states for async operations
    - Success/error visual confirmation
- Standardize cursor behavior:
    - `pointer` for clickable elements
    - `text` for editable fields
    - `not-allowed` for disabled states
- Add haptic feedback where appropriate (macOS trackpad)

**Definition of Done**:
1. All buttons use standardized button styles from `ButtonStyles.swift`.
2. Every async action shows a loading state within 100ms.
3. Success/failure states are visually distinct and accessible.
4. Manual affordance audit passes for all primary workflows.

**Acceptance Criteria**:
- ✅ Users never wonder "is this clickable?"
- ✅ Every action provides immediate visual feedback.
- ✅ Disabled states are clearly distinguishable from enabled states.

**Metrics**:
- Button style coverage: 100%.
- Feedback delay: <100ms for all interactions.

**References**:
- Contract definition in `priority_matrix.md` (section 3 - Affordance).
- Button styles: `Components/ButtonStyles.swift`.

---

*Ticket created automatically on 2026-01-07.*
