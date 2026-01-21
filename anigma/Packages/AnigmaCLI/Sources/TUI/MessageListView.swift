import Foundation

/// Component for displaying a list of messages
public class MessageListView: TUIBaseComponent {
    private var messages: [(role: String, content: String)] = []
    private var scrollOffset = 0
    private var renderedLines: [String] = []
    private let theme = Theme.defaultTheme

    private var subscriptionId: UUID?

    public init() {
        super.init(id: "message_list")

        Task {
            let id = await TUIEventBus.shared.subscribe { [weak self] event in
                switch event {
                case .messageAdded(let role, let content):
                    Task { @MainActor in
                        self?.addMessage(role: role, content: content)
                    }
                case .tokenReceived(let token):
                    Task { @MainActor in
                        self?.appendToLastMessage(token)
                    }
                default: break
                }
            }
            self.subscriptionId = id
        }
    }

    deinit {
        if let id = subscriptionId {
            Task { await TUIEventBus.shared.unsubscribe(id: id) }
        }
    }

    public func addMessage(role: String, content: String) {
        messages.append((role, content))
        scrollToBottom()
        markDirty()
    }

    public func appendToLastMessage(_ content: String) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].content += content
        scrollToBottom()
        markDirty()
    }

    private func scrollToBottom() {
        // We'll calculate the true bottom in the next render cycle, 
        // for now just set a large offset that will be clamped by render()
        scrollOffset = 999999
    }

    public override func render(engine: TUIEngine, rect: TUIRect) async {
        let borderColor = isFocused ? theme.borderActive.color : theme.border.color
        await engine.drawBox(row: rect.row, col: rect.col, width: rect.width, height: rect.height, title: "Anigma CLI Chat", color: borderColor)

        let width = rect.width - 4
        var allLines: [String] = []
        var inCodeBlock = false

        for msg in messages {
            let roleStyle = msg.role == "user" ? theme.userRole : (msg.role == "system" ? theme.systemRole : theme.assistantRole)
            allLines.append(engine.styled("[\(msg.role)]", style: roleStyle))

            let contentLines = msg.content.components(separatedBy: "\n")
            for rawLine in contentLines {
                if rawLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    inCodeBlock.toggle()
                    allLines.append(engine.styled("  " + String(repeating: "─", count: width - 2), style: theme.systemRole))
                    continue
                }

                let wrapped = wordWrap(rawLine, width: width - 2)
                for w in wrapped {
                    let styledLine = inCodeBlock ? engine.styled("  " + w, color: .cyan) : "  " + w
                    allLines.append(styledLine)
                }
            }
            allLines.append("")
        }

        let visibleHeight = rect.height - 2
        let visibleStart = max(0, min(scrollOffset, allLines.count - visibleHeight))
        let visibleEnd = min(allLines.count, visibleStart + visibleHeight)

        for (i, lineIdx) in (visibleStart..<visibleEnd).enumerated() {
            await engine.addToFrame(row: rect.row + 1 + i, col: rect.col + 2, text: allLines[lineIdx])
        }
    }

    private func wordWrap(_ text: String, width: Int) -> [String] {
        if text.isEmpty { return [""] }
        var lines: [String] = []
        var currentLine = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            if currentLine.count + word.count + 1 > width {
                if !currentLine.isEmpty { lines.append(currentLine); currentLine = "" }
            }
            if !currentLine.isEmpty { currentLine += " " }
            currentLine += word
        }
        if !currentLine.isEmpty { lines.append(currentLine) }
        return lines.isEmpty ? [""] : lines
    }

    public override func handleKey(_ key: InputHandler.Key) async -> Bool {
        switch key {
        case .up, .scrollUp:
            if scrollOffset > 0 { scrollOffset -= 1; markDirty() }
            return true
        case .down, .scrollDown:
            scrollOffset += 1; markDirty()
            return true
        default:
            return false
        }
    }
}
