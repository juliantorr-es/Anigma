# Phase 2: Daemon Architecture Unification Plan

## Current State Analysis

### Two Parallel Daemon Implementations:

1. **Simple Daemon** (`Anigma/Sources/anigmad/main.swift`)
   - ✅ Enhanced with real monitoring (CPU, memory, disk I/O, network)
   - ✅ SidecarBridge API compatibility implemented
   - ✅ Menu bar interface with SwiftUI
   - ✅ HTTP server on port 8080
   - ❌ Not part of main Package.swift
   - ❌ Missing production features (auth, telemetry, etc.)

2. **Full Daemon** (`Packages/AnigmaDaemon/main.swift`)
   - ✅ Part of main Package.swift (`anigmad` executable)
   - ✅ Modular architecture with `AnigmaDaemonCore`
   - ✅ Professional features (vault storage, worker processes, governance)
   - ❌ Build failures due to `MediaFingerprintCapsule` C-interop issues
   - ❌ Compiler crashes (signal 4) preventing compilation

### Build Status:
- `MediaFingerprintCapsule`: ✅ Builds successfully
- `AnigmaDaemonCore`: ❌ Fails with compiler crash (signal 4)
- `AnigmaDaemon`: ❌ Cannot build due to `AnigmaDaemonCore` dependency
- `AnigmaCLIExecutable`: ❌ Blocked by `AnigmaDaemonCore`

## Decision Points

### Option A: Fix Full Daemon Build Issues
**Pros:**
- Already part of main package structure
- Has professional architecture
- Designed for production use

**Cons:**
- Complex build issues (C-interop, compiler crashes)
- Unknown time to fix
- Blocking all dependent development

### Option B: Enhance Simple Daemon & Integrate into Main Package
**Pros:**
- Already working with enhancements
- Can be integrated quickly
- Unblocks development

**Cons:**
- Missing some production features
- Need to port enhancements to main package

### Option C: Hybrid Approach
1. Use simple daemon as interim solution
2. Work on fixing full daemon in parallel
3. Create migration path

## Recommended Approach: Option C (Hybrid)

### Phase 2.1: Interim Solution (2 weeks)
1. **Integrate simple daemon into main package**
   - Create new target in Package.swift
   - Move `Anigma/Sources/anigmad/` to `Sources/AnigmaDaemonSimple/`
   - Update dependencies

2. **Enhance for production use**
   - Add authentication stubs
   - Add basic telemetry
   - Update installer to use this version

3. **Unblock client development**
   - Ensure SidecarBridge API is complete
   - Test with existing clients

### Phase 2.2: Fix Full Daemon (4 weeks)
1. **Diagnose build issues**
   - Fix `MediaFingerprintCapsule` C-interop
   - Resolve compiler crashes
   - Update problematic dependencies

2. **Port enhancements**
   - Move monitoring features from simple daemon
   - Ensure SidecarBridge compatibility
   - Test migration path

3. **Production readiness**
   - Implement missing features (auth, telemetry, etc.)
   - Performance testing
   - Documentation

### Phase 2.3: Migration & Deprecation (2 weeks)
1. **Create migration tools**
   - Data migration from simple to full daemon
   - Configuration conversion
   - Testing procedures

2. **Update installer**
   - Package full daemon as replacement
   - Automatic migration during update
   - Rollback capability

3. **Deprecate simple daemon**
   - Mark as deprecated in code
   - Update documentation
   - Remove in future release

## Immediate Actions (Week 1)

### 1. Create Interim Package Target
```swift
// In Package.swift
.executableTarget(
    name: "AnigmaDaemonSimple",
    dependencies: [
        "AnigmaSidecar",
        "AnigmaPrimitives",
        // Minimal dependencies
    ],
    path: "Sources/AnigmaDaemonSimple",
    swiftSettings: [.swiftLanguageMode(.v6)]
)
```

### 2. Move and Refactor Simple Daemon
- Move `Anigma/Sources/anigmad/` → `Sources/AnigmaDaemonSimple/`
- Update imports and dependencies
- Ensure builds in main package

### 3. Basic Production Features
- Add API key authentication (stub → real)
- Add structured logging
- Add health check endpoints
- Update `DaemonLifecycle` to work with new binary

### 4. Update Installer
- Package `AnigmaDaemonSimple` as `anigmad`
- Update LaunchAgent configuration
- Test installation process

## Success Criteria

### Phase 2.1 Complete (Interim Solution):
- ✅ `AnigmaDaemonSimple` builds in main package
- ✅ All SidecarBridge endpoints implemented
- ✅ Basic authentication working
- ✅ Installer packages and deploys correctly
- ✅ Existing clients work without modification

### Phase 2.2 Complete (Full Daemon Fixed):
- ✅ `AnigmaDaemonCore` builds successfully
- ✅ `AnigmaDaemon` executable works
- ✅ All simple daemon features ported
- ✅ Production features implemented
- ✅ Performance meets requirements

### Phase 2.3 Complete (Migration):
- ✅ Automatic migration tools work
- ✅ Zero data loss during migration
- ✅ Clients transparently switch to full daemon
- ✅ Simple daemon deprecated and removed from installer

## Risks & Mitigations

### Risk 1: Full daemon cannot be fixed
**Mitigation**: Continue enhancing simple daemon as long-term solution

### Risk 2: Migration causes data loss
**Mitigation**: Comprehensive backup and rollback procedures

### Risk 3: Clients break during transition
**Mitigation**: Maintain API compatibility, thorough testing

### Risk 4: Timeline slips
**Mitigation**: Prioritize unblocking development first, then fix full daemon

## Next Steps

1. **Approve this plan**
2. **Start Phase 2.1 immediately** (unblock development)
3. **Assign resources to fix build issues** in parallel
4. **Weekly progress reviews**

This plan allows development to continue while working on the ideal architecture, minimizing blockers and providing a clear migration path.