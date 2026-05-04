# Executable/Sidecar Map

| Executable/Product | Role | Correct Readiness Lane | Native Dependencies | Optional/Required | Product Readiness Status |
|---|---|---|---|---|---|
| PDFSidecarExecutable | Sidecar Executable | Sidecar / PDF | PDFNative, PDFium | Optional | Unknown |
| anigmad (AnigmaDaemon) | App Entrypoint | Daemon | Storage, Evidence | Required | Verified |
| harmonia (HarmoniaV2CLI) | CLI Entrypoint | CLI | Core, Contracts | Required | Verified |
| anigma-mcp (AnigmaMCPExecutable) | Sidecar Executable | Sidecar / MCP | Sidecar Client | Optional | Verified |
| BackendReadinessContractTests | Test Helper | Test | AnigmaCore | Required | Verified |

## Sidecar Assumption Conflict
Consolidation assumed that adding `PDFSidecarExecutable` to `AnigmaDaemon`'s dependencies was sufficient for "readiness." However, under the new doctrine, this product requires a **Sidecar Readiness Receipt** at runtime, which is not yet implemented.
