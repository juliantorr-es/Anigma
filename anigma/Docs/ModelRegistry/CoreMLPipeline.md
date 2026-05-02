# Core ML Pipeline Integration Guide

## Overview

The Core ML pipeline converts PyTorch models to Core ML format with full SURFACE layer contracts, deterministic execution, and receipt-based audit trails. It wraps the coremltools Python package with a pinned environment for reproducibility and provides workload-specific optimizations for Apple Neural Engine (ANE) compatibility.

The pipeline implements the "Swift governs, Python computes" architecture where Swift manages the conversion workflow, Python executes the actual model conversion, and SURFACE contracts enforce governance boundaries.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CoreMLConversionPipeline                  │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐   │
│  │   Registry  │  │    Cache    │  │  Python Worker   │   │
│  │   Lookup    │◄─┤  Management │◄─┤  (coremltools)   │   │
│  └─────────────┘  └─────────────┘  └──────────────────┘   │
│         │                         │           │            │
│         ▼                         ▼           ▼            │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐   │
│  │ SURFACE     │  │  Receipt    │  │  Placement       │   │
│  │ Contracts   │  │  Generation │  │  Analysis        │   │
│  └─────────────┘  └─────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

- **Deterministic Conversion**: Same inputs produce identical Core ML outputs across runs
- **Receipt-Based Audit**: Cryptographic receipts track all conversion parameters and outputs
- **Workload Optimization**: Automatic settings for embeddings, rerankers, classifiers, etc.
- **ANE Compatibility**: Automatic analysis for Apple Neural Engine placement
- **Batch Processing**: Parallel conversion of multiple models with progress tracking
- **Intelligent Caching**: Content-addressable cache with validation
- **Retry Logic**: Automatic retry with exponential backoff for transient failures

## Usage Examples

### Basic Conversion

```swift
import ModelRegistry

let workDir = URL(fileURLWithPath: "/tmp/coreml_conversions")
let registry = ModelRegistryStore(storagePath: "/tmp/model_registry.db")
let pipeline = CoreMLConversionPipeline(
    workDir: workDir,
    registry: registry,
    maxRetries: 3,
    retryDelay: 2.0
)

// Convert PyTorch model to Core ML mlprogram format
let receipt = try await pipeline.convertToCoreML(
    modelId: "bert-base-uncased",
    targetFormat: .mlprogram,
    computeUnits: .cpuAndNeuralEngine,
    quantization: .int8,
    minOSVersion: "macos15"
)

print("Conversion successful: \(receipt.outputHashes.count) output files")
```

### ANE-Optimized Conversion

```swift
// Convert with ANE optimization and calibration data
let calibrationData = pipeline.generateCalibrationData(
    for: .embeddings,
    sampleCount: 50
)

let aneReceipt = try await pipeline.convertToCoreML(
    modelId: "all-MiniLM-L6-v2",
    targetFormat: .mlprogram,
    computeUnits: .cpuAndNeuralEngine,
    quantization: .int8,
    minOSVersion: "macos15",
    calibrationData: calibrationData
)

if aneReceipt.placementAnalysis.aneCompatible {
    print("Model is ANE compatible: \(aneReceipt.placementAnalysis.likelyPlacement)")
}
```

### Workload-Specific Conversion

```swift
// Convert with workload-specific optimizations
let workloadReceipt = try await pipeline.convertForWorkload(
    modelId: "clip-vit-base-patch32",
    workloadCategory: .perception
)

print("Optimized for \(workloadReceipt.targetFormat) with \(workloadReceipt.quantization?.rawValue ?? "no") quantization")
```

### Batch Conversion

```swift
// Convert multiple models in parallel
let job = try await pipeline.convertBatch(
    modelIds: ["bert-base-uncased", "all-MiniLM-L6-v2", "clip-vit-base-patch32"],
    targetFormat: .mlprogram,
    computeUnits: .cpuAndNeuralEngine,
    quantization: .int8,
    maxConcurrentConversions: 2,
    progressReporter: DefaultBatchConversionProgressReporter()
)

print("Batch job \(job.id): \(job.completedModels.count) completed, \(job.failedModels.count) failed")
```

## SURFACE Layer Contracts

### 1. Schema Contract
Validates model structure and ensures compatibility with Core ML format requirements.

**Requirements:**
- Input/output tensor shapes must be statically analyzable
- All operations must be supported by target Core ML version
- Model metadata must include version and author information
- Quantization parameters must be valid for target hardware

