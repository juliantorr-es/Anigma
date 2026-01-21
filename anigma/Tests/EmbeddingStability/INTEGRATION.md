# Embedding Stability Ranking Harness

This directory contains the test harness for validating semantic retrieval stability across engine changes (CoreML, MPS, Metal) as part of Phase 0 of Metal/MPS integration.

## Files

1. `GoldenStoreProvider.swift` - Provides precomputed embeddings and similarity scores for validation
2. `EmbeddingStabilityUnitTests.swift` - Unit tests with 1k docs/50 queries for CI
3. `EmbeddingStabilityIntegrationTests.swift` - Integration tests with 10k docs/200 queries for nightly

## Design Principles

- Store score distributions and hard negatives, not just top‑k IDs
- Focus on semantic retrieval stability (ranking) not bitwise float equality
- Golden store has reference embeddings for MiniLM (384‑dim) and other models
- Tests verify that rankings remain stable within tolerance windows

## Usage

### Adding to Package.swift

Add a new test target to `Package.swift`:

```swift
.testTarget(
    name: "EmbeddingStabilityTests",
    dependencies: [
        "VectorumModule",
        "ContextumModule",
        "ContractsCore",
        "AnigmaCore"
    ],
    path: "Tests/EmbeddingStability",
    swiftSettings: strictConcurrencySettings
),
```

Alternatively, include these files in an existing test target by extending its `path` to include this directory.

### Running Tests

**Unit tests (CI):**
```bash
swift test --filter EmbeddingStabilityUnitTests
```

**Integration tests (nightly):**
```bash
swift test --filter EmbeddingStabilityIntegrationTests
```

### Extending the Golden Store

The `GoldenStoreFactory` currently generates synthetic embeddings. To use real precomputed embeddings:

1. Export embeddings from a reference engine (e.g., CoreML) as JSON
2. Implement `GoldenStoreFactory.createFromJSON(...)`
3. Update the factory methods to load the JSON files

### Tolerance Tuning

Adjust tolerance thresholds in the tests based on expected floating‑point differences between engines:

- Score tolerance: `accuracy: 0.01` (unit), `accuracy: 0.001` (integration)
- Overlap ratio: `0.8` (unit), `0.95` (integration)
- Rank correlation (Kendall’s tau): `> 0.9`

### Future Work

- Add JSON serialization for golden store
- Integrate with actual embedding engines (CoreML, MPS, Metal)
- Add performance benchmarks for each engine
- Extend to support multiple embedding models (MiniLM, BGE, etc.)
- Add statistical tests for distribution stability (KL divergence, Wasserstein distance)

## Governance

“Swift governs, compute computes.” This harness ensures that semantic retrieval remains stable across compute engine changes, preserving the integrity of ranking‑based features.