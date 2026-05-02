# Anigma Roadmaps Directory

Welcome to the Anigma architectural roadmaps. This directory contains strategic long-term planning documents that guide major infrastructure initiatives.

---

## Active Roadmaps (P0 Priority)

## Active Roadmaps (P0 Priority)

### 🎬 Polytropos Saturated Media Backend Architecture
**Status**: ✅ Comprehensive Spec Complete → Phase 0 Approval Pending
**Owner**: Anigma Media Infrastructure
**Scope**: 6 phases spanning 8-12 weeks
**Priority**: 🔴 P0 (Highest)

Governed, unified media architecture for **Video, Audio, and Images**. Features an Apple-native primary path (VideoToolbox, AudioToolbox, ImageIO, CoreImage, Metal), with FFmpeg and isolated tools as subprocess fallbacks. **Phase 0 substrate is a blocker to all other phases.**

**Key Design Principles**:
- Media-wide substrate (Phase 0) covering Video, Audio, and Images
- SaturatedMemoryAuthority owns all live frames and buffers
- MaterializationGate approves copies (creates audit trail)
- Specialized references: FrameReference, AudioBufferReference, ImageSurfaceReference
- Apple/System frameworks are primary; fallbacks are isolated subprocesses
- Every operation produces MediaCopyProof (copiedBytes + events)

#### 📖 READ FIRST: Comprehensive Specification

**→ [POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md](POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md)** (Single source of truth for architecture)

This document contains everything: unified media paths, three-tier design, Phase 0 substrate, implementation roadmap, acceptance gates, and success criteria. Start here.

#### 📚 Supporting Documents

- **[POLYTROPOS_CODEC_LICENSING_DOCTRINE.md](POLYTROPOS_CODEC_LICENSING_DOCTRINE.md)** — ⚠️ CRITICAL: Why Anigma uses system frameworks, NOT custom codec implementations (licensing/IP)
- **[POLYTROPOS_WHY_PHASE_0_CRITICAL.md](POLYTROPOS_WHY_PHASE_0_CRITICAL.md)** — Architectural justification for Phase 0 (why it changes everything)
- **[FFMPEG_LINKING_ANALYSIS.md](FFMPEG_LINKING_ANALYSIS.md)** — Why FFmpeg linking is hard; why subprocess approach is right
- **[POLYTROPOS_RED_LINES_SUMMARY.md](POLYTROPOS_RED_LINES_SUMMARY.md)** — 8 critical corrections from architecture review (reference for design history)

#### ❌ Deprecated Documents (Consolidated)

The following documents have been consolidated into the comprehensive spec and are retained for historical reference only:
- `FFMPEG_SATURATED_METAL_INTEGRATION.md` (⚠️ Outdated — see comprehensive spec)
- `FFMPEG_SATURATED_EXECUTIVE_SUMMARY.md` (⚠️ Outdated — see comprehensive spec)
- `FFMPEG_SATURATED_QUICK_REFERENCE.md` (⚠️ Outdated — see comprehensive spec)
- `FFMPEG_SATURATED_ARCHITECTURE_DIAGRAMS.md` (⚠️ Outdated — see comprehensive spec)
- `POLYTROPOS_SATURATED_MEDIA_DOCTRINE.md` (⚠️ Consolidated into comprehensive spec)
- `POLYTROPOS_ZERO_COPY_SUBSTRATE.md` (⚠️ Consolidated into comprehensive spec Part 3)

#### Phases at a Glance
| Phase | Title | Duration | Status | Blocker |
|-------|-------|----------|--------|---------|
| **0** | **Media-Wide Substrate** | **2-3w** | **🔴 APPROVAL PENDING** | **Blocks all others** |
| 1 | Unified Contracts & Registry | 2-3w | 📋 Blocked by Phase 0 | Depends on Phase 0 |
| 2 | Apple-Native Backends | 2-3w | 📋 Blocked by Phase 1 | Depends on Phase 1 |
| 3 | Transform Engines & DSP | 1-2w | 📋 Blocked by Phase 2 | Depends on Phase 2 |
| 4 | Observability & Integration | 1-2w | 📋 Blocked by Phase 3 | Depends on Phase 3 |
| 5 | Fallbacks & Bridge Migration | 1-2w | 📋 Blocked by Phase 4 | Depends on Phase 4 |

