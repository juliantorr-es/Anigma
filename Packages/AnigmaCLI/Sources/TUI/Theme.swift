import Foundation

public struct Theme: Sendable {
    public struct Style: Sendable {
        public let color: TUIEngine.Color?
        public let bg: TUIEngine.Color?
        public let bold: Bool
        public let italic: Bool
        public let dim: Bool

        public init(color: TUIEngine.Color? = nil, bg: TUIEngine.Color? = nil, bold: Bool = false, italic: Bool = false, dim: Bool = false) {
            self.color = color
            self.bg = bg
            self.bold = bold
            self.italic = italic
            self.dim = dim
        }
    }

    // UI Elements
    public let border: Style
    public let borderActive: Style
    public let title: Style
    public let input: Style
    public let inputPlaceholder: Style
    public let statusBar: Style

    // Chat Content
    public let userRole: Style
    public let assistantRole: Style
    public let systemRole: Style
    public let text: Style
    public let codeBlock: Style
    public let inlineCode: Style

    // Defaults
    public static let defaultTheme = Theme(
        border: Style(color: .brightBlack),
        borderActive: Style(color: .cyan),
        title: Style(color: .white, bold: true),
        input: Style(color: .white),
        inputPlaceholder: Style(color: .brightBlack),
        statusBar: Style(color: .black, bg: .white),

        userRole: Style(color: .cyan, bold: true),
        assistantRole: Style(color: .green, bold: true),
        systemRole: Style(color: .yellow, dim: true),
        text: Style(color: .white),
        codeBlock: Style(color: .brightWhite, dim: false),
        inlineCode: Style(color: .magenta)
    )
}
