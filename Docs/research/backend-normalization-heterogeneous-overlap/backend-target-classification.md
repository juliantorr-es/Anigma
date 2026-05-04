# Backend Target Classification

| Target | Current Role | Correct Role | Tier | Native/Portable | Sidecar? | Readiness Lane | Misalignment |
|---|---|---|---|---|---|---|---|
| AnigmaPipeline | Generic Runtime | Governance Runtime | Tier 2 | Portable | No | Backend | Depends on LayoutEngineContracts (OK) and SaturationKit (Risky). |
| AnigmaFoundation | Generic Runtime | Substrate Runtime | Tier 2 | Portable | No | Backend | Depends on RendererBackendContracts (OK) and HardwareAuthority (Risky). |
| LayoutEngineContracts | Unknown | Portable Contract | Tier 1 | Portable | No | Contract | Correctly extracted to Tier 1. |
| PDFLayoutExtract | Unknown | Native Executor | Tier 2 | Native | No | Backend | Mixed native dependencies (PDFNative) with generic logic. |
| PDFNative | Unknown | Native Executor | Tier 3 | Native | No | Native | Should be a leaf dependency. |
| PDFSidecarClient | Unknown | Sidecar Client | Tier 2 | Portable | No | Sidecar | Good isolation. |
| PDFSidecarExecutable | Unknown | Sidecar Executable | N/A | Native | Yes | Sidecar | Should not be a direct dependency of generic targets. |
| LayoutEngineCapsule | Unknown | Native Executor | Tier 2 | Native | No | Native | High risk of native handle leakage. |
| RendererBackendContracts | Unknown | Portable Contract | Tier 1 | Portable | No | Contract | Correctly extracted. |
| ExecutionCore | Substrate | Governance Runtime | Tier 2 | Portable | No | Backend | Correctly holds evidence logic. |
