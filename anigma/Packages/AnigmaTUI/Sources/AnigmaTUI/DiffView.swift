import Foundation

public struct DiffLine: Sendable {
    public enum Kind: Sendable {
        case added
        case removed
        case unchanged
        case header
    }

    public let kind: Kind
    public let content: String

    public init(kind: Kind, content: String) {
        self.kind = kind
        self.content = content
    }
}

public struct DiffView: Renderable {
    public let lines: [DiffLine]
    public var showLineNumbers: Bool

    public init(lines: [DiffLine], showLineNumbers: Bool = true) {
        self.lines = lines
        self.showLineNumbers = showLineNumbers
    }

    public func measure(in availableSize: Size) -> Size {
        Size(width: availableSize.width, height: min(lines.count, availableSize.height))
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        for (i, line) in lines.enumerated() {
            if i >= frame.size.height { break }

            let backgroundColor: Color?
            let foregroundColor: Color?
            let prefix: String

            switch line.kind {
            case .added:
                backgroundColor = .custom(r: 0, g: 60, b: 0)
                foregroundColor = .brightGreen
                prefix = "+"
            case .removed:
                backgroundColor = .custom(r: 60, g: 0, b: 0)
                foregroundColor = .brightRed
                prefix = "-"
            case .header:
                backgroundColor = .custom(r: 0, g: 0, b: 60)
                foregroundColor = .brightCyan
                prefix = " "
            case .unchanged:
                backgroundColor = nil
                foregroundColor = .gray
                prefix = " "
            }

            let fullLine = "\(prefix) \(line.content)"
            let truncatedLine = String(fullLine.prefix(frame.size.width))

            for (x, char) in truncatedLine.enumerated() {
                buffer.setCell(
                    Cell(char: char, foreground: foregroundColor, background: backgroundColor),
                    at: Point(x: frame.origin.x + x, y: frame.origin.y + i)
                )
            }

            // Fill remaining background
            if let bg = backgroundColor {
                for x in truncatedLine.count..<frame.size.width {
                    buffer.setCell(
                        Cell(char: " ", background: bg),
                        at: Point(x: frame.origin.x + x, y: frame.origin.y + i)
                    )
                }
            }
        }
    }
}
