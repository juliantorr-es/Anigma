import Foundation

// MARK: - TextField
public final class TextField: Renderable, @unchecked Sendable {
    public var text: String = ""
    public var cursorPosition: Int = 0
    public var placeholder: String = ""
    public var isFocused: Bool = false

    public init(placeholder: String = "") {
        self.placeholder = placeholder
    }

    public func handleInput(_ key: Key) {
        switch key {
        case .char(let c):
            text.insert(c, at: text.index(text.startIndex, offsetBy: cursorPosition))
            cursorPosition += 1
        case .backspace:
            if cursorPosition > 0 {
                cursorPosition -= 1
                text.remove(at: text.index(text.startIndex, offsetBy: cursorPosition))
            }
        case .left:
            cursorPosition = max(0, cursorPosition - 1)
        case .right:
            cursorPosition = min(text.count, cursorPosition + 1)
        default:
            break
        }
    }

    public func measure(in availableSize: Size) -> Size {
        Size(width: availableSize.width, height: 1)
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let displayColor: Color = isFocused ? .brightWhite : .gray
        let content = text.isEmpty ? placeholder : text

        for (i, char) in content.prefix(frame.size.width).enumerated() {
            buffer.setCell(Cell(char: char, foreground: displayColor), at: Point(x: frame.origin.x + i, y: frame.origin.y))
        }

        if isFocused {
            // Hardware cursor positioning is handled by the Renderer
        }
    }
}

// MARK: - CommandPalette
public struct CommandPalette: Renderable {
    public var query: String
    public var suggestions: [String]
    public var selectedIndex: Int

    public init(query: String, suggestions: [String], selectedIndex: Int = 0) {
        self.query = query
        self.suggestions = suggestions
        self.selectedIndex = selectedIndex
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let box = Box(borderColor: .brightMagenta, title: "COMMAND PALETTE", padding: 1) {
            VStack(spacing: 0) {
                HStack {
                    Text("> ", foreground: .brightMagenta, attributes: [.bold])
                    Text(query)
                }
                Text(String(repeating: "─", count: frame.size.width - 4), foreground: .gray)
                for (i, suggestion) in suggestions.enumerated() {
                    Text(suggestion,
                         foreground: i == selectedIndex ? .black : .white,
                         background: i == selectedIndex ? .brightMagenta : nil)
                }
            }
        }
        box.render(in: frame, to: buffer)
    }
}

// MARK: - KeybindManager (Leader Key)
public actor KeybindManager {
    private var isLeaderActive = false
    private let leaderKey = Character("a") // Ctrl+A

    public func process(_ key: Key) -> CommandAction? {
        // Implementation for Leader key sequences (Ctrl+A -> E for Evidence)
        return nil
    }
}

public enum CommandAction {
    case toggleEvidence
    case toggleKillSwitch
    case switchModel(String)
}
