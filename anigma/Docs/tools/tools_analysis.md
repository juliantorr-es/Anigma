# OpenCode Tool System Architecture

A comprehensive analysis of how OpenCode handles tool usage by agents and subagents, with Swift implementation guidance.

---

## Table of Contents

1. [Tool System Overview](#tool-system-overview)
2. [Core Tool Interface](#core-tool-interface)
3. [Tool Registry](#tool-registry)
4. [Built-in Tools](#built-in-tools)
5. [Permission System](#permission-system)
6. [Subagent & Task Tool](#subagent--task-tool)
7. [Tool Execution Flow](#tool-execution-flow)
8. [MCP Integration](#mcp-integration)
9. [Custom Tools & Plugins](#custom-tools--plugins)
10. [Swift Implementation](#swift-implementation)

---

## Tool System Overview

OpenCode's tool system is built on three pillars:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Tool Registry                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │ Built-in    │  │ Custom      │  │ MCP         │  │ Plugin     │ │
│  │ Tools (15+) │  │ .opencode/  │  │ Servers     │  │ Tools      │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       Permission System                              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Agent.permission → Session.permission → Runtime approval    │   │
│  │ (Rulesets)        (Overrides)          (ask/allow/deny)    │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       Execution Context                              │
│  sessionID, messageID, abort signal, metadata updater, ask()        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Core Tool Interface

### Tool Definition (`tool.ts`)

```typescript
export namespace Tool {
  // Context passed to every tool execution
  export type Context = {
    sessionID: string
    messageID: string
    agent: string
    abort: AbortSignal
    callID?: string
    extra?: Record<string, any>
    
    // Update UI metadata during execution
    metadata(input: { title?: string; metadata?: any }): void
    
    // Request permission from user
    ask(input: {
      permission: string
      patterns: string[]
      always: string[]        // Patterns for "always allow"
      metadata: Record<string, any>
    }): Promise<void>
  }

  // Tool information schema
  export interface Info<Parameters extends z.ZodType, Metadata = any> {
    id: string
    init: (ctx?: InitContext) => Promise<{
      description: string
      parameters: Parameters
      execute(
        args: z.infer<Parameters>,
        ctx: Context,
      ): Promise<{
        title: string
        metadata: Metadata
        output: string
        attachments?: FilePart[]
      }>
      formatValidationError?(error: z.ZodError): string
    }>
  }

  // Helper to define tools with automatic validation and truncation
  export function define<P extends z.ZodType, M>(
    id: string,
    init: Info<P, M>["init"] | Awaited<ReturnType<Info<P, M>["init"]>>
  ): Info<P, M>
}
```

### Key Design Decisions

1. **Deferred Initialization**: Tools use `init()` for lazy loading, allowing agent-specific customization
2. **Automatic Validation**: Zod schemas validate inputs; custom `formatValidationError` for better messages
3. **Automatic Truncation**: Large outputs are saved to disk, truncated with hints for further reading
4. **Permission Integration**: Every tool can call `ctx.ask()` to request user approval

---

## Tool Registry

### Registry Pattern (`registry.ts`)

```typescript
export namespace ToolRegistry {
  // Instance-scoped state for custom tools
  const state = Instance.state(async () => {
    const custom: Tool.Info[] = []
    
    // Load from .opencode/tool/*.{js,ts}
    const glob = new Bun.Glob("tool/*.{js,ts}")
    for (const dir of await Config.directories()) {
      for await (const match of glob.scan({ cwd: dir })) {
        const mod = await import(match)
        for (const [id, def] of Object.entries(mod)) {
          custom.push(fromPlugin(id, def))
        }
      }
    }
    
    // Load from plugins
    const plugins = await Plugin.list()
    for (const plugin of plugins) {
      for (const [id, def] of Object.entries(plugin.tool ?? {})) {
        custom.push(fromPlugin(id, def))
      }
    }
    
    return { custom }
  })

  // Get all tools for a provider/agent combination
  export async function tools(providerID: string, agent?: Agent.Info) {
    const tools = await all()
    return Promise.all(
      tools
        .filter(t => filterByProvider(t, providerID))
        .map(async t => ({
          id: t.id,
          ...(await t.init({ agent })),
        }))
    )
  }
}
```

### Built-in Tools List

| Tool | Permission | Description |
|------|------------|-------------|
| `bash` | `bash` | Execute shell commands with tree-sitter parsing |
| `read` | `read` | Read file contents with line range support |
| `edit` | `edit` | Search-and-replace with fuzzy matching fallbacks |
| `write` | `edit` | Create new files |
| `glob` | `glob` | Find files by pattern |
| `grep` | `grep` | Search file contents |
| `task` | `task` | Spawn subagent sessions |
| `webfetch` | `webfetch` | HTTP requests |
| `websearch` | `websearch` | Exa web search |
| `codesearch` | `codesearch` | Exa code search |
| `todowrite` | `todowrite` | Update task list |
| `todoread` | `todoread` | Read task list |
| `skill` | `skill` | Load skill instructions |
| `question` | `question` | Ask user questions |
| `batch` | N/A | Parallel tool execution |
| `lsp` | N/A | Language server queries |

---

## Permission System

### Permission Rules (`permission/next.ts`)

```typescript
export namespace PermissionNext {
  // Rule structure
  export const Rule = z.object({
    permission: z.string(),  // Tool or category name
    pattern: z.string(),     // Wildcard pattern (e.g., "git *")
    action: z.enum(["allow", "deny", "ask"]),
  })

  // Evaluate a permission request against rulesets
  export function evaluate(
    permission: string,
    pattern: string,
    ...rulesets: Ruleset[]
  ): Rule {
    const merged = merge(...rulesets)
    // Find last matching rule (later rules override earlier)
    const match = merged.findLast(
      (rule) => 
        Wildcard.match(permission, rule.permission) &&
        Wildcard.match(pattern, rule.pattern)
    )
    return match ?? { action: "ask", permission, pattern: "*" }
  }

  // Ask for permission with Promise-based resolution
  export async function ask(input: {
    permission: string
    patterns: string[]
    always: string[]
    ruleset: Ruleset
    sessionID: string
    tool?: { messageID: string; callID: string }
  }): Promise<void> {
    for (const pattern of input.patterns) {
      const rule = evaluate(pattern, input.ruleset)
      
      if (rule.action === "deny")
        throw new DeniedError(ruleset)
        
      if (rule.action === "ask") {
        // Publish event, wait for user response
        return new Promise((resolve, reject) => {
          pending[id] = { resolve, reject, info: request }
          Bus.publish(Event.Asked, request)
        })
      }
    }
  }
}
```

### Agent Permission Configuration

```typescript
// Default agent with full permissions
const buildAgent: Agent.Info = {
  name: "build",
  permission: [
    { permission: "*", pattern: "*", action: "allow" },
    { permission: "doom_loop", pattern: "*", action: "ask" },
    { permission: "external_directory", pattern: "*", action: "ask" },
    { permission: "read", pattern: "*.env", action: "deny" },
    { permission: "read", pattern: "*.env.*", action: "deny" },
  ]
}

// Explore subagent - read-only
const exploreAgent: Agent.Info = {
  name: "explore",
  permission: [
    { permission: "*", pattern: "*", action: "deny" },
    { permission: "grep", pattern: "*", action: "allow" },
    { permission: "glob", pattern: "*", action: "allow" },
    { permission: "read", pattern: "*", action: "allow" },
    { permission: "bash", pattern: "*", action: "allow" },
  ]
}
```

---

## Subagent & Task Tool

### Task Tool Implementation (`task.ts`)

The `task` tool spawns subagent sessions with their own message history:

```typescript
export const TaskTool = Tool.define("task", async (ctx) => {
  // Filter agents by caller's permissions
  const agents = await Agent.list()
  const accessibleAgents = agents.filter(a => 
    PermissionNext.evaluate("task", a.name, ctx?.agent?.permission).action !== "deny"
  )

  return {
    description: DESCRIPTION.replace("{agents}", formatAgentList(accessibleAgents)),
    parameters: z.object({
      description: z.string(),
      prompt: z.string(),
      subagent_type: z.string(),
      session_id: z.string().optional(),
    }),
    
    async execute(params, ctx) {
      // Request permission (unless bypassed by @ invocation)
      if (!ctx.extra?.bypassAgentCheck) {
        await ctx.ask({
          permission: "task",
          patterns: [params.subagent_type],
          always: ["*"],
        })
      }

      // Create child session
      const session = await Session.create({
        parentID: ctx.sessionID,
        title: params.description,
        // Subagents can't use todowrite or spawn more subagents
        permission: [
          { permission: "todowrite", pattern: "*", action: "deny" },
          { permission: "task", pattern: "*", action: "deny" },
        ],
      })

      // Subscribe to part updates for live metadata
      const unsub = Bus.subscribe(MessageV2.Event.PartUpdated, (evt) => {
        if (evt.part.sessionID !== session.id) return
        ctx.metadata({ title: params.description, metadata: { summary } })
      })

      // Execute subagent prompt
      const result = await SessionPrompt.prompt({
        sessionID: session.id,
        agent: params.subagent_type,
        parts: await resolvePromptParts(params.prompt),
      })
      
      unsub()
      return {
        title: params.description,
        output: result.text + `\n<task_metadata>session_id: ${session.id}</task_metadata>`,
        metadata: { sessionId: session.id },
      }
    },
  }
})
```

### Session Hierarchy

```
Main Session (ses_xxx)
├── User Message: "Fix all tests"
├── Assistant Message
│   └── Tool Call: task { subagent: "general", prompt: "Fix test A" }
│       └── Child Session (ses_yyy, parentID: ses_xxx)
│           ├── User Message: "Fix test A"
│           └── Assistant Message
│               └── Tool Call: edit {...}
└── Tool Call: task { subagent: "general", prompt: "Fix test B" }
    └── Child Session (ses_zzz, parentID: ses_xxx)
```

---

## Tool Execution Flow

### From LLM Response to Execution (`session/prompt.ts`)

```typescript
async function resolveTools(input: {
  agent: Agent.Info
  session: Session.Info
  model: Provider.Model
  processor: SessionProcessor.Info
  bypassAgentCheck: boolean
}) {
  const tools: Record<string, AITool> = {}

  // Create context factory
  const context = (args: any, options: ToolCallOptions): Tool.Context => ({
    sessionID: input.session.id,
    abort: options.abortSignal!,
    messageID: input.processor.message.id,
    callID: options.toolCallId,
    agent: input.agent.name,
    
    async metadata(val) {
      const part = input.processor.partFromToolCall(options.toolCallId)
      if (part?.state.status === "running") {
        await Session.updatePart({ ...part, state: { ...part.state, ...val } })
      }
    },
    
    async ask(req) {
      await PermissionNext.ask({
        ...req,
        sessionID: input.session.id,
        ruleset: PermissionNext.merge(
          input.agent.permission,
          input.session.permission ?? []
        ),
      })
    },
  })

  // Convert registry tools to AI SDK format
  for (const item of await ToolRegistry.tools(model.providerID, agent)) {
    tools[item.id] = tool({
      id: item.id,
      description: item.description,
      inputSchema: jsonSchema(item.parameters),
      async execute(args, options) {
        const ctx = context(args, options)
        await Plugin.trigger("tool.execute.before", { tool: item.id }, { args })
        const result = await item.execute(args, ctx)
        await Plugin.trigger("tool.execute.after", { tool: item.id }, result)
        return result
      },
    })
  }

  // Add MCP tools with permission wrapper
  for (const [key, mcpTool] of Object.entries(await MCP.tools())) {
    mcpTool.execute = async (args, opts) => {
      await ctx.ask({ permission: key, patterns: ["*"], always: ["*"] })
      return originalExecute(args, opts)
    }
    tools[key] = mcpTool
  }

  return tools
}
```

---

## MCP Integration

### MCP Client Management (`mcp/index.ts`)

```typescript
export namespace MCP {
  // Convert MCP tool to AI SDK tool
  async function convertMcpTool(mcpTool: MCPToolDef, client: MCPClient): Promise<Tool> {
    return dynamicTool({
      description: mcpTool.description ?? "",
      inputSchema: jsonSchema({
        type: "object",
        properties: mcpTool.inputSchema.properties,
        additionalProperties: false,
      }),
      execute: async (args) => {
        return client.callTool({
          name: mcpTool.name,
          arguments: args,
        })
      },
    })
  }

  // State management per instance
  const state = Instance.state(async () => {
    const clients: Record<string, MCPClient> = {}
    const status: Record<string, Status> = {}
    
    for (const [key, mcp] of Object.entries(config.mcp ?? {})) {
      if (mcp.enabled === false) {
        status[key] = { status: "disabled" }
        continue
      }
      const result = await create(key, mcp)
      status[key] = result.status
      if (result.mcpClient) clients[key] = result.mcpClient
    }
    
    return { status, clients }
  })

  // Get all tools from connected MCP servers
  export async function tools() {
    const result: Record<string, Tool> = {}
    for (const [name, client] of Object.entries(await clients())) {
      const toolsResult = await client.listTools()
      for (const mcpTool of toolsResult.tools) {
        const sanitizedName = `${name}_${mcpTool.name}`.replace(/[^a-zA-Z0-9_-]/g, "_")
        result[sanitizedName] = await convertMcpTool(mcpTool, client)
      }
    }
    return result
  }
}
```

---

## Custom Tools & Plugins

### Custom Tool Definition (`.opencode/tool/example.ts`)

```typescript
import { z } from "zod"
import type { ToolDefinition } from "@opencode-ai/plugin"

export const myTool: ToolDefinition = {
  args: {
    query: z.string().describe("Search query"),
  },
  description: "Custom search tool",
  async execute(args, ctx) {
    // Custom logic
    return `Results for: ${args.query}`
  },
}
```

### Plugin Hooks

```typescript
export namespace Plugin {
  export async function trigger<Name extends keyof Hooks>(
    name: Name,
    input: Parameters<Hooks[Name]>[0],
    output: Parameters<Hooks[Name]>[1]
  ): Promise<typeof output> {
    for (const hook of await state().then(x => x.hooks)) {
      const fn = hook[name]
      if (fn) await fn(input, output)
    }
    return output
  }
}

// Hook types
interface Hooks {
  "tool.execute.before": (ctx: { tool: string }, data: { args: any }) => void
  "tool.execute.after": (ctx: { tool: string }, result: any) => void
  "experimental.chat.messages.transform": (ctx: {}, data: { messages: any[] }) => void
}
```

---

## Swift Implementation

### Tool Protocol

```swift
// MARK: - Core Tool Protocol

protocol Tool {
    associatedtype Parameters: Codable
    associatedtype Metadata: Codable
    
    static var id: String { get }
    
    func initialize(context: Tool.InitContext?) async throws -> ToolDefinition<Parameters, Metadata>
}

struct ToolDefinition<P: Codable, M: Codable> {
    let description: String
    let parameters: JSONSchema
    let execute: (P, ToolContext) async throws -> ToolResult<M>
    var formatValidationError: ((DecodingError) -> String)?
}

struct ToolResult<M: Codable> {
    let title: String
    let output: String
    let metadata: M
    var attachments: [FilePart]?
}

struct ToolContext {
    let sessionID: String
    let messageID: String
    let agent: String
    let abort: AsyncChannel<Void>
    var callID: String?
    var extra: [String: Any]
    
    func metadata(_ update: ToolMetadataUpdate) async
    func ask(_ request: PermissionRequest) async throws
}
```

### Tool Registry

```swift
// MARK: - Tool Registry

actor ToolRegistry {
    private var builtinTools: [any Tool.Type] = [
        BashTool.self,
        ReadTool.self,
        EditTool.self,
        WriteTool.self,
        GlobTool.self,
        GrepTool.self,
        TaskTool.self,
    ]
    
    private var customTools: [AnyTool] = []
    
    func registerCustom(_ tool: AnyTool) {
        customTools.append(tool)
    }
    
    func tools(for agent: Agent.Info?) async throws -> [ResolvedTool] {
        var result: [ResolvedTool] = []
        
        for toolType in builtinTools {
            let tool = toolType.init()
            let definition = try await tool.initialize(context: .init(agent: agent))
            result.append(ResolvedTool(
                id: toolType.id,
                definition: definition
            ))
        }
        
        result.append(contentsOf: customTools.map { $0.resolved })
        
        return result
    }
}
```

### Permission System

```swift
// MARK: - Permission System

enum PermissionAction: String, Codable {
    case allow, deny, ask
}

struct PermissionRule: Codable {
    let permission: String
    let pattern: String
    let action: PermissionAction
}

actor PermissionManager {
    private var pending: [String: CheckedContinuation<Void, Error>] = [:]
    private var approved: [PermissionRule] = []
    
    func evaluate(
        permission: String,
        pattern: String,
        rulesets: [[PermissionRule]]
    ) -> PermissionRule {
        let merged = rulesets.flatMap { $0 }
        
        // Find last matching rule
        if let match = merged.last(where: { rule in
            Wildcard.match(permission, rule.permission) &&
            Wildcard.match(pattern, rule.pattern)
        }) {
            return match
        }
        
        return PermissionRule(permission: permission, pattern: "*", action: .ask)
    }
    
    func ask(_ request: PermissionRequest, rulesets: [[PermissionRule]]) async throws {
        for pattern in request.patterns {
            let rule = evaluate(
                permission: request.permission,
                pattern: pattern,
                rulesets: rulesets
            )
            
            switch rule.action {
            case .deny:
                throw PermissionDeniedError(rule: rule)
            case .allow:
                continue
            case .ask:
                try await withCheckedThrowingContinuation { continuation in
                    let id = UUID().uuidString
                    pending[id] = continuation
                    EventBus.shared.publish(PermissionAskedEvent(id: id, request: request))
                }
            }
        }
    }
    
    func reply(requestID: String, reply: PermissionReply) {
        guard let continuation = pending.removeValue(forKey: requestID) else { return }
        
        switch reply {
        case .once:
            continuation.resume()
        case .always(let patterns):
            for pattern in patterns {
                approved.append(PermissionRule(
                    permission: request.permission,
                    pattern: pattern,
                    action: .allow
                ))
            }
            continuation.resume()
        case .reject(let message):
            continuation.resume(throwing: PermissionRejectedError(message: message))
        }
    }
}
```

### Bash Tool Example

```swift
// MARK: - Bash Tool

struct BashTool: Tool {
    static let id = "bash"
    
    struct Parameters: Codable {
        let command: String
        let timeout: Int?
        let workdir: String?
        let description: String
    }
    
    struct Metadata: Codable {
        var output: String
        var exit: Int32?
        let description: String
    }
    
    func initialize(context: Tool.InitContext?) async throws -> ToolDefinition<Parameters, Metadata> {
        return ToolDefinition(
            description: """
                Execute a shell command. Use workdir instead of cd.
                Output is truncated after \(Truncate.maxLines) lines.
                """,
            parameters: JSONSchema.object([
                "command": .string(description: "The command to execute"),
                "timeout": .integer(description: "Timeout in milliseconds").optional(),
                "workdir": .string(description: "Working directory").optional(),
                "description": .string(description: "5-10 word description"),
            ]),
            execute: execute
        )
    }
    
    private func execute(_ params: Parameters, _ ctx: ToolContext) async throws -> ToolResult<Metadata> {
        let cwd = params.workdir ?? Instance.directory
        let timeout = params.timeout ?? 120_000
        
        // Parse command for permission patterns
        let patterns = try await parseCommandPatterns(params.command, cwd: cwd)
        
        // Check for external directories
        let externalDirs = patterns.directories.filter { !Instance.directory.contains($0) }
        if !externalDirs.isEmpty {
            try await ctx.ask(PermissionRequest(
                permission: "external_directory",
                patterns: Array(externalDirs),
                always: externalDirs.map { $0 + "*" }
            ))
        }
        
        // Check bash permission
        if !patterns.commands.isEmpty {
            try await ctx.ask(PermissionRequest(
                permission: "bash",
                patterns: Array(patterns.commands),
                always: patterns.prefixes.map { $0 + "*" }
            ))
        }
        
        // Execute
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", params.command]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        var output = ""
        
        // Stream output
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let text = String(data: data, encoding: .utf8) {
                output += text
                Task {
                    await ctx.metadata(ToolMetadataUpdate(
                        metadata: Metadata(output: output.prefix(30_000), description: params.description)
                    ))
                }
            }
        }
        
        try process.run()
        
        // Wait with timeout
        let timeoutTask = Task {
            try await Task.sleep(for: .milliseconds(timeout))
            process.terminate()
            return true
        }
        
        process.waitUntilExit()
        timeoutTask.cancel()
        
        return ToolResult(
            title: params.description,
            output: output,
            metadata: Metadata(
                output: String(output.prefix(30_000)),
                exit: process.terminationStatus,
                description: params.description
            )
        )
    }
}
```

### Task Tool (Subagent)

```swift
// MARK: - Task Tool

struct TaskTool: Tool {
    static let id = "task"
    
    struct Parameters: Codable {
        let description: String
        let prompt: String
        let subagent_type: String
        let session_id: String?
    }
    
    struct Metadata: Codable {
        let sessionId: String
        var summary: [ToolSummary]?
    }
    
    func initialize(context: Tool.InitContext?) async throws -> ToolDefinition<Parameters, Metadata> {
        let agents = try await Agent.list().filter { $0.mode != .primary }
        let accessibleAgents = agents.filter { agent in
            guard let callerPermission = context?.agent?.permission else { return true }
            let rule = PermissionManager.evaluate(
                permission: "task",
                pattern: agent.name,
                rulesets: [callerPermission]
            )
            return rule.action != .deny
        }
        
        return ToolDefinition(
            description: formatDescription(agents: accessibleAgents),
            parameters: JSONSchema.object([
                "description": .string(description: "Short 3-5 word description"),
                "prompt": .string(description: "The task for the agent"),
                "subagent_type": .string(description: "Agent type to use"),
                "session_id": .string(description: "Continue existing session").optional(),
            ]),
            execute: execute
        )
    }
    
    private func execute(_ params: Parameters, _ ctx: ToolContext) async throws -> ToolResult<Metadata> {
        // Request permission
        if ctx.extra["bypassAgentCheck"] as? Bool != true {
            try await ctx.ask(PermissionRequest(
                permission: "task",
                patterns: [params.subagent_type],
                always: ["*"]
            ))
        }
        
        guard let agent = try await Agent.get(params.subagent_type) else {
            throw ToolError.invalidAgent(params.subagent_type)
        }
        
        // Create or resume session
        let session: Session
        if let existingID = params.session_id,
           let existing = try? await Session.get(existingID) {
            session = existing
        } else {
            session = try await Session.create(
                parentID: ctx.sessionID,
                title: "\(params.description) (@\(agent.name) subagent)",
                permission: [
                    PermissionRule(permission: "todowrite", pattern: "*", action: .deny),
                    PermissionRule(permission: "task", pattern: "*", action: .deny),
                ]
            )
        }
        
        // Subscribe to tool updates
        var toolSummary: [ToolSummary] = []
        let subscription = EventBus.shared.subscribe(MessagePartUpdatedEvent.self) { event in
            guard event.part.sessionID == session.id,
                  event.part.type == .tool else { return }
            toolSummary.append(ToolSummary(from: event.part))
            Task {
                await ctx.metadata(ToolMetadataUpdate(
                    title: params.description,
                    metadata: Metadata(sessionId: session.id, summary: toolSummary)
                ))
            }
        }
        defer { subscription.cancel() }
        
        // Execute subagent
        let result = try await SessionPrompt.prompt(
            sessionID: session.id,
            agent: agent.name,
            parts: try await resolvePromptParts(params.prompt)
        )
        
        let text = result.parts.last { $0.type == .text }?.text ?? ""
        
        return ToolResult(
            title: params.description,
            output: """
                \(text)
                
                <task_metadata>
                session_id: \(session.id)
                </task_metadata>
                """,
            metadata: Metadata(sessionId: session.id, summary: toolSummary)
        )
    }
}
```

### Output Truncation

```swift
// MARK: - Output Truncation

enum Truncate {
    static let maxLines = 2000
    static let maxBytes = 50 * 1024
    static let directory = Global.dataPath.appending(path: "tool-output")
    
    enum Result {
        case full(String)
        case truncated(content: String, path: URL)
    }
    
    static func output(
        _ text: String,
        direction: Direction = .head,
        agent: Agent.Info? = nil
    ) async throws -> Result {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let totalBytes = text.utf8.count
        
        if lines.count <= maxLines && totalBytes <= maxBytes {
            return .full(text)
        }
        
        var output: [Substring] = []
        var bytes = 0
        
        switch direction {
        case .head:
            for line in lines.prefix(maxLines) {
                let size = line.utf8.count + (output.isEmpty ? 0 : 1)
                if bytes + size > maxBytes { break }
                output.append(line)
                bytes += size
            }
        case .tail:
            for line in lines.suffix(maxLines).reversed() {
                let size = line.utf8.count + (output.isEmpty ? 0 : 1)
                if bytes + size > maxBytes { break }
                output.insert(line, at: 0)
                bytes += size
            }
        }
        
        // Save full output
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = Identifier.ascending("tool")
        let filepath = directory.appending(path: id)
        try text.write(to: filepath, atomically: true, encoding: .utf8)
        
        let hint = hasTaskTool(agent)
            ? "Use the Task tool to have a subagent process this file."
            : "Use Grep to search or Read with offset/limit."
        
        let preview = output.joined(separator: "\n")
        let removed = lines.count - output.count
        let message = "\(preview)\n\n...\(removed) lines truncated...\n\n\(hint)"
        
        return .truncated(content: message, path: filepath)
    }
}
```

---

## Summary

OpenCode's tool system excels through:

1. **Unified Interface**: All tools (built-in, custom, MCP) share the same `Tool.Info` contract
2. **Permission-First**: Every tool action goes through `ctx.ask()` with pattern-based rules
3. **Live Metadata**: Tools update UI in real-time via `ctx.metadata()`
4. **Subagent Hierarchy**: `task` tool creates child sessions with restricted permissions
5. **Automatic Truncation**: Large outputs are saved to disk with hints for navigation
6. **Plugin Hooks**: `tool.execute.before/after` for cross-cutting concerns
7. **MCP Integration**: External tools wrapped with permission checks

For Swift implementation:

1. Use **protocols with associated types** for type-safe tool definitions
2. Use **actors** for tool registry and permission state
3. Use **async/await with CheckedContinuation** for permission approval flow
4. Use **structured concurrency** for timeout handling
5. Use **EventBus** for real-time metadata updates
