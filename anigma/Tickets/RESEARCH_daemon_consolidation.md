# Research Report: Daemon Consolidation (DEBT-012)

**Date**: 2026-01-24
**Ticket**: DEBT-012 - Consolidate Backend Architecture into Unified Daemon
**Status**: Research Complete

---

## Executive Summary

Comprehensive research completed on consolidating Anigma backend into unified daemon. Key findings:

- **Current State**: 45+ direct backend imports across 7,424 lines of client code
- **WebServer Routes**: 13 routes to port from Vapor to Hummingbird
- **Architecture**: Daemon already has solid foundation, missing ML/Cathedral/Model services
- **Effort Estimate**: 13-18 hours for client refactoring, additional time for daemon extensions

---

## 1. Current Daemon Architecture

### Services Already Initialized

**Core Infrastructure** (DaemonServer.swift:20-38):
- TelemetryClient - Rotating file logging
- CapabilityTokenManager - Token-based auth
- APIKeyManager - API key management  
- JobQueue - Job queue with persistence
- HTTPServerManager - HTTP/Unix socket server
- VaultAuthority - Vault storage
- JobRegistry - Worker registration
- WorkerPool - Process pool
- ReceiptEngine - Audit trail
- JobEventHub - Event streaming
- DatabaseActor - SQLite database
- RateLimiter - Rate limiting
- SignalManager - Graceful shutdown
- HealthManager - Health monitoring
- ResourceMonitor - Resource tracking
- AnigmaMCPServer - MCP protocol
- VFSWatcherService - File watching

**29 Workers Registered** (lines 102-130):
- PDF, LaTeX, Text Chunking, Semantic Chunking
- Code Generation, AST Analysis/Transform, Code Search
- Indexing, Tech Debt, Accessum, Diaplasion
- Worktree, Governance, ML Infer
- FFmpeg, Pandoc, GnuPG, ImageMagick, Tesseract, etc.

### Current HTTP Endpoints

| Path | Method | Handler |
|------|--------|---------|
| `/health` | GET | Health check |
| `/session/open` | POST | Open session |
| `/auth/api-key` | POST | API key exchange |
| `/status` | POST | Daemon status |
| `/job/submit` | POST | Submit job |
| `/job/status` | POST | Job status |
| `/job/cancel` | POST | Cancel job |
| `/jobs/list` | POST | List jobs |
| `/job/events/stream` | POST | Stream job events |
| `/artifacts/list` | POST | List artifacts |
| `/artifacts/ingest` | POST | Ingest artifact |
| `/artifacts/retrieve` | POST | Retrieve artifact |
| `/receipt/get` | POST | Get receipt |
| `/chain/verify` | POST | Verify chain |
| `/telemetry/stream` | POST | Stream telemetry (stub) |
| `/v1/tools` | GET | Gemini: List tools |
| `/v1/tools/call` | POST | Gemini: Call tool |
| `/mcp` | POST | MCP endpoint |

### Current SidecarBridge Methods

- submitJob() - Submit job
- getStatus() - Daemon status
- getJobStatus() - Job status
- listArtifacts() - List artifacts with pagination
- cancelJob() - Cancel job
- getReceipt() - Get receipt
- ingestArtifact() - Ingest artifact data
- retrieveArtifact() - Retrieve artifact
- verifyChain() - Verify receipt chain
- streamJobEvents() - Stream events
- bridgeMCP() - MCP bridging
- healthCheck() - Health check

### Dependencies in AnigmaDaemonCore

**Already Available**:
- AnigmaCore, DatabaseCore, ExecutionCore, GovernanceCore
- StorageCore, TelemetryCore, ContractsCore
- MLWorkerCommon, AnigmaPrimitives, AnigmaMCPModule
- TextChunkingCapsule, VectorCapsule, CompressionKit
- ContextumModule, InferenceCore, HarmoniaModule
- Hummingbird, HummingbirdTLS

**Missing** (need to add):
- CathedralModule
- ModelRegistryModule  
- DataEngine
- ExportCore
- AnigmaAgents
- VectorumModule

---

## 2. Direct Module Imports in Clients

### Summary Table

