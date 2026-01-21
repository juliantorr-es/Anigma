//
//  HTMLRenderer.swift
//  PlatformCore
//
//  HTML renderer implementation for Phase 8.2
//

import Foundation

/// HTML renderer using the platform-agnostic Renderer protocol
public struct HTMLRenderer: Renderer {
    public let supportedFormats: [OutputFormat] = [.html]

    public init() {}

    public func render(document: ContentDocument, to format: OutputFormat) async throws -> RenderResult {
        guard format == .html else {
            throw RendererError.unsupportedFormat(format)
        }

        var htmlContent = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escape(document.title))</title>
            <style>
                body {
                    font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 20px;
                    color: #333;
                }
                h1, h2, h3, h4, h5, h6 { margin-top: 30px; margin-bottom: 10px; }
                h1 { font-size: 2.2em; border-bottom: 1px solid #eee; padding-bottom: 10px; }
                h2 { font-size: 1.8em; }
                h3 { font-size: 1.5em; }
                h4 { font-size: 1.3em; }
                ul, ol { padding-left: 20px; }
                li { margin-bottom: 5px; }
                table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
                th { background-color: #f2f2f2; }
                pre { background-color: #f5f5f5; padding: 15px; border-radius: 5px; overflow-x: auto; }
                code { font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace; background-color: #f5f5f5; padding: 2px 4px; border-radius: 3px; }
                blockquote { border-left: 4px solid #ddd; margin-left: 0; padding-left: 20px; color: #666; }
                img { max-width: 100%; height: auto; }
            </style>
        </head>
        <body>
        """

        // Render document metadata as comments
        htmlContent += "<!-- Document metadata -->\n"
        if let author = document.metadata.author {
            htmlContent += "<!-- Author: \(author) -->\n"
        }
        htmlContent += "<!-- Created: \(document.metadata.createdAt) -->\n"
        htmlContent += "<!-- Modified: \(document.metadata.modifiedAt) -->\n"

        if !document.metadata.tags.isEmpty {
            htmlContent += "<!-- Tags: \(document.metadata.tags.joined(separator: ", ")) -->\n"
        }

        // Render main content
        htmlContent += "<h1>\(escape(document.title))</h1>\n"

        for section in document.sections {
            htmlContent += renderSection(section)
        }

        htmlContent += """
        </body>
        </html>
        """

        return RenderResult(
            format: .html,
            data: htmlContent.data(using: .utf8) ?? Data(),
            metadata: ["generator": "PlatformCore.HTMLRenderer"]
        )
    }

    private func renderSection(_ section: ContentSection) -> String {
        var html = ""

        let headingLevel = min(section.level + 1, 6) // h1 is main title, so sections start at h2

        // Section header if title exists
        if let title = section.title {
            html += "<h\(headingLevel)>\(escape(title))</h\(headingLevel)>\n"
        }

        // Section content
        if !section.subsections.isEmpty {
            html += "<div>\n"
        }

        html += renderContentNode(section.content)

        // Subsections
        for subsection in section.subsections {
            html += renderSection(subsection)
        }

        if !section.subsections.isEmpty {
            html += "</div>\n"
        }

        return html
    }

    private func renderContentNode(_ node: ContentNode) -> String {
        switch node {
        case .text(let text):
            return escape(text)

        case .paragraph(let children):
            let childrenHTML = children.map { renderContentNode($0) }.joined()
            return "<p>\(childrenHTML)</p>"

        case .heading(let level, let text):
            let safeLevel = min(max(level, 1), 6)
            return "<h\(safeLevel)>\(escape(text))</h\(safeLevel)>"

        case .list(let items, let type):
            let listTag = type == .ordered ? "ol" : "ul"
            let itemsHTML = items.map { "<li>\(renderContentNode($0))</li>" }.joined()
            return "<\(listTag)>\(itemsHTML)</\(listTag)>"

        case .table(let rows):
            var tableHTML = "<table>\n"

            // Handle header row (first row)
            if let firstRow = rows.first {
                let headerCells = firstRow.map { "<th>\(renderContentNode($0))</th>" }.joined()
                tableHTML += "<tr>\(headerCells)</tr>\n"

                // Remaining rows are data rows
                for row in rows.dropFirst() {
                    let dataCells = row.map { "<td>\(renderContentNode($0))</td>" }.joined()
                    tableHTML += "<tr>\(dataCells)</tr>\n"
                }
            }

            tableHTML += "</table>"
            return tableHTML

        case .image(let image):
            var imgHTML = "<img"

            imgHTML += " src=\"\(imageSourceToUrl(image.source))\""

            if let alt = image.alt {
                imgHTML += " alt=\"\(escape(alt))\""
            }

            if let width = image.dimensions?.width {
                imgHTML += " width=\"\(width)\""
            }

            if let height = image.dimensions?.height {
                imgHTML += " height=\"\(height)\""
            }

            imgHTML += ">"

            return imgHTML

        case .link(let url, let text):
            return "<a href=\"\(escape(url))\">\(escape(text))</a>"

        case .code(let code, let language):
            let codeTag = language != nil ? "code" : "pre"
            let codeHTML = escape(code)
            return "<\(codeTag)>\(codeHTML)</\(codeTag)>"

        case .container(let children):
            let childrenHTML = children.map { renderContentNode($0) }.joined()
            return "<div>\(childrenHTML)</div>"
        }
    }

    private func imageSourceToUrl(_ source: ResourceSource) -> String {
        switch source {
        case .url(let url):
            return url
        case .data(let data):
            // Convert data to base64 data URL
            return "data:image/png;base64,\(data.base64EncodedString())"
        case .reference(let reference):
            return "#\(reference)" // Use internal reference if no URL
        }
    }

    private func escape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
