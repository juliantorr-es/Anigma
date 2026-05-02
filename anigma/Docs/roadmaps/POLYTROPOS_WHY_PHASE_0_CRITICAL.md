# Why Phase 0 Changes Everything: Zero-Copy As Foundation

**The key insight: Copying is not an implementation detail. It is an architectural boundary.**

---

## The Paradigm Shift

### Old (Copy-Heavy Hidden)

```
execute(operation: MediaDecodeContract) {
  let data = await fetchFromCAS(input)                    // Copy 1: CAS → memory
  let decoded = ffmpeg.decode(data)                       // Decode happens
  let result = Data(bytes: decoded)                       // Copy 2: frame → Data
  await storeToCAS(result)                                // Copy 3: Data → CAS
  return DecodeOutput(
    frameData: PayloadReference(cas_id),                  // ← Looks clean
    receipt: Receipt()                                    // ← Receipt generated
  )
}
```

**Problem**: Copying is hidden. Contracts describe operations cleanly, but executors do the copying. The architecture claims "receipted operations," but the reality is "receipted copying."

### New (Zero-Copy Enforced)

```
execute(operation: MediaDecodeContract) {
  let packet = await packetStreamSource.read()           // Reference only
  let pixelBuffer = try await videoToolbox.decode(packet)
  
  // MUST register, not copy
  let frame = try await surfaceAuthority.registerPixelBuffer(
    pixelBuffer,
    descriptor: frameMetadata,
    owner: self.id
  )
  
  // Verify zero-copy guarantee
  let proof = try await surfaceAuthority.getZeroCopyProof(for: frame.id)
  assert(proof.isZeroCopy)
  
  return DecodeOutput(
    frame: frame,                                         // ← Opaque handle
    zeroCopyProof: proof,                                 // ← Proof of no copy
    receipt: Receipt()
  )
}
```

**Benefit**: Copying is impossible without explicit gate approval. The system defaults to zero-copy. Materialization is the exception that requires justification.

---

## The Three Classes of References

### 1. ArtifactReference (Durable, Storable)

```
Input video file
  → ArtifactReference
  → Stored in CAS
  → Retrieved from CAS
  → Output video file
```

**Characteristics**:
- Long-lived
- Versioned (immutable)
- Auditable (with hash)
- Duplicable
- Compressible
- Storable in CAS

**Use cases**: Input video, output video, encoded packet streams, test vectors

**OK to store**: Anywhere

---

### 2. FrameReference (Ephemeral, Governed)

```
Decoded frame in GPU memory
  → FrameReference (opaque handle)
  → Never stored in CAS
  → Only leased from SurfaceAuthority
  → Lifetime-managed (auto-release)
```

**Characteristics**:
- Short-lived (single operation or few operations)
- Mutable (can be transformed in-place)
- Governed (only accessible via lease)
- Fragile (can be evicted if memory needed)
- Transferable (between operations via lease chain)

**Use cases**: Decoded frames, scaled frames, filtered frames, intermediate operations

**NOT OK to store**: In CAS, on disk, or returned as Data

---

### 3. SurfaceToken (Materialization Boundary)

```
FrameReference.surfaceToken
  → Identifies the actual underlying surface
  → Owned by SurfaceAuthority
  → Can be locked/unlocked for access
  → Can be materialized (turned into ArtifactReference)
```