**Enforcement:**
```swift
public enum CoreMLFormat: String, Codable, Sendable {
    case mlprogram = "mlprogram"      // Modern format with optimization
    case neuralnetwork = "neuralnetwork"  // Legacy format
}

public enum CoreMLComputeUnits: String, Codable, Sendable {
    case all = "all"                      // CPU, GPU, ANE
    case cpuOnly = "cpuOnly"              // CPU only
    case cpuAndGPU = "cpuAndGPU"          // CPU + GPU
    case cpuAndNeuralEngine = "cpuAndNeuralEngine"  // CPU + ANE
}
```

### 2. Limits Contract
Enforces resource boundaries and prevents conversion of models that exceed platform capabilities.

**Limits:**
- Maximum model size: 2GB (compressed)
- Maximum parameter count: 1 billion
- Maximum input dimensions: 5
- Maximum batch size: 32 (ANE), 64 (GPU), unlimited (CPU)

**Validation:**
```swift
public struct CoreMLPlacementAnalysis: Codable, Sendable {
    public let supportedOps: [String]     // Operations supported on target
    public let unsupportedOps: [String]   // Operations requiring fallback
    public let likelyPlacement: String    // "ANE", "GPU", "CPU"
    public let aneCompatible: Bool        // True if ANE compatible
    public let dynamicShapes: Bool        // True if supports dynamic shapes
    public let statefulSupported: Bool    // True if stateful operations supported
}
```

### 3. Versioning Contract
Ensures compatibility across macOS/iOS versions and Core ML toolchain versions.

**Requirements:**
- Minimum OS version must be specified (macos13, macos14, macos15, ios17, ios18)
- Core ML tools version must be pinned for reproducibility
- Output format must be compatible with target OS

**Implementation:**
```swift
public enum CoreMLOSVersion: String, Codable, Sendable, CaseIterable {
    case macos13 = "macos13"
    case macos14 = "macos14"
    case macos15 = "macos15"
    case macos16 = "macos16"
    case ios17 = "ios17"
    case ios18 = "ios18"
    
    public var deploymentTarget: String {
        switch self {
        case .macos13: return "13.0"
        case .macos14: return "14.0"
        case .macos15: return "15.0"
        case .macos16: return "16.0"
        case .ios17: return "17.0"
        case .ios18: return "18.0"
        }
    }
}
```

### 4. Capability Contract
Checks hardware capability compatibility and optimizes for specific workloads.

**Workload Categories:**
```swift
public enum WorkloadCategory: String, Codable, Sendable {
    case embeddings    // Text embedding models (int8 quantization)
    case reranker      // Reranking models (fp16 quantization)
    case classifier    // Classification models (int8 quantization)
    case perception    // Vision models (fp16 quantization, ANE optimized)
    case prefill       // LLM prefill (fp16 quantization)
    case decode        // LLM decode (fp16 quantization)
    case multimodal    // Multimodal models (fp16 quantization)
    case specialized   // Specialized models (custom optimization)
}
```

**Automatic Optimization:**
- Embeddings: int8 quantization, ANE optimization
- Perception: fp16 quantization, ANE optimization  
- Classifiers: int8 quantization, CPU/GPU optimization
- LLMs: fp16 quantization, mixed precision

### 5. Receipts Contract
Provides cryptographic audit trail for all conversions with deterministic hashing.

**Receipt Structure:**
```swift
public struct CoreMLConversionReceipt: Codable, Sendable {
    public let inputHashes: [String: String]      // SHA256 of input artifacts
    public let toolId: String                     // "coremltools"
    public let toolVersion: String                // Pinned version
    public let outputHashes: [String: String]     // SHA256 of output artifacts
    public let targetFormat: CoreMLFormat         // Output format
    public let computeUnits: CoreMLComputeUnits   // Target hardware
    public let quantization: CoreMLQuantization?  // Quantization type
    public let minOSVersion: String               // Minimum OS version
    public let placementAnalysis: CoreMLPlacementAnalysis
    public let timestamp: Date                    // Conversion time
    public let metadata: [String: String]         // Additional metadata
    public let cacheKey: String?                  // Cache key for reuse
    public let calibrationDataHash: String?       // Hash of calibration data
}
```

**Deterministic Hashing:**
- Input artifacts hashed with SHA256
- Output artifacts hashed with SHA256  
- Calibration data hashed with combined hasher
- Cache key derived from all conversion parameters

## Integration Guide

### 1. Prerequisites

**System Requirements:**
- macOS 13.0+ (for Core ML conversion)
- Python 3.8+ with coremltools 7.0+
- 8GB+ RAM for model conversion
- Xcode Command Line Tools

