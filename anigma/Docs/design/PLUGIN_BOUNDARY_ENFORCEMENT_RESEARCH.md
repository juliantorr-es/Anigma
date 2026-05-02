# Plugin Boundary Enforcement Research & Summary

**Date:** 2026-04-17  
**Task:** `research-plugin-boundary-enforcement`  
**Status:** Complete

## Executive Summary

Anigma already has practical boundary enforcement for the static plugin architecture. The daemon kernel depends only on contracts, the wiring target imports the feature implementation, and SwiftPM target dependencies enforce the split at build time. Broader dependency policy also constrains which packages may appear in core targets versus feature-rich targets.

## 1. Boundary Enforcement in the Static Plugin Architecture

### 1.1 Kernel Surface

`DaemonKernel` imports only `DaemonFeatureContracts` and does not import feature implementations.

Evidence:
- `DaemonKernel` owns lifecycle, registry, and bootstrap flow
- `DaemonKernel` depends only on `DaemonFeatureContracts`
- feature implementations are registered through `DaemonFeatureRegistrar`

### 1.2 Contracts Layer

`DaemonFeatureContracts` defines:
- `DaemonFeatureRegistrar`
- `DaemonFeatureRegistry`
- `WorkerRegistration`
- `RouteRegistration`
- `ToolRegistration`
- `CapabilityRegistration`
- `FeatureManifest`

This keeps the kernel contract-driven and avoids direct feature coupling.

### 1.3 Wiring Target Boundary

`ModelRegistryDaemonFeature` demonstrates the intended split:
- imports `DaemonFeatureContracts`
- imports `ModelRegistry`
- registers workers and capabilities through the registry
- is included explicitly by executable composition

That means the kernel never needs to know about `ModelRegistry` directly.

## 2. Enforcement Mechanisms Available Today

### 2.1 SwiftPM Target Dependencies

The package graph is the first enforcement layer:

```swift
.target(
    name: "DaemonKernel",
    dependencies: ["DaemonFeatureContracts"]
)

.target(
    name: "ModelRegistryDaemonFeature",
    dependencies: ["DaemonFeatureContracts", "ModelRegistry"]
)
```

If a forbidden import is added to the kernel target, the build fails.

### 2.2 Policy-Based Dependency Separation

`Dependency-Boundary-Policy.md` defines broader structural separation:
- core governance targets use vendored or tightly controlled dependencies
- capability targets may use richer external packages
- import bleed and database bypass are explicitly forbidden

This policy is a useful companion to the plugin boundary because it keeps the core layer predictable even as features expand.

### 2.3 Static Analysis and CI Checks

The current docs call for:
- dependency boundary verification scripts
- import boundary checks
- structural dependency audits
- version-range validation

## 3. Shared Vocabulary to Reuse

- `DaemonFeatureRegistrar`
- `DaemonFeatureRegistry`
- `FeatureID`
- `FeatureManifest`
- `WorkerRegistration`
- `RouteRegistration`
- `ToolRegistration`
- `CapabilityRegistration`

## 4. Design Implications

1. Keep the daemon kernel minimal and contract-only.
2. Put feature imports in wiring targets, not in reusable core.
3. Treat SwiftPM dependencies as the primary enforcement mechanism.
4. Use policy docs and CI checks to catch boundary drift beyond what the compiler can see.

## 5. Conclusion

The boundary is already enforceable enough to support the static plugin design. The main design task now is to preserve this split consistently across new features and avoid reintroducing feature imports into the kernel.

