# Harmonia CLI Overhaul Design

## Overview

This document describes the architecture and design for an overhauled Harmonia CLI, inspired by OpenCode's patterns while staying aligned with Harmonia's daemon, ECS, and MLX stack.

The CLI is a client to the Harmonia daemon, which manages:
- ECS world state (components, systems)
- AI inference pipelines (MLX, remote providers)
- Tool execution (file operations, shell, search, etc.)
- Session and agent state
- Undo/redo history and safety nets

## Goals

1. **Modular CLI**: Clean separation between command parsing, daemon client, UI presentation.
2. **Interactive TUI**: Rich terminal UI with chat, file picker, status bar, slash commands.
3. **Plan vs Build modes**: Different permission levels for tools.
4. **Undo/redo with git integration**: Safety nets for AI-driven changes.
5. **Agent profiles**: Configurable system prompts, tool permissions, model selection.
6. **Tool abstraction**: Map Harmonia's internal tools to LLM-callable functions.
7. **Project context**: Project summaries and RAG integration.

## Contract alignment

- The SURFACE.AnigmaCLI contract in `Docs/governance/contract-artifacts/SURFACE.AnigmaCLI.md` is the source of truth for the CLI surface, receipts, loop breakers, and housekeeping requirements.
- Praxis/RepoIdentity gates remain authoritative and must succeed before any mutating command executes; this overhaul aligns with those gates instead of creating a parallel entry point.

## Architecture

### Components

```
Sources/HarmoniaCLI/
├── Main.swift                    # Entry point, command configuration
├── Commands/                    # Subcommand implementations
│   ├── TUICommand.swift
│   ├── RunCommand.swift
│   ├── ServeCommand.swift
│   ├── ModelsCommand.swift
│   ├── AuthCommands.swift
│   ├── AgentCommands.swift
│   └── SessionCommands.swift
├── Client/
│   ├── DaemonClient.swift       # IPC client to Harmonia daemon
│   ├── Models/
│   │   ├── Session.swift
│   │   ├── AgentProfile.swift
│   │   ├── ToolDescriptor.swift
│   │   └── ...
│   └── Protocol/                # Request/response types
├── UI/
│   ├── TUI.swift                # Terminal UI controller
│   ├── Views/
│   │   ├── ChatView.swift
│   │   ├── StatusBar.swift
│   │   └── FilePicker.swift
│   └── InputHandler.swift       # Keybindings, slash commands
├── Tools/
│   ├── ToolRegistry.swift
│   └── implementations/
├── Undo/
│   ├── UndoManager.swift
│   └── GitIntegration.swift
└── Config/
    ├── ConfigManager.swift
    └── Store.swift              # JSON persistence
```

### Communication with Daemon

The Harmonia daemon exposes an API over either:
1. **HTTP REST/WebSocket** (preferred for cross-language compatibility)
2. **Unix domain sockets** (lower latency, same-machine only)
3. **Direct library calls** (CLI links to HarmoniaModule; daemon runs in-process)

Given the current codebase imports `HarmoniaModule`, we'll start with direct library calls but abstract behind a `DaemonClient` protocol. Later, we can implement socket-based IPC.

**DaemonClient Protocol**:
```swift
protocol DaemonClient {
    func startSession(agent: String?) async throws -> Session
    func sendMessage(sessionId: String, content: String, mode: ExecutionMode) async throws -> AsyncStream<MessageChunk>
    func listTools() async throws -> [ToolDescriptor]
    func executeTool(sessionId: String, tool: String, parameters: [String: Any]) async throws -> ToolResult
    func undo(sessionId: String) async throws -> UndoResult
    func redo(sessionId: String) async throws -> RedoResult
    // ... other methods
}
```

### Core Concepts

#### Session
Represents a conversation or interaction context with the daemon. Contains:
- Unique ID
- Agent profile
- Message history
- Tool execution history
- Undo/redo stacks

