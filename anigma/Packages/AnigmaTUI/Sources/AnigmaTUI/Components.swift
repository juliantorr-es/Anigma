import Foundation

// MARK: - ScrollBox
public struct ScrollBox: Renderable {
    public var children: [Renderable]
    public var scrollOffset: Int
    public var showScrollbar: Bool

    public init(scrollOffset: Int = 0, showScrollbar: Bool = true, @TUIBuilder content: () -> [Renderable]) {
        self.children = content()
        self.scrollOffset = scrollOffset
        self.showScrollbar = showScrollbar
    }

    public func measure(in availableSize: Size) -> Size {
        availableSize
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        // Create a sub-buffer or use clipping logic
        let contentHeight = children.reduce(0) { $0 + $1.measure(in: frame.size).height }

        var currentY = frame.origin.y - scrollOffset
        for child in children {
            let childSize = child.measure(in: frame.size)
            let childFrame = Rect(origin: Point(x: frame.origin.x, y: currentY), size: childSize)

            // Intersection clipping
            if childFrame.origin.y + childFrame.size.height > frame.origin.y && childFrame.origin.y < frame.origin.y + frame.size.height {
                child.render(in: childFrame, to: buffer)
            }
            currentY += childSize.height
        }

        if showScrollbar && contentHeight > frame.size.height {
            renderScrollbar(in: frame, contentHeight: contentHeight, to: buffer)
        }
    }

    private func renderScrollbar(in frame: Rect, contentHeight: Int, to buffer: TerminalBuffer) {
        let barHeight = max(1, (frame.size.height * frame.size.height) / contentHeight)
        let barPos = (scrollOffset * frame.size.height) / contentHeight

        for i in 0..<frame.size.height {
            let char: Character = (i >= barPos && i < barPos + barHeight) ? "┃" : "│"
            buffer.setCell(Cell(char: char, foreground: .gray), at: Point(x: frame.origin.x + frame.size.width - 1, y: frame.origin.y + i))
        }
    }
}

// MARK: - VStack (Weighted)
public struct WeightedVStack: Renderable {
    private struct Entry {
        let component: Renderable
        let weight: Int
    }
    private var entries: [Entry] = []

    public init() {}

    public mutating func add(_ component: Renderable, weight: Int = 0) {
        entries.append(Entry(component: component, weight: weight))
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        // Logic for distributing space based on weights
    }
}

// MARK: - Text
public struct Text: Renderable {
    public let content: String
    public var foreground: Color?
    public var background: Color?
    public var attributes: TextAttributes

    public init(_ content: String, foreground: Color? = nil, background: Color? = nil, attributes: TextAttributes = []) {
        self.content = content
        self.foreground = foreground
        self.background = background
        self.attributes = attributes
    }

    public func measure(in availableSize: Size) -> Size {
        // Simple word wrap or truncation logic could go here
        // For now, assume single line or manual newlines
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let height = lines.count
        let width = lines.map { $0.count }.max() ?? 0
        return Size(width: min(width, availableSize.width), height: min(height, availableSize.height))
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        for (y, line) in lines.enumerated() {
            if y >= frame.size.height { break }
            for (x, char) in line.enumerated() {
                if x >= frame.size.width { break }
                let cell = Cell(char: char, foreground: foreground, background: background, attributes: attributes)
                buffer.setCell(cell, at: Point(x: frame.origin.x + x, y: frame.origin.y + y))
            }
        }
    }
}

// MARK: - Box
public struct Box: Renderable {
    public var children: [Renderable]
    public var borderColor: Color?
    public var title: String?
    public var padding: Int

    public init(borderColor: Color? = nil, title: String? = nil, padding: Int = 0, @TUIBuilder content: () -> [Renderable]) {
        self.borderColor = borderColor
        self.title = title
        self.padding = padding
        self.children = content()
    }

    public func measure(in availableSize: Size) -> Size {
        availableSize
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        // Render border if color is set
        if let color = borderColor {
            // Top
            buffer.setCell(Cell(char: "┌", foreground: color), at: frame.origin)
            buffer.setCell(Cell(char: "┐", foreground: color), at: Point(x: frame.origin.x + frame.size.width - 1, y: frame.origin.y))
            for x in 1..<(frame.size.width - 1) {
                buffer.setCell(Cell(char: "─", foreground: color), at: Point(x: frame.origin.x + x, y: frame.origin.y))
            }
            // Bottom
            buffer.setCell(Cell(char: "└", foreground: color), at: Point(x: frame.origin.x, y: frame.origin.y + frame.size.height - 1))
            buffer.setCell(Cell(char: "┘", foreground: color), at: Point(x: frame.origin.x + frame.size.width - 1, y: frame.origin.y + frame.size.height - 1))
            for x in 1..<(frame.size.width - 1) {
                buffer.setCell(Cell(char: "─", foreground: color), at: Point(x: frame.origin.x + x, y: frame.origin.y + frame.size.height - 1))
            }
            // Sides
            for y in 1..<(frame.size.height - 1) {
                buffer.setCell(Cell(char: "│", foreground: color), at: Point(x: frame.origin.x, y: frame.origin.y + y))
                buffer.setCell(Cell(char: "│", foreground: color), at: Point(x: frame.origin.x + frame.size.width - 1, y: frame.origin.y + y))
            }

            // Title
            if let title = title {
                let titleText = " \(title) "
                for (i, char) in titleText.enumerated() {
                    if i + 2 >= frame.size.width - 1 { break }
                    buffer.setCell(Cell(char: char, foreground: color), at: Point(x: frame.origin.x + 2 + i, y: frame.origin.y))
                }
            }
        }

        let hasBorder = borderColor != nil
        let innerOrigin = Point(
            x: frame.origin.x + (hasBorder ? 1 : 0) + padding,
            y: frame.origin.y + (hasBorder ? 1 : 0) + padding
        )
        let innerSize = Size(
            width: max(0, frame.size.width - (hasBorder ? 2 : 0) - padding * 2),
            height: max(0, frame.size.height - (hasBorder ? 2 : 0) - padding * 2)
        )

        for child in children {
            let childSize = child.measure(in: innerSize)
            let childFrame = Rect(origin: innerOrigin, size: childSize)
            child.render(in: childFrame, to: buffer)
        }
    }
}

