# Harmonia Migration Phase 2: Comprehensive Roadmap
## V2 to V3 Transition Epic (td-333894)

**Document Version**: 1.0  
**Last Updated**: 2026-04-14  
**Status**: Ready for Implementation  
**Owner**: Backend Stabilization Track  

---

## 📋 Executive Summary

This document provides a comprehensive roadmap for Phase 2 of the Harmonia V2→V3 migration, targeting 50-70% functionality by migrating 20-30% additional components through the HarmoniaRuntime facade.

### Current State (2026-04-14)
- ✅ **Phase 1 Complete**: HarmoniaRuntime facade implemented and compiling
- ✅ **30-40% Functionality**: Core query and basic Phase9 (orchestration) working
- ✅ **4/12 Tasks Completed** (33%)
- ✅ **harmonia CLI**: Compiles successfully with degraded capabilities
- 🚀 **Ready to Start**: Phase 2 component migration

### Phase 2 Scope
- **Target**: 50-70% of V2 functionality working through HarmoniaRuntime
- **Timeline**: 3-6 months
- **Component Coverage**: 20-30% of adaptable components
- **Key Focus**: Replace stubs with real backend seams

---

## 🎯 Phase 2 Objectives

### Primary Objectives
1. **Replace Stub Services** with real backend implementations
2. **Define Clear Boundaries** between V2, V3, and runtime layers
3. **Establish Governance** authority and policy enforcement
4. **Integrate Observability** with canonical telemetry contracts
5. **Migrate Tool Execution** through governed dispatch

### Success Criteria
- [ ] Harmonia Conductor routes through HarmoniaRuntime facade
- [ ] Document-analysis lane returns controlled results with receipts
- [ ] Tool execution emits deterministic receipts and audit events
- [ ] Memory backend seams are non-stub and functional
- [ ] 50-70% of legacy functionality working through clean facade
- [ ] All Phase 2 tasks approved and closed
- [ ] Build remains at 0 errors

---

## 📊 Phase 2 Task Inventory

### Quick Reference Table

| Task ID | Title | Status | Priority | Estimate | Dependencies | Impact |
|---------|-------|--------|----------|----------|--------------|--------|
| td-0cb66d | Implement Harmonia Conductor | in_review | P1 | 2-3 weeks | None | **20 tasks** |
| td-1edbaa | Wire memory backend seams | in_progress | P1 | 2-3 weeks | td-01c59f, td-003af2 | **18 tasks** |
| td-e3b75e | Wire tool execution contract | in_progress | P1 | 2 weeks | td-cd1576, td-d55939 | **20 tasks** |
| td-8d067f | Define governance boundaries | in_progress | P1 | 1-2 weeks | td-ab16d6, td-cd1576 | **15 tasks** |
| td-a1ff61 | Integrate telemetry flow | in_progress | P1 | 2 weeks | td-16ca40, td-e07fd5 | **12 tasks** |

**Total Phase 2 Impact**: 85 downstream tasks unblocked

---

## 🔗 Dependency Analysis

### Dependency Graph

```
Phase 2 Tasks:

┌─────────────────────────────────────────────────────┐
│                  PHASE 1 COMPLETE                   │
│  HarmoniaRuntime Facade + ReceiptSpine + Audit    │
│              (Foundation for Phase 2)               │
└────────────┬────────────────────────────┬───────────┘
             │                            │
    ┌────────┴─────────┐         ┌───────┴──────────┐
    │  Task td-0cb66d  │         │   Task td-8d067f │
    │  Conductor impl. │         │ Governance bound.│
    │  Status: closed  │         │ Status: in_prog. │
    └────────┬─────────┘         └───────┬──────────┘
             │                            │
    ┌────────┴─────────────────┬──────────┴───────────┐
    │                          │                      │
│  Task td-e3b75e  │          │   Task td-1edbaa  │
│  Tool execution  │          │   Memory wiring   │
│  Status: in_prog │          │   Status: in_prog │
└──────┬───────────┘          └──────┬────────────┘
       │                             │
       │                    ┌────────┴──────────┐
       │                    │                   │
       │              ┌─────▼──────┐     ┌──────▼───────┐
       │              │ Contextum  │     │ ML/Inference │
       │              │ Integration│     │ Backend      │
       │              └────────────┘     └──────────────┘
       │
       └──────────────────────────┐
                                  │
                          ┌───────▼────────┐
                          │  Task td-a1ff61│
                          │  Telemetry int.│
                          └────────────────┘
```

### Critical Dependencies

