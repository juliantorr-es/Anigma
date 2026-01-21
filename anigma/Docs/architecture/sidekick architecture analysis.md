# Sidekick Architecture Analysis

## Executive Summary

**Sidekick** is a **local-first macOS AI assistant** built in Swift using SwiftUI. It provides a comprehensive AI chat experience with **RAG (Retrieval Augmented Generation)**, **function calling/agents**, **deep research**, and **system-wide accessibility features**. The application is designed around two core principles:

1. **Local-First Privacy**: All inference can run entirely on-device via `llama.cpp`, with optional OpenAI-compatible API support
2. **Deep macOS Integration**: Leverages Accessibility APIs, native frameworks, and Apple Intelligence capabilities

---

## Project Structure Overview

```
Sidekick/
├── Sidekick/                    # Main application source
│   ├── Logic/                   # Core business logic
│   │   ├── Inference/           # LLM inference engine
│   │   ├── Utilities/           # GraphRAG, tools, services
│   │   ├── Settings/            # App configuration
│   │   ├── View Controllers/    # UI controllers
│   │   ├── Commands/            # Menu commands
│   │   └── Data Models/         # State managers
│   ├── Types/                   # Data types & models
│   │   ├── Agent/               # Agent protocols
│   │   ├── Conversation/        # Messages, functions
│   │   ├── Expert/              # RAG resources, knowledge graphs
│   │   └── Model/               # LLM model definitions
│   ├── Views/                   # SwiftUI views
│   ├── Extensions/              # Swift & AppKit extensions
│   └── Resources/               # Assets, localization
├── Sidekick.xcodeproj/          # Xcode project
└── SidekickTests/               # Unit tests
```

---

## 1. Local Inference Mechanism (Deep Dive)

### 1.1 Architecture Overview

The local inference system is built around a **multi-server architecture** that manages `llama.cpp` server processes:

```
┌─────────────────────────────────────────────────────────────┐
│                       Model.swift                            │
│              (MainActor, ObservableObject)                   │
│   ┌──────────────────┐  ┌──────────────────┐                │
│   │  mainModelServer │  │ workerModelServer │                │
│   │   (LlamaServer)  │  │   (LlamaServer)   │                │
│   └────────┬─────────┘  └─────────┬─────────│                │
└────────────┼──────────────────────┼─────────────────────────┘
             │                      │
             ▼                      ▼
    ┌─────────────────┐    ┌─────────────────┐
    │  llama-server   │    │  llama-server   │
    │   (Port 4579)   │    │   (Port 9830)   │
    │  Regular Chat   │    │  Worker Tasks   │
    └─────────────────┘    └─────────────────┘
             │                      │
             └──────────┬───────────┘
                        ▼
         ┌──────────────────────────────┐
         │     llama-server-watchdog    │
         │   (Heartbeat Monitor)        │
         └──────────────────────────────┘
```

### 1.2 Core Components

#### **`Model.swift`** - Inference Orchestrator

The `Model` class is a `@MainActor` singleton that orchestrates all LLM inference:

```swift
@MainActor
public class Model: ObservableObject {
    static public let shared: Model = .init(systemPrompt: InferenceSettings.systemPrompt)
    
    // Dual-server architecture
    var mainModelServer: LlamaServer     // Primary chat model (port 4579)
    var workerModelServer: LlamaServer   // Lightweight worker model (port 9830)
    
    // State management
    @Published public var wasRemoteServerAccessible: Bool = false
    @Published var pendingMessage: Message? = nil
    @Published var status: Status = .cold
    
    // Agent support
    var agent: (any Agent)?
}
```

**Key Design Decisions:**
- **Dual-model architecture**: Separates heavy chat model from lightweight worker model for parallel task execution
- **Hybrid local/remote**: Supports both local `llama.cpp` and OpenAI-compatible remote APIs
- **MainActor isolation**: Guarantees thread-safe UI updates

#### **`LlamaServer.swift`** - Server Process Management

The `LlamaServer` actor manages individual `llama-server` processes:

```swift
public actor LlamaServer {
    var modelType: ModelType  // .regular, .worker, or .completions
    var port: String          // Unique port per model type
    var process: Process      // llama-server process
    var monitor: Process      // llama-server-watchdog process
    
    // Active streaming requests (supports concurrent inference)
    var activeRequests: [UUID: ActiveRequestContext] = [:]
}
```

