# Assumption Map

| Backend Normalization Assumption | Conflict with Heterogeneous Doctrine | Impact |
|---|---|---|
| Sidecars are standard executables. | Sidecars are **governed capabilities** with specific readiness and receipt requirements. | High: readiness logic might miss sidecar health. |
| Native executors are backend internals. | Native executors must be **isolated implementation targets** or sidecars. | High: native linker leakage into generic contracts. |
| BackendReadiness implies product readiness. | Target buildability does not prove **hardware product readiness**. | Medium: tests pass but runtime fails on GPU/ANE. |
| Zero-copy is a blanket architectural goal. | Zero-copy is a **proven claim** requiring instrumentation. | Critical: overclaiming performance leads to fragile logic. |
| Contracts can reside in implementation modules. | Contracts must be **portable targets** with zero native dependencies. | Critical: breaks cross-platform portability. |

## Detailed Analysis
The primary misalignment is the "internalization" of native logic within `AnigmaPipeline` and `AnigmaFoundation`. These modules have been treated as generic backend targets, but they increasingly pull in native shims and hardware authorities that should be isolated leaf executors.
