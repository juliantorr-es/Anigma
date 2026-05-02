# Gemini CLI: Full Architecture Analysis & Swift Implementation Plan

This document provides a comprehensive architectural analysis of the `gemini-cli` repository and a detailed technical roadmap for re-implementing its core capabilities in Swift.

---

## Part I: Architecture Analysis of `google-gemini/gemini-cli`

The `gemini-cli` is a TypeScript-based monorepo that provides both an interactive terminal interface and a scriptable CLI for interacting with Google's Gemini models. It is more than a simple API wrapper; it is a full-fledged **Agentic Runtime Environment** capable of tool discovery, complex multi-turn execution loops, and rich terminal UI rendering.

### 1. High-Level Organization

The codebase is organized as a workspace with two primary packages, enforcing a strict separation of concerns:

#### **`packages/core` (The logic Layer)**
*   **Purpose**: Contains all business logic, API interactions, state management, and agent definitions. It is strictly UI-agnostic.
*   **Key Responsibilities**:
    *   **Configuration**: Loading settings from multiple sources (defaults, user config, project config, flags).
    *   **Agent Execution**: The `LocalAgentExecutor` class that drives the OODA (Observe-Orient-Decide-Act) loop.
    *   **Tooling**: The `ToolRegistry` for managing built-in and external tools.
    *   **Networking**: Clients for the Gemini API (`@google/genai`).
    *   **Telemetry**: Tracing and metrics.

#### **`packages/cli` (The Presentation Layer)**
*   **Purpose**: The entry point for the user. It handles argument parsing and renders the UI.
*   **Key Responsibilities**:
    *   **Input Handling**: Parsing flags using `yargs` (or custom logic) and handling `stdin`.
    *   **Interactive UI**: A React-based terminal UI powered by **Ink**. It manages standard hooks (`useEffect`, `useState`) to render components like `ChatHistory`, `InputPrompt`, and `Spinners`.
    *   **Non-Interactive Mode**: A streamlined execution mode for piping data, which bypasses React for raw stdio streams.

---

### 2. Core Components Analysis

#### 2.1 The Agentic Execution Loop (`LocalAgentExecutor`)
Located in `packages/core/src/agents/local-executor.ts`, this is the heart of the application.

*   **State Machine**: It implements a `while(true)` loop that continues until a termination condition is met (`MAX_TURNS`, `TIMEOUT`, `GOAL`, `ABORT`).
*   **Turn Logic**:
    1.  **Compress**: Checks if context size is too large and effectively compresses history (using `ChatCompressionService`).
    2.  **Call Model**: Sends current history to Gemini.
    3.  **Parse Response**: Extracts text (for thoughts) and `FunctionCalls`.
    4.  **Execute Tools**: Validates tool arguments against Zod schemas and executes them via `ToolRegistry`.
    5.  **Feedback**: Appends tool outputs back to the history and repeats the loop.
*   **Resiliency**: It includes sophisticated recovery logic. If the agent times out or hits a limit, it injects a "Grace Period" turn, warning the model and giving it one last chance to call `complete_task`.

#### 2.2 Tool Management (`ToolRegistry`)
Located in `packages/core/src/tools/tool-registry.ts`.

*   **Unified Interface**: All tools (built-in, discovered, MCP) implement a common interface.
*   **Discovery**: It can "discover" tools by running a command (e.g., `gemini tools discover`) which expects a JSON output of function declarations.
*   **MCP Support**: It integrates with the Model Context Protocol (MCP) to load tools dynamically from local servers.
*   **Execution Isolation**: `DiscoveredTool` runs external commands as child processes, capturing `stdout`/`stderr` to return to the model.

#### 2.3 Configuration System (`Config`)
Located in `packages/core/src/config/config.ts`.

*   **Hierarchical Loading**:
    1.  **Hardcoded Defaults**: `DEFAULT_MODEL`, etc.
    2.  **Global User Config**: `~/.gemini/config.json`.
    3.  **Project Config**: `.gemini/config.json` in the current workspace.
    4.  **Runtime Flags**: CLI arguments override everything.
*   **Service Locator**: The `Config` class acts as a service locator, holding references to singletons like `ToolRegistry`, `GeminiClient`, and `WorkspaceContext`.

#### 2.4 User Interface (`packages/cli/src/ui`)
*   **Tech Stack**: **React** + **Ink**.
*   **Component Structure**:
    *   `AppContainer`: The root provider setup (Theme, Config, Auth).
    *   `App`: The main layout string.
    *   `ScrollableContent`: Handles the chat history view.
    *   `InputPrompt`: A complex component handling multi-line input, history navigation (Up/Down arrows), and auto-complete.
