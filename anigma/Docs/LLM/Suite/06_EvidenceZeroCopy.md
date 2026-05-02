# 06: Evidence & Zero-Copy Proofs: Mechanics
- **ZeroCopyProof**: A struct capturing the `token`, `copiedBytes`, and `materializationReason`.
- **Materialization**: Occurs when a surface is copied (e.g., from ANE to GPU).
- **Proving Path**:
    1. Node receives `SurfaceToken`.
    2. Performs transformation.
    3. Emits `ZeroCopyProof` to `GovernanceLogger`.
- **Validation**: Any `copiedBytes > 0` triggers an audit event in the `LoggingRing`, alerting performance degradation lanes.
