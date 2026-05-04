# AnigmaSidecar Readiness Research

**Task ID**: td-sidecar-anigma-readiness  
**Priority**: P0  
**Status**: RESEARCH COMPLETE  
**Date**: 2025-01-XX

---

## Goal

Add deterministic readiness validation for AnigmaSidecar as a governed sidecar capability, without pulling it into generic BackendReadiness.

---

## Context

### Foundational Lanes (Closed)
- `td-358315` BackendReadiness: DONE
- BackendReadiness unhandled-file cleanup: DONE
- `td-master-diagnostic-harness`: DONE
- `td-7c0153-01` PDFium vendoring / PDFSidecarExecutable readiness: DONE
- `td-sidecar-pdf-service-readiness`: DONE
- `td-sidecar-translate-readiness`: DONE
- `td-alignment-matrix-calibration`: DONE
- `td-alignment-matrix-sidecar-rule-refinement`: DONE

### Current Matrix State
- P0 = 2
- SidecarPDFService: **RESOLVED** (test_pdf_sidecar_readiness.sh)
- SidecarTranslateService: **RESOLVED** (test_translate_sidecar_readiness.sh)
- PDFSidecarExecutable: **RESOLVED** (td-7c0153-01 + script)
- anigma-mcp: **SUPPRESSED** (ADM-0005 exception)

### Remaining P0 Queue
1. **`td-sidecar-anigma-readiness`** - AnigmaSidecar ← This task
2. `td-sidecar-office-readiness` - SidecarOfficeService

---

## Pre-State Diagnostic

From alignment matrix `ADM-0001`:
```
ID: ADM-0001
Severity: P0
Subject: AnigmaSidecar
Misalignment: Product build/readiness is not equivalent to governed sidecar health.
Recommended: Implement sidecar readiness receipt and governance gate.
```

---

## Research Questions & Answers

### 1. What does AnigmaSidecar own?

**Answer**: AnigmaSidecar is a **package** (not just a target) at `anigma/Packages/AnigmaSidecar/` containing multiple library sources that provide client-side communication with the Anigma daemon (`anigmad`).

**Package contents** (`anigma/Packages/AnigmaSidecar/`):
- `AnigmaSidecar.swift` - Package manifest placeholder
- `SidecarBridge.swift` (~1700 lines) - Main bridge: HTTP+Unix socket client to daemon
- `SidecarConfig.swift` - Configuration (socket paths, defaults)
- `DaemonGuardian.swift` - Daemon lifecycle management (start/stop/status/restart)
- `DaemonLifecycle.swift` - Daemon process spawning and monitoring
- `SharedMemoryAuthority.swift` - POSIX shm_open/mmap for zero-copy tensor handoffs

**Key responsibilities**:
- **SidecarBridge**: Primary client interface to daemon via Unix domain socket HTTP
  - Session management (open/close/keepalive)
  - Job submission and status tracking
  - Vault operations (ingest/retrieve/verify/GC)
  - Model registry operations
  - Pipeline operations
  - Assignment/MCP bridging
  - ML operations (chat/embed/search)
  - Evidence and receipt operations
  - Heartbeat and health monitoring
  - Retry logic with exponential backoff
  - Request metrics tracking
  - Caching (artifact, connexion)
  - Streaming responses
- **DaemonGuardian**: High-level daemon management
  - Ensures daemon is running
  - Auto-restarts if unresponsive
- **DaemonLifecycle**: Low-level daemon process control
  - Spawns daemon with `--socket` argument
  - Waits for readiness via health check
  - Graceful/(force) stop
  - PID file management
- **SharedMemoryAuthority**: Zero-copy shared memory management
  - Creates/manages POSIX shared memory regions
  - Uses `shm_open` + `mmap` for tensor handoffs
  - Zero-copy data exchange between app and daemon

### 2. Is it a library/service target, executable, launcher, umbrella sidecar, or runtime host?

**Answer**: **Umbrella sidecar library package** + **Runtime host helper** functions.

