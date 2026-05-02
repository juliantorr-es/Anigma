# Ticket 003 – Consistency Contract: Design Tokens & Error Schema

**Title**: Enforce Consistency across UI components and backend error handling

**Description**:
- Use a semantic design system (colors/spacing/typography) from a shared tokens module (e.g., `DesignSystem`) across all SwiftUI views; no ad‑hoc literals.
- Define and reuse the shared `AnigmaError` / `OperationResult` contracts across app/daemon/workflows; no raw string errors.
- Add lint rules to block hard‑coded colors/fonts/spacing and raw string errors (`anigma_error_schema`).

**Definition of Done**:
1. Design system/tokens module exists and is imported by every view in `Sources/AnigmaAppMac/Surfaces`.
2. No view contains hard‑coded color hex values, font sizes, or spacing constants; uses semantic tokens.
3. All public APIs use `AnigmaError`/`OperationResult` (no raw string errors).
4. Lint passes with zero violations for error schema and token usage.
5. Unit tests verify a sample view renders using the token palette.

**Acceptance Criteria**:
- ✅ UI components share a single source of truth for visual styling.
- ✅ Backend errors are typed and documented.
- ✅ Linting enforces the rule.

**Metrics**:
- Lint violations: 0.
- Code coverage for token usage: ≥ 90 %.
- Documentation updated in `Docs/ConsistencyGuidelines.md`.

**References**:
- Contract definition in `priority_matrix.md` (section 1 & 4).
- Design system in `Sources/AnigmaAppMac/DesignSystem.swift`.
- Shared contracts module containing `AnigmaError` / `OperationResult`.

---

*Ticket created automatically on 2026‑01‑07.*
