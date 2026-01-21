import Foundation

// MARK: - LSPGutter
/// Renders IDE-style diagnostic squiggles in the gutter
public struct LSPGutter: Renderable {
    public struct Diagnostic: Sendable {
        let line: Int
        let severity: Severity
        let message: String
    }

    public enum Severity: Sendable {
        case error, warning, info
    }

    public var diagnostics: [Diagnostic]

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        for diag in diagnostics {
            let icon: Character = diag.severity == .error ? "✘" : "⚠"
            let color: Color = diag.severity == .error ? .brightRed : .brightYellow
            buffer.setCell(Cell(char: icon, foreground: color), at: Point(x: frame.origin.x, y: frame.origin.y + diag.line))
        }
    }
}
