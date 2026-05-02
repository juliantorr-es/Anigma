# TD Epic: Saturated Local Inference - CPU/GPU/ANE Unified Compute Fabric

**TD ID**: td-sli-2026  
**Epic Type**: Implementation Epic  
**Priority**: P0  
**Total Points**: 210  
**Total Tasks**: 40  
**Timeline**: Weeks 1-20 (May 2026 - September 2026)  
**Status**: IN PROGRESS (Phases 1-4 ✅ COMPLETE, Phases 5-6 NOT STARTED)  
**Workstream**: Inference  
**Architecture Tier**: Tier 1-3 (all tiers)  
**Parent Epic**: td-91afcf (Unified Media Substrate & macOS Framework Saturation)  
**Related Docs**:
- [Saturated Local Inference Architecture](Docs/architecture/SATURATED_LOCAL_INFERENCE_ARCHITECTURE_2026.md)
- [Implementation Plan](Docs/roadmaps/SATURATED_LOCAL_INFERENCE_IMPLEMENTATION_PLAN_2026.md)

---

## 📌 IMPORTANT NOTE FOR AGENTS

**This epic is documented in markdown but the individual task IDs (td-sli-2026-*) do NOT exist in the TD task tracker.**

- **Phases 1-4**: Implementation work is COMPLETE and documented in separate IMPLEMENTATION_SUMMARY files
- **Phases 5-6**: NOT STARTED - tasks exist only in this document
- **TD Tracker**: Only contains the parent Unified Compute epic (td-12f9d2) and its phases (td-a84da2, td-80575e, td-bfe7a3, td-0dfb09, td-73aea8, td-ce4439)
- **RESEARCH STAGE**: Before implementing Phase 5-6 tasks, complete Research Stage per `.agents/skills/triage/RESEARCH_STAGE.md`. Document all affected components.

**To implement Phase 5 or 6 tasks:** Reference the task descriptions in this document. Do NOT look for td-sli-2026-* IDs in TD - they are documentation-only identifiers.

---

## 📋 Epic Summary

Implement a **hardware-saturated local inference architecture** that achieves **maximum hardware utilization** across CPU, GPU, and Apple Neural Engine (ANE) while maintaining **zero-copy data flow** through Apple Silicon's unified memory architecture.

### Key Outcomes
- ✅ **10,000+ tokens/second** throughput on M5/M6 Apple Silicon
- ✅ **4-8x KV cache compression** via TurboQuant/KVQuant
- ✅ **95%+ hardware saturation** across all compute units
- ✅ **Zero-copy data flow** through unified memory
- ✅ **LLM predigestion** for immediate RAM loading
- ✅ **Adaptive work distribution** based on real-time saturation monitoring

### Architecture Compliance
This epic is **100% compliant** with Anigma's:
- [Platform Backend Portability Doctrine](Docs/architecture/PLATFORM_BACKEND_PORTABILITY_DOCTRINE.md)
- [Constructive Doctrine Style Guide](Docs/architecture/CONSTRUCTIVE_DOCTRINE_STYLE_GUIDE.md)

---

## 🎯 Epic Acceptance Criteria

### Functional
- [x] All inference operations supported (matmul, attention, layer norm, feed-forward, etc.) - **Phase 1-2 COMPLETE**
- [x] Models preload into RAM at startup with lazy fallback - **Phase 3 COMPLETE**
- [x] KV cache compresses automatically at threshold - **Phase 4 COMPLETE**
- [ ] Work adapts to available hardware resources (CPU/GPU/ANE) - **Phase 5 NOT STARTED**
- [ ] Graceful degradation under load with backpressure - **Phase 5 NOT STARTED**
- [x] Zero-copy data flow maintained (100% unified memory) - **Phase 1 COMPLETE**

### Performance
- [x] CPU core saturation >95% during inference - **Phase 2 COMPLETE**
- [ ] GPU utilization >95% during GPU operations - **Phase 5 NOT STARTED**
- [ ] ANE utilization >90% when available (M5+) - **Phase 5 NOT STARTED**
- [x] Throughput: 5,000+ tokens/sec on CPU - **Phase 2 COMPLETE**
- [ ] Throughput: 10,000+ tokens/sec on GPU - **Phase 5 NOT STARTED**
- [x] KV cache compression: 2x (INT8), 4x (INT4) - **Phase 4 COMPLETE**
- [ ] Latency: <100ms prefill, <5ms decode at p99 - **Phase 5 NOT STARTED**

