# Materialization and Copy Claims

| Flow / Claim | Current Claim | Correct Claim | Evidence Needed | Risk | Classification |
|---|---|---|---|---|---|
| MediaCore zero-copy flow | zero-copy | **copy-minimized** | `MaterializationGate` receipt | High | Architecture intention |
| UMABufferPool transfer | zero-copy | **zero_copy_proven** | `allocator_receipt` | Low | Proven by doctrine |
| PDF Sidecar IPC | zero-copy | **sidecar_transfer** | IPC receipt | Medium | Overclaim |
| SaturationKit dispatcher | zero-copy | **copy-minimized** | Executor receipt | Medium | Stale assumption |
| Binary Atlas mapping | zero-copy | **no_copy_wrap** | `mmap` receipt | Low | Supported by source |

## Audit Summary
"Zero-copy" is currently used as a marketing/architectural term rather than a technical claim backed by evidence. The move to **CHUNK_STORAGE_RECEIPT_DOCTRINE** will force these to be downgraded to `copy_minimized` or `unknown` until instrumentation is added.