**CRITICAL**: Phase 0 (media-wide substrate) must be completed and approved first. It blocks all other phases.
#### How to Proceed
1. **Read POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md** (40+ min, all phases + rationale)
2. **Review POLYTROPOS_WHY_PHASE_0_CRITICAL.md** (10+ min, why Phase 0 matters)
3. **Check FFMPEG_LINKING_ANALYSIS.md** (10+ min, context on FFmpeg challenges)
4. **Approve Phase 0 architecture with council**
5. **Allocate team for Phase 0 implementation** (2-3 weeks)
6. **Execute Phase 0** (SurfaceAuthority, MaterializationGate, linter, 8 acceptance gates)
7. **Proceed to Phase 1** (upon Phase 0 completion)

---

### 🎯 Messaging & Coordination Foundations
**Status**: Planning → Phase 1 Ready  
**Owner**: Anigma Architecture Council  
**Scope**: 6 phases spanning 8+ weeks  

### ⚡ Technical Optimizations
**Status**: 📋 Queued  
**Owner**: Anigma Engineering Team  
**Scope**: Data Structures (Bloom, Trie), Protocols (gRPC, SSE), and MCP 1.2 Upgrades

Three first-class messaging subsystems without external broker dependencies:
- **EventLog**: Kafka-like append-only event streams
- **WorkQueue**: RabbitMQ-like durable job broker
- **EphemeralCoordinator**: Valkey-like transient coordination

#### Documents
1. **MESSAGING_AND_COORDINATION_FOUNDATIONS.md** — Epic overview
   - Vision, scope, architecture constraints
   - Six-phase roadmap
   - Acceptance criteria, success metrics
   - Non-goals, risks, mitigations
   - Canonical doctrine

2. **PHASE_1_SEMANTIC_FOUNDATIONS.md** — Implementation blueprint
   - 21 type definitions with full code
   - 3 protocol definitions
   - 3 in-memory test doubles
   - Testing strategy
   - Acceptance checklist

3. **MESSAGING_FOUNDATIONS_QUICK_REFERENCE.md** — One-page summary
   - Quick lookup for each subsystem
   - Architecture constraints digest
   - Phase breakdown table
   - FAQ and contribution guide

#### Key Principles
- **No external brokers required** for local development
- **Postgres is the ledger, not the nervous system**
- **Tier separation** enforced (contracts → enforcement → consumption)
- **Governance everywhere** (receipts, signatures, audit trails)
- **Payloads are references** (use Vault/CAS, not embedded data)

#### Phases at a Glance
| Phase | Title | Duration | Status |
|-------|-------|----------|--------|
| 1 | Semantic Foundations | 2-3w | 🔄 Ready |
| 2 | Local Durable Implementation | 2-3w | 📋 Queued |
| 3 | Observability Integration | 1-2w | 📋 Queued |
| 4 | IoT/Ingest Readiness | 1w | 📋 Queued |
| 5 | External Adapter Readiness | 1w | 📋 Queued |
| 6 | Deployment Decision | Ongoing | 📋 Queued |

#### How to Proceed
1. Read **MESSAGING_AND_COORDINATION_FOUNDATIONS.md** for full vision
2. Review **PHASE_1_SEMANTIC_FOUNDATIONS.md** for code details
3. Use **MESSAGING_FOUNDATIONS_QUICK_REFERENCE.md** as lookup guide
4. Approve roadmap with architecture council
5. Allocate 1 architect + 1-2 engineers for Phase 1
6. Execute Phase 1 (2-3 weeks)
7. Continue through remaining phases

---

## Completed Initiatives

### ✅ Isolation & Governance Track (April 2026)
**Status**: Complete and tested (25/25 tests passing)  
**Deliverables**: 6 tasks, 7 implementation files, 25 tests

**Tasks**:
- td-ebd0ea: SidecarPDFService
- td-a6bc08: PDFSidecar IPC Contract
- td-f5a5ef: Native Geometry Pro Path (Metal)
- td-f6b361: Native Media Pro Path (Accelerate)
- td-f7c62c: Database Receipt Enforcement
- td-c9e8eb: Inference Provenance (MLX)

**Artifacts**:
- 7 production-ready implementation files (58 KB)
- 2 test suites (PDFSidecar + End2End integration)
- 25 tests, all passing

**Documentation**:
- Detailed technical decisions and trade-offs
- Architecture patterns established
- Governance receipt model defined

---

## How to Read These Documents

### For Architects
1. Start with **MESSAGING_AND_COORDINATION_FOUNDATIONS.md**
2. Review **Architecture Constraints** section
3. Check **Canonical Doctrine** for core principles
4. Plan Phase allocations

### For Implementation Teams
1. Read **PHASE_1_SEMANTIC_FOUNDATIONS.md**
2. Find the specific type/protocol you're implementing
3. Use the code examples as templates
4. Verify against acceptance criteria
5. Refer to **MESSAGING_FOUNDATIONS_QUICK_REFERENCE.md** for quick lookups