**Python Environment:**
```bash
# Create isolated Python environment
python -m venv /opt/anigma/coreml-env
source /opt/anigma/coreml-env/bin/activate
pip install coremltools==7.0 torch torchvision
```

### 2. Model Registry Integration

**Registering Models:**
```swift
import ModelRegistry

let registry = ModelRegistryStore(storagePath: "/path/to/registry.db")

// Register PyTorch model
try await registry.register(
    id: "bert-base-uncased",
    spec: ModelSpec(
        format: .pytorch,
        artifactHashes: [
            "model.pth": "sha256:abc123...",
            "config.json": "sha256:def456..."
        ],
        metadata: [
            "author": "Google",
            "license": "Apache-2.0",
            "parameters": "110M"
        ]
    ),
    installPath: "/models/bert-base-uncased"
)
```

### 3. Pipeline Configuration

**Basic Configuration:**
```swift
let pipeline = CoreMLConversionPipeline(
    workDir: URL(fileURLWithPath: "/tmp/coreml_work"),
    registry: registry,
    pythonEnvPath: "/opt/anigma/coreml-env",
    cacheDir: URL(fileURLWithPath: "/tmp/coreml_cache"),
    maxRetries: 3,
    retryDelay: 2.0,
    logger: DefaultCoreMLConversionLogger()
)
```

**Advanced Configuration:**
```swift
// Custom logger implementation
struct CustomLogger: CoreMLConversionLogger {
    func logConversionStart(modelId: String, targetFormat: CoreMLFormat, quantization: CoreMLQuantization?) {
        // Custom logging logic
    }
    // ... implement other methods
}

let customPipeline = CoreMLConversionPipeline(
    workDir: workDir,
    registry: registry,
    logger: CustomLogger()
)
```

### 4. Cache Management

**Cache Operations:**
```swift
// Get cache statistics
let stats = try await pipeline.getCacheStats()
print("Cache: \(stats.total) entries, \(stats.size) bytes")

// Clear cache
try await pipeline.clearCache()

// Manual cache operations (advanced)
let cacheKey = pipeline.generateCacheKey(
    modelId: "bert-base-uncased",
    targetFormat: .mlprogram,
    computeUnits: .cpuAndNeuralEngine,
    quantization: .int8,
    minOSVersion: "macos15",
    calibrationData: nil
)
```

### 5. Error Handling

**Common Errors:**
```swift
public enum CoreMLConversionError: Error {
    case modelNotFound(String)
    case conversionFailed(String)
    case analysisFailed(String)
    case toolNotFound(String)
    case cacheError(String)
    case calibrationError(String)
    case retryExhausted(String)
    case invalidOSVersion(String)
}
```

**Error Recovery:**
```swift
do {
    let receipt = try await pipeline.convertToCoreML(
        modelId: modelId,
        targetFormat: .mlprogram
    )
} catch CoreMLConversionError.modelNotFound(let modelId) {
    print("Model not found: \(modelId)")
    // Register missing model
} catch CoreMLConversionError.conversionFailed(let message) {
    print("Conversion failed: \(message)")
    // Check Python environment
} catch CoreMLConversionError.retryExhausted(let message) {
    print("Retries exhausted: \(message)")
    // Manual intervention required
} catch {
    print("Unexpected error: \(error)")
}
```

## Python Integration

### Conversion Script

The pipeline uses a Python script (`coreml_conversion_simple.py`) for actual conversion:

**Key Features:**
- Pinned coremltools version
- Deterministic output generation
- Placement analysis
- Calibration data support
- Error reporting with structured JSON

**Script Interface:**
```bash
python coreml_conversion_simple.py \
  --model-path /path/to/model \
  --output-path /path/to/output \
  --target-format mlprogram \
  --compute-units all \
  --min-os-version macos15 \
  --quantization int8 \
  --calibration-data calibration.json
```

### Environment Management

**Isolated Environment:**
```python
# coreml_conversion_simple.py
import coremltools as ct
import torch
import json
import sys

def convert_model(args):
    # Load PyTorch model
    model = torch.load(args.model_path)
    
    # Convert to CoreML
    mlmodel = ct.convert(
        model,
        inputs=[ct.TensorType(shape=(1, 3, 224, 224))],
        compute_units=ct.ComputeUnit[args.compute_units.upper()],
        minimum_deployment_target=ct.target[args.min_os_version],
        convert_to=args.target_format
    )
    
    # Save model
    mlmodel.save(args.output_path)
    
    # Generate analysis
    analysis = analyze_model(mlmodel)
    return analysis
```

## Performance Optimization

### 1. Quantization Strategies

**Int8 Quantization:**
- Best for embeddings and classifiers
- 4x memory reduction
- 2-3x speedup on ANE
- Requires calibration data

