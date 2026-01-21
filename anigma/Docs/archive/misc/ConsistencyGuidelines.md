# Consistency Guidelines (Design Tokens & Error Schema)

- Use the shared Bauhaus tokens for color, spacing, and typography (`Bauhaus.Color.*`, `Bauhaus.Grid.*`, `Bauhaus.Font.*`). Avoid raw `.system` fonts, hex colors, or ad-hoc spacing values.
- Prefer semantic roles (`accentHighContrast`, `errorHighContrast`, `textHighContrast`, `border`) instead of primitive colors for status/attention.
- Components must surface async state using the shared `OperationResult` envelope; errors should be expressed as `AnigmaError` (no raw string errors).
- Do not introduce new palette values directly in views—extend `DesignSystem.swift` if a new semantic token is needed.
- Tests should fail if surfaces include hard-coded system fonts or raw platform colors; keep UI code lint-clean.
- Keep token usage consistent in previews and empty states to avoid drift between flows.
