# Implementation Plan: Daemon Consolidation (DEBT-012)

**Date**: 2026-01-24
**Ticket**: DEBT-012 - Consolidate Backend Architecture into Unified Daemon
**Status**: Planning Complete
**Research**: See RESEARCH_daemon_consolidation.md

---

## Executive Summary

This document provides a detailed, actionable implementation plan for consolidating the Anigma backend into a unified daemon. The plan is broken into 7 phases with specific tasks, acceptance criteria, and dependencies.

**Total Estimated Effort**: 10-12 weeks (2.5-3 months)
**Team Size**: 1-2 engineers
**Risk Level**: Medium (well-researched, incremental approach)

---

## Implementation Phases

### Phase 1: Daemon API Extension (Week 1-2)
**Goal**: Add new HTTP endpoints to daemon (stubs) to enable future client migration
**Effort**: 2 weeks
**Risk**: Low

### Phase 2: Service Integration (Week 3-4)
**Goal**: Initialize Cathedral, ModelRegistry, ML services in daemon
**Effort**: 2 weeks
**Risk**: Medium (complex initialization)

### Phase 3: WebServer Removal (Week 5)
**Goal**: Port Vapor routes to Hummingbird, remove Vapor dependency
**Effort**: 1 week
**Risk**: Low (straightforward translation)

### Phase 4: Client Thinning (Week 6-8)
**Goal**: Refactor Mac App, CLI to use daemon APIs only
**Effort**: 3 weeks
**Risk**: Medium (large codebase changes)

### Phase 5: Auth & Security (Week 9)
**Goal**: Implement OAuth/JWT, enhance security
**Effort**: 1 week
**Risk**: Medium (new auth flows)

### Phase 6: Observability (Week 10)
**Goal**: Add metrics, tracing, dashboards
**Effort**: 1 week
**Risk**: Low

### Phase 7: Deployment & Docs (Week 11-12)
**Goal**: Update deployment configs, write documentation
**Effort**: 2 weeks
**Risk**: Low

---

## Phase 1: Daemon API Extension

### 1.1 Define New Request/Response Types

**File**: `Packages/AnigmaPrimitives/DaemonAPI.swift` (new file)

**Types to Add**:

```swift
// Model Registry API
public struct AnigmaListModelsRequest: Codable {
    let ctx: AnigmaRequestContext
}

public struct AnigmaListModelsResponse: Codable {
    let models: [ModelInfo]
    let error: AnigmaErrorStatus?
}

public struct ModelInfo: Codable {
    let id: String
    let name: String
    let type: String
    let sizeGB: Double
    let quantization: String
    let installedAt: Date?
}

public struct AnigmaInstallModelRequest: Codable {
    let ctx: AnigmaRequestContext
    let modelId: String
    let repo: String?
    let revision: String?
}

public struct AnigmaInstallModelResponse: Codable {
    let modelId: String
    let installPath: String?
    let error: AnigmaErrorStatus?
}

// ML Operations API
public struct AnigmaEmbedRequest: Codable {
    let ctx: AnigmaRequestContext
    let text: String
    let model: String
    let sessionId: String?
}

public struct AnigmaEmbedResponse: Codable {
    let vector: [Float]
    let dimension: Int
    let model: String
    let executionTimeMs: Int
    let error: AnigmaErrorStatus?
}

public struct AnigmaSearchRequest: Codable {
    let ctx: AnigmaRequestContext
    let query: String
    let model: String
    let topK: Int?
    let threshold: Double?
    let sessionId: String?
}

public struct AnigmaSearchResponse: Codable {
    let results: [SearchResultItem]
    let query: String
    let model: String
    let executionTimeMs: Int
    let error: AnigmaErrorStatus?
}

public struct SearchResultItem: Codable {
    let documentId: String
    let score: Double
    let rank: Int
    let snippet: String?
}

// Evidence API
public struct AnigmaSessionEvidenceRequest: Codable {
    let ctx: AnigmaRequestContext
    let sessionId: String
}

public struct AnigmaSessionEvidenceResponse: Codable {
    let sessionId: String
    let evidenceCount: Int
    let evidence: [EvidenceItem]
    let error: AnigmaErrorStatus?
}

public struct EvidenceItem: Codable {
    let id: String
    let type: String
    let timestamp: Date
    let agentId: String
}

// Plan Coordination API
public struct AnigmaPlanSubmitRequest: Codable {
    let ctx: AnigmaRequestContext
    let operationType: String
    let sessionContext: String?
    let parameters: [String: String]
    let priority: String
}

public struct AnigmaPlanSubmitResponse: Codable {
    let planId: String
    let status: String
    let evidenceHash: String?
    let error: AnigmaErrorStatus?
}

// Agent Orchestration API
public struct AnigmaAgentRunRequest: Codable {
    let ctx: AnigmaRequestContext
    let agentId: String
    let task: String
    let parameters: [String: String]?
}

public struct AnigmaAgentRunResponse: Codable {
    let runId: String
    let status: String
    let error: AnigmaErrorStatus?
}

// Export API
public struct AnigmaExportStartRequest: Codable {
    let ctx: AnigmaRequestContext
    let format: String
    let documentIds: [String]
    let options: [String: String]?
}

public struct AnigmaExportStartResponse: Codable {
    let exportId: String
    let jobId: String
    let error: AnigmaErrorStatus?
}
```

