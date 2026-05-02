> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research Report: Parallelization & Hardware Saturation Strategies

**Author:** Gemini CLI (ses_f7e637)
**Status:** Completed
**Date:** 2026-01-11
**Context:** Institutional AI Performance Optimization

## Executive Summary

To achieve high-performance institutional AI, Anigma must distinguish between **Coordination (Concurrency)** and **Saturation (Parallelism)**. While Swift's actor model provides excellent concurrency for non-blocking UI and safe state transitions, it does not inherently guarantee hardware saturation of specialized silicon (GPU/ANE). This report outlines strategies for moving from request-level concurrency to data-oriented parallelism through **Lane Scheduling** and **Batching**.

## Concurrency vs. Parallelism in Anigma

| Feature | Concurrency (Current Baseline) | Parallelism (Target State) |
| :--- | :--- | :--- |
| **Primary Goal** | Non-blocking UI / Safe state. | **Hardware Saturation (CPU/GPU/ANE).** |
| **Mechanism** | Swift Actors / `async/await`. | **SIMD / Metal Kernels / ANE Pipelines.** |
| **Unit of Work** | Single Turn / Single Workflow. | **Batched Tensors / Streamed Segments.** |
| **Limiter** | Latency / Task Switching. | **Memory Bandwidth / Throughput.** |

## Core Strategies for Hardware Saturation

### 1. Separate Control Plane from Data Plane
The CPU should not perform heavy data work; its job is to **manage the pipeline**.
- **Control Plane (Swift/CPU)**: Handles governance checks, policy evaluation, and buffer management.
- **Data Plane (C++/Metal/ANE)**: Performs the actual heavy lifting (Inference, OCR, Embeddings).
- **Saturation Rule**: The CPU must stay ahead of the GPU/ANE, ensuring there is always a "Ready Batch" waiting in the hardware queue.

### 2. Lane Scheduling (Domain-Specific Lanes)
Instead of a single global job queue, work should be partitioned into specialized "Lanes" with specific hardware affinities:
- **Control Lane**: High priority, CPU-only (Governance, Receipts).
- **Inference Lane**: GPU-centric, optimized for large tensor operations.
- **Perception Lane**: ANE-centric, optimized for background document analysis and OCR.
- **Native Lane**: C++ SIMD fallback for non-accelerated compute.

### 3. Data-Oriented Batching
Move from turn-level processing to batch-level processing to hide the overhead of hardware launch latency.
- **Batching Trigger**: Jobs are collected in a short-lived buffer (e.g., 10-50ms) before being dispatched as a single "Vectorized Workload."
- **Proven Benefit**: `CosineSimilarity` shows a **7x speedup** when processing 1M vectors in a single Metal batch compared to sequential CPU processing.
- **Expansion**: Apply this to `TextChunking` (Batch embedding) and `LayoutEngine` (Batch spatial analysis).

### 4. Backpressure & Pipeline Buffering
To prevent the CPU from overwhelming the hardware or memory, a backpressure mechanism is required:
- **Streaming Handshakes**: Authorities should use `AsyncStream` with a defined `bufferSize`. If the hardware queue is full, the ingestion layer (Control Plane) automatically slows down.
- **Zero-Copy Transport (Shared Memory)**: Use **Cap'n Proto over Shared Memory** for high-speed IPC between the App and Sidecar. This eliminates the "Serialization Tax" and ensures that massive tensors are handed off via pointer dereferences rather than buffer copies. (See: [Sidecar Networking Research](./Sidecar_Transport_Protocol.md)).
- **Unified Buffer Pool**: Use page-aligned memory that is shared between all lanes to eliminate the "Data Copy Tax."

## Implementation Pattern: The "Churning" Loop

```swift
// Example: Hardware-Saturated Ingestion Lane
actor HardwareSaturationLane {
    private let hardwareBuffer: UnifiedBufferPool
    private let dataPlane: MetalInferenceAdapter
    
    func process(items: [Data]) async {
        // 1. CPU Prepares Batch (Control Plane)
        let batch = hardwareBuffer.allocate(items.count)
        
        // 2. Parallel Dispatch (Data Plane)
        // This keeps the GPU/ANE "churning" while the CPU fetches next items
        try await dataPlane.dispatch(batch)
        
        // 3. CPU Fetches Next while GPU works
        let nextItems = await fetchNextItems()
        // ... loop
    }
}
```

## Identified Gaps for Design Phase

1. **Global Batch Orchestrator**: We lack a central system that can look across multiple authorities and "Co-Batch" similar tasks (e.g., merging embedding requests from two different workflows into one GPU call).
2. **Dynamic Backpressure**: The current `Job` system doesn't have a way to signal "GPU Busy" to the UI or Ingestion lanes.
3. **Partitionable Projections**: We need to ensure that trace data and audit logs can be rebuilt in parallel by partitioning events by `RunID` or `SessionID`.

## Conclusion

To truly "Churn" through data, Anigma must evolve from a "Safe Actor" system into a "High-Throughput Pipeline" system. By implementing **Lane Scheduling** and **Batch Orchestration**, the platform can ensure that the CPU is used as an efficient manager that keeps the specialized hardware saturated, delivering institutional-grade performance.