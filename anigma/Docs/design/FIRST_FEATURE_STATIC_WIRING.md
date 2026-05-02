# First Feature Static Wiring Design

## Status
**Partial implementation; executable proof blocked** (2026-04-20)

## Context

This document describes the current static plugin wiring pattern used by Anigma. It matches the existing kernel/contracts implementation and the first working feature wiring target. It is not a dynamic plugin system; feature inclusion is static, explicit, and enforced by SwiftPM target boundaries.

## Design Goals

1. Keep `DaemonKernel` slim and contract-only.
2. Register features at compile time through `DaemonFeatureRegistrar`.
3. Make executable composition explicit and auditable.
4. Preserve boundary enforcement between kernel, contracts, and feature implementations.
5. Provide a repeatable pattern for future wiring targets.

## Current Architecture

```mermaid
graph TD
    Exec[Executable composition root] --> Kernel[DaemonKernel]
    Exec --> ModelWiring[ModelRegistryDaemonFeature]
    Kernel --> Contracts[DaemonFeatureContracts]
    ModelWiring --> Contracts
    ModelWiring --> ModelImpl[ModelRegistry]
    Kernel --> Registry[DaemonFeatureRegistry]
    Kernel --> Bootstrap[bootstrapKernel(_:with:)]
```

### Package graph

- `DaemonFeatureContracts` defines the registration contract and registry descriptors.
- `DaemonKernel` depends only on `DaemonFeatureContracts`.
- `ModelRegistryDaemonFeature` depends on `DaemonFeatureContracts` and `ModelRegistry`.
- The executable/composition root decides which wiring targets are linked.

This is the enforcement boundary described in the research and proof docs:
- `anigma/Docs/design/STATIC_PLUGIN_REGISTRATION_RESEARCH.md`
- `anigma/Docs/design/PLUGIN_BOUNDARY_ENFORCEMENT_RESEARCH.md`
- `anigma/Docs/root-docs/architecture/plugins.md`

## Concrete Roles

### `DaemonFeatureContracts`

The contracts package defines the shared static API:

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

Important invariant: this target contains contracts only; it does not import feature implementations.

### `DaemonKernel`

The kernel owns:

- lifecycle phase transitions
- feature registration orchestration
- dependency checks between registered feature IDs
- registry inspection APIs
- bootstrap flow via `bootstrapKernel(_:with:)`

Current kernel flow:

1. `start()` moves to `.registering`
2. `registerFeature(_:)` validates dependencies and invokes the registrar
3. `finishRegistration()` seals registration and moves to `.ready`
4. `run()` transitions to `.running`
5. `shutdown()` transitions to `.stopped`

The kernel does **not** import feature implementation modules.

### `ModelRegistryDaemonFeature`

The first wiring target demonstrates the pattern:

- imports `DaemonFeatureContracts`
- imports `ModelRegistry`
- implements `DaemonFeatureRegistrar`
- registers `model-query` and `model-load` workers
- registers the `model-management` capability

This is the template for future feature wiring targets.

## Registration Flow

```mermaid
graph TD
    A[Executable composition] --> B[bootstrapKernel]
    B --> C[DaemonKernel.start]
    C --> D[registerFeature]
    D --> E[DaemonFeatureRegistrar.register(into:)]
    E --> F[DaemonFeatureRegistry]
    D --> G[Feature manifest recorded]
    D --> H[Dependency validation]
    C --> I[finishRegistration]
    I --> J[run]
```

The key point is that registration is explicit and statically linked. There is no runtime discovery or dynamic loading step.

## Boundary Policy

The doc should stay consistent with these rules:

- kernel targets depend on contracts only
- wiring targets import contracts plus their feature implementation
- reusable core targets do not import feature modules directly
- executable targets own feature selection
- compiler and SwiftPM dependencies enforce the split

Do not describe this architecture as a plugin loader, module scanner, or `.dylib` system.

## First Feature Reference

Current `ModelRegistryDaemonFeature` wiring registers:

- `model-query` worker
- `model-load` worker
- `model-management` capability

That aligns with the current registry surface in `DaemonFeatureContracts` and the kernel bootstrap path in `DaemonKernel`.

## Current Validation Status

What is proven in the current repo:

- `DaemonKernel` imports `DaemonFeatureContracts`, not feature implementations.
- `ModelRegistryDaemonFeature` imports `DaemonFeatureContracts` plus `ModelRegistry`.
- `AnigmaDaemon.swift` bootstraps the kernel with `ModelRegistryDaemonFeature.self` and `DaemonStatusDaemonFeature.self`.
- `DaemonKernelTests/testBootstrapRegistersExplicitFeatureWiringTargets` exercises the static registration path and inspects registered features, routes, and capabilities.

Current blocker:

- `Package.swift` still comments out the SwiftPM `AnigmaDaemon` executable/product wiring.
- Focused `swift build --package-path anigma --target AnigmaDaemon` therefore fails with `error: no target named 'AnigmaDaemon'`.

Interpretation:

- The first static wiring slice exists in source and test coverage.
- Full task acceptance remains blocked until the executable composition root is restored in the active SwiftPM manifest and can be validated directly.

## Cross-References

- Research: `STATIC_PLUGIN_REGISTRATION_RESEARCH.md`
- Boundary proof: `PLUGIN_BOUNDARY_ENFORCEMENT_RESEARCH.md`
- Stabilization guide: `anigma/Docs/guides/STATIC_PLUGIN_ARCHITECTURE_STABILIZATION.md`
- Architecture overview: `anigma/Docs/root-docs/architecture/plugins.md`
- Kernel implementation: `anigma/Packages/DaemonKernel/Sources/DaemonKernel/DaemonKernel.swift`
- Contracts implementation: `anigma/Packages/DaemonFeatureContracts/Sources/DaemonFeatureContracts/DaemonFeatureContracts.swift`
- First wiring target: `anigma/Packages/ModelRegistryDaemonFeature/Sources/ModelRegistryDaemonFeature/ModelRegistryDaemonFeature.swift`

## Next Steps

1. Restore the active SwiftPM `AnigmaDaemon` executable target/product wiring.
2. Re-run focused build validation against `AnigmaDaemon`.
3. Keep this design aligned with the contracts package as additional wiring targets are added.
4. Extend the pattern only through new static wiring modules.