**Tasks**:
- [ ] Create `Packages/AnigmaPrimitives/DaemonAPI.swift`
- [ ] Add all request/response types
- [ ] Ensure Codable conformance
- [ ] Add documentation comments
- [ ] Add to AnigmaPrimitives target in Package.swift

**Acceptance Criteria**:
- All types compile
- Types are Codable
- No dependencies on non-Primitives modules

---

### 1.2 Add HTTP Routes (Stubs)

**File**: `Packages/AnigmaDaemonCore/HTTPServerManager.swift`

**New Routes to Add**:

```swift
// Models endpoints (after line 402)
router.post("/models/list") { request, context in
    let body = try await request.decode(as: AnigmaListModelsRequest.self, context: context)
    let response = try await daemon.handleListModels(ctx: body.ctx.toDaemonContext())
    return response
}

router.post("/models/install") { request, context in
    let body = try await request.decode(as: AnigmaInstallModelRequest.self, context: context)
    let response = try await daemon.handleInstallModel(
        ctx: body.ctx.toDaemonContext(),
        modelId: body.modelId,
        repo: body.repo,
        revision: body.revision
    )
    return response
}

router.post("/models/uninstall") { request, context in
    // Similar pattern
}

// ML endpoints
router.post("/ml/embed") { request, context in
    let body = try await request.decode(as: AnigmaEmbedRequest.self, context: context)
    let response = try await daemon.handleMLEmbed(ctx: body.ctx.toDaemonContext(), request: body)
    return response
}

router.post("/ml/search") { request, context in
    let body = try await request.decode(as: AnigmaSearchRequest.self, context: context)
    let response = try await daemon.handleMLSearch(ctx: body.ctx.toDaemonContext(), request: body)
    return response
}

// Evidence endpoints
router.get("/evidence/session/:sessionId") { request, context in
    guard let sessionId = context.parameters.get("sessionId") else {
        throw HTTPError(.badRequest)
    }
    let ctxBody = try await request.decode(as: AnigmaSessionEvidenceRequest.self, context: context)
    let response = try await daemon.handleGetSessionEvidence(
        ctx: ctxBody.ctx.toDaemonContext(),
        sessionId: sessionId
    )
    return response
}

// Plan endpoints
router.post("/plan/submit") { request, context in
    let body = try await request.decode(as: AnigmaPlanSubmitRequest.self, context: context)
    let response = try await daemon.handleSubmitPlan(ctx: body.ctx.toDaemonContext(), request: body)
    return response
}

// Agent endpoints
router.post("/agents/run") { request, context in
    let body = try await request.decode(as: AnigmaAgentRunRequest.self, context: context)
    let response = try await daemon.handleAgentRun(ctx: body.ctx.toDaemonContext(), request: body)
    return response
}

// Export endpoints
router.post("/export/start") { request, context in
    let body = try await request.decode(as: AnigmaExportStartRequest.self, context: context)
    let response = try await daemon.handleExportStart(ctx: body.ctx.toDaemonContext(), request: body)
    return response
}
```

**Tasks**:
- [ ] Add all new route definitions
- [ ] Add ResponseGenerator conformances for new response types
- [ ] Test routes return "not implemented" stubs
- [ ] Document route patterns

**Acceptance Criteria**:
- Routes are registered
- Routes return stub responses (not 404)
- No runtime errors

---

### 1.3 Add Stub Handler Methods in DaemonServer

**File**: `Packages/AnigmaDaemonCore/DaemonServer.swift`

**Stub Handlers to Add** (after existing handlers, ~line 1300):