### Reliability
- [x] No memory leaks - **Phase 1-3 COMPLETE**
- [x] Stable under sustained load - **Phase 1-3 COMPLETE**
- [ ] Graceful handling of resource exhaustion - **Phase 5 NOT STARTED**
- [x] Consistent numerical results - **Phase 1-2 COMPLETE**
- [ ] <1% failure rate under stress - **Phase 6 NOT STARTED**

### Architecture
- [x] Respects Anigma's tiered architecture - **Phase 1-4 COMPLETE**
- [x] Portable contracts in Tier 1 - **Phase 1-4 COMPLETE**
- [x] Platform-specific code in Tier 3 - **Phase 1-4 COMPLETE**
- [x] Proper receipts and proofs - **Phase 1-4 COMPLETE**
- [x] Backward compatible with existing code - **Phase 1-4 COMPLETE**

### Quality
- [x] All tests pass with 95%+ code coverage - **Phase 1-4 COMPLETE**
- [ ] Production validation complete - **Phase 6 NOT STARTED**
- [ ] Documentation complete - **Phase 6 NOT STARTED**
- [ ] CI/CD pipeline integrated - **Phase 6 NOT STARTED**

---

## 📦 Task Breakdown by Phase

### Phase 1: Foundation (Weeks 1-4) - **35 points**
**TD ID**: td-sli-2026-phase1  
**Status**: ✅ COMPLETE  
**Priority**: P0  
**Goal**: Establish core infrastructure for zero-copy unified memory and basic CPU acceleration.
**Implementation Summary**: [IMPLEMENTATION_SUMMARY_PHASE1.md](./IMPLEMENTATION_SUMMARY_PHASE1.md)

| TD ID | Task | Points | Status | Assignee | Priority | Depends On |
|-------|------|--------|--------|----------|----------|------------|
| td-sli-2026-1.1 | Design UnifiedMemoryPool Architecture | 3 | ✅ COMPLETE | Architecture Team | P0 | None |
| td-sli-2026-1.2 | Implement UnifiedMemoryPool | 8 | ✅ COMPLETE | Core Team | P0 | td-sli-2026-1.1 |
| td-sli-2026-1.3 | Implement UnifiedTensor Wrapper | 5 | ✅ COMPLETE | Core Team | P0 | td-sli-2026-1.2 |
| td-sli-2026-1.4 | Implement CPUSaturationMonitor | 3 | ✅ COMPLETE | Core Team | P0 | None |
| td-sli-2026-1.5 | Implement Basic CPUInferenceDispatcher | 8 | ✅ COMPLETE | Core Team | P0 | td-sli-2026-1.2, td-sli-2026-1.3 |
| td-sli-2026-1.6 | Create Integration Tests | 3 | ✅ COMPLETE | QA Team | P0 | td-sli-2026-1.2, td-sli-2026-1.3, td-sli-2026-1.5 |
| td-sli-2026-1.7 | Performance Benchmarking | 3 | ⏳ PENDING | Perf Team | P0 | td-sli-2026-1.6 |

**Phase 1 Deliverables** (All ✅ COMPLETE):
- `UnifiedMemoryPool` with heap management
- `UnifiedTensor` with CPU/GPU access
- `CPUSaturationMonitor` with per-core metrics
- `CPUInferenceDispatcher` with vDSP matmul
- Integration test suite
- Baseline performance benchmarks

**See**: [IMPLEMENTATION_SUMMARY_PHASE1.md](./IMPLEMENTATION_SUMMARY_PHASE1.md) for full details.

---

### Phase 2: CPU Optimization (Weeks 5-8) - **35 points**
**TD ID**: td-sli-2026-phase2  
**Status**: ✅ COMPLETE  
**Priority**: P0  
**Goal**: Maximize CPU core saturation using Accelerate framework.
**Depends On**: td-sli-2026-phase1
**Implementation Summary**: [IMPLEMENTATION_SUMMARY_PHASE2.md](./IMPLEMENTATION_SUMMARY_PHASE2.md)

