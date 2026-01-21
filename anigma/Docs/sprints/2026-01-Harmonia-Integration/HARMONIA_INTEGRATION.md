# Harmonia CLI Integration - Implementation Guide

**Status:** In Progress  
**Date:** 2026-01-07  
**Goal:** Full integration of Harmonia CLI with macOS app

## Overview

This document tracks the implementation of full Harmonia CLI integration, transforming the CLI from a standalone tool into a first-class component of the Anigma macOS app.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       macOS App                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                     AppStore                           │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │          DaemonHostCapability                    │  │  │
│  │  │  - ensureDaemonRunning()                         │  │  │
│  │  │  - stopDaemon()                                  │  │  │
│  │  │  - getDaemonStatus()                             │  │  │
│  │  │  - harmonia: HarmoniaClient ← NEW!              │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                          │                                    │
│                          ↓                                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              HarmoniaClient                            │  │
│  │  - execute<T>(_ args) → T                             │  │
│  │  - executeRaw(_ args) → Data                          │  │
│  │  - executeStreaming(_ args) → AsyncStream            │  │
│  └────────────────────────────────────────────────────────┘  │
│                          │                                    │
└──────────────────────────┼────────────────────────────────────┘
                           │
                           ↓ Process()
                  ┌────────────────────┐
                  │  harmonia (CLI)    │
                  │  /usr/local/bin/   │
                  └────────────────────┘
                           │
                           ↓
                  ┌────────────────────┐
                  │  anigmad (daemon)  │
                  └────────────────────┘
```

## Implementation Phases

### Phase 1: Core Client Infrastructure ✅

**Status:** COMPLETE

**Files Created:**
- `Packages/AnigmaHostMac/HarmoniaClient.swift` - Core CLI execution client
- `Packages/AnigmaHostMac/HarmoniaCommands.swift` - Strongly-typed command wrappers

**Features Implemented:**
- ✅ Binary location discovery (installed, release, debug)
- ✅ Process execution with timeout
- ✅ JSON response parsing
- ✅ Streaming output support
- ✅ Error handling and reporting
- ✅ Daemon commands (start, stop, status)
- ✅ Vault commands (status, verify, gc)
- ✅ Pipeline status
- ✅ Tech debt audit
- ✅ Search functionality
- ✅ Tool trust management
- ✅ Stack management
- ✅ Maintenance commands

**Key APIs:**
```swift
let client = HarmoniaClient()

// Execute with JSON response
let status: DaemonStatusResponse = try await client.daemonStatus()

// Execute streaming
for try await line in client.executeStreaming(["search", "query"]) {
    print(line)
}

// Raw execution
let data = try await client.executeRaw(["--help"])
```

### Phase 2: Daemon Integration ✅

**Status:** COMPLETE

**Files Modified:**
- `Packages/AnigmaHostMac/DaemonHostCapability.swift`

**Changes:**
- ✅ Replaced DaemonLifecycle with HarmoniaClient
- ✅ Added harmonia property for direct access
- ✅ Updated ensureDaemonRunning() to use CLI
- ✅ Updated stopDaemon() to use CLI
- ✅ Updated getDaemonStatus() to use CLI

**Before:**
```swift
let status = await DaemonLifecycle.status()
```

**After:**
```swift
let statusResponse = try await harmoniaClient.daemonStatus()
```

### Phase 3: AppStore Integration 🔄

**Status:** IN PROGRESS

**Planned Changes:**

1. **Expose Harmonia Client**
```swift
// AppStore.swift
@MainActor
@Observable
final class AppStore {
    // Existing
    private let daemonCapability: DaemonHostCapability
    
    // NEW: Direct access to Harmonia
    var harmoniaClient: HarmoniaClient {
        daemonCapability.harmonia
    }
}
```

2. **Add Harmonia Operations**
```swift
// Vault operations
func refreshVaultStatus() async {
    vaultStatus = try? await harmoniaClient.vaultStatus()
}

// Pipeline operations
func refreshPipelineStatus() async {
    pipelineStatus = try? await harmoniaClient.pipelineStatus()
}

// Tech debt analysis
func runTechDebtAudit(path: String) async {
    techDebtReport = try? await harmoniaClient.techDebtAudit(path: path)
}
```

3. **State Management**
```swift
// Add published state for Harmonia data
@Published var vaultStatus: HarmoniaClient.VaultStatusResponse?
@Published var pipelineStatus: HarmoniaClient.PipelineStatusResponse?
@Published var techDebtReport: HarmoniaClient.TechDebtAuditResponse?
@Published var searchResults: HarmoniaClient.SearchResponse?
```

### Phase 4: UI Integration 📋

**Status:** PLANNED

**Components to Create:**

1. **Daemon Status View**
```swift
struct DaemonStatusView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        if let status = store.daemonStatus {
            // Show daemon status, PID, uptime
        }
    }
}
```

2. **Vault Inspector**
```swift
struct VaultInspectorView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        if let vault = store.vaultStatus {
            // Show artifacts, size, health
            // Buttons: Verify, GC
        }
    }
}
```

3. **Pipeline Monitor**
```swift
struct PipelineMonitorView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        // Show pending, running, completed jobs
        // Real-time updates
    }
}
```

4. **Tech Debt Dashboard**
```swift
struct TechDebtDashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var analysisPath: String = ""
    
    var body: some View {
        // Path selector
        // Run analysis button
        // Results display (critical, high, medium, low)
    }
}
```

5. **Search Interface**
```swift
struct HarmoniaSearchView: View {
    @EnvironmentObject var store: AppStore
    @State private var query: String = ""
    
