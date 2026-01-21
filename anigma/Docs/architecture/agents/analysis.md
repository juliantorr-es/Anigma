# OpenCode Agents and Subagents Architecture

A comprehensive analysis of how OpenCode manages agents and subagents, their tool usage patterns, and how to implement a similar system in Swift.

---

## Table of Contents

1. [Agent System Overview](#agent-system-overview)
2. [Agent Definition & Configuration](#agent-definition--configuration)
3. [Built-in Agents](#built-in-agents)
4. [Subagent Architecture](#subagent-architecture)
5. [Session-Agent Relationship](#session-agent-relationship)
6. [Tool Resolution Per Agent](#tool-resolution-per-agent)
7. [Permission Inheritance](#permission-inheritance)
8. [Execution Loop & Processing](#execution-loop--processing)
9. [Swift Implementation](#swift-implementation)

---

## Agent System Overview

OpenCode's agent system is hierarchical with three agent modes:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Agent Types                                  │
├─────────────────────────────────────────────────────────────────────┤
│  "primary"   │ Main agents (build, plan) - full tool access         │
│  "subagent"  │ Specialized agents (explore, general) - restricted   │
│  "all"       │ Can be invoked as either primary or subagent         │
└─────────────────────────────────────────────────────────────────────┘

Session Hierarchy:
┌────────────────────────────────────────┐
│ Main Session (primary agent: "build") │
│ ├── User: "Fix all tests"              │
│ ├── Assistant (agent: build)           │
│ │   ├── tool: read                     │
│ │   └── tool: task → Subagent Session  │
│ │       ├── User: "Fix test A"         │
│ │       └── Assistant (agent: general) │
│ │           ├── tool: read             │
│ │           └── tool: edit             │
│ └── tool: task → Subagent Session      │
└────────────────────────────────────────┘
```

---

## Agent Definition & Configuration

### Agent Schema (`agent/agent.ts`)

```typescript
export namespace Agent {
  export const Info = z.object({
    name: z.string(),                          // Unique identifier
    description: z.string().optional(),        // For task tool descriptions
    mode: z.enum(["subagent", "primary", "all"]),
    native: z.boolean().optional(),            // Built-in vs custom
    hidden: z.boolean().optional(),            // Hide from UI
    topP: z.number().optional(),               // LLM sampling
    temperature: z.number().optional(),
    color: z.string().optional(),              // UI color
    permission: PermissionNext.Ruleset,        // Tool access rules
    model: z.object({                          // Override model
      modelID: z.string(),
      providerID: z.string(),
    }).optional(),
    prompt: z.string().optional(),             // Custom system prompt
    options: z.record(z.string(), z.any()),    // Provider options
    steps: z.number().int().positive().optional(), // Max reasoning steps
  })
}
```

### Configuration Loading

```typescript
const state = Instance.state(async () => {
  const cfg = await Config.get()
  
  // Default permission ruleset
  const defaults = PermissionNext.fromConfig({
    "*": "allow",
    doom_loop: "ask",
    external_directory: { "*": "ask" },
    question: "deny",
    read: {
      "*": "allow",
      "*.env": "deny",
      "*.env.*": "deny",
      "*.env.example": "allow",
    },
  })
  
  const result: Record<string, Info> = {
    build: { name: "build", mode: "primary", native: true, ... },
    plan: { name: "plan", mode: "primary", native: true, ... },
    general: { name: "general", mode: "subagent", native: true, ... },
    explore: { name: "explore", mode: "subagent", native: true, ... },
    // Hidden utility agents
    compaction: { name: "compaction", mode: "primary", hidden: true, ... },
    title: { name: "title", mode: "primary", hidden: true, ... },
    summary: { name: "summary", mode: "primary", hidden: true, ... },
  }
  
  // Merge user-defined agents from config
  for (const [key, value] of Object.entries(cfg.agent ?? {})) {
    if (value.disable) { delete result[key]; continue }
    
    let item = result[key] ?? {
      name: key, mode: "all",
      permission: PermissionNext.merge(defaults, user),
      options: {}, native: false,
    }
    
    // Apply overrides
    if (value.model) item.model = Provider.parseModel(value.model)
    item.prompt = value.prompt ?? item.prompt
    item.permission = PermissionNext.merge(
      item.permission, 
      PermissionNext.fromConfig(value.permission ?? {})
    )
    result[key] = item
  }
  
  return result
})
```

---

## Built-in Agents

### Primary Agents

| Agent | Mode | Description | Key Permissions |
|-------|------|-------------|-----------------|
| `build` | primary | Full-featured coding agent | All tools allowed, question enabled |
| `plan` | primary | Planning without code changes | Edit restricted to `.opencode/plan/*.md` |

### Subagents

| Agent | Mode | Description | Key Permissions |
|-------|------|-------------|-----------------|
| `general` | subagent | General-purpose parallel work | No todo access, no further task spawning |
| `explore` | subagent | Fast codebase exploration | Read-only: grep, glob, read, bash |

### Hidden Utility Agents

| Agent | Purpose |
|-------|---------|
| `compaction` | Summarize long conversations |
| `title` | Generate session titles |
| `summary` | Create file change summaries |

### Explore Agent Permissions

```typescript
explore: {
  name: "explore",
  mode: "subagent",
  permission: PermissionNext.merge(
    defaults,
    PermissionNext.fromConfig({
      "*": "deny",              // Deny all by default
      grep: "allow",            // Allow searching
      glob: "allow",            // Allow finding files
      list: "allow",            // Allow listing
      bash: "allow",            // Allow shell (for ls, find, etc.)
      webfetch: "allow",        // Allow web requests
      websearch: "allow",       // Allow web search
      codesearch: "allow",      // Allow code search
      read: "allow",            // Allow reading files
      external_directory: {
        [Truncate.DIR]: "allow", // Allow tool output dir
      },
    }),
  ),
  description: `Fast agent specialized for exploring codebases...`,
  prompt: PROMPT_EXPLORE,
}
```

---

## Subagent Architecture

### Task Tool Flow

```
User: "Fix all failing tests"
         │
         ▼
┌──────────────────────────────────┐
│ Primary Agent (build)            │
│ 1. Reads test output             │
│ 2. Identifies failures           │
│ 3. Calls task tool for each      │
└──────────────────────────────────┘
         │
         ├──── task(subagent: general, prompt: "Fix auth test")
         │         │
         │         ▼
         │    ┌──────────────────────────────────┐
         │    │ Child Session (parentID: main)   │
         │    │ Agent: general                   │
         │    │ Permissions: no todo, no task    │
         │    │                                  │
         │    │ 1. Reads test file               │
         │    │ 2. Reads implementation          │
         │    │ 3. Edits to fix                  │
         │    │ 4. Returns summary               │
         │    └──────────────────────────────────┘
         │
         └──── task(subagent: explore, prompt: "Find all uses of X")
                   │
                   ▼
              ┌──────────────────────────────────┐
              │ Child Session (parentID: main)   │
              │ Agent: explore                   │
              │ Permissions: read-only           │
              │                                  │
              │ 1. grep for X                    │
              │ 2. glob for related files        │
              │ 3. Returns findings              │
              └──────────────────────────────────┘
```

### Task Tool Implementation

```typescript
export const TaskTool = Tool.define("task", async (ctx) => {
  // Filter subagents by caller's permissions
  const agents = await Agent.list()
  const accessibleAgents = agents.filter(a => 
    PermissionNext.evaluate("task", a.name, ctx?.agent?.permission).action !== "deny"
  )

  return {
    parameters: z.object({
      description: z.string().describe("Short 3-5 word description"),
      prompt: z.string().describe("The task for the agent"),
      subagent_type: z.string().describe("Agent type"),
      session_id: z.string().optional(),  // Resume existing
    }),
    
    async execute(params, ctx) {
      // Permission check (unless @ invoked)
      if (!ctx.extra?.bypassAgentCheck) {
        await ctx.ask({
          permission: "task",
          patterns: [params.subagent_type],
          always: ["*"],
        })
      }

      const agent = await Agent.get(params.subagent_type)
      
      // Create child session with restricted permissions
      const session = await Session.create({
        parentID: ctx.sessionID,
        title: `${params.description} (@${agent.name} subagent)`,
        permission: [
          // Subagents cannot use todos or spawn more subagents
          { permission: "todowrite", pattern: "*", action: "deny" },
          { permission: "todoread", pattern: "*", action: "deny" },
          { permission: "task", pattern: "*", action: "deny" },
        ],
      })

      // Inherit model from parent if not specified
      const model = agent.model ?? {
        modelID: parentMessage.modelID,
        providerID: parentMessage.providerID,
      }

      // Subscribe to child's tool calls for live updates
      const unsub = Bus.subscribe(MessageV2.Event.PartUpdated, (evt) => {
        if (evt.part.sessionID !== session.id) return
        if (evt.part.type !== "tool") return
        ctx.metadata({
          title: params.description,
          metadata: { summary: collectToolSummary() },
        })
      })

      // Execute the subagent's prompt
      const result = await SessionPrompt.prompt({
        sessionID: session.id,
        agent: agent.name,
        model,
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

---

## Session-Agent Relationship

### Session Structure

```typescript
export const SessionInfo = z.object({
  id: Identifier.schema("session"),
  projectID: z.string(),
  directory: z.string(),
  parentID: Identifier.schema("session").optional(),  // Link to parent
  title: z.string(),
  version: z.string(),
  permission: PermissionNext.Ruleset.optional(),      // Session-level overrides
  time: z.object({
    created: z.number(),
    updated: z.number(),
  }),
})
```

### Message-Agent Binding

```typescript
export const UserMessage = z.object({
  id: Identifier.schema("message"),
  sessionID: Identifier.schema("session"),
  role: z.literal("user"),
  agent: z.string(),      // Selected agent for this prompt
  model: z.object({       // Selected model
    providerID: z.string(),
    modelID: z.string(),
  }),
})

export const AssistantMessage = z.object({
  id: Identifier.schema("message"),
  sessionID: Identifier.schema("session"),
  role: z.literal("assistant"),
  parentID: Identifier.schema("message"),  // Links to user message
  agent: z.string(),       // Agent that generated this
  mode: z.string(),        // Agent mode snapshot
})
```

### Session Navigation

```typescript
// Get child sessions
export const children = fn(Identifier.schema("session"), async (parentID) => {
  const result: Session.Info[] = []
  for (const item of await Storage.list(["session", project.id])) {
    const session = await Storage.read<Info>(item)
    if (session.parentID === parentID) {
      result.push(session)
    }
  }
  return result
})
```

---

## Tool Resolution Per Agent

### Tool Filtering in Prompt Loop

```typescript
async function resolveTools(input: {
  agent: Agent.Info
  session: Session.Info
  model: Provider.Model
  bypassAgentCheck: boolean
}) {
  const tools: Record<string, AITool> = {}

  // Get tools from registry with agent context
  for (const item of await ToolRegistry.tools(model.providerID, agent)) {
    tools[item.id] = tool({
      id: item.id,
      description: item.description,
      inputSchema: jsonSchema(item.parameters),
      async execute(args, options) {
        const ctx: Tool.Context = {
          sessionID: input.session.id,
          abort: options.abortSignal!,
          messageID: input.processor.message.id,
          agent: input.agent.name,
          extra: { bypassAgentCheck: input.bypassAgentCheck },
          
          // Permission checker merges agent + session rulesets
          async ask(req) {
            await PermissionNext.ask({
              ...req,
              sessionID: input.session.id,
              ruleset: PermissionNext.merge(
                input.agent.permission,      // Agent's base permissions
                input.session.permission ?? [] // Session overrides
              ),
            })
          },
        }
        
        return item.execute(args, ctx)
      },
    })
  }

  return tools
}
```

### Agent-Specific Tool Descriptions

Tools can customize their description based on the calling agent:

```typescript
// task.ts - filters available subagents
export const TaskTool = Tool.define("task", async (ctx) => {
  const agents = await Agent.list()
  const accessibleAgents = ctx?.agent
    ? agents.filter(a => 
        PermissionNext.evaluate("task", a.name, ctx.agent.permission).action !== "deny"
      )
    : agents

  return {
    description: DESCRIPTION.replace(
      "{agents}",
      accessibleAgents.map(a => `- ${a.name}: ${a.description}`).join("\n")
    ),
    // ...
  }
})

// skill.ts - filters accessible skills
export const SkillTool = Tool.define("skill", async (ctx) => {
  const skills = await Skill.all()
  const accessibleSkills = ctx?.agent
    ? skills.filter(s => 
        PermissionNext.evaluate("skill", s.name, ctx.agent.permission).action !== "deny"
      )
    : skills
  // ...
})
```

---

## Permission Inheritance

### Permission Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Permission Resolution                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. Agent.permission (base rules from agent definition)             │
│           │                                                          │
│           ▼                                                          │
│  2. Session.permission (overrides set at session creation)          │
│           │                                                          │
│           ▼                                                          │
│  3. Runtime storage (rules added via "always allow")                │
│           │                                                          │
│           ▼                                                          │
│  4. PermissionNext.evaluate() → allow | deny | ask                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Subagent Permission Restrictions

When a subagent session is created, it receives restricted permissions:

```typescript
const session = await Session.create({
  parentID: ctx.sessionID,
  permission: [
    // Prevent recursive task spawning
    { permission: "task", pattern: "*", action: "deny" },
    // Prevent todo modifications (main agent tracks)
    { permission: "todowrite", pattern: "*", action: "deny" },
    { permission: "todoread", pattern: "*", action: "deny" },
    // Allow primary tools if configured
    ...(config.experimental?.primary_tools?.map(t => ({
      pattern: "*",
      action: "allow" as const,
      permission: t,
    })) ?? []),
  ],
})
```

---

## Execution Loop & Processing

### Main Prompt Loop (`session/prompt.ts`)

```typescript
export const loop = fn(Identifier.schema("session"), async (sessionID) => {
  const abort = start(sessionID)
  let step = 0
  
  while (true) {
    if (abort.aborted) break
    
    const msgs = await MessageV2.filterCompacted(MessageV2.stream(sessionID))
    const lastUser = msgs.findLast(m => m.role === "user")
    const lastAssistant = msgs.findLast(m => m.role === "assistant")
    
    // Check for completion
    if (lastAssistant?.finish && !["tool-calls", "unknown"].includes(lastAssistant.finish)) {
      break
    }
    
    step++
    const agent = await Agent.get(lastUser.agent)
    const maxSteps = agent.steps ?? Infinity
    const isLastStep = step >= maxSteps
    
    // Create processor for this step
    const processor = SessionProcessor.create({
      assistantMessage: await Session.updateMessage({
        role: "assistant",
        agent: agent.name,
        mode: agent.name,
        // ...
      }),
      sessionID,
      model,
      abort,
    })
    
    // Resolve tools for this agent
    const tools = await resolveTools({
      agent,
      session,
      model,
      processor,
      bypassAgentCheck: lastUserMsg.parts.some(p => p.type === "agent"),
    })
    
    // Process with LLM
    const result = await processor.process({
      agent,
      abort,
      sessionID,
      system: [...await SystemPrompt.environment(), ...await SystemPrompt.custom()],
      messages: MessageV2.toModelMessage(msgs),
      tools,
      model,
    })
    
    if (result === "stop") break
    if (result === "compact") {
      await SessionCompaction.create({ sessionID, agent: lastUser.agent, auto: true })
    }
  }
})
```

### Doom Loop Detection

```typescript
// In session/processor.ts
case "tool-call": {
  const parts = await MessageV2.parts(input.assistantMessage.id)
  const lastThree = parts.slice(-DOOM_LOOP_THRESHOLD)
  
  // Detect if same tool called 3+ times with identical args
  if (
    lastThree.length === DOOM_LOOP_THRESHOLD &&
    lastThree.every(p => 
      p.type === "tool" &&
      p.tool === value.toolName &&
      JSON.stringify(p.state.input) === JSON.stringify(value.input)
    )
  ) {
    // Ask for permission to continue
    await PermissionNext.ask({
      permission: "doom_loop",
      patterns: [value.toolName],
      sessionID: input.assistantMessage.sessionID,
      ruleset: agent.permission,
    })
  }
  break
}
```

---

## Swift Implementation

### Agent Protocol and Types

```swift
// MARK: - Agent System

enum AgentMode: String, Codable {
    case primary    // Main agents with full access
    case subagent   // Specialized with restricted access
    case all        // Can be used as either
}

struct Agent: Codable, Identifiable {
    let name: String
    var description: String?
    var mode: AgentMode
    var native: Bool
    var hidden: Bool
    var topP: Double?
    var temperature: Double?
    var color: String?
    var permission: [PermissionRule]
    var model: ModelSelection?
    var prompt: String?
    var options: [String: AnyCodable]
    var steps: Int?
    
    var id: String { name }
}

struct ModelSelection: Codable {
    let providerID: String
    let modelID: String
}
```

### Agent Registry

```swift
// MARK: - Agent Registry

actor AgentRegistry {
    private var agents: [String: Agent] = [:]
    
    static let shared = AgentRegistry()
    
    func initialize() async throws {
        let config = try await Config.load()
        
        // Default permissions
        let defaults: [PermissionRule] = [
            PermissionRule(permission: "*", pattern: "*", action: .allow),
            PermissionRule(permission: "doom_loop", pattern: "*", action: .ask),
            PermissionRule(permission: "external_directory", pattern: "*", action: .ask),
            PermissionRule(permission: "read", pattern: "*.env", action: .deny),
            PermissionRule(permission: "read", pattern: "*.env.*", action: .deny),
        ]
        
        // Built-in agents
        agents = [
            "build": Agent(
                name: "build",
                description: "Full-featured coding agent",
                mode: .primary,
                native: true,
                hidden: false,
                permission: defaults + [
                    PermissionRule(permission: "question", pattern: "*", action: .allow)
                ]
            ),
            "plan": Agent(
                name: "plan",
                description: "Planning agent",
                mode: .primary,
                native: true,
                hidden: false,
                permission: defaults + [
                    PermissionRule(permission: "edit", pattern: "*", action: .deny),
                    PermissionRule(permission: "edit", pattern: ".opencode/plan/*.md", action: .allow),
                ]
            ),
            "explore": Agent(
                name: "explore",
                description: "Fast codebase exploration",
                mode: .subagent,
                native: true,
                hidden: false,
                permission: [
                    PermissionRule(permission: "*", pattern: "*", action: .deny),
                    PermissionRule(permission: "grep", pattern: "*", action: .allow),
                    PermissionRule(permission: "glob", pattern: "*", action: .allow),
                    PermissionRule(permission: "read", pattern: "*", action: .allow),
                    PermissionRule(permission: "bash", pattern: "*", action: .allow),
                ],
                prompt: PROMPT_EXPLORE
            ),
            "general": Agent(
                name: "general",
                description: "General-purpose parallel work",
                mode: .subagent,
                native: true,
                hidden: false,
                permission: defaults + [
                    PermissionRule(permission: "todoread", pattern: "*", action: .deny),
                    PermissionRule(permission: "todowrite", pattern: "*", action: .deny),
                ]
            ),
        ]
        
        // Merge user-defined agents
        for (name, userAgent) in config.agents ?? [:] {
            if userAgent.disabled {
                agents.removeValue(forKey: name)
                continue
            }
            
            if var existing = agents[name] {
                existing.prompt = userAgent.prompt ?? existing.prompt
                existing.model = userAgent.model ?? existing.model
                existing.temperature = userAgent.temperature ?? existing.temperature
                existing.permission += PermissionRule.fromConfig(userAgent.permission ?? [:])
                agents[name] = existing
            } else {
                agents[name] = Agent(
                    name: name,
                    description: userAgent.description,
                    mode: userAgent.mode ?? .all,
                    native: false,
                    hidden: userAgent.hidden ?? false,
                    permission: defaults + PermissionRule.fromConfig(userAgent.permission ?? [:]),
                    prompt: userAgent.prompt
                )
            }
        }
    }
    
    func get(_ name: String) -> Agent? {
        agents[name]
    }
    
    func list() -> [Agent] {
        Array(agents.values).sorted { a, b in
            if a.name == "build" { return true }
            if b.name == "build" { return false }
            return a.name < b.name
        }
    }
    
    func primaryAgents() -> [Agent] {
        list().filter { $0.mode != .subagent && !$0.hidden }
    }
    
    func subagents() -> [Agent] {
        list().filter { $0.mode != .primary && !$0.hidden }
    }
}
```

### Session-Agent Relationship

```swift
// MARK: - Session

struct Session: Codable, Identifiable {
    let id: String
    let projectID: String
    let directory: String
    var parentID: String?           // Link to parent session
    var title: String
    var permission: [PermissionRule]?
    var time: SessionTime
    
    struct SessionTime: Codable {
        var created: Date
        var updated: Date
    }
}

struct UserMessage: Codable {
    let id: String
    let sessionID: String
    let role: String = "user"
    let agent: String               // Selected agent
    let model: ModelSelection
    var parts: [MessagePart]
}

struct AssistantMessage: Codable {
    let id: String
    let sessionID: String
    let role: String = "assistant"
    let parentID: String            // Links to user message
    let agent: String
    let mode: String
    var parts: [MessagePart]
    var finish: String?
    var error: MessageError?
}
```

### Task Tool (Subagent Spawner)

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
        let agents = await AgentRegistry.shared.subagents()
        
        // Filter by caller's permissions
        let accessibleAgents: [Agent]
        if let callerPermission = context?.agent?.permission {
            accessibleAgents = agents.filter { agent in
                let rule = PermissionManager.shared.evaluate(
                    permission: "task",
                    pattern: agent.name,
                    rulesets: [callerPermission]
                )
                return rule.action != .deny
            }
        } else {
            accessibleAgents = agents
        }
        
        let agentList = accessibleAgents
            .map { "- \($0.name): \($0.description ?? "Specialized agent")" }
            .joined(separator: "\n")
        
        return ToolDefinition(
            description: """
                Spawn a subagent to perform a specialized task.
                
                Available agents:
                \(agentList)
                """,
            parameters: taskParameterSchema,
            execute: execute
        )
    }
    
    private func execute(_ params: Parameters, _ ctx: ToolContext) async throws -> ToolResult<Metadata> {
        // Permission check (unless bypassed by @ invocation)
        if ctx.extra["bypassAgentCheck"] as? Bool != true {
            try await ctx.ask(PermissionRequest(
                permission: "task",
                patterns: [params.subagent_type],
                always: ["*"],
                metadata: [
                    "description": params.description,
                    "subagent_type": params.subagent_type,
                ]
            ))
        }
        
        guard let agent = await AgentRegistry.shared.get(params.subagent_type) else {
            throw ToolError.invalidAgent(params.subagent_type)
        }
        
        // Create or resume child session
        let session: Session
        if let existingID = params.session_id,
           let existing = try? await SessionManager.shared.get(existingID) {
            session = existing
        } else {
            session = try await SessionManager.shared.create(
                parentID: ctx.sessionID,
                title: "\(params.description) (@\(agent.name) subagent)",
                permission: [
                    // Subagents cannot spawn more subagents
                    PermissionRule(permission: "task", pattern: "*", action: .deny),
                    // Subagents cannot modify todos
                    PermissionRule(permission: "todowrite", pattern: "*", action: .deny),
                    PermissionRule(permission: "todoread", pattern: "*", action: .deny),
                ]
            )
        }
        
        // Get model (inherit from parent if not specified)
        let model = agent.model ?? try await getParentModel(ctx.sessionID)
        
        // Subscribe to child's tool updates
        var toolSummary: [ToolSummary] = []
        let subscription = EventBus.shared.subscribe(MessagePartUpdatedEvent.self) { event in
            guard event.part.sessionID == session.id,
                  case .tool(let toolPart) = event.part else { return }
            
            toolSummary.append(ToolSummary(
                id: toolPart.id,
                tool: toolPart.tool,
                status: toolPart.state.status,
                title: toolPart.state.title
            ))
            
            Task {
                await ctx.metadata(ToolMetadataUpdate(
                    title: params.description,
                    metadata: Metadata(sessionId: session.id, summary: toolSummary)
                ))
            }
        }
        defer { subscription.cancel() }
        
        // Handle abort propagation
        let abortTask = Task {
            for await _ in ctx.abort {
                await SessionPrompt.cancel(session.id)
            }
        }
        defer { abortTask.cancel() }
        
        // Execute subagent
        let result = try await SessionPrompt.prompt(
            sessionID: session.id,
            agent: agent.name,
            model: model,
            parts: try await resolvePromptParts(params.prompt)
        )
        
        let text = result.parts.compactMap { part -> String? in
            if case .text(let textPart) = part { return textPart.text }
            return nil
        }.last ?? ""
        
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

### Session Prompt Loop

```swift
// MARK: - Session Prompt Loop

actor SessionPrompt {
    private var activeLoops: [String: SessionLoopState] = [:]
    
    struct SessionLoopState {
        var abort: AsyncChannel<Void>
        var callbacks: [CheckedContinuation<AssistantMessage, Error>]
    }
    
    func prompt(
        sessionID: String,
        agent: String,
        model: ModelSelection,
        parts: [PromptPart]
    ) async throws -> AssistantMessage {
        let session = try await SessionManager.shared.get(sessionID)
        
        // Create user message
        let userMessage = try await SessionManager.shared.createUserMessage(
            sessionID: sessionID,
            agent: agent,
            model: model,
            parts: parts
        )
        
        return try await loop(sessionID: sessionID)
    }
    
    private func loop(sessionID: String) async throws -> AssistantMessage {
        guard let abort = start(sessionID) else {
            // Already running, wait for result
            return try await withCheckedThrowingContinuation { continuation in
                activeLoops[sessionID]?.callbacks.append(continuation)
            }
        }
        
        defer { cancel(sessionID) }
        
        var step = 0
        let session = try await SessionManager.shared.get(sessionID)
        
        while true {
            if abort.isCancelled { break }
            
            let messages = try await MessageManager.shared.stream(sessionID)
            guard let lastUser = messages.last(where: { $0.role == "user" }) as? UserMessage else {
                throw SessionError.noUserMessage
            }
            
            let lastAssistant = messages.last(where: { $0.role == "assistant" }) as? AssistantMessage
            
            // Check for completion
            if let finish = lastAssistant?.finish,
               !["tool-calls", "unknown"].contains(finish),
               lastUser.id < lastAssistant!.id {
                break
            }
            
            step += 1
            
            guard let agent = await AgentRegistry.shared.get(lastUser.agent) else {
                throw SessionError.invalidAgent(lastUser.agent)
            }
            
            let maxSteps = agent.steps ?? Int.max
            let isLastStep = step >= maxSteps
            
            // Resolve tools for this agent
            let tools = try await resolveTools(
                agent: agent,
                session: session,
                model: lastUser.model,
                bypassAgentCheck: messages.last?.parts.contains { $0.type == .agent } ?? false
            )
            
            // Create processor
            let processor = try await SessionProcessor(
                sessionID: sessionID,
                agent: agent,
                model: lastUser.model,
                abort: abort
            )
            
            // Process with LLM
            let result = try await processor.process(
                messages: messages,
                tools: tools,
                isLastStep: isLastStep
            )
            
            switch result {
            case .stop:
                break
            case .compact:
                try await SessionCompaction.create(sessionID: sessionID, agent: agent.name)
                continue
            case .continue:
                continue
            }
        }
        
        // Return final assistant message
        guard let result = try await MessageManager.shared
            .stream(sessionID)
            .last(where: { $0.role == "assistant" }) as? AssistantMessage else {
            throw SessionError.noAssistantMessage
        }
        
        // Notify waiters
        for callback in activeLoops[sessionID]?.callbacks ?? [] {
            callback.resume(returning: result)
        }
        
        return result
    }
    
    private func resolveTools(
        agent: Agent,
        session: Session,
        model: ModelSelection,
        bypassAgentCheck: Bool
    ) async throws -> [String: ResolvedTool] {
        var tools: [String: ResolvedTool] = [:]
        
        let registry = ToolRegistry.shared
        for resolvedTool in try await registry.tools(for: agent) {
            tools[resolvedTool.id] = ResolvedTool(
                id: resolvedTool.id,
                definition: resolvedTool.definition,
                contextFactory: { args, callID in
                    ToolContext(
                        sessionID: session.id,
                        messageID: "", // Set by processor
                        agent: agent.name,
                        abort: AsyncChannel(),
                        callID: callID,
                        extra: ["bypassAgentCheck": bypassAgentCheck],
                        ask: { request in
                            try await PermissionManager.shared.ask(
                                request,
                                rulesets: [agent.permission, session.permission ?? []]
                            )
                        }
                    )
                }
            )
        }
        
        return tools
    }
    
    func cancel(_ sessionID: String) {
        guard let state = activeLoops.removeValue(forKey: sessionID) else { return }
        state.abort.finish()
        for callback in state.callbacks {
            callback.resume(throwing: CancellationError())
        }
    }
}
```

### Session Processor

```swift
// MARK: - Session Processor

actor SessionProcessor {
    private let sessionID: String
    private let agent: Agent
    private let model: ModelSelection
    private let abort: AsyncChannel<Void>
    private var assistantMessage: AssistantMessage
    private var toolCalls: [String: ToolPart] = [:]
    
    enum Result {
        case stop
        case compact  
        case `continue`
    }
    
    init(sessionID: String, agent: Agent, model: ModelSelection, abort: AsyncChannel<Void>) async throws {
        self.sessionID = sessionID
        self.agent = agent
        self.model = model
        self.abort = abort
        
        // Create assistant message
        self.assistantMessage = try await SessionManager.shared.createAssistantMessage(
            sessionID: sessionID,
            agent: agent.name,
            model: model
        )
    }
    
    func process(
        messages: [any Message],
        tools: [String: ResolvedTool],
        isLastStep: Bool
    ) async throws -> Result {
        let systemPrompts = try await buildSystemPrompts(agent: agent)
        let modelMessages = messages.map { $0.toModelMessage() }
        
        // Add max steps warning if needed
        if isLastStep {
            modelMessages.append(ModelMessage(
                role: .assistant,
                content: "Maximum steps reached. Summarize progress and stop."
            ))
        }
        
        let stream = try await LLM.stream(
            model: model,
            system: systemPrompts,
            messages: modelMessages,
            tools: tools
        )
        
        var blocked = false
        var needsCompaction = false
        
        for try await event in stream {
            try abort.checkCancellation()
            
            switch event {
            case .textDelta(let delta):
                try await handleTextDelta(delta)
                
            case .toolCall(let call):
                try await handleToolCall(call, tools: tools)
                
            case .toolResult(let result):
                try await handleToolResult(result)
                
            case .toolError(let error):
                blocked = try await handleToolError(error)
                
            case .finishStep(let usage):
                let tokenUsage = calculateUsage(usage)
                assistantMessage.tokens = tokenUsage
                if isOverflow(tokenUsage) {
                    needsCompaction = true
                }
                
            case .finish(let reason):
                assistantMessage.finish = reason
            }
        }
        
        // Finalize message
        assistantMessage.time.completed = Date()
        try await SessionManager.shared.updateMessage(assistantMessage)
        
        if needsCompaction { return .compact }
        if blocked { return .stop }
        if assistantMessage.error != nil { return .stop }
        return .continue
    }
    
    private func handleToolCall(_ call: ToolCallEvent, tools: [String: ResolvedTool]) async throws {
        guard let tool = tools[call.toolName] else {
            throw ToolError.notFound(call.toolName)
        }
        
        // Doom loop detection
        let recentParts = assistantMessage.parts.suffix(3)
        let isDoomLoop = recentParts.count == 3 && recentParts.allSatisfy { part in
            guard case .tool(let toolPart) = part else { return false }
            return toolPart.tool == call.toolName &&
                   toolPart.state.input == call.input
        }
        
        if isDoomLoop {
            try await PermissionManager.shared.ask(
                PermissionRequest(
                    permission: "doom_loop",
                    patterns: [call.toolName],
                    metadata: ["tool": call.toolName, "input": call.input]
                ),
                rulesets: [agent.permission]
            )
        }
        
        // Create running part
        let part = ToolPart(
            id: Identifier.ascending("part"),
            messageID: assistantMessage.id,
            sessionID: sessionID,
            tool: call.toolName,
            callID: call.callID,
            state: .running(input: call.input, startTime: Date())
        )
        toolCalls[call.callID] = part
        try await SessionManager.shared.updatePart(part)
    }
}
```

---

## Summary

OpenCode's agent system provides:

1. **Hierarchical Agents**: Primary agents for full access, subagents for specialized work
2. **Permission Inheritance**: Agent → Session → Runtime approval chain
3. **Session Linking**: Parent-child sessions via `parentID` for subagent tracking
4. **Tool Filtering**: Per-agent tool resolution with dynamic descriptions
5. **Doom Loop Protection**: Detects repeated identical tool calls
6. **Step Limits**: Configurable max steps per agent
7. **Model Inheritance**: Subagents inherit parent's model if not specified

Swift implementation requires:

1. **Actor-based concurrency** for safe state management
2. **Async streams** for real-time event propagation
3. **Protocol-oriented tools** with associated types
4. **Structured concurrency** for abort handling
5. **Event bus** for cross-component communication