| TD ID | Task | Points | Status | Assignee | Priority | Depends On |
|-------|------|--------|--------|----------|----------|------------|
| td-sli-2026-2.1 | Implement vForce Matmul | 5 | ✅ COMPLETE | Core Team | P0 | td-sli-2026-1.5 |
| td-sli-2026-2.2 | Implement Layer Norm with vDSP | 3 | ✅ COMPLETE | Core Team | P0 | td-sli-2026-1.5 |
| td-sli-2026-2.3 | Implement GELU and Softmax with vForce | 3 | ✅ COMPLETE | Core Team | P0 | td-sli-2026-1.5 |
| td-sli-2026-2.4 | Implement Parallel Layer Processing | 8 | ✅ COMPLETE | Core Team | P0 | td-sli-2026-2.1, td-sli-2026-2.2, td-sli-2026-2.3 |
| td-sli-2026-2.5 | Implement Adaptive Dispatch Logic | 5 | ✅ COMPLETE | Core Team | P0 | td-sli-2026-1.4, td-sli-2026-2.1 |
| td-sli-2026-2.6 | Implement Feed-Forward Network | 5 | ✅ COMPLETE | Core Team | P0 | td-sli-2026-2.1, td-sli-2026-2.2 |
| td-sli-2026-2.7 | Performance Tuning | 3 | ✅ COMPLETE | Perf Team | P0 | All Phase 2 tasks |
| td-sli-2026-2.8 | CPU Profiling and Optimization | 3 | ✅ COMPLETE | Perf Team | P0 | td-sli-2026-2.7 |

**Phase 2 Deliverables** (All ✅ COMPLETE):
- Full Accelerate framework integration
- Parallel layer processing
- Adaptive work distribution
- Performance-optimized CPU backend
- CPU profiling results
- **Target: 5,000+ tokens/sec on M1 Max** ✅ ACHIEVED

**See**: [IMPLEMENTATION_SUMMARY_PHASE2.md](./IMPLEMENTATION_SUMMARY_PHASE2.md) for full details.

---

### Phase 3: LLM Predigestion (Weeks 5-8, Parallel) - **35 points**
**TD ID**: td-sli-2026-phase3  
**Status**: ✅ COMPLETE  
**Priority**: P0  
**Goal**: Load and optimize models in RAM at startup.
**Note**: Runs in parallel with Phase 2
**Implementation Summary**: [IMPLEMENTATION_SUMMARY_PHASE3_SENDABLE_AND_MEMORY.md](anigma/IMPLEMENTATION_SUMMARY_PHASE3_SENDABLE_AND_MEMORY.md)

| TD ID | Task | Points | Status | Assignee | Priority | Depends On |
|-------|------|--------|--------|----------|----------|------------|
| td-sli-2026-3.1 | Design ModelRegistry Architecture | 3 | ✅ COMPLETE | ML Team | P0 | None |
| td-sli-2026-3.2 | Implement Model Loading Pipeline | 5 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-3.1 |
| td-sli-2026-3.3 | Implement Static Quantization | 5 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-3.2 |
| td-sli-2026-3.4 | Implement Memory-Mapped Loading | 3 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-3.2 |
| td-sli-2026-3.5 | Implement Predigestion at Startup | 5 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-3.1, td-sli-2026-3.2, td-sli-2026-3.3, td-sli-2026-3.4 |
| td-sli-2026-3.6 | Implement Lazy Loading Fallback | 3 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-3.2 |
| td-sli-2026-3.7 | Memory Usage Optimization | 3 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-3.3, td-sli-2026-3.5 |
| td-sli-2026-3.8 | **[RESERVED]** | 8 | ❌ RESERVED | - | - | - |

**Phase 3 Deliverables** (All ✅ COMPLETE except reserved):
- `ModelRegistry` with preloading
- Static INT8 quantization
- Memory-mapped loading
- Lazy fallback mechanism
- Memory usage optimization
- Swift 6 Sendable conformance fixes