**Blocking External Tasks** (must resolve before Phase 2 can complete):
1. **td-01c59f**: Define personal-context retrieval quality contract (in_progress)
   - Blocks: td-1edbaa (memory wiring)
   - Impact: Can't wire memory until retrieval contract defined

2. **td-003af2**: Score ingest fidelity and surface degraded-context warnings (open)
   - Blocks: td-1edbaa (memory wiring)
   - Impact: Can't validate memory quality metrics

3. **td-cd1576**: Implement executable policy gates (open)
   - Blocks: td-8d067f, td-e3b75e (governance, tool execution)
   - Impact: Can't enforce policy without gates

4. **td-16ca40**: Agent observability spine (open)
   - Blocks: td-a1ff61 (telemetry integration)
   - Impact: Can't integrate telemetry without spine

### Recommended Task Order

**Order 1 (Least Blocked)**: td-0cb66d (Conductor)
- Status: Closed (can proceed to integration)
- No blocking dependencies
- Unblocks: 20+ downstream tasks
- **Action**: Start now - review implementation

**Order 2 (Can Start Parallel)**: td-8d067f (Governance Boundaries)
- Blocking Tasks: td-ab16d6, td-cd1576
- Status: Can start design phase independently
- Unblocks: 15+ downstream tasks
- **Action**: Start design, finalize with blocker resolution

**Order 3 (Can Start with Dependencies)**: td-e3b75e (Tool Execution)
- Blocking Tasks: td-cd1576, td-d55939
- Status: Can start contract definition
- Unblocks: 20+ downstream tasks
- **Action**: Create tool dispatch contract, wait for gates

**Order 4 (Moderate Blockage)**: td-1edbaa (Memory Wiring)
- Blocking Tasks: td-01c59f (in_progress), td-003af2 (open)
- Status: td-01c59f is in progress, should unblock soon
- Unblocks: 18+ downstream tasks
- **Action**: Wait 1-2 weeks, then start

**Order 5 (Highest Blockage)**: td-a1ff61 (Telemetry)
- Blocking Tasks: td-16ca40 (open), td-e07fd5 (in_progress), td-76ac32 (open)
- Status: Can start design, heavy blockage on implementation
- Unblocks: 12+ downstream tasks
- **Action**: Start design, coordinate with observability team

---

## 🚀 Quick Wins Identified

### Quick Win #1: Conductor Implementation Review
**Task**: td-0cb66d  
**Status**: Closed (implementation done)  
**Effort**: 2-3 days  
**Scope**: Review current Conductor implementation, validate acceptance criteria  
**Why Quick Win**:
- Implementation already exists
- No external blockers
- Foundation for rest of Phase 2
- Will unblock many tasks

**Next Step**: Review evidence and test integration

---

### Quick Win #2: Governance Authority Matrix (Design Phase)
**Task**: td-8d067f  
**Status**: In review (design ready)  
**Effort**: 1 week  
**Scope**: Document authority ownership, create policy matrix  
**Why Quick Win**:
- Can start design independently
- Unblocks tool execution and memory wiring
- Clear scope and deliverables
- No code changes required initially

**Next Step**: Create authority matrix document

---

### Quick Win #3: Memory Backend Audit
**Related to**: td-1edbaa  
**Status**: Open (investigation phase)  
**Effort**: 3-5 days  
**Scope**: Audit current memory stubs, identify real backend options  
**Why Quick Win**:
- Can start while blockers resolve
- Prep work for implementation
- Reduces implementation time later
- Low risk investigation

**Next Step**: Audit memory stubs and document integration points

---

### Quick Win #4: Tool Execution Contract (Design)
**Task**: td-e3b75e  
**Status**: In review (contract design)  
**Effort**: 1 week  
**Scope**: Define tool dispatch contract, create interface signatures  
**Why Quick Win**:
- Can design independently of policy gates
- Clarifies scope for implementation
- Integrates with td-8d067f (governance)
- Low risk design phase

**Next Step**: Create tool execution contract specification

---

## 📝 Detailed Task Specifications

### Task 1: td-0cb66d - Implement Harmonia Conductor

**Current Status**: Closed (Implementation complete, awaiting integration review)

**Description**:
Introduce Harmonia Conductor as the V3 target orchestration system behind HarmoniaRuntime facade. Replace direct Phase9 usage with clean conductor-backed orchestration that owns execution context, run identity, lifecycle state, policy checkpoints, receipt hooks, and telemetry hooks.