```swift
// MARK: - Model Registry Handlers

func handleListModels(ctx: DaemonRequestContext) async throws -> AnigmaListModelsResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "models.list")
    
    // TODO: Implement with ModelRegistry
    return AnigmaListModelsResponse(
        models: [],
        error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Model registry not yet integrated", detailJson: nil)
    )
}

func handleInstallModel(
    ctx: DaemonRequestContext,
    modelId: String,
    repo: String?,
    revision: String?
) async throws -> AnigmaInstallModelResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "models.install")
    
    // TODO: Implement with HuggingFaceAdapter
    return AnigmaInstallModelResponse(
        modelId: modelId,
        installPath: nil,
        error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Model installation not yet integrated", detailJson: nil)
    )
}

// MARK: - ML Operation Handlers

func handleMLEmbed(
    ctx: DaemonRequestContext,
    request: AnigmaEmbedRequest
) async throws -> AnigmaEmbedResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "ml.embed")
    
    // TODO: Implement with MLServiceRouter
    return AnigmaEmbedResponse(
        vector: [],
        dimension: 0,
        model: request.model,
        executionTimeMs: 0,
        error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Embedding service not yet integrated", detailJson: nil)
    )
}

// MARK: - Evidence Handlers

func handleGetSessionEvidence(
    ctx: DaemonRequestContext,
    sessionId: String
) async throws -> AnigmaSessionEvidenceResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "evidence.read")
    
    // TODO: Implement with Cathedral
    return AnigmaSessionEvidenceResponse(
        sessionId: sessionId,
        evidenceCount: 0,
        evidence: [],
        error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Evidence system not yet integrated", detailJson: nil)
    )
}

// MARK: - Plan Handlers

func handleSubmitPlan(
    ctx: DaemonRequestContext,
    request: AnigmaPlanSubmitRequest
) async throws -> AnigmaPlanSubmitResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "plan.submit")
    
    // TODO: Implement with PlanCompiler
    return AnigmaPlanSubmitResponse(
        planId: UUID().uuidString,
        status: "not_implemented",
        evidenceHash: nil,
        error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Plan coordination not yet integrated", detailJson: nil)
    )
}

// MARK: - Agent Handlers

func handleAgentRun(
    ctx: DaemonRequestContext,
    request: AnigmaAgentRunRequest
) async throws -> AnigmaAgentRunResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "agents.run")
    
    // TODO: Implement with AgentOrchestrator
    return AnigmaAgentRunResponse(
        runId: UUID().uuidString,
        status: "not_implemented",
        error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Agent orchestration not yet integrated", detailJson: nil)
    )
}

// MARK: - Export Handlers

func handleExportStart(
    ctx: DaemonRequestContext,
    request: AnigmaExportStartRequest
) async throws -> AnigmaExportStartResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "export.create")
    
    // TODO: Implement with ExportEngine
    return AnigmaExportStartResponse(
        exportId: UUID().uuidString,
        jobId: "",
        error: AnigmaErrorStatus(code: "NOT_IMPLEMENTED", message: "Export engine not yet integrated", detailJson: nil)
    )
}
```

**Tasks**:
- [ ] Add all stub handler methods
- [ ] Ensure proper token validation
- [ ] Add TODO comments for Phase 2
- [ ] Test stubs return expected structure

**Acceptance Criteria**:
- All handlers compile
- Handlers validate tokens
- Handlers return proper response structure

---

### 1.4 Extend SidecarBridge

**File**: `Packages/AnigmaSidecar/SidecarBridge.swift`

**New Methods to Add** (after line 218):