### For Reviewers
1. Check **MESSAGING_AND_COORDINATION_FOUNDATIONS.md** for scope alignment
2. Review **Acceptance Criteria** sections
3. Verify no external dependencies introduced
4. Confirm governance receipts on all operations
5. Validate tier separation constraints

### For Product Managers
1. Skim **Vision** in epic roadmap
2. Review **Six-Phase Roadmap** section
3. Check **Success Metrics**
4. Plan stakeholder communication based on phase timeline

---

## Key Concepts Glossary

### EventLog (Kafka-like)
Append-only event stream with replayable cursors. Used for daemon events, agent traces, IoT ingest, audit trails. **Protocol**: `append`, `subscribe`, `replay`, `checkpoint`. **Initial impl**: Local append-only (SQLite/Postgres). **Future**: Kafka adapter.

### WorkQueue (RabbitMQ-like)
Durable job broker with leases, retries, dead-letters. Used for daemon jobs, indexing, OCR, rendering, agent execution. **Protocol**: `enqueue`, `claim`, `acknowledge`, `nack`, `recover`. **Initial impl**: Postgres/SQLite job table. **Future**: RabbitMQ adapter.

### EphemeralCoordinator (Valkey-like)
Transient coordination with TTL-based leases, presence, rate limits. Used for worker coordination, short-lived locks, rate limiting. **Protocol**: `acquire`, `refresh`, `release`, `presence`, `rateLimit`. **Initial impl**: In-process actor or SQLite. **Future**: Valkey adapter.

### Tier 1 (Contracts)
ContractsCore package. Defines all types, envelopes, policies, validation rules. **No I/O, No persistence**. Types only.

### Tier 2 (Execution Authority)
ExecutionAuthority in AnigmaCore. Owns runtime enforcement of contracts. Implements protocols (local or persistent). Emits receipts. Manages governance context.

### Tier 3+ (Features)
All other modules (daemon, capabilities, services). **No direct database access to queue/event tables**. Consume through Tier 2 authorities only.

### PayloadReference
Pointer to data stored elsewhere (Vault/CAS). All large payloads use this, never embedded. Keeps messages small and hot path fast.

### Governance Context
Metadata attached to every message/job/event: schema version, provenance, source capability, project scope, governance decision. Used for audit trails and compliance.

### Receipt
Signed acknowledgment of operation. Every append/enqueue/claim emits one. Includes operation details, timestamp, signature. Forms immutable audit trail.

### Postgres as Ledger
Postgres can persist queue state, event logs, worker leases. **But Postgres is not the owner of semantics**. Anigma owns queue/event/coordination logic. Postgres is persistence mechanism only, replaceable.

### No External Brokers Required
Default build compiles without Kafka, RabbitMQ, Redis, Valkey. All three subsystems work locally. External systems added in Phase 5 as optional feature-flagged adapters.

---

## Files in This Directory

```
roadmaps/
├── POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md  (✅ PRIMARY: All phases + rationale)
├── POLYTROPOS_CODEC_LICENSING_DOCTRINE.md                   (⚠️ CRITICAL: Why VideoToolbox, not custom codecs)
├── POLYTROPOS_WHY_PHASE_0_CRITICAL.md                       (Architecture rationale)
├── POLYTROPOS_RED_LINES_SUMMARY.md                          (8 corrections from review)
├── FFMPEG_LINKING_ANALYSIS.md                               (Why linking is hard)
│
├── [DEPRECATED — See comprehensive spec above]
├── FFMPEG_SATURATED_METAL_INTEGRATION.md                    (Archived — outdated)
├── FFMPEG_SATURATED_EXECUTIVE_SUMMARY.md                    (Archived — outdated)
├── FFMPEG_SATURATED_QUICK_REFERENCE.md                      (Archived — outdated)
├── FFMPEG_SATURATED_ARCHITECTURE_DIAGRAMS.md                (Archived — outdated)
├── POLYTROPOS_SATURATED_MEDIA_DOCTRINE.md                   (Archived — consolidated)
├── POLYTROPOS_ZERO_COPY_SUBSTRATE.md                        (Archived — consolidated)
│
├── MESSAGING_AND_COORDINATION_FOUNDATIONS.md                (Messaging epic, 6 phases)
├── PHASE_1_SEMANTIC_FOUNDATIONS.md                          (Messaging Phase 1 spec)
├── PHASE_2_LOCAL_DURABLE_IMPLEMENTATION.md                  (Messaging Phase 2 spec)
├── PHASE_2_SCHEDULER_INTEGRATION_AND_TESTING.md             (Messaging Phase 2 integration)
├── MESSAGING_FOUNDATIONS_QUICK_REFERENCE.md                 (Messaging quick reference)
│
├── TECHNICAL_OPTIMIZATIONS_ROADMAP.md                       (Data structures, protocols, MCP 1.2)
└── README.md                                                 (This file)
```