**Model Types:**
| Type | Port | Purpose |
|------|------|---------|
| `.regular` | 4579 | Main chat conversations |
| `.worker` | 9830 | Background tasks (entity extraction, summarization) |
| `.completions` | 1623 | Inline text completions |

#### **`LlamaServer+ServerLifecycle.swift`** - Process Lifecycle

The server startup process includes sophisticated configuration:

```swift
public func startServer(canReachRemoteServer: Bool) async throws {
    // Configure arguments
    var arguments: [String: String] = [
        "--model": modelPath,
        "--threads": "\(threadsToUse)",
        "--ctx-size": "\(self.contextLength)",
        "--port": self.port,
        "--gpu-layers": gpuLayersToUse  // GPU acceleration
    ]
    
    // Speculative decoding support
    if InferenceSettings.useSpeculativeDecoding {
        arguments["--model-draft"] = speculativeDecodingModelUrl
        arguments["--draft"] = "16"
        arguments["--draft-min"] = "7"
    }
    
    // Multimodal (vision) support
    if InferenceSettings.localModelUseVision {
        arguments["--mmproj"] = multimodalModelUrl
    }
    
    // Jinja templates for tool calling
    if Settings.useFunctions {
        arguments["--jinja"] = ""
    }
}
```

**Advanced Features:**
- **Speculative Decoding**: Uses a draft model to accelerate inference
- **Vision/Multimodal**: Supports mmproj projectors for image understanding
- **GPU Acceleration**: Configurable layer offloading to Metal
- **Custom Arguments**: User-configurable server parameters

#### **`llama-server-watchdog`** - Process Guardian

A separate Swift executable that monitors the main app and terminates orphaned `llama-server` processes:

```swift
func checkHeartbeat(serverProcessPID: Int32) {
    let checkInterval: TimeInterval = 15.0
    
    while true {
        let fileHandle = FileHandle.standardInput
        if fileHandle.availableData.count > 0 {
            // Main app is alive
        } else {
            terminateServerProcess(pid: serverProcessPID)
        }
        Thread.sleep(forTimeInterval: checkInterval)
    }
}
```

This prevents zombie `llama-server` processes if the app crashes.

### 1.3 Inference Flow

```
User Prompt
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│              Model.listenThinkRespond()                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  1. Determine mode: .chat, .agent, .deepResearch      │  │
│  │  2. Check remote server reachability                   │  │
│  │  3. Format messages with sources (RAG lookup)         │  │
│  └───────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    ┌─────────┐    ┌──────────┐    ┌───────────┐
    │ Default │    │   Chat   │    │   Agent   │
    │  Mode   │    │   Mode   │    │   Mode    │
    └────┬────┘    └────┬─────┘    └─────┬─────┘
         │              │                │
         ▼              ▼                ▼
┌─────────────────────────────────────────────────────────────┐
│              LlamaServer.getChatCompletion()                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  - Build ChatParameters (model-specific templating)    │  │
│  │  - EventSource SSE streaming                           │  │
│  │  - Tool call accumulation & parsing                    │  │
│  │  - Retry logic for network failures                    │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 Remote Model Support

Sidekick supports any OpenAI-compatible API:

```swift
// InferenceSettings.swift
public static var endpoint: String     // e.g., "https://api.openai.com/v1"
public static var serverModelName: String
public static var inferenceApiKey: String  // Stored in SecureDefaults

// Model routing decision
let useServer: Bool = InferenceSettings.useServer && self.wasRemoteServerAccessible
```

The `KnownModel` system provides intelligent model matching:

```swift
public struct KnownModel {
    var primaryName: String
    var organization: Organization  // .openAi, .anthropic, .qwen, etc.
    var modalities: [Modality]      // .text, .image
    var isReasoningModel: Bool
    