*   **Concurrency**: Uses `useEffect` to subscribe to `coreEvents` (like `ModelChanged`, `ToolActivity`) to update the UI in real-time without blocking the main thread.

---

## Part II: Swift Implementation Proposal

To build a "Gemini CLI for Swift", we will leverage Swift's modern concurrency features (`async/await`, `Actors`) and strong type system to replicate the robustness of the TypeScript architecture.

### 1. Technology Stack Selection

| Component | Node.js (Current) | Swift (Proposed) | Rationale |
| :--- | :--- | :--- | :--- |
| **CLI Parser** | Custom / Yargs | **Swift Argument Parser** | The standard, type-safe library for Swift CLIs. |
| **Networking** | `@google/genai` | **GoogleGenerativeAI** SDK | Official Swift SDK provides native models and streaming. |
| **Concurrency** | Promises | **Swift Concurrency** | Actors provide safe shared state; Task groups for parallel tool execution. |
| **JSON/Schema** | Zod | **Codable** + **Reflection** | Swift's `Codable` is powerful; we can generate generic JSON schemas from structs. |
| **UI** | Ink (React) | **Swift TermUI** / **ANSI** | A full React-like TUI is complex; an MVC model with standard ANSI rendering is the MVP approach. |

---

### 2. Detailed Architecture Plan

We will create a Swift Package defined in `Package.swift` with two targets: `GeminiCore` and `GeminiCLI`.

#### 2.1 Target: `GeminiCore`

This library will mirror `packages/core`.

**A. Domain Models (`Sources/GeminiCore/Models.swift`)**
We need type-safe representations of the conversation.

```swift
import Foundation
import GoogleGenerativeAI

public enum Role: String, Codable {
    case user, model, tool
}

public struct AgentMessage: Identifiable, Sendable {
    public let id: UUID
    public let role: Role
    public let content: [Part] // Wraps the SDK's Part (text, functionCall, etc)
    public let timestamp: Date
}

public struct ToolDefinition: Sendable {
    public let name: String
    public let description: String
    public let schema: [String: Any] // JSON Schema representation
    public let execute: @Sendable ([String: Any]) async throws -> [String: Any]
}
```

**B. Tool Registry (`Sources/GeminiCore/ToolRegistry.swift`)**
An `actor` is perfect here to manage thread-safe registration.

```swift
public actor ToolRegistry {
    private var tools: [String: ToolDefinition] = [:]

    public func register(_ tool: ToolDefinition) {
        tools[tool.name] = tool
    }

    public func getFunctionDeclarations() -> [FunctionDeclaration] {
        // Convert internal ToolDefinitions to SDK's FunctionDeclaration objects
        return tools.values.map { ... }
    }

    public func execute(call: FunctionCall) async throws -> FunctionResponse {
        guard let tool = tools[call.name] else {
            throw ToolError.unknownTool(call.name)
        }
        let result = try await tool.execute(call.args)
        return FunctionResponse(name: call.name, response: result)
    }
}
```

**C. The Agent Executor (`Sources/GeminiCore/AgentExecutor.swift`)**
This encapsulates the conversation loop.

```swift
public actor AgentExecutor {
    private let model: GenerativeModel
    private let toolRegistry: ToolRegistry
    private var history: [ModelContent] = []
    
    public init(apiKey: String, modelName: String, registry: ToolRegistry) {
        self.model = GenerativeModel(name: modelName, apiKey: apiKey, tools: registry.getSDKTools())
        self.toolRegistry = registry
    }

    public func run(input: String, streamCallback: (String) -> Void) async throws -> String {
        // 1. Append User Input
        history.append(ModelContent(role: "user", parts: [.text(input)]))
        
        var keepGoing = true
        var finalResponse = ""

        while keepGoing {
            // 2. Generate Content (Streaming)
            let responseStream = model.generateContentStream(history)
            var currentTurnText = ""
            var functionCalls: [FunctionCall] = []

            for try await chunk in responseStream {
                if let text = chunk.text {
                    currentTurnText += text
                    streamCallback(text) // Update UI in real-time
                }
                functionCalls.append(contentsOf: chunk.functionCalls)
            }
            
            // 3. Handle Tool Calls
            if !functionCalls.isEmpty {
                var toolResponses: [FunctionResponse] = []
                
                // Parallel execution possible with TaskGroup
                await withTaskGroup(of: FunctionResponse.self) { group in
                    for call in functionCalls {
                        group.addTask {
                            return try! await self.toolRegistry.execute(call: call)
                        }
                    }
                    for await response in group {
                        toolResponses.append(response)
                    }
                }
                
                // Append logic and continue loop
                history.append(ModelContent(role: "model", parts: ...)) // previous turn
                history.append(ModelContent(role: "function", parts: toolResponses.map { ... }))
            } else {
                // Done
                keepGoing = false
                finalResponse = currentTurnText
            }
        }
        return finalResponse
    }
}
```

