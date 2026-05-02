import Foundation

// MARK: - ImageComponent
public struct ImageComponent: Renderable {
    public enum TerminalProtocol: Sendable {
        case iterm2, kitty
    }

    public var protocolType: TerminalProtocol

    public func measure(in availableSize: Size) -> Size {
        // Image rendering in terminal usually occupies specific dimensions
        availableSize
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        // Implementation for emitting iTerm2 or Kitty image escape sequences
        // Note: These bypass the standard character buffer and draw directly to the terminal canvas
    }
}
