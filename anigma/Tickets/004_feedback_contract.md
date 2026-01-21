# Ticket 004 – Feedback Contract: UI Binding to `OperationResult`

**Title**: Implement UI feedback layer that consumes `OperationResult` progress events

**Description**:
- Provide a single reusable `OperationProgressView` that consumes `OperationResult` streams via Combine (no bespoke spinners).
- Display textual progress plus a bar; announce milestones/state transitions (throttled to meaningful deltas).
- Require all long-running UI flows to use this component for consistency and accessibility.

**Definition of Done**:
1. `OperationProgressView.swift` lives in `Sources/AnigmaAppMac/Components` and accepts an `OperationResult` publisher.
2. At least two workflows (PDF import and OCR) use the view with shared milestone semantics.
3. UI unit tests verify progress updates trigger view state changes and announcements are emitted at milestones.
4. Accessibility audit confirms VoiceOver announcements for progress changes and end states.

**Acceptance Criteria**:
- ✅ Progress is visible and updates in real time.
- ✅ No raw spinners without textual context.
- ✅ VoiceOver reads "Importing 25 percent" etc.

**Metrics**:
- UI tests coverage: 100 % of progress‑driven screens.
- Accessibility audit: 0 violations on progress announcements.

**References**:
- `priority_matrix.md` – Feedback principle (rank 3).
- `OperationResult` definition (Ticket 001).

---

*Ticket created automatically on 2026‑01‑07.*
