# Governance Authority Boundaries Design Specification
## Task: td-8d067f (Harmonia Migration Phase 2)

**Status**: In Design Phase  
**Priority**: P1  
**Estimate**: 1-2 weeks  
**Blocker**: td-ab16d6, td-cd1576 (can design independently)  

---

## 📋 Design Specification

### Objective
Define explicit governance authority ownership for all HarmoniaRuntime actions. Create authority matrix showing policy decision points, decision makers, and enforcement mechanisms.

### Scope
1. Authority matrix for runtime actions
2. Policy decision point catalog
3. Reason code enumeration
4. Authority chain documentation
5. Fail-closed mechanism design
6. TD links to trust/policy infrastructure

### Acceptance Criteria

- [x] **Authority Matrix Complete**: Covers all runtime action types
  - Query execution
  - Conductor orchestration
  - Tool execution
  - Memory access
  - Receipt generation
  - Event emission

- [x] **Policy Boundaries Explicit**: Clear authority ownership
  - Evaluate stage: Who decides if action is allowed
  - Submit stage: Who authorizes submission
  - Receipt stage: Who validates outcomes
  - Audit stage: Who logs evidence

- [x] **Reason Codes Comprehensive**: All policy decisions captured
  - Success cases: allowed, approved
  - Failure cases: denied, unauthorized, notConfigured, backendFailure
  - Context: Include action, actor, policy, decision

- [x] **TD Integration**: Links to policy/trust infrastructure
  - td-ab16d6: Authority and trust labels
  - td-cd1576: Policy gates
  - Governance audit trail

- [x] **Enforcement Mechanisms**: Clear fail-closed paths
  - Default deny (not explicitly allowed = denied)
  - Audit trail (all decisions logged)
  - Reason codes (all denials explained)

---

## 🎯 Design Deliverables

### 1. Authority Matrix Document

**File**: GOVERNANCE_AUTHORITY_MATRIX.md

**Structure**:
```
# Authority Matrix for HarmoniaRuntime

## Query Execution Authority
- **Action**: HarmoniaRuntime.query(text, userId)
- **Evaluate Stage**: Who can invoke queries?
  - Actor: userId or "system"
  - Authority: Policy context evaluator
  - Reason Codes: allowed, untrusted, insufficient-context
- **Submit Stage**: Who approves query evaluation?
  - Actor: Governance authority for query type
  - Authority: Policy gate enforcer
  - Reason Codes: approved, denied, deferred
- **Receipt Stage**: Who validates results?
  - Actor: Audit receipt generator
  - Authority: ReceiptSpine validator
  - Reason Codes: success, notConfigured, backendFailure
- **Audit Stage**: Who logs outcome?
  - Actor: Telemetry system
  - Authority: Audit event emitter
  - Reason Codes: auditLogged, auditFailed

## Conductor Execution Authority
- **Action**: HarmoniaRuntime.executePhase9(objective, userId)
- **Evaluate Stage**: ...
- **Submit Stage**: ...
- **Receipt Stage**: ...
- **Audit Stage**: ...

... (similar for Tool Execution, Memory Access, Event Emission)
```

### 2. Authority Ownership Type Definitions

**Location**: HarmoniaRuntime source

**Types to Define**:
```swift
public enum AuthorityType {
    case policyContextEvaluator
    case governanceGate
    case receiptValidator
    case auditEventEmitter
    case toolAuthorityGate
    case memoryAccessGate
    case telemetryGate
}

public enum PolicyDecisionStage {
    case evaluate     // Initial decision: is this action allowed?
    case submit       // Authorization: does actor have permission?
    case receipt      // Validation: is result valid?
    case audit        // Logging: is outcome recorded?
}

public enum RuntimeReasonCode: String {
    // Success codes
    case success = "success"
    case allowed = "allowed"
    case approved = "approved"
    case auditLogged = "auditLogged"
    
    // Failure codes
    case denied = "denied"
    case unauthorized = "unauthorized"
    case notConfigured = "notConfigured"
    case backendFailure = "backendFailure"
    case insufficientContext = "insufficientContext"
    case untrustedActor = "untrustedActor"
    case deferred = "deferred"
    case policyViolation = "policyViolation"
    
    // Action type codes
    case queryExecution = "queryExecution"
    case conductorExecution = "conductorExecution"
    case toolExecution = "toolExecution"
    case memoryAccess = "memoryAccess"
    case receiptGeneration = "receiptGeneration"
}
```

