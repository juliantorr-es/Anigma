import Foundation

public struct Size: Hashable, Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public static let zero = Size(width: 0, height: 0)
}

public struct Point: Hashable, Equatable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public static let zero = Point(x: 0, y: 0)
}

public struct Rect: Hashable, Equatable, Sendable {
    public var origin: Point
    public var size: Size

    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }

    public static let zero = Rect(origin: .zero, size: .zero)
}

public enum Color: Hashable, Equatable, Sendable {
    case black
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white
    case gray
    case brightBlack
    case brightRed
    case brightGreen
    case brightYellow
    case brightBlue
    case brightMagenta
    case brightCyan
    case brightWhite
    case custom(r: UInt8, g: UInt8, b: UInt8)

    public var ansiCode: String {
        switch self {
        case .black: return "30"
        case .red: return "31"
        case .green: return "32"
        case .yellow: return "33"
        case .blue: return "34"
        case .magenta: return "35"
        case .cyan: return "36"
        case .white: return "37"
        case .gray, .brightBlack: return "90"
        case .brightRed: return "91"
        case .brightGreen: return "92"
        case .brightYellow: return "93"
        case .brightBlue: return "94"
        case .brightMagenta: return "95"
        case .brightCyan: return "96"
        case .brightWhite: return "97"
        case .custom(let r, let g, let b): return "38;2;\(r);\(g);\(b)"
        }
    }

    public var ansiBackgroundCode: String {
        switch self {
        case .black: return "40"
        case .red: return "41"
        case .green: return "42"
        case .yellow: return "43"
        case .blue: return "44"
        case .magenta: return "45"
        case .cyan: return "46"
        case .white: return "47"
        case .gray, .brightBlack: return "100"
        case .brightRed: return "101"
        case .brightGreen: return "102"
        case .brightYellow: return "103"
        case .brightBlue: return "104"
        case .brightMagenta: return "105"
        case .brightCyan: return "106"
        case .brightWhite: return "107"
        case .custom(let r, let g, let b): return "48;2;\(r);\(g);\(b)"
        }
    }
}

public struct Theme: Sendable {
    public var foreground: Color
    public var background: Color
    public var primary: Color
    public var secondary: Color
    public var accent: Color
    public var success: Color
    public var warning: Color
    public var error: Color
    public var info: Color
    public var border: Color
    public var borderActive: Color

    public init(
        foreground: Color = .white,
        background: Color = .black,
        primary: Color = .cyan,
        secondary: Color = .magenta,
        accent: Color = .yellow,
        success: Color = .green,
        warning: Color = .yellow,
        error: Color = .red,
        info: Color = .blue,
        border: Color = .gray,
        borderActive: Color = .white
    ) {
        self.foreground = foreground
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
        self.border = border
        self.borderActive = borderActive
    }

    public static let anigmaDark = Theme(
        foreground: .brightWhite,
        background: .black,
        primary: .custom(r: 0, g: 255, b: 255),
        secondary: .custom(r: 255, g: 0, b: 255),
        accent: .custom(r: 255, g: 255, b: 0),
        success: .brightGreen,
        warning: .brightYellow,
        error: .brightRed,
        info: .brightBlue,
        border: .gray,
        borderActive: .brightCyan
    )
}

public struct TextAttributes: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let bold = TextAttributes(rawValue: 1 << 0)
    public static let italic = TextAttributes(rawValue: 1 << 1)
    public static let underline = TextAttributes(rawValue: 1 << 2)
    public static let strikethrough = TextAttributes(rawValue: 1 << 3)
}

// MARK: - Flex Layout
public struct Flex: Sendable {
    public let weight: Int
    public let minSize: Int?

    public static let fixed = Flex(weight: 0, minSize: nil)
    public static let flexible = Flex(weight: 1, minSize: 0)

    public init(weight: Int, minSize: Int? = nil) {
        self.weight = weight
        self.minSize = minSize
    }
}

// MARK: - Theme Management
public actor ThemeManager {
    public private(set) var current: Theme
    private var themes: [String: Theme] = [:]

    public init(initial: Theme = .anigmaDark) {
        self.current = initial
    }

    public func loadThemes(from directory: URL) async {
        // Implementation for loading JSON themes matching OpenCode formats
    }

    public func setTheme(_ name: String) {
        if let theme = themes[name] {
            self.current = theme
        }
    }
}
