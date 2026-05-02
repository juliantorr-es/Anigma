import Foundation

/// Defines the color palette and styles for the TUI
public struct TUITheme: Sendable {
    public struct Style: Sendable {
        public var color: TUIEngine.Color?
        public var bg: TUIEngine.Color?
        public var bold: Bool = false
        public var italic: Bool = false
        public var dim: Bool = false

        public init(color: TUIEngine.Color? = nil, bg: TUIEngine.Color? = nil, bold: Bool = false, italic: Bool = false, dim: Bool = false) {
            self.color = color
            self.bg = bg
            self.bold = bold
            self.italic = italic
            self.dim = dim
        }
    }

    public var border: Style
    public var borderActive: Style
    public var text: Style
    public var userRole: Style
    public var assistantRole: Style
    public var systemRole: Style
    public var input: Style
    public var statusBar: Style
    public var error: Style

    public static let defaultTheme = TUITheme(
        border: Style(color: .white),
        borderActive: Style(color: .cyan, bold: true),
        text: Style(color: .white),
        userRole: Style(color: .brightBlue, bold: true),
        assistantRole: Style(color: .brightGreen, bold: true),
        systemRole: Style(color: .brightBlack, italic: true),
        input: Style(color: .brightWhite),
        statusBar: Style(color: .black, bg: .white),
        error: Style(color: .brightRed, bold: true)
    )

    public static let matrixTheme = TUITheme(
        border: Style(color: .green),
        borderActive: Style(color: .brightGreen, bold: true),
        text: Style(color: .green),
        userRole: Style(color: .brightGreen, bold: true),
        assistantRole: Style(color: .green, bold: true),
        systemRole: Style(color: .green, dim: true),
        input: Style(color: .brightGreen),
        statusBar: Style(color: .black, bg: .green),
        error: Style(color: .red, bold: true)
    )
}

/// Central registry for TUI themes
public actor TUIThemeManager {
    public static let shared = TUIThemeManager()

    private var currentTheme: TUITheme = .defaultTheme

    private init() {}

    public func getTheme() -> TUITheme {
        return currentTheme
    }

    public func setTheme(_ theme: TUITheme) {
        currentTheme = theme
        // Notify components via event bus
        Task {
            await TUIEventBus.shared.publish(.statusUpdated(message: "Theme updated!"))
        }
    }
}
