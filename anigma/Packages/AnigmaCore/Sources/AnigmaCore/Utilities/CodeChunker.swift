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
        switch config.language.lowercased() {
        case "python", "py":
            return chunkPython(sourceCode)
        default:
            return chunkCStyle(sourceCode)
        }
    }
    
    // Chunking for C-style languages (Swift, C++, Java, JS, etc.) using brace counting
    private static func chunkCStyle(_ sourceCode: String) -> [SemanticChunk] {
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
            
            // Ignore comments for brace counting
            let uncommented = removeComments(line)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect start of significant block
            if !inChunk && isSignificantDefinition(trimmed) {
                inChunk = true
                startLine = index
                chunkStartOffset = currentOffset
                currentChunkLines.append(line)
                braceBalance += uncommented.filter { $0 == "{" }.count
                braceBalance -= uncommented.filter { $0 == "}" }.count
                
                // If single line definition (e.g. protocol func without body or one-liner)
                if braceBalance == 0 && !trimmed.hasSuffix("{") {
                     chunks.append(SemanticChunk(
                        content: currentChunkLines.joined(separator: "\n"),
                        startLine: startLine,
                        endLine: index,
                        startOffset: chunkStartOffset,
                        endOffset: currentOffset + lineLength - 1
                    ))
                    inChunk = false
                    currentChunkLines = []
                }
                
                currentOffset += lineLength
                continue
            }
            
            if inChunk {
                currentChunkLines.append(line)
                braceBalance += uncommented.filter { $0 == "{" }.count
                braceBalance -= uncommented.filter { $0 == "}" }.count
                currentOffset += lineLength
                
                if braceBalance <= 0 {
                    // End of chunk
                    chunks.append(SemanticChunk(
                        content: currentChunkLines.joined(separator: "\n"),
                        startLine: startLine,
                        endLine: index,
                        startOffset: chunkStartOffset,
                        endOffset: currentOffset - 1
                    ))
                    inChunk = false
                    currentChunkLines = []
                    braceBalance = 0 // Reset to handle malformed code gracefully
                }
            } else {
                currentOffset += lineLength
            }
        }
        
        return chunks
    }
    
    // Chunking for Python using indentation
    private static func chunkPython(_ sourceCode: String) -> [SemanticChunk] {
        var chunks: [SemanticChunk] = []
        let lines = sourceCode.components(separatedBy: .newlines)
        
        var currentChunkLines: [String] = []
        var inChunk = false
        var chunkIndentLevel = 0
        var startLine = 0
        var currentOffset = 0
        var chunkStartOffset = 0
        
        for (index, line) in lines.enumerated() {
            let lineLength = line.utf8.count + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines or comments when detecting start, but keep them if inside chunk
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                if inChunk {
                    currentChunkLines.append(line)
                }
                currentOffset += lineLength
                continue
            }
            
            let indentLevel = line.prefix(while: { $0 == " " }).count
            
            if !inChunk && (trimmed.hasPrefix("def ") || trimmed.hasPrefix("class ") || trimmed.hasPrefix("async def ")) {
                inChunk = true
                startLine = index
                chunkStartOffset = currentOffset
                chunkIndentLevel = indentLevel
                currentChunkLines.append(line)
                currentOffset += lineLength
                continue
            }
            
            if inChunk {
                // If indentation drops below start level, chunk ends
                // But we must handle multiline strings/brackets (ignored for simple heuristic)
                if indentLevel <= chunkIndentLevel && !trimmed.isEmpty {
                    // End previous chunk
                    chunks.append(SemanticChunk(
                        content: currentChunkLines.joined(separator: "\n"),
                        startLine: startLine,
                        endLine: index - 1,
                        startOffset: chunkStartOffset,
                        endOffset: currentOffset - 1
                    ))
                    
                    // Check if this line starts a NEW chunk
                    if trimmed.hasPrefix("def ") || trimmed.hasPrefix("class ") || trimmed.hasPrefix("async def ") {
                        inChunk = true
                        startLine = index
                        chunkStartOffset = currentOffset
                        chunkIndentLevel = indentLevel
                        currentChunkLines = [line]
                    } else {
                        inChunk = false
                        currentChunkLines = []
                    }
                } else {
                    currentChunkLines.append(line)
                }
            }
            
            currentOffset += lineLength
        }
        
        // Final flush
        if inChunk && !currentChunkLines.isEmpty {
            chunks.append(SemanticChunk(
                content: currentChunkLines.joined(separator: "\n"),
                startLine: startLine,
                endLine: lines.count - 1,
                startOffset: chunkStartOffset,
                endOffset: currentOffset - 1
            ))
        }
        
        return chunks
    }
    
    private static func removeComments(_ line: String) -> String {
        // Simple removal of // comments and strings to avoid counting braces inside them
        // This is a rough heuristic.
        var result = ""
        var inString = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                inString.toggle()
            }
            
            if !inString && char == "/" {
                if line.index(after: i) < line.endIndex && line[line.index(after: i)] == "/" {
                    break // Comment starts
                }
            }
            
            if !inString {
                result.append(char)
            }
            
            i = line.index(after: i)
        }
        
        return result
    }
    
    private static func isSignificantDefinition(_ trimmed: String) -> Bool {
        return trimmed.hasPrefix("func ") ||
               trimmed.hasPrefix("class ") ||
               trimmed.hasPrefix("struct ") ||
               trimmed.hasPrefix("extension ") ||
               trimmed.hasPrefix("enum ") ||
               trimmed.hasPrefix("protocol ") ||
               trimmed.hasPrefix("public ") ||
               trimmed.hasPrefix("private ") ||
               trimmed.hasPrefix("internal ") ||
               trimmed.hasPrefix("static ") ||
               trimmed.hasPrefix("final ")
    }
}
