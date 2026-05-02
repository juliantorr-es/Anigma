# Design: Hardware Authority (Compute Mesh)

**Author:** Gemini CLI (ses_f7e637)
**Status:** DRAFT (Design Phase)
**Date:** 2026-01-11
**Version:** 1.0.0

## 1. Overview
The Hardware Authority is the "Engine" of the Anigma platform. It provides a saturation-aware compute mesh that abstracts Apple Silicon's heterogeneous architecture (CPU, GPU, ANE) into a set of specialized **Hardware Lanes**. It is designed to maximize throughput while enforcing strict **Backpressure** to prevent system instability under high institutional load.

## 2. Hardware Lane Architecture

Workloads are partitioned into four dedicated lanes based on their hardware affinity and governance requirements.

| Lane | Hardware | Primary Workload | Governance |
| :--- | :--- | :--- | :--- |
| **Control** | CPU (High-Perf) | Auth, Governance, SQL | Strict (Synchronous) |
| **Inference** | GPU (Metal) | LLM, Diffusion, Reranking | Assistive (Async) |
| **Perception** | ANE (CoreML) | OCR, Layout, Embeddings | Background (Batch) |
| **Native** | CPU (AMX/SIMD) | BLAKE3, Crypto, Fallback | Deterministic |

- **Isolation**: Each lane maintains its own isolation boundary. A crash in the `Perception` lane (e.g., a buggy OCR model) does not halt the `Control` lane.
- **Fairness**: Resources are time-sliced across `ProjectID`s to prevent a single "Thundering Herd" from starving the platform.

## 3. Unified Buffer Pool (Zero-Copy)

To eliminate the "Serialization Tax" and redundant memory copies, Anigma uses a **Unified Buffer Pool**.

```swift
public actor ManagedBufferPool {
    /// Provides a page-aligned buffer shared between Swift and Metal
    public func requestBuffer(size: Int) async -> SharedBuffer {
        // Implementation uses MTLDevice.makeBuffer(length:options:) 
        // with .storageModeShared
    }
}
```

- **Pointer Handoff**: The `HardwareAuthority` hands off a pointer to the shared memory buffer. No data is moved across the CPU/GPU boundary.
- **Unified Memory**: Leverages Apple Silicon's unified memory architecture for microsecond-scale handoffs.

## 4. Hardware-Level Backpressure

Anigma prevents "Firehose Overflows" (producing data faster than it can be processed) via a **Pull-Based Workload Model**.

```swift
public protocol HardwareLane {
    /// The lane signals when it is ready for more work
    var capacityStream: AsyncStream<Int> { get }
    
    func submit(_ task: ComputeTask) async throws -> TaskResult
}
```

- **Mechanism**: The `ExecutionAuthority` subscribes to the `capacityStream` of each lane.
- **Handshake**: A producer (Agent) is suspended until the target lane (e.g., `Inference`) signals available capacity. This ensures that the queue length remains constant and memory usage is predictable.

## 5. Saturation-Aware Dispatch

The `DispatchController` routes tasks based on the current saturation levels of the system.

- **Dynamic Routing**: If the GPU is 100% saturated with a large Chat task, background embedding tasks (normally Perception/ANE) can be throttled or moved to the Native/CPU lane if immediate capacity is available.
- **Energy Awareness**: The dispatcher can favor the ANE for batch background tasks to conserve power on portable institutional devices (MacBook Pros).

## 6. Implementation Interfaces

```swift
public struct ComputeTask: Sendable {
    public let type: WorkloadType
    public let priority: TaskPriority
    public let projectID: ProjectID
    public let buffer: SharedBuffer
}

public protocol HardwareAuthority: Actor {
    func dispatch(_ task: ComputeTask) async throws -> TaskResult
}
```

---
**Status**: Initial Draft Complete
**Next Steps**: Implementation of the Metal-based Shared Buffer Pool.
