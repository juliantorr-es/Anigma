# Daemon Static Feature Registration Contracts

**Status:** Active Design  
**Issue:** `td-a99725`  
**Date:** 2026-04-20  

## Goal

Document actual minimal contracts for static daemon feature registration. Make current coverage and gaps explicit.

Acceptance focus:

1. feature descriptors
2. worker / route / tool / capability descriptors
3. schema / workflow registration stance
4. dependency metadata
5. parity validation shape
6. operator inspection
7. package-graph impact

This doc is repo-backed evidence/spec, not claim that all future registration surfaces already exist.

## Repo-Backed Current Contract Surface

Current contract target:

- `DaemonFeatureContracts`

Current kernel target:

- `DaemonKernel`

Current wiring/example targets:

- `ModelRegistryDaemonFeature`
- `DaemonStatusDaemonFeature`

Current composition root evidence:

- `AnigmaDaemon`

## Minimal Contracts Present Today

### 1. Feature Descriptor

Current descriptor is protocol-based:

```swift
public protocol DaemonFeatureRegistrar: Sendable {
    static var featureID: FeatureID { get }
    static var dependencies: [FeatureID] { get }
    static func register(into registry: inout DaemonFeatureRegistry) throws
}
```

Meaning:

- `featureID` = stable registration identifier
- `dependencies` = feature ordering metadata
- `register(into:)` = compile-time registration hook

Current judgment:

- enough for first wiring proof
- still narrow
- no explicit version/schema/workflow parity metadata yet

### 2. Worker Registration

Present:

```swift
public struct WorkerRegistration: Sendable {
    public let kind: String
    public let factory: @Sendable () -> any JobWorker
}
```

Registry API:

```swift
registerWorker(kind:factory:)
```

Current coverage:

- yes for worker registration
- yes for factory-based dispatch

### 3. Route Registration

Present:

```swift
public struct RouteRegistration: Sendable {
    public let path: String
    public let method: String
    public let handler: @Sendable (RouteRequest) async throws -> RouteResponse
}
```

Registry API:

```swift
registerRoute(path:method:handler:)
```

Current coverage:

- yes for route registration
- enough for static route wiring proof

### 4. Tool Registration

Present:

```swift
public struct ToolRegistration: Sendable {
    public let toolID: String
    public let definition: ToolDefinition
}
```

Registry API:

```swift
registerTool(toolID:definition:)
```

Current coverage:

- descriptor exists
- registry path exists
- no current repo-backed wiring example observed in sampled feature targets

### 5. Capability Registration

Present:

```swift
public struct CapabilityRegistration: Sendable {
    public let capabilityID: String
    public let metadata: CapabilityMetadata
}
```

Registry API:

```swift
registerCapability(capabilityID:metadata:)
```

Current coverage:

- descriptor exists
- registry path exists
- used by both sampled wiring targets

### 6. Operator Inspection

Present on `DaemonFeatureRegistry` and `DaemonKernel`:

- `inspectFeatures()`
- `listWorkerKinds()`
- `listRoutes()`
- `listToolIDs()`
- `listCapabilityIDs()`
- kernel passthroughs for feature/worker/route/tool/capability listing

Current coverage:

- yes for basic operator inspection
- enough to inspect registered features and missing dependency failures at runtime

## Current Wiring Evidence

### ModelRegistryDaemonFeature

Repo evidence:

- imports `DaemonFeatureContracts`
- imports `ModelRegistry`
- implements `DaemonFeatureRegistrar`
- registers:
  - workers: `model-query`, `model-load`
  - capability: `model-management`

Why it matters:

- proves kernel does not import feature implementation
- proves wiring target can import implementation + contracts

### DaemonStatusDaemonFeature

Repo evidence:

- imports `DaemonFeatureContracts`
- implements `DaemonFeatureRegistrar`
- registers:
  - capability: `daemon-status`
  - route: `GET /daemon/kernel-status`

Why it matters:

- proves route + capability registration path
- provides smaller non-database example

### AnigmaDaemon composition root

Repo evidence:

- imports `DaemonKernel`
- imports wiring targets
- bootstraps kernel with explicit feature list:
  - `ModelRegistryDaemonFeature.self`
  - `DaemonStatusDaemonFeature.self`

Why it matters:

- proves executable composition root owns final feature selection
- kernel remains contract-only

## Dependency Metadata

Current dependency metadata is:

- per-feature `dependencies: [FeatureID]`

Current enforcement:

- `DaemonKernel.registerFeature` checks that all declared dependencies are already registered
- missing dependency throws `KernelError.missingDependency`

Current gaps:

- no dependency-cycle detection across registrar list
- no optional/soft dependency model
- no explicit dependency capability typing

## Feature Manifest And Parity

Present:

```swift
public struct FeatureManifest: Sendable {
    public let featureID: FeatureID
    public let workers: [String: WorkerRegistration]
    public let routes: [RouteRegistration]
    public let tools: [String: ToolRegistration]
    public let capabilities: [String: CapabilityRegistration]
}
```

But current kernel behavior records only:

```swift
FeatureManifest(featureID: feature.featureID)
```

Meaning:

- manifest shape exists
- parity recording is incomplete
- registry remains source of truth for registered items
- per-feature manifest does not yet capture full worker/route/tool/capability sets

## Schema / Workflow Registration Status

Current contract surface does **not** expose dedicated schema registration or workflow registration descriptors.

Current judgment:

- acceptance not fully satisfied for schema/workflow registration
- nearest current equivalent = workers + tools + capabilities

Next contract additions, if task scope later expands:

- `SchemaRegistration`
- `WorkflowRegistration`
- maybe `HealthCheckRegistration`

These should stay contract-only and avoid importing implementation/runtime-heavy types.

## Forbidden Contract Imports

For `DaemonFeatureContracts`, avoid:

- feature implementation targets
- database implementation targets
- UI targets
- ML/runtime-heavy packages

Current repo evidence:

- `DaemonFeatureContracts` imports only `Foundation`
- package target has no dependencies

For `DaemonKernel`, allow:

- `DaemonFeatureContracts`
- minimal kernel-safe utilities only

Current repo evidence:

- `DaemonKernel` depends only on `DaemonFeatureContracts`
- source imports only `Foundation`, `DaemonFeatureContracts`

## Package-Graph Impact

Current before/after shape, repo-backed:

- broad historical `AnigmaDaemonCore` mega-target remains commented out in `Package.swift`
- narrow kernel/wiring split exists now
- wiring target imports implementation
- kernel does not

Impact:

- compile surface shrinks at kernel boundary
- composition root explicitly chooses linked features
- reusable kernel avoids feature import fan-out

## Contract Inventory Summary

### Fully present now

- feature ID
- dependency metadata
- worker registration
- route registration
- tool registration descriptor
- capability registration
- operator inspection lists
- missing-dependency error path

### Partially present now

- feature manifest parity recording

Reason:

- manifest type exists
- current recording path stores only `featureID`

### Missing now

- schema registration contract
- workflow registration contract
- explicit parity validation helper
- per-feature complete manifest capture

## Parity Validation Design

Minimal next-step parity validation:

1. during `register(into:)`, collect delta before/after registry mutation
2. build `FeatureManifest` from actual delta
3. record manifest with workers/routes/tools/capabilities populated
4. expose kernel check:

```text
registered feature count
registered feature manifests
missing declared deps
duplicate worker/tool/capability IDs
```

Useful failure modes:

- duplicate worker kind
- duplicate tool ID
- duplicate capability ID
- feature declared but empty registration where non-empty expected

## Acceptance Mapping

### feature descriptors

Met:
- `DaemonFeatureRegistrar`
- `FeatureID`
- dependency metadata

### worker / route / tool / capability descriptors

Met:
- present in contracts + registry APIs

### schema / workflow registration

Not yet met fully:
- no dedicated descriptors in current contracts

### dependency metadata

Met:
- `dependencies: [FeatureID]`

### parity validation

Partial:
- missing-dependency check exists
- complete per-feature manifest parity not yet implemented

### operator inspection

Met:
- registry and kernel inspection APIs exist

### package-graph impact documented

Met:
- kernel/contracts narrow
- wiring target imports implementation
- executable composition root imports wiring targets

## Next Step

Follow-on implementation task should:

1. complete per-feature manifest recording
2. add schema/workflow registration only if real backend features require them
3. add duplicate-registration parity checks
4. wire kernel-boundary/package-graph checks into automated enforcement
