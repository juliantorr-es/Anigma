# Native Capsule Architecture: The Saturated Standard

## Status: 🔄 RENOVATION IN PROGRESS
Establishing the transition from **Modular Jobs** to **Hardware-Saturated Missions**.

## Overview
Native Capsules are the high-performance engines of Anigma. To achieve theoretical peak performance on Apple Silicon, capsules must evolve from synchronous "Call-Response" workers into autonomous "Saturated Missions" that eliminate the six architectural walls (Coordination, Serialization, Governance, Evidence, I/O, and Scheduling).

---

## 1. Legacy vs. Saturated Pattern

| Feature | Legacy Pattern (Call-Response) | Saturated Pattern (Mission-Evidence) |
| :--- | :--- | :--- |
| **Control Flow** | CPU-driven (Swift pushes every op) | **GPU-driven (Autonomous ICB)** |
| **Data Layout** | Array-of-Structures (AoS) | **Structure-of-Arrays (SoA)** |
| **Synchronization** | `waitUntilCompleted()` (Blocked CPU) | **`addCompletedHandler` (Async Evidence)** |
| **Memory Access** | CPU Buffer Copies | **Governed Memory-Mapped Atlas** |
| **Governance** | Dynamic Policy Checks | **Pre-Signed Mission Descriptors** |
| **Evidence** | CPU-bound Hashing | **In-Kernel SIMD-Blake3 Receipts** |

---

## 2. The Saturated Implementation Pattern

### A. The "Mission" Descriptor
Instead of calling functions, Swift constructs a `MissionDescriptor` that defines the constraints of the hardware execution.

```swift
struct SaturatedMission {
    let missionId: UUID
    let projectContext: ProjectID
    let signedPolicy: MissionPolicyHash  // Pre-signed by Tier 1
    let atlasPointers: [MTLBuffer]       // Governed memory-mapped atlases
    let resultBuffer: MTLBuffer          // Unified memory for output + heartbeats
}
```

### B. The Fused Megakernel (`.metal`)
A single kernel encapsulates the entire capsule workflow to eliminate CPU round-trips.

```cpp
kernel void saturated_capsule_mission(
    device const SaturatedSpine* atlas [[buffer(0)]],
    device SaturatedResult* results [[buffer(1)]],
    constant MissionDescriptor& mission [[buffer(2)]],
    uint thread_idx [[thread_position_in_grid]]
) {
    // 1. Stage 1: Load aligned data from atlas
    // 2. Stage 2: Fused math (No return to CPU)
    // 3. Stage 3: In-kernel evidence hashing (SIMD-Blake3)
    // 4. Stage 4: Write heartbeats directly to resultBuffer
}
```

### C. The Decoupled Driver (Swift Tier 2)
The Swift driver issues the mission and returns a **ReceiptID** immediately.

```swift
public func executeMission(_ mission: SaturatedMission) async throws -> ReceiptID {
    // 1. Governance Handshake (Near-Zero latency with pre-signed descriptor)
    try await governance.verify(mission.signedPolicy)
    
    // 2. Autonomous Submission
    let commandBuffer = commandQueue.makeCommandBuffer()!
    commandBuffer.enqueueSaturatedMission(mission)
    
    // 3. Decoupled Evidence Collection
    commandBuffer.addCompletedHandler { buffer in
        self.evidenceAuthority.ingestInKernelHeartbeats(from: mission.resultBuffer)
    }
    
    commandBuffer.commit()
    return ReceiptID(mission.missionId)
}
```

---

## 3. Mandatory Saturated Requirements

### I. Data-Oriented Design (DOD)
All heavy data (Vectors, Tensors, Document Fragments) must be stored in contiguous **Binary Atlases** (.atlas files). 
- **Rule**: Never store large arrays directly inside an ECS component.
- **Rule**: Ensure 128-byte alignment for SIMD coalescing.

### II. DSL Memory Bridge
All capsules must use the `DSLMemoryBridge` to map data into the GPU address space.
- **Goal**: Zero-copy flow from Disk -> Hot Memory.

### III. Indirect Command Buffers (ICB)
For complex branching (e.g., Speculative Decoding), capsules must use ICBs to allow the GPU to schedule its own kernel sequences.

---

## 4. Renovation Status per Capsule

| Capsule | Renovation Status | Primary Task |
| :--- | :--- | :--- |
| **Search/Similarity** | 🏗️ Phase 1 | `td-106172` (Search Megakernel) |
| **Table Extraction** | ⏳ Blocked | Awaiting `DSLMemoryBridge` |
| **Math OCR** | ⏳ Blocked | Awaiting ANE-to-GPU pipeline |
| **Diff** | ⏳ Blocked | Awaiting SoA Layout redesign |

---

## Conclusion
The Saturated Standard ensures that Anigma’s native performance is limited only by the laws of physics and hardware capacity, not by architectural coordination taxes. Every new native target must conform to the **Mission-Evidence** pattern.
