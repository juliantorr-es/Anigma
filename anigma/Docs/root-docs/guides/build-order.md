# Fixing Build Order Issues in Anigma

## Problem Analysis

The build is failing because Swift Package Manager is attempting to build application-level targets before core dependency modules are available. While the `dependencies` parameter in target definitions specifies what each target needs, SPM doesn't always respect this order during the initial build phase.

## Solution: Enforce Build Order

### Option 1: Create a Build Order Target (Recommended)

Create a special target that depends on all core modules first, then create application targets that depend on this build order target.

#### Step 1: Add a BuildOrder target to Package.swift

Add this target to the `coreTargets` array (around line 555):

```swift
// Add this near the beginning of coreTargets
.target(
    name: "BuildOrder",
    dependencies: [
        // Core infrastructure - MUST be built first
        "AnigmaFoundation",
        "AnigmaPrimitives",
        "AnigmaNativeShims",
        "NativeKernel",
        "ContractsCore",
        "CapsuleCore",
        "DatabaseCore",
        "GovernanceCore",
        "StorageCore",
        "InferenceCore",
        "SecurityEventsManager",
        "TelemetryCore",
        "ExecutionCore",
        "AnigmaEvents",
        
        // Native modules
        "PDFNative",
        "LayoutEngineNative",
        "TextChunkingNative",
        "VectorStoreNative",
        "SyntaxNative",
        "MarkdownNative",
        "CompressionNative",
        "VizAggregationNative",
        "MediaFingerprintNative",
        "MediaContainerNative",
        "VectorNative",
        "TextPipelineNative",
        "VectorIndexNative",
        "CosineNative",
        "RankFusionNative",
        "SceneGraphNative",
        "HitTestNative",
        "RenderPlanNative",
        "AnimationNative",
        "GeometryNative",
        "TableExtractionNative",
        "MathOCRNative",
        "CitationExtractionNative",
        "ReferenceResolutionNative",
        "DiffNative",
        
        // Capsule modules
        "PDFCapsule",
        "SyntaxCapsule",
        "MarkdownCapsule",
        "CompressionKit",
        "VizAggregationCapsule",
        "MediaFingerprintCapsule",
        "MediaContainerCapsule",
        "VectorCapsule",
        "TextPipelineCapsule",
        "VectorIndexCapsule",
        "CosineSimilarityCapsule",
        "RankFusionCapsule",
        "SceneGraphCapsule",
        "HitTestCapsule",
        "RenderPlanCapsule",
        "AnimationKit",
        "GeometryCapsule",
        "TextChunkingCapsule",
        "LayoutEngineCapsule",
        "VectorStoreCapsule",
        "TableExtractionCapsule",
        "MathOCRCapsule",
        "CitationExtractionCapsule",
        "ReferenceResolutionCapsule",
        "DiffCapsule",
        
        // Core application modules
        "AnigmaCore",
        "CapabilityCore",
        "DoctrineCore",
        "DataCore",
        "DataEngine",
        "RendererKit",
        "MLWorkerCommon",
        "ModelRegistry",
    ],
    path: "Packages/BuildOrder",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
),
```

#### Step 2: Create the BuildOrder package

Create a minimal package at `Packages/BuildOrder`:

```bash
mkdir -p /anigma/Packages/BuildOrder/Sources/BuildOrder
```

Create `Packages/BuildOrder/Sources/BuildOrder/BuildOrder.swift`:

```swift
// BuildOrder.swift
// This package ensures all core dependencies are built before application targets

public struct BuildOrder {
    public static let version = "1.0.0"
    
    public init() {}
}
```

#### Step 3: Update Application Targets to Depend on BuildOrder

Modify the failing targets to depend on BuildOrder:

```swift
// Find these targets and add "BuildOrder" to their dependencies
.target(name: "outlineum-zine", dependencies: ["BuildOrder", "AnigmaCore", ...]),
.target(name: "ml-worker", dependencies: ["BuildOrder", "MLWorkerCommon", ...]),
.target(name: "harmonia-surface", dependencies: ["BuildOrder", "AnigmaCore", ...]),
.target(name: "harmonia", dependencies: ["BuildOrder", "AnigmaCLICore", ...]),
```

### Option 2: Build Targets Incrementally (Manual Approach)

If you don't want to modify Package.swift, build targets manually in the correct order:

