import Foundation
import AnigmaCLIML
import HarmoniaModule

/// Orchestrates interaction between TUI components and backend services
public actor ChatPresenter {
    private let mlCoordinator: MLBackendCoordinator
    private let toolRouter: ToolRouter
    private var subscriptionId: UUID?

    public init(mlCoordinator: MLBackendCoordinator, toolRouter: ToolRouter) {
        self.mlCoordinator = mlCoordinator
        self.toolRouter = toolRouter
    }

    public func start() async {
        // Subscribe to input events
        self.subscriptionId = await TUIEventBus.shared.subscribe { [weak self] event in
            if case .inputCommitted(let text) = event {
                Task {
                    await self?.handleUserInput(text)
                }
            }
        }
    }

    public func stop() async {
        if let id = subscriptionId {
            await TUIEventBus.shared.unsubscribe(id: id)
        }
    }

    private func handleUserInput(_ input: String) async {
        // 1. Log user message
        await TUIEventBus.shared.publish(.messageAdded(role: "user", content: input))
        await TUIEventBus.shared.publish(.statusUpdated(message: "🤔 Thinking..."))

        // 2. Perform Streaming Inference Loop
        do {
            let systemPrompt = """
            You are an expert Swift developer and AI assistant for the Anigma project.
            Anigma is a governed, local-first Swift stack for institutional AI.

            Key Architectural Tiers:
            - Tier 1: Governance & Policy
            - Tier 2: Platform Runtime
            - Tier 3: Capability Modules
            """

            var currentPrompt = input
            var iteration = 0
            let maxIterations = 5

            while iteration < maxIterations {
                iteration += 1

                // Add placeholder for assistant response
                await TUIEventBus.shared.publish(.messageAdded(role: "assistant", content: ""))

                let stream = try await mlCoordinator.chatStream(
                    prompt: currentPrompt,
                    systemPrompt: systemPrompt,
                    maxTokens: 2048,
                    temperature: 0.7
                )

                await TUIEventBus.shared.publish(.statusUpdated(message: "✍️ Assistant is typing..."))

                var fullResponse = ""
                for try await token in stream {
                    fullResponse += token
                    await TUIEventBus.shared.publish(.tokenReceived(token: token))
                }

                // Check for Tool Calls
                if fullResponse.contains("<tool_call>") {
                    await TUIEventBus.shared.publish(.statusUpdated(message: "🛠️ Executing tools..."))

                    let toolCalls = extractToolCalls(from: fullResponse)
                    if toolCalls.isEmpty {
                        await TUIEventBus.shared.publish(.statusUpdated(message: nil))
                        break
                    }

                    var toolResults = ""
                    for call in toolCalls {
                        await TUIEventBus.shared.publish(.messageAdded(role: "system", content: "🛠️ Executing \(call.name)..."))

                        let result = await toolRouter.executeToolCall(
                            request: ToolCallRequest(
                                toolName: call.name,
                                sessionId: "tui-session",
                                parameters: call.parameters
                            ),
                            session: SessionContext(
                                sessionId: "tui-session",
                                agentId: "chat",
                                permissions: [.readFiles, .writeFiles, .executeBuild, .executeTests, .readRepository]
                            )
                        )

                        let output = String(data: result.result ?? Data(), encoding: .utf8) ?? "[No output]"
                        toolResults += "<tool_result>\n<name>\(call.name)</name>\n<output>\n\(output)\n</output>\n</tool_result>\n"

                        let displayOutput = output.count > 300 ? String(output.prefix(300)) + "..." : output
                        await TUIEventBus.shared.publish(.messageAdded(role: "system", content: "✅ Result from \(call.name):\n\(displayOutput)"))
                    }

                    currentPrompt = "Tool Results:\n\(toolResults)\n\nPlease continue based on these results."
                    await TUIEventBus.shared.publish(.statusUpdated(message: "🤔 Processing results..."))
                } else {
                    // No more tool calls, exit loop
                    await TUIEventBus.shared.publish(.statusUpdated(message: nil))
                    break
                }
            }

        } catch {
            await TUIEventBus.shared.publish(.messageAdded(role: "system", content: "Error: \(error.localizedDescription)"))
            await TUIEventBus.shared.publish(.statusUpdated(message: "❌ Error occurred"))
        }
    }

    private struct ExtractedToolCall {
        let name: String
        let parameters: String
    }

    private func extractToolCalls(from text: String) -> [ExtractedToolCall] {
        var calls: [ExtractedToolCall] = []
        let parts = text.components(separatedBy: "<tool_call>")
        for part in parts.dropFirst() {
            guard let callEnd = part.range(of: "</tool_call>") else { continue }
            let callContent = String(part[..<callEnd.lowerBound])

            guard let nameStart = callContent.range(of: "<name>"),
                  let nameEnd = callContent.range(of: "</name>") else { continue }
            let name = String(callContent[nameStart.upperBound..<nameEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let paramsStart = callContent.range(of: "<parameters>"),
                  let paramsEnd = callContent.range(of: "</parameters>") else { continue }
            let parameters = String(callContent[paramsStart.upperBound..<paramsEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

            calls.append(ExtractedToolCall(name: name, parameters: parameters))
        }
        return calls
    }
}
