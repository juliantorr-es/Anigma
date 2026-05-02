import Foundation
import CryptoKit

public enum DocumentTruthSourceFormat: String, Codable, Sendable, CaseIterable {
    case markdown
    case html
    case pdf
    case plainText
}

public enum DocumentTruthNodeKind: String, Codable, Sendable, CaseIterable {
    case document
    case page
    case heading
    case paragraph
    case listItem
    case table
    case figure
    case image
    case caption
    case codeBlock
    case blockquote
    case text
}

public struct DocumentTruthSectionNode: Codable, Hashable, Sendable {
    public let nodeID: String
    public let kind: DocumentTruthNodeKind
    public let title: String?
    public let text: String?
    public let pageIndex: Int?
    public let boundingBox: [Double]?
    public let level: Int?
    public let path: [String]
    public let sourceRangeStart: Int?
    public let sourceRangeEnd: Int?
    public let children: [DocumentTruthSectionNode]

    public init(
        nodeID: String,
        kind: DocumentTruthNodeKind,
        title: String? = nil,
        text: String? = nil,
        pageIndex: Int? = nil,
        boundingBox: [Double]? = nil,
        level: Int? = nil,
        path: [String] = [],
        sourceRangeStart: Int? = nil,
        sourceRangeEnd: Int? = nil,
        children: [DocumentTruthSectionNode] = []
    ) {
        self.nodeID = nodeID
        self.kind = kind
        self.title = title
        self.text = text
        self.pageIndex = pageIndex
        self.boundingBox = boundingBox
        self.level = level
        self.path = path
        self.sourceRangeStart = sourceRangeStart
        self.sourceRangeEnd = sourceRangeEnd
        self.children = children
    }
}

public struct DocumentTruthLineage: Codable, Hashable, Sendable {
    public let adapterID: String
    public let sourceFormat: DocumentTruthSourceFormat
    public let sourceMimeType: String
    public let sourceHash: String
    public let sectionPath: [String]
    public let sectionTitle: String?
    public let nodeKind: DocumentTruthNodeKind
    public let pageIndex: Int?
    public let sourceRangeStart: Int?
    public let sourceRangeEnd: Int?
    public let partIndex: Int
    public let partCount: Int
    public let replayKey: String
    public let structuralHash: String
}

public struct DocumentTruthChunkDraft: Codable, Hashable, Sendable {
    public let content: String
    public let contentHash: String
    public let lineage: DocumentTruthLineage
}

public struct DocumentTruthDocument: Codable, Hashable, Sendable {
    public let format: DocumentTruthSourceFormat
    public let mimeType: String
    public let adapterID: String
    public let sourceHash: String
    public let canonicalRef: String
    public let uri: String?
    public let title: String?
    public let sections: [DocumentTruthSectionNode]
    public let manifestHash: String

    public init(
        format: DocumentTruthSourceFormat,
        mimeType: String,
        adapterID: String,
        sourceHash: String,
        canonicalRef: String,
        uri: String? = nil,
        title: String? = nil,
        sections: [DocumentTruthSectionNode],
        manifestHash: String
    ) {
        self.format = format
        self.mimeType = mimeType
        self.adapterID = adapterID
        self.sourceHash = sourceHash
        self.canonicalRef = canonicalRef
        self.uri = uri
        self.title = title
        self.sections = sections
        self.manifestHash = manifestHash
    }

    public func makeChunkDrafts(maxChunkSize: Int = 512, overlapSize: Int = 50) -> [DocumentTruthChunkDraft] {
        var drafts: [DocumentTruthChunkDraft] = []
        for section in sections {
            drafts.append(contentsOf: flatten(section: section, maxChunkSize: maxChunkSize, overlapSize: overlapSize))
        }
        return drafts
    }

    private func flatten(section: DocumentTruthSectionNode, maxChunkSize: Int, overlapSize: Int) -> [DocumentTruthChunkDraft] {
        var drafts: [DocumentTruthChunkDraft] = []
        if let text = section.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let parts = split(text: text, maxChunkSize: maxChunkSize, overlapSize: overlapSize)
            for (index, part) in parts.enumerated() {
                let contentHash = digest(part)
                let lineage = DocumentTruthLineage(
                    adapterID: adapterID,
                    sourceFormat: format,
                    sourceMimeType: mimeType,
                    sourceHash: sourceHash,
                    sectionPath: section.path,
                    sectionTitle: section.title,
                    nodeKind: section.kind,
                    pageIndex: section.pageIndex,
                    sourceRangeStart: section.sourceRangeStart,
                    sourceRangeEnd: section.sourceRangeEnd,
                    partIndex: index,
                    partCount: parts.count,
                    replayKey: digest([
                        sourceHash,
                        canonicalRef,
                        section.path.joined(separator: "/"),
                        section.kind.rawValue,
                        String(section.pageIndex ?? -1),
                        String(index),
                        String(parts.count)
                    ].joined(separator: "|")),
                    structuralHash: digest([
                        section.nodeID,
                        section.kind.rawValue,
                        section.path.joined(separator: "/"),
                        section.title ?? "",
                        String(section.pageIndex ?? -1)
                    ].joined(separator: "|"))
                )
                drafts.append(DocumentTruthChunkDraft(content: part, contentHash: contentHash, lineage: lineage))
            }
        }