```swift
// MARK: - Model Registry Operations

public func listModels() async throws -> AnigmaListModelsResponse {
    let request = AnigmaListModelsRequest(ctx: makeContext())
    return try await post("/models/list", body: request)
}

public func installModel(modelId: String, repo: String? = nil, revision: String? = nil) async throws -> AnigmaInstallModelResponse {
    let request = AnigmaInstallModelRequest(
        ctx: makeContext(),
        modelId: modelId,
        repo: repo,
        revision: revision
    )
    return try await post("/models/install", body: request)
}

// MARK: - ML Operations

public func embed(text: String, model: String, sessionId: String? = nil) async throws -> AnigmaEmbedResponse {
    let request = AnigmaEmbedRequest(
        ctx: makeContext(),
        text: text,
        model: model,
        sessionId: sessionId
    )
    return try await post("/ml/embed", body: request)
}

public func search(query: String, model: String, topK: Int = 10, threshold: Double = 0.7, sessionId: String? = nil) async throws -> AnigmaSearchResponse {
    let request = AnigmaSearchRequest(
        ctx: makeContext(),
        query: query,
        model: model,
        topK: topK,
        threshold: threshold,
        sessionId: sessionId
    )
    return try await post("/ml/search", body: request)
}

// MARK: - Evidence Operations

public func getSessionEvidence(sessionId: String) async throws -> AnigmaSessionEvidenceResponse {
    let request = AnigmaSessionEvidenceRequest(
        ctx: makeContext(),
        sessionId: sessionId
    )
    return try await get("/evidence/session/\(sessionId)")
}

// MARK: - Plan Coordination

public func submitPlan(operationType: String, parameters: [String: String], priority: String = "normal") async throws -> AnigmaPlanSubmitResponse {
    let request = AnigmaPlanSubmitRequest(
        ctx: makeContext(),
        operationType: operationType,
        sessionContext: nil,
        parameters: parameters,
        priority: priority
    )
    return try await post("/plan/submit", body: request)
}

// MARK: - Agent Operations

public func runAgent(agentId: String, task: String, parameters: [String: String]? = nil) async throws -> AnigmaAgentRunResponse {
    let request = AnigmaAgentRunRequest(
        ctx: makeContext(),
        agentId: agentId,
        task: task,
        parameters: parameters
    )
    return try await post("/agents/run", body: request)
}

// MARK: - Export Operations

public func startExport(format: String, documentIds: [String], options: [String: String]? = nil) async throws -> AnigmaExportStartResponse {
    let request = AnigmaExportStartRequest(
        ctx: makeContext(),
        format: format,
        documentIds: documentIds,
        options: options
    )
    return try await post("/export/start", body: request)
}
```

**Tasks**:
- [ ] Add all new SidecarBridge methods
- [ ] Ensure consistent error handling
- [ ] Add method documentation
- [ ] Test against stub endpoints

**Acceptance Criteria**:
- All methods compile
- Methods call correct endpoints
- Error handling works

---

### Phase 1 Deliverables

- [ ] New request/response types in AnigmaPrimitives
- [ ] New HTTP routes in HTTPServerManager
- [ ] Stub handler methods in DaemonServer
- [ ] Extended SidecarBridge API
- [ ] All stubs return "NOT_IMPLEMENTED" errors
- [ ] Daemon builds and runs with new endpoints
- [ ] SidecarBridge can call new endpoints

**Testing**:
```bash
# Start daemon
swift run anigmad

# Test new endpoints (should return NOT_IMPLEMENTED)
curl -X POST http://localhost:8080/models/list -H "Content-Type: application/json" -d '{...}'
```

---

## Phase 2: Service Integration

### 2.1 Add Dependencies to Package.swift

**File**: `Package.swift`

**Change at line ~531** (AnigmaDaemonCore target dependencies):

```swift
.target(
    name: "AnigmaDaemonCore",
    dependencies: [
        // Existing
        "AnigmaCore",
        "DatabaseCore",
        "ExecutionCore",
        // ... existing deps
        
        // NEW - Add these
        "CathedralModule",
        "ModelRegistryModule",
        "VectorumModule",
        "DataEngine",
        "ExportCore",
        "AnigmaAgents",
    ],
    path: "Packages/AnigmaDaemonCore",
    swiftSettings: strictConcurrencySettings
)
```

**Tasks**:
- [ ] Add new dependencies
- [ ] Verify no circular dependencies
- [ ] Run `swift build` to verify

**Acceptance Criteria**:
- Package resolves
- No build errors
- All modules available to DaemonCore

---

### 2.2 Initialize Services in DaemonServer

**File**: `Packages/AnigmaDaemonCore/DaemonServer.swift`

**Add Properties** (after line 38):

```swift
// Phase 2: Integrated Services
private let modelRegistry: ModelRegistry
private let hfAdapter: HuggingFaceAdapter
private let cathedralCoordinator: CathedralCoordinator
private let evidenceSubstrate: EvidenceSubstrate
private let planCompiler: PlanCompiler
private let mlServiceRouter: MLServiceRouter
private let agentOrchestrator: AgentOrchestrator
private let dataEngine: DataEngine
private let exportEngine: ExportEngine
```

**Add Initialization** (in init, after line 100):

