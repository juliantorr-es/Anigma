# Follow-up TD Plan

> **Note**: The alignment diagnostic matrix for this research is now **generated evidence** produced by the `Scripts/anigma_package_graph_audit.py alignment-matrix` tool. Hand-written tables in these research docs are for initial mapping only; the generated JSON/CSV outputs in `.build/anigma-graph/current/` are the canonical sources for review.

1. **TD: Isolate PDFNative and HardwareAuthority behind Portable Contracts**
   - Goal: Break the direct dependency from `AnigmaFoundation` and `PDFLayoutExtract` to native linkers.
   - Status: Candidate

2. **TD: Implement Sidecar Readiness Receipt and Governance Gate**
   - Goal: Ensure `PDFSidecarExecutable` is healthy and version-compatible before starting daemon ingestion.
   - Status: **DONE** - td-7c0153-01 completed
   - Follow-up TDs created:
     - td-sidecar-anigma-readiness (AnigmaSidecar)
     - td-sidecar-office-readiness (SidecarOfficeService)
     - td-sidecar-pdf-service-readiness (SidecarPDFService library)
     - td-sidecar-translate-readiness (SidecarTranslateService)
     - td-alignment-matrix-sidecar-rule-refinement (matrix logic improvements)
   - See: `Docs/td/ready/td-sidecar-*` for individual sidecar readiness TDs

3. **TD: Instrument MediaCore and SaturationKit with Chunk Storage Receipts**
   - Goal: Downgrade overclaims to `copy_minimized` and prove zero-copy where it exists.
   - Status: Candidate

4. **TD: Standardize ECS-Inspired Runtime Terminology and Schemas**
   - Goal: Rename "Capsule" to "Component" where appropriate and align with `chunk-storage-receipt.schema.json`.
   - Status: Candidate
