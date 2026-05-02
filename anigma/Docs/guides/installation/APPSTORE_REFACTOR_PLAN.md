# AppStore Refactor Plan

**Current State**: 3104 lines, 132 methods, 37 MARK sections
**Target State**: 6 focused stores, each <500 lines

---

## Domain Analysis

Based on MARK comments and property analysis, here are the clear domains:

### 1. **MLStore** (ML Worker + Model Registry)
**Lines**: ~300 (lines 596-609 + 677-705 + 2278-2584)
**Properties**:
- `registeredModels: [ModelRegistryEntry]`
- `mlWorkerStatus: MLWorkerStatus?`
- `modelRegistry: ModelRegistry`
- `mlWorkerClient: MLWorkerClient?`

**Methods**:
- Model Registry Operations (lines 2285-2584)
- ML Worker Operations (lines 2278-2584)
- `loadRegisteredModels()`, `registerModel()`, `runInference()`

---

### 2. **PipelineStore** (Workflow Pipelines)
**Lines**: ~200 (lines 651-663 + 2730-2770)
**Properties**:
- `pipelines: [PipelineInfo]`
- `pipelineRuns: [PipelineRun]`
- `pipelineClient: PipelineClient?`
- `pipelineStatus: HarmoniaClient.PipelineStatusResponse?`

**Methods**:
- Pipeline Operations (lines 2730-2770)
- `loadPipelines()`, `createPipeline()`, `runPipeline()`

---

### 3. **SourceConnectionStore** (OAuth + Integrations)
**Lines**: ~350 (lines 65-86 + 2951-3076)
**Properties**:
- `googleOAuthClientId: String`
- `googleOAuthToken: GoogleOAuthToken?`
- `googleOAuthLastRefreshAt: Date?`
- `googleRefreshTask: Task<Void, Never>?`

**Methods**:
- OAuth section (lines 2951-3076)
- `linkGoogleAccount()`, `unlinkGoogle()`, `refreshGoogleToken()`

---

### 4. **WorkspaceStore** (Repository Management)
**Lines**: ~400 (lines 47 + 335-356 + 1343-1522)
**Properties**:
- `repoWorkspaces: [RepoWorkspace]`
- `activeWorkspaceID: UUID?`
- `selectedFileURL: URL?`
- `changeSets: [ChangeSet]`

**Methods**:
- Workspace Management (lines 1343-1522)
- Repository Maintenance (lines 777-1300)
- `openLocalRepository()`, `indexWorkspace()`, `loadWorkspaces()`

---

### 5. **DaemonStore** (Daemon Connection + Services)
**Lines**: ~350 (lines 435-438 + 518-528 + integration sections)
**Properties**:
- `daemonBridge: DaemonBridge?`
- `daemonStatus: String`
- `daemonDetailedStatus: AnigmaStatusResponse?`
- `daemonCapability: DaemonHostCapability?`
- `client: MacAnigmaClient?`

**Methods**:
- Connection management
- Service coordination (Harmonia, Doctrine, AST, etc.)

---

### 6. **ServiceIntegrationStore** (Harmonia, Doctrine, AST, Accessum, Surface, Outline)
**Lines**: ~500 (lines 544-676 + 2136-2810)
**Properties**:
- `vaultStatus`, `pipelineStatus`, `techDebtReport`, `searchResults`
- `doctrineScanResults`, `doctrineStats`, `doctrineRules`
- `astClient`, `surfaceClient`, `accessumClient`, etc.

**Methods**:
- Harmonia CLI Operations (lines 2136-2218)
- Doctrine Operations (lines 2219-2277)
- AST Services Operations (lines 2697-2729)
- Accessum Flow Operations (lines 2601-2648)
- Surface Operations (lines 2649-2696)
- Outline/Zine Operations (lines 2771-2810)

---

### 7. **AppStore** (Orchestrator - Keep Slim)
**Lines**: target <400
**Properties**:
- `role: AnigmaRole`
- `mode: AppMode`
- `sources`, `contexts`, `scopes` (knowledge graph)
- `localJobs`, `workItems`, `tools`
- `activeToasts`, presentation flags
- Chrome/UI state

**Methods**:
- Intake logic (lines 87-266)
- Context operations (lines 267-317)
- Build loop/tools (lines 318-334)
- Toast/error handling
- Mode/surface navigation