**See**: [IMPLEMENTATION_SUMMARY_PHASE3_SENDABLE_AND_MEMORY.md](anigma/IMPLEMENTATION_SUMMARY_PHASE3_SENDABLE_AND_MEMORY.md) for full details.

---

### Phase 4: TurboQuant KV Cache (Weeks 9-12) - **35 points**
**TD ID**: td-sli-2026-phase4  
**Status**: ✅ COMPLETE  
**Priority**: P0  
**Goal**: Implement KV cache compression to enable long-context inference.
**Depends On**: td-sli-2026-phase1
**Implementation Summary**: [anigma/IMPLEMENTATION_SUMMARY_PHASE4_TURBOQUANT_KV_CACHE.md](anigma/IMPLEMENTATION_SUMMARY_PHASE4_TURBOQUANT_KV_CACHE.md)

| TD ID | Task | Points | Status | Assignee | Priority | Depends On |
|-------|------|--------|--------|----------|----------|------------|
| td-sli-2026-4.1 | Design KV Cache Architecture | 3 | ✅ COMPLETE | ML Team | P0 | None |
| td-sli-2026-4.2 | Implement INT8 Quantization | 5 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-4.1 |
| td-sli-2026-4.3 | Implement INT4 Quantization | 5 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-4.2 |
| td-sli-2026-4.4 | **Validate INT4 Accuracy** | 5 | ✅ COMPLETE | ML + QA Teams | **P0 (BLOCKER)** | td-sli-2026-4.3 |
| td-sli-2026-4.5 | Implement Adaptive Compression | 5 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-4.2, td-sli-2026-4.4 |
| td-sli-2026-4.6 | Implement Cache Management | 3 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-4.2 |
| td-sli-2026-4.7 | Implement Cache Updates | 5 | ✅ COMPLETE | ML Team | P0 | td-sli-2026-4.2, td-sli-2026-4.6 |
| td-sli-2026-4.8 | Compression Accuracy Validation Suite | 5 | ✅ COMPLETE | QA Team | P0 | td-sli-2026-4.4 |

**Phase 4 Deliverables** (All ✅ COMPLETE):
- `TurboQuantKVCache` with INT8 and INT4
- Adaptive compression based on sequence length
- Cache management and updates
- Accuracy validation suite (CRITICAL)
- **Target: 4x compression with <1% accuracy loss** ✅ VALIDATED

**See**: [anigma/IMPLEMENTATION_SUMMARY_PHASE4_TURBOQUANT_KV_CACHE.md](anigma/IMPLEMENTATION_SUMMARY_PHASE4_TURBOQUANT_KV_CACHE.md) for full details.

---

### Phase 5: Isolation & Seam Deepening (Weeks 13-15) - **40 points**
**TD ID**: td-sli-2026-phase5  
**Status**: NOT STARTED  
**Priority**: P0  
**Goal**: Enforce strict isolation for hardware-saturated tasks and implement zero-copy handle passing.

| TD ID | Task | Points | Status | Assignee | Priority | Depends On |
|-------|------|--------|--------|----------|----------|------------|
| td-sli-2026-5.1 | **Implement SaturatedMemoryAuthority (IOSurface)** | 8 | Not Started | Core Team | P0 | td-sli-2026-1.2 |
| td-sli-2026-5.2 | Refactor MetalTransformExecutor to use Authority | 5 | Not Started | Core Team | P0 | td-sli-2026-5.1 |
| td-sli-2026-5.3 | Implement IOSurfaceID passing in `MLWorkerInput` | 8 | Not Started | Core Team | P0 | td-sli-2026-5.1 |
| td-sli-2026-5.4 | **Extract CoreML Computation to isolated MLWorker** | 8 | Not Started | ML Team | P0 | td-sli-2026-5.3 |
| td-sli-2026-5.5 | Implement MLWorker Proxy in `anigmad` | 3 | Not Started | Core Team | P0 | td-sli-2026-5.4 |
| td-sli-2026-5.6 | Subprocess Crash Recovery for ANE/GPU Jetsam | 8 | Not Started | Core Team | P0 | None |

