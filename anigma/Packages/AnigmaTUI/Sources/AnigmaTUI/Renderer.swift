import Foundation

// MARK: - Spinner
public struct Spinner: Renderable {
    public var width: Int
    public var frame: Int
    public var color: Color

    public init(width: Int = 10, frame: Int, color: Color = .cyan) {
        self.width = width
        self.frame = frame
        self.color = color
    }

    public func measure(in availableSize: Size) -> Size {
        Size(width: width, height: 1)
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let cycle = width * 2 - 2
        let pos = self.frame % cycle
        let x = pos < width ? pos : cycle - pos

        for i in 0..<width {
            let char: Character = i == x ? "█" : "░"
            buffer.setCell(Cell(char: char, foreground: color), at: Point(x: frame.origin.x + i, y: frame.origin.y))
        }
    }
}

// MARK: - TerminalRenderer
public actor TerminalRenderer {
    private var buffer: TerminalBuffer
    private var previousBuffer: TerminalBuffer?
    private var stdout = FileHandle.standardOutput

    public init(size: Size) {
        self.buffer = TerminalBuffer(size: size)
    }

    public func render(_ root: Renderable) {
        // Prepare back buffer
        let backBuffer = TerminalBuffer(size: buffer.size)
        let frame = Rect(origin: .zero, size: buffer.size)
        root.render(in: frame, to: backBuffer)

        flush(diffing: backBuffer)
        self.previousBuffer = buffer
        self.buffer = backBuffer
    }

    private func flush(diffing newBuffer: TerminalBuffer) {
        var output = ""

        // Optimized rendering: Only emit ANSI codes for changed characters
        for y in 0..<newBuffer.size.height {
            for x in 0..<newBuffer.size.width {
                let index = y * newBuffer.size.width + x
                let newCell = newBuffer.cells[index]
                let oldCell = previousBuffer?.cells[index]

                if newCell != oldCell {
                    // Move cursor and write only the change
                    output += "\u{001B}[\(y + 1);\(x + 1)H"

                    // Style application (simplified)
                    if let fg = newCell.foreground { output += "\u{001B}[\(fg.ansiCode)m" }
                    output += String(newCell.char)
                    output += "\u{001B}[0m" // Reset
                }
            }
        }

        if let data = output.data(using: .utf8) {
            stdout.write(data)
        }
    }
}
