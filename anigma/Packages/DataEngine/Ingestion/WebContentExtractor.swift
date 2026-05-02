//
//  WebContentExtractor.swift
//  DataEngine
//
//  Extracts structured content from raw HTML.
//

import Foundation

public struct StructuredCapture: Sendable, Codable {
    public let title: String
    public let url: URL
    public let summary: String?
    public let textContent: String
    public let tables: [ExtractedTable]
    public let metadata: [String: String]
}

public struct ExtractedTable: Sendable, Codable {
    public let id: String
    public let headers: [String]
    public let rows: [[String]]
}

public actor WebContentExtractor {
    public init() {}

    public func extract(html: String, url: URL, title: String) async -> StructuredCapture {
        let summary = extractMetaContent(html: html, name: "description")
        let text = stripTags(html)
        let tables = extractTables(html: html)

        // Extract generic metadata
        var metadata: [String: String] = [:]
        if let author = extractMetaContent(html: html, name: "author") {
            metadata["author"] = author
        }
        if let keywords = extractMetaContent(html: html, name: "keywords") {
            metadata["keywords"] = keywords
        }

        return StructuredCapture(
            title: title,
            url: url,
            summary: summary,
            textContent: text,
            tables: tables,
            metadata: metadata
        )
    }

    private func extractMetaContent(html: String, name: String) -> String? {
        // Simple regex for <meta name="..." content="...">
        // Note: This is fragile and should be replaced by a real parser in production
        let pattern = "<meta\\s+name=[\"']\(name)[\"']\\s+content=[\"'](.*?)[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }
        return nil
    }

    private func stripTags(_ html: String) -> String {
        // Very basic tag stripping
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTables(html: String) -> [ExtractedTable] {
        guard let tableRegex = try? NSRegularExpression(
            pattern: "<table\\b[^>]*>(.*?)</table>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let htmlRange = NSRange(html.startIndex..., in: html)
        let matches = tableRegex.matches(in: html, range: htmlRange)

        return matches.enumerated().compactMap { index, match in
            guard let tableRange = Range(match.range(at: 1), in: html) else { return nil }
            let tableHTML = String(html[tableRange])
            let rows = extractTableRows(html: tableHTML)
            guard let firstRow = rows.first else {
                return ExtractedTable(id: "table-\(index + 1)", headers: [], rows: [])
            }

            let headers: [String]
            let bodyRows: [[String]]
            if firstRow.isHeaderRow {
                headers = firstRow.cells
                bodyRows = rows.dropFirst().map { $0.cells }
            } else {
                headers = firstRow.cells.enumerated().map { "Column\($0.offset + 1)" }
                bodyRows = rows.map { $0.cells }
            }
            return ExtractedTable(id: "table-\(index + 1)", headers: headers, rows: bodyRows)
        }
    }

    private func extractTableRows(html: String) -> [(isHeaderRow: Bool, cells: [String])] {
        guard let rowRegex = try? NSRegularExpression(
            pattern: "<tr\\b[^>]*>(.*?)</tr>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let htmlRange = NSRange(html.startIndex..., in: html)
        return rowRegex.matches(in: html, range: htmlRange).compactMap { match in
            guard let rowRange = Range(match.range(at: 1), in: html) else { return nil }
            let rowHTML = String(html[rowRange])
            let isHeaderRow = rowHTML.range(of: "<th\\b", options: [.caseInsensitive, .regularExpression]) != nil
            return (isHeaderRow: isHeaderRow, cells: extractTableCells(html: rowHTML))
        }
    }

    private func extractTableCells(html: String) -> [String] {
        guard let cellRegex = try? NSRegularExpression(
            pattern: "<t[dh]\\b[^>]*>(.*?)</t[dh]>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let htmlRange = NSRange(html.startIndex..., in: html)
        return cellRegex.matches(in: html, range: htmlRange).compactMap { match in
            guard let cellRange = Range(match.range(at: 1), in: html) else { return nil }
            return stripTags(String(html[cellRange]))
        }
    }
}
