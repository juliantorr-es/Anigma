# Priority Reassessment - 2026-04-21

## Current State

| Status | Count | Priority Breakdown |
|--------|-------|---------------|
| Closed | 43 | 42 P0, 1 (unknown) |
| Open | 2 | 2 P0 |
| In Progress | 0 | - |
| Blocked | 0 | - |

## Issues Identified

### 1. All tasks are P0 (Priority Inflation)
Nearly every task in TD is marked P0, which defeats the purpose of prioritization.

### 2. "Unblock:" Tasks Were Closed Without Implementation
Many tasks like "Unblock: Connect memo capture to assistant flow" were closed but may not have been implemented - they were likely just status cleanup.

### 3. Open Tasks Are Actually Blocked By Hardware Saturation
- td-40d410 (Tiered Truth Storage) - blocked by td-16ca40 (Agent Observability)
- This dependency was removed during cleanup but the work is still gated on observability work

### 4. Hardware Saturation Epic Has 3 Open Stories
These weren't properly completed before the epic was closed.

## Recommendations

### A. Reclassify Priorities

| Current Priority | Count | Recommendation |
|----------------|-------|------------|
| P0 | ~50 | Reduce to P1-P3 based on actual urgency |

### B. Tasks to Close as "No Longer Needed"

| Task | Reason |
|-------|-------|
| td-40d410 | Blocked by observability epic - defer to Phase 2 |
| td-a8076d | Sub-task of above |
| td-550a39 | Depends on BLAKE3 completion |
| td-75fbb4 | ANE work may be superseded |
| td-d2fb8a | Tests depend on binary atlas completion |

### C. Tasks to Promote to Active

| Task | Reason | Priority |
|------|--------|---------|
| td-7ff1d3 | Hardware Saturation epic needs 3 more stories completed | P1 |
| td-333894 | Harmonia V3 Migration | P1 |
| td-cbe207 | Privacy/Compliance Spine | P1 |

### D. New Priority Structure

**P0 (Critical - Current Quarter)**
- Tiered Truth Storage implementation (if observability unblocks)
- Build stabilization for executables

**P1 (Important - Next Quarter)**
- Hardware Saturation completion
- Harmonia V3 Migration
- Privacy/Compliance implementation

**P2 (Useful - This Year)**
- DSL Candidate implementations
- UI/UX improvements

**P3 (Nice to Have)**
- Transcriptum improvements
- Legacy cleanup

## Proposed Changes

### Immediate Actions
1. Close td-40d410 and td-a8076d as "Deferred to Phase 2"
2. Close td-550a39, td-75fbb4, td-d2fb8a as "Superseded by completed work"
3. Reopen td-333894 (Harmonia Migration) as P1

### Medium-term Actions
1. Create new P2/P3 tasks for DSL implementations
2. Break Hardware Saturation epic into completed/archived
3. Archive "Unblock:" tasks that were never implemented

## Verification Needed

Before archiving, verify which "Unblock:" tasks were actually implemented:
- td-8b48e2 "Connect memo capture to assistant flow" - needs verification
- td-8cbe46 "Wire governed ML runs" - needs verification
- td-d169d8 "Wire ML model registry" - needs verification

## Decision Required

Should we:
1. **Archive** - Close tasks as "completed" or "wont-fix" without implementation
2. **Re-implement** - Actually implement the unblock tasks that were never done
3. **Defer** - Move to P3 backlog for future quarters