```swift
// Initialize Model Registry
let modelRegistryPath = vaultRoot.appendingPathComponent("models/registry.json")
try FileManager.default.createDirectory(
    at: modelRegistryPath.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
self.modelRegistry = try ModelRegistry(registryPath: modelRegistryPath.path)

// Initialize HuggingFace Adapter
let modelCacheDir = vaultRoot.appendingPathComponent("models/cache")
self.hfAdapter = try HuggingFaceAdapter(cacheDir: modelCacheDir.path)

// Initialize Evidence Substrate
self.evidenceSubstrate = try await EvidenceSubstrate(dbActor: database)

// Initialize Plan Compiler
self.planCompiler = PlanCompiler(
    dbActor: database,
    evidenceSubstrate: evidenceSubstrate
)

// Initialize ML Service Router
let embeddingService = EmbeddingMLService(
    embeddingComputing: embeddingComputing, // Need to add this
    modelRegistry: modelRegistry
)
let retrievalService = RetrievalMLService(
    searchSystem: SemanticSearchSystem(),
    embeddingComputing: embeddingComputing,
    modelRegistry: modelRegistry,
    database: contextumDatabase // Need to add this
)
self.mlServiceRouter = MLServiceRouter(
    embeddingService: embeddingService,
    retrievalService: retrievalService,
    generationService: GenerationMLService(),
    classificationService: ClassificationMLService()
)

// Initialize Cathedral Coordinator
self.cathedralCoordinator = await CathedralModule.createFacade(
    database: database,
    mlService: mlServiceRouter
)

// Initialize Agent Orchestrator  
self.agentOrchestrator = AgentOrchestrator(
    jobEngine: self, // DaemonServer implements JobEngine protocol
    dataEngine: dataEngine,
    registry: aiRegistry // Need to create this
)

// Initialize Data Engine
self.dataEngine = DataEngine()

// Initialize Export Engine
self.exportEngine = ExportEngine(jobEngine: self)
```

**Tasks**:
- [ ] Add service properties
- [ ] Add initialization code
- [ ] Handle initialization errors gracefully
- [ ] Add logging for service startup
- [ ] Create helper services (embeddingComputing, aiRegistry)

**Acceptance Criteria**:
- All services initialize without errors
- Daemon starts successfully
- Services are accessible from handlers

---

### 2.3 Implement Handler Methods

**File**: `Packages/AnigmaDaemonCore/DaemonServer.swift`

Replace stub methods with real implementations:

```swift
func handleListModels(ctx: DaemonRequestContext) async throws -> AnigmaListModelsResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "models.list")
    
    let models = try await modelRegistry.listAll()
    let modelInfos = models.map { model in
        ModelInfo(
            id: model.id,
            name: model.name,
            type: model.type.rawValue,
            sizeGB: Double(model.sizeBytes) / 1_000_000_000.0,
            quantization: model.quantization ?? "unknown",
            installedAt: model.installedAt
        )
    }
    
    return AnigmaListModelsResponse(
        models: modelInfos,
        error: nil
    )
}

func handleInstallModel(
    ctx: DaemonRequestContext,
    modelId: String,
    repo: String?,
    revision: String?
) async throws -> AnigmaInstallModelResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "models.install")
    
    // Use HF adapter to download
    let actualRepo = repo ?? modelRegistry.getDefaultRepo(for: modelId)
    let result = try await hfAdapter.fetchAndVerify(
        repo: actualRepo,
        revision: revision ?? "main"
    )
    
    // Register with model registry
    let spec = ModelSpec(
        id: modelId,
        name: modelId,
        type: .embedding, // Infer from modelId
        repo: actualRepo,
        revision: revision ?? "main",
        sizeBytes: result.sizeBytes,
        quantization: nil
    )
    _ = try await modelRegistry.register(spec, installPath: result.installPath)
    
    // Record receipt
    let receipt = try await receiptEngine.recordActionExecution(
        actionName: "model.install",
        authority: "anigmad",
        decision: .allowed,
        reasonCode: "MODEL_INSTALLED",
        inputs: ["modelId": modelId, "repo": actualRepo],
        outputs: ["installPath": result.installPath]
    )
    
    return AnigmaInstallModelResponse(
        modelId: modelId,
        installPath: result.installPath,
        error: nil
    )
}

func handleMLEmbed(
    ctx: DaemonRequestContext,
    request: AnigmaEmbedRequest
) async throws -> AnigmaEmbedResponse {
    _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "ml.embed")
    
    // Route through Cathedral for evidence
    let operation = MLOperation(
        type: .embedding,
        sessionId: request.sessionId ?? UUID().uuidString,
        agentId: ctx.clientId,
        parameters: [
            "text": request.text,
            "model": request.model
        ]
    )
    
    let startTime = Date()
    let result = try await cathedralCoordinator.executeOperation(
        operation: operation,
        requirement: .moderate
    )
    let duration = Int(Date().timeIntervalSince(startTime) * 1000)
    
    // Parse vector from result
    let vectorData = result.data["vector"]?.data(using: .utf8) ?? Data()
    let vector = try JSONDecoder().decode([Float].self, from: vectorData)
    
    return AnigmaEmbedResponse(
        vector: vector,
        dimension: vector.count,
        model: request.model,
        executionTimeMs: duration,
        error: nil
    )
}

// Similar implementations for other handlers...
```