    // Fuzzy matching for remote API model names
    static func findModel(byIdentifier: String, in models: [KnownModel]) -> KnownModel?
}
```

---

## 2. Deep macOS Integration

### 2.1 Entitlements & Permissions

```xml
<!-- Sidekick.entitlements -->
<key>com.apple.security.cs.allow-jit</key>           <!-- JIT for llama.cpp -->
<key>com.apple.security.device.audio-input</key>     <!-- Voice input -->
<key>com.apple.security.files.bookmarks.app-scope</key>
<key>com.apple.security.personal-information.addressbook</key>
<key>com.apple.security.personal-information.calendars</key>
<key>com.apple.security.personal-information.location</key>
```

### 2.2 Accessibility API Integration

#### **`Accessibility.swift`** - System-Wide Text Access

```swift
public class Accessibility {
    @MainActor public static let shared = Accessibility()
    
    // Check accessibility permissions
    public static func checkAccessibility() -> Bool {
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    // Get selected text from any application
    public func getSelectedText() -> String? {
        // Try AXSelectedTextAttribute first
        if let text = getSelectedTextAX() { return text }
        // Fallback: simulate Cmd+C
        return getSelectedTextViaCopy()
    }
    
    // Type text into any focused field
    public func simulateTyping(for string: String) -> Bool {
        // Uses CGEvent to post keyboard events
    }
}
```

#### **`Extension+AXUIElement.swift`** - Caret Position Detection

```swift
extension AXUIElement {
    // Get cursor position for floating UI placement
    func getInsertionPointRect() -> CGRect? {
        // Cascade: CaretBounds → CaretRect → MouseCursor
        if let caretBounds = getCaretBounds() { return caretBounds }
        if let caretRect = getCaretRect() { return caretRect }
        return getMouseCursorRect()
    }
    
    // Get text before/after cursor for completions
    func getCursorPosition() -> Int?
}
```

### 2.3 Global Keyboard Shortcuts

```swift
// ShortcutController.swift
public static func setup() {
    // Global hotkey: Cmd+Ctrl+I → Inline Writing Assistant
    KeyboardShortcuts.setShortcut(.init(.i, modifiers: [.command, .control]),
                                   for: .toggleInlineAssistant)
    
    // Tab → Accept next completion word
    KeyboardShortcuts.setShortcut(.init(.tab), for: .acceptNextToken)
    
    // Shift+Tab → Accept entire completion
    KeyboardShortcuts.setShortcut(.init(.tab, modifiers: .shift), for: .acceptAllTokens)
}
```

### 2.4 Inline Writing Assistant

The `InlineAssistantController` creates floating overlay windows:

```swift
@MainActor
private func showInlineAssistant() {
    // 1. Get selected text via Accessibility API
    guard let selectedText = Accessibility.shared.getSelectedText() else { return }
    
    // 2. Create floating NSPanel
    let panel = NSPanel.getOverlayPanel()
    panel.contentView = NSHostingView(rootView: InlineAssistantView(selectedText: ...))
    
    // 3. Position at mouse location
    panel.setPosition(vertical: .center, horizontal: .center, screen: screenWithMouse)
}
```

### 2.5 Inline Text Completions

The `CompletionsController` provides IDE-style autocomplete across all apps:

```swift
public class CompletionsController {
    var server: LlamaServer  // Uses .completions model type (port 1623)
    var panels: [NSPanel]    // Floating suggestion overlays
    
    private func generateAndDisplayCompletion() async {
        // 1. Get text from focused field
        let (preText, postText) = fetchText()
        
        // 2. Generate completion tokens
        let tokens = await server.getCompletion(text: preText, maxTokenNumber: 5)
        
        // 3. Display in floating panel at cursor position
        let cursorBounds = CursorBounds()
        displayCompletion(text: completion)
    }
    
