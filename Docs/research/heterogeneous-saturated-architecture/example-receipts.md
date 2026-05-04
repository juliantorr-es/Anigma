# Example Chunk Storage Receipts

These examples demonstrate how the `chunk-storage-receipt.schema.json` should be populated for various architectural scenarios.

## 1. Copy-Minimized Chunk Transform
*Scenario: An executor performs a layout transformation (AoS to SoA) within the same memory domain, minimizing copies by using contiguous buffers.*

```json
{
  "schema_version": "1.0.0",
  "operation_id": "550e8400-e29b-41d4-a716-446655440000",
  "operation_kind": "transfer",
  "source_chunk_id": "a1b2c3d4-e5f6-4789-8012-34567890abcd",
  "destination_chunk_id": "f9e8d7c6-b5a4-4321-0987-654321fedcba",
  "component_type_ids": ["Anigma.Position", "Anigma.Velocity"],
  "layout_kind": "soa",
  "memory_domain": "cpu",
  "movement_classification": "copy_minimized",
  "proof_method": "executor_receipt",
  "byte_counts": 65536,
  "alignment": 64,
  "chunk_capacity": 1024,
  "component_count": 1024,
  "executor_id": "Anigma.PhysicsEngine.SoAConverter"
}
```

## 2. Materialized Copy (Fallback)
*Scenario: A planned zero-copy path failed because of alignment issues, falling back to a materialized CPU copy.*

```json
{
  "schema_version": "1.0.0",
  "operation_id": "660e8400-e29b-41d4-a716-446655441111",
  "operation_kind": "fallback",
  "source_chunk_id": "b2c3d4e5-f6a7-4890-8012-34567890abcd",
  "destination_chunk_id": "c3d4e5f6-a7b8-4901-8012-34567890abcd",
  "component_type_ids": ["Anigma.TensorData"],
  "layout_kind": "native_buffer",
  "memory_domain": "cpu",
  "movement_classification": "materialized_copy",
  "proof_method": "materialization_gate",
  "byte_counts": 1048576,
  "alignment": 16,
  "chunk_capacity": 1,
  "component_count": 1,
  "executor_id": "Anigma.ML.FallbackDispatcher",
  "fallback_reason": "Source buffer was not 4KB page-aligned; makeBuffer(bytesNoCopy:) refused wrapping."
}
```

## 3. No-Copy Wrap (Metal Boundary)
*Scenario: Successfully wrapping a CPU-allocated buffer for GPU access using Apple Silicon unified memory.*

```json
{
  "schema_version": "1.0.0",
  "operation_id": "770e8400-e29b-41d4-a716-446655442222",
  "operation_kind": "no_copy_wrap",
  "source_chunk_id": "d4e5f6a7-b8c9-4012-8012-34567890abcd",
  "destination_chunk_id": "e5f6a7b8-c9d0-4123-8012-34567890abcd",
  "component_type_ids": ["Anigma.VertexData"],
  "layout_kind": "native_buffer",
  "memory_domain": "shared_cpu_gpu",
  "movement_classification": "no_copy_wrap",
  "proof_method": "allocator_receipt",
  "byte_counts": 4096,
  "alignment": 4096,
  "chunk_capacity": 1,
  "component_count": 1,
  "executor_id": "Anigma.Render.MetalResourceManager"
}
```

## 4. Zero-Copy Proven (Shared Memory IPC)
*Scenario: Transferring a chunk to a sidecar process using shared memory, proven by a materialization gate audit.*

```json
{
  "schema_version": "1.0.0",
  "operation_id": "880e8400-e29b-41d4-a716-446655443333",
  "operation_kind": "transfer",
  "source_chunk_id": "f6a7b8c9-d0e1-4234-8012-34567890abcd",
  "destination_chunk_id": "a7b8c9d0-e1f2-4345-8012-34567890abcd",
  "component_type_ids": ["Anigma.MediaFrame"],
  "layout_kind": "sidecar_buffer",
  "memory_domain": "sidecar",
  "movement_classification": "zero_copy_proven",
  "proof_method": "materialization_gate",
  "byte_counts": 2097152,
  "alignment": 16384,
  "chunk_capacity": 1,
  "component_count": 1,
  "executor_id": "Anigma.Sidecar.PDFiumManager",
  "warnings": ["Sidecar process shares same physical address space; memory pressure may trigger swap."]
}
```
