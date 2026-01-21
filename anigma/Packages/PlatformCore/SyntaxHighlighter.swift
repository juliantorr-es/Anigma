//
//  SyntaxHighlighter.swift
//  PlatformCore
//
//  Simple regex-based syntax highlighter for CLI output.
//

import Foundation

public struct SyntaxHighlighter {
    public static func highlight(_ code: String, language: String?) -> String {
        guard let lang = language?.lowercased() else { return code }

        switch lang {
        case "swift":
            return highlightSwift(code)
        case "json":
            return highlightJSON(code)
        case "md", "markdown":
            return highlightMarkdown(code)
        default:
            return code
        }
    }

    private static func highlightSwift(_ code: String) -> String {
        var highlighted = code

        // Keywords
        let keywords = [
            "import", "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
            "if", "else", "guard", "switch", "case", "default", "for", "while", "do", "try", "catch",
            "return", "throw", "throws", "async", "await", "public", "private", "internal", "fileprivate",
            "static", "final", "override", "init", "self", "Self", "true", "false", "nil"
        ]

        for keyword in keywords {
            highlighted = highlighted.replacingOccurrences(
                of: "\\b\(keyword)\\b",
                with: ANSI.magenta + keyword + ANSI.reset,
                options: .regularExpression
            )
        }

        // Strings
        highlighted = highlighted.replacingOccurrences(
            of: "\"[^\"]*\"",
            with: ANSI.green + "$0" + ANSI.reset,
            options: .regularExpression
        )

        // Comments (simple single line)
        highlighted = highlighted.replacingOccurrences(
            of: "//.*$",
            with: ANSI.gray + "$0" + ANSI.reset,
            options: [.regularExpression]
        )

        return highlighted
    }

    private static func highlightJSON(_ code: String) -> String {
        var highlighted = code

        // Keys
        highlighted = highlighted.replacingOccurrences(
            of: "\"([^\"]+)\"\\s*:",
            with: ANSI.blue + "\"$1\"" + ANSI.reset + ":",
            options: .regularExpression
        )

        // String values
        highlighted = highlighted.replacingOccurrences(
            of: ":\\s*\"([^\"]+)\"",
            with: ": " + ANSI.green + "\"$1\"" + ANSI.reset,
            options: .regularExpression
        )

        // Numbers/Booleans/Null
        highlighted = highlighted.replacingOccurrences(
            of: ":\\s*([0-9]+|true|false|null)",
            with: ": " + ANSI.yellow + "$1" + ANSI.reset,
            options: .regularExpression
        )

        return highlighted
    }

    private static func highlightMarkdown(_ code: String) -> String {
        var highlighted = code

        // Headers
        highlighted = highlighted.replacingOccurrences(
            of: "^#+ .+$",
            with: ANSI.bold + ANSI.blue + "$0" + ANSI.reset,
            options: [.regularExpression]
        )

        // Bold
        highlighted = highlighted.replacingOccurrences(
            of: "\\*\\*([^*]+)\\*\\*",
            with: ANSI.bold + "$1" + ANSI.reset,
            options: .regularExpression
        )

        // Code blocks
        highlighted = highlighted.replacingOccurrences(
            of: "`([^`]+)`",
            with: ANSI.cyan + "$1" + ANSI.reset,
            options: .regularExpression
        )

        return highlighted
    }
}

public struct ANSI {
    public static let reset = "\u{001B}[0m"
    public static let bold = "\u{001B}[1m"
    public static let red = "\u{001B}[31m"
    public static let green = "\u{001B}[32m"
    public static let yellow = "\u{001B}[33m"
    public static let blue = "\u{001B}[34m"
    public static let magenta = "\u{001B}[35m"
    public static let cyan = "\u{001B}[36m"
    public static let gray = "\u{001B}[90m"
}
