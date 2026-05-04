# td-001b-break-wider-cycle: Break DatabaseCore → GovernanceCore → AnigmaFoundation → AnigmaCore cycle

## Goal

Remove the wider dependency cycle that remained after td-001-break-cycle.

## Problem

**td-001-break-cycle** only partially addressed the DatabaseCore ↔ AnigmaFoundation cycle.

The wider cycle persists through GovernanceCore and AnigmaCore, blocking build/test verification for:
- td-358315 (backend readiness gates)
- Downstream architecture work requiring stable PlatformRuntime
- EvidenceAuthority integration
- Governance enforcement testing

**Current Cycle**:
```
DatabaseCore → GovernanceCore → AnigmaFoundation → AnigmaCore (umbrella) → DatabaseCore
```

**Specific Evidence**:
- `DatabaseCore/PostgresCutoverUtility.swift:9` imports `AnigmaCore`
- `GovernanceCore` target depends on `DatabaseCore` (Package.swift line 894)
- `AnigmaFoundation` target depends on `GovernanceCore` (Package.swift line 529)
- `AnigmaCore` umbrella re-exports `AnigmaFoundation` via `@_exported import`

## Approved Shape

**DatabaseCore must not depend on GovernanceCore, AnigmaFoundation, or AnigmaCore implementation modules.**

If DatabaseCore needs governance decisions, receipts, principals, policy identifiers, or mutation authorization contracts, depend on **portable contract modules only**. Use contract protocols/value types, not concrete runtime/governance implementations.

## Non-Goals

- Do not fix Evidence/CoreReceipt alignment (separate concern)
- Do not continue backend readiness implementation (td-358315 is blocked, not canceled)
- Do not restore vendored pdfium (separate infrastructure concern)
- Do not add `@_exported` imports to hide the cycle (anti-pattern)
- Do not create a generic AnigmaTypes dumping ground (violates tiering)

## Implementation Sequence

### 1. Inspect Exact Dependencies

Map the current dependency declarations and imports forming:
```
DatabaseCore → GovernanceCore → AnigmaFoundation → AnigmaCore
```

**Commands**:
```bash
# Find all DatabaseCore imports
grep -r "import.*AnigmaCore\|import.*GovernanceCore\|import.*AnigmaFoundation" Packages/DatabaseCore/

# Find all GovernanceCore imports  
grep -r "import.*DatabaseCore" Packages/GovernanceCore/

# Check Package.swift dependencies
grep -A 5 "name: \"DatabaseCore\"\|name: \"GovernanceCore\"\|name: \"AnigmaFoundation\"" Package.swift
```

### 2. Classify Imported Symbols

For each import in the cycle, classify as:

| Import Source | Symbol | Classification | Action |
|---------------|--------|----------------|--------|
| DatabaseCore → AnigmaCore | ? | portable contract | Move to contract module |
| DatabaseCore → AnigmaCore | ? | governance implementation | Replace with contract |
| DatabaseCore → AnigmaCore | ? | runtime/foundation implementation | Replace with contract |
| DatabaseCore → AnigmaCore | ? | stale import | Remove |
| DatabaseCore → AnigmaCore | ? | test-only usage | Isolate in test target |

### 3. Extract Contract Surfaces

Move only portable contract requirements into the correct contract module:

**Options**:
- `FoundationContracts` (if foundation-level)
- `GovernanceContracts` (if governance-specific)
- `EvidenceContracts` (if evidence-related)
- New minimal contract module (if domain-specific)

**Criteria**:
- No implementation types
- No platform-specific types  
- No concrete executors/authorities
- Pure value types and protocols only

### 4. Remove Implementation Dependencies

**DatabaseCore**:
- Remove dependency on `GovernanceCore` target
- Remove dependency on `AnigmaCore` target
- Replace with dependency on appropriate contract module

**PostgresCutoverUtility.swift**:
- Remove `import AnigmaCore`
- Use contract interfaces instead
- Move to appropriate contract-based target if needed

### 5. Validate Dependency Graph

**Commands**:
```bash
# Check for cycles
swift package dump-package | grep -A 20 dependencies

# Attempt build
swift build --dry-run

# Validate tiers
python3 tools/governance/scripts/validate_tiers.py
```

### 6. Document Remaining Blockers

If build still fails after cycle removal, document:
- Missing vendor libraries (pdfium, etc.)
- Unhandled files in build system
- Other unrelated build issues

## Acceptance Criteria

✅ **Cycle Elimination**:
- The DatabaseCore → GovernanceCore → AnigmaFoundation → AnigmaCore cycle is eliminated
- DatabaseCore no longer imports GovernanceCore, AnigmaFoundation, or AnigmaCore implementation modules
- Exception: Explicitly justified, cycle-free imports documented in ADR

✅ **No Workarounds**:
- No broad umbrella import introduced
- No `@_exported` import added to hide the cycle
- No generic AnigmaTypes dumping ground created

✅ **Contract Surfaces**:
- Any extracted contract surface is narrow and portable
- Contracts contain only value types and protocols
- No implementation types leaked into contracts

✅ **Validation**:
- Dependency graph is cycle-free
- Swift package validation passes
- Tier validation passes

✅ **Unblocking**:
- td-358315 remains blocked only by remaining non-cycle issues (if any)
- Clear path for backend readiness testing
- EvidenceAuthority wiring can proceed

## Proof Artifact

Create `Docs/proofs/td-001b-break-wider-cycle-proof.md` with:

### Before Dependency Chain
```mermaid
graph TD
    A[DatabaseCore] -->|depends on| B[GovernanceCore]
    B -->|depends on| C[AnigmaFoundation]  
    C -->|depends on| D[AnigmaCore]
    D -->|@_exported imports| A
```

### Exact Imports/Dependencies Removed
```
DatabaseCore/PostgresCutoverUtility.swift:
- Removed: import AnigmaCore
- Replaced with: import GovernanceContracts

Package.swift DatabaseCore target:
- Removed: "GovernanceCore" from dependencies
- Added: "GovernanceContracts" to dependencies

Package.swift GovernanceCore target:
- No changes (already correct)
```

### Contract Surfaces Introduced/Reused
```
GovernanceContracts:
- Added: PostgresCutoverContract protocol
- Added: CutoverReceipt struct
- Added: CutoverPolicy enum
```

### Validation Commands/Results
```bash
# Before (fails)
$ swift build --dry-run
error: cyclic dependency detected: DatabaseCore → GovernanceCore → AnigmaFoundation → AnigmaCore

# After (succeeds)
$ swift build --dry-run
success: no cyclic dependencies detected

# Tier validation
$ python3 tools/governance/scripts/validate_tiers.py
✅ No tier violations
✅ No implementation types in contracts
```

### Remaining Blockers (if any)
```
- Missing vendor library: pdfium
- Tracked in: p0-vendor-library-restoration
- Does not block td-358315 testing
```

## Next Steps After Completion

1. **Unblock td-358315**: Execute BackendReadinessTests
2. **Complete EvidenceAuthority wiring**: Now that build is stable
3. **Proceed with architecture verification**: PlatformRuntime governance enforcement
4. **Close p0-build-recovery-epic**: When all build blockers resolved

## References

- **Parent Epic**: p0-build-recovery-epic
- **Predecessor**: td-001-break-cycle (partial cycle breaking)
- **Blocked Task**: td-358315 (backend readiness gates)
- **Related**: td-arch-001, td-arch-002 (governance/evidence unification)