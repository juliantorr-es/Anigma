# Design: Anigma Sidecar Protocol

**Author:** Gemini CLI (ses_f7e637)
**Status:** DRAFT (Design Phase)
**Date:** 2026-01-11
**Version:** 1.0.0

## 1. Overview
The Anigma Sidecar Protocol defines the high-performance communication layer between the App/CLI and the Daemon (Sidecar). It employs a hybrid transport strategy: **gRPC** for the control plane (RPC, status, auth) and **Cap'n Proto over Shared Memory** for the data plane (high-speed inference, tensors, zero-copy IPC).

## 2. Hybrid Transport Architecture

### 2.1 Control Plane (gRPC)
Used for non-blocking, asynchronous management tasks where standardization and observability are paramount.
- **Protocol**: gRPC over Unix Domain Sockets (local) or TCP/mTLS (remote).
- **Primary Use Cases**: Session management, status heartbeats, governance policy updates, and identity bootstrapping.

```protobuf
// Example gRPC service for management
service SidecarControl {
    rpc Initialize(IdentityHandshake) returns (SessionReceipt);
    rpc UpdatePolicy(PolicyUpdate) returns (Acknowledgement);
    rpc GetStatus(StatusRequest) returns (StatusReport);
}
```

### 2.2 Data Plane (Cap'n Proto)
Used for high-throughput, latency-critical inference and data handoffs.
- **Protocol**: Cap'n Proto over Shared Memory (SHM) or Unix Sockets.
- **Primary Use Cases**: LLM token streaming, image/tensor transfer, and zero-copy artifact handoffs.

```capnp
# Example Cap'n Proto schema for inference
interface InferenceStream {
    submit @0 (task :InferenceTask) -> (result :InferenceResult);
    stream @1 (requestId :UInt64) -> (token :Text);
}
```

## 3. Zero-Copy IPC (Shared Memory)

To eliminate the "Serialization Tax," the protocol uses **mmap/shm_open** to establish a shared memory region between the App and the Daemon.

### 3.1 The Handshake Sequence
1.  **Handshake**: The App calls `Initialize` via gRPC.
2.  **SHM Allocation**: The Daemon creates a shared memory segment and returns the `shm_id`.
3.  **Mapping**: The App maps the `shm_id` into its address space.
4.  **Cap'n Proto Pointers**: Both processes use Cap'n Proto pointers to read/write structured data in the shared memory without copying buffers.

## 4. Identity & Security

### 4.1 Workload Identity (SPIFFE/SVID)
Connections are bootstrapped using cryptographically verifiable SVIDs.
- **mTLS**: Remote institutional connections require mutual TLS based on the SPIFFE document.
- **Principal Propagation**: The `ProjectID` and `PrincipalID` are injected into the initial gRPC handshake and propagated to all subsequent data plane operations via a bit-packed **Session Token**.

## 5. Large-Blob Handoff

For massive artifacts (e.g., a 1GB PDF or 10GB Model weights), the protocol uses **File Descriptor Passing (FD Passing)**.
1.  The App opens the file and obtains an FD.
2.  The FD is passed to the Daemon via the Unix Domain Socket.
3.  The Daemon uses `mmap` on the passed FD, allowing direct NVMe-to-Memory access without copying data into the transport layer.

## 6. Handshake & Capability Negotiation

During the initial `Initialize` call, the processes negotiate:
- **ML Accelerators**: (e.g., ANE, Metal, or CPU fallback).
- **Memory Limits**: Max shared memory allocation per session.
- **Protocol Version**: Ensuring compatibility between App and Daemon binaries.

---
**Status**: Initial Draft Complete
**Next Steps**: Implementation of gRPC and Cap'n Proto code generation scripts.
