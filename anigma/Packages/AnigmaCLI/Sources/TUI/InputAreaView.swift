import Foundation

/// Component for multi-line text input
public class InputAreaView: TUIBaseComponent {
    private var editor = MultiLineEditor()
    private var history: [String] = []
    private var historyIndex: Int = -1
    private var tempInput: String = "" // Stash current input when browsing history
    
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
        let title = historyIndex >= 0 ? "Input (History \(historyIndex + 1)/\(history.count))" : "Input"
        await engine.drawBox(row: rect.row, col: rect.col, width: rect.width, height: rect.height, title: title, color: borderColor)

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
            if c == "\\" && editor.text.hasSuffix("\\") { 
                // Double backslash? Or just handle in Enter
            }
            editor.insert(c); markDirty(); return true
        case .space:
            editor.insert(" "); markDirty(); return true
        case .backspace:
            editor.backspace(); markDirty(); return true
        case .enter:
            // Check for escaped newline
            let currentLine = editor.lines[editor.cursorRow]
            if currentLine.hasSuffix("\\") {
                editor.backspace() // Remove backslash
                editor.insert("\n") // Insert newline
                markDirty()
                return true
            }
            
            let text = editor.text
            if !text.isEmpty {
                // Save to history
                if history.last != text {
                    history.append(text)
                }
                historyIndex = -1
                tempInput = ""
                
                Task {
                    await TUIEventBus.shared.publish(.inputCommitted(text: text))
                }
                editor.clear()
                markDirty()
            }
            return true
        case .up:
            if editor.cursorRow == 0 {
                navigateHistory(offset: -1)
            } else {
                editor.moveUp()
            }
            markDirty(); return true
        case .down:
            if editor.cursorRow == editor.lines.count - 1 {
                navigateHistory(offset: 1)
            } else {
                editor.moveDown()
            }
            markDirty(); return true
        case .left:
            editor.moveLeft(); markDirty(); return true
        case .right:
            editor.moveRight(); markDirty(); return true
        default:
            return false
        }
    }
    
    private func navigateHistory(offset: Int) {
        if history.isEmpty { return }
        
        if historyIndex == -1 && offset == -1 {
            // Start browsing history, stash current
            tempInput = editor.text
            historyIndex = history.count - 1
        } else if historyIndex != -1 {
            historyIndex += offset
        }
        
        if historyIndex < -1 { historyIndex = -1 }
        if historyIndex >= history.count { historyIndex = -1 }
        
        if historyIndex == -1 {
            editor.text = tempInput
        } else {
            editor.text = history[historyIndex]
        }
        
        // Move cursor to end
        editor.moveToEnd()
    }
}
