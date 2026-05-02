//
//  PlainTextRenderer.swift
//  PlatformCore
//
//  Plain text renderer implementation for Phase 8.2
//

import Foundation

/// Plain text renderer using the platform-agnostic Renderer protocol
public struct PlainTextRenderer: Renderer {
    public let supportedFormats: [OutputFormat] = [.plainText]

    public init() {}

    public func render(document: ContentDocument, to format: OutputFormat) async throws -> RenderResult {
        guard format == .plainText else {
            throw RendererError.unsupportedFormat(format)
        }

        var output = ""

        // Add title
        output += document.title
        output += "\n\n"

        // Render sections
        for section in document.sections {
            output += renderSection(section)
            output += "\n"
        }

        let data = output.data(using: .utf8) ?? Data()

        return RenderResult(
            format: .plainText,
            data: data,
            metadata: ["generator": "PlatformCore.PlainTextRenderer"]
        )
    }

    private func renderSection(_ section: ContentSection, level: Int = 1) -> String {
        var output = ""

        // Section title if present
        if let title = section.title {
            let indent = String(repeating: " ", count: (level - 1) * 2)
            output += "\(indent)\(title)\n"

            // Add underline for section title
            let underline = String(repeating: "-", count: title.count)
            output += "\(indent)\(underline)\n"
        }

        // Section content
        output += renderContentNode(section.content)

        // Subsections
        for subsection in section.subsections {
            output += renderSection(subsection, level: level + 1)
        }

        return output
    }

    private func renderContentNode(_ node: ContentNode) -> String {
        switch node {
        case .text(let text):
            return text

        case .paragraph(let children):
            let childrenOutput = children.map { renderContentNode($0) }.joined(separator: " ")
            return childrenOutput

        case .heading(let level, let text):
            let prefix = String(repeating: "#", count: level)
            return "\(prefix) \(text)"

        case .list(let items, let type):
            var output = ""
            for (index, item) in items.enumerated() {
                let bullet = type == .ordered ? "\(index + 1)." : "•"
                output += "\(bullet) \(renderContentNode(item))\n"
            }
            return output

        case .table(let rows):
            var output = ""
            for (rowIndex, row) in rows.enumerated() {
                let cells = row.map { renderContentNode($0) }.joined(separator: " | ")
                output += cells

                // Add separator after header row
                if rowIndex == 0 {
                    output += "\n"
                    let separatorCells = row.map { String(repeating: "-", count: renderContentNode($0).count) }.joined(separator: "---")
                    output += "\(separatorCells)"
                }
                output += "\n"
            }
            return output

        case .image(let image):
            var description = "Image"
            if let title = image.title {
                description = "Image: \(title)"
            }
            if let alt = image.alt {
                description += " (\(alt))"
            }
            return description

        case .link(let url, let text):
            return "\(text) (\(url))"

        case .code(let code, let language):
            let langInfo = language != nil ? " (\(language!))" : ""
            let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
            var output = "Code\(langInfo):\n"
            for line in lines {
                output += "\(line)\n"
            }
            return output

        case .container(let children):
            return children.map { renderContentNode($0) }.joined(separator: "\n")
        }
    }
}