**Acceptance Criteria**:
- [x] HarmoniaRuntime exposes Conductor-backed orchestration entrypoint
- [x] Execution context ownership is explicit
- [x] Run identity and lifecycle managed by Conductor
- [x] Policy checkpoints integrated
- [x] Receipt and telemetry hooks wired
- [x] Document analysis lane routes: CLI → HarmoniaRuntime → Conductor → lane
- [x] Missing capabilities return typed deferred results
- [x] Roadmap updated to reference Conductor as target architecture

**Evidence Required**:
- Implementation source code with Conductor interface
- Test cases covering success and deferred paths
- Build verification (swift build --product harmonia)
- Runtime execution test output

**Verification Approach**:
1. Build harmonia executable: `swift build --product harmonia`
2. Test basic query: `harmonia query "test"`
3. Test phase9 command: `harmonia phase9 "analyze document"`
4. Verify receipt generation in output
5. Check audit events logged

**Success Metrics**:
- Harmonia CLI compiles without errors
- Query execution returns results with receipts
- Phase9 execution returns controlled results
- No direct HarmoniaModule calls on execution path
- Build time < 3 minutes

**Estimated Effort**: 2-3 weeks (review + integration)

**Owner**: Architecture team + implementation session

**Next Actions**:
1. Review current implementation evidence
2. Validate acceptance criteria met
3. Test runtime execution paths
4. Integrate with phase 2 roadmap
5. Approve and mark ready for downstream tasks

---

### Task 2: td-8d067f - Define Governance Authority Boundaries

**Current Status**: In review (design phase)

**Description**:
Establish explicit governance authority ownership and policy gate responsibilities for HarmoniaRuntime command/query/tool actions. Create authority matrix covering evaluate/submit/receipt stages.

**Acceptance Criteria**:
- [ ] Authority matrix documents ownership for all runtime actions
- [ ] Policy checks tied to concrete runtime boundaries
- [ ] Authority chain: evaluate → submit → receipt clearly documented
- [ ] TD links to trust/policy tracks recorded
- [ ] Violating paths fail closed with auditable reason codes
- [ ] Authority matrix includes:
  - Query execution authority
  - Conductor action authority
  - Tool execution authority
  - Memory access authority
  - Receipt generation authority
- [ ] Governance boundaries specified in code (e.g., enums, types)

**Deliverables**:
- Authority matrix document (GOVERNANCE_AUTHORITY_MATRIX.md)
- Policy gate type definitions in HarmoniaRuntime
- Reason codes for policy violations
- TD links documenting authority chain
- Code comments showing authority ownership

**Verification Approach**:
1. Review authority matrix document
2. Verify all runtime actions covered
3. Check reason codes documented
4. Validate TD links present
5. Build and test authority enforcement

**Success Metrics**:
- Authority matrix covers 100% of runtime actions
- Zero ambiguous policy boundaries
- Reason codes are exhaustive and clear
- All authority gates have reason codes
- Build validates authority types

**Estimated Effort**: 1-2 weeks

**Blockers**:
- td-ab16d6 (Authority and trust labels for agent context)
- td-cd1576 (Executable policy gates)

**Depends On**:
- Phase 1 completion (HarmoniaRuntime stable)
- Receipt spine (for audit trail)

**Next Actions**:
1. Document current authority assumptions
2. Create authority matrix skeleton
3. Identify missing authority definitions
4. Link to trust/policy tasks in TD
5. Design fail-closed mechanisms

---

### Task 3: td-e3b75e - Wire Tool Execution Runtime Contract

**Current Status**: In progress (contract design)

**Description**:
Define executable-safe tool dispatch contract in HarmoniaRuntime. Connect to canonical tool authority path. Replace direct HarmoniaModule tool wiring with governed dispatch through HarmoniaRuntime.

**Acceptance Criteria**:
- [ ] Tool calls from HarmoniaRuntime routed through single governed contract
- [ ] Tool denials explicit with receipt-backed reason codes
- [ ] No legacy HarmoniaModule direct tool wiring on executable path
- [ ] Tool dispatch contract includes:
  - Authorization check (who can execute)
  - Capability check (what tools are available)
  - Execution guard (safe execution paths)
  - Result receipt (auditable outcome)
- [ ] Deterministic CLI/runtime integration test passes
- [ ] Tool execution emits audit events with evidence reference

**Contract Specification**:
```
ToolExecutionContract:
  - Authorization: (toolName, userId, policyContext) -> permit/deny
  - Capability: (toolName) -> ToolCapability? (nil = not implemented)
  - Execute: (toolName, args, context) async -> ToolResult
  - Result includes:
    - success/failure status
    - return value or error
    - receipt reference
    - audit event reference
```

