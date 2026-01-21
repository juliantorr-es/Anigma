import Foundation
import AnigmaTUI

@main
struct AnigmaTUIDemo {
    static func main() async throws {
        let renderer = TerminalRenderer(size: Size(width: 100, height: 24))
        var state = TUIState()
        state.mode = "Autopilot"
        state.currentModel = "GPT-4o"
        state.lastReceipt = "6a0f...7667"

        let messages = [
            ChatMessage(role: .user, content: "Analyze the current memory leaks in HarmoniaModule."),
            ChatMessage(role: .assistant, content: "I've identified 3 potential leaks in the SessionManager. Applying fixes..."),
            ChatMessage(role: .user, content: "Ensure evidence is recorded for each fix."),
            ChatMessage(role: .assistant, content: "Understood. Evidence chains are being generated and signed by EvidenceAuthority.")
        ]

        var frame = 0
        while frame < 100 {
            let currentFrame = frame
            let root = ChatView(messages: messages, state: state)

            await renderer.render(root)
            try await Task.sleep(nanoseconds: 50_000_000)
            frame += 1
        }
    }
}
