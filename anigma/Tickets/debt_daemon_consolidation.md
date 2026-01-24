---
type: debt
priority: high
created: 2026-01-24T12:00:00Z
created_by: Opus
status: created
tags: [architecture, daemon, consolidation, thin-client, refactor]
keywords: [DaemonServer, HTTPServerManager, SidecarBridge, CathedralModule, ModelRegistry, AppStore, AnigmaWebServer, CLIDatabase, AgentOrchestrator, GeminiBridge, OAuth, Hummingbird]
patterns: [direct-module-imports, actor-isolation, http-routes, capability-tokens, job-workers, receipt-recording]
---

# DEBT-012: Consolidate Backend Architecture into Unified Daemon

## Description

Transform the Anigma architecture so that all backend logic, compute, governance, and orchestration flows through the `anigmad` daemon process. The Mac App, CLI, and all other client executables become **thin clients** that communicate exclusively via the `SidecarBridge` HTTP API.

This consolidation eliminates:
- Direct module imports in client applications
- Duplicate database instances (CLI's `CLIDatabase`)
- Separate web server executable (Vapor-based `AnigmaWebServer`)
- Scattered ML service initialization
- Inconsistent governance enforcement

## Context

The current architecture has multiple processes directly instantiating backend modules:
- **Mac App** imports `CathedralModule`, `ModelRegistry`, `HuggingFaceAdapter`, `DataEngine`, `AgentOrchestrator`, `ExportEngine`, `AIConsoleClient` directly
- **CLI** maintains its own `CLIDatabase` and `ModelInstaller`
- **WebServer** duplicates Cathedral evidence enforcement with different HTTP framework (Vapor)
- **GeminiBridge** runs as separate executable

This creates:
1. **Code duplication** - Same logic initialized in multiple places
2. **Governance gaps** - Operations bypassing receipt/evidence chains
3. **Resource contention** - Multiple processes accessing same resources
4. **Deployment complexity** - Multiple binaries to manage
5. **Testing difficulty** - Hard to integration test fragmented architecture

**This is a critical path blocker** for other work requiring consistent backend behavior.

## Requirements

### Functional Requirements

#### Phase 1: Daemon API Extension
- [ ] Add `/models/*` endpoints for model registry operations (list, install, uninstall, recommend, status)
- [ ] Add `/ml/*` endpoints for ML operations (embed, search, generate, classify)
- [ ] Add `/evidence/*` endpoints for Cathedral operations (session, compliance, bundle, validate)
- [ ] Add `/plan/*` endpoints for plan coordination (submit, inspect, execute)
- [ ] Add `/agents/*` endpoints for agent orchestration (run, status, cancel, list)
- [ ] Add `/search/*` endpoints for Contextum search (hybrid, semantic, keyword)
- [ ] Add `/export/*` endpoints for export operations (start, status, download)
- [ ] Add `/documents/*` endpoints for document operations (acquire, transform, ingest)
- [ ] Add `/system/*` endpoints for system operations (benchmark, resources, config)
- [ ] Expand `/mcp` with additional MCP tool capabilities

#### Phase 2: Service Integration into Daemon
- [ ] Integrate `CathedralModule` (CathedralCoordinator, EvidenceSubstrate, PlanCompiler)
- [ ] Integrate `ModelRegistry` and `HuggingFaceAdapter`
- [ ] Integrate `MLServiceRouter` (embedding, retrieval, generation, classification)
- [ ] Integrate `AgentOrchestrator` and agent execution
- [ ] Integrate `DataEngine` and data operations
- [ ] Integrate `ExportEngine` for export workflows
- [ ] Integrate `ContextumModule` for document search
- [ ] Merge `AnigmaGeminiBridge` functionality into daemon

#### Phase 3: WebServer Removal
- [ ] Port all Vapor routes to Hummingbird in `HTTPServerManager`
- [ ] Port Vapor middleware (EvidenceEnforcement, Authentication, SecurityLogging) to Hummingbird
- [ ] Remove `AnigmaWebServer` executable target
- [ ] Remove Vapor dependency from Package.swift

#### Phase 4: Client Thinning
- [ ] Extend `SidecarBridge` with methods for all new daemon endpoints
- [ ] Refactor Mac App `AppStore` to use daemon APIs instead of direct imports
- [ ] Remove direct module imports from Mac App target dependencies
- [ ] Refactor all CLI executables (anigma, harmonia, doctrine, AST CLI) to thin clients
- [ ] Remove `CLIDatabase` - all persistence through daemon
- [ ] Remove `CLIConfiguration` local storage - config through daemon

#### Phase 5: Authentication & Security
- [ ] Implement OAuth/JWT authentication alongside capability tokens
- [ ] Add multi-user session support
- [ ] Enhance daemon security/sandboxing
- [ ] Implement proper credential storage

#### Phase 6: Observability
- [ ] Add metrics endpoints and collection
- [ ] Implement distributed tracing
- [ ] Add observability dashboard support
- [ ] Enhance telemetry for unified daemon

#### Phase 7: Deployment & Documentation
- [ ] Update launchd plist for unified daemon
- [ ] Update install scripts to remove WebServer binary
- [ ] Write API documentation for all new endpoints
- [ ] Update architecture documentation
- [ ] Add contract tests for client-daemon API

### Non-Functional Requirements
- **Performance**: Optimize during implementation, no hard latency targets but should not regress
- **Reliability**: Daemon must handle all client requests; clients have no offline capability
- **Security**: Enhanced sandboxing/isolation for daemon process
- **Scalability**: Design APIs for future multi-client, multi-user scenarios
- **Testability**: Integration tests via SidecarBridge, contract tests for API boundaries

## Current State

### Mac App (`Sources/AnigmaAppMac/AppStore.swift`)
```swift
// Direct imports that bypass daemon
import CathedralModule
import DevelopumModule
import MLWorkerCommon
import AnigmaDaemonCore

// Direct initialization
self.cathedralCoordinator = CathedralModule.create(config: cathedralConfig)
self.modelRegistry = try! ModelRegistry(registryPath: modelRegistryPath)
self.hfAdapter = try! HuggingFaceAdapter(cacheDir: modelCacheDir)
```

### CLI (`Sources/AnigmaCLI/`)
```swift
// Local database and config
let config = try await CLIConfiguration.shared()
let database = try await CLIDatabase.shared()
let installer = ModelInstaller(config: config, database: database)
```

### WebServer (`Sources/AnigmaWebServer/`)
- Separate Vapor-based HTTP server
- Duplicates Cathedral evidence enforcement
- Own initialization of services

### Daemon (`Packages/AnigmaDaemonCore/`)
- Already has job queue, worker pool, vault, receipts
- HTTP server via Hummingbird
- MCP server
- But missing: ML services, Cathedral, Models, Agents, Export, Search

## Desired State

### Daemon (Unified Backend)
```swift
public actor DaemonServer {
    // Existing infrastructure
    private let jobQueue: JobQueue
    private let workerPool: WorkerPool
    private let vault: VaultAuthority
    private let receiptEngine: ReceiptEngine
    private let httpServer: HTTPServerManager
    private let mcpServer: AnigmaMCPServer
    
    // NEW: Integrated services
    private let cathedralCoordinator: CathedralCoordinator
    private let evidenceSubstrate: EvidenceSubstrate
    private let planCompiler: PlanCompiler
    private let modelRegistry: ModelRegistry
    private let hfAdapter: HuggingFaceAdapter
    private let mlServiceRouter: MLServiceRouter
    private let agentOrchestrator: AgentOrchestrator
    private let dataEngine: DataEngine
    private let exportEngine: ExportEngine
    private let contextumDatabase: ContextumDatabase
    private let searchSystem: SemanticSearchSystem
    
    // NEW: Enhanced auth
    private let authManager: OAuthJWTManager
}
```

### Mac App (Thin Client)
```swift
@MainActor
@Observable
final class AppStore {
    // ONLY backend access is through bridge
    private let bridge: SidecarBridge
    
    // Pure UI state
    var models: [ModelInfo] = []
    var searchResults: [SearchResult] = []
    
    func loadModels() async {
        let response = try await bridge.listModels()
        self.models = response.models
    }
}
```

### Package.swift
```swift
// Mac App dependencies - minimal
.executableTarget(
    name: "AnigmaAppMacExecutable",
    dependencies: [
        "AnigmaSidecar",      // SidecarBridge
        "AnigmaPrimitives",   // Shared Codable types
        "AnigmaClientKit",    // Thin client helpers
        "AnigmaUI",           // UI components
    ]
)

// Daemon dependencies - everything
.target(
    name: "AnigmaDaemonCore",
    dependencies: [
        // All capability modules
        "CathedralModule",
        "ContextumModule",
        "HarmoniaModule",
        "ModelRegistryModule",
        "VectorumModule",
        "DataEngine",
        "ExportCore",
        "AnigmaAgents",
        // ... existing deps
    ]
)
```

## Research Context

### Keywords to Search
- `DaemonServer` - Main coordinator actor, needs service additions
- `HTTPServerManager` - Route definitions, add new endpoints here
- `SidecarBridge` - Client communication, extend with new methods
- `CathedralModule` - Evidence coordination to integrate
- `CathedralCoordinator` - Coordinator pattern to adopt
- `ModelRegistry` - Model management logic to move
- `HuggingFaceAdapter` - HF integration to centralize
- `AppStore` - Mac App state, identify direct imports
- `AnigmaWebServer` - Vapor routes to port
- `CLIDatabase` - CLI persistence to eliminate
- `AgentOrchestrator` - Agent execution to centralize
- `EvidenceSubstrate` - Evidence layer to integrate
- `GeminiBridge` - Gemini integration to merge
- `CapabilityToken` - Current auth, basis for OAuth

### Patterns to Investigate
- `import CathedralModule` in App/CLI - Direct imports to remove
- `router.post("/` - Hummingbird route patterns
- `tokenManager.validateToken` - Auth patterns to extend
- `jobRegistry.register(worker:` - Worker registration patterns
- `receiptEngine.recordActionExecution` - Receipt patterns
- `try await bridge.` - SidecarBridge call patterns
- `@MainActor` isolation - Actor patterns in clients

### Key Decisions Made
| Decision | Rationale |
|----------|-----------|
| Hummingbird only | Daemon uses Hummingbird, remove Vapor entirely |
| Minimal shared types | `AnigmaPrimitives` Codable types shared OK |
| Daemon API first | Build API surface before refactoring clients |
| Single daemon DB | Centralize all persistence in daemon |
| OAuth/JWT auth | Multi-user scenarios need proper auth |
| No offline support | Daemon required, no client-side fallback |
| All CLIs thin | Consistent architecture across all CLIs |
| Hybrid ML | In-process for speed, subprocess for isolation |
| StatusBar unchanged | Keep current direct access (out of scope) |
| Breaking change OK | No migration helpers needed |
| Full documentation | API + architecture docs included |
| No rollback | Ship clean, no feature flags |

## Success Criteria

### Automated Verification
- [ ] `swift build` succeeds with reduced Mac App dependencies
- [ ] `swift test` passes for daemon integration tests
- [ ] Contract tests verify SidecarBridge ↔ Daemon API parity
- [ ] No `import CathedralModule` in Mac App target (except Primitives)
- [ ] No `import ModelRegistry` in Mac App target
- [ ] `AnigmaWebServer` target removed from Package.swift
- [ ] Vapor dependency removed from Package.swift
- [ ] All CLI executables build with thin dependencies

### Manual Verification
- [ ] Mac App functions correctly using only daemon APIs
- [ ] All CLI commands work via daemon
- [ ] Model installation works through daemon
- [ ] ML operations (embed, search, generate) work through daemon
- [ ] Evidence/Cathedral operations work through daemon
- [ ] Agent execution works through daemon
- [ ] Export operations work through daemon
- [ ] Gemini bridge functionality works in daemon
- [ ] OAuth/JWT authentication works
- [ ] Observability metrics are collected
- [ ] launchd service starts unified daemon

## Implementation Phases

### Phase 1: Daemon API Extension (Foundation)
**Files**: `HTTPServerManager.swift`, `DaemonServer.swift`, `AnigmaPrimitives`
**Deliverable**: New endpoints available but not yet integrated with services

### Phase 2: Service Integration (Core Work)
**Files**: `DaemonServer.swift` init, new daemon service files
**Deliverable**: All services initialized and owned by daemon

### Phase 3: WebServer Removal
**Files**: Delete `AnigmaWebServer/`, update `Package.swift`
**Deliverable**: Vapor gone, all routes in Hummingbird

### Phase 4: Client Thinning (Largest Phase)
**Files**: `AppStore.swift`, all CLI files, `SidecarBridge.swift`
**Deliverable**: Clients only use SidecarBridge

### Phase 5: Auth & Security
**Files**: New auth module, daemon security config
**Deliverable**: OAuth/JWT working, enhanced sandboxing

### Phase 6: Observability
**Files**: Metrics collection, tracing, dashboard support
**Deliverable**: Unified observability for daemon

### Phase 7: Deployment & Docs
**Files**: launchd plist, install scripts, documentation
**Deliverable**: Production-ready deployment

## Related Information

### Existing Tickets
- Ticket 001: OperationResult PDF Import (pattern for result envelopes)

### Key Files
- `Packages/AnigmaDaemonCore/DaemonServer.swift` - Main daemon actor
- `Packages/AnigmaDaemonCore/HTTPServerManager.swift` - HTTP routes
- `Packages/AnigmaSidecar/SidecarBridge.swift` - Client bridge
- `Sources/AnigmaAppMac/AppStore.swift` - Mac App state
- `Sources/AnigmaCLI/main.swift` - CLI entry point
- `Packages/CathedralModule/` - Evidence coordination
- `Sources/AnigmaWebServer/` - Vapor routes to port

### Architecture Diagrams
See planning conversation for current vs target architecture diagrams.

## Notes

- **Critical Path**: This work blocks other efforts requiring consistent backend behavior
- **Breaking Change**: No backwards compatibility or migration helpers required
- **Single Ticket**: Despite large scope, keep as one coordinated effort
- **StatusBar Exception**: AnigmaStatusBar keeps current direct access (out of scope)
- **Mobile Out of Scope**: iOS considerations are separate effort

---

*Ticket created: 2026-01-24*