**Deliverables**:
- Tool dispatch contract interface
- Authorization service integration
- Capability discovery mechanism
- Execution guard wiring
- Test cases for:
  - Successful tool execution with permit
  - Denied tool execution with reason code
  - Missing tool with not-implemented result
  - Direct HarmoniaModule tool calls (should fail)

**Verification Approach**:
1. Create tool dispatch contract interface
2. Implement authorization check
3. Test permit/deny scenarios
4. Verify receipts generated
5. Integration test: CLI tool command → HarmoniaRuntime → dispatch → result

**Success Metrics**:
- Tool dispatch contract defined and compiling
- Authorization working with reason codes
- Receipts generated for tool execution
- Zero legacy direct tool calls on path
- Integration test passes

**Estimated Effort**: 2 weeks

**Blockers**:
- td-cd1576 (Executable policy gates)
- td-d55939 (MCP CLI daemon wiring)

**Next Actions**:
1. Define tool dispatch contract interface
2. Sketch authorization logic
3. Plan integration with policy gates
4. Design test cases
5. Identify legacy tool call sites

---

### Task 4: td-1edbaa - Wire Memory and Retrieval Backend Seams

**Current Status**: In progress (blocked by retrieval quality contract)

**Description**:
Convert memory/retrieval seams from stub placeholders to real backend adapters. Inventory marks inference/memory as "adapt-behind-facade" with stub behavior. Replace stubs with controlled not-configured gates or real backend wiring.

**Acceptance Criteria**:
- [ ] HarmoniaRuntime memory/query seam uses real backend adapters (not stubs)
- [ ] Real backends fallback to controlled not-configured gates with reason codes
- [ ] Retrieval provenance fields returned to callers
- [ ] Memory dependencies documented:
  - Contextum integration specified
  - Related store integration specified
  - Fallback behavior defined
- [ ] Targeted runtime checks verify integration
- [ ] Memory backend options documented:
  - Which backends ready (inference memory, embedding store, etc.)
  - Which deferred (vector search, semantic search, etc.)
  - Fallback to V2 stubs marked explicitly

**Backend Options** (from inventory):
1. **Inference Memory**: HarmoniaV2Memory (ready to wire)
   - Provides: Session context, conversation history
   - Status: Compiles, needs ReceiptSpine integration

2. **Contextum Integration**: Contextum module (dependencies TBD)
   - Provides: Context aggregation, store management
   - Status: Requires td-01c59f (retrieval quality contract)

3. **Embedding/Vector**: MLX-based vector search (partial)
   - Provides: Semantic similarity search
   - Status: Deferred (complex number compilation issue)

4. **Fallback**: HarmoniaV2Stubs (current)
   - Provides: No-op responses
   - Status: Replace with real adapters when ready

**Deliverables**:
- Memory backend selection criteria
- Adapter interface for each backend
- Integration layer for Contextum
- Fallback mechanism documentation
- Test cases for each backend option

**Verification Approach**:
1. Identify available backends (grep HarmoniaV2Memory usage)
2. Define adapter interface
3. Wire real backend (start with HarmoniaV2Memory)
4. Test success path (memory available)
5. Test fallback path (memory unavailable)
6. Verify provenance fields present

**Success Metrics**:
- Real backends integrated (at least HarmoniaV2Memory)
- Fallback mechanism working
- Provenance fields present in results
- Contextum integration designed
- Build passes with new backends

**Estimated Effort**: 2-3 weeks

**Blockers**:
- td-01c59f (Retrieval quality contract) - in_progress (blocks full implementation)
- td-003af2 (Ingest fidelity scoring) - open (blocks quality assessment)

**Can Start**: Preparation and backend inventory

**Next Actions**:
1. Audit current memory stubs (find all stub implementations)
2. Document backend options and status
3. Design adapter interface
4. Plan Contextum integration
5. Create fallback mechanism specification

---

### Task 5: td-a1ff61 - Integrate Telemetry and Observability Event Flow

**Current Status**: In progress (high blockage)

**Description**:
Connect HarmoniaRuntime telemetry/observability integration from migration notes to canonical trace/event/artifact contracts. Emit canonical trace context for command/query/tool flows.

**Acceptance Criteria**:
- [ ] HarmoniaRuntime emits canonical trace context for:
  - Query execution flows
  - Conductor orchestration flows
  - Tool execution flows
