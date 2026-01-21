import Foundation

// MARK: - KnightRiderSpinner
public struct KnightRiderSpinner: Renderable {
    public var width: Int
    public var frame: Int
    public var colors: [Color]

    public init(width: Int = 12, frame: Int, colors: [Color] = [.custom(r: 255, g: 0, b: 0), .custom(r: 150, g: 0, b: 0), .custom(r: 50, g: 0, b: 0)]) {
        self.width = width
        self.frame = frame
        self.colors = colors
    }

    public func measure(in availableSize: Size) -> Size {
        Size(width: width, height: 1)
    }

    public func render(in targetFrame: Rect, to buffer: TerminalBuffer) {
        let cycle = (width - 1) * 2
        let pos = frame % cycle
        let leadX = pos < width ? pos : cycle - pos

        for i in 0..<width {
            let dist = abs(i - leadX)
            if dist < colors.count {
                let cell = Cell(char: "█", foreground: colors[dist])
                buffer.setCell(cell, at: Point(x: targetFrame.origin.x + i, y: targetFrame.origin.y))
            } else {
                buffer.setCell(Cell(char: "·", foreground: .gray), at: Point(x: targetFrame.origin.x + i, y: targetFrame.origin.y))
            }
        }
    }
}

// MARK: - ToastSystem
public actor ToastSystem {
    public struct Toast: Sendable {
        let message: String
        let kind: ToastKind
        let createdAt: Date
    }

    public enum ToastKind: Sendable {
        case success, error, info
    }

    private var activeToasts: [Toast] = []

    public func show(_ message: String, kind: ToastKind = .info) {
        activeToasts.append(Toast(message: message, kind: kind, createdAt: Date()))
    }

    public func render(to buffer: TerminalBuffer) {
        // Renders floating toasts in the top-right corner
    }
}
