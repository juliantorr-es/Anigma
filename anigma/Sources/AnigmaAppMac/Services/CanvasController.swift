//
//  CanvasController.swift
//  AnigmaAppMac
//
//  Orchestrates the "Live Preview" (Canvas) for code and web content.
//  Inspired by Sidekick.
//

import Foundation
import AnigmaCore

public enum CanvasContentType: String, Codable, Sendable {
    case code
    case web
    case document
}

public struct CanvasSnapshot: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: CanvasContentType
    public let content: String
    public let language: String?
    public let timestamp: Date

    public init(type: CanvasContentType, content: String, language: String? = nil) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.language = language
        self.timestamp = Date()
    }
}

@MainActor
public class CanvasController: ObservableObject {
    @Published public var currentSnapshot: CanvasSnapshot?
    @Published public var isExtracting: Bool = false
    @Published public var previewURL: URL?

    private let runtime: RuntimeServices
    private let cacheDirectory: URL

    public init(runtime: RuntimeServices) {
        self.runtime = runtime
        self.cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AnigmaCanvas")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Write the current snapshot to a temporary directory for WebView rendering.
    public func materializeForPreview() async throws {
        guard let snapshot = currentSnapshot else { return }

        let sessionDir = cacheDirectory.appendingPathComponent(snapshot.id.uuidString)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        let indexURL = sessionDir.appendingPathComponent("index.html")
        try snapshot.content.write(to: indexURL, atomically: true, encoding: .utf8)

        self.previewURL = indexURL

        // 4. Persist to ArtifactAuthority for long-term storage
        let artifact = Artifact(
            mimeType: snapshot.type == .web ? "text/html" : "text/plain",
            data: snapshot.content.data(using: .utf8)!,
            metadata: ["canvas_id": snapshot.id.uuidString, "language": snapshot.language ?? ""]
        )

        // _ = try await runtime.artifacts.store(artifact, context: .system)
    }

    /// Cleanup old preview files.
    public func cleanup() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    /// Extract code blocks from a message and update the canvas.
    public func extract(from text: String) async {
        isExtracting = true
        defer { isExtracting = false }

        // 1. Regex to find markdown code blocks
        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)

        var extractedCode: [String: String] = [:]

        for match in matches {
            let langRange = match.range(at: 1)
            let codeRange = match.range(at: 2)

            let language = langRange.location != NSNotFound ? (text as NSString).substring(with: langRange) : "text"
            let code = (text as NSString).substring(with: codeRange)

            extractedCode[language] = code
        }

        // 2. Determine type
        if extractedCode["html"] != nil {
            currentSnapshot = CanvasSnapshot(
                type: .web,
                content: buildWebBundle(from: extractedCode)
            )
        } else if let first = extractedCode.first {
            currentSnapshot = CanvasSnapshot(
                type: .code,
                content: first.value,
                language: first.key
            )
        }
    }

    private func buildWebBundle(from extracted: [String: String]) -> String {
        // Simple bundling logic for HTML/CSS/JS
        let html = extracted["html"] ?? "<html><body></body></html>"
        let css = extracted["css"] ?? ""
        let js = extracted["javascript"] ?? extracted["js"] ?? ""

        return """
        \(html)
        <style>\(css)</style>
        <script>\(js)</script>
        """
    }

    /// Export the current canvas content to a file.
    public func export(to url: URL) throws {
        guard let snapshot = currentSnapshot else { return }
        try snapshot.content.write(to: url, atomically: true, encoding: .utf8)
    }
}
