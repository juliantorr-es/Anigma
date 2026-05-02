# Governance Invariants

These are non-negotiable properties of the governance system. Breaking any of these will cause silent failures, test failures, or brick the system in readOnly mode.

## 1. Governance State Mutations Must Carry Principal Context

**Rule**: All governance state changes (setMode, clearMode, setKillSwitch) MUST call `database.mutate(mutation, context)` with the actual principal's ExecutionContext, NOT `database.execute()` with system context.

**Why**: Without principal context, the admin carveout cannot distinguish between admin and non-admin operations. System context bypasses governance entirely.

**Enforcement**: If you call `database.execute()` on a governance table, admin privileges won't work and you'll brick yourself in readOnly mode.

**Files**: 
- `Governance.swift`: `setMode()`, `clearMode()`
- Must use: `database.mutate(mutation, context)` where context has real principal

## 2. Mode Checks Must Be Project-Aware

**Rule**: WriteGate's OperatingModeCheck MUST evaluate the effective mode for the specific project in the WriteProposal, not the global mode.

**Why**: Without this, project-specific readOnly overrides are ignored and writes succeed when they should be denied.

**Enforcement**: OperatingModeCheck closure must call `getMode(for: projectId)` where projectId is extracted from `proposal.context["projectId"]`.

**Files**:
- `Governance.swift`: OperatingModeCheck registration must pass projectId to modeProvider
- `KernelDatabaseAuthority.swift`: Must populate `proposalContext["projectId"]` from `context.projectId`

## 3. Clearing Mode Must Delete DB + Evict Cache

**Rule**: `clearMode()` must BOTH delete the database row AND remove the in-memory cache entry.

**Why**: If you only do one, either restarts reload stale data (DB not deleted) or current runtime sees stale mode (cache not evicted).

**Enforcement**: 
- Database: `DELETE FROM governance_modes WHERE project_id = ?`
- Cache: `projectModes.removeValue(forKey: projectId)`
- Must do BOTH in the same function

**Files**:
- `Governance.swift`: `clearMode(for:by:using:)` does both operations
- `PlatformRuntime`: MUST call the DB version, NOT the cache-only `clearProjectMode()`

## 4. Admin Carveout Prevents Self-Bricking

**Rule**: Governance-admin principals (cli-admin, test-admin, system, daemon-admin) can ALWAYS mutate governance tables, regardless of current mode.

**Why**: Without this, setting global mode to readOnly makes mode changes impossible forever.

**Current Implementation**: 
- Dual enforcement (TECH DEBT - see below)
- Authority-level: `KernelDatabaseAuthority.mutate()` skips governance check for admin+governance
- Gate-level: `GovernanceAdminCheck` (currently unused because authority bypass runs first)

**Tech Debt**: Should consolidate to gate-level only. Authority should always call governance.

**Files**:
- `AnigmaCoreSecurityRuntimeStub.swift`: KernelDatabaseAuthority.mutate() admin bypass
- `GovernanceAdminCheck.swift`: Gate-level check (currently shadowed)

## 5. ProjectId Must Flow Through Context

**Rule**: Database writes for project-scoped data MUST include `projectId` in ExecutionContext and WriteProposal.context.

**Why**: Without projectId, mode checks evaluate global mode instead of project-specific mode.

**Current State**: 
- ExecutionContext has typed `projectId: String?` field ✅
- WriteProposal.context uses stringly-typed dictionary (TECH DEBT)
- Memory adapter uses `metadata["tenantId"]` (inconsistent naming)

**Tech Debt**: Consolidate on single canonical name (prefer `projectId`) in typed fields.

**Files**:
- `CLIKernel.swift`: SimpleMemoryStoreAdapter maps `metadata["tenantId"]` to context.projectId
- `KernelDatabaseAuthority.swift`: Extracts `context.projectId` into `proposalContext["projectId"]`

---

## Tech Debt Markers

### 1. Dual Admin Carveout
**Location**: KernelDatabaseAuthority.mutate() + GovernanceAdminCheck  
**Issue**: Authority-level bypass shadows gate-level check  
**Fix**: Remove authority bypass, rely on gate check only  
**Risk**: Medium - expands bypass scope over time  

### 2. Stringly-Typed ProjectId
**Location**: WriteProposal.context dictionary  
**Issue**: `proposal.context["projectId"]` instead of typed field  
**Fix**: Add `projectId: String?` to WriteProposal struct  
**Risk**: Low - typos cause silent fallback to global mode  

### 3. TenantId vs ProjectId Naming
**Location**: MemoryManager uses "tenantId", adapter maps to "projectId"  
**Issue**: Two names for same concept  
**Fix**: Pick one canonical name (projectId), map legacy key once at boundary  
**Risk**: Low - confuses contributors, causes mapping bugs  

---

## Test Coverage

All invariants are covered by `Tests/GovernanceHarness`:
- Admin carveout: `GovernanceAdminTests` (3 tests)
- Project-aware enforcement: `CLIIntegrationTests.testProjectModeDenialWhileGlobalAllows`
- clearMode persistence: `CLIIntegrationTests.testModeClearRevertToGlobal`
- Mode change across restart: `GovernanceRestartTests` (4 tests)

**Tripwire**: Harness should run automatically on changes to:
- `Governance.swift`
- `AnigmaCoreSecurityRuntimeStub.swift`
- `CLIKernel.swift`
- `PlatformRuntime.swift`

Run manually: `cd Tests/GovernanceHarness && swift test`