```bash
# Step 1: Build core infrastructure
swift build --target AnigmaFoundation
swift build --target AnigmaPrimitives
swift build --target AnigmaNativeShims
swift build --target NativeKernel

# Step 2: Build core modules
swift build --target ContractsCore
swift build --target CapsuleCore
swift build --target DatabaseCore
swift build --target GovernanceCore
swift build --target StorageCore
swift build --target InferenceCore
swift build --target SecurityEventsManager
swift build --target TelemetryCore
swift build --target ExecutionCore
swift build --target AnigmaEvents

# Step 3: Build native modules
swift build --target PDFNative
swift build --target LayoutEngineNative
swift build --target TextChunkingNative
swift build --target VectorStoreNative

# Step 4: Build capsule modules
swift build --target PDFCapsule
swift build --target SyntaxCapsule
swift build --target MarkdownCapsule
swift build --target TextChunkingCapsule
swift build --target LayoutEngineCapsule
swift build --target VectorStoreCapsule

# Step 5: Build AnigmaCore
swift build --target AnigmaCore

# Step 6: Build application targets
swift build --target outlineum-zine
swift build --target ml-worker
swift build --target harmonia-surface
swift build --target harmonia
```

### Option 3: Use Xcode Workspace (Alternative Approach)

Xcode often handles complex dependency graphs better than SPM command line:

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open /anigma/.swiftpm/xcode/project.xcworkspace

# Build in Xcode
# Xcode will handle build order automatically based on dependencies
```

## Why This Works

1. **BuildOrder Target**: By creating a target that explicitly depends on all core modules, SPM is forced to build them first
2. **Dependency Chain**: Application targets then depend on BuildOrder, ensuring they're built after all dependencies
3. **Explicit Order**: This makes the build order explicit in the package configuration

## Additional Recommendations

### 1. Create a Build Script

Create a script to automate the incremental build process:

```bash
#!/bin/bash
# build_incremental.sh

set -e

echo "Building Anigma incrementally..."

# Core infrastructure
echo "\n=== Building Core Infrastructure ==="
swift build --target AnigmaFoundation
swift build --target AnigmaPrimitives
swift build --target AnigmaNativeShims
swift build --target NativeKernel

# Core modules
echo "\n=== Building Core Modules ==="
swift build --target ContractsCore
swift build --target CapsuleCore
swift build --target DatabaseCore
swift build --target GovernanceCore
swift build --target StorageCore
swift build --target InferenceCore
swift build --target SecurityEventsManager
swift build --target TelemetryCore
swift build --target ExecutionCore
swift build --target AnigmaEvents

# Native modules
echo "\n=== Building Native Modules ==="
swift build --target PDFNative
swift build --target LayoutEngineNative
swift build --target TextChunkingNative
swift build --target VectorStoreNative

# Capsule modules
echo "\n=== Building Capsule Modules ==="
swift build --target PDFCapsule
swift build --target SyntaxCapsule
swift build --target MarkdownCapsule
swift build --target TextChunkingCapsule
swift build --target LayoutEngineCapsule
swift build --target VectorStoreCapsule

# AnigmaCore
echo "\n=== Building AnigmaCore ==="
swift build --target AnigmaCore

# Application targets
echo "\n=== Building Application Targets ==="
swift build --target outlineum-zine
swift build --target ml-worker
swift build --target harmonia-surface
swift build --target harmonia

echo "\n=== Build Complete ==="
```

### 2. Add Build Order Validation

Add a pre-build validation step to your CI/CD pipeline:

```bash
#!/bin/bash
# validate_build_order.sh

echo "Validating build order..."

# Check if all required targets exist
REQUIRED_TARGETS=(
    "AnigmaFoundation"
    "AnigmaPrimitives"
    "ContractsCore"
    "CapsuleCore"
    "DatabaseCore"
    "AnigmaCore"
)

for target in "${REQUIRED_TARGETS[@]}"; do
    if ! swift build --target "$target" --show-dependencies > /dev/null 2>&1; then
        echo "ERROR: Target $target has dependency issues"
        exit 1
    fi
done

echo "Build order validation passed"
```

## Monitoring and Maintenance

### 1. Track Dependency Changes

When adding new targets, always:
1. Add them to the BuildOrder dependencies
2. Test the build order
3. Update build scripts

### 2. Visualize Dependency Graph

Create a dependency visualization script:

```bash
#!/bin/bash
# visualize_dependencies.sh

# Generate dependency graph
swift build --show-dependencies > dependencies.txt

# Use Graphviz or similar to visualize
echo "Dependency graph generated in dependencies.txt"
```

### 3. Regular Build Order Testing

Add to your CI/CD pipeline:
```bash
# Test build order regularly
swift build --target BuildOrder
```

## Conclusion

The BuildOrder target approach (Option 1) is the most robust solution because:
- It makes build order explicit in the package configuration
- It leverages SPM's dependency resolution
- It's maintainable and scalable
- It works with both command-line and Xcode builds

The incremental build approach (Option 2) is useful for debugging but requires manual intervention.

The Xcode approach (Option 3) may work better for some projects but requires Xcode installation.
