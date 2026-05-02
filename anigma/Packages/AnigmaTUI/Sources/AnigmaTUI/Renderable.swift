import Foundation

public struct Cell: Equatable, Sendable {
    public var char: Character
    public var foreground: Color?
    public var background: Color?
    public var attributes: TextAttributes

    public init(
        char: Character = " ",
        foreground: Color? = nil,
        background: Color? = nil,
        attributes: TextAttributes = []
    ) {
        self.char = char
        self.foreground = foreground
        self.background = background
        self.attributes = attributes
    }
}

public final class TerminalBuffer {
    public private(set) var size: Size
    public private(set) var cells: [Cell]

    public init(size: Size) {
        self.size = size
        self.cells = Array(repeating: Cell(), count: size.width * size.height)
    }

    public func setCell(_ cell: Cell, at point: Point) {
        guard point.x >= 0 && point.x < size.width && point.y >= 0 && point.y < size.height else {
            return
        }
        cells[point.y * size.width + point.x] = cell
    }

    public func clear() {
        for i in 0..<cells.count {
            cells[i] = Cell()
        }
    }

    public func resize(to newSize: Size) {
        if size == newSize { return }
        self.size = newSize
        self.cells = Array(repeating: Cell(), count: newSize.width * newSize.height)
    }
}

public protocol Renderable: Sendable {
    func measure(in availableSize: Size) -> Size
    func render(in frame: Rect, to buffer: TerminalBuffer)
}

extension Renderable {
    public func measure(in availableSize: Size) -> Size {
        availableSize
    }
}
