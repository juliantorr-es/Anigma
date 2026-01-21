import Foundation

// MARK: - VirtualVStack
/// Efficiently renders only the visible portion of a massive list
public struct VirtualVStack: Renderable {
    public var itemCount: Int
    public var itemHeight: Int
    public var scrollOffset: Int
    public var renderItem: @Sendable (Int, Rect, TerminalBuffer) -> Void

    public func measure(in availableSize: Size) -> Size {
        availableSize
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let visibleStart = scrollOffset / itemHeight
        let visibleEnd = min(itemCount, (scrollOffset + frame.size.height) / itemHeight + 1)

        for i in visibleStart..<visibleEnd {
            let itemY = frame.origin.y + (i * itemHeight) - scrollOffset
            let itemFrame = Rect(x: frame.origin.x, y: itemY, width: frame.size.width, height: itemHeight)

            // Render only if within frame bounds
            if itemFrame.origin.y + itemHeight > frame.origin.y && itemFrame.origin.y < frame.origin.y + frame.size.height {
                renderItem(i, itemFrame, buffer)
            }
        }
    }
}
