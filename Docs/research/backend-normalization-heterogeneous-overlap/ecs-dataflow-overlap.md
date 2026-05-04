# Contract/Executor Boundary Map

| Capability | Contract Target | Executor Target | Native Dependencies | Current Leak? | Correct Boundary |
|---|---|---|---|---|---|
| Receipt Signing | EvidenceContracts | ReceiptSigner (Impl) | None | No | Correctly extracted. |
| Renderer | RendererBackendContracts | RendererKit (Impl) | None | No | Correctly extracted. |
| PDF Layout | LayoutEngineContracts | PDFLayoutExtract | PDFNative | **Yes** | PDFLayoutExtract leaks PDFNative into generic paths. |
| Hardware Auth | AnigmaPrimitives | HardwareAuthority | Accelerate, MPS | **Yes** | AnigmaFoundation pulls in HardwareAuthority directly. |
| ECS Storage | PipelineECS.swift | N/A | None | No | Currently just a Swift file, needs target. |
| Media Processing | MediaPipelineContracts | MediaCore | Metal, vDSP | **Yes** | MediaCore is a monolithic Tier 2 module. |

## Findings
The boundary between **portable contracts** and **native executors** is hardening but still porous in `PDFLayoutExtract` and `HardwareAuthority`. These executors are still being treated as "core libraries" rather than "optional native backends."
