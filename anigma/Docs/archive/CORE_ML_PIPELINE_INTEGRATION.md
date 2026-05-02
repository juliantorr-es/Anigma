# Core ML Pipeline Integration Guide

## Overview

The Core ML Pipeline has been successfully integrated into the Anigma architecture. This document provides guidance on using the new components.

## New Components Added

### 1. CoreMLConversionPipeline
**Location**: `Packages/ModelRegistry/Sources/CoreMLConversionPipeline.swift`
**Purpose**: Converts PyTorch models to Core ML format with deterministic execution and receipts
**Dependencies**: ModelRegistry, ContractsCore

### 2. ANECapsuleIntegration  
**Location**: `Packages/ANECapsuleIntegration/Sources/ANECapsuleIntegration/`
**Purpose**: Provides ANE-aware capsule execution with contract validation and placement verification
**Dependencies**: ANEServicesCore, CapsuleCore, ContractsCore, CapabilityCore

### 3. CoreMLArtifactContract
**Location**: `Packages/ContractsCore/CoreMLArtifactContract.swift`
**Purpose**: Defines SURFACE-style contracts for CoreML artifacts with 5-layer validation
**Dependencies**: ContractsCore (internal)

## Package.swift Updates

The main `Package.swift` has been updated with:

### New Products
```swift
.library(name: "CoreMLConversionPipeline", targets: ["CoreMLConversionPipeline"]),
.library(name: "ANECapsuleIntegration", targets: ["ANECapsuleIntegration"]),
```

### New Targets
```swift
.target(name: "CoreMLConversionPipeline", 
        dependencies: ["ModelRegistry", "ContractsCore"], 
        path: "Packages/ModelRegistry/Sources", 
        sources: ["CoreMLConversionPipeline.swift", "CoreMLConversionPipelineDemo.swift"],
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),

.target(name: "ANECapsuleIntegration",
        dependencies: ["ANEServicesCore", "CapsuleCore", "ContractsCore", "CapabilityCore"],
        path: "Packages/ANECapsuleIntegration/Sources/ANECapsuleIntegration",
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
```

### Updated Dependencies
- **HarmoniaModule**: Now depends on `CoreMLConversionPipeline` and `ANECapsuleIntegration`
- **AnigmaDaemonCore**: Now depends on `ANECapsuleIntegration` for ANE-aware scheduling

## Usage Examples

### 1. Converting a Model to Core ML

```swift
import CoreMLConversionPipeline
import ModelRegistry

// Create conversion pipeline
let pipeline = CoreMLConversionPipeline(
    workDir: workDir,
    registry: registry,
    pythonEnvPath: "/opt/anigma/coreml-env"
)

// Convert model
let receipt = try await pipeline.convertToCoreML(
    modelId: "bert-base-uncased",
    targetFormat: .mlprogram,
    computeUnits: .cpuAndNeuralEngine,
    quantization: .int8,
    minOSVersion: "macos15"
)
```

### 2. Using ANE Capsule Integration

```swift
import ANECapsuleIntegration
import ContractsCore

// Create ANE capsule
let capsule = ANECapsuleBase(
    identifier: "embeddings.ane",
    capability: ANECapability(
        preferredComputeUnit: .aneOnly,
        fallbackComputeUnits: [.gpu, .cpu],
        optimizationHints: [.prefersFixedShapes, .avoidDynamicReshapes]
    )
)

// Validate contract before execution
try await capsule.validateContract(artifactContract)

// Execute with placement verification
let result = try await capsule.execute(
    input: inputData,
    profile: CoreMLEmbeddingProfile(
        allowFallback: true,
        generateReceipts: true,
        maxBatchSize: 32
    )
)
```

### 3. Working with Artifact Contracts

```swift
import ContractsCore

// Create CoreML artifact contract
let contract = CoreMLArtifactContract(
    schema: ArtifactSchema(
        inputs: [/* tensor schemas */],
        outputs: [/* tensor schemas */],
        supportsStatefulExecution: false
    ),
    limits: ArtifactLimits(
        hard: HardLimits(maxBatchSize: 32, maxMemoryMB: 1024),
        soft: SoftLimits(targetBatchSize: 16, warningThreshold: 0.8)
    ),
    versioning: ArtifactVersioning(
        architectureFingerprint: "bert-encoder-12x768",
        semanticVersion: "1.0.0",
        buildId: "20250127"
    ),
    capability: ArtifactCapability(
        preferredComputeUnit: .aneOnly,
        supportedComputeUnits: [.ane, .gpu, .cpu],
        performanceProfile: PerformanceProfile(
            ane: PerformanceMetrics(expectedLatencyMs: 10),
            gpu: PerformanceMetrics(expectedLatencyMs: 25),
            cpu: PerformanceMetrics(expectedLatencyMs: 100)
        )
    ),
    receiptTemplate: ArtifactReceiptTemplate(
        placementReceipt: PlacementReceipt(/* ... */),
        executionReceipt: CoreMLExecutionReceipt(/* ... */)
    )
)

// Validate contract
try CoreMLArtifactContract.validateInvariants(contract)
```

## Python Environment Setup

The Core ML conversion requires a Python environment with `coremltools`. Create it with:

```bash
# Create Python environment
python3 -m venv /opt/anigma/coreml-env
source /opt/anigma/coreml-env/bin/activate

# Install coremltools
pip install coremltools==8.0

# Install PyTorch (if converting from PyTorch)
pip install torch torchvision
```

## Testing the Integration

### Build Test
```bash
# Build CoreMLConversionPipeline
swift build --product CoreMLConversionPipeline

# Build ANECapsuleIntegration
swift build --product ANECapsuleIntegration

# Build HarmoniaModule (which includes both)
swift build --product HarmoniaModule
```

### Run Demo
```swift
// See CoreMLConversionPipelineDemo.swift for complete example
import CoreMLConversionPipeline

// Run the demo
try await CoreMLConversionPipelineDemo.runDemo()
```

## Troubleshooting

### Common Issues

1. **Missing Python Environment**
   ```
   Error: Python environment not found at /opt/anigma/coreml-env
   ```
   **Solution**: Create the Python environment as shown above.

2. **CoreMLTools Import Error**
   ```
   Error: Failed to import coremltools
   ```
   **Solution**: Ensure coremltools is installed in the Python environment.

3. **Contract Validation Errors**
   ```
   Error: Schema validation failed
   ```
   **Solution**: Check that tensor shapes and data types are valid for Core ML.

4. **ANE Compatibility Issues**
   ```
   Error: Model not compatible with ANE
   ```
   **Solution**: Use `ProgressiveLowering` to create fallback variants or adjust model architecture.

## Next Steps

1. **Integration Testing**: Add comprehensive tests for the new components
2. **Performance Optimization**: Tune ANE-specific optimizations
3. **Documentation**: Expand with more examples and best practices
4. **Monitoring**: Add telemetry for Core ML conversion success rates and performance

## Architecture Notes

The implementation follows the original vision:
- **Don't build a converter**: Build a predictable brick factory
- **5 SURFACE layers**: Schema, Limits, Versioning, Capability, Receipts
- **ANE as infrastructure**: Not a science project, but reliable hardware offload
- **Deterministic execution**: Hash-based identification and reproducible conversions

The system transforms Core ML from a "conversion problem" into a "predictable brick factory" with full auditability and hardware optimization.