**Tasks**:
- [ ] Implement all handler methods
- [ ] Add error handling
- [ ] Add receipt recording
- [ ] Add logging
- [ ] Test each handler

**Acceptance Criteria**:
- All handlers work end-to-end
- Errors are handled gracefully
- Receipts are recorded
- No "NOT_IMPLEMENTED" errors

---

### Phase 2 Deliverables

- [ ] All service dependencies added
- [ ] All services initialize in daemon
- [ ] All handler methods implemented
- [ ] Integration tests pass
- [ ] Receipts recorded for all operations

**Testing**:
```bash
# Start daemon
swift run anigmad

# Test model list (should return real models)
curl -X POST http://localhost:8080/models/list -H "Content-Type: application/json" -d '{...}'

# Test embedding (should return vector)
curl -X POST http://localhost:8080/ml/embed -H "Content-Type: application/json" -d '{...}'
```

---

## Phase 3: WebServer Removal

### 3.1 Port Middleware to Hummingbird

**File**: `Packages/AnigmaDaemonCore/Middleware/` (new directory)

Create three new middleware files:

**EvidenceEnforcementMiddleware.swift**:
```swift
import Hummingbird
import AnigmaCore
import CathedralModule

struct EvidenceEnforcementMiddleware: HBMiddleware {
    let evidenceSubstrate: EvidenceSubstrate
    
    func apply(
        to request: Request,
        context: some RequestContext,
        next: (Request, some RequestContext) async throws -> Response
    ) async throws -> Response {
        // Extract operation from path
        let operation = extractOperation(from: request.uri.path)
        
        // Enforce evidence requirements
        do {
            try await evidenceSubstrate.enforceEvidenceSubstrate(
                operation: operation,
                evidenceLevel: .moderate
            )
        } catch CathedralError.operationBlocked(let reason) {
            // Return 403 with reason
            return Response(
                status: .forbidden,
                body: .init(string: reason)
            )
        }
        
        return try await next(request, context)
    }
    
    private func extractOperation(from path: String) -> String {
        // Extract operation type from path
        // e.g., "/api/v1/ml/embed" -> "ml.embed"
        let components = path.split(separator: "/")
        if components.count >= 4 {
            return "\(components[2]).\(components[3])"
        }
        return "unknown"
    }
}
```

**Tasks**:
- [ ] Create middleware directory
- [ ] Port EvidenceEnforcementMiddleware
- [ ] Port AuthenticationMiddleware
- [ ] Port SecurityLoggingMiddleware
- [ ] Add middleware to router

**Acceptance Criteria**:
- All middleware compile
- Middleware integrate with Hummingbird
- Evidence enforcement works

---

### 3.2 Port Route Handlers

Already done in Phase 2! The handlers are implemented.

**Tasks**:
- [ ] Verify all WebServer routes have equivalents
- [ ] Test all ported routes
- [ ] Compare behavior with original

**Acceptance Criteria**:
- All 13 routes work identically
- Response formats match
- Error handling matches

---

### 3.3 Remove WebServer Target

**Files to Delete**:
- `Sources/AnigmaWebServer/AnigmaWebServer.swift`
- `Sources/AnigmaWebServer/AnigmaWebServer+Cathedral.swift`
- `Sources/AnigmaWebServer/` (entire directory)

**File**: `Package.swift`

Remove:
```swift
// Remove from products
.executable(name: "anigma-web-server", targets: ["AnigmaWebServer"]),

// Remove target
.executableTarget(
    name: "AnigmaWebServer",
    dependencies: [
        "Vapor",
        "DatabaseCore",
        // ...
    ]
),

// Remove from dependencies
.package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
```

**Tasks**:
- [ ] Delete AnigmaWebServer files
- [ ] Remove from Package.swift
- [ ] Remove Vapor dependency
- [ ] Run `swift build` to verify

**Acceptance Criteria**:
- Builds successfully
- No Vapor references
- No AnigmaWebServer executable

---

### Phase 3 Deliverables

