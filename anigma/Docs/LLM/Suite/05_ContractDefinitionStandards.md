# 05: Contract Definition Standards: Implementation
- **Schema Hash**: Every contract (struct) must implement a unique `schemaHash`. This allows the `ArtifactStore` to detect breaking changes at runtime.
- **Envelope Pattern**: All data passed across binary boundaries (e.g., Sidecar IPC) must be encoded into an `Envelope` shape containing:
  - `contractId`
  - `version`
  - `payload` (opaque data)
  - `proof` (signature or hash validation)