- [ ] Key runtime events project into observability queries
- [ ] Trace gaps documented
- [ ] Replay semantics defined
- [ ] TD links to td-16ca40 recorded and validated
- [ ] Canonical event types used:
  - CommandStart/CommandEnd
  - QueryStart/QueryEnd
  - ToolStart/ToolEnd
  - Receipt/Audit events
- [ ] Trace correlation across nested calls

**Trace Context Structure**:
```
TraceContext:
  - traceID: Unique flow identifier
  - spanID: Current operation identifier
  - parentSpanID: Caller's span (for nesting)
  - correlationID: User/session identifier
  - timestampMs: Precise timing
  - actionType: query/tool/conductor/etc.
```

**Observability Integration Points**:
1. **Trace Context Propagation**
   - Enter: CLI → HarmoniaRuntime (trace created)
   - Exit: HarmoniaRuntime → result (trace closed)
   - Nested: calls to backends include parentSpanID

2. **Event Emission**
   - CommandStart: CLI → HarmoniaRuntime entry
   - QueryStart/End: Query execution
   - ToolStart/End: Tool dispatch
   - ReceiptGenerated: Audit receipt created
   - AuditEvent: Policy decision logged

3. **Artifact Projection**
   - Traces stored with key events
   - Query history indexed by traceID
   - Tool results linked to traceID
   - Audit events searchable by trace

**Deliverables**:
- Trace context type definitions
- Event emission interface
- Trace correlation logic
- Test cases for trace flows
- Integration with TelemetryCore

**Verification Approach**:
1. Define trace context structure
2. Add trace emission to HarmoniaRuntime operations
3. Verify trace propagation through layers
4. Test trace correlation (nested calls)
5. Verify artifact projection

**Success Metrics**:
- Canonical trace context used in all HarmoniaRuntime operations
- Event emissions present for all operation types
- Trace IDs properly correlated
- Build passes with telemetry integration
- Test shows complete trace flow

**Estimated Effort**: 2 weeks

**Blockers**:
- td-16ca40 (Observability spine) - open (design dependency)
- td-76ac32 (Replace trace_query placeholder) - open (artifact dependency)
- td-e07fd5 (Canonical AgentTrace contract) - in_progress (awaiting definition)

**Can Start**: Design phase (structure, interfaces)

**Next Actions**:
1. Review current TelemetryCore capabilities
2. Define trace context type
3. Identify all HarmoniaRuntime operations needing traces
4. Design event emission interface
5. Link to td-16ca40 and coordinate

---

## 🔄 Recommended Implementation Sequence

### Phase 2 Timeline: Months 1-6

#### **Month 1: Foundation & Design**

| Week | Task | Work |
|------|------|------|
| 1 | All | Documentation kickoff, blockers review |
| 1-2 | td-0cb66d | **Integration Review** - Validate Conductor implementation |
| 1-2 | td-8d067f | **Design** - Authority matrix, policy boundaries |
| 2 | td-e3b75e | **Design** - Tool dispatch contract |
| 2 | td-1edbaa | **Audit** - Memory backend options |
| 2-3 | td-a1ff61 | **Design** - Trace context structure |

**Outcome**: Conductor integrated, designs reviewed, blockers unblocked

#### **Month 2: Early Implementation**

| Week | Task | Work |
|------|------|------|
| 1 | td-8d067f | **Implement** - Authority matrix, type definitions |
| 2 | td-e3b75e | **Implement** - Tool dispatch contract, basic tests |
| 2-3 | td-1edbaa | **Prep** - Backend adapter interfaces |
| 3 | td-a1ff61 | **Implement** - Trace context emission (design-dependent) |

**Outcome**: Governance and tool execution working, telemetry design ready

#### **Month 3: Backend Integration**

| Week | Task | Work |
|------|------|------|
| 1-2 | td-1edbaa | **Implement** - Wire real memory backends |
| 2-3 | All | Resolve external blockers (td-01c59f, td-cd1576) |
| 3 | td-a1ff61 | **Finalize** - Telemetry integration (if blockers resolved) |

**Outcome**: Memory backends working, telemetry integrated

#### **Month 4-6: Integration & Testing**

| Week | Task | Work |
|------|------|------|
| 1-4 | All | Integration testing, cross-task verification |
| 4-8 | All | Bug fixes, performance tuning |
| 9-12 | All | Documentation, approval, Phase 3 planning |

**Outcome**: Phase 2 complete, 50-70% functionality, ready for Phase 3

