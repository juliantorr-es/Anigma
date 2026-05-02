# Daemon Kernel Boundary Specification

## Status
**Implementation-backed** (2026-04-17)

## Scope

This document defines the hard boundary for Anigma's daemon static-plugin architecture. It matches the current code and policy language:

- `DaemonKernel` is the slim kernel.
- `DaemonFeatureContracts` is the contracts-only surface.
- Wiring targets import contracts plus feature implementation.
- SwiftPM target dependencies are the primary enforcement mechanism.

This is **not** a dynamic plugin loader, module scanner, or `.dylib` system.

## Current Architecture

```mermaid
graph TD
    Exec[Executable composition root] --> Kernel[DaemonKernel]
    Exec --> Wiring[Feature wiring target]
    Kernel --> Contracts[DaemonFeatureContracts]
    Wiring --> Contracts
    Wiring --> Impl[Feature implementation target]
    Kernel --> Registry[DaemonFeatureRegistry]
    Kernel --> Bootstrap[bootstrapKernel(_:with:)]
```

### Roles

#### `DaemonFeatureContracts`

Contracts-only target. It defines:

- `FeatureID`
- `DaemonFeatureRegistrar`
- `WorkerRegistration`
- `RouteRegistration`
- `ToolRegistration`
- `CapabilityRegistration`
- `FeatureManifest`
- `DaemonFeatureRegistry`
- `JobWorker`, `JobInput`, `JobOutput`
- `RouteRequest`, `RouteResponse`
- `ToolDefinition`, `CapabilityMetadata`

It does **not** import feature implementations.

#### `DaemonKernel`

The kernel owns:

- lifecycle state
- feature registration orchestration
- dependency checks between feature IDs
- registry inspection
- bootstrap flow

It imports only:

```swift
import Foundation
import DaemonFeatureContracts
```

#### Feature wiring targets

Wiring targets bridge implementation into the kernel. Example:

- `ModelRegistryDaemonFeature`

They:

- import `DaemonFeatureContracts`
- import their feature implementation target
- implement `DaemonFeatureRegistrar`
- register workers, routes, tools, and capabilities

## Hard Boundary

SwiftPM target dependencies are the primary hard boundary.

### Evidence from `Package.swift`

```swift
.target(
    name: "DaemonFeatureContracts",
    dependencies: [],
    path: "Packages/DaemonFeatureContracts/Sources",
    swiftSettings: strictConcurrencySettings
)

.target(
    name: "DaemonKernel",
    dependencies: ["DaemonFeatureContracts"],
    path: "Packages/DaemonKernel/Sources",
    swiftSettings: strictConcurrencySettings
)

.target(
    name: "ModelRegistryDaemonFeature",
    dependencies: ["DaemonFeatureContracts", "ModelRegistry"],
    path: "Packages/ModelRegistryDaemonFeature/Sources",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
)
```

If a forbidden import is added to `DaemonKernel` or `DaemonFeatureContracts`, the build should fail.

## Forbidden Imports

### `DaemonKernel` must not import

- any feature implementation target
- any wiring target
- any broad daemon aggregator
- any dynamic plugin loader
- any `.dylib`/module scanning mechanism

Concrete examples already present in the repo and therefore forbidden here:

- `ModelRegistry`
- `ModelRegistryModule`
- `ModelRegistryDaemonFeature`
- `HarmoniaV2Surface`
- `HarmoniaModule`
- `RLMModule`
- `ContextumModule`
- `CathedralModule`
- `AnigmaAgents`
- `AnigmaMCPModule`
- `DataEngine`
- `VectorumModule`
- `ExportCore`
- `GRDB`
- `Hummingbird`
- `MCP`
- `swift-sdk`

### `DaemonFeatureContracts` must not import

- feature implementations
- wiring targets
- executable targets
- runtime or host adapters
- plugin loading APIs
- database/network/ML feature packages

Concrete examples forbidden on the contracts surface:

- `ModelRegistry`
- `ModelRegistryModule`
- `ModelRegistryDaemonFeature`
- `DaemonKernel`
- `HarmoniaV2Surface`
- `RLMModule`
- `ContextumModule`
- `AnigmaMCPModule`
- `GRDB`
- `Hummingbird`
- `MCP`

## Policy Alignment

This boundary matches the repo's dependency policy:

- core surfaces stay deterministic and narrow
- feature-rich implementation belongs outside core
- compiler and package graph enforcement are the first line of defense
- import bleed is treated as a policy violation, not an architectural preference

See:

- `anigma/Docs/governance/Dependency-Boundary-Policy.md`
- `anigma/Docs/guides/STATIC_PLUGIN_ARCHITECTURE_STABILIZATION.md`
- `anigma/Docs/design/STATIC_PLUGIN_REGISTRATION_RESEARCH.md`
- `anigma/Docs/design/PLUGIN_BOUNDARY_ENFORCEMENT_RESEARCH.md`
- `anigma/Docs/root-docs/architecture/plugins.md`

## Verification Notes

The current implementation already reflects this boundary:

- `DaemonKernel.swift` imports only `Foundation` and `DaemonFeatureContracts`
- `DaemonFeatureContracts.swift` contains contracts and registry descriptors only
- `bootstrapKernel(_:with:)` takes an explicit list of `DaemonFeatureRegistrar.Type`
- the executable composition root decides which wiring targets ship

## Conclusion

The daemon boundary is contract-driven and statically enforced. `DaemonKernel` remains slim, `DaemonFeatureContracts` remains contracts-only, and all feature implementation enters through explicit wiring targets.
