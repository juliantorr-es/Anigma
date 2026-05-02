# OpenCode TUI Architecture: Deep Analysis

A comprehensive analysis of OpenCode's Terminal User Interface implementation—all the features, why the UX is so polished, and how to implement a similar TUI renderer in Swift.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Core Rendering Architecture](#core-rendering-architecture)
3. [Complete Feature Catalog](#complete-feature-catalog)
4. [UX Polish: Why It Feels Premium](#ux-polish-why-it-feels-premium)
5. [State Management Deep Dive](#state-management-deep-dive)
6. [Component Architecture](#component-architecture)
7. [Theming System](#theming-system)
8. [Implementing a Similar TUI in Swift](#implementing-a-similar-tui-in-swift)
9. [Architectural Patterns to Adopt](#architectural-patterns-to-adopt)

---

## Executive Summary

OpenCode's TUI is built on a custom Solid.js-based terminal rendering framework called **OpenTUI** (`@opentui/solid` and `@opentui/core`). The architecture achieves a premium feel through:

- **60 FPS rendering** with intelligent dirty-checking
- **Declarative JSX components** for terminal primitives
- **Reactive state management** using Solid.js stores
- **Event-driven architecture** with real-time sync via SSE/RPC
- **Comprehensive theming** with 31 built-in themes and syntax highlighting
- **Vim-like keybindings** with leader key support
- **Deep feature integration** (autocomplete, fuzzy search, image paste, stashing)

---

## Core Rendering Architecture

### The OpenTUI Framework

OpenCode's TUI uses a custom framework consisting of two packages:

1. **`@opentui/core`**: Low-level rendering primitives
   - `BoxRenderable`, `TextareaRenderable`, `ScrollBoxRenderable`, `InputRenderable`
   - Layout engine (Flexbox-based for terminal)
   - `RGBA` color handling, `TextAttributes` (bold, italic, etc.)
   - Mouse event handling, keyboard parsing
   - Extmarks system for virtual text overlays

2. **`@opentui/solid`**: React-like JSX bindings
   - `<box>`, `<text>`, `<textarea>`, `<scrollbox>`, `<input>`, `<diff>` components
   - `useKeyboard()`, `useRenderer()`, `useTerminalDimensions()` hooks
   - `render()` function with configurable FPS and features

### Entry Point and Render Loop

```typescript
// From packages/opencode/src/cli/cmd/tui/app.tsx
render(
  () => <App />,
  {
    targetFps: 60,                    // Smooth 60 FPS rendering
    gatherStats: false,
    exitOnCtrlC: false,
    useKittyKeyboard: {},             // Modern keyboard protocol
    consoleOptions: {
      keyBindings: [{ name: "y", ctrl: true, action: "copy-selection" }],
      onCopySelection: (text) => Clipboard.copy(text),
    },
  },
)
```

### Client-Server Model

```
┌─────────────────────────────────────────────────────────────────┐
│                        Main Thread (TUI)                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────────┐     ┌────────────────────────────────┐  │
│  │   Solid.js UI     │────→│   16 Context Providers         │  │
│  │   Components      │     │   (Theme, Sync, Local, etc.)   │  │
│  └───────────────────┘     └────────────────────────────────┘  │
│            │                            │                       │
│            ▼                            ▼                       │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              SDK Client (RPC/HTTP)                        │ │
│  └───────────────────────────────────────────────────────────┘ │
└────────────────────────────│────────────────────────────────────┘
                             │ RPC/SSE
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Worker Thread (Server)                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────────┐     ┌────────────────────────────────┐  │
│  │   Hono Backend    │────→│   GlobalBus Events             │  │
│  │   API Server      │     │   (Session, Permission, etc.)  │  │
│  └───────────────────┘     └────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Complete Feature Catalog

### Input & Prompt Features

| Feature | Description | Files |
|---------|-------------|-------|
| **Multi-line Input** | Full textarea with cursor navigation | `prompt/index.tsx` |
| **Shell Mode** | Prefix `!` to run shell commands directly | `prompt/index.tsx` |
| **Extmarks** | Virtual text overlays for `@file` and `@agent` references | `prompt/index.tsx`, autocomplete |
| **Autocomplete** | Fuzzy file search (`@`), command completion (`/`) | `prompt/autocomplete.tsx` |
| **Frecency Sorting** | Files sorted by frequency × recency | `prompt/frecency.tsx` |
| **History Navigation** | Up/Down arrows with persistent JSONL storage | `prompt/history.tsx` |
| **Prompt Stashing** | Save incomplete prompts for later (`/stash`) | `prompt/stash.tsx` |
| **Image Paste** | `Ctrl+V` to paste images from clipboard | `prompt/index.tsx` |
| **External Editor** | `Ctrl+X E` opens full editor for long prompts | via `Editor.open()` |
| **Vim Keybindings** | Standard textarea movement | `textarea-keybindings.ts` |

### Session Features

| Feature | Description |
|---------|-------------|
| **Undo/Redo** | Full message undo with file restoration |
| **Compact/Summarize** | Compress long sessions to save context |
| **Share** | Public URL generation for conversations |
| **Fork** | Branch from any message in timeline |
| **Export** | Markdown export with multiple formats |
| **Timeline Jump** | Navigate to specific messages |
| **Parent/Child Navigation** | Navigate subagent session hierarchies |

### UI Components

| Component | Purpose |
|-----------|---------|
| **Toast System** | Transient notifications with variants (info, success, warning, error) |
| **Dialog Stack** | Modal system with proper focus management |
| **DialogSelect** | Fuzzy-searchable selection dialogs |
| **Knight Rider Spinner** | Animated bidirectional scanner with color trails |
| **Diff Viewer** | Split/unified diff with syntax highlighting |
| **ScrollBox** | Virtual scrolling for large content |
| **Permission Prompts** | Interactive approval for tool calls |
| **Did You Know** | Contextual tips with random rotation |

### Sidebar Information

| Data | Display |
|------|---------|
| Session title & share URL | Header |
| Context tokens & cost | Real-time updates |
| MCP status | Connected/Failed/Auth needed |
| LSP status | Active language servers |
| Todo items | Agent task tracking |
| Modified files | Diff additions/deletions |
| Getting started | Onboarding for new users |

### Command System

All 102+ tips suggest commands/keybinds available:

```typescript
// From tips.ts - Just the categories
- File attachment: @filename fuzzy search
- Shell commands: !command execution  
- Session management: /new, /sessions, /compact, /undo, /redo
- Sharing: /share, /unshare
- Export: /export, /copy
- Navigation: PageUp/Down, Ctrl+G (top), End (bottom)
- Models: /models, F2 cycle, favorites
- Agents: Tab cycle, @agent invoke
- Theme: /theme, Ctrl+X T
- MCP: /mcp toggle
- Vim: standard text movements
- Custom commands: .opencode/command/*.md
- Plugins: .opencode/plugin/*.ts
```

---

## UX Polish: Why It Feels Premium

### 1. **Micro-Interactions & Animations**

**Knight Rider Spinner**: Not a simple spinner—a sophisticated bidirectional scanner:

```typescript
// From ui/spinner.ts
interface KnightRiderOptions {
  width?: number
  style?: "blocks" | "diamonds"      // ■⬝ or ⬥◆
  holdFrames?: { start?: number; end?: number }  // Pause at edges
  colors?: ColorInput[]              // Gradient trail
  enableFading?: boolean             // Inactive dot fading
}

// Creates smooth animation with:
// - Forward sweep with color trail
// - Hold at end (9 frames)
// - Backward sweep
// - Hold at start (30 frames)
// - Alpha-based fading during hold
```

**Toast Notifications**: Proper timing with auto-dismiss:
```typescript
toast.show({
  variant: "success" | "warning" | "error" | "info",
  message: string,
  duration: 5000,  // Auto-dismiss
})
```

### 2. **Intelligent Autocomplete**

The autocomplete system is remarkably sophisticated:

```typescript
// From prompt/autocomplete.tsx
const result = fuzzysort.go(removeLineRange(currentFilter), mixed, {
  keys: [
    (obj) => removeLineRange((obj.value ?? obj.display).trimEnd()),
    "description",
    (obj) => obj.aliases?.join(" ") ?? "",
  ],
  limit: 10,
  scoreFn: (objResults) => {
    let score = objResults.score
    // Boost exact prefix matches
    if (displayResult?.target.startsWith(store.visible + currentFilter)) {
      score *= 2
    }
    // Apply frecency bonus
    const frecencyScore = objResults.obj.path ? frecency.getFrecency(objResults.obj.path) : 0
    return score * (1 + frecencyScore)
  },
})
```

**Features**:
- Fuzzy matching with `fuzzysort`
- Line range support (`file.ts#10-20`)
- Frecency scoring (frequency × recency decay)
- Tab to expand directories
- Agent and MCP resource suggestions

### 3. **Vim-Like Keybinding System**

Leader key pattern for complex commands:

```typescript
// From context/keybind.tsx
function leader(active: boolean) {
  if (active) {
    setStore("leader", true)
    focus = renderer.currentFocusedRenderable
    focus?.blur()  // Blur input during leader mode
    timeout = setTimeout(() => leader(false), 2000)  // 2s timeout
  }
}

// Usage: Ctrl+X (leader) then another key
// Ctrl+X L = session list
// Ctrl+X T = theme switch
// Ctrl+X M = model switch
```

### 4. **Real-Time Synchronization**

The `SyncProvider` maintains a reactive mirror of server state:

```typescript
// From context/sync.tsx
const [store, setStore] = createStore({
  status: "loading" | "partial" | "complete",
  provider: Provider[],
  session: Session[],
  message: Record<string, Message[]>,
  part: Record<string, Part[]>,
  permission: Record<string, PermissionRequest[]>,
  question: Record<string, QuestionRequest[]>,
  lsp: LspStatus[],
  mcp: Record<string, McpStatus>,
  mcp_resource: Record<string, McpResource>,
  config: Config,
  todo: Record<string, Todo[]>,
  // ... more
})

// Real-time updates via SSE events
sdk.event.listen((e) => {
  switch (e.type) {
    case "session.created":
    case "message.created":
    case "part.updated":
    case "permission.asked":
    // ... handle all event types
  }
})
```

### 5. **Persistence & Recovery**

Multiple layers of state persistence:

| State | Storage | Format |
|-------|---------|--------|
| Prompt history | `~/.opencode/state/prompt-history.jsonl` | JSONL (self-healing) |
| Prompt stash | `~/.opencode/state/prompt-stash.jsonl` | JSONL |
| File frecency | `~/.opencode/state/frecency.jsonl` | JSONL |
| Model preferences | `~/.opencode/state/model.json` | JSON |
| Local KV store | In-memory | Reactive store |

### 6. **Graceful Degradation**

```typescript
// Terminal capability detection
const mode = await getTerminalBackgroundColor()  // Light/dark detection
useKittyKeyboard: {}  // Falls back if not supported

// Permission system with multi-level fallback
reply: "once" | "always" | "reject"
```

### 7. **Contextual Help**

**Did You Know** component with parsed formatting:

```typescript
// From component/did-you-know.tsx
const TIPS = [
  "Type {highlight}@{/highlight} followed by a filename...",
  "Press {highlight}Tab{/highlight} to cycle between agents...",
]

function parseTip(tip: string): TipPart[] {
  // Parse {highlight}...{/highlight} tags for styling
}
```

---

## State Management Deep Dive

### Context Provider Hierarchy (16 Levels)

```tsx
<ArgsProvider>           // CLI arguments
  <ExitProvider>         // Exit handling
    <KVProvider>         // Local key-value storage
      <ToastProvider>    // Notifications
        <RouteProvider>  // Client-side routing
          <SDKProvider>  // API client & SSE
            <SyncProvider>       // Real-time state mirror
              <ThemeProvider>    // Theming & syntax
                <LocalProvider>  // Agent/model selection
                  <KeybindProvider>      // Vim-style keybinds
                    <PromptStashProvider>  // Saved prompts
                      <DialogProvider>     // Modal management
                        <CommandProvider>  // Command palette
                          <FrecencyProvider>     // File ranking
                            <PromptHistoryProvider>  // History
                              <PromptRefProvider>    // Prompt refs
                                <App />
```

### Why Solid.js?

OpenCode chose Solid.js over React for TUI for specific reasons:

1. **Fine-grained reactivity**: No virtual DOM diffing overhead
2. **True reactive primitives**: `createSignal`, `createStore`, `createEffect`
3. **Compile-time optimization**: Smaller runtime, faster execution
4. **Direct DOM mutations**: Critical for 60 FPS terminal rendering

```typescript
// Solid.js reactive pattern used throughout
const [store, setStore] = createStore({ selected: 0 })

// Fine-grained update - only this property changes
setStore("selected", 5)

// Produce for complex mutations
setStore(produce((draft) => {
  draft.entries.push(newEntry)
}))
```

---

## Component Architecture

### Prompt Component (1085 lines)

The `Prompt` component is the most complex single component:

```typescript
export function Prompt(props: PromptProps) {
  // Core state
  const [store, setStore] = createStore({
    prompt: { input: "", parts: [] },
    mode: "normal" | "shell",
    extmarkToPartIndex: Map<number, number>,
    interrupt: number,
    placeholder: number,
  })

  // Feature integrations
  const keybind = useKeybind()      // Vim keybindings
  const local = useLocal()          // Model/agent state
  const sdk = useSDK()              // API client
  const history = usePromptHistory() // Command history
  const stash = usePromptStash()    // Saved prompts
  const autocomplete = useAutocomplete()  // File/command completion
  
  // Extmark management for virtual text
  function syncExtmarksWithPromptParts() { ... }
  function restoreExtmarksFromParts(parts) { ... }
  
  // Submission with validation
  async function submit() {
    if (autocomplete.visible) return
    if (!store.prompt.input) return
    const model = local.model.current()
    if (!model) { promptModelWarning(); return }
    // ... send to API
  }
}
```

### Dialog System

Stack-based modal management:

```typescript
// From ui/dialog.tsx
export function DialogProvider(props: ParentProps) {
  const [store, setStore] = createStore({
    stack: [] as DialogEntry[],
  })

  return {
    push: (component) => setStore("stack", (s) => [...s, { component }]),
    replace: (component) => setStore("stack", [{ component }]),
    pop: () => setStore("stack", (s) => s.slice(0, -1)),
    clear: () => setStore("stack", []),
  }
}
```

### Permission Prompt

Sophisticated permission handling with diff preview:

```typescript
// From routes/session/permission.tsx
<Switch>
  <Match when={request.permission === "edit"}>
    <EditBody request={request} />  // Shows diff preview
  </Match>
  <Match when={request.permission === "bash"}>
    <TextBody icon="#" title={description} description={"$ " + command} />
  </Match>
  // ... handlers for read, glob, grep, webfetch, etc.
</Switch>

<Prompt
  options={{ once: "Allow once", always: "Allow always", reject: "Reject" }}
  onSelect={(option) => {
    sdk.client.permission.reply({ reply: option, requestID })
  }}
/>
```

---

## Theming System

### Built-in Themes (31)

Located in `context/theme/`:
- GitHub Dark/Light
- Monokai variants
- Dracula
- Catppuccin (Frappé, Latte, Macchiato, Mocha)
- Tokyo Night variants
- Nord
- Gruvbox
- Solarized
- Material
- One Dark
- And more...

### Theme Resolution

```typescript
// From context/theme.tsx
interface Theme {
  // Core colors
  background: RGBA
  backgroundPanel: RGBA
  backgroundElement: RGBA
  backgroundMenu: RGBA
  
  // Semantic colors
  primary: RGBA
  secondary: RGBA
  accent: RGBA
  success: RGBA
  warning: RGBA
  error: RGBA
  info: RGBA
  
  // Text colors
  text: RGBA
  textMuted: RGBA
  
  // Diff colors
  diffAdded: RGBA
  diffRemoved: RGBA
  diffAddedBg: RGBA
  // ... 20+ more diff colors
  
  // UI elements
  border: RGBA
  selection: RGBA
}
```

### Syntax Highlighting Integration

Tree-sitter based syntax highlighting with theme-aware colors:

```typescript
const { theme, syntax } = useTheme()

// Get style IDs for extmarks
const fileStyleId = syntax().getStyleId("extmark.file")
const agentStyleId = syntax().getStyleId("extmark.agent")

// Apply to diff viewer
<diff
  syntaxStyle={syntax()}
  addedBg={theme.diffAddedBg}
  removedBg={theme.diffRemovedBg}
  // ...
/>
```

---

## Implementing a Similar TUI in Swift

### Recommended Architecture

```swift
// MARK: - Core Rendering Layer

/// Low-level terminal rendering primitives
struct TerminalRenderer {
    var targetFPS: Int = 60
    var buffer: TerminalBuffer
    var dirtyRegions: Set<Rect>
    
    mutating func render(_ root: any Renderable) {
        // 1. Layout pass (Flexbox-like)
        layoutTree(root)
        
        // 2. Render to buffer
        root.render(to: &buffer)
        
        // 3. Diff with previous frame
        let changes = buffer.diff(with: previousBuffer)
        
        // 4. Emit ANSI sequences for changes only
        for change in changes {
            terminal.write(change.ansiSequence)
        }
    }
}

/// Renderable protocol for all UI elements
protocol Renderable {
    var frame: Rect { get set }
    var children: [any Renderable] { get }
    func render(to buffer: inout TerminalBuffer)
    func handleKey(_ event: KeyEvent) -> Bool
    func handleMouse(_ event: MouseEvent) -> Bool
}
```

### Component System

```swift
// MARK: - Declarative Component Layer

/// Result builder for declarative UI
@resultBuilder
struct TUIBuilder {
    static func buildBlock(_ components: any Renderable...) -> [any Renderable] {
        components
    }
}

/// Box container (like <box> in OpenTUI)
struct Box: Renderable {
    var flexDirection: FlexDirection = .column
    var justifyContent: JustifyContent = .flexStart
    var alignItems: AlignItems = .stretch
    var padding: EdgeInsets = .zero
    var backgroundColor: Color?
    var borderStyle: BorderStyle?
    
    @TUIBuilder var content: () -> [any Renderable]
    
    var children: [any Renderable] { content() }
}

/// Text element
struct Text: Renderable {
    var content: String
    var foreground: Color?
    var attributes: TextAttributes = []
    var wrapMode: WrapMode = .word
}

/// Textarea with full editing
class Textarea: Renderable {
    var text: String = ""
    var cursorOffset: Int = 0
    var extmarks: ExtmarkManager
    var keyBindings: [KeyBinding]
    
    func insertText(_ text: String) { ... }
    func deleteRange(_ start: Int, _ end: Int) { ... }
}
```

### Reactive State Management

Swift's Observation framework (iOS 17+/macOS 14+) provides similar reactivity:

```swift
// MARK: - State Management

@Observable
final class AppState {
    var sessions: [Session] = []
    var messages: [String: [Message]] = [:]
    var currentTheme: Theme = .default
    var selectedModel: ModelSelection?
}

@Observable
final class SyncState {
    var status: SyncStatus = .loading
    var permissions: [String: [PermissionRequest]] = [:]
    var mcpStatus: [String: MCPStatus] = [:]
    var lspStatus: [LSPStatus] = []
    
    func handleEvent(_ event: ServerEvent) {
        switch event {
        case .sessionCreated(let session):
            // Automatic observation triggers UI update
            sessions.append(session)
        case .permissionAsked(let request):
            permissions[request.sessionID, default: []].append(request)
        // ...
        }
    }
}

// For earlier OS versions, use Combine:
final class LegacySyncState: ObservableObject {
    @Published var sessions: [Session] = []
    // ...
}
```

### Event-Driven Communication

```swift
// MARK: - Server Communication

actor ServerConnection {
    private var eventStream: AsyncStream<ServerEvent>?
    private var rpcChannel: RPCChannel
    
    func connect() async throws {
        // SSE for events, RPC for commands
        eventStream = AsyncStream { continuation in
            Task {
                let eventSource = EventSource(url: serverURL.appending(path: "/events"))
                for await event in eventSource {
                    continuation.yield(ServerEvent(from: event))
                }
            }
        }
    }
    
    func subscribe() -> AsyncStream<ServerEvent> {
        eventStream!
    }
    
    func call<T: Decodable>(_ method: String, params: Encodable) async throws -> T {
        try await rpcChannel.call(method, params: params)
    }
}
```

### Keybinding System

```swift
// MARK: - Vim-Like Keybindings

struct Keybind: Hashable {
    var key: String
    var modifiers: KeyModifiers
    var requiresLeader: Bool
}

@Observable
final class KeybindManager {
    var isLeaderActive = false
    var bindings: [String: [Keybind]] = [:]
    
    private var leaderTimeout: Task<Void, Never>?
    
    func activateLeader() {
        isLeaderActive = true
        leaderTimeout?.cancel()
        leaderTimeout = Task {
            try? await Task.sleep(for: .seconds(2))
            isLeaderActive = false
        }
    }
    
    func match(_ name: String, event: KeyEvent) -> Bool {
        guard let binds = bindings[name] else { return false }
        let parsed = Keybind(from: event, leaderActive: isLeaderActive)
        return binds.contains(parsed)
    }
}
```

### Autocomplete with Frecency

```swift
// MARK: - Frecency-Based Autocomplete

struct FrecencyEntry: Codable {
    var frequency: Int
    var lastOpen: Date
    
    var score: Double {
        let daysSince = Date().timeIntervalSince(lastOpen) / 86400
        let weight = 1.0 / (1.0 + daysSince)
        return Double(frequency) * weight
    }
}

@Observable
final class FrecencyStore {
    private var entries: [String: FrecencyEntry] = [:]
    private let storageURL: URL
    
    func recordAccess(_ path: String) {
        var entry = entries[path] ?? FrecencyEntry(frequency: 0, lastOpen: .distantPast)
        entry.frequency += 1
        entry.lastOpen = Date()
        entries[path] = entry
        save()
    }
    
    func score(for path: String) -> Double {
        entries[path]?.score ?? 0
    }
}

struct Autocomplete {
    var frecency: FrecencyStore
    
    func search(query: String, files: [String]) -> [String] {
        let fuzzyResults = files.fuzzyMatch(query)
        return fuzzyResults.sorted { lhs, rhs in
            let lhsScore = frecency.score(for: lhs) * (1 + lhs.fuzzyScore(for: query))
            let rhsScore = frecency.score(for: rhs) * (1 + rhs.fuzzyScore(for: query))
            return lhsScore > rhsScore
        }
    }
}
```

### Layout Engine

```swift
// MARK: - Flexbox-Like Layout

struct LayoutContext {
    var availableWidth: Int
    var availableHeight: Int
}

protocol Layoutable {
    var layoutNode: LayoutNode { get }
    func layout(in context: LayoutContext) -> Size
}

struct LayoutNode {
    // Flexbox properties
    var flexDirection: FlexDirection = .column
    var flexGrow: Float = 0
    var flexShrink: Float = 1
    var justifyContent: JustifyContent = .flexStart
    var alignItems: AlignItems = .stretch
    var gap: Int = 0
    var padding: EdgeInsets = .zero
    var margin: EdgeInsets = .zero
    
    // Computed
    var computedFrame: Rect = .zero
    
    mutating func calculateLayout(width: Int, height: Int) {
        // Yoga-like layout algorithm
        // 1. Measure all children
        // 2. Distribute space based on flex properties
        // 3. Position children based on justify/align
    }
}
```

### Animation System

```swift
// MARK: - Spinner Animation

struct KnightRiderSpinner {
    var width: Int = 8
    var style: Style = .diamonds
    var colors: [Color]
    var holdStartFrames: Int = 30
    var holdEndFrames: Int = 9
    
    enum Style {
        case blocks  // ■⬝
        case diamonds  // ⬥◆
    }
    
    private var frameIndex: Int = 0
    private var totalFrames: Int {
        width + holdEndFrames + (width - 1) + holdStartFrames
    }
    
    mutating func nextFrame() -> AttributedString {
        frameIndex = (frameIndex + 1) % totalFrames
        
        var result = AttributedString()
        for charIndex in 0..<width {
            let colorIndex = calculateColorIndex(frameIndex, charIndex)
            let char = style == .diamonds ? (colorIndex >= 0 ? "⬥" : "·") : (colorIndex >= 0 ? "■" : "⬝")
            var charStr = AttributedString(char)
            charStr.foregroundColor = colorIndex >= 0 ? colors[min(colorIndex, colors.count - 1)] : .gray
            result.append(charStr)
        }
        return result
    }
    
    private func calculateColorIndex(_ frame: Int, _ char: Int) -> Int {
        // Bidirectional scanning with trail calculation
        // (Implementation matches spinner.ts logic)
    }
}
```

### Dialog/Modal System

```swift
// MARK: - Dialog Stack

@Observable
final class DialogManager {
    private(set) var stack: [DialogEntry] = []
    
    struct DialogEntry: Identifiable {
        let id = UUID()
        var content: AnyView
        var onDismiss: (() -> Void)?
    }
    
    func push<Content: View>(_ content: Content) {
        stack.append(DialogEntry(content: AnyView(content)))
    }
    
    func replace<Content: View>(_ content: Content) {
        stack = [DialogEntry(content: AnyView(content))]
    }
    
    func pop() {
        guard !stack.isEmpty else { return }
        let entry = stack.removeLast()
        entry.onDismiss?()
    }
    
    func clear() {
        stack.removeAll()
    }
}
```

### Theming

```swift
// MARK: - Theme System

struct Theme: Codable {
    // Core
    var background: Color
    var backgroundPanel: Color
    var backgroundElement: Color
    var backgroundMenu: Color
    
    // Semantic
    var primary: Color
    var secondary: Color
    var accent: Color
    var success: Color
    var warning: Color
    var error: Color
    
    // Text
    var text: Color
    var textMuted: Color
    
    // Diff
    var diffAdded: Color
    var diffRemoved: Color
    var diffAddedBg: Color
    var diffRemovedBg: Color
    // ...
    
    static let `default` = Theme.load(name: "github-dark")
    
    static func load(name: String) -> Theme {
        // Load from bundled JSON or ~/.config/app/themes/
    }
}

@Observable
final class ThemeManager {
    var current: Theme
    var mode: ColorMode  // .light, .dark, .system
    
    init() {
        // Detect terminal background color
        mode = TerminalCapabilities.detectColorMode()
        current = Theme.forMode(mode)
    }
}
```

---

## Architectural Patterns to Adopt

### 1. **Context Provider Pattern**

Create a hierarchy of observable contexts for dependency injection:

```swift
@Observable
final class AppContext {
    let sdk: SDKClient
    let sync: SyncState
    let theme: ThemeManager
    let keybinds: KeybindManager
    let dialogs: DialogManager
    let frecency: FrecencyStore
    let history: PromptHistory
    
    init() {
        self.sdk = SDKClient()
        self.sync = SyncState()
        // ... wire up dependencies
    }
}

// Use environment injection
struct TUIApp: View {
    var body: some View {
        ContentView()
            .environment(appContext.theme)
            .environment(appContext.sync)
            // ...
    }
}
```

### 2. **Event Bus Pattern**

```swift
actor EventBus {
    typealias Handler = @Sendable (any TUIEvent) async -> Void
    private var handlers: [String: [Handler]] = [:]
    
    func subscribe<E: TUIEvent>(to eventType: E.Type, handler: @escaping (E) async -> Void) {
        handlers[String(describing: E.self), default: []].append { event in
            if let e = event as? E {
                await handler(e)
            }
        }
    }
    
    func publish(_ event: any TUIEvent) async {
        let key = String(describing: type(of: event))
        for handler in handlers[key, default: []] {
            await handler(event)
        }
    }
}

protocol TUIEvent: Sendable {}
struct PromptAppendEvent: TUIEvent { let text: String }
struct ToastShowEvent: TUIEvent { let message: String; let variant: ToastVariant }
```

### 3. **Persistent State with Self-Healing**

```swift
actor PersistentJSONLStore<T: Codable> {
    let fileURL: URL
    let maxEntries: Int
    private var entries: [T] = []
    
    init(filename: String, maxEntries: Int = 50) {
        self.fileURL = Global.statePath.appending(path: filename)
        self.maxEntries = maxEntries
    }
    
    func load() async throws {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        entries = content.split(separator: "\n").compactMap { line in
            try? JSONDecoder().decode(T.self, from: Data(line.utf8))
        }
        
        // Self-heal by rewriting valid entries
        if !entries.isEmpty {
            try await save()
        }
    }
    
    func append(_ entry: T) async throws {
        entries.append(entry)
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
            try await save()
        } else {
            let line = try JSONEncoder().encode(entry)
            try (String(data: line, encoding: .utf8)! + "\n").append(to: fileURL)
        }
    }
    
    private func save() async throws {
        let content = entries.map { try! JSONEncoder().encode($0) }
            .map { String(data: $0, encoding: .utf8)! }
            .joined(separator: "\n") + "\n"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
```

### 4. **Fuzzy Matching**

```swift
extension String {
    func fuzzyMatch(_ query: String) -> (matches: Bool, score: Double) {
        guard !query.isEmpty else { return (true, 1.0) }
        
        var queryIndex = query.startIndex
        var score = 0.0
        var consecutiveBonus = 0.0
        var previousMatchIndex: String.Index?
        
        for (selfIndex, char) in self.enumerated().lazy {
            if queryIndex < query.endIndex && char.lowercased() == query[queryIndex].lowercased() {
                score += 1.0
                
                // Consecutive match bonus
                if let prev = previousMatchIndex, self.distance(from: prev, to: self.index(self.startIndex, offsetBy: selfIndex)) == 1 {
                    consecutiveBonus += 0.5
                }
                
                // Prefix match bonus
                if selfIndex == 0 {
                    score += 2.0
                }
                
                previousMatchIndex = self.index(self.startIndex, offsetBy: selfIndex)
                queryIndex = query.index(after: queryIndex)
            }
        }
        
        let matches = queryIndex == query.endIndex
        return (matches, matches ? (score + consecutiveBonus) / Double(self.count) : 0)
    }
}
```

---

## Summary

OpenCode's TUI achieves its premium feel through:

1. **Performance**: 60 FPS rendering with dirty-checking
2. **Reactivity**: Fine-grained Solid.js updates, no unnecessary re-renders
3. **Features**: Deep integration of autocomplete, history, stashing, frecency
4. **Polish**: Micro-animations (Knight Rider spinner), toasts, contextual tips
5. **Theming**: 31 themes with proper semantic colors and syntax highlighting
6. **Keyboard-First**: Vim-like bindings with leader key support
7. **State Sync**: Real-time SSE updates with proper persistence

To replicate in Swift:

1. Use **Swift Observation** (`@Observable`) for reactivity
2. Implement a **Flexbox-like layout engine** 
3. Build a **component system** with protocols and result builders
4. Create **async event streams** for server communication
5. Persist state using **self-healing JSONL stores**
6. Design a **theme system** with JSON-based definitions
7. Implement **fuzzy matching with frecency scoring**

The key insight is that a polished TUI requires the same attention to detail as a graphical UI—animations, state management, theming, and keyboard ergonomics all contribute to the premium feel.
