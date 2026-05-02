import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// A single cell in the terminal grid
struct TUICell: Equatable {
    var char: Character = " "
    var color: TUIEngine.Color?
    var bg: TUIEngine.Color?
    var style = TUIEngine.Style.reset

    // We store the rendered ANSI string for fast comparison and output
    var rendered: String = " "
}

/// Terminal UI rendering engine with double buffering and ANSI support
public actor TUIEngine {
    private var isRawMode = false
    private var terminalSize: (rows: Int, cols: Int) = (24, 80)

    private var currentBuffer: [TUICell] = []
    private var backBuffer: [TUICell] = []

    public init() {}

    // MARK: - Terminal Control

    public func enableRawMode() throws {
        #if canImport(Darwin)
        var raw = termios()
        tcgetattr(STDIN_FILENO, &raw)

        raw.c_lflag &= ~(UInt(ECHO | ICANON))
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        isRawMode = true
        print("\u{001B}[?1049h", terminator: "") // Enable alternate buffer
        print("\u{001B}[?25l", terminator: "")   // Hide cursor
        print("\u{001B}[?1002h\u{001B}[?1006h", terminator: "") // Enable mouse tracking (Motion + SGR mode)
        fflush(stdout)
        updateSize()
        #endif
    }

    public func disableRawMode() {
        #if canImport(Darwin)
        print("\u{001B}[?1002l\u{001B}[?1006l", terminator: "") // Disable mouse tracking
        print("\u{001B}[?25h", terminator: "")   // Show cursor
        print("\u{001B}[?1049l", terminator: "") // Disable alternate buffer

        var raw = termios()
        tcgetattr(STDIN_FILENO, &raw)
        raw.c_lflag |= UInt(ECHO | ICANON)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        isRawMode = false
        fflush(stdout)
        #endif
    }

    public func getTerminalSize() -> (rows: Int, cols: Int) {
        updateSize()
        return terminalSize
    }

    private func updateSize() {
        #if canImport(Darwin)
        var w = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 {
            let newRows = Int(w.ws_row)
            let newCols = Int(w.ws_col)

            if newRows != terminalSize.rows || newCols != terminalSize.cols {
                terminalSize = (newRows, newCols)
                let count = terminalSize.rows * terminalSize.cols
                currentBuffer = Array(repeating: TUICell(), count: count)
                backBuffer = Array(repeating: TUICell(), count: count)
            }
        }
        #endif
    }

    // MARK: - Drawing (Buffered)

    public func clearScreen() {
        for i in 0..<backBuffer.count {
            backBuffer[i] = TUICell()
        }
    }

    public func beginFrame() {
        updateSize()
        clearScreen()
    }

    public func endFrame() {
        var output = ""
        var lastRow = -1
        var lastCol = -1

        for r in 1...terminalSize.rows {
            for c in 1...terminalSize.cols {
                let idx = (r - 1) * terminalSize.cols + (c - 1)
                guard idx < backBuffer.count, idx < currentBuffer.count else { continue }
                let backCell = backBuffer[idx]
                let currentCell = currentBuffer[idx]

                if backCell != currentCell {
                    if r != lastRow || c != lastCol + 1 {
                        output += "\u{001B}[\(r);\(c)H"
                    }
                    output += backCell.rendered
                    currentBuffer[idx] = backCell
                    lastRow = r
                    lastCol = c
                }
            }
        }

        if !output.isEmpty {
            print(output, terminator: "")
            fflush(stdout)
        }
    }

    public func addToFrame(row: Int, col: Int, text: String) {
        guard row >= 1 && row <= terminalSize.rows && col >= 1 && col <= terminalSize.cols else { return }

        var currentCol = col
        var currentStyle = Style.reset
        var foreground: Color?
        var background: Color?

        // Accurate ANSI parsing and distribution
        let pattern = "\\u{001B}\\[([0-9;]*)m"
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        var lastEnd = text.startIndex
        let matches = regex?.matches(in: text, options: [], range: nsRange) ?? []

        func processText(_ plainText: String) {
            for char in plainText {
                if currentCol > terminalSize.cols { break }
                let idx = (row - 1) * terminalSize.cols + (currentCol - 1)
                guard idx < backBuffer.count else { break }

                let cellRendered = renderCell(char, style: currentStyle, fg: foreground, bg: background)
                backBuffer[idx] = TUICell(char: char, color: foreground, bg: background, style: currentStyle, rendered: cellRendered)
                currentCol += 1
            }
        }

        for match in matches {
            // Text before the match
            if let range = Range(NSRange(location: lastEnd.utf16Offset(in: text), length: match.range.location - lastEnd.utf16Offset(in: text)), in: text) {
                processText(String(text[range]))
            }

            // Extract and apply codes
            if let codeRange = Range(match.range(at: 1), in: text) {
                let codes = String(text[codeRange])
                for code in codes.split(separator: ";") {
                    applyANSICode(String(code), style: &currentStyle, fg: &foreground, bg: &background)
                }
            }

            lastEnd = text.index(text.startIndex, offsetBy: match.range.location + match.range.length)
        }

        // Remaining text after last match
        if lastEnd < text.endIndex {
            processText(String(text[lastEnd...]))
        }
    }

    private func applyANSICode(_ code: String, style: inout Style, fg: inout Color?, bg: inout Color?) {
        switch code {
        case "0": style = .reset; fg = nil; bg = nil
        case "1": style = .bold
        case "2": style = .dim
        case "3": style = .italic
        case "30"..."37", "90"..."97": fg = Color(rawValue: code)
        case "40"..."47", "100"..."107":
            if let c = Int(code) {
                bg = Color(rawValue: String(c - 10))
            }
        default: break
        }
    }

    private func renderCell(_ char: Character, style: Style, fg: Color?, bg: Color?) -> String {
        var codes: [String] = []
        if style != .reset { codes.append(style.rawValue) }
        if let fg = fg { codes.append(fg.rawValue) }
        if let bg = bg, let c = Int(bg.rawValue) {
            codes.append(String(c + 10))
        }

        if codes.isEmpty { return String(char) }
        return "\u{001B}[\(codes.joined(separator: ";"))m\(char)\u{001B}[0m"
    }

    private func stripANSI(_ text: String) -> String {
        return text.replacingOccurrences(of: #"\u{001B}\[[^m]*m"#, with: "", options: .regularExpression)
    }

    public func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
    }

    public func showCursor() {
        print("\u{001B}[?25h", terminator: "")
    }

    public func moveCursor(row: Int, col: Int) {
        print("\u{001B}[\(row);\(col)H", terminator: "")
        fflush(stdout)
    }

    public func copyToClipboard(_ text: String) {
        let base64 = Data(text.utf8).base64EncodedString()
        print("\u{001B}]52;c;\(base64)\u{0007}", terminator: "")
        fflush(stdout)
    }

    // MARK: - Color and Style

    public enum Color: String, Sendable {
        case black = "30"
        case red = "31"
        case green = "32"
        case yellow = "33"
        case blue = "34"
        case magenta = "35"
        case cyan = "36"
        case white = "37"
        case brightBlack = "90"
        case brightRed = "91"
        case brightGreen = "92"
        case brightYellow = "93"
        case brightBlue = "94"
        case brightMagenta = "95"
        case brightCyan = "96"
        case brightWhite = "97"
    }

    public enum Style: String, Sendable {
        case reset = "0"
        case bold = "1"
        case dim = "2"
        case italic = "3"
        case underline = "4"
        case blink = "5"
        case reverse = "7"
        case hidden = "8"
    }

    public nonisolated func styled(_ text: String, style: Theme.Style) -> String {
        var codes: [String] = []

        if style.bold { codes.append("1") }
        if style.dim { codes.append("2") }
        if style.italic { codes.append("3") }

        if let color = style.color {
            codes.append(color.rawValue)
        }
        if let bg = style.bg, let c = Int(bg.rawValue) {
            codes.append(String(c + 10))
        }

        guard !codes.isEmpty else { return text }
        return "\u{001B}[\(codes.joined(separator: ";"))m\(text)\u{001B}[0m"
    }

    public nonisolated func styled(_ text: String, color: Color? = nil, bg: Color? = nil, style: Style? = nil) -> String {
        var codes: [String] = []
        if let style = style { codes.append(style.rawValue) }
        if let color = color { codes.append(color.rawValue) }
        if let bg = bg, let c = Int(bg.rawValue) {
            codes.append(String(c + 10))
        }

        if codes.isEmpty { return text }
        return "\u{001B}[\(codes.joined(separator: ";"))m\(text)\u{001B}[0m"
    }

    public func renderText(row: Int, col: Int, text: String) {
        addToFrame(row: row, col: col, text: text)
    }

    // MARK: - Markdown Rendering

    public func renderMarkdown(row: Int, col: Int, text: String, maxWidth: Int, theme: Theme) -> Int {
        // Simple Markdown parser
        var currentRow = row
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        var inCodeBlock = false

        for line in lines {
            let lineStr = String(line)

            // Code block handling
            if lineStr.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inCodeBlock.toggle()
                let style = theme.codeBlock
                let border = String(repeating: "─", count: min(lineStr.count, maxWidth))
                addToFrame(row: currentRow, col: col, text: styled(border, style: style))
                currentRow += 1
                continue
            }

            if inCodeBlock {
                addToFrame(row: currentRow, col: col, text: styled(lineStr, style: theme.codeBlock))
                currentRow += 1
                continue
            }

            // Word wrap and inline formatting
            let wrapped = wordWrap(lineStr, width: maxWidth)
            for wrappedLine in wrapped {
                // Basic parsing for **bold** and `code`
                let formatted = formatInline(wrappedLine, theme: theme)
                addToFrame(row: currentRow, col: col, text: formatted)
                currentRow += 1
            }
        }

        return currentRow - row // Height used
    }

    private func wordWrap(_ text: String, width: Int) -> [String] {
        var lines: [String] = []
        var currentLine = ""
        for word in text.split(separator: " ") {
            if currentLine.count + word.count + 1 > width {
                if !currentLine.isEmpty { lines.append(currentLine); currentLine = "" }
            }
            if !currentLine.isEmpty { currentLine += " " }
            currentLine += word
        }
        if !currentLine.isEmpty { lines.append(currentLine) }
        return lines.isEmpty ? [""] : lines
    }

    private func formatInline(_ text: String, theme: Theme) -> String {
        var result = text

        // Bold **...**
        let parts = result.components(separatedBy: "**")
        if parts.count > 1 {
            var newResult = ""
            for (i, part) in parts.enumerated() {
                if i % 2 == 1 {
                    newResult += styled(part, style: Theme.Style(bold: true))
                } else {
                    newResult += styled(part, style: theme.text)
                }
            }
            result = newResult
        } else {
            result = styled(result, style: theme.text)
        }

        return result
    }

    // MARK: - Box Drawing

    public func drawBox(row: Int, col: Int, width: Int, height: Int, title: String? = nil, color: Color? = nil) {
        let topLeft = "╭"
        let topRight = "╮"
        let bottomLeft = "╰"
        let bottomRight = "╯"
        let horizontal = "─"
        let vertical = "│"

        var topBorder = topLeft + String(repeating: horizontal, count: width - 2) + topRight
        if let title = title, title.count < width - 4 {
            let titleStr = " \(title) "
            let pos = (width - titleStr.count) / 2
            let startIndex = topBorder.index(topBorder.startIndex, offsetBy: pos)
            let endIndex = topBorder.index(startIndex, offsetBy: titleStr.count)
            topBorder.replaceSubrange(startIndex..<endIndex, with: titleStr)
        }

        if let color = color {
            topBorder = styled(topBorder, color: color)
        }

        addToFrame(row: row, col: col, text: topBorder)

        for i in 1..<height - 1 {
            let side = color != nil ? styled(vertical, color: color) : vertical
            let padding = String(repeating: " ", count: width - 2)
            addToFrame(row: row + i, col: col, text: side + padding + side)
        }

        var bottomBorder = bottomLeft + String(repeating: horizontal, count: width - 2) + bottomRight
        if let color = color {
            bottomBorder = styled(bottomBorder, color: color)
        }
        addToFrame(row: row + height - 1, col: col, text: bottomBorder)
    }

    // MARK: - Legacy / Helper Render Methods

    public func renderMultiline(startRow: Int, col: Int, lines: [String], maxWidth: Int? = nil) {
        for (i, line) in lines.enumerated() {
            var text = line
            if let maxWidth = maxWidth {
                text = String(line.prefix(maxWidth))
            }
            addToFrame(row: startRow + i, col: col, text: text)
        }
    }

    public func renderProgressBar(row: Int, col: Int, width: Int, progress: Double, label: String? = nil) {
        let percentage = min(max(progress, 0.0), 1.0)
        let filled = Int(Double(width) * percentage)
        let empty = width - filled

        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        let percentText = String(format: " %.0f%%", percentage * 100)

        let text: String
        if let label = label {
            text = "\(label): [\(bar)]\(percentText)"
        } else {
            text = "[\(bar)]\(percentText)"
        }

        addToFrame(row: row, col: col, text: text)
    }

    private let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var spinnerIndex = 0

    public func renderSpinner(row: Int, col: Int, label: String? = nil) {
        let frame = spinnerFrames[spinnerIndex % spinnerFrames.count]
        spinnerIndex += 1

        let coloredFrame = styled(frame, color: .cyan)
        let text = label != nil ? "\(coloredFrame) \(label!)" : coloredFrame

        addToFrame(row: row, col: col, text: text)
    }
}