---

## Common Questions

**Q: Why three subsystems instead of one message bus?**  
A: EventLog, WorkQueue, and EphemeralCoordinator have different semantics (append-only, brokered jobs, transient coordination). Conflating them leads to compromises. Better to have three clean ports.

**Q: Do I need Kafka/RabbitMQ/Redis?**  
A: No for local development. All three have local implementations. External systems are Phase 5 optional adapters. Promoted to required only when local limits exceeded (Phase 6).

**Q: Can my module import the queue table directly?**  
A: No. Only Tier 2 (ExecutionAuthority) owns persistence. Tier 3+ consumes through protocols. This prevents tight coupling and enables adapter swapping.

**Q: Where do large payloads go?**  
A: Vault/CAS (Content-Addressed Storage). Messages carry `PayloadReference` pointers, not embedded data. Keeps hot path fast and messages small.

**Q: How do I know if an operation succeeded?**  
A: Every operation emits a signed `Receipt`. Check the receipt, not the operation return value. Receipts form immutable audit trail.

**Q: What if Postgres can't handle the load?**  
A: Phase 6 decision gate. Only then promote external adapters to required dependencies. Measured workload data informs decision.

**Q: How do I switch from local to Kafka?**  
A: Implement `KafkaEventLogAdapter` (Phase 5). All Tier 3 code stays unchanged. Same protocol. Swap at initialization time.

---

## Getting Involved

### Phase 1 Contributors
- Architect (1 FTE): Design review, protocol definition
- Engineers (2 FTE): Type definitions, in-memory test doubles, tests

**Duration**: 2-3 weeks  
**Deliverables**: 21 types, 3 protocols, 3 test doubles, 150+ tests

### Phase 2 Contributors
- Engineer (1-2 FTE): SQLite/Postgres persistence, scheduler integration
- Engineer (1 FTE): Lease recovery loop, dead-letter handling

**Duration**: 2-3 weeks

### Phase 3-6 Contributors
See roadmap for phase-specific needs.

---

## Decision Gates

| Gate | Approval Required | Trigger |
|------|-------------------|---------|
| Start Phase 1 | Architecture Council | Roadmap sign-off |
| Start Phase 2 | Phase 1 completion | All tests passing |
| Promote Adapter | Engineering Lead | Local workload exceeds limits |

---

## Architecture Council Decisions

- ✅ **Three distinct subsystems** (EventLog, WorkQueue, EphemeralCoordinator)
- ✅ **Tier separation** (Tier 1 contracts, Tier 2 enforcement, Tier 3 consumption)
- ✅ **No external brokers required** for default build
- ✅ **Postgres as ledger** (persists state, doesn't own semantics)
- ✅ **Governance everywhere** (receipts on all operations)
- ✅ **Payloads are references** (use Vault/CAS)
- ✅ **Six-phase roadmap** (Phase 1 semantic foundations through Phase 6 deployment decision)

---

## Status Dashboard

| Component | Phase | Status | Last Updated |
|-----------|-------|--------|--------------|
| Epic Roadmap | Planning | ✅ Complete | 2026-04-24 |
| Phase 1 Spec | Planning | ✅ Complete | 2026-04-24 |
| Quick Reference | Planning | ✅ Complete | 2026-04-24 |
| Tracking Tables | Planning | ✅ Complete | 2026-04-24 |
| Phase 1 Impl | — | 🔄 Ready | — |
| Phase 2 Impl | — | 📋 Queued | — |
| Phase 3 Impl | — | 📋 Queued | — |
| Phase 4 Impl | — | 📋 Queued | — |
| Phase 5 Impl | — | 📋 Queued | — |
| Phase 6 Decision | — | 📋 Queued | — |

---

## Next Steps

1. **Review** these documents with architecture council
2. **Approve** roadmap and canonical doctrine
3. **Allocate** team for Phase 1
4. **Kick off** Phase 1 implementation
5. **Execute** 2-3 week Phase 1
6. **Approve** move to Phase 2
7. **Continue** through remaining phases

---

**Owner**: Anigma Architecture Council  
**Created**: 2026-04-24  
**Status**: 🎉 Ready for Phase 1 Kickoff  

For questions or clarifications, consult the specific phase document or reach out to the architecture council.
