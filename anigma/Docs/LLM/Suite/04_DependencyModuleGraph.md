# 04: Dependency & Module Graph: Technical Hardening

## Avoiding God-Modules
- **ContractsCore**: Currently an umbrella. The refactoring strategy mandates breaking this into `MediaPipelineContracts`, `EvidenceContracts`, `GovernanceContracts` as standalone entities.
- **@_exported**: The `Swift` compiler feature `@_exported` is treated as a high-risk security hazard. Any use outside Tier 1 requires explicit inclusion in the `Doctrine Authority` allowlist in `Scripts/validate_exported_imports.py`.

## Dependency Fan-Out Budget
- Each target has a soft "fan-out" limit of 15 imports.
- Targets exceeding this must demonstrate that the fan-out is constitutional, not implementation-leakage.
