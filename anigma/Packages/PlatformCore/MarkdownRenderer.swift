//
//  MarkdownRenderer.swift
//  PlatformCore
//
//  Markdown renderer implementation for Phase 8.2
//

import Foundation

/// Markdown renderer using the platform-agnostic Renderer protocol
public struct MarkdownRenderer: Renderer {
    public let supportedFormats: [OutputFormat] = [.markdown]

    public init() {}

    public func render(document: ContentDocument, to format: OutputFormat) async throws -> RenderResult {
        guard format == .markdown else {
            throw RendererError.unsupportedFormat(format)
        }

        var output = ""

        // Add title with markdown header syntax
        output += "# \(document.title)\n\n"

        // Render sections
        for section in document.sections {
            output += renderSection(section)
        }

        let data = output.data(using: .utf8) ?? Data()

        return RenderResult(
            format: .markdown,
            data: data,
            metadata: ["generator": "PlatformCore.MarkdownRenderer"]
        )
    }

    private func renderSection(_ section: ContentSection) -> String {
        var output = ""

        // Section title if present
        if let title = section.title {
            let headerLevel = section.level + 1 > 6 ? 6 : section.level + 1
            let headerPrefix = String(repeating: "#", count: headerLevel)
            output += "\(headerPrefix) \(title)\n\n"
        }

        // Section content
        output += renderContentNode(section.content)
        output += "\n"

        // Subsections
        for subsection in section.subsections {
            output += renderSection(subsection)
        }

        return output
    }

    private func renderContentNode(_ node: ContentNode) -> String {
        switch node {
        case .text(let text):
            return text

        case .paragraph(let children):
            let childrenOutput = children.map { renderContentNode($0) }.joined(separator: " ")
            return "\(childrenOutput)\n\n"

        case .heading(let level, let text):
            let headerLevel = level > 6 ? 6 : level
            let headerPrefix = String(repeating: "#", count: headerLevel)
            return "\(headerPrefix) \(text)\n\n"

        case .list(let items, let type):
            var output = ""
            for item in items {
                let bullet = type == .ordered ? "1." : "•"
                output += "\(bullet) \(renderContentNode(item))"
                output += "\n"
            }
            return output + "\n"

        case .table(let rows):
            return renderTableToMarkdown(rows)

        case .image(let image):
            var output = "!["
            if let alt = image.alt {
                output += alt
            }
            output += "]("
            output += imageSourceToUrl(image.source)

            if let title = image.title {
                output += " \"\(title)\""
            }

            output += ")\n\n"

            return output

        case .link(let url, let text):
            return "[\(text)](\(url))"

        case .code(let code, let language):
            return "```\(language ?? "")\n\(code)\n```\n\n"

        case .container(let children):
            return children.map { renderContentNode($0) }.joined()
        }
    }

    private func renderTableToMarkdown(_ rows: [[ContentNode]]) -> String {
        guard !rows.isEmpty else { return "" }

        // Calculate column widths
        let numColumns = rows.map { $0.count }.max() ?? 0
        guard numColumns > 0 else { return "" }

        var columnWidths: [Int] = Array(repeating: 0, count: numColumns)

        for row in rows {
            for (index, cell) in row.enumerated() {
                let cellText = renderContentNode(cell).trimmingCharacters(in: .newlines)
                columnWidths[index] = max(columnWidths[index], cellText.count)
            }
        }

        var output = ""

        // Render header row (first row)
        if let firstRow = rows.first {
            let headerCells = firstRow.enumerated().map { index, node -> String in
                let text = renderContentNode(node).trimmingCharacters(in: .newlines)
                return text.padding(toLength: columnWidths[index], withPad: " ", startingAt: 0)
            }
            output += "|" + headerCells.map { " \($0) " }.joined(separator: "|") + "|\n"

            // Render separator row
            let separatorCells = columnWidths.map { String(repeating: "-", count: $0) }
            output += "|" + separatorCells.map { " \($0) " }.joined(separator: "|") + "|\n"

            // Render data rows
            for row in rows.dropFirst() {
                let dataCells = row.enumerated().map { index, node -> String in
                    let text = renderContentNode(node).trimmingCharacters(in: .newlines)
                    return text.padding(toLength: columnWidths[index], withPad: " ", startingAt: 0)
                }
                output += "|" + dataCells.map { " \($0) " }.joined(separator: "|") + "|\n"
            }
        }

        return output + "\n"
    }

    private func imageSourceToUrl(_ source: ResourceSource) -> String {
        switch source {
        case .url(let url):
            return url
        case .data:
            return "data:image/png;base64,<base64_data>"
        case .reference(let reference):
            return "#\(reference)"
        }
    }
}
