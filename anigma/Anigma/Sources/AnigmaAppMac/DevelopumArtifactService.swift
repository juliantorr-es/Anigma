//
//  DevelopumArtifactService.swift
//  AnigmaAppMac
//
//  Lightweight artifact loader for the develop workbench.
//

import Foundation

struct CodeChunk: Identifiable, Hashable {
    let id: UUID
    let index: Int
    let text: String
    let lineRange: ClosedRange<Int>
}

actor DevelopumArtifactService {
    private let maxChunkLines = 160
    private let maxFileSizeBytes = 2_000_000

    func loadChunks(from url: URL) async throws -> [CodeChunk] {
        let fileData = try Data(contentsOf: url)
        guard fileData.count <= maxFileSizeBytes else {
            let message = "File is too large to preview (\(fileData.count) bytes)."
            throw ArtifactLoadError.tooLarge(message)
        }
        guard let fileText = String(data: fileData, encoding: .utf8) else {
            throw ArtifactLoadError.unreadable
        }

        let lines = fileText.split(separator: "\n", omittingEmptySubsequences: false)
        var chunks: [CodeChunk] = []
        var index = 0
        var start = 0

        while start < lines.count {
            let end = min(start + maxChunkLines, lines.count)
            let slice = lines[start..<end]
            let text = slice.joined(separator: "\n")
            let chunk = CodeChunk(
                id: UUID(),
                index: index,
                text: text,
                lineRange: (start + 1)...end
            )
            chunks.append(chunk)
            index += 1
            start = end
        }

        if chunks.isEmpty {
            chunks = [
                CodeChunk(
                    id: UUID(),
                    index: 0,
                    text: "",
                    lineRange: 1...1
                )
            ]
        }

        return chunks
    }
}

enum ArtifactLoadError: LocalizedError {
    case tooLarge(String)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .tooLarge(let message):
            return message
        case .unreadable:
            return "Unable to decode the file as UTF-8 text."
        }
    }
}