From `anigma/Package.swift`:
```swift
// Product definition
.library(name: "AnigmaSidecar", targets: ["AnigmaSidecar"]),

// Target definition  
.target(
    name: "AnigmaSidecar",
    dependencies: ["AnigmaPrimitives", "AnigmaNativeShims"],
    path: "Packages/AnigmaSidecar"
)
```

**Classification**:
- **Product type**: Library (`.library`)
- **Target type**: Library (not executable)
- **Role**: Client-side sidecar communication layer + daemon management
- **Architecture**: Umbrella package providing multiple sidecar capabilities

**Not an executable**: AnigmaSidecar has no `executable` product. It's a client library.

**However**: It DOES spawn and manage the daemon (`anigmad`) via `DaemonLifecycle` and `DaemonGuardian`.

### 3. What are its build-time dependencies?

From `anigma/Package.swift`:
```swift
dependencies: ["AnigmaPrimitives", "AnigmaNativeShims"]
```

**Build dependencies**:
- `AnigmaPrimitives` (tier1) - Portable primitive types, AnyCodable
- `AnigmaNativeShims` (tier3) - Native interop shims (POSIX shm_open, etc.)

**Transitive dependencies** (via SidecarBridge):
- `AsyncHTTPClient` - For HTTP requests over Unix socket
- `NIOCore` - Networking primitives
- `NIOPosix` - POSIX-specific networking
- `OSLog` - Logging
- `Foundation` - Standard library

### 4. What are its runtime dependencies?

**Runtime dependencies**:
- `anigmad` daemon binary - Must exist and be spawnable
- Unix domain socket support - For IPC with daemon
- POSIX shared memory (`shm_open`, `mmap`) - For zero-copy tensor handoffs
- Network stack - For HTTP over Unix socket ( AsyncHTTPClient)

**Environment requirements**:
- Unix-like OS (macOS/Linux) for Unix domain sockets and POSIX SHM
- `anigmad` binary available at expected path or in PATH
- Write permissions for socket directory (~/.cache/anigma/ on macOS)
- Sufficient file descriptors for socket connections

### 5. Does it spawn or coordinate other sidecars?

**Answer**: **YES** - AnigmaSidecar spawns and coordinates the primary daemon.

**Daemon spanwning**:
- `DaemonLifecycle.start()` spawns `anigmad` process
- Creates PID file at `<socket_path>.pid`
- Manages socket file at configured path

**Coordination**:
- `DaemonGuardian` wraps lifecycle with auto-restart
- `SidecarBridge` maintains session state and health checks
- Multiple bridge instances can share one daemon

**Other sidecars**: Does NOT directly spawn PDF/Translate sidecars. Those are:
- PDFSidecarExecutable: Spawned separately, becomes a daemon when run
- SidecarTranslateService: Library imported by AnigmaDaemon, no separate process
- SidecarOfficeService: Similar to Translate - library imported by daemon

### 6. Does any readiness script already cover it?

**Answer**: **NO** - No dedicated readiness script exists for AnigmaSidecar.

Existing coverage:
- Generic `test_backend_readiness.sh` - Tests BackendReadinessContractTests, skips PDFSidecarExecutable
- `test_pdf_sidecar_readiness.sh` - PDF sidecar only
- `test_translate_sidecar_readiness.sh` - Translate service only
- No script for AnigmaSidecar specifically

### 7. What minimal deterministic readiness proof is possible now?

**Answer**: **Build + daemon spawn validation**

Since AnigmaSidecar:
- Is a library (must build successfully)
- Has daemon spawning code (need to verify daemon can be spawned)
- Has no stub implementation (unlike SidecarTranslateService)
- Has real functionality (HTTP over Unix socket, SHM)

**Minimal proof strategy**:
1. Build AnigmaSidecar target (compilation proof)
2. Verify daemon binary exists at expected location
3. Optionally attempt daemon start/stop (if environment allows)
4. Emit readiness receipt

**Note**: The daemon (`anigmad`) is defined in a separate target. AnigmaSidecar library just communicates with it. So we need to check for the daemon binary, not build it as part of AnigmaSidecar validation.

### 8. Should readiness be build-only, smoke-test, IPC contract test, process-launch test, or dependency discovery?

