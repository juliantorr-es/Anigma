# Daemon Consolidation: Complete Specification

**Project**: DEBT-012 - Consolidate Backend Architecture into Unified Daemon
**Date**: 2026-01-24
**Status**: ✅ Ready for Implementation

---

## Documents

### 1. Ticket (Specification)
**File**: `Tickets/debt_daemon_consolidation.md`
**Purpose**: Requirements, scope, success criteria

### 2. Research Report
**File**: `Tickets/RESEARCH_daemon_consolidation.md`
**Purpose**: Current state analysis, findings, gaps

### 3. Implementation Plan (This Document)
**File**: `Tickets/PLAN_daemon_consolidation.md`
**Purpose**: Detailed tasks, code examples, timeline

---

## Quick Reference

### Timeline
- **Total Duration**: 10-12 weeks
- **Phase 1 (API Extension)**: Weeks 1-2
- **Phase 2 (Service Integration)**: Weeks 3-4
- **Phase 3 (WebServer Removal)**: Week 5
- **Phase 4 (Client Thinning)**: Weeks 6-8
- **Phase 5 (Auth & Security)**: Week 9
- **Phase 6 (Observability)**: Week 10
- **Phase 7 (Deployment)**: Weeks 11-12

### Key Metrics
- **Files to Refactor**: 7+ client files
- **Code to Remove**: 7,424 lines of direct imports
- **Routes to Port**: 13 Vapor → Hummingbird
- **Services to Integrate**: 9 major services
- **New API Endpoints**: 30+ new routes

### Success Indicators
- ✅ Zero Vapor dependencies
- ✅ Zero direct backend imports in clients
- ✅ Single daemon process
- ✅ All operations receipted
- ✅ OAuth/JWT authentication
- ✅ Full observability

---

## Implementation Order

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Daemon API Extension (Foundation)                  │
│ ────────────────────────────────────────────────────────── │
│ 1. Define request/response types in AnigmaPrimitives       │
│ 2. Add HTTP routes (stubs) to HTTPServerManager            │
│ 3. Add stub handlers to DaemonServer                        │
│ 4. Extend SidecarBridge with new methods                    │
│                                                             │
│ Deliverable: API surface ready, returns "NOT_IMPLEMENTED"  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Service Integration (Core Implementation)          │
│ ────────────────────────────────────────────────────────── │
│ 1. Add dependencies to Package.swift                        │
│ 2. Initialize services in DaemonServer                      │
│ 3. Implement real handlers (replace stubs)                  │
│                                                             │
│ Deliverable: Full daemon functionality operational          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: WebServer Removal (Cleanup)                        │
│ ────────────────────────────────────────────────────────── │
│ 1. Port Vapor middleware to Hummingbird                     │
│ 2. Verify all routes work                                   │
│ 3. Delete AnigmaWebServer files                             │
│ 4. Remove Vapor from Package.swift                          │
│                                                             │
│ Deliverable: Single HTTP framework (Hummingbird only)       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 4: Client Thinning (Architectural Shift)              │
│ ────────────────────────────────────────────────────────── │
│ 1. Refactor CLIDatabase → daemon calls                      │
│ 2. Refactor Mac App stores → daemon calls                   │
│ 3. Refactor main AppStore → daemon calls                    │
│ 4. Refactor MCP Server → daemon calls                       │
│                                                             │
│ Deliverable: All clients thin, zero direct imports          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 5: Auth & Security (Hardening)                        │
│ ────────────────────────────────────────────────────────── │
│ 1. Implement OAuth/JWT                                      │
│ 2. Add multi-user support                                   │
│ 3. Enhance sandboxing                                       │
│                                                             │
│ Deliverable: Production-ready authentication                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 6: Observability (Operations)                         │
│ ────────────────────────────────────────────────────────── │
│ 1. Add metrics collection                                   │
│ 2. Add distributed tracing                                  │
│ 3. Create dashboards                                        │
│                                                             │
│ Deliverable: Full operational visibility                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 7: Deployment & Docs (Productionization)              │
│ ────────────────────────────────────────────────────────── │
│ 1. Update launchd configuration                             │
│ 2. Write API documentation                                  │
│ 3. Write architecture documentation                         │
│ 4. Write migration guide                                    │
│                                                             │
│ Deliverable: Production-ready deployment                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Next Steps

### Ready to Begin Implementation

1. **Review all three documents**:
   - Ticket (requirements)
   - Research (findings)
   - Plan (tasks)

2. **Start with Phase 1**:
   - Create `Packages/AnigmaPrimitives/DaemonAPI.swift`
   - Add new types for all APIs
   - Add routes to `HTTPServerManager.swift`
   - Extend `SidecarBridge.swift`

3. **Testing approach**:
   - Test each phase independently
   - Contract tests for API compatibility
   - Integration tests for end-to-end flows

---

## Resources

- **Ticket**: `/Tickets/debt_daemon_consolidation.md`
- **Research**: `/Tickets/RESEARCH_daemon_consolidation.md`
- **Plan**: `/Tickets/PLAN_daemon_consolidation.md`
- **Reference Implementation**: `App/MacApp/AppStore.swift` (correct pattern)

---

**Status**: ✅ Planning Complete - Ready for Implementation
**Confidence**: High (thorough research, clear plan)
**Risk**: Medium (large effort, well-mitigated)
