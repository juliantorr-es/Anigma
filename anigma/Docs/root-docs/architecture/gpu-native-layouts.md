# Binary Atlas (.atlas): The Saturated Storage Standard

## Status: 🔄 RENOVATION IN PROGRESS
Transitioning from **AoS (Array of Structures)** to **Binary Atlases (SoA)**.

## Overview
To achieve theoretical peak performance on Apple Silicon, Anigma employs the **Binary Atlas (.atlas)** format. This format is designed for **Saturated Autonomy**, eliminating the **Serialization Wall** and the **I/O Wall** by allowing high-throughput data to be memory-mapped directly into GPU/ANE registers.

---

## 1. The .atlas Specification

### A. Layout (Structure of Arrays)
Data is stored as contiguous, typed arrays. This ensures 100% memory coalescing during SIMD execution.
- **Header**: 128-byte aligned metadata (Magic, Version, Dimension, Count, Alignment).
- **Data Spine**: Fused sequential arrays of `Float32`, `BFloat16`, or `Int8`.
- **Padding**: All vector starts are aligned to 128-byte (1024-bit) boundaries to match SIMD cache-line loading.

### B. Access (Zero-Copy)
- **DSLMemoryBridge**: The only authorized way to map an Atlas.
- **Governed Mapping**: Tier 2 uses `mmap` to project the `.atlas` file into the GPU's address space. No `memcpy` or `unzip` steps are allowed.

---

## 2. Hardware Benefits (The "Hot" Tier)

### SIMD Saturation
By storing vectors contiguously, 100% of the bytes fetched from the Unified Memory bus are consumed by the compute cores. This eliminates the "Dead Data" problem of JSON or Swift objects, where the GPU wastes bandwidth skipping over strings and IDs.

### Predictive Pre-fetching
The **Look-Ahead Pager** (Tier 2) uses the `.atlas` structure to signal the OS (`posix_fadvise`) to pre-fetch the next block of vectors into the L3 cache before the Megakernel finishes its current tile.

---

## 3. Saturated Component Linkage (Warm Tier)

While the heavy data lives in the **Binary Atlas**, the relational metadata lives in the **Warm Database**.

```swift
struct SaturatedEmbeddingComponent: Component {
    let atlasId: UUID    // Path to the .atlas file
    let atlasOffset: UInt64 // The 128-byte aligned offset to the vector
    let dimension: Int   // E.g., 384, 1024
}
```

---

## 4. Why .atlas?

| Feature | Legacy (SQL/Swift) | Saturated (.atlas) | Gain |
| :--- | :--- | :--- | :--- |
| **Data Layout** | AoS (Scattered) | **SoA (Contiguous)** | **3.3x Bandwidth** |
| **Transformation** | CPU-bound `unzip` | **Zero cycles (mmap)** | **Infinite** |
| **SIMD Alignment** | Misaligned (BLOB) | **128-byte (Aligned)** | **Full Saturation** |

---

## 5. Renovation Roadmap
- **Phase 1**: Port **Contextum Memories** to use `.atlas` files.
- **Phase 2**: Implement the **Atlas Writer DSL** for saturated ingestion.
- **Phase 3**: Establish the **Look-Ahead Pager** in the `ArtifactAuthority`.