    // Triggered via global CGEvent tap
    var keyEventTap: CFMachPort?  // Monitors all keyboard events
}
```

### 2.6 Apple Intelligence Integration

```swift
// PromptAnalyzer.swift (Image Generation Router)
public static func getExpectedResultType(_ prompt: String) -> ResultType {
    // CoreML classifier determines if prompt wants text or image
    guard let promptClassifier = try? NLModel(mlModel: MLModel(
        contentsOf: Bundle.main.url(forResource: "UserRequestClassifier", withExtension: "mlmodelc")!
    )) else { return .text }
    
    let hypotheses = promptClassifier.predictedLabelHypotheses(for: prompt)
    // Route to Apple's ImagePlayground if available (macOS 15.2+)
    if #available(macOS 15.2, *) {
        return ImagePlaygroundViewController.isAvailable ? .image : .text
    }
}
```

### 2.7 Native Framework Integration

| Framework | Usage |
|-----------|-------|
| **EventKit** | Calendar events (get, add, remove, edit) |
| **Contacts** | Address book lookup for email drafting |
| **AVFoundation** | Speech-to-text (SFSpeechRecognizer) and TTS (AVSpeechSynthesizer) |
| **NaturalLanguage** | CoreML model inference for prompt classification |
| **ApplicationServices** | Accessibility API for system-wide text manipulation |
| **Carbon** | Legacy key code handling |
| **ImagePlayground** | Apple Intelligence image generation |
| **Sparkle** | App updates |

---

## 3. RAG & Knowledge Management (Experts System)

### 3.1 Architecture

```
        ┌─────────────────────────────────────────┐
        │           ExpertManager                  │
        │  (ObservableObject, manages all experts) │
        └─────────────────┬───────────────────────┘
                          │
           ┌──────────────┼──────────────┐
           ▼              ▼              ▼
      ┌─────────┐    ┌─────────┐    ┌─────────┐
      │ Expert  │    │ Expert  │    │ Expert  │
      │ (CS)    │    │ (Math)  │    │ (Lit)   │
      └────┬────┘    └────┬────┘    └────┬────┘
           │              │              │
           ▼              ▼              ▼
      ┌─────────────────────────────────────────┐
      │              Resources                   │
      │  ┌─────────────────────────────────┐    │
      │  │         Resource[]              │    │
      │  │  (Files, Folders, URLs)         │    │
      │  └────────────────┬────────────────┘    │
      │                   │                      │
      │  ┌────────────────┼───────────────┐     │
      │  │                │               │     │
      │  ▼                ▼               ▼     │
      │ ┌────────┐   ┌──────────┐  ┌─────────┐ │
      │ │Vectors │   │Knowledge │  │Community│ │
      │ │(DistilBERT)│  Graph   │  │Detection│ │
      │ └────────┘   └──────────┘  └─────────┘ │
      └─────────────────────────────────────────┘
```

### 3.2 Vector Search (SimilaritySearchKit)

```swift
// Resource.swift
public mutating func updateIndex(resourcesDirUrl: URL) async -> Bool {
    // 1. Extract text using ExtractKit
    let text = try await ExtractKit.shared.extractText(url: self.url, speed: .fast)
    
    // 2. Chunk into overlapping segments
    let chunks = Chunker.chunkText(text, maxChunkSize: 500, overlapSize: 50)
    
    // 3. Generate embeddings with DistilBERT
    let similarityIndex = await SimilarityIndex(
        model: DistilbertEmbeddings(),
        metric: CosineSimilarity()
    )
    
    // 4. Save to disk for persistence
    try similarityIndex.saveIndex(toDirectory: indexDirUrl)
}
```

### 3.3 GraphRAG (Knowledge Graph Enhancement)

The GraphRAG system uses the worker model to extract entities and relationships:

```swift
// EntityExtractor.swift
public static func extractEntitiesAndRelationships(from chunks: [String]) async throws {
    let systemPrompt = """
    You are an expert at extracting entities and relationships from text.
    Return ONLY a valid JSON object with this exact structure:
    { "entities": [...], "relationships": [...] }
    """
    
    // Uses worker model for extraction
    let response = try await Model.shared.workerModelServer.getChatCompletion(...)
}

// GraphRetriever.swift (Multi-stage retrieval)
public static func retrieve(query: String, vectorResults: [SearchResult], graph: KnowledgeGraph) {
    // Stage 1: Get initial vector results
    // Stage 2: Find entities in those chunks
    // Stage 3: Expand via graph traversal (relationships)
    // Stage 4: Find relevant community summaries
    // Stage 5: Build enhanced results with entity context
}
```

---

## 4. Function Calling & Agents

### 4.1 Function System

```swift
// Function.swift - Generic function implementation
public struct Function<Parameter: FunctionParams, Result: Codable>: AnyFunctionBox {
    var name: String
    var description: String
    var clearance: Clearance  // .regular, .sensitive, .dangerous
    var params: [FunctionParameter]
    var run: (Parameter) async throws -> Result
    
