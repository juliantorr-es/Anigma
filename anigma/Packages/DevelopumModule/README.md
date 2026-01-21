# DevelopumModule

Develop mode capability module for Anigma IDE features. Provides Monaco editor integration, artifact-first file operations, fast search via IndexCapsule, and repository session management.

## Overview

DevelopumModule is a capability module that adds develop mode features to the Anigma platform. It enables full code editing capabilities with:

- **Monaco Editor Integration** - Web-based code editor running in WKWebView
- **Artifact-First File Operations** - All saves create immutable artifacts before working tree updates
- **IndexCapsule Search** - Fast file/text search without LSP dependencies
- **Repository Session Management** - Track open files, cursor positions, and editor state
- **Bridge Contracts** - Deterministic JSON communication between Swift and JavaScript

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PlatformRuntime                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                   DevelopumModule (register)                 │    │
│  │  ┌───────────────────────────────────────────────────────┐  │    │
│  │  │           DevelopumDatabaseService                     │  │    │
│  │  │  (Database access actor for Developum tables)          │  │    │
│  │  └───────────────────────────────────────────────────────┘  │    │
│  │                                                              │    │
│  │  ┌────────────────┐  ┌──────────────────────────────────┐   │    │
│  │  │ Developum      │  │ DevelopumEditorSystem            │   │    │
│  │  │ EditorSystem   │──│ (ECS system for editor state)    │   │    │
│  │  └────────────────┘  └──────────────────────────────────┘   │    │
│  │                                                              │    │
│  │  ┌────────────────┐  ┌──────────────────────────────────┐   │    │
│  │  │ Developum      │  │ DevelopumIndexSystem             │   │    │
│  │  │ IndexSystem    │──│ (ECS system for file indexing)   │   │    │
│  │  └────────────────┘  └──────────────────────────────────┘   │    │
│  │                                                              │    │
│  │  ┌───────────────────────────────────────────────────────┐  │    │
│  │  │              Workflow Registry                          │  │    │
│  │  │  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │  │    │
│  │  │  │ OpenFile     │ │ SaveFile     │ │ SearchFiles    │  │  │    │
│  │  │  │ Workflow     │ │ Workflow     │ │ Workflow       │  │  │    │
│  │  │  └──────────────┘ └──────────────┘ └────────────────┘  │  │    │
│  │  │  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │  │    │
│  │  │  │ IndexFile    │ │ CreateSession│ │ CloseSession   │  │  │    │
│  │  │  │ Workflow     │ │ Workflow     │ │ Workflow       │  │  │    │
│  │  │  └──────────────┘ └──────────────┘ └────────────────┘  │  │    │
│  │  └───────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Services Layer                             │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  │    │
│  │  │ Developum      │  │ Developum      │  │ IndexCapsule   │  │    │
│  │  │ ArtifactService│  │ ReceiptService │  │ (Search)       │  │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Bridge Layer                               │    │
│  │  ┌────────────────────────────────────────────────────────┐ │    │
│  │  │           DevelopumBridge Contract                       │ │    │
│  │  │  (JCS-canonicalized JSON messages for replayability)   │ │    │
│  │  └────────────────────────────────────────────────────────┘ │    │
│  │                                                              │    │
│  │  ┌────────────────────────────────────────────────────────┐ │    │
│  │  │           MonacoEditorView (UI Layer)                    │ │    │
│  │  │  (WKWebView wrapper for Monaco editor)                  │ │    │
│  │  └────────────────────────────────────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Concepts

### Monaco is UI-Only

The Monaco editor component (`MonacoEditorView`) is purely a presentation layer. All side effects are handled through the job/receipt systems:

1. User types in Monaco → JavaScript sends `contentChanged` message
2. Swift receives message → Creates `Job` entity
3. Workflow processes job → Updates database
4. Receipt generated → Evidence chain maintained

**Never perform file I/O directly from UI callbacks.**

### Artifact-First File Operations

