# Ticket 010 – Alignment Contract: Grid-Based Layout & Data Concepts

**Title**: Implement unified grid alignment and domain-concept mapping

**Description**:
- Define a 12-column grid system in `DesignSystem.swift` for flexible but aligned layouts.
- Re-factor `CompassView` and `ProjectsView` to snap to the grid.
- Ensure "Alignment of Concepts":
    - Backend data models (`AnigmaSource`, `AnigmaJob`) must align conceptually with their visual representation.
    - Terminology in UI labels must match the terminology in the `ContractsCore` and domain logic.
- Implement "Anatomical Layouts" where information is placed in predictable locations based on its semantic role (e.g., Action buttons always bottom-right in cards).

**Definition of Done**:
1. Grid utility components (e.g., `BauhausHStack`, `BauhausVStack`) are used in 80% of layouts.
2. Terminology audit: labels in `Surfaces/*.swift` match `SpineObjects.swift` properties.
3. UI unit tests verify component positioning relative to the grid.
4. "Anatomical" consistency verified for top-3 most used views.

**Acceptance Criteria**:
- ✅ The UI feels structurally sound and organized.
- ✅ Data representations are intuitive and match domain models.
- ✅ Consistent placement of controls reduces cognitive load.

**Metrics**:
- Grid compliance rate: 80%+.
- Terminology mismatch count: 0.

**References**:
- Contract definition in `priority_matrix.md` (section 3 - Alignment).

---

*Ticket created automatically on 2026-01-07.*
