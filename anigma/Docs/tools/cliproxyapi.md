# CLIProxyAPI Architecture Report

> A comprehensive analysis of the CLIProxyAPI codebase with Swift implementation guidance.

## Executive Summary

**CLIProxyAPI** is a Go-based proxy server that provides unified OpenAI/Gemini/Claude/Codex-compatible API interfaces for CLI-based AI tools. It enables multi-account OAuth authentication, load balancing, request/response translation between different AI provider formats, and hot-reloading of configuration and credentials.

---

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Core Components](#core-components)
3. [Data Flow](#data-flow)
4. [Key Design Patterns](#key-design-patterns)
5. [Swift Implementation Guide](#swift-implementation-guide)
6. [Module-by-Module Mapping](#module-by-module-mapping)

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              CLI Clients                                 │
│         (Claude Code, Cursor, Cline, RooCode, Amp CLI, etc.)            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            HTTP/WebSocket API                            │
│                     (Gin Framework - OpenAI Compatible)                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │   /v1/chat  │  │  /v1/models │  │ /management │  │   /v1/ws        │ │
│  │ completions │  │             │  │     API     │  │  (WebSocket)    │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Request Processing Layer                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │
│  │  Access Manager  │  │ Translator       │  │  Payload Rules       │   │
│  │  (API Key Auth)  │  │ Registry         │  │  (Default/Override)  │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Auth Conductor (Core Runtime)                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │
│  │    Selector      │  │    Executors     │  │   Refresh Manager    │   │
│  │  (Load Balance)  │  │   (Per Provider) │  │   (Token Lifecycle)  │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Provider Executors                              │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────┐ │
│  │ Gemini  │ │ Claude  │ │  Codex  │ │Antigrav │ │  Qwen   │ │ iFlow │ │
│  │Executor │ │Executor │ │Executor │ │Executor │ │Executor │ │Exec.  │ │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘ └───────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Upstream AI Providers                           │
│    Google AI Studio | Anthropic | OpenAI | Vertex AI | Qwen | iFlow     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Entry Point (`cmd/server/main.go`)

**Purpose**: Application bootstrap, CLI parsing, store initialization, service startup.

**Key Responsibilities**:
- Parse CLI flags (`-login`, `-codex-login`, `-claude-login`, etc.)
- Load configuration from YAML or environment
- Initialize token stores (File, Git, Postgres, S3/MinIO)
- Register access providers and start the service

**Go Structure**:
```go
func main() {
    // 1. Parse flags
    // 2. Load .env
    // 3. Initialize token store (Postgres/Git/Object/File)
    // 4. Load config
    // 5. Register access providers
    // 6. Start service or handle login flow
}
```

---

### 2. Configuration System (`internal/config/`)

**Purpose**: YAML-based configuration with hot-reload support.

**Key Types**:
```go
type Config struct {
    Host                    string
    Port                    int
    TLS                     TLSConfig
    RemoteManagement        RemoteManagement
    AuthDir                 string
    APIKeys                 []string
    GeminiAPIKey            []GeminiKey
    ClaudeAPIKey            []ClaudeKey
    CodexAPIKey             []CodexKey
    OpenAICompatibility     []OpenAICompatEntry
    RoutingConfig           RoutingConfig
    PayloadConfig           PayloadConfig
    OAuthModelMappings      map[string][]ModelNameMapping
    // ... many more
}
```

**Features**:
- Legacy migration support
- Per-provider API key configurations
- Model aliasing and exclusion
- Payload default/override rules

---

### 3. API Server (`internal/api/server.go`)

**Purpose**: HTTP server with Gin framework, route registration, middleware.

**Key Components**:
- **Server struct**: Wraps Gin engine, HTTP server, handlers, config
- **Route groups**: `/v1/` (OpenAI compat), `/v0/management/`, `/api/provider/`
- **Middleware**: CORS, authentication, request logging
- **WebSocket support**: Real-time streaming via `/v1/ws`

**Route Examples**:
```go
// Chat completions (OpenAI format)
POST /v1/chat/completions

// Gemini native format
POST /v1beta/models/:model:generateContent

// Claude native format  
POST /v1/messages

// Model listing
GET /v1/models
```

---

### 4. Translator System (`sdk/translator/` + `internal/translator/`)

**Purpose**: Transform requests/responses between provider formats (OpenAI ↔ Gemini ↔ Claude ↔ Codex).

**Core Types**:
```go
type RequestTransform func(model string, rawJSON []byte, stream bool) []byte

type ResponseStreamTransform func(
    ctx context.Context, 
    model string, 
    originalRequestRawJSON, requestRawJSON, rawJSON []byte, 
    param *any,
) []string

type ResponseNonStreamTransform func(
    ctx context.Context,
    model string,
    originalRequestRawJSON, requestRawJSON, rawJSON []byte,
    param *any,
) string
```

**Registry Pattern**:
```go
type Registry struct {
    requests  map[Format]map[Format]RequestTransform
    responses map[Format]map[Format]ResponseTransform
}

// Usage
translator.Register(FormatOpenAI, FormatGemini, reqTransform, respTransform)
```

**Supported Format Combinations**:
- OpenAI → Gemini, Claude, Codex, GeminiCLI
- Gemini → OpenAI, Claude, GeminiCLI
- Claude → OpenAI, Gemini, GeminiCLI
- Codex → OpenAI, Gemini, Claude, GeminiCLI
- Antigravity → OpenAI, Gemini, Claude

---

### 5. Auth System (`sdk/cliproxy/auth/`)

**Purpose**: Credential lifecycle management, OAuth token refresh, quota tracking.

**Core Types**:

```go
type Auth struct {
    ID              string
    Provider        string              // "gemini", "claude", "codex", etc.
    Prefix          string              // Namespace for routing
    Status          Status
    Disabled        bool
    Unavailable     bool
    ProxyURL        string
    Attributes      map[string]string   // Immutable config (api_key, base_url)
    Metadata        map[string]any      // Mutable runtime state (tokens, cookies)
    Quota           QuotaState
    ModelStates     map[string]*ModelState
    CreatedAt       time.Time
    UpdatedAt       time.Time
    LastRefreshedAt time.Time
    NextRefreshAfter time.Time
}

type QuotaState struct {
    Exceeded      bool
    Reason        string
    NextRecoverAt time.Time
    BackoffLevel  int
}
```

**Conductor (Manager)**:
- Registers/unregisters auth entries
- Selects credentials via `Selector` interface
- Executes requests via `ProviderExecutor` interface
- Tracks execution results and updates quota state
- Runs background refresh loop

---

### 6. Executor System (`internal/runtime/executor/`)

**Purpose**: Provider-specific HTTP client logic for AI API calls.

**Interface**:
```go
type ProviderExecutor interface {
    Identifier() string
    Execute(ctx, auth, req, opts) (Response, error)
    ExecuteStream(ctx, auth, req, opts) (<-chan StreamChunk, error)
    CountTokens(ctx, auth, req, opts) (Response, error)
    Refresh(ctx, auth) (*Auth, error)
    HttpRequest(ctx, auth, req) (*http.Response, error)
}
```

**Implementations**:
| Executor | Provider | Auth Type |
|----------|----------|-----------|
| `GeminiExecutor` | Google AI Studio | API Key / OAuth |
| `GeminiCLIExecutor` | Gemini CLI | OAuth |
| `ClaudeExecutor` | Anthropic | API Key / OAuth |
| `CodexExecutor` | OpenAI Codex | OAuth |
| `AntigravityExecutor` | Antigravity | OAuth |
| `QwenExecutor` | Alibaba Qwen | OAuth |
| `IFlowExecutor` | iFlow | OAuth / Cookie |
| `VertexExecutor` | Google Vertex AI | Service Account |
| `OpenAICompatExecutor` | Generic OpenAI-compat | API Key |

---

### 7. Model Registry (`internal/registry/`)

**Purpose**: Dynamic model availability tracking with reference counting.

**Features**:
- Register models per client/provider
- Track quota-exceeded state per model
- Auto-hide models when no clients available
- Hook system for external integrations

```go
type ModelRegistry struct {
    models           map[string]*ModelRegistration
    clientModels     map[string][]string
    clientModelInfos map[string]map[string]*ModelInfo
}

type ModelInfo struct {
    ID                  string
    ContextLength       int
    MaxCompletionTokens int
    Thinking            *ThinkingSupport
    // ...
}
```

---

### 8. Watcher System (`internal/watcher/`)

**Purpose**: File system watching for hot-reload of config and auth files.

**Components**:
- **Watcher**: fsnotify-based file watcher
- **Dispatcher**: Debounced event handling
- **Synthesizer**: Diff computation for auth changes

**Event Types**:
```go
type AuthUpdate struct {
    Action AuthUpdateAction  // add, modify, delete
    ID     string
    Auth   *Auth
}
```

---

### 9. Token Stores (`internal/store/`)

**Purpose**: Persistent storage backends for credentials.

| Store | Backend | Use Case |
|-------|---------|----------|
| `FileTokenStore` | Local filesystem | Single-machine deployment |
| `GitTokenStore` | Git repository | Team sync, version control |
| `PostgresStore` | PostgreSQL | Cloud deployment, HA |
| `ObjectTokenStore` | S3/MinIO | Cloud deployment |

---

### 10. Access System (`sdk/access/`)

**Purpose**: API key validation for incoming requests.

```go
type Provider interface {
    Validate(ctx context.Context, key string) bool
}

type Manager struct {
    providers []Provider
}
```

---

## Data Flow

### Request Flow

```
1. HTTP Request arrives
   └─▶ Gin Router matches route
       └─▶ Middleware: CORS, Auth (Access Manager)
           └─▶ Handler extracts model, payload
               └─▶ Translator: Convert to provider format
                   └─▶ Auth Conductor: Select credential
                       └─▶ Selector: Pick best auth (round-robin/fill-first)
                           └─▶ Executor: Make upstream request
                               └─▶ Translator: Convert response back
                                   └─▶ Return to client
```

### Streaming Flow

```
Handler → Executor.ExecuteStream() → <-chan StreamChunk
    └─▶ For each chunk:
        └─▶ Translator.TranslateStream()
            └─▶ Write SSE to client
```

---

## Key Design Patterns

### 1. Registry Pattern
Used for translators, executors, and models. Allows dynamic registration via init().

### 2. Strategy Pattern
- `Selector` interface for credential selection algorithms
- `ProviderExecutor` interface for provider-specific logic

### 3. Observer/Hook Pattern
- `ModelRegistryHook` for model changes
- `auth.Hook` for auth lifecycle events

### 4. Builder Pattern
- `Service` builder for configuring the proxy service

### 5. Hot-Reload Pattern
- File watcher → debounced callback → atomic config swap

---

## Swift Implementation Guide

### Recommended Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Swift Package Structure                   │
├─────────────────────────────────────────────────────────────────┤
│  CLIProxyCore/                                                   │
│  ├── Sources/                                                    │
│  │   ├── CLIProxyCore/           # Core types, protocols        │
│  │   ├── CLIProxyConfig/         # Configuration system         │
│  │   ├── CLIProxyTranslator/     # Format translation           │
│  │   ├── CLIProxyAuth/           # Auth management              │
│  │   ├── CLIProxyExecutor/       # Provider executors           │
│  │   ├── CLIProxyServer/         # HTTP/WebSocket server        │
│  │   └── CLIProxyWatcher/        # File watching                │
│  └── Tests/                                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Go Component | Swift Equivalent |
|--------------|------------------|
| Gin (HTTP) | Vapor or Hummingbird |
| fsnotify | DispatchSource / FSEvents |
| gorilla/websocket | WebSocketKit (Vapor) |
| sync.RWMutex | os.OSAllocatedUnfairLock / actor |
| context.Context | Task + TaskLocal |
| channels | AsyncStream / AsyncChannel |

---

## Module-by-Module Mapping

### 1. Configuration (`CLIProxyConfig`)

```swift
// Config.swift
public struct Config: Codable, Sendable {
    public var host: String = ""
    public var port: Int = 8317
    public var tls: TLSConfig?
    public var remoteManagement: RemoteManagement?
    public var authDir: String = "~/.cli-proxy-api"
    public var apiKeys: [String] = []
    public var geminiAPIKeys: [GeminiKey] = []
    public var claudeAPIKeys: [ClaudeKey] = []
    public var routing: RoutingConfig?
    // ...
}

public struct GeminiKey: Codable, Sendable {
    public var apiKey: String
    public var prefix: String?
    public var baseURL: String?
    public var headers: [String: String]?
    public var proxyURL: String?
    public var models: [ModelMapping]?
    public var excludedModels: [String]?
}

// ConfigLoader.swift
public actor ConfigLoader {
    private var currentConfig: Config?
    private var configPath: URL
    
    public func load() async throws -> Config {
        let data = try Data(contentsOf: configPath)
        let decoder = YAMLDecoder()
        return try decoder.decode(Config.self, from: data)
    }
    
    public func watch() -> AsyncStream<Config> {
        // Use DispatchSource for file watching
    }
}
```

### 2. Translator (`CLIProxyTranslator`)

```swift
// TranslatorTypes.swift
public enum Format: String, Sendable, Hashable {
    case openai = "openai"
    case gemini = "gemini"
    case claude = "claude"
    case codex = "codex"
    case geminiCLI = "gemini-cli"
}

public typealias RequestTransform = @Sendable (
    _ model: String,
    _ rawJSON: Data,
    _ stream: Bool
) -> Data

public typealias ResponseStreamTransform = @Sendable (
    _ context: TranslationContext,
    _ chunk: Data
) -> [String]

// TranslatorRegistry.swift
public actor TranslatorRegistry {
    private var requests: [Format: [Format: RequestTransform]] = [:]
    private var responses: [Format: [Format: ResponseTransform]] = [:]
    
    public func register(
        from: Format,
        to: Format,
        request: RequestTransform?,
        response: ResponseTransform
    ) {
        if requests[from] == nil { requests[from] = [:] }
        if let request { requests[from]![to] = request }
        if responses[from] == nil { responses[from] = [:] }
        responses[from]![to] = response
    }
    
    public func translateRequest(
        from: Format,
        to: Format,
        model: String,
        rawJSON: Data,
        stream: Bool
    ) -> Data {
        guard let transform = requests[from]?[to] else { return rawJSON }
        return transform(model, rawJSON, stream)
    }
}
```

### 3. Auth System (`CLIProxyAuth`)

```swift
// Auth.swift
public struct Auth: Codable, Sendable, Identifiable {
    public let id: String
    public var provider: String
    public var prefix: String?
    public var status: AuthStatus
    public var disabled: Bool
    public var unavailable: Bool
    public var proxyURL: String?
    public var attributes: [String: String]
    public var metadata: [String: AnyCodable]
    public var quota: QuotaState
    public var modelStates: [String: ModelState]
    public var createdAt: Date
    public var updatedAt: Date
    public var lastRefreshedAt: Date?
    public var nextRefreshAfter: Date?
}

public struct QuotaState: Codable, Sendable {
    public var exceeded: Bool = false
    public var reason: String?
    public var nextRecoverAt: Date?
    public var backoffLevel: Int = 0
}

// AuthConductor.swift
public actor AuthConductor {
    private var auths: [String: Auth] = [:]
    private var executors: [String: any ProviderExecutor] = [:]
    private var selector: AuthSelector
    
    public func register(_ auth: Auth) {
        auths[auth.id] = auth
    }
    
    public func execute(
        provider: String,
        model: String,
        request: ExecutorRequest,
        options: ExecutorOptions
    ) async throws -> ExecutorResponse {
        let candidates = auths.values.filter { 
            $0.provider == provider && !$0.disabled && !$0.unavailable 
        }
        guard let auth = try await selector.pick(
            provider: provider, 
            model: model, 
            candidates: Array(candidates)
        ) else {
            throw AuthError.noAvailableCredentials
        }
        
        guard let executor = executors[provider] else {
            throw AuthError.unknownProvider(provider)
        }
        
        return try await executor.execute(auth: auth, request: request, options: options)
    }
}
```

### 4. Executor System (`CLIProxyExecutor`)

```swift
// ExecutorTypes.swift
public struct ExecutorRequest: Sendable {
    public var model: String
    public var payload: Data
    public var format: Format
    public var metadata: [String: AnyCodable]?
}

public struct ExecutorOptions: Sendable {
    public var stream: Bool = false
    public var alt: String?
    public var headers: HTTPHeaders?
    public var sourceFormat: Format?
    public var originalRequest: Data?
}

public struct ExecutorResponse: Sendable {
    public var payload: Data
    public var metadata: [String: AnyCodable]?
}

// ProviderExecutor.swift
public protocol ProviderExecutor: Sendable {
    var identifier: String { get }
    
    func execute(
        auth: Auth,
        request: ExecutorRequest,
        options: ExecutorOptions
    ) async throws -> ExecutorResponse
    
    func executeStream(
        auth: Auth,
        request: ExecutorRequest,
        options: ExecutorOptions
    ) -> AsyncThrowingStream<Data, Error>
    
    func refresh(auth: Auth) async throws -> Auth
    
    func countTokens(
        auth: Auth,
        request: ExecutorRequest,
        options: ExecutorOptions
    ) async throws -> ExecutorResponse
}

// GeminiExecutor.swift
public actor GeminiExecutor: ProviderExecutor {
    public let identifier = "gemini"
    private let httpClient: HTTPClient
    private let config: Config
    
    public func execute(
        auth: Auth,
        request: ExecutorRequest,
        options: ExecutorOptions
    ) async throws -> ExecutorResponse {
        let baseURL = auth.attributes["base_url"] ?? "https://generativelanguage.googleapis.com"
        let apiKey = auth.attributes["api_key"]
        
        var urlRequest = HTTPClientRequest(url: "\(baseURL)/v1beta/models/\(request.model):generateContent")
        urlRequest.method = .POST
        urlRequest.headers.add(name: "Content-Type", value: "application/json")
        
        if let apiKey {
            urlRequest.headers.add(name: "x-goog-api-key", value: apiKey)
        }
        
        urlRequest.body = .bytes(ByteBuffer(data: request.payload))
        
        let response = try await httpClient.execute(urlRequest, timeout: .seconds(60))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)
        
        return ExecutorResponse(payload: Data(buffer: body))
    }
}
```

### 5. HTTP Server (`CLIProxyServer`)

```swift
// Using Vapor
import Vapor

// Routes.swift
func routes(_ app: Application, conductor: AuthConductor, registry: TranslatorRegistry) throws {
    // OpenAI-compatible endpoints
    app.post("v1", "chat", "completions") { req async throws -> Response in
        let payload = try req.content.decode(ChatCompletionRequest.self)
        // ... handle request
    }
    
    app.get("v1", "models") { req async throws -> ModelsResponse in
        // Return available models
    }
    
    // Gemini-native endpoint
    app.post("v1beta", "models", ":model") { req async throws -> Response in
        let model = req.parameters.get("model")!
        // ... handle Gemini format
    }
    
    // Management API
    let management = app.grouped("v0", "management")
    management.get("accounts") { req async throws -> [AccountInfo] in
        // List accounts
    }
}

// App.swift
@main
struct CLIProxyApp {
    static func main() async throws {
        let app = Application()
        defer { app.shutdown() }
        
        let config = try await ConfigLoader(path: configPath).load()
        let conductor = AuthConductor(selector: RoundRobinSelector())
        let registry = TranslatorRegistry()
        
        // Register translators
        await registerBuiltinTranslators(registry)
        
        // Setup routes
        try routes(app, conductor: conductor, registry: registry)
        
        try app.run()
    }
}
```

### 6. File Watcher (`CLIProxyWatcher`)

```swift
// FileWatcher.swift
public actor FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let path: URL
    private let queue: DispatchQueue
    
    public init(path: URL) {
        self.path = path
        self.queue = DispatchQueue(label: "com.cliproxy.watcher")
    }
    
    public func watch() -> AsyncStream<FileEvent> {
        AsyncStream { continuation in
            fileDescriptor = open(path.path, O_EVTONLY)
            guard fileDescriptor != -1 else {
                continuation.finish()
                return
            }
            
            source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .delete, .rename],
                queue: queue
            )
            
            source?.setEventHandler { [weak self] in
                guard let self else { return }
                let event = FileEvent(mask: self.source?.data ?? [])
                continuation.yield(event)
            }
            
            source?.setCancelHandler { [weak self] in
                if let fd = self?.fileDescriptor, fd != -1 {
                    close(fd)
                }
            }
            
            continuation.onTermination = { [weak self] _ in
                self?.source?.cancel()
            }
            
            source?.resume()
        }
    }
}

public struct FileEvent: Sendable {
    public let mask: DispatchSource.FileSystemEvent
    public var isWrite: Bool { mask.contains(.write) }
    public var isDelete: Bool { mask.contains(.delete) }
    public var isRename: Bool { mask.contains(.rename) }
}
```

### 7. Model Registry (`CLIProxyCore`)

```swift
// ModelRegistry.swift
public actor ModelRegistry {
    public struct ModelInfo: Codable, Sendable, Identifiable {
        public let id: String
        public var object: String = "model"
        public var created: Int64
        public var ownedBy: String
        public var contextLength: Int?
        public var maxCompletionTokens: Int?
        public var thinking: ThinkingSupport?
    }
    
    private var models: [String: ModelRegistration] = [:]
    private var clientModels: [String: [String]] = [:]
    
    public func registerClient(
        clientID: String,
        provider: String,
        models: [ModelInfo]
    ) {
        clientModels[clientID] = models.map(\.id)
        for model in models {
            if var registration = self.models[model.id] {
                registration.count += 1
                registration.providers[provider, default: 0] += 1
                self.models[model.id] = registration
            } else {
                self.models[model.id] = ModelRegistration(
                    info: model,
                    count: 1,
                    providers: [provider: 1]
                )
            }
        }
    }
    
    public func availableModels(filtered: Bool = true) -> [ModelInfo] {
        models.values
            .filter { !filtered || $0.count > 0 }
            .map(\.info)
            .sorted { $0.id < $1.id }
    }
}
```

---

## Key Differences: Go vs Swift

| Aspect | Go Approach | Swift Approach |
|--------|-------------|----------------|
| Concurrency | goroutines + channels | async/await + actors |
| Mutability | sync.RWMutex | actor isolation |
| Error Handling | Multiple returns | throws/Result |
| Interfaces | Duck typing | Protocols with explicit conformance |
| Generics | Type parameters | Associated types + where clauses |
| HTTP Server | Gin framework | Vapor/Hummingbird |
| JSON | encoding/json + gjson/sjson | Codable + SwiftyJSON (optional) |
| Streaming | channels | AsyncStream/AsyncSequence |

---

## Implementation Priority

1. **Phase 1: Core Foundation**
   - [ ] Config system with YAML parsing
   - [ ] Auth types and basic conductor
   - [ ] Single executor (Gemini or Claude)

2. **Phase 2: API Server**
   - [ ] HTTP server with Vapor/Hummingbird
   - [ ] OpenAI-compatible `/v1/chat/completions`
   - [ ] Model listing endpoint

3. **Phase 3: Translator System**
   - [ ] Registry pattern
   - [ ] OpenAI ↔ Gemini translation
   - [ ] Streaming support

4. **Phase 4: Multi-Provider**
   - [ ] All executor implementations
   - [ ] OAuth flows for each provider
   - [ ] Credential selection strategies

5. **Phase 5: Advanced Features**
   - [ ] File watcher + hot reload
   - [ ] WebSocket support
   - [ ] Management API
   - [ ] Token stores (File, Git, Postgres)

---

## Summary

CLIProxyAPI is a well-architected Go application following clean separation of concerns:

- **Config**: YAML-driven with migration support
- **API**: Gin-based HTTP/WebSocket server
- **Translation**: Registry-based format conversion
- **Auth**: Conductor pattern with pluggable selectors and executors
- **Storage**: Multiple backend support (File, Git, Postgres, S3)
- **Watching**: fsnotify-based hot reload

A Swift implementation should leverage:
- **Actors** for thread-safe state management
- **Async/await** for clean async code
- **AsyncStream** for streaming responses
- **Vapor/Hummingbird** for HTTP server
- **DispatchSource** for file watching
- **Codable** for serialization

The modular design allows incremental implementation, starting with core functionality and expanding to full feature parity.
