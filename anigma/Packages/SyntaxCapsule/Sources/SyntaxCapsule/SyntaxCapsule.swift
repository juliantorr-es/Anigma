import Foundation

public enum SyntaxLanguage: Int, Sendable {
    case json = 0
    case swift = 1
    case python = 2
    case markdown = 3
}

public enum SyntaxCapsuleError: Error, Sendable {
    case unavailable(String)
}

public final class SyntaxParser {
    private let language: SyntaxLanguage

    public init(language: SyntaxLanguage) throws {
        self.language = language
    }

    public func parse(source: String) throws -> SyntaxTree {
        // Fallback parser while native bridge is being stabilized.
        SyntaxTree(source: source, language: language)
    }
}

public final class SyntaxTree {
    private let source: String
    private let language: SyntaxLanguage

    internal init(source: String, language: SyntaxLanguage) {
        self.source = source
        self.language = language
    }

    public var rootNode: SyntaxNode? {
        SyntaxNode(
            info: SyntaxNodeInfo(
                type: "document",
                startByte: 0,
                endByte: source.utf8.count,
                startRow: 0,
                startColumn: 0,
                endRow: source.split(separator: "\n").count,
                endColumn: 0
            ),
            text: source,
            children: []
        )
    }

    public var rootNodeString: String {
        source
    }

    public var debugDescription: String {
        "SyntaxTree(language: \(language), bytes: \(source.utf8.count))"
    }
}

public struct SyntaxNodeInfo: Sendable {
    public let type: String
    public let startByte: Int
    public let endByte: Int
    public let startRow: Int
    public let startColumn: Int
    public let endRow: Int
    public let endColumn: Int

    public init(
        type: String,
        startByte: Int,
        endByte: Int,
        startRow: Int,
        startColumn: Int,
        endRow: Int,
        endColumn: Int
    ) {
        self.type = type
        self.startByte = startByte
        self.endByte = endByte
        self.startRow = startRow
        self.startColumn = startColumn
        self.endRow = endRow
        self.endColumn = endColumn
    }
}

public final class SyntaxNode {
    private let childrenStorage: [SyntaxNode]

    public let info: SyntaxNodeInfo
    public let text: String

    internal init(info: SyntaxNodeInfo, text: String, children: [SyntaxNode]) {
        self.info = info
        self.text = text
        self.childrenStorage = children
    }

    public var type: String { info.type }
    public var startPosition: (row: Int, column: Int) { (info.startRow, info.startColumn) }
    public var endPosition: (row: Int, column: Int) { (info.endRow, info.endColumn) }
    public var children: [SyntaxNode] { childrenStorage }
    public var childCount: Int { childrenStorage.count }

    public func child(at index: Int) -> SyntaxNode? {
        guard childrenStorage.indices.contains(index) else { return nil }
        return childrenStorage[index]
    }
}