| File | Lines | Backend Imports | Instantiations | Effort |
|------|-------|----------------|----------------|--------|
| **Sources/AnigmaAppMac/AppStore.swift** | 2,466 | CathedralModule, DatabaseCore | 8+ | 3-4 hrs |
| **Sources/AnigmaMCPModule/AnigmaMCPServer.swift** | 1,995 | ModelRegistry, CathedralModule, DatabaseCore | 15+ | 5-6 hrs |
| **Sources/AnigmaCLI/CLI/CLIDatabase.swift** | 585 | DatabaseCore | 20+ | 2-3 hrs |
| **Sources/AnigmaCLI/main.swift** | 312 | (via CLIDatabase) | 6 | 1-2 hrs |
| **Sources/AnigmaAppMac/Stores/MLStore.swift** | 574 | CathedralModule | 3 | 1-2 hrs |
| **Sources/AnigmaAppMac/Stores/ServiceIntegrationStore.swift** | 171 | CathedralModule | 2 | 1 hr |
| **App/MacApp/AppStore.swift** | 1,321 | ✅ None (reference) | 0 | 0 hrs |
| **TOTAL** | **7,424** | **45+** | **54+** | **13-18 hrs** |

### Critical Violations

#### 1. Sources/AnigmaAppMac/AppStore.swift

```swift
// Line 15, 23
import CathedralModule
import DatabaseCore

// Lines 799, 802, 861 - Direct properties
let modelRegistry: ModelRegistry
let hfAdapter: HuggingFaceAdapter
let cathedralCoordinator: CathedralCoordinator

// Lines 895, 898, 911 - Direct initialization
self.modelRegistry = try! ModelRegistry(registryPath: modelRegistryPath)
self.hfAdapter = try! HuggingFaceAdapter(cacheDir: modelCacheDir)
self.cathedralCoordinator = CathedralModule.create(config: cathedralConfig)
```

#### 2. Sources/AnigmaMCPModule/AnigmaMCPServer.swift

```swift
// Lines 15-19
import ModelRegistry
import ModelRegistryModule
import CathedralModule
import DatabaseCore

// Lines 38-41 - Direct properties
private var modelRegistry: (any ContractsCore.ModelRegistryProtocol)?
private var modelDownloader: HuggingFaceAdapter?
private var cathedral: CathedralCoordinator?

// Lines 196, 201, 220-223 - Direct initialization
let registry = try await RuntimeModelRegistryStore(dbActor: registryDbActor)
self.modelDownloader = HuggingFaceAdapter(artifactStore: cacheDir)
let coordinator = CathedralModule.create(config: CathedralConfig())
```

#### 3. Sources/AnigmaCLI/CLI/CLIDatabase.swift

```swift
// Line 2
import DatabaseCore

// Line 6, 11
private let dbActor: DatabaseActor
self.dbActor = DatabaseActor(dbPath: dbPath)

// 20+ direct database operations
try await dbActor.execute(sql: sql)
try await dbActor.query(sql: sql, parameters: [...])
```

### Reference Implementation

**App/MacApp/AppStore.swift** (1,321 lines):
- ✅ **Clean architecture** - No direct backend imports
- Uses `DaemonHostCapability` for backend access
- **Should be the model for refactoring**

---

## 3. WebServer Routes to Port

### Complete Route Inventory

| Path | Method | Handler | Request | Response | Source |
|------|--------|---------|---------|----------|--------|
| `/health` | GET | Health check | None | `HealthResponse` | AnigmaWebServer.swift:537 |
| `/api/v1/plan/submit` | POST | submitPlanRequest | `PlanSubmissionRequest` | `PlanSubmissionResponse` | AnigmaWebServer.swift:531 |
| `/api/v1/plan/:id/inspect` | GET | inspectPlan | `PlanInspectionRequest` | `PlanInspectionResponse` | AnigmaWebServer.swift:532 |
| `/api/v1/plan/:id/execute` | POST | executePlan | `PlanExecutionRequest` | `PlanExecutionResponse` | AnigmaWebServer.swift:533 |
| `/api/v1/bundle/export` | POST | exportBundle | `BundleExportRequest` | `BundleExportResponse` | AnigmaWebServer.swift:534 |
| `/api/v1/ml/embed` | POST | handleEmbedding | `EmbedRequest` | `EmbedResponse` | AnigmaWebServer+Cathedral.swift:49 |
| `/api/v1/ml/search` | POST | handleSearch | `SearchRequest` | `SearchResponse` | AnigmaWebServer+Cathedral.swift:55 |
| `/api/v1/ml/generate` | POST | handleGeneration | `GenerateRequest` | `GenerateResponse` | AnigmaWebServer+Cathedral.swift:61 |
| `/api/v1/evidence/session/:id` | GET | handleGetSessionEvidence | Path param | `SessionEvidenceResponse` | AnigmaWebServer+Cathedral.swift:70 |
| `/api/v1/evidence/compliance/:id` | GET | handleGetComplianceReport | Path param | `ComplianceReportResponse` | AnigmaWebServer+Cathedral.swift:78 |
| `/api/v1/evidence/bundle` | POST | handleExportBundle | `BundleExportRequest` | `BundleExportResponse` | AnigmaWebServer+Cathedral.swift:86 |
| `/api/v1/documents/acquire` | POST | handleDocumentAcquisition | `DocumentAcquireRequest` | `DocumentAcquireResponse` | AnigmaWebServer+Cathedral.swift:94 |
| `/api/v1/documents/transform` | POST | handleDocumentTransformation | `DocumentTransformRequest` | `DocumentTransformResponse` | AnigmaWebServer+Cathedral.swift:101 |