- [ ] All middleware ported
- [ ] AnigmaWebServer deleted
- [ ] Vapor removed
- [ ] All tests pass

---

## Phase 4: Client Thinning

### 4.1 Refactor CLIDatabase

**Strategy**: Remove `CLIDatabase` entirely, replace with daemon calls

**File**: `Sources/AnigmaCLI/CLI/ChatInterface.swift`

**Before**:
```swift
private let database: CLIDatabase

func saveMessage() async {
    try await database.execute(sql: "INSERT INTO messages ...")
}
```

**After**:
```swift
private let bridge: SidecarBridge

func saveMessage() async {
    // Messages saved in daemon's database via job submission
    let job = try await bridge.submitJob(...)
}
```

**Tasks**:
- [ ] Audit all `CLIDatabase` usage
- [ ] Design daemon APIs for CLI data
- [ ] Refactor ChatInterface
- [ ] Refactor ModelInstaller to use bridge
- [ ] Remove `CLIDatabase.swift`
- [ ] Update CLI main.swift

**Acceptance Criteria**:
- CLI works without local database
- All data persisted in daemon
- No `import DatabaseCore` in CLI

---

### 4.2 Refactor Mac App Stores

**Files**:
- `Sources/AnigmaAppMac/Stores/MLStore.swift`
- `Sources/AnigmaAppMac/Stores/ServiceIntegrationStore.swift`

**Strategy**: Use `DaemonHostCapability` pattern from `App/MacApp/AppStore.swift`

**Before**:
```swift
let modelRegistry = try! ModelRegistry(registryPath: path)
let models = try await modelRegistry.query()
```

**After**:
```swift
let modelRegistry = daemonCapability.modelRegistry
let models = try await modelRegistry.query()
```

**Tasks**:
- [ ] Refactor MLStore to use DaemonHostCapability
- [ ] Refactor ServiceIntegrationStore
- [ ] Remove direct imports
- [ ] Test stores work via daemon

**Acceptance Criteria**:
- Stores use daemon APIs only
- No direct module imports
- All functionality preserved

---

### 4.3 Refactor Main AppStore

**File**: `Sources/AnigmaAppMac/AppStore.swift`

**Strategy**: Migrate to pattern from `App/MacApp/AppStore.swift`

**Tasks**:
- [ ] Replace ModelRegistry with daemon client
- [ ] Replace HuggingFaceAdapter with daemon client
- [ ] Replace CathedralCoordinator with daemon client
- [ ] Remove all direct imports
- [ ] Update initialization
- [ ] Test all app functionality

**Acceptance Criteria**:
- AppStore matches reference implementation
- No backend imports
- All features work

---

### 4.4 Refactor MCP Server

**File**: `Sources/AnigmaMCPModule/AnigmaMCPServer.swift`

**Strategy**: Call daemon instead of direct initialization

**Tasks**:
- [ ] Replace ModelRegistry with bridge calls
- [ ] Replace HuggingFaceAdapter with bridge calls
- [ ] Replace Cathedral with bridge calls
- [ ] Remove direct imports
- [ ] Test MCP functionality

**Acceptance Criteria**:
- MCP server works via daemon
- No direct backend access
- All MCP tools functional

---

### Phase 4 Deliverables

- [ ] CLI uses daemon only
- [ ] Mac App uses daemon only
- [ ] MCP uses daemon only
- [ ] All clients thin
- [ ] 54+ direct instantiations removed

**Testing**:
```bash
# Test CLI
anigma chat

# Test Mac App
open AnigmaApp.app

# Test MCP
anigma-mcp
```

---

## Phase 5: Auth & Security

### 5.1 Implement OAuth/JWT

**File**: `Packages/AnigmaDaemonCore/Auth/OAuthManager.swift` (new)

**Implementation**:
- OAuth 2.0 authorization code flow
- JWT token signing with RS256
- JWKS endpoint for public keys
- User identity table
- Refresh token support

**Tasks**:
- [ ] Create OAuthManager actor
- [ ] Add OAuth endpoints (/oauth/authorize, /oauth/token)
- [ ] Implement JWT signing/verification
- [ ] Add user identity table
- [ ] Integrate with existing CapabilityTokenManager

**Acceptance Criteria**:
- OAuth flow works end-to-end
- JWT tokens validated correctly
- Refresh tokens work

---

### 5.2 Enhance Security

**Tasks**:
- [ ] Add sandboxing configuration
- [ ] Implement rate limiting per user
- [ ] Add audit logging for auth events
- [ ] Security review of daemon

