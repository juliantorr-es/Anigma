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

    private let richRenderer = RichTextRenderer()

    public override func render(engine: TUIEngine, rect: TUIRect) async {
        let borderColor = isFocused ? theme.borderActive.color : theme.border.color
        await engine.drawBox(row: rect.row, col: rect.col, width: rect.width, height: rect.height, title: "Anigma CLI Chat", color: borderColor)

        let width = rect.width - 4
        var allLines: [String] = [] // Legacy string lines for scrolling calculation
        var richLines: [[RichTextRenderer.RenderedLine]] = [] 

        // We render everything to a buffer first
        for msg in messages {
            let roleStyle = msg.role == "user" ? theme.userRole : (msg.role == "system" ? theme.systemRole : theme.assistantRole)
            
            // Header
            richLines.append([RichTextRenderer.RenderedLine(segments: [
                RichTextRenderer.StyledSegment(text: "[\(msg.role)]", style: roleStyle.bold ? .bold : .reset, color: roleStyle.color)
            ])])
            allLines.append("[\(msg.role)]")

            // Content
            let renderedContent = richRenderer.render(text: msg.content, width: width)
            richLines.append(renderedContent)
            
            // Update line count for scrolling
            for _ in renderedContent {
                allLines.append("") 
            }
            
            // Spacer
            richLines.append([RichTextRenderer.RenderedLine(segments: [])])
            allLines.append("")
        }
        
        // Flatten richLines for easy indexing
        let flatRichLines = richLines.flatMap { $0 }

        let visibleHeight = rect.height - 2
        let visibleStart = max(0, min(scrollOffset, flatRichLines.count - visibleHeight))
        let visibleEnd = min(flatRichLines.count, visibleStart + visibleHeight)

        for (i, lineIdx) in (visibleStart..<visibleEnd).enumerated() {
            let line = flatRichLines[lineIdx]
            var currentCol = rect.col + 2
            
            for segment in line.segments {
                let text = segment.text
                await engine.addToFrame(
                    row: rect.row + 1 + i, 
                    col: currentCol, 
                    text: engine.styled(text, color: segment.color, bg: segment.background, style: segment.style)
                )
                currentCol += text.count 
            }
        }
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
