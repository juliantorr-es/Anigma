//
//  CLIRenderer.swift
//  PlatformCore
//
//  CLI renderer implementation for Phase 8.2
//

import Foundation

/// CLI renderer for terminal output
public struct CLIRenderer: Renderer {
    public let supportedFormats: [OutputFormat] = [.cli]

    public init() {}

    public func render(document: ContentDocument, to format: OutputFormat) async throws -> RenderResult {
        guard format == .cli else {
            throw RendererError.unsupportedFormat(format)
        }

        var output = ""

        // Render title with visual emphasis
        output += renderTitle(document.title)
        output += "\n"

        // Render metadata if present
        if let author = document.metadata.author {
            output += "Author: \(author)\n"
        }

        if !document.metadata.tags.isEmpty {
            output += "Tags: \(document.metadata.tags.joined(separator: ", "))\n"
        }

        output += "\n---\n\n"

        // Render sections
        for section in document.sections {
            output += renderSection(section, level: 1)
        }

        let data = output.data(using: .utf8) ?? Data()

        return RenderResult(
            format: .cli,
            data: data,
            metadata: ["generator": "PlatformCore.CLIRenderer"]
        )
    }

    private func renderTitle(_ title: String) -> String {
        let line = String(repeating: "=", count: title.count + 4)
        return "\(line)\n= \(title) =\n\(line)"
    }

    private func renderSection(_ section: ContentSection, level: Int) -> String {
        var output = ""

        let indent = String(repeating: " ", count: (level - 1) * 2)

        // Section header
        if let title = section.title {
            let headerPrefix = String(repeating: "#", count: level)
            output += "\(indent)\(headerPrefix) \(title)\n"
        }

        // Section content
        output += renderContentNode(section.content, indent: indent) + "\n"

        // Subsections
        for subsection in section.subsections {
            output += renderSection(subsection, level: level + 1)
        }

        return output
    }

    private func renderContentNode(_ node: ContentNode, indent: String = "") -> String {
        switch node {
        case .text(let text):
            return "\(indent)\(text)"

        case .paragraph(let children):
            let childOutput = children.map { renderContentNode($0, indent: indent) }.joined(separator: " ")
            return "\(indent)\(childOutput)"

        case .heading(let level, let text):
            let prefix = String(repeating: "#", count: level)
            return "\(indent)\(prefix) \(text)"

        case .list(let items, let type):
            var output = ""
            for (index, item) in items.enumerated() {
                let bullet = type == .ordered ? "\(index + 1)." : "•"
                let childIndent = indent + "  "
                output += "\(indent)\(bullet) \(renderContentNode(item, indent: childIndent))\n"
            }
            return output.trimmingCharacters(in: .newlines)

        case .table(let rows):
            return renderTableToCLI(rows, indent: indent)

        case .image(let image):
            var description = "Image"
            if let title = image.title {
                description = "Image: \(title)"
            }
            if let alt = image.alt {
                description += " (\(alt))"
            }
            return "\(indent)[\(description)]"

        case .link(let url, let text):
            return "\(indent)\(text) (\(url))"

        case .code(let code, let language):
            let langInfo = language.map { " [\($0)]" } ?? ""
            let codeIndent = indent + "  "

            // Apply syntax highlighting
            let highlightedCode = SyntaxHighlighter.highlight(code, language: language)
            let lines = highlightedCode.split(separator: "\n", omittingEmptySubsequences: false)

            var output = "\(indent)```\(langInfo)\n"
            for line in lines {
                output += "\(codeIndent)\(line)\n"
            }
            output += "\(indent)```"
            return output

        case .container(let children):
            return children.map { renderContentNode($0, indent: indent) }.joined(separator: "\n")
        }
    }

    private func renderTableToCLI(_ rows: [[ContentNode]], indent: String) -> String {
        guard !rows.isEmpty else { return "" }

        // Calculate column widths
        let numColumns = rows.map { $0.count }.max() ?? 0
        guard numColumns > 0 else { return "" }

        var columnWidths: [Int] = Array(repeating: 0, count: numColumns)

        for row in rows {
            for (index, cell) in row.enumerated() {
                let cellText = renderContentNode(cell).count
                columnWidths[index] = max(columnWidths[index], cellText)
            }
        }

        var output = ""

        // Render header row (first row) with separator
        if let firstRow = rows.first {
            output += renderTableRow(firstRow, widths: columnWidths, indent: indent)
            output += "\n"
            output += renderTableSeparator(widths: columnWidths, indent: indent)
            output += "\n"

            // Render data rows
            for row in rows.dropFirst() {
                output += renderTableRow(row, widths: columnWidths, indent: indent)
                output += "\n"
            }
        }

        return output.trimmingCharacters(in: .newlines)
    }

    private func renderTableRow(_ row: [ContentNode], widths: [Int], indent: String) -> String {
        let cells = row.enumerated().map { index, node -> String in
            let text = renderContentNode(node)
            let width = widths[index]
            return text.padding(toLength: width, withPad: " ", startingAt: 0)
        }

        return "\(indent)| \(cells.joined(separator: " | ")) |"
    }

    private func renderTableSeparator(widths: [Int], indent: String) -> String {
        let separators = widths.map { String(repeating: "-", count: $0) }
        return "\(indent)+-\(separators.joined(separator: "-+-"))-+"
    }
}
