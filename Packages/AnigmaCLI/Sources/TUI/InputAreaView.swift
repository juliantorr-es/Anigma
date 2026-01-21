import Foundation

/// Component for multi-line text input
public class InputAreaView: TUIBaseComponent {
    private var editor = MultiLineEditor()
    private let theme = Theme.defaultTheme
    private var onCommit: ((String) -> Void)?

    public init(onCommit: ((String) -> Void)? = nil) {
        self.onCommit = onCommit
        super.init(id: "input_area")
    }

    public var lineCount: Int {
        editor.lines.count
    }

    public override func render(engine: TUIEngine, rect: TUIRect) async {
        let borderColor = isFocused ? theme.borderActive.color : theme.border.color
        await engine.drawBox(row: rect.row, col: rect.col, width: rect.width, height: rect.height, title: "Input", color: borderColor)

        for (i, line) in editor.lines.prefix(rect.height - 2).enumerated() {
            let visibleText = String(line.prefix(rect.width - 4))
            await engine.addToFrame(row: rect.row + 1 + i, col: rect.col + 2, text: engine.styled(visibleText, style: theme.input))
        }

        if isFocused {
            await engine.moveCursor(row: rect.row + 1 + editor.cursorRow, col: rect.col + 2 + editor.cursorCol)
        }
    }

    public override func handleKey(_ key: InputHandler.Key) async -> Bool {
        switch key {
        case .char(let c):
            editor.insert(c); markDirty(); return true
        case .space:
            editor.insert(" "); markDirty(); return true
        case .backspace:
            editor.backspace(); markDirty(); return true
        case .enter:
            let text = editor.text
            if !text.isEmpty {
                Task {
                    await TUIEventBus.shared.publish(.inputCommitted(text: text))
                }
                editor.clear()
                markDirty()
            }
            return true
        case .up:
            editor.moveUp(); markDirty(); return true
        case .down:
            editor.moveDown(); markDirty(); return true
        case .left:
            editor.moveLeft(); markDirty(); return true
        case .right:
            editor.moveRight(); markDirty(); return true
        default:
            return false
        }
    }
}
