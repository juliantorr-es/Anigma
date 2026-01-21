//
//  LocalLLMOrchestrator.swift
//  AnigmaAppMac
//
//  Orchestrates multiple CLI agents using a local LLM as the decision-making brain.
//  Governed execution with full audit trail.
//

import Foundation
import AnigmaClientKit
import CryptoKit
import AnigmaHostMac
import MLWorkerCommon
import ContextumModule
import DatabaseCore
import ContractsCore

// MARK: - CLI Tool Registry

/// Registry of available CLI coding agents
struct CLIToolRegistry {

    /// Known CLI tools that can be orchestrated
    enum Tool: String, CaseIterable, Identifiable, Codable {
        case codex = "codex"
        case claudeCLI = "claude"
        case copilotCLI = "gh-copilot"
        case geminiCLI = "gemini"
        case aiderCLI = "aider"
        case cursorCLI = "cursor"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .codex: return "OpenAI Codex"
            case .claudeCLI: return "Claude CLI"
            case .copilotCLI: return "GitHub Copilot CLI"
            case .geminiCLI: return "Gemini CLI"
            case .aiderCLI: return "Aider"
            case .cursorCLI: return "Cursor CLI"
            }
        }

        var description: String {
            switch self {
            case .codex:
                return "OpenAI's code generation model optimized for programming tasks"
            case .claudeCLI:
                return "Anthropic's Claude assistant for code review and generation"
            case .copilotCLI:
                return "GitHub's AI pair programmer integrated with git workflows"
            case .geminiCLI:
                return "Google's Gemini for multi-modal reasoning and code"
            case .aiderCLI:
                return "Terminal-based AI pair programmer with git integration"
            case .cursorCLI:
                return "Cursor's AI-first code editing capabilities"
            }
        }

        var binaryName: String {
            rawValue
        }

        var strengths: [String] {
            switch self {
            case .codex:
                return ["Python", "JavaScript", "Code completion", "API integration"]
            case .claudeCLI:
                return ["Code review", "Refactoring", "Documentation", "Long context"]
            case .copilotCLI:
                return ["Git operations", "Repository understanding", "Quick suggestions"]
            case .geminiCLI:
                return ["Multi-modal", "Reasoning chains", "Large context", "Planning"]
            case .aiderCLI:
                return ["Git workflow", "Multi-file edits", "Interactive coding"]
            case .cursorCLI:
                return ["IDE integration", "Fast iteration", "Code transforms"]
            }
        }
    }

    /// Discover which CLI tools are available on this system
    static func discoverAvailableTools() -> [ToolAvailability] {
        Tool.allCases.map { tool in
            let path = findBinaryPath(for: tool)
            return ToolAvailability(
                tool: tool,
                isInstalled: path != nil,
                binaryPath: path,
                version: path.flatMap { getVersion(at: $0) }
            )
        }
    }

    private static func findBinaryPath(for tool: Tool) -> String? {
        let paths = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []

        for dir in paths {
            let fullPath = "\(dir)/\(tool.binaryName)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        // Check common locations
        let commonPaths = [
            "/usr/local/bin/\(tool.binaryName)",
            "/opt/homebrew/bin/\(tool.binaryName)",
            "\(NSHomeDirectory())/.local/bin/\(tool.binaryName)",
            "\(NSHomeDirectory())/.cargo/bin/\(tool.binaryName)"
        ]

        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    private static func getVersion(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

struct ToolAvailability: Identifiable {
    let tool: CLIToolRegistry.Tool
    let isInstalled: Bool
    let binaryPath: String?
    let version: String?

    var id: String { tool.id }
}

// MARK: - Orchestration Messages

/// A message in the orchestration conversation
struct OrchestratorMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var toolCall: ToolCallInfo?

    enum Role: String, Codable {
        case user
        case orchestrator // The local LLM
        case tool // Output from a CLI tool
        case system
    }

    init(role: Role, content: String, toolCall: ToolCallInfo? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.toolCall = toolCall
    }
}

struct ToolCallInfo: Codable {
    let tool: CLIToolRegistry.Tool
    let command: String
    let exitCode: Int32?
    let durationMs: Int?
}

// MARK: - Orchestration Plan

/// A plan generated by the local LLM for how to orchestrate tools
struct OrchestrationPlan: Codable {
    let taskDescription: String
    var steps: [OrchestrationStep]
    let reasoning: String
}

struct OrchestrationStep: Codable, Identifiable {
    let id: UUID
    let order: Int
    let tool: CLIToolRegistry.Tool
    let instruction: String
    let inputFromPrevious: Bool
    var status: StepStatus
    var result: String?

    enum StepStatus: String, Codable {
        case pending
        case running
        case completed
        case failed
        case skipped
    }

    init(order: Int, tool: CLIToolRegistry.Tool, instruction: String, inputFromPrevious: Bool = false) {
        self.id = UUID()
        self.order = order
        self.tool = tool
        self.instruction = instruction
        self.inputFromPrevious = inputFromPrevious
        self.status = .pending
    }
}

// MARK: - Local LLM Orchestrator

/// Orchestrates multiple CLI agents using a local LLM as the brain
@Observable
@MainActor
final class LocalLLMOrchestrator {

    // MARK: - State

    var messages: [OrchestratorMessage] = []
    var availableTools: [ToolAvailability] = []
    var currentPlan: OrchestrationPlan?
    var isProcessing: Bool = false
    var currentStepIndex: Int = 0

    private let cliRunner = CLIAgentRunner()
    private var contextumModule: Contextum?

    // Correlation tracking
    private var currentWorkflowID: UUID?
    private var currentRunID: UUID?

    // MARK: - Initialization

    init() {
        refreshAvailableTools()
        Task {
            await initializeContextum()
        }
    }

    private func initializeContextum() async {
        do {
            let dbActor = DatabaseActor()
            self.contextumModule = try await Contextum(dbActor: dbActor)
        } catch {
            addMessage(.system, "⚠️ Contextum initialization failed: \(error.localizedDescription)")
        }
    }

    func refreshAvailableTools() {
        availableTools = CLIToolRegistry.discoverAvailableTools()

        let installed = availableTools.filter { $0.isInstalled }
        if installed.isEmpty {
            addMessage(.system, "⚠️ No CLI agents found. Install codex, claude, gh-copilot, or gemini CLI.")
        } else {
            let names = installed.map { $0.tool.displayName }.joined(separator: ", ")
            addMessage(.system, "✅ Available agents: \(names)")
        }
    }

    // MARK: - Public API

    /// Submit a task to the orchestrator
    func submitTask(_ task: String, workspace: RepoWorkspace) async {
        guard !isProcessing else { return }

        isProcessing = true
        addMessage(.user, task)

        // Initialize correlation IDs for full run tracking
        let workflowID = UUID()
        let runID = UUID()
        self.currentWorkflowID = workflowID
        self.currentRunID = runID

        do {
            // PHASE 1: Contextum Preflight - Search for relevant context
            let contextResults = try await contextumPreflight(
                task: task,
                workspace: workspace,
                workflowID: workflowID,
                runID: runID
            )

            if !contextResults.isEmpty {
                addMessage(.system, "📚 Found \(contextResults.count) relevant context chunks")
            }

            // PHASE 2: Generate plan using local LLM with context
            addMessage(.orchestrator, "🧠 Analyzing task and generating execution plan...")

            let plan = try await generatePlan(for: task, context: contextResults)
            currentPlan = plan

            addMessage(.orchestrator, """
            📋 **Execution Plan**

            \(plan.reasoning)

            **Steps:**
            \(plan.steps.enumerated().map { i, step in
                "\(i + 1). [\(step.tool.displayName)] \(step.instruction)"
            }.joined(separator: "\n"))
            """)

            // PHASE 3: Execute each step with full correlation and receipts
            for (index, step) in plan.steps.enumerated() {
                currentStepIndex = index

                guard var currentStep = currentPlan?.steps[index] else { continue }
                currentStep.status = .running
                currentPlan?.steps[index] = currentStep

                addMessage(.orchestrator, "▶️ Executing step \(index + 1): \(step.tool.displayName)")

                let stepStartTime = Date()
                let jobID = UUID()

                do {
                    let result = try await executeStep(
                        step,
                        workspace: workspace,
                        workflowID: workflowID,
                        runID: runID,
                        jobID: jobID
                    )

                    let durationMs = Int(Date().timeIntervalSince(stepStartTime) * 1000)

                    currentStep.status = .completed
                    currentStep.result = result
                    currentPlan?.steps[index] = currentStep

                    addMessage(.tool, result, toolCall: ToolCallInfo(
                        tool: step.tool,
                        command: step.instruction,
                        exitCode: 0,
                        durationMs: durationMs
                    ))

                    // PHASE 4: Contextum Postflight - Record execution outcome
                    try await contextumPostflight(
                        agentId: step.tool.rawValue,
                        taskTaxonomy: classifyTask(task),
                        durationMs: durationMs,
                        outcome: .success,
                        workflowID: workflowID,
                        runID: runID,
                        jobID: jobID
                    )

                } catch {
                    let durationMs = Int(Date().timeIntervalSince(stepStartTime) * 1000)

                    currentStep.status = .failed
                    currentStep.result = error.localizedDescription
                    currentPlan?.steps[index] = currentStep

                    // Record failure in Contextum
                    try await contextumPostflight(
                        agentId: step.tool.rawValue,
                        taskTaxonomy: classifyTask(task),
                        durationMs: durationMs,
                        outcome: .failure,
                        errorCode: "EXEC_FAILED",
                        workflowID: workflowID,
                        runID: runID,
                        jobID: jobID
                    )

                    throw error
                }
            }

            addMessage(.orchestrator, "✅ All steps completed successfully.")

        } catch {
            addMessage(.orchestrator, "❌ Orchestration failed: \(error.localizedDescription)")
        }

        isProcessing = false
        currentWorkflowID = nil
        currentRunID = nil
    }

    /// Clear the conversation
    func clearConversation() {
        messages.removeAll()
        currentPlan = nil
        currentStepIndex = 0
    }

    // MARK: - Private Methods

    private func addMessage(_ role: OrchestratorMessage.Role, _ content: String, toolCall: ToolCallInfo? = nil) {
        messages.append(OrchestratorMessage(role: role, content: content, toolCall: toolCall))
    }

    /// Generate an execution plan using the local LLM
    private func generatePlan(for task: String, context: [String] = []) async throws -> OrchestrationPlan {
        let installedTools = availableTools.filter { $0.isInstalled }

        // Build context for the local LLM
        let toolDescriptions = installedTools.map { availability in
            """
            - **\(availability.tool.displayName)** (\(availability.tool.rawValue))
              Description: \(availability.tool.description)
              Strengths: \(availability.tool.strengths.joined(separator: ", "))
            """
        }.joined(separator: "\n")

        let systemPrompt = """
        You are an AI orchestrator that coordinates multiple coding AI assistants to complete tasks.

        Available Tools:
        \(toolDescriptions)

        \(context.isEmpty ? "" : """

        Relevant Context:
        \(context.prefix(3).enumerated().map { i, ctx in "[\(i + 1)] \(ctx.prefix(200))..." }.joined(separator: "\n"))
        """)

        Choose the best tool(s) for the task. You can use multiple tools in sequence.
        Respond ONLY with valid JSON matching this structure:
        {
            "taskDescription": "...",
            "reasoning": "Brief explanation of why you chose these tools",
            "steps": [
                {
                    "order": 1,
                    "tool": "tool-id",
                    "instruction": "What to tell this tool",
                    "inputFromPrevious": false
                }
            ]
        }
        """

        let userPrompt = "Task: \(task)"

        // Wire to actual MLWorker via governed execution
        do {
            let client = MLWorkerClient()

            // Check if MLWorker is installed
            guard client.isInstalled() else {
                addMessage(.system, "⚠️ MLWorker not installed, using heuristic planning")
                return generateMockPlan(for: task, installedTools: installedTools)
            }

            // Build the prompt for local LLM - combine system and user prompts
            let fullPrompt = """
            \(systemPrompt)

            \(userPrompt)
            """

            let promptHash = fullPrompt.sha256Hash()

            // Execute via MLWorker - use LLM chat task
            let response = try await client.runTask(
                engine: "mlx",
                task: .chat,
                inputs: [WorkerMLArtifactRef(path: "", hash: promptHash)],
                options: MLTaskOptions(
                    seed: 42,
                    maxTokens: 1024,
                    temperature: 0.2,
                    topP: nil,
                    outputDirectory: nil
                )
            )

            // Parse response - expect JSON from the model
            guard let firstOutput = response.outputs.first else {
                throw OrchestratorError.planGenerationFailed
            }

            let outputText = try String(contentsOfFile: firstOutput.path, encoding: String.Encoding.utf8)

            // Decode the JSON plan
            if let jsonData = outputText.data(using: String.Encoding.utf8) {
                let decoder = JSONDecoder()
                let planResponse = try decoder.decode(OrchestrationPlanResponse.self, from: jsonData)

                // Convert to OrchestrationPlan with proper step objects
                var steps: [OrchestrationStep] = []
                for stepData in planResponse.steps {
                    if let tool = CLIToolRegistry.Tool(rawValue: stepData.tool) {
                        steps.append(OrchestrationStep(
                            order: stepData.order,
                            tool: tool,
                            instruction: stepData.instruction,
                            inputFromPrevious: stepData.inputFromPrevious
                        ))
                    }
                }

                return OrchestrationPlan(
                    taskDescription: planResponse.taskDescription,
                    steps: steps,
                    reasoning: planResponse.reasoning
                )
            } else {
                throw OrchestratorError.planGenerationFailed
            }

        } catch {
            // Fallback to mock plan if MLWorker fails (graceful degradation)
            addMessage(.system, "⚠️ Local LLM error: \(error.localizedDescription), using heuristic planning")
            return generateMockPlan(for: task, installedTools: installedTools)
        }
    }

    /// Mock plan generation (replace with actual local LLM call)
    private func generateMockPlan(for task: String, installedTools: [ToolAvailability]) -> OrchestrationPlan {
        let taskLower = task.lowercased()

        // Simple keyword matching for demo
        var steps: [OrchestrationStep] = []
        var reasoning = "Based on the task description, I've selected the most appropriate tools."

        if taskLower.contains("review") || taskLower.contains("refactor") {
            if let claude = installedTools.first(where: { $0.tool == .claudeCLI }) {
                steps.append(OrchestrationStep(order: 1, tool: claude.tool, instruction: task))
                reasoning = "Code review and refactoring tasks benefit from Claude's analytical capabilities."
            }
        }

        if taskLower.contains("git") || taskLower.contains("commit") || taskLower.contains("pr") {
            if let copilot = installedTools.first(where: { $0.tool == .copilotCLI }) {
                steps.append(OrchestrationStep(order: steps.count + 1, tool: copilot.tool, instruction: task))
                reasoning += " GitHub Copilot is ideal for git-related operations."
            }
        }

        if taskLower.contains("generate") || taskLower.contains("implement") || taskLower.contains("code") {
            if let codex = installedTools.first(where: { $0.tool == .codex }) {
                steps.append(OrchestrationStep(order: steps.count + 1, tool: codex.tool, instruction: task))
                reasoning = "Codex excels at code generation tasks."
            } else if let gemini = installedTools.first(where: { $0.tool == .geminiCLI }) {
                steps.append(OrchestrationStep(order: steps.count + 1, tool: gemini.tool, instruction: task))
                reasoning = "Gemini provides strong code generation with reasoning."
            }
        }

        // Fallback: use the first available tool
        if steps.isEmpty, let first = installedTools.first {
            steps.append(OrchestrationStep(order: 1, tool: first.tool, instruction: task))
            reasoning = "Using \(first.tool.displayName) as the primary tool for this task."
        }

        return OrchestrationPlan(
            taskDescription: task,
            steps: steps,
            reasoning: reasoning
        )
    }

    // MARK: - Contextum Integration

    /// Preflight: Search Contextum for relevant context before execution
    private func contextumPreflight(
        task: String,
        workspace: RepoWorkspace,
        workflowID: UUID,
        runID: UUID
    ) async throws -> [String] {
        guard let contextum = contextumModule else {
            return []
        }

        let jobID = UUID()

        // Record search event
        _ = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .search,
            jobId: jobID.uuidString,
            runId: runID.uuidString,
            outcome: .success,
            diagnosticPayload: [
                "query": task,
                "workflowID": workflowID.uuidString
            ]
        )

        // Perform hybrid search (FTS only in Phase 0, embeddings in Phase 1)
        let searchRequest = HybridSearchSystem.SearchRequest(
            query: task,
            mode: .fullText,  // Phase 0: FTS only, upgrade to .hybrid in Phase 1
            limit: 10,
            filters: ["workspace": workspace.rootURL.path],
            workflowId: workflowID.uuidString,
            runId: runID.uuidString
        )

        do {
            let results = try await contextum.search(request: searchRequest)
            // Extract content from results
            return results.chunks.map { $0.content }
        } catch {
            // Non-critical failure: log and continue without context
            addMessage(.system, "⚠️ Context search failed: \(error.localizedDescription)")
struct ContextumPostflightConfiguration: Sendable {
    let agentId: String
    let taskTaxonomy: String
    let durationMs: Int
    let outcome: String
    let errorCode: String?
    let workflowID: UUID
    let runID: UUID
    let jobID: UUID
}

// Function signature should be updated to:
// func contextumPostflight(config: ContextumPostflightConfiguration) async throws
// Function signature should change from:
// func contextumPostflight(agentId: String, taskTaxonomy: String, durationMs: Int, outcome: String, errorCode: String?, workflowID: UUID, runID: UUID, jobID: UUID)
// To:
// func contextumPostflight(config: ContextumPostflightConfiguration)
// In the function signature:
func contextumPostflight(config: ContextumPostflightConfiguration) async throws {
    guard let contextum = contextumModule else {
        return
    }

    try await contextum.recordAgentExecution(
        agentId: config.agentId,
        // ... other parameters from config
    )
}
            taskTaxonomy: taskTaxonomy,
            durationMs: durationMs,
            outcome: outcome,
            errorCode: errorCode
        )
    }

    /// Classify task into taxonomy for skill tracking
    private func classifyTask(_ task: String) -> String {
        let lower = task.lowercased()

        if lower.contains("refactor") { return "refactoring" }
        if lower.contains("review") { return "code_review" }
        if lower.contains("test") || lower.contains("spec") { return "testing" }
        if lower.contains("fix") || lower.contains("bug") { return "bug_fix" }
        if lower.contains("implement") || lower.contains("add") { return "feature_implementation" }
        if lower.contains("document") || lower.contains("doc") { return "documentation" }
        if lower.contains("optimize") || lower.contains("performance") { return "optimization" }

        return "general_coding"
    }

    /// Execute a single orchestration step with full correlation
    private func executeStep(
        _ step: OrchestrationStep,
        workspace: RepoWorkspace,
        workflowID: UUID,
        runID: UUID,
        jobID: UUID
    ) async throws -> String {
        guard let availability = availableTools.first(where: { $0.tool == step.tool && $0.isInstalled }),
              let binaryPath = availability.binaryPath else {
            throw OrchestratorError.toolNotAvailable(step.tool.displayName)
        }

        // Build and execute the command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [step.instruction]
        process.currentDirectoryURL = workspace.rootURL

        // Environment with correlation tracking
        var env = ProcessInfo.processInfo.environment
        env["ANIGMA_ORCHESTRATED"] = "1"
        env["ANIGMA_STEP"] = "\(step.order)"
        env["ANIGMA_WORKFLOW_ID"] = workflowID.uuidString
        env["ANIGMA_RUN_ID"] = runID.uuidString
        env["ANIGMA_JOB_ID"] = jobID.uuidString
        process.environment = env

        // Capture output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        var result = String(data: outputData, encoding: .utf8) ?? ""
        if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
            result += "\n⚠️ stderr: \(errorOutput)"
        }

        if process.terminationStatus != 0 {
            throw OrchestratorError.toolFailed(step.tool.displayName, process.terminationStatus)
        }

        return result.isEmpty ? "(No output)" : result
    }
}

// MARK: - Errors

enum OrchestratorError: LocalizedError {
    case toolNotAvailable(String)
    case toolFailed(String, Int32)
    case planGenerationFailed

    var errorDescription: String? {
        switch self {
        case .toolNotAvailable(let name):
            return "Tool '\(name)' is not installed or not in PATH"
        case .toolFailed(let name, let code):
            return "Tool '\(name)' failed with exit code \(code)"
        case .planGenerationFailed:
            return "Failed to generate execution plan"
        }
    }
}

// MARK: - Plan Response Format

/// JSON structure for LLM plan responses
private struct OrchestrationPlanResponse: Codable {
    let taskDescription: String
    let reasoning: String
    let steps: [StepData]

    struct StepData: Codable {
        let order: Int
        let tool: String
        let instruction: String
        let inputFromPrevious: Bool
    }
}

// MARK: - String Extension for Hashing

extension String {
    func sha256Hash() -> String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
