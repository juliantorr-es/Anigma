# Anigma Design Principles – Contracts & Enforcement

**Purpose**: This document turns the top‑priority design principles from *Universal Principles of Design* into **system‑level contracts** that are verifiable by tests, CI, and governance. The contracts sit above feature work and below architecture, ensuring every UI surface and backend operation complies.

---

## 1️⃣ Definition of Done – Contract Packs

| Contract Pack | Scope | Core Principles (Rank 1‑10) | Enforcement |
|--------------|-------|---------------------------|-------------|
| **UI Surface Contract** | SwiftUI components, navigation, accessibility, visual hierarchy | Accessibility, Consistency, Feedback, Affordance, Legibility, Hierarchy, Aesthetic‑Usability, Color, Alignment, Contrast, Chunking | Automated accessibility audit (axe‑core), UI‑unit tests for focus order, snapshot tests for component tokens |
| **Backend Operation Contract** | Workflow runner, daemon jobs, tool invocations | Consistency (error/status schema), Feedback (progress streaming), Affordance (method naming), Performance, Legibility (log clarity), Hierarchy (layered architecture) | Unit tests for `OperationResult` schema, CI lint for error codes, integration tests for progress streams |

---

## 2️⃣ Canonical Operation Envelope

```swift
struct OperationResult<T: Codable>: Codable {
    enum State: String, Codable { case running, success, failure, cancelled }
    struct Progress: Codable { let percent: Double; let message: String? }
    struct Failure: Codable { let code: String; let message: String; let recoveryHint: String? }
    let id: UUID
    let kind: String               // e.g. "pdfImport", "ocr"
    let startTime: Date
    let endTime: Date?
    let state: State
    let payload: T?                // success payload
    let progress: Progress?
    let failure: Failure?
}
```

**Contract Rules**:
- Every async job must emit at least one `Progress` event if it runs longer than 0.2 s.
- End states are limited to `success`, `failure`, or `cancelled`.
- `Failure` must contain a stable `code` (from the **Error Code Taxonomy**) and a human‑readable `message`.
- The UI renders `state` and `progress` verbatim; VoiceOver announces changes automatically.

---

## 3️⃣ UI Surface Contract Details

1. **Accessibility**
   - All interactive views must have an explicit `.accessibilityLabel`.
   - Keyboard navigation must be possible for every focusable element.
   - Dynamic Type support and sufficient contrast (≥ 4.5:1) are mandatory.
2. **Consistency**
   - Use the shared `DesignTokens` palette, spacing, and typography.
   - All components come from the `AnigmaUI` library; no ad‑hoc styling.
3. **Feedback**
   - Bind UI to `OperationResult` streams; show textual progress, not just spinners.
   - VoiceOver must announce state transitions (`running → success`).
4. **Affordance & Hierarchy**
   - Buttons use `PrimaryButton`/`DestructiveButton` styles that convey intent.
   - Navigation hierarchy mirrors the layered architecture (UI → Domain → Infrastructure).
5. **Legibility & Color**
   - Font families are limited to `Inter` (body) and `Roboto` (titles).
   - Color usage follows the `BrandPalette` with semantic roles (error, success, info).

*All UI components are covered by unit‑tests that assert the presence of the above attributes.*

---

## 4️⃣ Backend Operation Contract Details

- **Error Schema** – All errors conform to:
  ```swift
  struct AnigmaError: Codable {
      let code: String   // from the taxonomy (e.g. "PDF_PARSE_TIMEOUT")
      let message: String
      let hint: String?
  }
  ```
- **Status Codes** – Use the unified `OperationResult` `state` field; never return raw strings.
- **Progress Streaming** – Jobs publish `OperationResult.Progress` via Combine publishers or async sequences.
- **Logging** – Logs must include the operation `id` and `kind`; log level follows the `LogLevel` enum (error > warn > info > debug).
- **Idempotency** – All public endpoints must be safe to retry; duplicate requests return the same `OperationResult`.

---

## 5️⃣ Enforcement Pipeline

| Stage | Check | Tool |
|-------|-------|------|
| **Compile‑time** | No raw `String` errors | SwiftLint rule `anigma_error_schema` |
| **Unit Tests** | `OperationResult` schema compliance | XCTest extensions `assertOperationValid` |
| **Integration** | Progress events emitted for long jobs | CI job runs a sample workflow and asserts ≥ 1 progress update |
| **Accessibility** | Contrast, labels, keyboard | `axe‑core` run in CI, fail on violations |
| **Performance** | Latency budgets per `kind` | Benchmark suite; fail if p95 > budget |

---

## 6️⃣ Ticket Templates (example)

**Title**: Implement `OperationResult` for `<JobName>`
**Description**:
- Add `OperationResult` wrapper to `<JobName>` output.
- Emit `Progress` every 10 %.
- Map existing errors to `AnigmaError` taxonomy.
**Definition of Done**:
- Unit test verifies schema compliance.
- CI integration test confirms progress streaming.
- UI component consuming this job displays textual progress and passes accessibility audit.

Create similar tickets for each principle in the top‑10 list.

---

## 7️⃣ Metrics Dashboard

| Metric | Target | Owner |
|--------|--------|-------|
| Accessibility audit pass rate | 100 % on core flows | UI team |
| Operations with progress events | ≥ 95 % of async jobs | Backend team |
| Error‑code coverage | 100 % of failures use `AnigmaError` taxonomy | Backend team |
| p95 latency per `kind` | ≤ budget (see `PerformanceBudgets.md`) | Performance squad |
| UI component token compliance | 0 lint violations | UI team |

---

## 8️⃣ Updated Priority Table (contract‑focused)

| Rank | Principle | Front‑End Contract | Back‑End Contract | ROI |
|------|-----------|-------------------|-------------------|-----|
| 1 | **Accessibility** | UI Surface Contract – labels, focus, contrast | Backend – error objects must be accessible to screen readers via `OperationResult` | High |
| 2 | **Consistency** | Shared `DesignTokens` & `AnigmaUI` library | Unified `OperationResult` & `AnigmaError` schema | High |
| 3 | **Feedback** | Bind UI to `OperationResult` progress streams | Emit `Progress` events for every long‑running job | High |
| 4 | **Affordance** | Button styles (`PrimaryButton`, `DestructiveButton`) convey intent | Method names reflect action semantics | High |
| 5 | **Performance** | UI latency budgets (≤ 100 ms interaction) | Operation latency budgets, scaling fallacy awareness | High |
| 6 | **Legibility** | `Inter`/`Roboto` fonts, clear hierarchy | Log messages include operation `id` and human‑readable messages | High |
| 7 | **Hierarchy** | Visual hierarchy mirrors layered architecture | Enforce layered architecture (UI → Domain → Infra) | High |
| 8 | **Aesthetic‑Usability** | `AnigmaUI` components provide polished look | Codebase follows Ockham’s Razor – no unnecessary complexity | Medium |
| 9 | **Color** | `BrandPalette` with semantic roles | Log level colors for console output | Medium |
|10| **Alignment** | Grid‑based layout via `DesignTokens.spacing` | Data models aligned with domain concepts | Medium |

*(Ranks 11‑125 remain as reference for future refinement.)*

---

## 9️⃣ Next Steps
1. **Create contract tickets** for each of the top‑10 principles using the template above.
2. **Add CI jobs** for the enforcement pipeline (accessibility, schema, progress).
3. **Populate `PerformanceBudgets.md`** with latency targets per operation kind.
4. **Review** the matrix with the team at the next sprint planning and lock the contracts.

*Document generated automatically on 2026‑01‑07.*
