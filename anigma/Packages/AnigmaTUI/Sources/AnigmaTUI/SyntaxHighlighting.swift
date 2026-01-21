import Foundation

// MARK: - SyntaxHighlighter
public protocol SyntaxHighlighter: Sendable {
    func highlight(_ code: String, language: String) -> [HighlightedSegment]
}

public struct HighlightedSegment: Sendable {
    public let text: String
    public let color: Color
    public let attributes: TextAttributes
}

// MARK: - TreeSitterBridge
/// Bridge to AnigmaHostMac's Tree-Sitter implementation
public final class TreeSitterHighlighter: SyntaxHighlighter {
    public init() {}

    public func highlight(_ code: String, language: String) -> [HighlightedSegment] {
        // Implementation will call out to SwiftTreeSitter via PlatformRuntime
        return [HighlightedSegment(text: code, color: .white, attributes: [])]
    }
}

extension DiffView {
    // Enhancement to use highlighter
    public func renderWithHighlighter(_ highlighter: SyntaxHighlighter, in frame: Rect, to buffer: TerminalBuffer) {
        // Implementation for colorized diff lines
    }
}