**Characteristics**:
- Opaque (Tier 1 contracts don't see it)
- Governable (SurfaceAuthority controls access)
- Auditable (all accesses recorded)
- Materialization-gated (copying requires approval)

**Use cases**: Access control, lifetime management, copy prevention

**Never exposed to**: Tier 1 contracts, UI, random executors

---

## The Four Layers

```
┌──────────────────────────────────────────┐
│ Tier 1: Contracts (Pure Semantics)       │
│ • FrameReference (handle only)           │
│ • ArtifactReference (for durables)       │
│ • Never see SurfaceToken, CVPixelBuffer, │
│   MTLTexture, or any framework objects   │
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│ Tier 2: Authorities                      │
│ • SurfaceAuthority (frame ownership)     │
│ • MaterializationGate (copy approval)    │
│ • CASAuthority (durable storage)         │
│ • Only Tier 2 can:                       │
│   - Create FrameReference                │
│   - Approve materialization              │
│   - Expose leases                        │
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│ Tier 2b: Executors (Implementers)        │
│ • VideoToolboxDecoder (takes ref)        │
│ • MetalScaleFormatter (takes ref)        │
│ • FFmpegExecutor (materialization)       │
│ • Only receive:                          │
│   - FrameReference (opaque handle)       │
│   - Leases (PixelBufferLease,            │
│             TextureLease)                │
│ • Must return:                           │
│   - FrameReference (registered)          │
│   - ZeroCopyProof (with proof)           │
│   - Receipt (with materialization log)   │
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│ Tier 3: Platform APIs                    │
│ • CVPixelBuffer (Apple)                  │
│ • MTLTexture (Metal)                     │
│ • IOSurface (cross-framework)            │
│ • VideoToolbox (hardware decode/encode)  │
│ • Only Tier 2 can call these              │
└──────────────────────────────────────────┘
```

---

## Why SurfaceAuthority Is the Keystone

**Without SurfaceAuthority:**
- Anyone can create a CVPixelBuffer
- Executors have ad-hoc lifetime management
- No audit trail of who owns what
- Copying happens silently
- Memory leaks (who releases?)

**With SurfaceAuthority:**
- One central owner of all surfaces
- All frames registered, trackable, auditable
- Leases are explicit and time-bound
- Copying is gatekept and recorded
- Automatic cleanup (lease expiration)

---

## The MaterializationGate as Policy Enforcement

**Without gate:**
```
executor.materialize(frame) {
  let data = frame.toData()                 // ← Copying hidden
  await cas.store(data)
  return ArtifactReference(...)
}
```

**With gate:**
```
executor.materialize(frame, reason: .unsupportedExecutor) {
  // Gate checks: is this allowed?
  guard try await gate.requestMaterialization(
    frame: frame,
    reason: reason,
    executor: self.id
  ) else {
    throw MaterializationError.policyViolation(reason, frame.id, self.id)
  }
  
  // Only if approved: record the event
  let event = MaterializationEvent(
    reason: reason,
    timestamp: now,
    copiedBytes: data.count,  // ← Counted!
    source: frame.id,
    destination: artifactID
  )
  
  // Executor can proceed, but it is audited
  let data = frame.toData()
  await cas.store(data)
  return ArtifactReference(...)  // Will carry proof of materialization
}
```

---

## ZeroCopyProof as Accountability

**For saturated path** (H.264 → Metal → HEVC):
```
ZeroCopyProof {
  copiedBytes: 0,
  materializationEvents: [],
  isZeroCopy: true
}
```
✅ **We can guarantee**: Frames stayed in GPU memory.

**For fallback path** (VP9 → FFmpeg → encode):
```
ZeroCopyProof {
  copiedBytes: 47_300_000,                      // 47.3 MB
  materializationEvents: [
    MaterializationEvent(
      reason: .fallbackBoundary,
      copiedBytes: 47_300_000,
      source: vp9_frame_id,
      destination: temporary_artifact_id
    )
  ],
  isZeroCopy: false
}
```
⚠️ **We can see**: Fallback broke zero-copy, with evidence.

---

## The Codec Support Threshold

**In old architecture**:
- "Does FFmpeg support it?" → Supported
- "Is there a decoder available?" → Supported
- "Codec coverage" = FFmpeg codec count

**In new architecture**:
- "Can it flow through GPU memory without CPU copies?" → Saturated support
- "Is there a zero-copy path?" → Saturated support
- "Codec coverage" = saturation tiers (Tier S / Tier F)

**Result**:
- Saturated path: 4 codecs (H.264, HEVC, ProRes, AV1)
- Fallback path: 20+ codecs (via FFmpeg, with copy overhead recorded)

---

## Why This Changes the Implementation Order

### Without Phase 0 Substrate

**Old order**:
1. Define contracts (MediaDecodeContract, etc.)
2. Build executors (VideoToolboxDecodeExecutor, etc.)
3. Realize frames should be handles, not Data
4. Refactor everything (ugh)

**Problem**: Contracts designed for Data, executors designed for Data, then we bolt on frame governance.

### With Phase 0 Substrate

**New order**:
1. Build substrate (SurfaceAuthority, MaterializationGate, FrameReference)
2. Define contracts (now with FrameReference, not Data)
3. Build executors (take FrameReference, return FrameReference)
4. Done (right model from start)

**Benefit**: Contracts and executors designed for zero-copy from day 1.

---

## The Proof Is In The Receipt

**Old approach**:
```
Receipt {
  operation: "Decode",
  status: "success",
  duration: 12ms
}
```

**New approach**:
```
Receipt {
  operation: "Decode",
  status: "success",
  duration: 12ms,
  zeroCopyProof: {
    copiedBytes: 0,
    materializationEvents: [],
    memoryClass: .cvPixelBuffer
  }
}
```

Now the receipt proves not just that the operation succeeded, but **how it succeeded**.

---

## The Acceptance Gates Make Phase 0 Non-Negotiable

If we skip Phase 0 substrate:
- Executors will create surfaces ad-hoc
- Copying will be hidden (found in bugs, not architecture review)
- Receipts will look good, but operations will be slow
- We can't enforce "no Data frames"
- Debugging will be a nightmare

**Phase 0 gates prevent all of this:**
- Gate 1: Linter prevents Data frames (compile-time check)
- Gate 2: Decode must produce IOSurface-backed CVPixelBuffer (runtime assertion)
- Gate 3: Scale must use CVMetalTextureCache (code review + test)
- Gate 4-8: Integration points verified

**Result**: By the time Phase 0 is done, the system physically cannot hide copying. It is impossible to write slow code by accident.

---

## The Secret Sauce

Anigma's "secret sauce" is not:
- ❌ Metal acceleration (everyone has Metal)
- ❌ VideoToolbox (Apple provides it)
- ❌ FFmpeg fallback (everyone uses FFmpeg)

It is:
- ✅ **Making zero-copy the default** (SurfaceAuthority)
- ✅ **Making copying visible** (MaterializationGate + audit)
- ✅ **Making governance enforceable** (receipts + proofs)
- ✅ **Making fallback transparent** (copiedBytes in receipt)

That is what Phase 0 enables.

---

## Implementation Scope For Phase 0

**What Phase 0 builds**:
- FrameReference type (opaque handle)
- ArtifactReference type (durable)
- SurfaceAuthority actor (register, lease, materialize)
- MaterializationGate actor (approve/deny)
- ZeroCopyProof type (evidence)
- Linter rules (reject Data frames)

**What Phase 0 does NOT do**:
- No VideoToolbox integration (Phase 2)
- No Metal kernels (Phase 3)
- No contracts (Phase 1)
- No executors (Phase 2)

**Phase 0 deliverable**: A governed surface substrate that makes zero-copy enforceable.

---

**Result**: When Phase 0 is done, Phase 1 contracts will be impossible to implement wrong. They will flow FrameReference handles, not Data. Executors will register surfaces, not copy them. The architecture will be correct by construction.**

That is the point of Phase 0.
