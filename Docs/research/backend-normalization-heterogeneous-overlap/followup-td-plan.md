# Follow-up TD Plan

1. **TD: Isolate PDFNative and HardwareAuthority behind Portable Contracts**
   - Goal: Break the direct dependency from `AnigmaFoundation` and `PDFLayoutExtract` to native linkers.
   - Status: Candidate

2. **TD: Implement Sidecar Readiness Receipt and Governance Gate**
   - Goal: Ensure `PDFSidecarExecutable` is healthy and version-compatible before starting daemon ingestion.
   - Status: Candidate

3. **TD: Instrument MediaCore and SaturationKit with Chunk Storage Receipts**
   - Goal: Downgrade overclaims to `copy_minimized` and prove zero-copy where it exists.
   - Status: Candidate

4. **TD: Standardize ECS-Inspired Runtime Terminology and Schemas**
   - Goal: Rename "Capsule" to "Component" where appropriate and align with `chunk-storage-receipt.schema.json`.
   - Status: Candidate
