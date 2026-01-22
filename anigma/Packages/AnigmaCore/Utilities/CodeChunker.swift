//
//  CodeChunker.swift
//  AnigmaCore
//
//  Shared utility for semantic code chunking.
//

import Foundation

public struct SemanticChunkingConfig: Codable, Sendable {
    public let language: String
    public let granularity: String // "function", "block", "file"
    
    public static let `default` = SemanticChunkingConfig(language: "swift", granularity: "function")
    
    public init(language: String = "swift", granularity: String = "function") {
        self.language = language
        self.granularity = granularity
    }
}

public struct SemanticChunk: Sendable {
    public let content: String
    public let startLine: Int
    public let endLine: Int
    public let startOffset: Int
    public let endOffset: Int
    
    public init(content: String, startLine: Int, endLine: Int, startOffset: Int, endOffset: Int) {
        self.content = content
        self.startLine = startLine
        self.endLine = endLine
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

public enum CodeChunker {
    public static func heuristicChunking(sourceCode: String, config: SemanticChunkingConfig = .default) -> [SemanticChunk] {
        var chunks: [SemanticChunk] = []
        let lines = sourceCode.components(separatedBy: .newlines)
        
        var currentChunkLines: [String] = []
        var braceBalance = 0
        var inChunk = false
        var startLine = 0
        var currentOffset = 0
        var chunkStartOffset = 0
        
        for (index, line) in lines.enumerated() {
            let lineLength = line.utf8.count + 1 // +1 for newline
            let uncommented = line.components(separatedBy: "//").first ?? ""
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect start of function/class/struct/extension
            if !inChunk && (
                trimmed.hasPrefix("func ") ||
                trimmed.hasPrefix("class ") ||
                trimmed.hasPrefix("struct ") ||
                trimmed.hasPrefix("extension ") ||
                trimmed.hasPrefix("enum ") ||
                trimmed.hasPrefix("protocol ") ||
                trimmed.hasPrefix("public func ") ||
                trimmed.hasPrefix("public class ") ||
                trimmed.hasPrefix("public struct ") ||
                trimmed.hasPrefix("public extension ") ||
                trimmed.hasPrefix("public enum ") ||
                trimmed.hasPrefix("public protocol ") ||
                trimmed.hasPrefix("private func ")
            ) {
                inChunk = true
                startLine = index
                chunkStartOffset = currentOffset
                currentChunkLines.append(line)
                braceBalance += uncommented.filter { $0 == "{" }.count
                braceBalance -= uncommented.filter { $0 == "}" }.count
                currentOffset += lineLength
                continue
            }
            
            if inChunk {
                currentChunkLines.append(line)
                braceBalance += uncommented.filter { $0 == "{" }.count
                braceBalance -= uncommented.filter { $0 == "}" }.count
                currentOffset += lineLength
                
                if braceBalance == 0 {
                    // End of chunk
                    chunks.append(SemanticChunk(
                        content: currentChunkLines.joined(separator: "\n"),
                        startLine: startLine,
                        endLine: index,
                        startOffset: chunkStartOffset,
                        endOffset: currentOffset - 1 // Exclude trailing newline of last line if needed, but simple is better
                    ))
                    inChunk = false
                    currentChunkLines = []
                }
            } else {
                currentOffset += lineLength
            }
        }
        
        return chunks
    }
}
