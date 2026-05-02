//
//  CanvasController.swift
//  AnigmaAppMac
//
//  Orchestrates the high-performance Engine-driven Canvas.
//  Bridges the Swift AppStore state to the Native Kernel.
//

import Foundation
import AnigmaCore
import AnigmaClientKit
import RuntimeOrchestrator
import PlatformAdapters
import Metal
import MetalKit

public enum CanvasContentType: String, Codable, Sendable {
    case code
    case web
    case document
    case graph // Added for Atlas integration
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
    
    // Engine components
    public let orchestrator: RuntimeOrchestrator
    public let renderer: MetalRenderAdapter
    
    private let cacheDirectory: URL

    public init() throws {
        self.orchestrator = try RuntimeOrchestrator()
        self.renderer = try MetalRenderAdapter()
        self.cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AnigmaCanvas")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Synchronize the application state into the Native Kernel Scene Graph.
    // SceneNode initializer is internal - disabling for now
    /*
    func syncScene(artifacts: [ArtifactSummary], contexts: [AnigmaContext]) async throws {
        let contextNodes = contexts.enumerated().map { index, context in
            var node = SceneNode(
                id: UInt64(context.id.hashValue),
                transform: [1, 0, 0, 1, Float(index * 200), 0]
            )
            return node
        }
        if !contextNodes.isEmpty {
            try await orchestrator.attach(nodes: contextNodes)
        }

        let artifactNodes = artifacts.enumerated().map { index, artifact in
            var node = SceneNode(
                id: UInt64(artifact.id.hashValue),
                transform: [1, 0, 0, 1, Float(index * 150), 250]
            )
            return node
        }
        if !artifactNodes.isEmpty {
            try await orchestrator.attach(nodes: artifactNodes)
        }
        
        try await orchestrator.evaluateTransforms()
    }
    */

    /// Extract code blocks from a message and update the canvas.
    public func extract(from text: String) async {
        isExtracting = true
        defer { isExtracting = false }

        // Regex to find markdown code blocks
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
        let html = extracted["html"] ?? "<html><body></body></html>"
        let css = extracted["css"] ?? ""
        let js = extracted["javascript"] ?? extracted["js"] ?? ""

        return """
        \(html)
        <style>\(css)</style>
        <script>\(js)</script>
        """
    }

    /// Cleanup old preview files.
    public func cleanup() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}