**FP16 Quantization:**
- Best for vision and LLM models
- 2x memory reduction
- GPU/ANE acceleration
- Minimal accuracy loss

**Mixed Precision:**
- Automatic by coremltools
- Critical layers in FP32
- Non-critical in FP16/INT8

### 2. ANE Optimization

**ANE-Compatible Operations:**
- Convolutions (2D, depthwise)
- Fully connected layers
- Batch normalization
- Element-wise operations

**Optimization Techniques:**
- Channel-last memory layout
- Power-of-two channel counts
- Fused operations
- Weight packing

### 3. Cache Optimization

**Cache Key Generation:**
```swift
private func generateCacheKey(
    modelId: String,
    targetFormat: CoreMLFormat,
    computeUnits: CoreMLComputeUnits,
    quantization: CoreMLQuantization?,
    minOSVersion: String,
    calibrationData: CoreMLCalibrationData?
) -> String {
    var hasher = Hasher()
    hasher.combine(modelId)
    hasher.combine(targetFormat.rawValue)
    hasher.combine(computeUnits.rawValue)
    hasher.combine(quantization?.rawValue ?? "none")
    hasher.combine(minOSVersion)
    hasher.combine(calibrationData?.hash() ?? "none")
    return String(hasher.finalize())
}
```

**Cache Validation:**
- Output file existence check
- Hash verification
- Automatic cache invalidation on corruption

## Monitoring and Debugging

### Logging

**Default Logger Output:**
```
[CoreML] Starting conversion: bert-base-uncased -> mlprogram (int8)
[CoreML] bert-base-uncased: 10% - Preparing conversion
[CoreML] Cache miss: bert-base-uncased (abc12345)
[CoreML] bert-base-uncased: 30% - Starting conversion
[CoreML] bert-base-uncased: 70% - Conversion complete, hashing outputs
[CoreML] bert-base-uncased: 80% - Analyzing placement
[CoreML] bert-base-uncased: 90% - Saving to cache
[CoreML] bert-base-uncased: 100% - Conversion complete
[CoreML] Conversion successful: bert-base-uncased (45s)
```

### Progress Reporting

**Batch Progress:**
```
[Batch abc12345] 25% complete - 1/4 models (ETA: 135s)
[Batch abc12345] bert-base-uncased: 50% - Converting layers
[Batch abc12345] 50% complete - 2/4 models (ETA: 90s)
[Batch abc12345] Completed: 4 successful, 0 failed
```

### Debugging Tips

**Common Issues:**
1. **Python environment not found**: Verify `/opt/anigma/coreml-env` exists
2. **Model not found**: Check registry registration
3. **Unsupported operations**: Review placement analysis
4. **Memory issues**: Reduce batch size or model complexity
5. **Cache corruption**: Clear cache with `pipeline.clearCache()`

**Debug Commands:**
```swift
// Check Python environment
let version = try await pipeline.getCoreMLToolsVersion()
print("CoreML Tools version: \(version)")

// Analyze model placement
let analysis = try await pipeline.analyzeCoreMLPlacement(modelPath: "/path/to/model")
print("ANE compatible: \(analysis.aneCompatible)")
print("Unsupported ops: \(analysis.unsupportedOps)")
```

## Best Practices

### 1. Model Preparation
- Use PyTorch 2.0+ for best compatibility
- Export with `torch.jit.trace` for static graphs
- Include model metadata (author, license, version)
- Validate input/output shapes

### 2. Conversion Settings
- Start with `.mlprogram` format for modern features
- Use `.cpuAndNeuralEngine` for ANE compatibility
- Add quantization for production deployments
- Specify minimum OS version for compatibility

### 3. Production Deployment
- Use receipts for audit trails
- Implement cache warming for common models
- Monitor conversion success rates
- Set up alerting for conversion failures

### 4. Testing
- Test conversion on target hardware
- Validate accuracy after quantization
- Benchmark performance across devices
- Test edge cases (empty inputs, max sizes)

## Related Documentation

- [Model Registry Overview](../architecture/ModelRegistry.md)
- [SURFACE Contracts](../../governance/contract-artifacts/SURFACE.MLWorkerBackends.md)
- [Core ML Tools Documentation](https://coremltools.readme.io)
- [Apple Neural Engine Guide](https://developer.apple.com/documentation/coreml)

## Support

For issues with Core ML conversion:
1. Check Python environment and dependencies
2. Review placement analysis for unsupported operations
3. Verify model format and compatibility
4. Check system logs for memory issues
5. Contact ML infrastructure team for assistance