**Composed Stores**:
```swift
let mlStore: MLStore
let pipelineStore: PipelineStore
let sourceConnectionStore: SourceConnectionStore
let workspaceStore: WorkspaceStore
let daemonStore: DaemonStore
let serviceStore: ServiceIntegrationStore
```

---

## Refactor Strategy

### Phase 1: Create Store Protocols (Defines Contracts)

```swift
// Sources/AnigmaAppMac/Stores/Protocols/MLStoreProtocol.swift
@MainActor
protocol MLStoreProtocol: AnyObject, Observable {
    var registeredModels: [ModelRegistryEntry] { get set }
    var mlWorkerStatus: MLWorkerStatus? { get set }

    func loadRegisteredModels() async
    func registerModel(_ spec: ModelSpec) async throws
    func runInference(...) async throws -> Receipt
}
```

### Phase 2: Extract Stores One-by-One

**Order** (least risky to most risky):
1. **MLStore** (most self-contained, clear boundaries)
2. **PipelineStore** (also well-isolated)
3. **SourceConnectionStore** (OAuth is standalone)
4. **ServiceIntegrationStore** (collection of integrations)
5. **WorkspaceStore** (has dependencies on Daemon)
6. **DaemonStore** (central coordination, most dependencies)
7. **Slim AppStore** (final composition)

### Phase 3: Update View Dependencies

Update views to access stores:
```swift
// BEFORE:
@Environment(AppStore.self) private var store
let models = store.registeredModels

// AFTER:
@Environment(AppStore.self) private var appStore
let models = appStore.mlStore.registeredModels
```

### Phase 4: Performance Optimization

With focused stores, optimize each:
- MLStore: Cache model queries
- WorkspaceStore: Debounce file system operations
- DaemonStore: Connection pooling

---

## Implementation Plan

### Step 1: Create MLStore ✅ (Start Here)

**File**: `Sources/AnigmaAppMac/Stores/MLStore.swift`

**Extract**:
- Properties: `registeredModels`, `mlWorkerStatus`, `modelRegistry`, `mlWorkerClient`
- Methods: All from "ML Worker Operations" + "Model Registry Operations"

**Dependencies**:
- ContractsCore (ModelSpec, RunSpec)
- MLWorkerCommon
- AppStore (for `showError`, `showToast` - will inject)

**Estimated Time**: 2-3 hours

---

### Step 2: Create PipelineStore

**File**: `Sources/AnigmaAppMac/Stores/PipelineStore.swift`

**Extract**:
- Properties: `pipelines`, `pipelineRuns`, `pipelineClient`, `pipelineStatus`
- Methods: All from "Pipeline Operations"

**Estimated Time**: 1-2 hours

---

### Step 3: Create SourceConnectionStore

**File**: `Sources/AnigmaAppMac/Stores/SourceConnectionStore.swift`

**Extract**:
- Properties: All OAuth-related
- Methods: All from "OAuth" section

**Estimated Time**: 2 hours

---

### Step 4: Create ServiceIntegrationStore

**File**: `Sources/AnigmaAppMac/Stores/ServiceIntegrationStore.swift`

**Extract**:
- Properties: All service clients and results
- Methods: All service operations (Harmonia, Doctrine, AST, Accessum, Surface, Outline)

**Estimated Time**: 3-4 hours (largest store)

---

### Step 5: Create WorkspaceStore

**File**: `Sources/AnigmaAppMac/Stores/WorkspaceStore.swift`

**Extract**:
- Properties: `repoWorkspaces`, workspace IDs, file selection
- Methods: All from "Workspace Management" + "Repository Maintenance"

**Estimated Time**: 3-4 hours (complex dependencies)

---

### Step 6: Create DaemonStore

**File**: `Sources/AnigmaAppMac/Stores/DaemonStore.swift`

**Extract**:
- Properties: `daemonBridge`, connection state
- Methods: Connection management, service coordination

**Estimated Time**: 2-3 hours

---

### Step 7: Slim AppStore

**File**: `Sources/AnigmaAppMac/AppStore.swift` (REWRITE)

**Keep**:
- Navigation state (role, mode, surface)
- Knowledge graph (sources, contexts, scopes)
- UI state (toasts, presentation flags)
- Intake logic (or extract to IntakeStore?)
- Store composition

**Remove**:
- All extracted properties/methods
- Replace with store references