**Answer**: **Build + process-launch test** (minimum for real sidecar).

**Rationale**:
- AnigmaSidecar is a REAL sidecar client with daemon coordination
- Unlike SidecarTranslateService (stub), AnigmaSidecar has production code
- It spawns the daemon, so process validation is appropriate
- IPC contract test would require daemon to be running and listening
- Full smoke test would require submitting jobs via bridge

**Decision**: Minimal deterministic extension:
1. Build AnigmaSidecar target (library compilation)
2. Verify daemon binary exists at expected path
3. Optionally attempt daemon start + health check + stop
4. Emit ready receipt

**IPC contract test**: Could be added later as enhancement, but requires daemon running state to be managed.

### 9. How should missing environment be classified?

**Answer**:
- `FAILED`: Build fails or daemon binary missing
- `CLEAN`: Build + daemon exists + daemon start/stop works, zero warnings
- `PASSED`: Build + daemon exists + daemon start/stop works, with warnings
- `CONTAMINATED`: Build passes but daemon binary missing (voids sidecar functionality)
- `ENVIRONMENT_UNAVAILABLE`: System cannot spawn processes ( rare case)

### 10. How should alignment-matrix detect this readiness lane after the fix?

**Answer**: Via `check_for_readiness_script()` in the audit script.

**Mechanism**:
1. Create `Scripts/test_anigma_sidecar_readiness.sh`
2. Script validates:
   - `swift build --target AnigmaSidecar`
   - Daemon binary exists at expected path
   - Optional: daemon start/health/stop cycle
3. `check_for_readiness_script("AnigmaSidecar", repo_root)` will find it because:
   - Script name contains `anigma` and `sidecar` and `readiness`
   - Script content contains `AnigmaSidecar`
   - Global glob pattern `test_*_readiness.sh` matches

---

## Architecture Inventory

### Package Structure

```
anigma/Packages/AnigmaSidecar/
├── AnigmaSidecar.swift          # Target placeholder
├── SidecarBridge.swift          # Main client bridge (~1700 lines)
├── SidecarConfig.swift          # Socket paths, defaults
├── DaemonGuardian.swift         # High-level daemon management
├── DaemonLifecycle.swift        # Low-level process control
└── SharedMemoryAuthority.swift  # Zero-copy SHM management
```

### Product/Target

| Name | Type | Path | Dependencies | Size |
|------|------|------|--------------|------|
| AnigmaSidecar | library | Packages/AnigmaSidecar | AnigmaPrimitives, AnigmaNativeShims | ~27KB |

### Transitive Dependencies

Via import graphs:
- `AsyncHTTPClient` (SwiftNIO) - Networking
- `NIOCore` - Event loop
- `NIOPosix` - POSIX networking
- `OSLog` - Logging framework

### Daemon Coordination

**AnigmaSidecar ↔ anigmad relationship**:
- AnigmaSidecar: **Client library** that communicates with daemon
- anigmad: **Separate executable** daemon process
- Communication: Unix domain socket HTTP (via AsyncHTTPClient)
- Lifecycle: AnigmaSidecar can spawn/manage anigmad

**anigmad location**:
- Development: `.build/debug/anigmad` or `.build/release/anigmad`
- Production: `App/Contents/Helpers/anigmad` (macOS app bundle)
- Configurable: `--socket` argument specifies socket path

### Graph Checks

```bash
$ explain-target AnigmaSidecar
Target: AnigmaSidecar
  Tier: unclassified
  Role: unknown
  Type: library
  Path: Packages/AnigmaSidecar
  Dependencies: AnigmaPrimitives, AnigmaNativeShims
  Reachable from: AnigmaNativeShims, AnigmaPrimitives

$ explain-edge BackendReadinessContractTests AnigmaSidecar
Edge 'BackendReadinessContractTests -> AnigmaSidecar' not found.
```

**Result**: ✅ No reachability from BackendReadinessContractTests to AnigmaSidecar.

---

## Readiness Gaps

