# OpenCode TUI Architecture - Comprehensive Analysis

> **Generated:** 2026-01-11  
> **Repository:** anomalyco/opencode  
> **Version:** 1.1.8

---

## Executive Summary

**OpenCode** is an open-source AI coding agent that uses a sophisticated **Terminal User Interface (TUI)** built on **custom rendering technology**. The TUI is driven by a **client-server architecture** where Solid.js-based components render to the terminal through a custom rendering engine called **OpenTUI**.

---

## Table of Contents

1. [Core TUI Rendering Technology](#1-core-tui-rendering-technology)
2. [Client-Server Architecture](#2-client-server-architecture)
3. [State Management Architecture](#3-state-management-architecture)
4. [Routing & Views](#4-routing--views)
5. [Event-Driven Architecture](#5-event-driven-architecture)
6. [Component Architecture](#6-component-architecture)
7. [Theming System](#7-theming-system)
8. [Agent System](#8-agent-system)
9. [Tool System](#9-tool-system)
10. [Server Architecture](#10-server-architecture)
11. [Technical Highlights](#11-technical-highlights)

---

## 1. Core TUI Rendering Technology

### 1.1 OpenTUI Framework (`@opentui/solid`)

OpenCode uses a **custom TUI framework** split into two packages:

| Package | Purpose |
|---------|---------|
| `@opentui/core` (v0.1.72) | Low-level rendering primitives, layout engine, text attributes, RGBA colors, syntax highlighting |
| `@opentui/solid` (v0.1.72) | Solid.js JSX integration layer providing React-like component model for terminal UI |

**Key features:**
- **JSX-based declarative UI** - Write terminal UI using familiar component patterns
- **60 FPS rendering target** - High performance terminal rendering
- **Flexbox layout** - CSS Flexbox-like layout engine (`flexDirection`, `gap`, `alignItems`, etc.)
- **Kitty keyboard protocol** - Enhanced keyboard input handling
- **Mouse support** - Click events, selection, copy functionality
- **Text selection & clipboard** - OSC52 escape sequences for clipboard integration

```tsx
// Example from app.tsx - Solid.js components render to terminal
render(
  () => (
    <ErrorBoundary>
      <ArgsProvider>
        <RouteProvider>
          <SDKProvider url={input.url}>
            <SyncProvider>
              <ThemeProvider mode={mode}>
                <App />
              </ThemeProvider>
            </SyncProvider>
          </SDKProvider>
        </RouteProvider>
      </ArgsProvider>
    </ErrorBoundary>
  ),
  {
    targetFps: 60,
    exitOnCtrlC: false,
    useKittyKeyboard: {},
  }
)
```

### 1.2 Component Primitives

The framework provides terminal-specific JSX components:

| Component | Description |
|-----------|-------------|
| `<box>` | Container with flexbox layout, borders, padding |
| `<text>` | Text rendering with colors and attributes |
| `<textarea>` | Multi-line editable text input with extmarks |
| `<scrollbox>` | Scrollable container |

### 1.3 Key Hooks from `@opentui/solid`

```typescript
import { 
  render,           // Mount Solid app to terminal
  useKeyboard,      // Keyboard event handler
  useRenderer,      // Access to renderer APIs
  useTerminalDimensions  // Reactive terminal size
} from "@opentui/solid"
```

---

## 2. Client-Server Architecture

### 2.1 Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Main Process                             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                      TUI Thread                              ││
│  │  • Solid.js Components (App, Session, Prompt, etc.)         ││
│  │  • OpenTUI Renderer                                          ││
│  │  • User Input Handling                                       ││
│  │  • SDK Client (HTTP/RPC)                                     ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│                         RPC/HTTP                                 │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                     Worker Thread                            ││
│  │  • Hono HTTP Server                                          ││
│  │  • Session Management                                        ││
│  │  • LLM Integration (AI SDK)                                  ││
│  │  • Tool Execution                                            ││
│  │  • Bus Event System                                          ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Worker Thread (`worker.ts`)

The **Worker Thread** runs the backend server in a separate Bun Worker:

```typescript
// worker.ts - Exposes RPC methods to the main thread
export const rpc = {
  async fetch(input) { /* Forward HTTP requests to Hono server */ },
  async server(input) { /* Start HTTP server for external access */ },
  async subscribe(input) { /* Subscribe to events from Instance */ },
  async shutdown() { /* Clean shutdown */ },
}
```

### 2.3 Communication Modes

The TUI supports **two communication modes**:

1. **Direct RPC** (default) - For local-only usage, no HTTP server:
   ```typescript
   // Communication goes through Bun Worker postMessage
   customFetch = createWorkerFetch(client)
   events = createEventSource(client)
   ```

2. **HTTP Server** - For remote access or desktop app:
   ```typescript
   const server = await client.call("server", { port, hostname })
   ```

### 2.4 Thread Initialization Flow

```
opencode (CLI)
    ↓
TuiThreadCommand (thread.ts)
    ↓
new Worker(workerPath)  // Spawn worker thread
    ↓
client.call("subscribe", { directory })  // Initialize instance
    ↓
tui({ url, fetch, events })  // Start TUI render loop
    ↓
render(<App />)  // Mount Solid.js app to terminal
```

---

## 3. State Management Architecture

### 3.1 Context Provider Hierarchy

The TUI uses a **deep provider tree** for dependency injection, built using a `createSimpleContext` helper:

```tsx
// Provider nesting from app.tsx (outermost to innermost)
<ArgsProvider>           // CLI arguments
  <ExitProvider>         // Exit handling
    <KVProvider>         // Local key-value storage
      <ToastProvider>    // Notification toasts
        <RouteProvider>  // Client-side routing
          <SDKProvider>  // API client + SSE events
            <SyncProvider>  // Reactive data synchronization
              <ThemeProvider>  // Theme colors + syntax highlighting
                <LocalProvider>  // Local UI state (model, agent)
                  <KeybindProvider>  // Keyboard shortcuts
                    <PromptStashProvider>  // Prompt draft storage
                      <DialogProvider>  // Modal dialogs
                        <CommandProvider>  // Command palette
                          <FrecencyProvider>  // Frecency-based sorting
                            <PromptHistoryProvider>  // Input history
                              <PromptRefProvider>  // Prompt focus ref
                                <App />
                              </PromptRefProvider>
                            </PromptHistoryProvider>
                          </FrecencyProvider>
                        </CommandProvider>
                      </DialogProvider>
                    </PromptStashProvider>
                  </KeybindProvider>
                </LocalProvider>
              </ThemeProvider>
            </SyncProvider>
          </SDKProvider>
        </RouteProvider>
      </ToastProvider>
    </KVProvider>
  </ExitProvider>
</ArgsProvider>
```

### 3.2 Key Contexts

| Context | File | Purpose |
|---------|------|---------|
| **SDKProvider** | `context/sdk.tsx` | Creates OpenCode client, manages SSE event subscription |
| **SyncProvider** | `context/sync.tsx` | Reactive store synchronization - sessions, messages, parts, permissions |
| **LocalProvider** | `context/local.tsx` | Local UI state - selected model, agent, variants |
| **ThemeProvider** | `context/theme.tsx` | Theme resolution, syntax highlighting styles |
| **RouteProvider** | `context/route.tsx` | Client-side navigation (home, session) |
| **CommandProvider** | `component/dialog-command.tsx` | Command palette registration and execution |
| **KeybindProvider** | `context/keybind.tsx` | Keyboard shortcut matching |
| **KVProvider** | `context/kv.tsx` | Persistent key-value storage |

### 3.3 Sync Provider - Real-time Data Store

The `SyncProvider` maintains a **reactive Solid.js store** that mirrors server state:

```typescript
const [store, setStore] = createStore<{
  status: "loading" | "partial" | "complete"
  provider: Provider[]
  provider_default: Record<string, string>
  provider_auth: Record<string, ProviderAuthMethod[]>
  agent: Agent[]
  command: Command[]
  session: Session[]
  session_status: Record<string, SessionStatus>
  session_diff: Record<string, Snapshot.FileDiff[]>
  message: Record<string, Message[]>
  part: Record<string, Part[]>
  permission: Record<string, PermissionRequest[]>
  question: Record<string, QuestionRequest[]>
  todo: Record<string, Todo[]>
  lsp: LspStatus[]
  mcp: Record<string, McpStatus>
  mcp_resource: Record<string, McpResource>
  formatter: FormatterStatus[]
  config: Config
  vcs: VcsInfo | undefined
  path: Path
}>()
```

Events from the server update this store reactively:

```typescript
sdk.event.listen((e) => {
  switch (event.type) {
    case "session.updated":
      setStore("session", result.index, reconcile(event.properties.info))
      break
    case "message.part.updated":
      setStore("part", part.messageID, result.index, reconcile(part))
      break
    case "permission.asked":
      setStore("permission", sessionID, produce((draft) => {
        draft.splice(match.index, 0, request)
      }))
      break
    // ... 20+ event types handled
  }
})
```

### 3.4 Context Helper Pattern

```typescript
// context/helper.tsx - Factory for creating contexts
export function createSimpleContext<T, Props>({ name, init }) {
  const ctx = createContext<T>()
  
  return {
    provider: (props: ParentProps<Props>) => {
      const value = init(props)
      return (
        <Show when={value.ready === undefined || value.ready === true}>
          <ctx.Provider value={value}>{props.children}</ctx.Provider>
        </Show>
      )
    },
    use() {
      const value = useContext(ctx)
      if (!value) throw new Error(`${name} context must be used within provider`)
      return value
    },
  }
}
```

---

## 4. Routing & Views

### 4.1 Route Types

```typescript
// context/route.tsx
type Route = HomeRoute | SessionRoute

type HomeRoute = { 
  type: "home"
  initialPrompt?: PromptInfo 
}

type SessionRoute = { 
  type: "session"
  sessionID: string
  initialPrompt?: PromptInfo 
}
```

### 4.2 Route Navigation

```typescript
const route = useRoute()

// Navigate to session
route.navigate({ type: "session", sessionID: "01HXYZ..." })

// Navigate home
route.navigate({ type: "home" })

// Navigate with preserved prompt
route.navigate({ 
  type: "home", 
  initialPrompt: { input: "Draft text", parts: [] } 
})
```

### 4.3 View Structure

**Home View (`routes/home.tsx`)**:
```
┌─────────────────────────────────────────┐
│                                         │
│              ╔═══════════╗              │
│              ║  OPENCODE ║              │
│              ╚═══════════╝              │
│                                         │
│   ┌─────────────────────────────────┐   │
│   │ Ask anything... "Fix a TODO..." │   │
│   └─────────────────────────────────┘   │
│                                         │
│   • 3 MCP servers  /status              │
│                                         │
├─────────────────────────────────────────┤
│ /path/to/project              v1.1.8    │
└─────────────────────────────────────────┘
```

**Session View (`routes/session/index.tsx`)** - 1898 lines:
```
┌─────────────────────────────────────────┬───────────────┐
│ Session Title          claude-sonnet    │ Todo List     │
├─────────────────────────────────────────┤ ☐ Fix bug     │
│ User: Fix the login bug                 │ ☐ Add tests   │
│                                         │               │
│ Assistant: I'll help you fix that...    │ Diff Preview  │
│ ├ Read src/auth.ts                      │ + line added  │
│ ├ Edit src/auth.ts                      │ - line removed│
│ └ ✓ Changes applied                     │               │
│                                         │               │
│ [scrollable message area]               │               │
│                                         │               │
├─────────────────────────────────────────┴───────────────┤
│ ┃ > Enter your next message...                          │
├─────────────────────────────────────────────────────────┤
│ ctrl+x for commands  esc to cancel  enter to send       │
└─────────────────────────────────────────────────────────┘
```

---

## 5. Event-Driven Architecture

### 5.1 Bus System

OpenCode uses a **pub/sub event bus** for internal communication:

```typescript
// bus/index.ts
export namespace Bus {
  export async function publish<Definition>(def, properties) {
    const payload = { type: def.type, properties }
    
    // Notify local subscribers
    for (const sub of subscriptions.get(def.type) ?? []) {
      sub(payload)
    }
    
    // Forward to GlobalBus for cross-instance events
    GlobalBus.emit("event", { directory: Instance.directory, payload })
  }
  
  export function subscribe<Definition>(def, callback) {
    subscriptions.get(def.type)?.push(callback)
    return () => { /* unsubscribe */ }
  }
  
  export function subscribeAll(callback) {
    return raw("*", callback)
  }
}
```

### 5.2 Event Flow

```
User Input (TUI) 
    ↓
SDK Client (HTTP request or RPC call)
    ↓
Server Handler (Hono route)
    ↓
Session/Tool Processing
    ↓
Bus.publish(event)
    ↓
GlobalBus.emit("event", ...)
    ↓
SSE stream / RPC emit
    ↓
SyncProvider.listen()
    ↓
Store Update (setStore + reconcile)
    ↓
Solid.js Reactivity
    ↓
UI Re-render
```

### 5.3 Server-Sent Events (SSE)

Real-time updates use SSE:

```typescript
// server.ts - SSE endpoint
.get("/global/event", async (c) => {
  return streamSSE(c, async (stream) => {
    // Send initial connected event
    stream.writeSSE({
      data: JSON.stringify({
        payload: { type: "server.connected", properties: {} }
      })
    })
    
    // Subscribe to all events
    const handler = (event) => {
      stream.writeSSE({ data: JSON.stringify({ payload: event.payload }) })
    }
    GlobalBus.on("event", handler)
    
    // Heartbeat every 30s
    const heartbeat = setInterval(() => {
      stream.writeSSE({ data: JSON.stringify({ heartbeat: true }) })
    }, 30_000)
    
    // Cleanup on disconnect
    stream.onAborted(() => {
      clearInterval(heartbeat)
      GlobalBus.off("event", handler)
    })
  })
})
```

### 5.4 Event Types

Key event types handled by `SyncProvider`:

| Event Type | Description |
|------------|-------------|
| `session.updated` | Session metadata changed |
| `session.deleted` | Session removed |
| `session.status` | Session working/idle state |
| `session.diff` | File changes in session |
| `message.updated` | New or updated message |
| `message.removed` | Message deleted |
| `message.part.updated` | New/updated part (text, tool, reasoning) |
| `message.part.removed` | Part deleted |
| `permission.asked` | Permission request from tool |
| `permission.replied` | Permission response |
| `question.asked` | Question request from agent |
| `todo.updated` | Todo list changed |
| `lsp.updated` | LSP server status changed |
| `vcs.branch.updated` | Git branch changed |

---

## 6. Component Architecture

### 6.1 Prompt Component (`component/prompt/index.tsx`)

The most complex component (~1085 lines):

**Features:**
- Multi-line textarea with cursor control
- **Extmarks** - Virtual text overlays for file/agent references
- **Autocomplete** - File paths, agents, commands, MCP resources
- **History** - Up/down navigation through past prompts
- **Stash** - Save drafts for later
- **Image paste** - OSC52 clipboard images
- **Shell mode** - Direct bash command execution

```typescript
export type PromptRef = {
  focused: boolean
  current: PromptInfo
  set(prompt: PromptInfo): void
  reset(): void
  blur(): void
  focus(): void
  submit(): void
}

export type PromptInfo = {
  input: string
  parts: (FilePart | AgentPart | TextPart)[]
  mode?: "normal" | "shell"
}
```

**Prompt submission flow:**

```typescript
async function submit() {
  if (props.disabled) return
  if (!store.prompt.input) return
  
  const sessionID = props.sessionID ?? await sdk.client.session.create({})
  
  if (store.mode === "shell") {
    sdk.client.session.shell({ sessionID, command: inputText })
  } else if (inputText.startsWith("/")) {
    sdk.client.session.command({ sessionID, command: ..., arguments: ... })
  } else {
    sdk.client.session.prompt({
      sessionID,
      model: selectedModel,
      agent: local.agent.current().name,
      variant: local.model.variant.current(),
      parts: [{ type: "text", text: inputText }, ...fileParts],
    })
  }
  
  history.append(store.prompt)
  input.clear()
}
```

### 6.2 Dialog System

Modal dialogs use a **stack-based approach**:

```typescript
// ui/dialog.tsx
function init() {
  const [store, setStore] = createStore({
    stack: [] as { element: JSX.Element; onClose?: () => void }[],
    size: "medium" as "medium" | "large",
  })

  return {
    clear() {
      for (const item of store.stack) item.onClose?.()
      setStore("stack", [])
    },
    replace(element, onClose?) {
      setStore("stack", [{ element, onClose }])
    },
    get stack() { return store.stack },
  }
}

// Usage
dialog.replace(() => <DialogModel />)
dialog.replace(() => <DialogSessionList />)
dialog.clear()
```

**Available dialogs:**
- `DialogModel` - Model selection
- `DialogAgent` - Agent selection
- `DialogMcp` - MCP server toggles
- `DialogSessionList` - Session browser
- `DialogSessionRename` - Rename session
- `DialogStatus` - System status
- `DialogThemeList` - Theme picker
- `DialogHelp` - Keyboard shortcuts
- `DialogProvider` - Provider connection
- `DialogTimeline` - Message timeline
- `DialogForkFromTimeline` - Fork session from message
- `DialogConfirm` - Confirmation prompt
- `DialogAlert` - Alert message
- `DialogPrompt` - Text input
- `DialogExportOptions` - Export settings
- `DialogStash` - Stashed prompts

### 6.3 Command Palette

Commands are registered via hooks with support for keybinds:

```typescript
const command = useCommandDialog()

command.register(() => [
  {
    title: "Switch model",
    value: "model.list",
    keybind: "model_list",
    category: "Agent",
    suggested: true,
    onSelect: () => dialog.replace(() => <DialogModel />),
  },
  {
    title: "New session",
    value: "session.new",
    keybind: "session_new",
    category: "Session",
    onSelect: () => route.navigate({ type: "home" }),
  },
  {
    title: "Toggle thinking",
    value: "session.toggle.thinking",
    category: "Session",
    onSelect: (dialog) => {
      setShowThinking((prev) => !prev)
      dialog.clear()
    },
  },
  // ... 50+ commands
])
```

**Command categories:**
- Session
- Agent
- Provider
- Prompt
- System

### 6.4 Message Parts Rendering

Messages contain typed parts rendered conditionally:

```typescript
// Simplified from session/index.tsx
<For each={parts}>
  {(part) => (
    <Switch>
      <Match when={part.type === "text"}>
        <MarkdownText text={part.text} />
      </Match>
      <Match when={part.type === "reasoning"}>
        <ThinkingBlock content={part.reasoning} />
      </Match>
      <Match when={part.type === "tool"}>
        <ToolBlock tool={part.tool} state={part.state} />
      </Match>
      <Match when={part.type === "step-start"}>
        <StepIndicator step={part.step} />
      </Match>
    </Switch>
  )}
</For>
```

---

## 7. Theming System

### 7.1 Theme Definition

Themes are JSON files with color tokens (`context/theme/*.json`):

```json
{
  "$schema": "...",
  "defs": {
    "orange": "#fab283",
    "bg0": "#0a0a0a",
    "fg0": "#eeeeee"
  },
  "theme": {
    "primary": "orange",
    "secondary": "#e37ecb",
    "accent": "orange",
    "error": "#f47067",
    "warning": "#e8b73c",
    "success": "#8ddb8c",
    "info": "#6cb6ff",
    "text": "fg0",
    "textMuted": "#808080",
    "background": "bg0",
    "backgroundPanel": "#141414",
    "backgroundElement": "#1a1a1a",
    "border": "#333333",
    "borderActive": "#555555",
    "diffAdded": "#8ddb8c",
    "diffRemoved": "#f47067",
    "syntaxComment": "#6e7681",
    "syntaxKeyword": "#e37ecb",
    "syntaxFunction": "#dcbdfb",
    "syntaxString": "#a5d6ff",
    "syntaxNumber": "#f2cc60",
    "syntaxType": "#8ddb8c",
    // ... 40+ color tokens
  }
}
```

### 7.2 Built-in Themes (31 themes)

| Theme | Description |
|-------|-------------|
| **opencode** | Default orange theme |
| **aura** | Purple/pink aesthetic |
| **ayu** | Warm yellow tones |
| **catppuccin** | Pastel palette |
| **catppuccin-frappe** | Catppuccin variant |
| **catppuccin-macchiato** | Catppuccin variant |
| **cobalt2** | Blue-focused theme |
| **cursor** | Cursor IDE inspired |
| **dracula** | Classic Dracula |
| **everforest** | Green forest tones |
| **flexoki** | Minimal warm theme |
| **github** | GitHub dark theme |
| **gruvbox** | Retro groove colors |
| **kanagawa** | Japanese wave inspired |
| **material** | Material Design |
| **matrix** | Green terminal style |
| **mercury** | Silver/gray tones |
| **monokai** | Classic Monokai |
| **nightowl** | Night Owl colors |
| **nord** | Arctic blue palette |
| **one-dark** | Atom One Dark |
| **osaka-jade** | Jade green theme |
| **orng** | Bright orange |
| **lucent-orng** | Transparent orange |
| **palenight** | Soft purple night |
| **rosepine** | Rose Pine palette |
| **solarized** | Classic Solarized |
| **synthwave84** | Retro synthwave |
| **tokyonight** | Tokyo Night colors |
| **vesper** | Dark minimal |
| **vercel** | Vercel-inspired |
| **zenburn** | Low-contrast comfort |

### 7.3 Theme Resolution

```typescript
// context/theme.tsx
function resolveTheme(theme: ThemeJson, mode: "dark" | "light"): Theme {
  const defs = theme.defs ?? {}
  
  function resolveColor(c: ColorValue): RGBA {
    if (c instanceof RGBA) return c
    if (typeof c === "string") {
      if (c === "transparent") return RGBA.fromInts(0, 0, 0, 0)
      if (c.startsWith("#")) return RGBA.fromHex(c)
      if (defs[c]) return resolveColor(defs[c])
      if (theme.theme[c]) return resolveColor(theme.theme[c])
    }
    // Handle light/dark variants
    return resolveColor(c[mode])
  }
  
  return Object.fromEntries(
    Object.entries(theme.theme).map(([key, value]) => [key, resolveColor(value)])
  )
}
```

### 7.4 Syntax Highlighting

Tree-sitter parsers generate syntax tokens mapped to theme colors:

```typescript
function generateSyntax(theme: Theme) {
  return SyntaxStyle.fromTheme([
    { scope: ["default"], style: { foreground: theme.text } },
    { scope: ["comment"], style: { foreground: theme.syntaxComment, italic: true } },
    { scope: ["string", "symbol"], style: { foreground: theme.syntaxString } },
    { scope: ["number", "boolean"], style: { foreground: theme.syntaxNumber } },
    { scope: ["keyword"], style: { foreground: theme.syntaxKeyword, italic: true } },
    { scope: ["keyword.type"], style: { foreground: theme.syntaxType, bold: true } },
    { scope: ["function", "constructor"], style: { foreground: theme.syntaxFunction } },
    { scope: ["variable"], style: { foreground: theme.syntaxVariable } },
    { scope: ["operator"], style: { foreground: theme.syntaxOperator } },
    { scope: ["type", "module"], style: { foreground: theme.syntaxType } },
    // ... more scopes
  ])
}
```

### 7.5 Custom Themes

Users can add custom themes in:
- `~/.config/opencode/themes/*.json`
- `.opencode/themes/*.json` (project-local)

### 7.6 System Theme Detection

```typescript
async function getTerminalBackgroundColor(): Promise<"dark" | "light"> {
  return new Promise((resolve) => {
    // Query terminal for background color via escape sequence
    process.stdout.write("\x1b]11;?\x07")
    
    process.stdin.on("data", (data) => {
      const match = data.toString().match(/\x1b]11;([^\x07\x1b]+)/)
      if (match) {
        const luminance = calculateLuminance(parseColor(match[1]))
        resolve(luminance > 0.5 ? "light" : "dark")
      }
    })
    
    setTimeout(() => resolve("dark"), 1000)  // Fallback
  })
}
```

---

## 8. Agent System

### 8.1 Agent Definition

```typescript
// agent/agent.ts
export const Info = z.object({
  name: z.string(),
  description: z.string().optional(),
  mode: z.enum(["subagent", "primary", "all"]),
  native: z.boolean().optional(),
  hidden: z.boolean().optional(),
  topP: z.number().optional(),
  temperature: z.number().optional(),
  color: z.string().optional(),
  permission: PermissionNext.Ruleset,
  model: z.object({
    modelID: z.string(),
    providerID: z.string(),
  }).optional(),
  prompt: z.string().optional(),
  options: z.record(z.string(), z.any()),
  steps: z.number().int().positive().optional(),
})
```

### 8.2 Built-in Agents

| Agent | Mode | Purpose |
|-------|------|---------|
| **build** | primary | Full-access development agent (default) |
| **plan** | primary | Read-only analysis and planning agent |
| **general** | subagent | Multi-step task execution via `@general` |
| **explore** | subagent | Fast codebase exploration via `@explore` |
| **compaction** | hidden | Session summarization (internal) |
| **title** | hidden | Title generation (internal) |
| **summary** | hidden | Message summarization (internal) |

### 8.3 Permission System

Agents have fine-grained tool permissions:

```typescript
// Default permissions for build agent
permission: PermissionNext.fromConfig({
  "*": "allow",
  doom_loop: "ask",
  external_directory: { "*": "ask" },
  question: "allow",
  read: {
    "*": "allow",
    "*.env": "deny",
    "*.env.*": "deny",
    "*.env.example": "allow",
  },
})

// Plan agent has restricted permissions
permission: PermissionNext.fromConfig({
  "*": "allow",
  question: "allow",
  edit: {
    "*": "deny",
    ".opencode/plan/*.md": "allow",
  },
})
```

**Permission actions:**
- `allow` - Always permit
- `deny` - Always block
- `ask` - Prompt user for permission

### 8.4 Custom Agents

Users can define custom agents in `opencode.json`:

```json
{
  "agent": {
    "docs": {
      "description": "Documentation writer",
      "prompt": "You are a technical documentation expert...",
      "permission": {
        "bash": "deny",
        "edit": {
          "*": "deny",
          "docs/**/*.md": "allow"
        }
      }
    }
  }
}
```

---

## 9. Tool System

### 9.1 Available Tools (20 tools)

| Category | Tool | Description |
|----------|------|-------------|
| **File Read** | `read` | Read file contents with line ranges |
| **File Read** | `glob` | Find files by pattern |
| **File Read** | `ls` | List directory contents |
| **File Read** | `grep` | Search file contents |
| **File Write** | `write` | Create new files |
| **File Write** | `edit` | Edit existing files |
| **File Write** | `patch` | Apply unified diffs |
| **File Write** | `multiedit` | Multiple edits in one call |
| **Execution** | `bash` | Run shell commands |
| **Execution** | `batch` | Run multiple bash commands |
| **Search** | `codesearch` | Semantic code search |
| **Search** | `websearch` | Web search |
| **Search** | `webfetch` | Fetch URL content |
| **Agent** | `task` | Dispatch to subagent |
| **Agent** | `question` | Ask user a question |
| **Workflow** | `todoread` | Read todo list |
| **Workflow** | `todowrite` | Update todo list |
| **Workflow** | `skill` | Load skill prompts |
| **LSP** | `lsp` | Get diagnostics, hover info |
| **Invalid** | `invalid` | Error for unknown tools |

### 9.2 Tool Structure

```typescript
// tool/tool.ts
export interface Tool<TInput, TOutput> {
  name: string
  description: string
  parameters: ZodSchema<TInput>
  execute(input: TInput, ctx: ToolContext): Promise<TOutput>
}

export interface ToolContext {
  sessionID: string
  messageID: string
  partID: string
  abort: AbortSignal
  agent: Agent.Info
}
```

### 9.3 Tool Registration

```typescript
// tool/registry.ts
export namespace ToolRegistry {
  export function register<T extends Tool>(tool: T) {
    registry.set(tool.name, tool)
  }
  
  export function get(name: string): Tool | undefined {
    return registry.get(name)
  }
  
  export function list(): Tool[] {
    return Array.from(registry.values())
  }
}
```

### 9.4 Tool Execution Flow

```
LLM Response (tool_use)
    ↓
SessionProcessor.handleToolCall()
    ↓
PermissionNext.check(toolName, input)
    ↓
(if ask) → PermissionPrompt → User decision
    ↓
ToolRegistry.get(toolName)
    ↓
tool.execute(input, context)
    ↓
Bus.publish("message.part.updated", result)
    ↓
TUI renders tool output
```

---

## 10. Server Architecture (`server/server.ts`)

### 10.1 Hono Framework

The backend uses **Hono** web framework (v4) with OpenAPI integration:

```typescript
const app = new Hono()
  // Global endpoints
  .get("/global/health", ...)
  .get("/global/event", ...)  // SSE stream
  .post("/global/dispose", ...)
  
  // Per-directory instance endpoints
  .use("/:directory/*", async (c, next) => {
    return Instance.provide({
      directory: decodeURIComponent(directory),
      init: InstanceBootstrap,
      fn: next,
    })
  })
  
  // Session endpoints
  .post("/:directory/session", ...)           // Create session
  .get("/:directory/session", ...)            // List sessions
  .get("/:directory/session/:sessionID", ...) // Get session
  .post("/:directory/session/:sessionID/prompt", ...)  // Send prompt
  .post("/:directory/session/:sessionID/abort", ...)   // Cancel
  .post("/:directory/session/:sessionID/share", ...)   // Share
  // ... 50+ endpoints
```

### 10.2 OpenAPI Generation

```typescript
.get("/doc", openAPIRouteHandler(app, {
  documentation: {
    info: {
      title: "opencode",
      version: "0.0.3",
    },
    servers: [{ url: "..." }],
  },
}))
```

### 10.3 Instance System

The `Instance` namespace provides **per-project state isolation**:

```typescript
// project/instance.ts
export namespace Instance {
  export async function provide<T>(opts: {
    directory: string
    init: () => Promise<void>
    fn: () => Promise<T>
  }): Promise<T> {
    // Get or create instance for directory
    // Run fn() within instance context
    // Instance.state() accesses per-instance state
  }
  
  export function state<T>(init: () => T, dispose?: (t: T) => Promise<void>) {
    // Create per-instance state with optional cleanup
  }
  
  export async function disposeAll() {
    // Clean up all instances
  }
}
```

### 10.4 Key Server Modules

| Module | File | Purpose |
|--------|------|---------|
| **Session** | `session/index.ts` | Session CRUD |
| **SessionPrompt** | `session/prompt.ts` | Prompt handling & LLM loop |
| **SessionProcessor** | `session/processor.ts` | Tool execution pipeline |
| **MessageV2** | `session/message-v2.ts` | Message/Part storage |
| **Provider** | `provider/provider.ts` | LLM provider management |
| **Agent** | `agent/agent.ts` | Agent configuration |
| **ToolRegistry** | `tool/registry.ts` | Tool management |
| **Bus** | `bus/index.ts` | Event pub/sub |
| **Config** | `config/config.ts` | Configuration loading |
| **LSP** | `lsp/*.ts` | Language server integration |
| **MCP** | `mcp/*.ts` | Model Context Protocol |

---

## 11. Technical Highlights

### 11.1 Performance Optimizations

- **Event batching** - 16ms debounce for SSE events to reduce render thrashing:
  ```typescript
  const flush = () => {
    batch(() => {
      for (const event of queue) {
        emitter.emit(event.type, event)
      }
    })
  }
  
  if (elapsed < 16) {
    timer = setTimeout(flush, 16)
  } else {
    flush()
  }
  ```

- **Binary search** - O(log n) message/part lookup:
  ```typescript
  const result = Binary.search(messages, messageID, (m) => m.id)
  if (result.found) {
    setStore("message", sessionID, result.index, reconcile(newMessage))
  }
  ```

- **Store reconciliation** - Minimal diffing for updates using `solid-js/store`:
  ```typescript
  setStore("session", result.index, reconcile(event.properties.info))
  ```

- **Lazy loading** - Theme/parser loading on demand

### 11.2 Terminal Compatibility

- **TTY detection** - Graceful fallback for non-interactive:
  ```typescript
  if (!process.stdin.isTTY) return "dark"
  ```

- **Background color detection** - Auto light/dark mode via escape sequences

- **OSC52** - Universal clipboard via escape codes:
  ```typescript
  const base64 = Buffer.from(text).toString("base64")
  const osc52 = `\x1b]52;c;${base64}\x07`
  const finalOsc52 = process.env["TMUX"] 
    ? `\x1bPtmux;\x1b${osc52}\x1b\\` 
    : osc52
  renderer.writeOut(finalOsc52)
  ```

- **Kitty keyboard protocol** - Enhanced modifier support

- **TMUX awareness** - Passthrough escape sequences

### 11.3 Developer Experience

- **Hot reload** - SIGUSR2 for config reload:
  ```typescript
  process.on("SIGUSR2", async () => {
    Config.global.reset()
    await Instance.disposeAll()
  })
  ```

- **Debug overlay** - Built-in renderer stats:
  ```typescript
  renderer.toggleDebugOverlay()
  ```

- **Console toggle** - In-app log viewer:
  ```typescript
  renderer.console.toggle()
  ```

- **Heap snapshots** - Memory debugging:
  ```typescript
  const path = writeHeapSnapshot()
  ```

### 11.4 Keyboard Shortcut System

```typescript
// context/keybind.tsx
const DEFAULT_KEYBINDS = {
  "session_list": "ctrl+x l",
  "session_new": "ctrl+x n",
  "model_list": "ctrl+e",
  "agent_cycle": "tab",
  "input_submit": "enter",
  "input_paste": "ctrl+v",
  "messages_copy": "ctrl+x y",
  "editor_open": "ctrl+x e",
  // ... 40+ keybinds
}

// Usage
const keybind = useKeybind()
if (keybind.match("input_submit", event)) {
  submit()
}
```

---

## 12. File Structure Overview

```
packages/opencode/src/
├── cli/
│   ├── cmd/
│   │   ├── tui/
│   │   │   ├── app.tsx           # Main TUI entry point
│   │   │   ├── thread.ts         # Worker thread initialization
│   │   │   ├── worker.ts         # Backend worker
│   │   │   ├── event.ts          # TUI-specific events
│   │   │   ├── context/          # 13 context providers
│   │   │   │   ├── sdk.tsx
│   │   │   │   ├── sync.tsx
│   │   │   │   ├── theme.tsx
│   │   │   │   ├── local.tsx
│   │   │   │   ├── route.tsx
│   │   │   │   ├── keybind.tsx
│   │   │   │   └── ...
│   │   │   ├── component/        # Shared components
│   │   │   │   ├── prompt/
│   │   │   │   ├── dialog-*.tsx
│   │   │   │   └── ...
│   │   │   ├── routes/           # View components
│   │   │   │   ├── home.tsx
│   │   │   │   └── session/
│   │   │   ├── ui/               # UI primitives
│   │   │   │   ├── dialog.tsx
│   │   │   │   ├── toast.tsx
│   │   │   │   └── ...
│   │   │   └── util/             # Utilities
│   │   ├── run.ts                # Non-interactive run command
│   │   └── ...
│   └── ui.ts                     # CLI output utilities
├── server/
│   └── server.ts                 # Hono HTTP server (2894 lines)
├── session/
│   ├── index.ts                  # Session management
│   ├── prompt.ts                 # LLM interaction loop
│   ├── processor.ts              # Tool processing
│   └── ...
├── agent/
│   └── agent.ts                  # Agent definitions
├── tool/
│   ├── registry.ts               # Tool registry
│   ├── bash.ts, edit.ts, ...     # Individual tools
│   └── ...
├── provider/
│   └── provider.ts               # LLM provider abstraction
├── bus/
│   ├── index.ts                  # Event bus
│   └── global.ts                 # Cross-instance events
└── ...
```

---

## Conclusion

OpenCode's TUI architecture is a **sophisticated, production-grade terminal application** that combines:

1. **Custom rendering engine** (OpenTUI) with Solid.js integration for declarative terminal UI
2. **Client-server separation** with Worker threads and SSE for responsive updates
3. **Reactive state management** built on Solid.js stores with fine-grained updates
4. **Comprehensive theming** with 31 built-in themes + custom theme support
5. **Extensible agent/tool system** for AI-powered code manipulation
6. **First-class terminal support** with keyboard, mouse, clipboard integration

The architecture enables OpenCode to run as:
- Standalone TUI application
- Headless CLI tool (`opencode run`)
- Remote server with HTTP API
- Desktop application backend

All sharing the same core backend logic through the client-server abstraction.