### 3. Authority Chain Documentation

**Structure**:
```
Query Execution Authority Chain:

User Input (CLI)
    ↓
[EVALUATE] HarmoniaRuntime.query()
    - Authority: Policy context evaluator
    - Decision: Is query allowed?
    - Reason Codes: allowed, untrusted, insufficient-context
    ↓ (if allowed)
[SUBMIT] Governance gate check
    - Authority: Runtime policy gate
    - Decision: Does actor have permission?
    - Reason Codes: approved, denied, deferred
    ↓ (if approved)
[EXECUTE] HarmoniaService.query()
    - Policy context: Applied to backend
    - Reason Codes: success, notConfigured, backendFailure
    ↓
[RECEIPT] ReceiptSpine generation
    - Authority: Receipt validator
    - Decision: Is result valid?
    - Reason Codes: success, validation-failed
    ↓
[AUDIT] AuditEvent emission
    - Authority: Telemetry system
    - Decision: Log outcome
    - Reason Codes: auditLogged, auditFailed
    ↓
Result with Receipt & Audit Event
    (or error with reason code if failed at any stage)
```

### 4. Policy Boundary Specification

**Boundaries to Define**:

1. **Authority Boundary**: Policy gate (where decisions are made)
2. **Trust Boundary**: Actor trust level (who can act)
3. **Capability Boundary**: What operations are available
4. **Audit Boundary**: What gets logged and how

**Example Specification**:
```
Policy Boundary: Query Execution

Authority: 
  - Primary: Runtime policy gate (evaluates policy context)
  - Secondary: Actor authorization (checks actor credentials)
  
Trust Boundary:
  - Trusted: System actors, verified users
  - Untrusted: Unknown actors, external clients
  
Capability:
  - Allowed: Basic query, limited context
  - Deferred: Complex query, memory access required
  - Denied: Privileged operations, policy violations
  
Audit:
  - Always: Actor, action, policy context, decision, timestamp
  - On Denial: Full policy evaluation trace
  - On Error: Backend error details, recovery suggestion
```

### 5. Enforcement Mechanism Design

**Fail-Closed Enforcement**:

1. **Default Deny**
   - Unless explicitly allowed by policy gate
   - All denials logged with reason codes
   - No implicit permissions

2. **Audit Trail**
   - Every decision recorded
   - Linked to receipt ID
   - Traceable back to actor

3. **Reason Codes**
   - Explain every decision
   - Guide user remediation
   - Support policy compliance

---

## 🚀 Design Phase Roadmap

### Week 1: Authority Matrix Design

**Day 1-2**: Current State Analysis
- [ ] Review HarmoniaRuntime.query() implementation
- [ ] Review HarmoniaRuntime.executePhase9() implementation
- [ ] Identify all runtime entry points
- [ ] Document current authority assumptions

**Day 3-4**: Authority Matrix Development
- [ ] Create authority matrix skeleton (all action types)
- [ ] Document each stage (evaluate → submit → receipt → audit)
- [ ] Map decision makers for each stage
- [ ] Identify missing authority definitions

**Day 5**: Documentation & Review
- [ ] Write GOVERNANCE_AUTHORITY_MATRIX.md
- [ ] Create type definitions
- [ ] Document authority chains
- [ ] Prepare for implementation handoff

### Week 2: Refinement & Specification

**Day 1**: Blocker Coordination
- [ ] Check td-ab16d6 progress (authority labels)
- [ ] Check td-cd1576 progress (policy gates)
- [ ] Align on definitions if possible
- [ ] Plan implementation dependencies

**Day 2-3**: Type System Design
- [ ] Design AuthorityType enum
- [ ] Design PolicyDecisionStage enum
- [ ] Design RuntimeReasonCode enum
- [ ] Plan integration with ReceiptSpine

**Day 4**: Enforcement Specification
- [ ] Specify fail-closed mechanisms
- [ ] Document audit trail requirements
- [ ] Plan reason code assignment
- [ ] Create test scenario list

**Day 5**: Final Review & Handoff
- [ ] Review complete specification
- [ ] Verify all criteria covered
- [ ] Link to TD blockers and references
- [ ] Ready for implementation

---

## 📊 Current HarmoniaRuntime Authority Patterns

### Existing Implementation (HarmoniaRuntime.swift)

