---
title: "Subprocess Worker Integration Guide"
description: "How to implement isolated adapters behind the SubprocessWorker seam in anigmad."
audience: ["developers", "architects"]
complexity: "advanced"
estimated_time: "20 minutes"
status: "active"
last_updated: "2026-05-01"
---

# Subprocess Worker Integration Guide

The `anigmad` daemon consolidates the system's operational interface into a single **deep module**, but it relies on strict isolation for execution. We use a **SubprocessWorker seam** to isolate untrusted, memory-unsafe, or hardware-saturating logic (like PDF text extraction or Metal LLM inference) away from the core daemon. 

By implementing an **adapter** that satisfies the `SubprocessWorker` interface, you gain the benefits of parallelization and fault isolation while keeping the user-facing CLI unified.

## 1. The SubprocessWorker Seam

When you implement a new feature that carries risk (e.g., a C++ dependency or a high-memory ML model), you must **not** link it directly into the daemon's address space. Instead, you build a standalone executable that implements the worker protocol.

```swift
protocol SubprocessWorker {
    static var poolSize: Int { get }
    static var maxIdleSeconds: Int { get }
    static var maxTasksPerWorker: Int { get }
    func initialize() async throws
    func handleTask(_ task: Task) async throws -> Result
    func cleanup() async
}
```

## 2. Implementing an Adapter

If you are building a new capability—for example, an Image Processing worker—you will build it as an adapter behind this seam.

### A. Define the Worker executable

Create a lightweight Swift executable (e.g., `ImageWorkerExecutable`).

```swift
@main
struct ImageWorkerExecutable {
    static func main() async {
        // 1. Establish IPC connection via stdin/out or UMA
        let transport = IPCChannel(stdin: FileHandle.standardInput, stdout: FileHandle.standardOutput)
        
        // 2. Await initialization payload
        let initData = await transport.receiveInit()
        
        // 3. Process loop
        while let task = await transport.receiveTask() {
            let result = processImage(task)
            await transport.sendResult(result)
        }
    }
}
```

### B. Register with anigmad

In the `anigmad` daemon codebase, you register your new worker type with the `SubprocessManager`.

```swift
// In AnigmaDaemonCore/SubprocessManager.swift
let imageWorkerPool = ProcessPool(
    executableName: "ImageWorkerExecutable",
    poolSize: 2, 
    maxIdleSeconds: 300,
    ipcStrategy: .unixDomainSockets
)

subprocessManager.register(imageWorkerPool)
```

## 3. IPC Strategy Selection & MaterializationGate

The `SubprocessManager` supports different IPC routing depending on your worker's **locality** requirements. Crucially, all data crossing these boundaries must first clear the **`MaterializationGate`**—a universal seam ensuring governed, traceable IPC memory transfers.

| Use Case | Mechanism | Latency | Throughput | Example |
|----------|-----------|---------|------------|---------|
| Heavy Tensor / Media | UMA Shared Memory / IOSurface | ~0.1-0.5μs | ~10-50GB/s | `MLWorkerExecutable` |
| Structured Data | Unix Domain Sockets | ~1-5μs | ~1-10GB/s | `anigma-mcp` |
| Unsafe Parsing (C++/AST) | stdin/stdout pipes | ~10-50μs | ~50-200MB/s | `ASTParserWorkerExecutable`, `PDFSidecarExecutable` |

### 4. Mandatory Zero-Copy Protocol (2026 Mandate)

For any task involving heavy data (Video frames, Large Tensors, high-res Images), you **must** use the zero-copy protocol to clear the `MaterializationGate`:

1. **Authority First:** Request buffers via the `SaturatedMemoryAuthority`. Never use direct `CVPixelBufferCreate` or `malloc` in your adapter.
2. **Handle Passing:** Do not send raw `[Float]` or `Data` over pipes. Send `IOSurfaceID`s or `UMAHandle` pointers in your `handleTask` payload.
3. **Lease Lifecycle:** The `SaturatedMemoryAuthority` manages the lease. Your worker must release the handle immediately after processing to prevent jetsam events.

## 5. Architectural Benefits


By adhering to the `SubprocessWorker` seam:
1. **Locality:** The entire complexity of your image processing logic (and its associated crashes or memory leaks) is contained within your adapter.
2. **Leverage:** The caller (the user or another agent) simply calls `anigmad process-image`. They do not need to manage the lifecycle, sandbox entitlements, or crash-recovery of your worker; the `SubprocessManager` handles that automatically.
