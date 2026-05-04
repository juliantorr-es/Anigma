# Misalignment Findings

| ID | Misaligned Assumption | Evidence | Impact | Severity | Recommended Follow-up TD |
|---|---|---|---|---|---|
| FIND-001 | PDFLayoutExtract depends on PDFNative directly in generic paths. | `explain-target PDFLayoutExtract` | Native linker leakage into generic Tier 2. | P1 | Isolate PDFNative behind Sidecar/Native boundary. |
| FIND-002 | Sidecar products conflated with target readiness. | `AnigmaDaemon` dependencies in `Package.swift`. | Readiness gates pass without actual product health. | P0 | Implement Sidecar Readiness Receipt. |
| FIND-003 | "Zero-copy" overclaims in MediaCore. | `rg "zero-copy" MediaCore` | Fragile performance assumptions. | P1 | Instrument MediaCore with Chunk Receipts. |
| FIND-004 | HardwareAuthority in AnigmaFoundation. | `explain-edge AnigmaFoundation HardwareAuthority` | Generic foundation pulls in Accelerate/MPS. | P1 | Extract HardwareContract to Tier 1. |
| FIND-005 | ECS terminology mismatch. | `rg "ECS" Packages` | Mixed usage of "ECS" and "Capsule". | P2 | Standardize on "ECS-inspired" terminology. |
