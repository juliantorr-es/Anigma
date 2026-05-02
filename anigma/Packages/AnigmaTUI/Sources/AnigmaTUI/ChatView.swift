import Foundation

public struct ChatMessage: Sendable {
    public enum Role: Sendable {
        case user
        case assistant
        case system
    }

    public let role: Role
    public let content: String
    public let timestamp: Date

    public init(role: Role, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

public struct ChatView: Renderable {
    public let messages: [ChatMessage]
    public let state: TUIState

    public init(messages: [ChatMessage], state: TUIState) {
        self.messages = messages
        self.state = state
    }

    public func measure(in availableSize: Size) -> Size {
        availableSize
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let root = Box(borderColor: .blue, title: "ANIGMA HARMONIA", padding: 1) {
            VStack(spacing: 1) {
                // Header
                HStack {
                    HStack(spacing: 0) {
                        Text("MODE: ", foreground: .gray)
                        Text(state.mode.uppercased(), foreground: .brightCyan, attributes: [.bold])
                    }
                    Spacer()
                    HStack(spacing: 0) {
                        Text("MODEL: ", foreground: .gray)
                        Text(state.currentModel, foreground: .brightMagenta)
                    }
                }

                // Messages Area
                Box(borderColor: .gray, title: "Session History") {
                    VStack(spacing: 1) {
                        if messages.isEmpty {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("No messages yet. Start by typing a prompt.", foreground: .gray, attributes: [.italic])
                                Spacer()
                            }
                            Spacer()
                        } else {
                            for message in messages.suffix(10) {
                                HStack(spacing: 1, alignment: .top) {
                                    Text(message.role == .user ? "YOU " : "AI  ",
                                         foreground: message.role == .user ? .brightGreen : .brightBlue,
                                         attributes: [.bold])
                                    Text(message.content)
                                }
                            }
                        }
                    }
                }

                // Governance status
                HStack {
                    Text("GOVERNANCE:", foreground: .gray)
                    Text(state.isWriteAllowed ? "ALLOWED" : "BLOCKED",
                         foreground: state.isWriteAllowed ? .brightGreen : .brightRed)
                    Spacer()
                    if let receipt = state.lastReceipt {
                        Text("RECEIPT: ", foreground: .gray)
                        Text(receipt, foreground: .brightYellow)
                    }
                }

                // Input Prompt
                Box(borderColor: .brightCyan) {
                    HStack {
                        Text("> ", foreground: .brightCyan, attributes: [.bold])
                        Text("Type your message here...", foreground: .gray)
                        Spacer()
                    }
                }
            }
        }

        root.render(in: frame, to: buffer)
    }
}