        for child in section.children {
            drafts.append(contentsOf: flatten(section: child, maxChunkSize: maxChunkSize, overlapSize: overlapSize))
        }
        return drafts
    }

    private func split(text: String, maxChunkSize: Int, overlapSize: Int) -> [String] {
        guard text.count > maxChunkSize else { return [text] }
        var chunks: [String] = []
        let lines = text.components(separatedBy: .newlines)
        var current = ""
        for line in lines {
            if (current + line).count > maxChunkSize, !current.isEmpty {
                chunks.append(current)
                current = overlapSize > 0 ? String(current.suffix(overlapSize)) : ""
            }
            current += line + "\n"
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks.isEmpty ? [text] : chunks
    }
}

public struct DocumentTruthIngestInput: Sendable {
    public let format: DocumentTruthSourceFormat
    public let content: String?
    public let pdfLayout: PDFLayoutOutput?
    public let mimeType: String
    public let canonicalRef: String
    public let uri: String?
    public let title: String?
    public let metadata: [String: String]

    public init(
        format: DocumentTruthSourceFormat,
        content: String? = nil,
        pdfLayout: PDFLayoutOutput? = nil,
        mimeType: String,
        canonicalRef: String,
        uri: String? = nil,
        title: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.format = format
        self.content = content
        self.pdfLayout = pdfLayout
        self.mimeType = mimeType
        self.canonicalRef = canonicalRef
        self.uri = uri
        self.title = title
        self.metadata = metadata
    }
}

public protocol DocumentTruthIngestAdapter: Sendable {
    var adapterID: String { get }
    var format: DocumentTruthSourceFormat { get }

    func buildDocument(from input: DocumentTruthIngestInput) throws -> DocumentTruthDocument
}

public struct PlainTextDocumentTruthAdapter: DocumentTruthIngestAdapter {
    public let adapterID = "document-truth/plain-text"
    public let format: DocumentTruthSourceFormat = .plainText

    public init() {}

    public func buildDocument(from input: DocumentTruthIngestInput) throws -> DocumentTruthDocument {
        let text = input.content ?? ""
        let sections = buildSections(from: text, input: input)
        return makeDocument(input: input, sections: sections)
    }

    private func buildSections(from text: String, input: DocumentTruthIngestInput) -> [DocumentTruthSectionNode] {
        guard !text.isEmpty else { return [] }
        var sections: [DocumentTruthSectionNode] = []
        var buffer: [String] = []
        var cursor = 0

        func flush() {
            guard !buffer.isEmpty else { return }
            let paragraph = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                sections.append(DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, cursor, paragraph),
                    kind: .paragraph,
                    title: input.title,
                    text: paragraph,
                    path: [input.title ?? input.canonicalRef],
                    sourceRangeStart: cursor,
                    sourceRangeEnd: cursor + paragraph.utf8.count
                ))
            }
            buffer.removeAll()
        }

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flush()
            } else {
                buffer.append(line)
            }
            cursor += line.utf8.count + 1
        }
        flush()
        return sections
    }
}

public struct MarkdownDocumentTruthAdapter: DocumentTruthIngestAdapter {
    public let adapterID = "document-truth/markdown"
    public let format: DocumentTruthSourceFormat = .markdown

    public init() {}

    public func buildDocument(from input: DocumentTruthIngestInput) throws -> DocumentTruthDocument {
        let sections = MarkdownParser.parse(input: input)
        return makeDocument(input: input, sections: sections)
    }
}

public struct HTMLDocumentTruthAdapter: DocumentTruthIngestAdapter {
    public let adapterID = "document-truth/html"
    public let format: DocumentTruthSourceFormat = .html

    public init() {}

    public func buildDocument(from input: DocumentTruthIngestInput) throws -> DocumentTruthDocument {
        let sections = HTMLParser.parse(input: input)
        return makeDocument(input: input, sections: sections)
    }
}

public struct PDFDocumentTruthAdapter: DocumentTruthIngestAdapter {
    public let adapterID = "document-truth/pdf"
    public let format: DocumentTruthSourceFormat = .pdf

    public init() {}

