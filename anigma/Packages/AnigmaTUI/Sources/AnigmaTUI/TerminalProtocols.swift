import Foundation

// MARK: - Clipboard (OSC 52)
public actor Clipboard {
    public static let shared = Clipboard()
    private let stdout = FileHandle.standardOutput

    public func copy(_ text: String) {
        let base64 = Data(text.utf8).base64EncodedString()
        let sequence = "\u{001B}]52;c;\(base64)\u{0007}"
        if let data = sequence.data(using: .utf8) {
            stdout.write(data)
        }
    }
}

// MARK: - TerminalCapabilities
public struct TerminalCapabilities: Sendable {
    public enum ColorDepth: Sendable {
        case basic8, ansi256, trueColor
    }

    public let depth: ColorDepth
    public let supportsImages: Bool
    public let supportsKittyKeyboard: Bool

    public static func detect() -> TerminalCapabilities {
        // Fallback detection logic
        let colorTerm = ProcessInfo.processInfo.environment["COLORTERM"]
        let depth: ColorDepth = (colorTerm == "truecolor" || colorTerm == "24bit") ? .trueColor : .ansi256
        return TerminalCapabilities(depth: depth, supportsImages: true, supportsKittyKeyboard: false)
    }
}
