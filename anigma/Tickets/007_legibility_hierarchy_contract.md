# Ticket 007 – Legibility & Hierarchy Contract: Typography & Visual Structure

**Title**: Standardize Typography and Visual Hierarchy across all UI surfaces

**Description**:
- Audit all views in `Sources/AnigmaAppMac/Surfaces` for compliance with the Typography Contract:
    - Body text must use `Inter`.
    - Headings and Titles must use `Roboto`.
    - No ad-hoc `Font.system(size: ...)` calls; use `DesignTokens.Font` semantic levels.
- Re-factor `CompassView` and `ArtifactInspector` to use a clear visual hierarchy (Display > Title > Header > Body > Caption).
- Implement "Breadcrumb" and "Progress Stepper" components to reflect the system's structural hierarchy.
- Ensure log output in the Developer console uses the same tiered legibility rules.

**Definition of Done**:
1. Global search for `Font.system` outside of `DesignTokens` returns zero results.
2. `ArtifactInspector` uses at least 4 distinct hierarchy levels to organize metadata.
3. UI snapshot tests verify font family usage for core components.
4. VoiceOver heading navigation follows a logical tree structure (H1 -> H2 -> H3).

**Acceptance Criteria**:
- ✅ Consistency in font usage across app modes.
- ✅ Information density is managed through clear structural hierarchy.
- ✅ Accessible heading structure for screen readers.

**Metrics**:
- Typography compliance: 100% of text elements use Design Tokens.
- Feedback from design audit: No "floating" elements or orphaned labels.

**References**:
- Contract definition in `priority_matrix.md` (section 3 - Hierarchy & Legibility).
- Design tokens: `Sources/AnigmaAppMac/DesignSystem.swift`.

---

*Ticket created automatically on 2026-01-07.*
