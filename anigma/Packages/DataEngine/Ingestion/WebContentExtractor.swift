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
        // Placeholder for table extraction logic
        // Real implementation would parse <table> structures
        return []
    }
}