    var body: some View {
        // Search bar
        // Results list with relevance
        // Type filtering
    }
}
```

### Phase 5: Advanced Features 📋

**Status:** PLANNED

**Features to Implement:**

1. **Background Sync**
   - Periodic vault status updates
   - Pipeline status polling
   - Daemon health checks

2. **Command History**
   - Track Harmonia CLI invocations
   - Store results for offline viewing
   - Command replay capability

3. **Error Recovery**
   - Automatic retry logic
   - Circuit breaker implementation
   - Graceful degradation

4. **Performance Optimization**
   - Command result caching
   - Batch operations
   - Parallel command execution

5. **Developer Tools**
   - Raw CLI output viewer
   - Command builder UI
   - JSON response inspector

## Command Coverage

| Category | Command | Wrapper Status | UI Status |
|----------|---------|----------------|-----------|
| **Daemon** | start | ✅ Complete | 🔄 In Progress |
| | stop | ✅ Complete | 🔄 In Progress |
| | status | ✅ Complete | 🔄 In Progress |
| **Vault** | status | ✅ Complete | 📋 Planned |
| | verify | ✅ Complete | 📋 Planned |
| | gc | ✅ Complete | 📋 Planned |
| | export | 📋 Planned | 📋 Planned |
| **Pipeline** | status | ✅ Complete | 📋 Planned |
| **Tech Debt** | audit | ✅ Complete | 📋 Planned |
| **Search** | search | ✅ Complete | 📋 Planned |
| **Tool** | status | ✅ Complete | 📋 Planned |
| | trust add | ✅ Complete | 📋 Planned |
| | trust remove | ✅ Complete | 📋 Planned |
| | trust list | ✅ Complete | 📋 Planned |
| **Stack** | status | ✅ Complete | 📋 Planned |
| | create | ✅ Complete | 📋 Planned |
| | sync | ✅ Complete | 📋 Planned |
| **Maintenance** | maintain | ✅ Complete | 📋 Planned |
| | gc | ✅ Complete | 📋 Planned |
| **Praxis** | diagnose | 📋 Planned | 📋 Planned |
| | boundary-ticket | 📋 Planned | 📋 Planned |
| **Swift6** | test | 📋 Planned | 📋 Planned |
| | step | 📋 Planned | 📋 Planned |
| **Segment** | segment | 📋 Planned | 📋 Planned |

## Testing Plan

### Unit Tests
- [ ] HarmoniaClient initialization
- [ ] Binary discovery logic
- [ ] Command execution
- [ ] JSON parsing
- [ ] Error handling
- [ ] Timeout behavior

### Integration Tests
- [ ] Daemon start/stop cycle
- [ ] Vault operations
- [ ] Pipeline status retrieval
- [ ] Search functionality
- [ ] Tool trust workflow

### UI Tests
- [ ] Daemon status display
- [ ] Vault inspector interaction
- [ ] Tech debt report viewing
- [ ] Search results navigation

## Migration Path

### For Existing Code

**Before (Direct DaemonLifecycle):**
```swift
let status = await DaemonLifecycle.status()
```

**After (Via DaemonHostCapability):**
```swift
let status = await daemonCapability.getDaemonStatus()
```

**After (Direct Harmonia Access):**
```swift
let response = try await daemonCapability.harmonia.daemonStatus()
```

### For New Features

Always use `HarmoniaClient` for CLI operations:

```swift
// In AppStore or view models
let client = appStore.harmoniaClient

// Execute commands
let vault = try await client.vaultStatus()
let results = try await client.search(query: "keyword")
```

## Performance Considerations

### Command Execution Time

| Command | Expected Time | Timeout |
|---------|---------------|---------|
| daemon status | < 100ms | 5s |
| vault status | < 500ms | 10s |
| vault verify | 5-30s | 60s |
| vault gc | 10-60s | 120s |
| search | < 1s | 30s |
| techdebt audit | 10-120s | 300s |

### Caching Strategy

- **Daemon status:** No cache (real-time)
- **Vault status:** Cache 5 minutes
- **Pipeline status:** Cache 30 seconds
- **Search results:** Cache 10 minutes
- **Tech debt reports:** Cache 1 hour

## Security Considerations

1. **Binary Verification**
   - Verify harmonia binary signature
   - Check SHA256 checksum
   - Validate installation path

2. **Command Injection Prevention**
   - All arguments are array-based (no shell parsing)
   - No string interpolation in commands
   - Input validation on all parameters

3. **Output Sanitization**
   - Parse JSON responses only
   - Validate response structure
   - Handle malformed output gracefully

## Known Issues

1. **Harmonia CLI JSON Output**
   - Not all commands support `--format json` yet
   - Some commands output text only
   - Need to enhance CLI for consistent JSON

2. **Error Reporting**
   - CLI error messages vary in format
   - Need standardized error codes
   - Some errors only in stderr

3. **Performance**
   - Process spawning overhead (~50-100ms)
   - No connection pooling yet
   - Each command is isolated

## Next Steps

1. ✅ **Complete Phase 1:** Core client infrastructure
2. ✅ **Complete Phase 2:** Daemon integration
3. 🔄 **Phase 3:** AppStore integration (IN PROGRESS)
4. 📋 **Phase 4:** UI integration
5. 📋 **Phase 5:** Advanced features

## Success Criteria

- [ ] All Harmonia commands accessible from macOS app
- [ ] < 100ms overhead for CLI invocations
- [ ] Comprehensive error handling
- [ ] Real-time status updates
- [ ] Graceful fallback when CLI unavailable
- [ ] User-friendly error messages
- [ ] Complete UI coverage for common operations
- [ ] Documentation for all APIs
- [ ] Integration tests passing
- [ ] Performance benchmarks met

---

**Last Updated:** 2026-01-07
**Contributors:** System
**Status:** 50% Complete (Phases 1-2 done, 3-5 remaining)