All file saves follow the artifact-first pattern:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Save File Flow                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. ContentHash      ┌─────────────────────────────────────┐    │
│     ────────────────►│  Compute SHA-256 hash of content    │    │
│                      └─────────────────────────────────────┘    │
│                                 │                                 │
│                                 ▼                                 │
│                      ┌─────────────────────┐                     │
│                      │  Create Artifact     │                     │
│                      │  (Immutable storage) │                     │
│                      └─────────────────────┘                     │
│                                 │                                 │
│                                 ▼                                 │
│                      ┌─────────────────────┐                     │
│                      │  Generate Receipt    │                     │
│                      │  (Evidence chain)    │                     │
│                      └─────────────────────┘                     │
│                                 │                                 │
│                                 ▼                                 │
│                      ┌─────────────────────┐                     │
│                      │  Mirror to Working   │                     │
│                      │  Tree (Optional)     │                     │
│                      └─────────────────────┘                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

This ensures:
- All changes are cryptographically hash-linked
- Full replay capability from artifacts
- Working tree can be reconstructed from evidence

### JCS Canonicalization

Bridge messages use JSON Canonicalization Scheme (JCS) for deterministic hashing:

```swift
extension DevelopumBridgeMessage {
    public func toCanonicalJSON() throws -> Data {
        // Uses sorted keys and no whitespace for reproducibility
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
```

This enables:
- Deterministic evidence hashing
- Replay verification
- Audit trail integrity

### IndexCapsule - Fast Search

`IndexCapsule` provides fast file/text search without LSP dependencies:

- **Index artifacts** store line-by-line content in compressed JSON
- **Searches** query these artifacts for fast results
- **Caching** improves repeat search performance
- **No semantic analysis** - honest scoping (LSP handles that)

## Module Registration

Register DevelopumModule with your `PlatformRuntime`:

```swift
import DevelopumModule
import PlatformCore

func registerModules(runtime: PlatformRuntime) async throws {
    try await HarmoniaModule.register(runtime: runtime)
    try await DevelopumModule.register(runtime: runtime)
}
```

The `register(runtime:)` function:
1. Opens the legacy database actor
2. Runs migrations for Developum tables
3. Registers `DevelopumEditorSystem` and `DevelopumIndexSystem`
4. Registers all workflows with the registry

## Usage Examples

### Opening Files

```swift
import AnigmaCore

// Create a job to open a file
let openFileJob = Job.openFile(
    repoId: repoSessionId.uuidString,
    filePath: "Sources/AppDelegate.swift",
    languageId: "swift"
)

// Submit to the job system
let world = runtime.getWorld()
let jobEntity = await world.createEntity()
await world.addComponent(jobEntity, openFileJob)
await world.addComponent(jobEntity, repoSessionComponent)
```

### Saving Files

```swift
// Create a save job (artifact-first)
let saveJob = Job.saveFile(
    repoId: repoSessionId.uuidString,
    filePath: "Sources/AppDelegate.swift",
    content: newContent,
    createArtifact: true,      // Always create artifact first
    mirrorToWorkingTree: true  // Then optionally mirror
)

// Submit the job
let jobEntity = await world.createEntity()
await world.addComponent(jobEntity, saveJob)
await world.addComponent(jobEntity, repoSessionComponent)

// Receipt will be generated automatically
let receipt = await receiptService.generateSaveReceipt(
    repoId: repoSessionId,
    filePath: "Sources/AppDelegate.swift",
    contentHash: artifactHash,
    artifactHash: artifactHash,
    mirrorSuccess: true
)
```

### Searching Files

```swift
import DevelopumModule

// Configure search options
let options = SearchOptions(
    isRegex: false,
    matchCase: false,
    matchWholeWord: true,
    maxResults: 100,
    filePattern: "**/*.swift"
)

// Search using IndexCapsule
let results = try await indexCapsule.searchFiles(
    repoId: repoSessionId,
    query: "func viewDidLoad",
    options: options
)

// Process results
for result in results {
    print("\(result.fileUri):\(result.line): \(result.match)")
}
```

### Managing Repository Sessions