#### AgentProfile
Defines behavior and permissions for an AI agent:
- Name
- System prompt
- Default execution mode (plan/build)
- Allowed tools
- Tools requiring confirmation
- Default model
- ECS component attachments (for governance)

Built-in profiles:
- `plan`: Read-only tools, suggests changes but requires confirmation.
- `build`: Full write/execute permissions, with automatic undo snapshots.

#### ToolDescriptor
Describes a capability the LLM can invoke:
- Name
- Description
- Parameters (JSON schema)
- Permission level (read/write/execute)
- Confirmation required (yes/no)

Example tools:
- `read_file`: Read contents of a file
- `write_file`: Write or patch a file
- `search_files`: Search project for patterns
- `run_shell`: Execute a shell command
- `query_rag`: Query project RAG index

#### ExecutionMode
- `plan`: Tools that modify state require explicit confirmation.
- `build`: Tools execute directly, with automatic safety nets.

## Subcommand Design

### `harmonia` (no arguments)
Starts interactive TUI attached to daemon. If daemon not running, prompts to start it.

### `harmonia serve`
Starts the Harmonia daemon in background. Options:
- `--port`: HTTP port (default 4173)
- `--socket`: Unix socket path
- `--foreground`: Run in foreground (no daemonize)

### `harmonia run`
One-shot prompt execution. Options:
- `--agent`: Agent profile name
- `--mode`: Override execution mode
- `--model`: Override model
- `--file`: Attach file(s) as context
- `--path`: Project path (default cwd)
- `--format`: Output format (text, json)

### `harmonia session`
Session management:
- `harmonia session list`
- `harmonia session show <id>`
- `harmonia session close <id>`

### `harmonia agent`
Agent profile management:
- `harmonia agent list`
- `harmonia agent show <name>`
- `harmonia agent create <name> [options]`
- `harmonia agent edit <name>`
- `harmonia agent delete <name>`

### `harmonia models`
Model introspection:
- `harmonia models list` (available models)
- `harmonia models set-default <model>`
- `harmonia models test <model> <prompt>`

### `harmonia tools`
Tool management:
- `harmonia tools list`
- `harmonia tools describe <name>`
- `harmonia tools permissions <agent>`

## Interactive TUI Design

### Views
1. **Chat View**: Messages between user and AI, with syntax highlighting for code and diffs.
2. **Status Bar**: Shows agent name, mode, model, session ID, and system status.
3. **Input Area**: Multi-line input with `@` file picker trigger.
4. **Tool Output Panel**: Dedicated area for tool execution results (collapsible).

### Keybindings
- `Ctrl+P` / `Ctrl+N`: Navigate message history
- `Ctrl+R`: Toggle plan/build mode
- `Ctrl+Z`: Undo
- `Ctrl+Shift+Z`: Redo
- `Ctrl+F`: Open file picker
- `Ctrl+L`: Clear screen
- `Ctrl+C`: Cancel current operation
- `Ctrl+D` or `/quit`: Exit

### Slash Commands
- `/mode plan|build`
- `/undo [steps]`
- `/redo [steps]`
- `/agent <name>`
- `/model <id>`
- `/tools list|enable|disable`
- `/session new|list|switch`
- `/project init|summary`
- `/quit` or `/exit`

### File Picker
When user types `@`, open fuzzy file picker over current project root. Uses in-memory index for speed. Supports:
- Navigation with arrow keys
- Filtering by typing
- Selecting with Enter
- Cancelling with Esc

Selected file path inserted as `@path/to/file` token.

## Undo/Redo and Safety Nets

### Approach
1. **Git-based**: If project is git repository, create lightweight commit before AI-driven changes. Undo reverts to that commit.
2. **Patch-based**: Store unified diffs in `.harmonia/undo/<session>/` directory.

### Implementation
- `UndoManager` tracks changes per session.
- Before applying tool that modifies files, capture snapshot.
- Snapshot includes:
  - Git commit hash (if available)
  - File patches
  - Tool invocation parameters
- Undo stack limited to configurable depth (default 20).