---

## 🧪 Verification and Testing Strategy

### Phase 2 Verification Gates

**Gate 1: Build Success**
```bash
cd anigma && swift build --product harmonia
```
- Expected: 0 errors, <3 min build time
- Validates: Code changes don't introduce regressions

**Gate 2: Conductor Integration Test**
```bash
harmonia phase9 "analyze document"
```
- Expected: Returns result with receipt and audit event
- Validates: Conductor routing working

**Gate 3: Governance Authority Test**
```bash
harmonia query "test" --policy-context "untrusted"
```
- Expected: Policy check honored, receipt generated
- Validates: Authority boundaries enforced

**Gate 4: Tool Execution Test**
```bash
harmonia tool execute tool_name --args "test"
```
- Expected: Dispatch contract honored, receipt generated
- Validates: Tool execution governed

**Gate 5: Memory Backend Test**
```bash
harmonia query "retrieve from memory"
```
- Expected: Real backend used (or controlled not-configured)
- Validates: Memory wiring working

**Gate 6: Telemetry Test**
```bash
harmonia query "test" --trace-enabled
```
- Expected: Trace events emitted, correlatable
- Validates: Telemetry integration working

**Gate 7: Functionality Test**
```bash
# Run Phase 2 acceptance test suite
swift test --target HarmoniaRuntimeTests
```
- Expected: 100% tests passing
- Validates: Functionality complete

### Success Metrics

**Build Metrics**:
- ✅ 0 compilation errors
- ✅ Build time < 3 min
- ✅ Binary size < 50MB

**Functionality Metrics**:
- ✅ 50-70% of V2 features working
- ✅ All receipts generated correctly
- ✅ Audit trail complete for all operations

**Governance Metrics**:
- ✅ All policy checks enforced
- ✅ Zero policy violations on critical paths
- ✅ 100% reason codes assigned

**Telemetry Metrics**:
- ✅ Trace correlation complete
- ✅ Event emission 100%
- ✅ Observable query/tool/conductor flows

**Code Quality Metrics**:
- ✅ SwiftLint passes
- ✅ Test coverage > 80%
- ✅ Documentation complete

---

## 📋 Task Implementation Checklist

### td-0cb66d: Conductor Implementation (START IMMEDIATELY)

**Status**: Closed (ready for integration review)

```
INTEGRATION CHECKLIST:
[ ] Review implementation evidence
[ ] Verify Conductor interface complete
[ ] Test Phase9 CLI integration
[ ] Check receipt generation
[ ] Validate audit event emission
[ ] Build passes: swift build --product harmonia
[ ] Runtime test: harmonia phase9 "test"
[ ] Approve and mark complete
```

**Verification**: 1-2 days

---

### td-8d067f: Governance Boundaries (CAN START NOW)

**Status**: In review (design phase)

```
DESIGN CHECKLIST:
[ ] Authority matrix identified all runtime actions
[ ] Policy decision points documented
[ ] Reason codes enumerated
[ ] TD links recorded for trust/policy tracks
[ ] Fail-closed mechanisms designed

IMPLEMENTATION CHECKLIST:
[ ] Authority type definitions created
[ ] Policy check interface designed
[ ] Reason codes implemented
[ ] Governance enforcement tests written
[ ] HarmoniaRuntime updated with authority checks
[ ] Build passes
[ ] Runtime verification: authority checks working
[ ] Approve and mark complete
```

**Timeline**: 2-3 weeks (design 1 week, impl 1-2 weeks)

---

### td-e3b75e: Tool Execution Contract (CAN START NOW)

**Status**: In progress (contract design)

```
DESIGN CHECKLIST:
[ ] Tool dispatch contract interface specified
[ ] Authorization component designed
[ ] Capability discovery planned
[ ] Execution guard mechanism sketched
[ ] Test scenarios identified

IMPLEMENTATION CHECKLIST:
[ ] ToolDispatchContract interface created
[ ] Authorization service integrated
[ ] Capability discovery implemented
[ ] Execution guard wired
[ ] Receipt generation for tool execution
[ ] Test cases covering permit/deny/missing
[ ] Legacy tool call sites identified and removed
[ ] Build passes
[ ] Integration test: CLI tool → dispatch → result
[ ] Approve and mark complete
```

**Timeline**: 2-3 weeks (design 1 week, impl 1-2 weeks)

**Parallel Work**: Coordinate with td-8d067f (policy gates)

---

### td-1edbaa: Memory Backend Wiring (START AUDIT NOW)