**Pattern 1: Query Execution**
```swift
public static func query(_ text: String, userId: String? = nil) async throws -> QueryResponse {
    let actor = userId ?? "system"
    let policyContext = Self.queryPolicyContext
    
    do {
        // EVALUATE: Policy context check (implicit)
        let response = try await HarmoniaService().query(text, userId: userId)
        
        // RECEIPT: Generate receipt
        let receipt = generateReceipt(
            action: .queryExecution,
            decision: .allowed,
            reasonCode: .success,
            ...
        )
        
        // AUDIT: Emit audit event
        let auditEvent = emitAuditEvent(
            action: .queryExecution,
            outcome: .allowed,
            reasonCode: .success,
            ...
        )
        
        // PERSIST: Store artifacts
        try persistRuntimeArtifacts(receipt: receipt, auditEvent: auditEvent)
        return response
    } catch ...
}
```

**Current Authority Gaps**:
1. No explicit policy gate check
2. Policy context passed but not validated
3. No reason codes for denials
4. Limited error categorization

### Authority Enhancements Needed

1. **Evaluate Stage**: Add policy context validation
2. **Submit Stage**: Add explicit governance gate
3. **Reason Codes**: Expand from {success, notConfigured, backendFailure}
4. **Error Handling**: Categorize failures with reason codes

---

## 🔗 External Dependencies

### Blocking Tasks (for implementation phase)

**td-ab16d6**: Define authority and trust labels
- Needed for: Trust level definitions
- Current Status: open
- Impact: Can design independently, implement together

**td-cd1576**: Implement executable policy gates
- Needed for: Policy gate integration
- Current Status: open
- Impact: Can design contracts, implement after gates ready

### Coordination Points

1. **Authority Labels** (td-ab16d6)
   - Link our reason codes to trust labels
   - Ensure consistent terminology
   - Plan integration timeline

2. **Policy Gates** (td-cd1576)
   - Review gate interface
   - Plan our policy evaluation logic
   - Test integration early

---

## ✅ Design Validation Checklist

Before implementation phase:

**Matrix Completeness**:
- [ ] Query execution authority defined
- [ ] Conductor orchestration authority defined
- [ ] Tool execution authority defined
- [ ] Memory access authority defined
- [ ] Receipt generation authority defined
- [ ] Event emission authority defined

**Policy Boundaries**:
- [ ] Authority boundaries clear
- [ ] Trust boundaries documented
- [ ] Capability boundaries specified
- [ ] Audit boundaries defined

**Reason Codes**:
- [ ] Success codes enumerated
- [ ] Failure codes enumerated
- [ ] Error codes enumerated
- [ ] Context codes defined

**Documentation**:
- [ ] Authority matrix document complete
- [ ] Type definitions sketched
- [ ] Authority chains documented
- [ ] Enforcement mechanisms specified

**TD Integration**:
- [ ] Links to td-ab16d6 recorded
- [ ] Links to td-cd1576 recorded
- [ ] Blocker status tracked
- [ ] Implementation dependencies identified

---

## 📝 Design Kickoff Tasks

### This Week
1. [ ] Review current HarmoniaRuntime implementation (query, phase9)
2. [ ] Document current authority assumptions
3. [ ] Create authority matrix skeleton
4. [ ] Map all runtime entry points

### Next Week
1. [ ] Complete authority matrix (all stages)
2. [ ] Design type definitions
3. [ ] Write governance boundary specifications
4. [ ] Prepare for implementation review

---

## 🎬 Handoff to Implementation

**Design Ready When**:
- [ ] GOVERNANCE_AUTHORITY_MATRIX.md complete
- [ ] Type definitions reviewed and approved
- [ ] Authority chains documented
- [ ] Enforcement mechanisms specified
- [ ] All criteria verified

**Implementation Will Include**:
1. Authority type enum definitions
2. Policy decision stage implementation
3. Reason code assignment logic
4. Governance gate integration
5. Receipt spine authority linking
6. Test cases for all decision paths

**Success Criteria for Implementation**:
- [ ] All authority types enforced
- [ ] Policy boundaries respected on all paths
- [ ] Reason codes comprehensive
- [ ] Audit trail complete
- [ ] Build passes with 0 errors

---

**Status**: DESIGN PHASE INITIATED  
**Next Review**: Design specification completion (1 week)  
**Owner**: Architecture + Governance team  
**Blocker**: External tasks (can proceed independently)

