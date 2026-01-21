# Ticket 001 – Implement Canonical `OperationResult` for PDF Import Workflow

**Title**: Implement `OperationResult` envelope for PDF Import job

**Description**:
- Define a canonical `OperationResult<ImportResult>` and `AnigmaError` in a shared contracts module (importable by app + daemon/workflow), not app‑local.
- Replace ad‑hoc results in the PDF import pipeline with this envelope; no raw strings.
- Emit `Progress` at real phase boundaries (0 % accepted, 25 % bytes read, 50 % parsed pages, 75 % OCR/index, 100 % committed).
- Map all error cases (file read, OCR timeout, indexing) to the stable `AnigmaError` taxonomy.
- UI consumes the envelope via the shared `OperationProgressView` (Ticket 004) with textual progress and VoiceOver state announcements.

**Definition of Done**:
1. `OperationResult` + `AnigmaError` live in a shared contracts target and are public.
2. PDF import workflow returns `OperationResult<ImportResult>` with the phase milestones above.
3. Unit test `PDFImportJobTests` verifies:
   - Codable round-trip.
   - Progress milestones emitted for jobs > 0.2 s.
   - Failure maps to `AnigmaError` code (e.g., `PDF_READ_ERROR`).
4. UI `PDFImportView` uses `OperationProgressView` and binds to the shared envelope.
5. Accessibility audit passes for the import UI (labels, VoiceOver announcements).
6. CI integration test runs sample import and asserts ≥ 1 progress update plus typed failure on error.

**Acceptance Criteria**:
- ✅ No raw `String` results remain in the PDF import code path.
- ✅ All error paths use `AnigmaError` and are covered by tests.
- ✅ UI updates are deterministic and announced to assistive tech.
- ✅ Linting (`SwiftLint`) passes with the new file.

**Metrics**:
- Coverage: 100 % of PDF import branches exercised.
- Accessibility: 0 violations on the import screen.
- Performance: p95 latency ≤ budget defined in `PerformanceBudgets.md` for `pdfImport`.

**References**:
- Contract definition in `priority_matrix.md` (section 2 & 4).
- Existing PDF import code: `Sources/AnigmaAppMac/Model/PDFImportJob.swift` (to be refactored).
- UI component: `Sources/AnigmaAppMac/Surfaces/PDFImportView.swift`.

---

*Ticket created automatically on 2026‑01‑07.*