**Acceptance Criteria**:
- Daemon runs in sandbox
- Rate limiting prevents abuse
- All auth events logged

---

## Phase 6: Observability

### 6.1 Add Metrics

**File**: `Packages/AnigmaDaemonCore/Observability/MetricsCollector.swift` (new)

**Metrics to Track**:
- Request count per endpoint
- Request duration
- Error rate
- Active sessions
- Job queue depth
- Worker pool utilization

**Tasks**:
- [ ] Create MetricsCollector
- [ ] Add metrics endpoints (/metrics)
- [ ] Integrate with Prometheus format
- [ ] Add dashboards

**Acceptance Criteria**:
- Metrics collected
- /metrics endpoint works
- Dashboard displays data

---

### 6.2 Add Tracing

**Tasks**:
- [ ] Add distributed tracing support
- [ ] Integrate with OpenTelemetry
- [ ] Trace request flows
- [ ] Add trace IDs to logs

**Acceptance Criteria**:
- Traces captured
- Request flows visible
- Trace IDs in logs

---

## Phase 7: Deployment & Docs

### 7.1 Update Deployment

**File**: `launchd/com.anigma.daemon.plist`

**Tasks**:
- [ ] Update plist for unified daemon
- [ ] Remove WebServer plist
- [ ] Update install scripts
- [ ] Test installation

**Acceptance Criteria**:
- Daemon auto-starts on boot
- Only one daemon process
- Installation scripts work

---

### 7.2 Documentation

**Documents to Create**:
1. **API Documentation** - All daemon endpoints
2. **Architecture Doc** - New consolidated architecture
3. **Migration Guide** - For existing deployments
4. **Client Guide** - How to use SidecarBridge

**Tasks**:
- [ ] Write API docs
- [ ] Update architecture docs
- [ ] Write migration guide
- [ ] Write client guide

**Acceptance Criteria**:
- All endpoints documented
- Architecture diagrams updated
- Migration guide tested

---

## Testing Strategy

### Unit Tests

- Test all new request/response types
- Test each handler method
- Test service initialization
- Test middleware

### Integration Tests

- Test full client → daemon → response flow
- Test all API endpoints
- Test error handling
- Test token validation

### Contract Tests

- Verify SidecarBridge ↔ Daemon API compatibility
- Test request/response schemas
- Test error formats

### End-to-End Tests

- Test Mac App full workflows
- Test CLI commands
- Test MCP operations

---

## Implementation Timeline

| Week | Phase | Deliverables | Risk |
|------|-------|--------------|------|
| 1-2 | Phase 1 | Daemon API Extension | Low |
| 3-4 | Phase 2 | Service Integration | Medium |
| 5 | Phase 3 | WebServer Removal | Low |
| 6-8 | Phase 4 | Client Thinning | Medium |
| 9 | Phase 5 | Auth & Security | Medium |
| 10 | Phase 6 | Observability | Low |
| 11-12 | Phase 7 | Deployment & Docs | Low |

**Total**: 10-12 weeks

---

## Success Criteria (Overall)

### Automated Verification

- [ ] `swift build` succeeds with reduced Mac App dependencies
- [ ] `swift test` passes for all daemon integration tests
- [ ] Contract tests pass for all API endpoints
- [ ] No `import CathedralModule` in Mac App (except Primitives)
- [ ] No `import ModelRegistry` in Mac App
- [ ] `AnigmaWebServer` removed from Package.swift
- [ ] Vapor dependency removed from Package.swift
- [ ] All CLI executables build with thin dependencies

### Manual Verification

- [ ] Mac App functions correctly using daemon APIs
- [ ] All CLI commands work via daemon
- [ ] Model installation works
- [ ] ML operations work
- [ ] Evidence/Cathedral operations work
- [ ] Agent execution works
- [ ] Export operations work
- [ ] OAuth/JWT authentication works
- [ ] Observability metrics collected
- [ ] launchd service starts unified daemon

---

## Risk Mitigation

### Technical Risks

1. **Service initialization failures**
   - Mitigation: Graceful degradation, service health checks
   
2. **Performance regression**
   - Mitigation: Benchmarking, profiling, optimization

3. **Breaking changes to clients**
   - Mitigation: Parallel running, feature flags

### Process Risks

1. **Scope creep**
   - Mitigation: Strict phase boundaries, defer non-critical items

2. **Testing gaps**
   - Mitigation: Contract tests, comprehensive integration tests

---

**Planning Complete**: 2026-01-24
**Ready for Implementation**: ✅
