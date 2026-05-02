# Accessibility Guidelines (UI Surface Contract)

- Every interactive control must expose a non-empty `accessibilityLabel` and, when helpful, an `accessibilityHint`.
- Ensure keyboard-only focus reaches all actionable elements; use `.accessibilityElement(children: .combine/.ignore)` to clarify focus targets.
- Use `OperationResult` progress/state to provide textual status updates for VoiceOver instead of spinners alone; prefer the shared `OperationProgressView` for async flows.
- Favor high-contrast tokens: `Bauhaus.Color.accentHighContrast`, `errorHighContrast`, and `textHighContrast` for critical states; maintain WCAG AA (≥ 4.5:1). Tint primary actions and progress indicators with high-contrast colors when status matters.
- Avoid decorative-only announcements: mark ornaments with `.accessibilityHidden(true)`.
- For text input, provide meaningful placeholders and labels; avoid relying on placeholder text alone.
- Add UI tests that assert focus order/keyboard reachability for at least one representative surface (e.g., Compass briefing tiles or Inbox list selection).
- Run automated AX checks in CI (axe-core or equivalent) and fix any violations before merging.