**Phase 5 Deliverables**:
- `SaturatedMemoryAuthority` mandating IOSurface backing for zero-copy continuity.
- Isolated `MLWorkerExecutable` handling all CoreML/ANE workloads.
- Zero-copy IPC passing `IOSurfaceID`s instead of raw data arrays.
- Fault-tolerant daemon that survives hardware-unit worker crashes.

---

### Phase 6: Hybrid Execution (Weeks 16-19) - **35 points**
**TD ID**: td-sli-2026-phase6  
**Status**: NOT STARTED  
**Priority**: P0  
**Goal**: Integrate GPU and ANE acceleration with adaptive scheduling.
**Depends On**: td-sli-2026-phase1, td-sli-2026-phase4, td-sli-2026-phase5

| TD ID | Task | Points | Status | Assignee | Priority | Depends On |
|-------|------|--------|--------|----------|----------|------------|
| td-sli-2026-6.1 | Implement GPUInferenceDispatcher | 5 | Not Started | GPU Team | P0 | td-sli-2026-5.1 |
| td-sli-2026-6.2 | Implement FusedGPUANEDispatcher (M5 Metal 4) | 5 | Not Started | GPU Team | P0 | td-sli-2026-6.1 |
| td-sli-2026-6.3 | **Implement MPS-Based Megakernels** | 8 | Not Started | GPU Team | **P0 (HIGH RISK)** | td-sli-2026-6.2 |
| td-sli-2026-6.4 | Implement Decode Kernels | 3 | Not Started | GPU Team | P0 | td-sli-2026-6.3 |
| td-sli-2026-6.5 | Implement HybridInferenceEngine | 5 | Not Started | Core Team | P0 | td-sli-2026-6.1, td-sli-2026-6.2, td-sli-2026-6.3 |
| td-sli-2026-6.6 | Implement Adaptive Scheduling | 3 | Not Started | Core Team | P0 | td-sli-2026-6.5 |
| td-sli-2026-6.7 | Implement Fallback Paths | 3 | Not Started | Core Team | P0 | td-sli-2026-6.5 |
| td-sli-2026-6.8 | End-to-End Performance Testing | 3 | Not Started | Perf Team | P0 | All Phase 6 tasks |

**Phase 6 Deliverables**:
- `GPUInferenceDispatcher` with MPS
- `ANEDispatcher` with Metal 4 Tensor APIs
- Metal megakernels for prefill and decode
- `HybridInferenceEngine` orchestrator
- Adaptive scheduling with backpressure
- **Target: 10,000+ tokens/sec on GPU**

---

### Phase 7: Production Hardening (Weeks 20-22) - **35 points**
**TD ID**: td-sli-2026-phase7  
**Status**: NOT STARTED  
**Priority**: P0  
**Goal**: Prepare for production deployment.
**Depends On**: All previous phases

| TD ID | Task | Points | Status | Assignee | Priority | Depends On |
|-------|------|--------|--------|----------|----------|------------|
| td-sli-2026-7.1 | Comprehensive Test Suite | 5 | Not Started | QA Team | P0 | All previous tasks |
| td-sli-2026-7.2 | Memory Leak Testing | 3 | Not Started | QA Team | P0 | td-sli-2026-7.1 |
| td-sli-2026-7.3 | Stress Testing | 5 | Not Started | QA Team | P0 | td-sli-2026-7.1 |
| td-sli-2026-7.4 | Power/Thermal Testing | 3 | Not Started | QA Team | P0 | td-sli-2026-7.1 |
| td-sli-2026-7.5 | Documentation | 5 | Not Started | Docs Team | P0 | All previous tasks |
| td-sli-2026-7.6 | Benchmarking Suite | 3 | Not Started | Perf Team | P0 | td-sli-2026-7.1 |
| td-sli-2026-7.7 | CI/CD Integration | 3 | Not Started | DevOps Team | P0 | td-sli-2026-7.1, td-sli-2026-7.6 |
| td-sli-2026-7.8 | Final Performance Validation | 5 | Not Started | Perf Team | P0 | All Phase 7 tasks |

**Phase 6 Deliverables**:
- Comprehensive test suite (95%+ coverage)
- Stress and load testing results
- Power/thermal analysis
- Complete documentation
- CI/CD pipeline integration
- Production validation report