**Status**: In progress (blocked by td-01c59f, td-003af2)

```
AUDIT CHECKLIST (START NOW):
[ ] Find all memory stub implementations
[ ] Document available backends (HarmoniaV2Memory, Contextum, etc.)
[ ] Identify backend status (ready/partial/deferred)
[ ] Plan adapter interface
[ ] Document Contextum integration points
[ ] Create fallback mechanism design

IMPLEMENTATION CHECKLIST (AFTER BLOCKERS RESOLVE):
[ ] Backend adapter interface created
[ ] HarmoniaV2Memory adapter implemented
[ ] Contextum integration layer added
[ ] Fallback mechanism implemented
[ ] Provenance field mapping defined
[ ] Test cases for success and fallback paths
[ ] Build passes
[ ] Runtime verification: memory backend working
[ ] Approve and mark complete
```

**Timeline**: 1-2 weeks audit (now) + 2-3 weeks impl (after blockers)

**Dependency Monitoring**:
- Check td-01c59f daily (should resolve 1-2 weeks)
- Check td-003af2 status weekly

---

### td-a1ff61: Telemetry Integration (START DESIGN NOW)

**Status**: In progress (high blockage)

```
DESIGN CHECKLIST (START NOW):
[ ] Trace context structure defined
[ ] Event types enumerated
[ ] Correlation mechanism designed
[ ] Artifact projection mechanism planned
[ ] TD links to td-16ca40 recorded

IMPLEMENTATION CHECKLIST (PARTIALLY DEPENDENT ON BLOCKERS):
[ ] TraceContext type created
[ ] Event emission interface designed
[ ] Trace propagation logic added
[ ] Correlation ID management added
[ ] Event emission integrated with all HarmoniaRuntime operations
[ ] TelemetryCore integration added
[ ] Test cases for trace flows
[ ] Build passes
[ ] Runtime verification: traces correlatable
[ ] Approve and mark complete
```

**Timeline**: 1 week design (now) + 2 weeks impl (partially blocked)

**Coordination**: Link with td-16ca40 team weekly

---

## 🎯 Success Criteria for Phase 2 Completion

### Functional Criteria
- [ ] Harmonia Conductor routes all operations through HarmoniaRuntime
- [ ] Document-analysis lane returns results with receipts
- [ ] Tool execution governed through dispatch contract
- [ ] Memory backends wired (real backends or controlled fallback)
- [ ] Telemetry emits canonical trace context
- [ ] 50-70% of V2 functionality working

### Technical Criteria
- [ ] Build succeeds with 0 errors
- [ ] All Phase 2 tasks approved and closed
- [ ] Integration tests pass (100%)
- [ ] No regressions from Phase 1
- [ ] Code follows Swift conventions
- [ ] Documentation updated

### Governance Criteria
- [ ] Authority boundaries documented and enforced
- [ ] Policy checks working on all paths
- [ ] Receipts generated for all operations
- [ ] Audit events complete and traceable
- [ ] Reason codes assigned for all decisions

### Observability Criteria
- [ ] Traces emitted for all operations
- [ ] Events correlatable across layers
- [ ] Query artifacts accessible via trace
- [ ] Tool results linked to operations
- [ ] Audit trail complete

---

## 📚 Deliverables

### Phase 2 Documentation
- [ ] HARMONIA_MIGRATION_PHASE2_ROADMAP.md (this document)
- [ ] GOVERNANCE_AUTHORITY_MATRIX.md (td-8d067f deliverable)
- [ ] TOOL_DISPATCH_CONTRACT.md (td-e3b75e deliverable)
- [ ] MEMORY_BACKEND_INTEGRATION.md (td-1edbaa deliverable)
- [ ] TELEMETRY_INTEGRATION_GUIDE.md (td-a1ff61 deliverable)

### Phase 2 Code Changes
- [ ] Conductor integration in HarmoniaRuntime
- [ ] Authority matrix type definitions
- [ ] Tool dispatch contract implementation
- [ ] Memory backend adapters
- [ ] Telemetry event emission

### Phase 2 Tests
- [ ] Conductor integration tests (td-0cb66d)
- [ ] Authority enforcement tests (td-8d067f)
- [ ] Tool execution tests (td-e3b75e)
- [ ] Memory backend tests (td-1edbaa)
- [ ] Telemetry trace tests (td-a1ff61)

### Phase 2 Evidence
- [ ] Build success output
- [ ] Test results
- [ ] Runtime execution traces
- [ ] Receipt and audit logs
- [ ] Integration test reports