**Estimated Time**: 2-3 hours

---

### Step 8: Update View Dependencies

**Affected Views**: ~40 files

**Pattern**:
```swift
// BEFORE:
Button("Register Model") {
    Task {
        try await store.registerModel(spec)
    }
}

// AFTER:
Button("Register Model") {
    Task {
        try await store.mlStore.registerModel(spec)
    }
}
```

**Automated with Find/Replace**:
- `store.registeredModels` → `store.mlStore.registeredModels`
- `store.runInference` → `store.mlStore.runInference`
- etc.

**Estimated Time**: 3-4 hours (careful testing)

---

## Testing Strategy

### Unit Tests (New)
Each store gets unit tests:
- `MLStoreTests.swift`
- `PipelineStoreTests.swift`
- etc.

### Integration Tests
- Test AppStore → Store communication
- Test cross-store operations (e.g., workspace → daemon)

### Manual Testing
- Full app walkthrough after each store extraction
- Verify no regressions in UI

---

## File Structure (After Refactor)

```
Sources/AnigmaAppMac/
├── AppStore.swift (300-400 lines, orchestrator)
├── AppState.swift (unchanged)
├── Stores/
│   ├── Protocols/
│   │   ├── MLStoreProtocol.swift
│   │   ├── PipelineStoreProtocol.swift
│   │   ├── SourceConnectionStoreProtocol.swift
│   │   ├── WorkspaceStoreProtocol.swift
│   │   ├── DaemonStoreProtocol.swift
│   │   └── ServiceIntegrationStoreProtocol.swift
│   │
│   ├── MLStore.swift (~300 lines)
│   ├── PipelineStore.swift (~200 lines)
│   ├── SourceConnectionStore.swift (~350 lines)
│   ├── ServiceIntegrationStore.swift (~500 lines)
│   ├── WorkspaceStore.swift (~400 lines)
│   └── DaemonStore.swift (~350 lines)
│
└── ... (rest of app)
```

**Total Lines**: ~2400 (down from 3104)
**Average per file**: ~340 lines
**Largest store**: ServiceIntegrationStore at ~500 lines

---

## Benefits

### 1. **Maintainability**
- Each store <500 lines (easy to understand)
- Clear responsibilities (single concern)
- Easy to find code (domain-organized)

### 2. **Testability**
- Unit test each store independently
- Mock store dependencies
- Faster test execution

### 3. **Parallel Development**
- Team members work on different stores
- Fewer merge conflicts
- Clear ownership

### 4. **Performance**
- Optimize each store independently
- Profile hot paths per domain
- Cache strategically

### 5. **Type Safety**
- Protocols define contracts
- Compiler enforces dependencies
- Easier refactoring

---

## Risks & Mitigation

### Risk 1: Breaking Changes
**Mitigation**: Incremental approach, test after each extraction

### Risk 2: Cross-Store Dependencies
**Mitigation**: Use protocols, inject dependencies

### Risk 3: View Update Errors
**Mitigation**: Automated find/replace, careful review

### Risk 4: Performance Regression
**Mitigation**: Profile before/after, optimize hot paths

---

## Timeline

| Phase | Task | Time | Cumulative |
|-------|------|------|------------|
| 1 | Create MLStore | 2-3h | 3h |
| 2 | Create PipelineStore | 1-2h | 5h |
| 3 | Create SourceConnectionStore | 2h | 7h |
| 4 | Create ServiceIntegrationStore | 3-4h | 11h |
| 5 | Create WorkspaceStore | 3-4h | 15h |
| 6 | Create DaemonStore | 2-3h | 18h |
| 7 | Slim AppStore | 2-3h | 21h |
| 8 | Update View Dependencies | 3-4h | 25h |
| 9 | Testing & Fixes | 3-5h | 30h |

**Total**: ~30 hours (~1 week full-time, 2 weeks part-time)

---

## Success Criteria

✅ All stores <500 lines
✅ AppStore <400 lines
✅ No compilation errors
✅ All existing features work
✅ Unit tests for each store
✅ No performance regressions

---

## Next Steps

1. **Start with MLStore** (most isolated)
2. **Test thoroughly** before moving to next
3. **Update views incrementally**
4. **Profile performance** after each extraction
5. **Document patterns** for team

---

**Ready to begin?** Let's start with MLStore! 🚀