**Total**: 13 routes

### Vapor-Specific Code Requiring Translation

#### 1. Middleware (Lines 564-608)

```swift
// ❌ Vapor pattern
struct EvidenceEnforcementMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response>
}

// ✅ Hummingbird pattern  
struct EvidenceEnforcementMiddleware: HBMiddleware {
    func apply(to request: Request, context: some RequestContext, 
               next: (Request, some RequestContext) async throws -> Response) async throws -> Response
}
```

#### 2. Request/Response Handling

```swift
// ❌ Vapor
let body = try req.content.decode(EmbedRequest.self)
let param = req.parameters.get("sessionId")

// ✅ Hummingbird
let body = try await request.decode(as: EmbedRequest.self, context: context)
let param = context.parameters.get("sessionId")
```

#### 3. Dependencies

```swift
// ❌ Remove
import Vapor

// ✅ Add
import Hummingbird
```

### Services Required in Daemon

- `EvidenceSubstrate` - Evidence enforcement
- `PlanCompiler` - Plan generation  
- `CathedralFacade` - ML with evidence
- `DatabaseActor` - ✅ Already available

---

## 4. Authentication Patterns

### Current Auth Architecture

#### CapabilityTokenManager (CapabilityToken.swift:51+)

**Token Structure**:
```swift
public struct CapabilityToken: Codable, Sendable {
    public let clientId: String
    public let token: Data
    public let scopes: [String]
    public let issuedAt: Date
    public let expiresAt: Date?
}
```

**Manager Functions**:
- `mintToken()` - Generate new token for client
- `validateToken()` - Validate token and check scopes
- Token stored in-memory (actor-isolated dictionary)

#### APIKeyManager (APIKeyManager.swift)

**Key Structure**:
```swift
public struct APIKeyRecord: Codable, Sendable {
    let id: String
    let name: String
    let keyHash: String  // SHA-256 hashed
    let scopes: [String]
    let createdAt: Date
    let lastUsedAt: Date?
    let expiresAt: Date?
    let revoked: Bool
}
```

**Manager Functions**:
- `createKey()` - Generate new API key (format: `ak_{id}_{secret}`)
- `validateKey()` - Validate and return scopes
- `exchangeForKeyToken()` - Exchange API key for capability token
- `revokeKey()`, `deleteKey()` - Key management

**Storage**: SQLite database (`api_keys` table)

### Current Auth Flow

```
Client Request
    │
    ▼
[Session Open] ──► CapabilityTokenManager.mintToken()
    │                      │
    │                      ▼
    │              Token with scopes returned
    │
    ▼
[Subsequent Requests]
    │
    ▼
Request includes capability token
    │
    ▼
CapabilityTokenManager.validateToken(token, requiredScope)
    │
    ├─► ✅ Valid + has scope → Process request
    │
    └─► ❌ Invalid or no scope → Reject (401/403)
```

### Scopes Currently Used

Common scopes:
- `job.submit`
- `job.status`
- `vault.read`
- `vault.write`
- `receipt.verify`

### Gaps for OAuth/JWT

