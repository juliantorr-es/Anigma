# HarmoniaModule Snapshot-First Concurrency Contract

## Scope
**Targets**: HarmoniaModule, HarmoniaCLI, DatabaseCore, AnigmaCore  
**Language Mode**: Swift 6 strict concurrency enforced  
**Migration Order**: Core → Capability → Experimental modules  

## Invariants

### 1. Actor Ownership Model
- **Actors own mutable state** - All mutable properties must be `actor`-isolated
- **No mutable state crosses module boundaries** - Cross-boundary APIs traffic only in Sendable snapshots/IDs
- **Public DTOs are immutable and Sendable** - Structs with `let` properties only
- **Components remain data-only** - No I/O, no scheduling, no actor references

### 2. Truthful Protocol Contracts
- **Protocols traffic only in Sendable types** - No actor-isolated state implied
- **Actor-bound protocols explicitly declared** - No pretending to be globally usable
- **Nonisolated protocol requirements** - Where cross-isolation access is needed
- **Implementation isolation** - Actor isolation in conforming types, not protocols

### 3. Compiler Enforcement Boundaries
- **Swift 6 mode produces zero diagnostics** - No concurrency warnings/errors for migrated targets
- **Strict concurrency checking enabled** - Both `-Xswiftc -strict-concurrency=complete` and `SWIFT_STRICT_CONCURRENCY=complete` for Xcode consistency
- **@preconcurrency limited to import statements only** - SE-0337 migration bridge, no sprinkling on declarations, tracked for removal
- **No mutable globals or non-isolated static vars** - Swift 6 prohibits these as data race vectors
- **Tests run under identical strict settings** - No back doors with lax test compilation

### 4. Dependency Structural Rules
- **Governed CLI boundary insulated** - AST services and governance binaries have minimal, pinned dependency graph
- **Terminal UX dependencies isolated** - SwiftTerm and UI libraries in separate capability modules
- **Acyclic dependency resolution** - No ArgumentParser range conflicts across structural boundaries
- **Capability modules optional** - Core governance works without rich features

## Acceptance Tests

### Compiler Validation
```bash
# Must pass with zero diagnostics (both methods for Xcode consistency)
swift build --target HarmoniaModule -Xswiftc -strict-concurrency=complete
SWIFT_STRICT_CONCURRENCY=complete swift build --target HarmoniaModule

# SE-0337 compliance: @preconcurrency ONLY on import statements, no sprinkling
rg "@preconcurrency\s+(class|struct|func|var|let)" Sources/ && exit 1
rg "@preconcurrency" Sources/ | grep -v "import " && exit 1

# No mutable globals or non-isolated static vars (Swift 6 prohibition)
rg "^[[:space:]]*var[[:space:]]+[A-Za-z_]" Sources/ --type swift && exit 1

# All public APIs are Sendable
swift build --target HarmoniaModule -Xswiftc -warn-concurrency

# Tests run under identical strict settings
swift test --filter HarmoniaModuleTests -Xswiftc -strict-concurrency=complete
SWIFT_STRICT_CONCURRENCY=complete swift test --filter HarmoniaModuleTests
```

### Runtime Validation
- **Integration tests under strict concurrency** - No data races in concurrent execution
- **Snapshot exchange correctness** - Cross-isolation communication maintains data integrity
- **Policy violation detection** - Attempts to access mutable state across boundaries fail fast

### Governance Validation
- **No new authority violations** - CI gate prevents regression
- **Dependency graph remains acyclic** - Automated structural verification
- **Accessum integration maintained** - All governed operations produce receipts

## Non-Goals

- **"Convert everything to actors"** - Actor façade conversion, not blanket actorification
- **"Silence warnings"** - Fix the underlying data race risks
- **"Ship faster by disabling safety"** - Speed comes from truthful contracts, not suppression
- **"Perfect isolation"** - Practical isolation with clear boundaries and escape hatches

## Success Metrics

1. **Zero Swift 6 concurrency diagnostics** for in-scope targets
2. **No @preconcurrency outside import boundaries** 
3. **All cross-boundary APIs traffic in Sendable types**
4. **Dependency boundary enforcement** prevents structural conflicts
5. **Integration tests pass** under strict concurrency conditions

## Enforcement

**CI Gate**: `Scripts/verify_swift6_compliance.sh` - Fails build on any violation  
**Authority Map**: `Docs/governance/type-authority-map.json` - Prevents shadow authorities  
**Dependency Contract**: `Package.swift` structural rules - Enforces acyclic resolution  
**Review Checklist**: All PRs touching concurrency must reference this contract

---

*"Anigma treats every transformation, including concurrency boundaries, as a governed step with provable correctness, so race conditions are eliminated at compile time rather than discovered at runtime."*