---

## 🔗 Related Documentation

### Primary References
- **Phase 1 Complete**: anigma/Docs/guides/HARMONIA_MIGRATION_EPIC.md
- **Backend Surface**: HARMONIA_BACKEND_SURFACE_INVENTORY_TD14BB05.md
- **HarmoniaRuntime Facade**: anigma/Packages/HarmoniaRuntime/
- **Receipt Spine**: anigma/Packages/HarmoniaRuntime/Sources/HarmoniaRuntime/ReceiptSpine.swift

### Related Epics
- **Backend Stabilization**: td-79a05d (closed)
- **Build Error Resolution**: td-d856c3 (in_progress)
- **Backend Executable Rebuild**: td-2c38e1 (in_progress)

### Monitoring Commands
```bash
# View epic tree
td tree td-333894

# Check critical path
td critical-path --epic td-333894

# Monitor task status
td show td-333894 --children

# View dependencies
td depends-on td-333894

# Track blockers
td blockers --epic td-333894
```

---

## 📊 Success Tracking

### Current Status: Phase 2 Preparation

| Component | Status | Evidence |
|-----------|--------|----------|
| **Phase 1** | ✅ Complete | 4/4 tasks closed, build success |
| **Conductor (td-0cb66d)** | ⏳ Ready for review | Implementation complete, awaiting integration |
| **Governance (td-8d067f)** | 🟡 Design phase | Design docs ready, implementation pending |
| **Tool Execution (td-e3b75e)** | 🟡 Design phase | Contract design ready, implementation pending |
| **Memory Wiring (td-1edbaa)** | 🟡 Audit phase | Blocked by td-01c59f, audit can start |
| **Telemetry (td-a1ff61)** | 🟡 Design phase | Design ready, blocked by td-16ca40 |

### Phase 2 Completion Target

```
Target: 50-70% functionality
Current: 30-40% functionality (Phase 1)
Gap: 20-30% to migrate

Task Progress:
┌─────────────────────────────────────┐
│ Phase 2 Task Completion Tracker      │
├──────────────────┬──────────────────┤
│ NOT STARTED      │ ░░░░░ 0%         │
│ IN PROGRESS      │ ▓▓▓░░ 60%        │
│ COMPLETE         │ ░░░░░ 0%         │
└──────────────────┴──────────────────┘
```

**Expected Timeline**:
- Design phase: 2-3 weeks
- Implementation: 6-8 weeks
- Integration/testing: 2-3 weeks
- Total: 10-14 weeks (2.5-3.5 months)

---

## 🚀 Next Immediate Actions

### This Week (Urgent)

1. **Conductor Integration Review** (td-0cb66d)
   - [ ] Review implementation evidence
   - [ ] Validate acceptance criteria
   - [ ] Test harmonia CLI execution
   - [ ] Approve for downstream integration
   - **Owner**: Architecture team
   - **Time**: 2-3 days

2. **Governance Design Finalization** (td-8d067f)
   - [ ] Complete authority matrix
   - [ ] Document policy decision points
   - [ ] Define reason codes
   - [ ] Ready for implementation
   - **Owner**: Governance team
   - **Time**: 3-5 days

3. **Tool Execution Contract Review** (td-e3b75e)
   - [ ] Finalize contract interface
   - [ ] Plan authorization integration
   - [ ] Document test scenarios
   - **Owner**: Tool team
   - **Time**: 3-5 days

### Next 2 Weeks (High Priority)

4. **Memory Backend Audit Start** (td-1edbaa)
   - [ ] Identify all memory stubs
   - [ ] Document backend options
   - [ ] Plan adapter interface
   - **Owner**: Memory team
   - **Time**: 5-7 days

5. **Telemetry Design Finalization** (td-a1ff61)
   - [ ] Define trace context
   - [ ] Enumerate event types
   - [ ] Plan correlation mechanism
   - **Owner**: Observability team
   - **Time**: 3-5 days

6. **Blocker Resolution Coordination**
   - [ ] Check td-01c59f progress (retrieval contract)
   - [ ] Check td-cd1576 progress (policy gates)
   - [ ] Check td-16ca40 progress (observability spine)
   - **Owner**: Program manager
   - **Time**: Daily check-in

---

## 📝 Document Versioning

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-04-14 | Initial Phase 2 roadmap with full analysis | Copilot Session |

---

**Status**: READY FOR IMPLEMENTATION  
**Next Review**: Weekly during Phase 2  
**Approval**: Awaiting architecture team review