```swift
// Create a repository session
let createSessionJob = Job.createRepoSession(
    repoPath: "/path/to/repository",
    remoteUrl: "https://github.com/user/repo.git",
    workspaceConfig: jsonConfig
)

// Close a repository session
let closeSessionJob = Job.closeRepoSession(
    repoId: repoSessionId.uuidString,
    saveUnsavedChanges: true
)

// Generate session receipts
let createReceipt = await receiptService.generateCreateSessionReceipt(
    repoId: repoSessionId,
    repoPath: "/path/to/repository"
)

let closeReceipt = await receiptService.generateCloseSessionReceipt(
    repoId: repoSessionId,
    savedFiles: 5,
    unsavedFiles: 1
)
```

## API Reference

### Main Module

```swift
public enum DevelopumModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws
    
    public static func createArtifactService(
        with runtime: PlatformRuntime,
        databaseService: DevelopumDatabaseService,
        telemetry: TelemetryClient? = nil
    ) -> DevelopumArtifactService
    
    public static func createReceiptService(
        databaseService: DevelopumDatabaseService,
        telemetry: TelemetryClient? = nil
    ) -> DevelopumReceiptService
}
```

### Models

```swift
/// Repository session record
public struct RepoRecord: Codable, Sendable, TableRecord {
    public var id: UUID
    public var repoPath: String
    public var remoteUrl: String?
    public var currentBranch: String
    public var headSha: String
    public var createdAt: Date
    public var lastActivityAt: Date
    public var isActive: Bool
    public var workspaceConfig: String?
    public var metadata: String?
}

/// Workspace state for open files
public struct WorkspaceState: Codable, Sendable, TableRecord {
    public var id: UUID
    public var repoId: UUID
    public var filePath: String
    public var cursorLine: Int
    public var cursorColumn: Int
    public var selectionStartLine: Int?
    public var selectionEndLine: Int?
    public var viewportTopLine: Int?
    public var viewportBottomLine: Int?
    public var isOpen: Bool
    public var hasUnsavedChanges: Bool
}

/// Index artifact for fast search
public struct IndexArtifactRecord: Codable, Sendable, TableRecord {
    public var id: UUID
    public var repoId: UUID
    public var artifactHash: String
    public var filePath: String
    public var mimeType: String
    public var languageId: String?
    public var fileSize: Int64
    public var indexedAt: Date
    public var indexContent: Data
    public var isCurrent: Bool
}
```

### Services

```swift
/// Database service for Developum operations
public actor DevelopumDatabaseService {
    public func createRepoRecord(_ record: RepoRecord) async throws
    public func getRepoRecord(id: UUID) async throws -> RepoRecord?
    public func saveWorkspaceState(_ state: WorkspaceState) async throws
    public func saveIndexArtifact(_ artifact: IndexArtifactRecord) async throws
    public func recordBridgeEvent(...) async throws
}

/// Artifact service for immutable file storage
public actor DevelopumArtifactService {
    @discardableResult
    public func storeFile(
        repoId: UUID,
        filePath: String,
        content: String,
        mimeType: String? = nil
    ) async throws -> (hash: String, artifactId: ArtifactID)
    
    public func retrieveFile(hash: String) async throws -> String
    public func mirrorToWorkingTree(...) async throws
}

/// Receipt service for evidence generation
public actor DevelopumReceiptService {
    public func generateSaveReceipt(...) async throws -> ReceiptWire
    public func generateOpenReceipt(...) async throws -> ReceiptWire
    public func generateSearchReceipt(...) async throws -> ReceiptWire
}

/// Fast search actor
public actor IndexCapsule {
    public func searchFiles(
        repoId: UUID,
        query: String,
        options: SearchOptions = .default
    ) async throws -> [SearchResult]
    
    public func buildSearchIndex(...) async throws
}
```

### Bridge Contract

```swift
/// Bridge message types
public enum DevelopumMessageType: String, Codable, Sendable {
    case fileOpened, fileClosed, cursorMoved, selectionChanged
    case viewportChanged, contentChanged, saveRequest, searchRequest
    case openFile, closeFile, updateContent, showMessage
    // ... more types
}

/// Base bridge message
public struct DevelopumBridgeMessage: Codable, Sendable {
    public let version: DevelopumBridgeVersion
    public let type: DevelopumMessageType
    public let messageId: String
    public let sessionId: String
    public let repoId: String?
    public let timestampMs: Int64
    public let payload: DevelopumPayload
}

/// Search result structure
public struct SearchResult: Codable, Sendable {
    public let fileUri: String
    public let line: Int
    public let column: Int
    public let match: String
    public let lineText: String
}
```