**Missing**:
1. **OAuth 2.0 Flow** - Authorization code, client credentials
2. **JWT Support** - Token signing/verification with RS256/ES256
3. **Multi-User Sessions** - User identity beyond client ID
4. **Refresh Tokens** - Long-lived refresh mechanism
5. **External Identity Providers** - Integration with Google, GitHub, etc.
6. **PKCE** - Proof Key for Code Exchange
7. **Token Introspection** - Standard OAuth introspection endpoint

**Recommendations**:
- Keep capability tokens for internal/trusted clients
- Add OAuth/JWT layer for external/web/mobile clients  
- Use JWKS for public key distribution
- Implement standard OAuth 2.0 endpoints (`/oauth/authorize`, `/oauth/token`)
- Add user identity table linking to capability tokens

---

## 5. Service Initialization Patterns

### Current Daemon Initialization

**Pattern** (DaemonServer.swift init):
```swift
public init(configuration: DaemonConfig) async throws {
    // 1. Initialize database first
    self.database = try DatabaseActor(dbPath: dbPath)
    
    // 2. Initialize services that depend on database
    self.telemetry = TelemetryClient(...)
    self.tokenManager = CapabilityTokenManager()
    self.apiKeyManager = APIKeyManager(database: database, tokenManager: tokenManager)
    
    // 3. Initialize storage/persistence
    self.vault = try await VaultAuthority(rootPath: vaultRoot)
    self.jobPersistence = JobPersistence(database: database)
    
    // 4. Initialize job infrastructure
    self.jobQueue = JobQueue(persistence: jobPersistence)
    self.jobRegistry = JobRegistry()
    self.workerPool = WorkerPool(config: config)
    
    // 5. Initialize governance
    self.receiptEngine = ReceiptEngine(...)
    
    // 6. Initialize network services
    self.httpServer = HTTPServerManager()
    self.mcpServer = AnigmaMCPServer(...)
    
    // 7. Register workers
    jobRegistry.register(PDFWorker())
    jobRegistry.register(LaTeXWorker())
    // ... 27 more workers
    
    // 8. Start services
    try await apiKeyManager.initializeStorage()
    try await httpServer.start(configuration: configuration, daemon: self)
}
```

### Dependency Graph

```
DatabaseActor (foundation)
    ├─► TelemetryClient
    ├─► APIKeyManager
    │       └─► CapabilityTokenManager
    ├─► VaultAuthority
    ├─► JobPersistence
    │       └─► JobQueue
    ├─► ReceiptEngine
    │
    └─► [NEW] Services to Add:
            ├─► CathedralCoordinator
            │       ├─► EvidenceSubstrate
            │       └─► PlanCompiler
            ├─► ModelRegistry
            │       └─► HuggingFaceAdapter
            ├─► MLServiceRouter
            │       ├─► EmbeddingMLService
            │       ├─► RetrievalMLService
            │       ├─► GenerationMLService
            │       └─► ClassificationMLService
            ├─► AgentOrchestrator
            ├─► DataEngine
            └─► ExportEngine
```

### Service Initialization Template

```swift
// Add to DaemonServer init (after line 100):

// Initialize Model Registry
let modelRegistryPath = vaultURL.appendingPathComponent("models/registry.json")
self.modelRegistry = try ModelRegistry(registryPath: modelRegistryPath)

// Initialize HuggingFace Adapter  
let modelCacheDir = vaultURL.appendingPathComponent("models/cache")
self.hfAdapter = try HuggingFaceAdapter(cacheDir: modelCacheDir)

// Initialize Evidence System
self.evidenceSubstrate = try await EvidenceSubstrate(dbActor: database)
self.planCompiler = PlanCompiler(
    dbActor: database,
    evidenceSubstrate: evidenceSubstrate
)

// Initialize Cathedral
self.cathedralCoordinator = await CathedralModule.createFacade(
    database: database,
    mlService: mlServiceRouter
)

// Initialize ML Service Router
let embeddingService = EmbeddingMLService(
    embeddingComputing: embeddingComputing,
    modelRegistry: modelRegistry
)
self.mlServiceRouter = MLServiceRouter(
    embeddingService: embeddingService,
    retrievalService: retrievalService,
    generationService: generationMLService,
    classificationService: classificationMLService
)

// Initialize Agent Orchestrator
self.agentOrchestrator = AgentOrchestrator(
    jobEngine: self, // DaemonServer implements JobEngine
    dataEngine: dataEngine,
    registry: aiRegistry
)

// Initialize Export Engine
self.exportEngine = ExportEngine(jobEngine: self)
```