    // Converts to OpenAI-compatible function schema
    public var openAiFunctionCall: OpenAIFunction {
        return OpenAIFunction(type: "function", function: funcDetail)
    }
}
```

**Available Functions:**
| Category | Functions |
|----------|-----------|
| **Arithmetic** | Basic math operations |
| **Calendar** | `get_events`, `add_event`, `remove_event`, `edit_event` |
| **Reminders** | CRUD operations on Reminders.app |
| **Todos** | Task management |
| **Code** | Python execution, JavaScript running |
| **File** | File system operations |
| **Web** | Web search, page reading |
| **Expert** | RAG resource lookup |
| **Input** | Prompt for user input |

### 4.2 Agent Protocol

```swift
public protocol Agent: ObservableObject {
    var name: String { get }
    var preview: AnyView { get }  // Progress UI
    func run() async throws -> LlamaServer.CompleteResponse
}
```

### 4.3 Deep Research Agent

A multi-step research agent that:
1. Clarifies the query if needed
2. Plans section structure
3. Conducts web research (50-80 pages)
4. Synthesizes into a research report

```swift
public class DeepResearchAgent: Agent {
    var sections: [Section] = []
    var currentStep: Step = .planning
    
    public func run() async throws -> LlamaServer.CompleteResponse {
        // 1. Check if we have sufficient information
        // 2. Split into sections via LLM
        // 3. Conduct research for each section
        // 4. Draft final report with citations
    }
}
```

---

## 5. Data Flow & State Management

### 5.1 App Architecture

```swift
@main
struct SidekickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Global state objects
    @StateObject private var conversationManager: ConversationManager = .shared
    @StateObject private var expertManager: ExpertManager = .shared
    @StateObject private var memories: Memories = .shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(conversationManager)
                .environmentObject(expertManager)
        }
    }
}
```

### 5.2 Manager Pattern

All persistent state uses singleton managers:
- `ConversationManager` - Conversation history
- `ExpertManager` - RAG experts and resources
- `SourcesManager` - Cited sources
- `Memories` - Cross-conversation memory
- `DownloadManager` - Model downloads

---

## 6. Key Architectural Decisions

### 6.1 Strengths

| Decision | Rationale |
|----------|-----------|
| **Actor-based LlamaServer** | Thread-safe concurrent inference management |
| **Dual-model architecture** | Parallel task execution without blocking chat |
| **Process watchdog** | Prevents resource leaks from orphaned servers |
| **EventSource SSE streaming** | Real-time token streaming to UI |
| **MainActor Model singleton** | Single source of truth for inference state |

### 6.2 Trade-offs

| Decision | Trade-off |
|----------|-----------|
| **llama.cpp subprocess** | Must manage process lifecycle (vs. in-process library) |
| **UserDefaults for settings** | Fast but not encrypted (API key uses SecureDefaults) |
| **Singleton managers** | Simple global state but harder to test |
| **Full Accessibility access** | Requires user trust for system-wide text access |

---

## 7. Technology Stack

| Layer | Technology |
|-------|------------|
| **UI** | SwiftUI, AppKit (NSPanel overlays) |
| **Inference** | llama.cpp (subprocess), EventSource (SSE) |
| **Embeddings** | SimilaritySearchKit + DistilBERT (CoreML) |
| **Text Extraction** | ExtractKit (PDF, DOCX, etc.) |
| **Graph Database** | SQLite (via swift-sqlite) |
| **Keyboard Shortcuts** | KeyboardShortcuts (Sindre Sorhus) |
| **Updates** | Sparkle |

---

## Summary

Sidekick is a well-architected native macOS application that demonstrates how to build a privacy-preserving AI assistant with deep OS integration. Key takeaways:

1. **Local inference via llama.cpp** provides complete privacy with sophisticated features (speculative decoding, vision, function calling)
2. **Dual-model architecture** enables responsive UX by parallelizing heavy chat and lightweight worker tasks
3. **macOS-first design** leverages Accessibility APIs, EventKit, Contacts, and Apple Intelligence
4. **GraphRAG** enhances traditional vector search with entity/relationship extraction and community detection
5. **Process watchdog** ensures robustness by preventing orphaned inference servers

The architecture would benefit from:
- Migration from singletons to dependency injection for testability
- More structured error handling in the inference pipeline
- Potential migration to in-process `llama.cpp` bindings for reduced overhead

---

*Analysis generated: 2026-01-11*
