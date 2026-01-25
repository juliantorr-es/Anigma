//
//  OutputTruncator.swift
//  HarmoniaModule
//
//  Middleware for automatically truncating large tool outputs and saving them as artifacts.
//

@preconcurrency import Foundation
import AnigmaPrimitives

public enum OutputTruncator {
    public static let maxLines = 1000
    public static let maxBytes = 32 * 1024 // 32KB

    public enum TruncationResult {
        case full(Data)
        case truncated(preview: String, artifactPath: String, originalSize: Int)
    }

    /// Truncates tool output if it exceeds limits and saves full content to disk.
    public static func process(
        output: Data,
        toolName: String,
        sessionId: String,
        repoRoot: URL
    ) throws -> TruncationResult {
        let size = output.count

        // If within limits, return full output
        if size <= maxBytes {
            return .full(output)
        }

        // Exceeds bytes, needs truncation
        guard let text = String(data: output, encoding: .utf8) else {
            // Binary data, always save as artifact if large
            let artifactPath = try saveArtifact(output, toolName: toolName, sessionId: sessionId, repoRoot: repoRoot)
            return .truncated(
                preview: "[Binary data truncated]",
                artifactPath: artifactPath,
                originalSize: size
            )
        }

        let lines = text.components(separatedBy: .newlines)
        if lines.count <= maxLines && size <= maxBytes {
            return .full(output)
        }

        // Truncate text
        let previewLines = lines.prefix(maxLines)
        let previewText = previewLines.joined(separator: "\n")
        let artifactPath = try saveArtifact(output, toolName: toolName, sessionId: sessionId, repoRoot: repoRoot)

        let hint = "\n\n... [Output truncated to \(maxLines) lines]. Full output saved to: \(artifactPath)"
        return .truncated(
            preview: previewText + hint,
            artifactPath: artifactPath,
            originalSize: size
        )
    }

    private static func saveArtifact(
        _ data: Data,
        toolName: String,
        sessionId: String,
        repoRoot: URL
    ) throws -> String {
        let artifactsDir = repoRoot.appendingPathComponent(".anigma/artifacts/tool-outputs/\(sessionId)")
        try FileManager.default.createDirectory(at: artifactsDir, withIntermediateDirectories: true)

        let filename = "\(toolName)_\(UUID().uuidString.prefix(8)).log"
        let fileURL = artifactsDir.appendingPathComponent(filename)
        try data.write(to: fileURL)

        // Return relative path for portability
        return ".anigma/artifacts/tool-outputs/\(sessionId)/\(filename)"
    }
}