## Integration with PlatformRuntime

DevelopumModule integrates with the broader Anigma platform:

### Dependencies

```swift
// From root Package.swift
.target(
    name: "DevelopumModule",
    dependencies: [
        "AnigmaCore",
        "DatabaseCore",
        "ContractsCore",
        "TelemetryCore",
        "ExecutionCore",
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "BLAKE3", package: "blake3-swift")
    ],
    path: "Packages/DevelopumModule"
)
```

### Database Schema

DevelopumModule creates three tables:
- `developum_repos` - Repository session records
- `developum_workspace_states` - Open file states
- `developum_index_artifacts` - Search index entries
- `developum_bridge_events` - Bridge message audit trail

### Workflow Integration

All file operations flow through the workflow system:

```swift
// Workflow names for reference
OpenFileWorkflow.name        // "Open File"
SaveFileWorkflow.name        // "Save File"
SearchFilesWorkflow.name     // "Search Files"
IndexFileWorkflow.name       // "Index File"
CreateRepoSessionWorkflow.name   // "Create Repository Session"
CloseRepoSessionWorkflow.name    // "Close Repository Session"
```

## Troubleshooting

### Monaco Editor Not Loading

**Symptom**: Editor appears blank or shows "Loading..."

**Solution**:
1. Check Monaco HTML resource is included in bundle
2. Verify WKWebView configuration allows local file access
3. Check console for JavaScript errors

```swift
// Ensure resources are copied
// In Package.swift target for AnigmaHostMac:
resources: [.copy("Resources/Monaco")]
```

### File Save Failures

**Symptom**: Save operations fail with artifact errors

**Solution**:
1. Verify `artifactAuthority` is configured in runtime
2. Check database is open and migrations ran
3. Review receipt generation for hashing errors

```swift
// Verify database service is available
try await databaseActor.open()
try await DevelopumMigration.migrate(databaseActor)
```

### Search Returns No Results

**Symptom**: IndexCapsule searches return empty results

**Solution**:
1. Ensure files have been indexed (`IndexFileWorkflow`)
2. Check search options (file pattern, max results)
3. Verify index artifacts exist in database

```swift
// Build index for files
try await indexCapsule.buildSearchIndex(
    repoId: repoSessionId,
    filePaths: ["Sources/**/*.swift"]
)
```

### Bridge Message Failures

**Symptom**: Messages from Monaco not being processed

**Solution**:
1. Verify `WKUserContentController` is configured
2. Check message handler is registered
3. Review JCS canonicalization for encoding issues

```swift
// Message handler registration
let userContentController = WKUserContentController()
userContentController.add(context.coordinator, name: "developumBridge")
```

### Performance Issues

**Symptom**: Slow indexing or search operations

**Solution**:
1. IndexCapsule caches searches (5 minute TTL)
2. Limit concurrent indexing jobs (`maxConcurrentJobs = 3`)
3. Use file pattern filtering to reduce scope

```swift
// Configure search with limits
let options = SearchOptions(
    maxResults: 100,
    filePattern: "**/*.swift",
    maxFileSizeBytes: 1_000_000
)
```

### Database Migration Failures

**Symptom**: Module registration fails with database errors

**Solution**:
1. Ensure `DevelopumMigration.migrate()` is called
2. Verify database actor is properly initialized
3. Check for conflicting table names

```swift
// In register(runtime:)
let databaseActor = try await runtime.legacyDatabaseActor()
try await databaseActor.open()
try await DevelopumMigration.migrate(databaseActor)
```

## Version

- **Module Version**: 0.1.0
- **Bridge Protocol**: 1.0
- **Minimum Swift**: 5.9

## License

Part of the Anigma platform. See root LICENSE file.