// MARK: - Spacer
public struct Spacer: Renderable {
    public var minLength: Int?

    public init(minLength: Int? = nil) {
        self.minLength = minLength
    }

    public func measure(in availableSize: Size) -> Size {
        Size(width: minLength ?? 0, height: minLength ?? 0)
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        // Spacer just takes up space, renders nothing
    }
}

// MARK: - VStack
public struct VStack: Renderable {
    public var children: [Renderable]
    public var spacing: Int
    public var alignment: Alignment

    public enum Alignment: Sendable {
        case leading, center, trailing
    }

    public init(spacing: Int = 0, alignment: Alignment = .leading, @TUIBuilder content: () -> [Renderable]) {
        self.spacing = spacing
        self.alignment = alignment
        self.children = content()
    }

    public func measure(in availableSize: Size) -> Size {
        let hasSpacer = children.contains { $0 is Spacer }
        if hasSpacer {
            return Size(width: children.map { $0.measure(in: availableSize).width }.max() ?? 0, height: availableSize.height)
        }

        var totalHeight = 0
        var maxWidth = 0
        for child in children {
            let size = child.measure(in: availableSize)
            totalHeight += size.height
            maxWidth = max(maxWidth, size.width)
        }
        totalHeight += spacing * max(0, children.count - 1)
        return Size(width: min(maxWidth, availableSize.width), height: min(totalHeight, availableSize.height))
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let spacers = children.filter { $0 is Spacer }
        let nonSpacers = children.filter { !($0 is Spacer) }

        var totalHeight = nonSpacers.reduce(0) { $0 + $1.measure(in: frame.size).height }
        totalHeight += spacing * max(0, children.count - 1)

        let remainingHeight = max(0, frame.size.height - totalHeight)
        let spacerHeight = spacers.isEmpty ? 0 : remainingHeight / spacers.count

        var currentY = frame.origin.y
        for child in children {
            if currentY >= frame.origin.y + frame.size.height { break }

            let height: Int
            if child is Spacer {
                height = spacerHeight
            } else {
                height = child.measure(in: frame.size).height
            }

            let width = min(frame.size.width, child.measure(in: frame.size).width)
            var x = frame.origin.x
            if alignment == .center {
                x += (frame.size.width - width) / 2
            } else if alignment == .trailing {
                x += frame.size.width - width
            }

            let childFrame = Rect(origin: Point(x: x, y: currentY), size: Size(width: width, height: height))
            child.render(in: childFrame, to: buffer)
            currentY += height + spacing
        }
    }
}

// MARK: - HStack
public struct HStack: Renderable {
    public var children: [Renderable]
    public var spacing: Int
    public var alignment: Alignment

    public enum Alignment: Sendable {
        case top, center, bottom
    }

    public init(spacing: Int = 0, alignment: Alignment = .center, @TUIBuilder content: () -> [Renderable]) {
        self.spacing = spacing
        self.alignment = alignment
        self.children = content()
    }

    public func measure(in availableSize: Size) -> Size {
        let hasSpacer = children.contains { $0 is Spacer }
        if hasSpacer {
            return Size(width: availableSize.width, height: children.map { $0.measure(in: availableSize).height }.max() ?? 0)
        }

        var totalWidth = 0
        var maxHeight = 0
        for child in children {
            let size = child.measure(in: availableSize)
            totalWidth += size.width
            maxHeight = max(maxHeight, size.height)
        }
        totalWidth += spacing * max(0, children.count - 1)
        return Size(width: min(totalWidth, availableSize.width), height: min(maxHeight, availableSize.height))
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let spacers = children.filter { $0 is Spacer }
        let nonSpacers = children.filter { !($0 is Spacer) }

        let nonSpacerWidth = nonSpacers.reduce(0) { $0 + $1.measure(in: frame.size).width }
        let totalSpacing = spacing * max(0, children.count - 1)

        let remainingWidth = max(0, frame.size.width - nonSpacerWidth - totalSpacing)
        let spacerWidth = spacers.isEmpty ? 0 : remainingWidth / spacers.count

        var currentX = frame.origin.x
        for child in children {
            if currentX >= frame.origin.x + frame.size.width { break }

            let width: Int
            if child is Spacer {
                width = spacerWidth
            } else {
                width = child.measure(in: frame.size).width
            }

            let measuredHeight = child.measure(in: frame.size).height
            let height = min(frame.size.height, measuredHeight)
            var y = frame.origin.y
            if alignment == .center {
                y += (frame.size.height - height) / 2
            } else if alignment == .bottom {
                y += frame.size.height - height
            }

            let childFrame = Rect(origin: Point(x: currentX, y: y), size: Size(width: width, height: height))
            child.render(in: childFrame, to: buffer)
            currentX += width + spacing
        }
    }
}
