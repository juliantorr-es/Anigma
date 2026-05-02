# 13: Testing & Verification: Methodology

## Focused Testing Protocol
To avoid test-bloat and fake progress, all changes must be verified against a filtered test subset:
- **Scope Filtering**: Run tests only for modified targets/dependent targets using `swift test --filter`.
- **Integration Proof**: Changes touching `MediaCore` or `AnigmaPipeline` MUST pass the `SaturationSubstrate` integration suite.

## Sanitizer Gating
- Sanitizer tests (`--sanitize=address,thread`) run at the end of every significant feature integration milestone.
- **Leak Detection**: The `ArtifactStore` must pass an `Allocations` profile baseline before marking any media pipeline PR as reviewable.
