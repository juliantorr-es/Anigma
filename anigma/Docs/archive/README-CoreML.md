# Core ML Conversion Pipeline

## Overview

The Core ML Conversion Pipeline provides deterministic PyTorch → Core ML conversion with full provenance tracking for the Anigma Model Registry. It extends the existing `ModelConversionPipeline` patterns and integrates with the Anigma architecture.

## Key Features

- **Deterministic Conversions**: Reproducible Core ML model generation with SHA-256 hashing
- **Provenance Tracking**: Complete conversion receipts with input/output hashes
- **ANE Compatibility Analysis**: Automatic placement analysis for Apple Neural Engine
- **Workload-Specific Optimization**: Pre-configured settings for different ML workloads
- **Python Tool Wrapping**: Safe execution of coremltools in isolated environment

## Architecture

### Core Components

1. **CoreMLConversionPipeline** (`CoreMLConversionPipeline.swift`)
   - Main actor for managing Core ML conversions
   - Integrates with `ModelRegistryProtocol` for model discovery
   - Generates `CoreMLConversionReceipt` with full provenance

2. **CoreMLConversionReceipt** (`CoreMLConversionPipeline.swift:308`)
   - Core ML-specific receipt structure extending base `ConversionReceipt`
   - Includes placement analysis, compute units, and format metadata

3. **Python Wrapper Script** (`Scripts/coreml_conversion_simple.py`)
   - Bridge between Swift and coremltools Python package
   - Provides deterministic execution environment
   - Returns structured JSON for Swift parsing

### Supporting Types

- `CoreMLFormat`: mlprogram or neuralnetwork formats
- `CoreMLComputeUnits`: Hardware targeting (CPU, GPU, ANE)
- `CoreMLQuantization`: Precision levels (int8, fp16, fp32)
- `CoreMLPlacementAnalysis`: Hardware compatibility analysis
- `WorkloadCategory`: Workload-specific optimization presets

## Usage

### Basic Conversion

```swift
let pipeline = CoreMLConversionPipeline(
    workDir: workDirURL,
    registry: modelRegistry,
    pythonEnvPath: "/opt/anigma/coreml-env"
)

let receipt = try await pipeline.convertToCoreML(
    modelId: "bert-base-uncased",
    targetFormat: .mlprogram,
    computeUnits: .cpuAndNeuralEngine,
    quantization: .int8
)
```

### Workload-Specific Conversion

```swift
let receipt = try await pipeline.convertForWorkload(
    modelId: "all-MiniLM-L6-v2",
    workloadCategory: .embeddings
)
```

### Receipt Inspection

```swift
print("Tool: \(receipt.toolId) v\(receipt.toolVersion)")
print("Format: \(receipt.targetFormat)")
print("Compute Units: \(receipt.computeUnits)")
print("ANE Compatible: \(receipt.placementAnalysis.aneCompatible)")
print("Output Files: \(receipt.outputHashes.count)")
```

## Integration Points

### With ModelRegistry

The pipeline integrates with the existing `ModelRegistryProtocol`:
- Discovers models via `registry.find(id:)`
- Uses `ModelRegistryEntry.installPath` for source models
- Leverages `ModelSpec.artifactHashes` for input provenance

### With CoreMLEmbeddingComputer

Converted models can be loaded by `CoreMLEmbeddingComputer`:
- Core ML models stored as `.mlpackage` or `.mlmodel` files
- Placement analysis guides runtime hardware selection
- Quantization settings optimize for target hardware

### With Conversion Pipeline Pattern

Extends the `ModelConversionPipeline` pattern:
- Similar receipt structure to MLX and GGUF conversions
- Consistent error handling and execution patterns
- Integrated with model governance and provenance

## Python Environment

### Requirements

The pipeline expects a Python environment with:
- `coremltools` >= 7.0
- `torch` for PyTorch model loading
- Python 3.11+ (aligned with macOS system Python)

### Environment Setup

```bash
# Create isolated Python environment
python3 -m venv /opt/anigma/coreml-env

# Activate and install dependencies
source /opt/anigma/coreml-env/bin/activate
pip install coremltools torch
```

## Error Handling

The pipeline throws `CoreMLConversionError` for:
- `modelNotFound`: Model not in registry
- `conversionFailed`: Python wrapper execution failed
- `analysisFailed`: Placement analysis failed
- `toolNotFound`: coremltools not available

## Deterministic Guarantees

1. **Input Hashing**: All input artifacts are SHA-256 hashed
2. **Tool Versioning**: coremltools version captured in receipt
3. **Output Hashing**: Generated Core ML models are hashed
4. **Environment Isolation**: Python environment pinned for reproducibility
5. **Parameter Recording**: All conversion parameters stored in receipt

## Placement Analysis

The pipeline analyzes Core ML models for:
- **ANE Compatibility**: Whether model can use Apple Neural Engine
- **Dynamic Shapes**: Support for variable input sizes
- **Stateful Operations**: Support for recurrent models
- **Operation Support**: List of supported/unsupported ops

## Workload Categories

Pre-configured optimizations for:

| Category | Format | Compute Units | Quantization | Use Case |
|----------|--------|---------------|--------------|----------|
| Embeddings | mlprogram | CPU+ANE | int8 | Text embeddings, retrieval |
| Reranker | mlprogram | CPU+ANE | fp16 | Cross-encoder reranking |
| Classifier | mlprogram | All | int8 | Text classification |
| Perception | mlprogram | CPU+ANE | fp16 | Vision/image models |
| Prefill | mlprogram | All | fp16 | LLM prefill phase |

## Future Extensions

1. **Model Lowering Pipeline**: Integration with `ModelLoweringPipeline`
2. **Custom Conversion Scripts**: User-provided Python conversion scripts
3. **Batch Conversion**: Parallel conversion of multiple models
4. **Conversion Caching**: Hash-based caching of conversion results
5. **Remote Execution**: Distributed conversion on GPU servers