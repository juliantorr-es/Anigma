# Circular Dependency Analysis

## Problem: "Multiple Producers" Build Errors

The build is failing with "multiple producers" errors for several modules:
- AnigmaAppMacExecutable
- AnigmaClientKit
- AnigmaDaemonCore
- HarmoniaModule
- ObservatoriumModule

These errors occur because Swift Package Manager detects circular dependencies in the module graph and tries to compile the same module multiple times simultaneously.

## Root Cause: Circular Dependency Chain

### Primary Circular Dependency

```
HarmoniaModule
  → AnigmaCLIOrchestrator (dependency)
    → AnigmaCLITUI (dependency)
      → HarmoniaModule (dependency)
```

**This creates a circular chain:** `HarmoniaModule → AnigmaCLIOrchestrator → AnigmaCLITUI → HarmoniaModule`

### How This Affects Other Modules

1. **AnigmaAppMacExecutable** depends on `HarmoniaModule`, which is part of the circular chain
2. **AnigmaClientKit** is used by `DataUI`, which is used by `AnigmaAppMacExecutable`
3. **AnigmaDaemonCore** depends on `HarmoniaModule`
4. **ObservatoriumModule** is used by various modules that depend on the circular chain

## Detailed Dependency Breakdown

### HarmoniaModule Dependencies (from Package.swift)
```swift
.target(name: "HarmoniaModule", dependencies: [
    "AnigmaCore", "ContractsCore", "AnigmaPrimitives", "CapabilityCore", "DatabaseCore", 
    "TelemetryCore", "ExecutionCore", "DoctrineCore", "SecurityEventsManager", 
    "AnigmaASTServicesCore", "MLWorkerCommon", 
    .product(name: "MLXEmbedders", package: "mlx-swift-lm"), 
    "CathedralModule", "StorageCore", "GovernedMigrationCore",
    "AnigmaCLIProviders", "AnigmaCLIRouter", "AnigmaCLIOrchestrator",  // ← Circular!
    "AnigmaCLIEventing", "AnigmaCLIGovernance", 
    .product(name: "GRDB", package: "GRDB.swift"), 
    "DataCore", "InferenceCore"
], ...)
```

### AnigmaCLIOrchestrator Dependencies
```swift
.target(name: "AnigmaCLIOrchestrator", dependencies: [
    "AnigmaCLICore", "AnigmaCLIEventing", "AnigmaCLIGovernance", 
    "AnigmaCLIProviders", "AnigmaCLIRouter"
], ...)
```

### AnigmaCLITUI Dependencies
```swift
.target(name: "AnigmaCLITUI", dependencies: [
    "AnigmaCLICore", "AnigmaCLIEventing", "AnigmaCLIDatabase", 
    "AnigmaCLIML", "HarmoniaModule",  // ← Circular!
    "AnigmaTUI", "AnigmaSidecar"
], ...)
```

## Why This Happens

When Swift Package Manager tries to build `HarmoniaModule`, it needs:
1. `AnigmaCLIOrchestrator`
2. `AnigmaCLITUI` (which depends on `AnigmaCLIOrchestrator`)
3. But `AnigmaCLITUI` also depends on `HarmoniaModule` itself!

This creates a deadlock where:
- Swift tries to build `HarmoniaModule`
- To build `HarmoniaModule`, it needs `AnigmaCLIOrchestrator`
- To build `AnigmaCLIOrchestrator`, it needs `AnigmaCLITUI`
- To build `AnigmaCLITUI`, it needs `HarmoniaModule` (which is still being built)

## Solutions

### Option 1: Break the Circular Dependency (Recommended)

Move the `HarmoniaModule` dependency from `AnigmaCLITUI` to a higher-level module that doesn't create a cycle.

**Changes needed:**
- Remove `HarmoniaModule` from `AnigmaCLITUI` dependencies
- Add it to `AnigmaAppMacExecutable` or `AnigmaCLIExecutable` instead
- Use protocol-oriented design or dependency injection to access HarmoniaModule functionality

### Option 2: Use `@_exported` Import (Swift-specific)

If the dependency is only for type sharing (not runtime), you can use:
```swift
.target(name: "AnigmaCLITUI", dependencies: [
    // ... other dependencies
], swiftSettings: [
    .unsafeFlags(["-Xfrontend", "-experimental-allow-module-with-same-name-as-dependency"])
])
```

However, this is not a clean solution and may cause other issues.

### Option 3: Refactor Shared Code

Extract the shared functionality between `HarmoniaModule` and `AnigmaCLITUI` into a separate module that both can depend on without creating a cycle.

### Option 4: Use Build Phases

Split the build into phases:
1. Build non-circular modules first
2. Build circular modules separately with proper ordering

This requires custom build scripts and is not ideal for SPM.

## Immediate Workaround

If you need to build the project despite the circular dependencies:

```bash
# Build specific targets that don't depend on the circular chain
cd anigma
swift build --product VectorStoreCapsule
swift build --product MediaContainerCapsule

# Or build with fewer jobs to reduce contention
swift build -j4
```

## Long-term Recommendation

**Break the circular dependency by removing `HarmoniaModule` from `AnigmaCLITUI` dependencies.**

The `AnigmaCLITUI` module should focus on terminal user interface concerns, while `HarmoniaModule` handles core workflow orchestration. These are separate concerns that shouldn't directly depend on each other.

If `AnigmaCLITUI` needs to interact with `HarmoniaModule`, use:
1. **Dependency Injection**: Pass HarmoniaModule services as parameters
2. **Event Bus**: Use the existing eventing system for cross-module communication
3. **Protocol Abstraction**: Define protocols in a shared module that both implement

## Verification

After making changes, verify the dependency graph is acyclic:

```bash
cd anigma
swift package show-dependencies --format text | grep -i "harmonia\|tui"
```

Or use a third-party tool like `SwiftPackageGraph` to visualize dependencies.