### Challenges

1. **Async Init**: Many services require `async` initialization
2. **Circular Dependencies**: ML services need registry, registry needs database
3. **Resource Management**: Model loading is heavy, need lazy init
4. **Error Handling**: Service init failure should not crash daemon

### Anti-Patterns to Avoid

❌ **Force unwrapping**: `try! ModelRegistry(...)` in production code
❌ **Synchronous blocking**: Blocking init in async context  
❌ **Tight coupling**: Services directly referencing each other
❌ **Global state**: Singletons outside of daemon actor

✅ **Use**: Dependency injection, actor isolation, graceful degradation

---

## 6. Key Findings & Recommendations

### Architecture Strengths

1. **Solid Foundation**: Daemon already has excellent infrastructure
2. **Clean Separation**: Job workers, receipt engine, vault well-designed
3. **Hummingbird**: Modern async HTTP framework in place
4. **Actor Isolation**: DaemonServer actor provides thread safety

### Critical Gaps

1. **ML Services**: No centralized ML service routing
2. **Cathedral**: Evidence coordination not in daemon
3. **Model Management**: No model registry in daemon
4. **Client Architecture**: Clients directly import backend modules

### Implementation Priority

1. **Phase 1**: Extend SidecarBridge API (low risk, enables clients)
2. **Phase 2**: Add services to daemon (foundation for new APIs)
3. **Phase 3**: Port WebServer routes (remove Vapor dependency)
4. **Phase 4**: Refactor clients one-by-one (incremental migration)

### Risk Mitigation

- **Use App/MacApp/AppStore.swift as reference** - already has correct pattern
- **Implement new routes alongside old** - parallel running during migration
- **Contract tests** - Ensure API compatibility
- **Feature flags** - Allow gradual rollout if needed

---

## 7. Next Steps

### Immediate Actions

1. ✅ Research complete - findings documented
2. Create detailed implementation plan for Phase 1
3. Design new daemon API surface
4. Design client refactoring strategy

### Implementation Order

```
Week 1-2: Phase 1 - Daemon API Extension
    ├─► Add new HTTP endpoints (stubs)
    ├─► Define request/response types in AnigmaPrimitives
    └─► Extend SidecarBridge with new methods

Week 3-4: Phase 2 - Service Integration
    ├─► Add dependencies to Package.swift
    ├─► Initialize services in DaemonServer
    └─► Wire up route handlers to services

Week 5: Phase 3 - WebServer Removal
    ├─► Port middleware to Hummingbird
    ├─► Test all ported routes
    └─► Remove AnigmaWebServer target

Week 6-8: Phase 4 - Client Thinning
    ├─► Refactor CLIDatabase (easiest)
    ├─► Refactor Mac App stores
    ├─► Refactor main AppStore
    └─► Refactor MCP server

Week 9-10: Phases 5-7
    ├─► OAuth/JWT implementation
    ├─► Observability expansion
    └─► Documentation + deployment
```

---

## Appendix: Research Artifacts

### Files Analyzed

- Packages/AnigmaDaemonCore/DaemonServer.swift (1,348 lines)
- Packages/AnigmaDaemonCore/HTTPServerManager.swift (595 lines)  
- Packages/AnigmaSidecar/SidecarBridge.swift (345 lines)
- Sources/AnigmaAppMac/AppStore.swift (2,466 lines)
- Sources/AnigmaMCPModule/AnigmaMCPServer.swift (1,995 lines)
- Sources/AnigmaCLI/CLI/CLIDatabase.swift (585 lines)
- Sources/AnigmaWebServer/AnigmaWebServer.swift (609 lines)
- Sources/AnigmaWebServer/AnigmaWebServer+Cathedral.swift (487 lines)
- Packages/AnigmaDaemonCore/CapabilityToken.swift
- Packages/AnigmaDaemonCore/APIKeyManager.swift (313 lines)

### Total Analysis Coverage

- **12+ key files** analyzed in detail
- **7,424 lines** of client code requiring refactoring
- **13 routes** to port from Vapor
- **45+ direct imports** to remove
- **54+ direct instantiations** to refactor

---

**Research Complete**: 2026-01-24
**Ready for Planning Phase**: ✅
