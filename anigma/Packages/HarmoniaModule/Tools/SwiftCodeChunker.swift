//
//  SwiftCodeChunker.swift
//  HarmoniaModule
//
//  SwiftSyntax-based chunker for Swift source files.
//  Extracts semantic chunks (functions, classes, structs, enums, protocols, extensions, properties).
//

@preconcurrency import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Swift Code Chunker

/// Extracts semantic code chunks from Swift source files using SwiftSyntax.
public struct SwiftCodeChunker {

    /// Parse a Swift file and extract semantic chunks.
    /// - Parameters:
    ///   - fileURL: URL to the Swift source file.
    ///   - content: Optional file content (if nil, reads from fileURL).
    /// - Returns: Array of semantic code chunks.
    public static func extractChunks(
        from fileURL: URL,
        content: String? = nil
    ) throws -> [CodeChunk] {
        guard FileManager.default.fileExists(atPath: fileURL.path) || content != nil else {
            throw ChunkerError.fileNotFound
        }

        let source = try content ?? String(contentsOf: fileURL, encoding: .utf8)
        let fileHash = try computeFileHash(for: fileURL)

        let syntax = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: fileURL.path, tree: syntax)
        let visitor = ChunkVisitor(converter: converter)
        visitor.walk(syntax)

        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let path = fileURL.path

        let chunks = visitor.chunks.compactMap { spec -> CodeChunk? in
            let content = extractLines(
                lines,
                startLine: spec.startLine,
                endLine: spec.endLine
            )
            guard !content.isEmpty else { return nil }
            return CodeChunk(
                path: path,
                language: "swift",
                symbolName: spec.symbolName,
                symbolKind: spec.symbolKind,
                startLine: spec.startLine,
                endLine: spec.endLine,
                content: content,
                fileHash: fileHash
            )
        }

        return chunks.sorted { lhs, rhs in
            if lhs.startLine != rhs.startLine { return lhs.startLine < rhs.startLine }
            return (lhs.symbolName ?? "") < (rhs.symbolName ?? "")
        }
    }

    /// Compute a hash for file change detection.
    /// - Parameter fileURL: URL to the file.
    /// - Returns: Hash string combining file size and modification date.
    public static func computeFileHash(for fileURL: URL) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let size = attributes[.size] as? Int64,
            let modDate = attributes[.modificationDate] as? Date
        else {
            throw ChunkerError.cannotComputeFileHash
        }
        // Simple hash combining size and timestamp
        return "\(size):\(modDate.timeIntervalSince1970)"
    }
}

// MARK: - Error Types

public enum ChunkerError: Error {
    case cannotComputeFileHash
    case fileNotFound
    case parsingFailed
}

private struct ChunkSpec {
    let symbolName: String?
    let symbolKind: String?
    let startLine: Int
    let endLine: Int
}

private final class ChunkVisitor: SyntaxVisitor {
    let converter: SourceLocationConverter
    private(set) var chunks: [ChunkSpec] = []

    init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node: node, kind: "class", name: node.name.text)
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node: node, kind: "struct", name: node.name.text)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node: node, kind: "enum", name: node.name.text)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node: node, kind: "protocol", name: node.name.text)
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.extendedType.description.trimmingCharacters(in: .whitespacesAndNewlines)
        record(node: node, kind: "extension", name: name)
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node: node, kind: "function", name: node.name.text)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node: node, kind: "initializer", name: "init")
        return .visitChildren
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node: node, kind: "deinitializer", name: "deinit")
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node: node, kind: "subscript", name: "subscript")
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                record(node: node, kind: "property", name: pattern.identifier.text)
            }
        }
        return .visitChildren
    }

    private func record(node: some SyntaxProtocol, kind: String, name: String?) {
        let start = node.startLocation(converter: converter).line
        let end = node.endLocation(converter: converter).line
        let startLine = max(1, start)
        let endLine = max(startLine, end)
        chunks.append(
            ChunkSpec(
                symbolName: name?.trimmingCharacters(in: .whitespacesAndNewlines),
                symbolKind: kind,
                startLine: startLine,
                endLine: endLine
            )
        )
    }
}

private func extractLines(_ lines: [String], startLine: Int, endLine: Int) -> String {
    guard !lines.isEmpty else { return "" }
    let startIndex = max(startLine - 1, 0)
    let endIndex = min(endLine - 1, lines.count - 1)
    guard startIndex <= endIndex else { return "" }
    return lines[startIndex...endIndex].joined(separator: "\n")
}
