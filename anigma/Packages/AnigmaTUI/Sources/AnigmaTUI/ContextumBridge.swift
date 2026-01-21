import Foundation

// MARK: - ContextumBridge
public actor ContextumBridge {
    public struct SemanticHint: Sendable {
        let symbol: String
        let signature: String
        let documentation: String?
    }

    public func fetchHint(for symbol: String) async -> SemanticHint? {
        // Bridges to ContextumModule semantic index
        return nil
    }
}

// MARK: - VirtualHintLayer
public struct VirtualHintLayer: Renderable {
    public var hint: String

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        // Renders dim virtual text at the end of current user input
        Text(hint, foreground: .custom(r: 100, g: 100, b: 100), attributes: [.italic]).render(in: frame, to: buffer)
    }
}