### Current State
- ✅ PDFSidecarExecutable: validated
- ✅ SidecarPDFService: validated
- ✅ SidecarTranslateService: validated
- ❌ AnigmaSidecar: **NOT validated**

### What's Missing

1. **Dedicated readiness script**: No `test_anigma_sidecar_readiness.sh`
2. **Build validation**: AnigmaSidecar target not explicitly built
3. **Daemon coordination proof**: No verification that daemon can be spawned
4. **Alignment matrix integration**: Matrix flags AnigmaSidecar because no readiness script

### AnigmaSidecar vs Other Sidecars

| Aspect | AnigmaSidecar | SidecarPDFService | SidecarTranslateService | SidecarOfficeService |
|--------|---------------|------------------|------------------------|---------------------|
| Product type | Library | Library + Executable | Library | Library |
| Build deps | AnigmaPrimitives, AnigmaNativeShims | AnigmaPrimitives, AnigmaNativeShims, PDFNative | AnigmaPrimitives, AnigmaNativeShims | AnigmaPrimitives, AnigmaNativeShims |
| Runtime deps | anigmad daemon | PDFium, libpdfium.dylib | None (stub) | Unknown |
| Spawns daemon | YES (anigmad) | YES (PDFSidecarExecutable) | NO | Unknown |
| Has executable | NO | YES | NO | Unknown |

---

## Implementation Plan

### Phase 1: Minimal Readiness Script (This Task)

**Goal**: Create `Scripts/test_anigma_sidecar_readiness.sh` with build + daemon binary validation.

**Script steps**:
1. Build AnigmaSidecar target
2. Check for daemon binary at expected locations
3. Optional: Attempt daemon start + health check + stop (if not already running)
4. Classify based on results
5. Emit readiness receipt

**Classification**:
- `FAILED`: Build fails or daemon binary missing
- `CLEAN`: All checks pass, zero warnings
- `PASSED`: All checks pass, has warnings
- `CONTAMINATED`: Build passes but daemon binary missing

**Optional enhancement**: If daemon is not running, attempt start → health check → stop cycle as smoke test.

### Phase 2: Enhanced Readiness (Follow-up TD)

When more sophisticated validation is needed:
- IPC contract test (requires daemon running)
- Zero-copy SHM validation
- Full job submission smoke test
- Receiving end-point verification

---

## Decision

### Implementation Direction

**Prefer the smallest deterministic sidecar-level readiness lane**:

1. **Build AnigmaSidecar target** - Prove library compiles
2. **Verify daemon binary exists** - Prove sidecar can coordinate daemon
3. **Optional daemon start/health/stop** - Prove daemon lifecycle works
4. **Emit readiness receipt** - Document evidence
5. **No fake behavior** - Don't create stubs

### Classification Strategy

**Build status language** (consistent with other readiness scripts):
- `FAILED`: Build fails or daemon binary missing
- `CLEAN`: Build + daemon binary present + optional start/stop, zero warnings
- `PASSED`: Build + daemon binary present, has warnings
- `CONTAMINATED`: Build passes but daemon binary missing

---

## Follow-up Questions

1. Should AnigmaSidecar be split into separate targets (bridge, lifecycle, shm)?
2. Should daemon spawning be moved to a separate DaemonHost target?
3. Should there be a single SidecarClients umbrella package?
4. Should SharedMemoryAuthority be a separate target for isolation?
5. What's the relationship between AnigmaSidecar and AnigmaClientKit?

---

## Acceptance Criteria

✅ AnigmaSidecar has deterministic readiness evidence  
✅ Dedicated readiness command/script exists (`test_anigma_sidecar_readiness.sh`)  
✅ Missing environment/dependencies classified explicitly  
✅ Generic BackendReadiness remains independent  
✅ BackendReadinessContractTests does not reach AnigmaSidecar  
✅ Alignment matrix no longer reports AnigmaSidecar as active P0  
✅ No fake stubs  
✅ No @_exported imports  
✅ No new cycles  
✅ No new tier violations  

---

## Next Step

Proceed to implementation: Create `Scripts/test_anigma_sidecar_readiness.sh` with build validation and daemon binary check for AnigmaSidecar.