#### 2.2 Target: `GeminiCLI`

This executable handles the user interactions.

**A. Entry Point (`Sources/GeminiCLI/main.swift`)**
Using `ArgumentParser`.

```swift
import ArgumentParser
import GeminiCore

@main
struct Gemini: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "Model name")
    var model: String = "gemini-1.5-pro"

    @Argument(help: "Prompt to run immediately")
    var prompt: String?

    mutating func run() async throws {
        // 1. Config Loading
        let config = Config.load()
        let registry = ToolRegistry.default()
        
        // 2. Register standard tools
        await registry.register(FileReadTool())
        await registry.register(ListDirectoryTool())

        // 3. Initialize Agent
        let agent = AgentExecutor(apiKey: config.apiKey, modelName: model, registry: registry)

        if let prompt = prompt {
            // One-Shot Mode
            try await agent.run(input: prompt) { fragment in
                print(fragment, terminator: "")
                fflush(stdout)
            }
        } else {
            // Interactive REPL
            print("\u{1B}[1;34mGemini CLI (Swift)\u{1B}[0m") // ANSI Blue
            while true {
                print("\n> ", terminator: "")
                guard let line = readLine() else { break }
                if line == "exit" { break }
                
                do {
                    _ = try await agent.run(input: line) { fragment in
                        // Streaming Output
                        print(fragment, terminator: "")
                        fflush(stdout)
                    }
                } catch {
                    print("\nError: \(error)")
                }
            }
        }
    }
}
```

---

### 3. Implementation Phases

#### Phase 1: Foundation
*   set up the Swift Package Manager (SPM) project.
*   Integrate `google-generative-ai-swift` SDK.
*   Implement basic `Config` struct to load API Key from `ENV`.
*   Build a simple "User Input -> Model Text -> Console Output" loop.

#### Phase 2: Tooling Infrastructure
*   Implement the `ToolDefinition` struct.
*   Create the `ToolRegistry` actor.
*   Implement `executeToolCall` logic in the Agent loop.
*   **First Tool**: `ReadFileTool` (essential for proving the concept).

#### Phase 3: Advanced Agent Loop
*   Implement the `checkTermination` logic (Max turns).
*   Add **History Management**: Ability to compress or truncate history if the token count gets too high (using strict `Codable` sizing as a proxy or an estimation API).
*   Add **Resiliency**: Implement the "Grace Period" retry logic seen in the TypeScript codebase.

#### Phase 4: UI Polish
*   Move away from simple `print`.
*   Implement a `Renderer` class that handles ANSI escape codes for:
    *   Colors (User = Green, Agent = Blue, Tool = Yellow).
    *   Spinners (⠋ ⠙ ⠹) during network waits.
    *   Markdown rendering (basic terminal formatting for bold/code blocks).

### 4. Key Challenges & mitigations

1.  **JSON Schema Generation**:
    *   *Challenge*: TypeScript has libraries that auto-convert types to JSON Schema. Swift `Codable` does not do this out of the box.
    *   *Solution*: We will likely need to manually define the schema dictionaries for tools initially, or use a library like `OpenAPIKit` to reflect on structs.

2.  **UI Interactivity (React vs Loop)**:
    *   *Challenge*: The TS CLI uses React (Ink) which re-renders components based on state. Swift CLIs are typically imperative.
    *   *Solution*: For the MVP, an imperitive "print stream" is sufficient. If a complex UI is needed later, we can use a "Clear Screen + Redraw" loop pattern, essentially implementing a basic game loop.

3.  **Cross-Platform Support**:
    *   *Challenge*: `gemini-cli` works on Windows/Mac/Linux.
    *   *Solution*: Swift 6 has excellent cross-platform support. By sticking to `Foundation` and avoiding direct macOS APIs (like `AppKit`), the CLI will compile for Linux and Windows (via WSL or native Swift toolchain).