    public func buildDocument(from input: DocumentTruthIngestInput) throws -> DocumentTruthDocument {
        guard let layout = input.pdfLayout else {
            throw NSError(domain: "ContextumModule.DocumentTruth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing PDF layout output"])
        }
        let sections = PDFParser.parse(input: input, layout: layout)
        return makeDocument(input: input, sections: sections)
    }
}

public enum DocumentTruthIngestAdapterFactory {
    public static func makeAdapter(for format: DocumentTruthSourceFormat) -> any DocumentTruthIngestAdapter {
        switch format {
        case .markdown: return MarkdownDocumentTruthAdapter()
        case .html: return HTMLDocumentTruthAdapter()
        case .pdf: return PDFDocumentTruthAdapter()
        case .plainText: return PlainTextDocumentTruthAdapter()
        }
    }
}

// MARK: - Shared document assembly

private func makeDocument(input: DocumentTruthIngestInput, sections: [DocumentTruthSectionNode]) -> DocumentTruthDocument {
    let manifestHash = digest([
        input.format.rawValue,
        input.mimeType,
        input.canonicalRef,
        input.uri ?? "",
        input.title ?? "",
        sections.map(\.nodeID).joined(separator: ",")
    ].joined(separator: "|"))
    return DocumentTruthDocument(
        format: input.format,
        mimeType: input.mimeType,
        adapterID: DocumentTruthIngestAdapterFactory.makeAdapter(for: input.format).adapterID,
        sourceHash: digest([
            input.format.rawValue,
            input.mimeType,
            input.canonicalRef,
            input.content ?? "",
            input.pdfLayout?.blobID ?? ""
        ].joined(separator: "|")),
        canonicalRef: input.canonicalRef,
        uri: input.uri,
        title: input.title,
        sections: sections,
        manifestHash: manifestHash
    )
}

private func stableNodeID(_ canonicalRef: String, _ offset: Int, _ text: String) -> String {
    digest([canonicalRef, String(offset), text].joined(separator: "|"))
}

private func digest(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
}

private enum MarkdownParser {
    static func parse(input: DocumentTruthIngestInput) -> [DocumentTruthSectionNode] {
        guard let text = input.content, !text.isEmpty else { return [] }
        var sections: [DocumentTruthSectionNode] = []
        var headingStack: [(level: Int, title: String)] = []
        var paragraphBuffer: [String] = []
        var cursor = 0

        func currentPath() -> [String] {
            let headings = headingStack.map { $0.title }
            return headings.isEmpty ? [input.title ?? input.canonicalRef] : headings
        }

        func flushParagraph() {
            guard !paragraphBuffer.isEmpty else { return }
            let paragraph = paragraphBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                sections.append(DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, cursor, paragraph),
                    kind: paragraph.hasPrefix("- ") || paragraph.hasPrefix("* ") ? .listItem : .paragraph,
                    title: headingStack.last?.title ?? input.title,
                    text: paragraph,
                    path: currentPath(),
                    sourceRangeStart: max(0, cursor - paragraph.utf8.count),
                    sourceRangeEnd: cursor
                ))
            }
            paragraphBuffer.removeAll()
        }

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let heading = trimmed.headingMatch {
                flushParagraph()
                let level = heading.level
                while let last = headingStack.last, last.level >= level {
                    headingStack.removeLast()
                }
                headingStack.append((level: level, title: heading.title))
                sections.append(DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, cursor, heading.title),
                    kind: .heading,
                    title: heading.title,
                    text: heading.title,
                    level: level,
                    path: headingStack.map(\.title),
                    sourceRangeStart: cursor,
                    sourceRangeEnd: cursor + line.utf8.count
                ))
            } else if trimmed.isEmpty {
                flushParagraph()
            } else {
                paragraphBuffer.append(line)
            }
            cursor += line.utf8.count + 1
        }
        flushParagraph()
        return sections
    }
}