### Commands
- `harmonia undo [session]`: Revert last change set.
- `harmonia redo [session]`: Reapply last undone change.
- `harmonia history [session]`: Show undo stack.

## Agent Profiles and Tools

### Agent Configuration
YAML format at `~/.config/harmonia/agents/<name>.yaml`:
```yaml
name: "build"
system_prompt: |
  You are a helpful AI assistant that can write and modify code.
  You have permission to execute tools that modify files and run commands.
  Always explain your reasoning before making changes.
mode: build
model: "harmonia/default"
allowed_tools:
  - read_file
  - write_file
  - search_files
  - run_shell
tools_requiring_confirmation: []
ecs_components:
  - "GovernanceComponent"
  - "AuditComponent"
```

### Tool Permissions
Each tool has a permission level:
- `read`: Can read files, search, query
- `write`: Can modify files
- `execute`: Can run shell commands

Agent profiles specify which tools are allowed and which require confirmation.

## Project Context

### Project Summary
Similar to OpenCode's `AGENTS.md`, Harmonia maintains a project summary at `.harmonia/summary.md` (or `HARMONIA.md`). Contains:
- Project structure overview
- Key files and their purposes
- Build/run instructions
- Toolchain information
- Recent changes

Generated via `harmonia project init` or TUI command `/init`.

### RAG Integration
If Harmonia has RAG capabilities, the project summary and source files can be indexed for contextual retrieval during sessions.

## Implementation Phases

### Phase 1: Refactor Existing CLI
- Extract subcommands into separate files
- Create `DaemonClient` protocol with stub implementation
- Move models to `Client/Models/`
- Set up module structure

### Phase 2: Basic TUI Foundation
- Choose TUI library (e.g., `SwiftTerm`, `TerminalKit`)
- Implement chat view and input handling
- Add status bar

### Phase 3: Plan/Build Mode Integration
- Extend `ExecutionMode` to influence tool permissions
- Implement confirmation prompts for restricted tools

### Phase 4: File Picker and `@` Trigger
- Implement fast file indexing
- Fuzzy search UI
- Path token insertion

### Phase 5: Tool System
- Define `ToolDescriptor` protocol
- Implement core tools (read_file, write_file, etc.)
- Integrate with daemon's tool execution

### Phase 6: Undo/Redo with Git
- Implement `UndoManager`
- Git integration for repositories
- Patch-based fallback

### Phase 7: Agent Profiles and Configuration
- YAML configuration loader
- Profile management commands
- Tool permission system

### Phase 8: Polish and Testing
- Improve error handling and logging
- Add unit and integration tests
- Documentation

## Compatibility

Maintain backward compatibility with existing CLI:
- Keep existing subcommands (`tui`, `run`, `serve`, `models`, `auth`, `agent`)
- Preserve current flag names and behavior
- Add new functionality as extensions

## Configuration

### Global Config
`~/.config/harmonia/config.yaml`:
```yaml
default_agent: "plan"
default_model: "harmonia/default"
daemon:
  port: 4173
  socket_path: "/tmp/harmonia.sock"
tui:
  theme: "dark"
  keybindings: {}
```

### Project Config
`.harmonia/config.yaml`:
```yaml
agent: "build"
model: "mlx:orca-mini"
tools:
  allowed:
    - read_file
    - write_file
  denied:
    - run_shell
```

## Testing Strategy

1. **Unit tests**: Command parsing, model serialization, utility functions.
2. **Integration tests**: Mock daemon client, test end-to-end flows.
3. **UI tests**: Screen recording and assertion (hard but possible with TUI library support).

## Open Issues

1. **Daemon API specification**: Need to define exact endpoints/methods.
2. **TUI library selection**: Evaluate Swift TUI options.
3. **Performance**: File indexing for large projects.
4. **Security**: Tool execution in sandboxed environment.

## References

- OpenCode (sst/opencode): https://github.com/sst/opencode
- Harmonia daemon architecture (internal docs)
- Anigma ECS design (ADR 0001)
