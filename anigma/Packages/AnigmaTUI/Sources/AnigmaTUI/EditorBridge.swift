import Foundation

// MARK: - EditorBridge
/// Spawns a system editor (Vim/Nano) for long-form prompt editing
public actor EditorBridge {
    public static let shared = EditorBridge()

    public func openEditor(with initialText: String) async throws -> String {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("anigma_prompt.md")
        try initialText.write(to: tempFile, atomically: true, encoding: .utf8)

        let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "vim"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [editor, tempFile.path]

        // Note: In a TUI, we must temporarily disable raw mode and restore it after
        try process.run()
        process.waitUntilExit()

        return try String(contentsOf: tempFile, encoding: .utf8)
    }
}