private enum HTMLParser {
    static func parse(input: DocumentTruthIngestInput) -> [DocumentTruthSectionNode] {
        guard let html = input.content, !html.isEmpty else { return [] }
        let stripped = html
            .replacingOccurrences(of: #"(?is)<script.*?</script>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<style.*?</style>"#, with: "", options: .regularExpression)
        var sections: [DocumentTruthSectionNode] = []
        var headingStack: [(level: Int, title: String)] = []

        let blockRegex = try? NSRegularExpression(pattern: #"(?is)<(h[1-6]|p|li|figcaption|caption|blockquote|pre|table|div|section|article)[^>]*>(.*?)</\1>"#)
        let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
        let matches = blockRegex?.matches(in: stripped, range: range) ?? []
        for match in matches {
            guard let tagRange = Range(match.range(at: 1), in: stripped),
                  let bodyRange = Range(match.range(at: 2), in: stripped) else { continue }
            let tag = String(stripped[tagRange]).lowercased()
            let body = stripTags(String(stripped[bodyRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }

            if tag.first == "h", let level = Int(tag.dropFirst()) {
                while let last = headingStack.last, last.level >= level {
                    headingStack.removeLast()
                }
                headingStack.append((level: level, title: body))
                sections.append(DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, match.range.location, body),
                    kind: .heading,
                    title: body,
                    text: body,
                    level: level,
                    path: headingStack.map(\.title),
                    sourceRangeStart: match.range.location,
                    sourceRangeEnd: match.range.location + match.range.length
                ))
            } else {
                sections.append(DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, match.range.location, body),
                    kind: tag == "li" ? .listItem : tag == "table" ? .table : tag == "figcaption" ? .caption : .paragraph,
                    title: headingStack.last?.title,
                    text: body,
                    path: headingStack.map(\.title).isEmpty ? [input.title ?? input.canonicalRef] : headingStack.map(\.title),
                    sourceRangeStart: match.range.location,
                    sourceRangeEnd: match.range.location + match.range.length
                ))
            }
        }

        if sections.isEmpty {
            let fallback = stripTags(stripped).trimmingCharacters(in: .whitespacesAndNewlines)
            if !fallback.isEmpty {
                sections = [DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, 0, fallback),
                    kind: .paragraph,
                    title: input.title,
                    text: fallback,
                    path: [input.title ?? input.canonicalRef],
                    sourceRangeStart: 0,
                    sourceRangeEnd: fallback.utf8.count
                )]
            }
        }

        return sections
    }

    private static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    }
}

private enum PDFParser {
    static func parse(input: DocumentTruthIngestInput, layout: PDFLayoutOutput) -> [DocumentTruthSectionNode] {
        var sections: [DocumentTruthSectionNode] = []
        for page in layout.pages {
            let pagePath = [input.title ?? layout.blobID, "page-\(page.pageIndex + 1)"]
            var children: [DocumentTruthSectionNode] = []

            for (index, segment) in page.segments.enumerated() {
                let kind: DocumentTruthNodeKind = segment.fontSize >= 14 ? .heading : .paragraph
                children.append(DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, index + Int(page.pageIndex), segment.text),
                    kind: kind,
                    title: kind == .heading ? segment.text : nil,
                    text: segment.text,
                    pageIndex: Int(page.pageIndex),
                    boundingBox: [segment.boundingBox.x, segment.boundingBox.y, segment.boundingBox.width, segment.boundingBox.height],
                    path: pagePath,
                    sourceRangeStart: nil,
                    sourceRangeEnd: nil
                ))
            }

            for (index, table) in page.tables.enumerated() {
                children.append(DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, index + Int(page.pageIndex) + 1000, "table"),
                    kind: .table,
                    text: "Table on page \(page.pageIndex + 1)",
                    pageIndex: Int(page.pageIndex),
                    boundingBox: [table.boundingBox.x, table.boundingBox.y, table.boundingBox.width, table.boundingBox.height],
                    path: pagePath
                ))
            }

            for (index, figure) in page.figures.enumerated() {
                children.append(DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, index + Int(page.pageIndex) + 2000, "figure"),
                    kind: .figure,
                    text: "Figure on page \(page.pageIndex + 1)",
                    pageIndex: Int(page.pageIndex),
                    boundingBox: [figure.boundingBox.x, figure.boundingBox.y, figure.boundingBox.width, figure.boundingBox.height],
                    path: pagePath
                ))
            }

            for (index, image) in page.images.enumerated() {
                children.append(DocumentTruthSectionNode(
                    nodeID: stableNodeID(input.canonicalRef, index + Int(page.pageIndex) + 3000, "image"),
                    kind: .image,
                    text: "Image on page \(page.pageIndex + 1)",
                    pageIndex: Int(page.pageIndex),
                    boundingBox: [image.boundingBox.x, image.boundingBox.y, image.boundingBox.width, image.boundingBox.height],
                    path: pagePath
                ))
            }

            sections.append(DocumentTruthSectionNode(
                nodeID: stableNodeID(input.canonicalRef, Int(page.pageIndex), "page"),
                kind: .page,
                title: "Page \(page.pageIndex + 1)",
                pageIndex: Int(page.pageIndex),
                path: pagePath,
                children: children
            ))
        }
        return sections
    }
}

private extension String {
    var headingMatch: (level: Int, title: String)? {
        let pattern = #"^(#{1,6})\s+(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              let hashesRange = Range(match.range(at: 1), in: self),
              let titleRange = Range(match.range(at: 2), in: self) else { return nil }
        return (level: self[hashesRange].count, title: String(self[titleRange]))
    }
}
