//
//  PDFRenderer.swift
//  PlatformCore
//
//  PDF renderer implementation for Phase 8.2
//

import Foundation

/// PDF renderer using the platform-agnostic Renderer protocol
/// Note: This is a basic text-based PDF generator. For production, consider using native frameworks.
public struct PDFRenderer: Renderer {
    public let supportedFormats: [OutputFormat] = [.pdf]

    public init() {}

    public func render(document: ContentDocument, to format: OutputFormat) async throws -> RenderResult {
        guard format == .pdf else {
            throw RendererError.unsupportedFormat(format)
        }

        let pdfContent = generatePDF(from: document)

        return RenderResult(
            format: .pdf,
            data: pdfContent,
            metadata: ["generator": "PlatformCore.PDFRenderer"]
        )
    }

    private func generatePDF(from document: ContentDocument) -> Data {
        // Simple PDF generation using ASCII text format
        // This is a text-to-PDF converter - suitable for basic documents

        var pdfData = Data()

        // PDF header
        let header = "%PDF-1.4\n"
        pdfData.append(header.data(using: .utf8) ?? Data())

        // PDF binary comment
        let binaryComment = "%\u{E2}\u{E3}\u{CF}\u{D3}\n"
        pdfData.append(binaryComment.data(using: .utf8) ?? Data())

        // Object 1: Catalog
        let catalogObj = """
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        """
        pdfData.append((catalogObj + "\n").data(using: .utf8) ?? Data())

        // Object 2: Pages
        let pagesObj = """
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        """
        pdfData.append((pagesObj + "\n").data(using: .utf8) ?? Data())

        // Create content stream for document
        let contentStream = createContentStream(from: document)
        let streamLength = contentStream.count

        // Object 3: Page
        let pageObj = """
        3 0 obj
        << /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>
        endobj
        """
        pdfData.append((pageObj + "\n").data(using: .utf8) ?? Data())

        // Object 4: Font
        let fontObj = """
        4 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        """
        pdfData.append((fontObj + "\n").data(using: .utf8) ?? Data())

        // Object 5: Content stream
        let contentObj = """
        5 0 obj
        << /Length \(streamLength) >>
        stream
        \(contentStream)
        endstream
        endobj
        """
        pdfData.append((contentObj + "\n").data(using: .utf8) ?? Data())

        // Cross-reference table
        let xrefOffset = pdfData.count
        let xrefTable = """
        xref
        0 6
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000214 00000 n
        0000000287 00000 n
        """
        pdfData.append((xrefTable).data(using: .utf8) ?? Data())

        // Trailer
        let trailer = """
        trailer
        << /Size 6 /Root 1 0 R >>
        startxref
        \(xrefOffset)
        %%EOF
        """
        pdfData.append((trailer + "\n").data(using: .utf8) ?? Data())

        return pdfData
    }

    private func createContentStream(from document: ContentDocument) -> String {
        var stream = "BT\n/F1 12 Tf\n50 750 Td\n"

        // Render title
        let title = escape(document.title)
        stream += "(\(title)) Tj\n0 -20 Td\n"

        // Render sections
        for section in document.sections {
            stream += renderSectionToPDF(section)
        }

        stream += "ET\n"
        return stream
    }

    private func renderSectionToPDF(_ section: ContentSection) -> String {
        var stream = ""

        // Reset text matrix for section
        stream += "0 -15 Td\n"

        // Section title if exists
        if let title = section.title {
            let fontSize = max(20 - (section.level * 2), 10)
            stream += "ET\n/F1 \(fontSize) Tf\nBT\n"
            stream += "(\(escape(title))) Tj\n"
            stream += "0 -\(fontSize) Td\n"
        }

        // Content node
        stream += renderContentNodeToPDF(section.content)

        // Subsections
        for subsection in section.subsections {
            stream += renderSectionToPDF(subsection)
        }

        return stream
    }

    private func renderContentNodeToPDF(_ node: ContentNode) -> String {
        switch node {
        case .text(let text):
            return "(\(escape(text))) Tj\n0 -12 Td\n"

        case .paragraph(let children):
            var stream = ""
            for child in children {
                stream += renderContentNodeToPDF(child)
            }
            return stream

        case .heading(let level, let text):
            let fontSize = max(20 - (level * 2), 10)
            return "ET\n/F1 \(fontSize) Tf\nBT\n(\(escape(text))) Tj\n0 -\(fontSize) Td\n"

        case .list(let items, _):
            var stream = ""
            for item in items {
                stream += "(• \(renderContentNodePlainText(item))) Tj\n0 -12 Td\n"
            }
            return stream

        case .table(let rows):
            var stream = "0 -20 Td\n"
            for row in rows {
                for cell in row {
                    stream += "(\(renderContentNodePlainText(cell)) | ) Tj\n"
                }
                stream += "0 -12 Td\n"
            }
            return stream

        case .image:
            // PDF images require binary data - skip for now
            return "(Image content) Tj\n0 -12 Td\n"

        case .link(let url, let text):
            return "(\(escape(text)): \(escape(url))) Tj\n0 -12 Td\n"

        case .code(let code, _):
            return "(\(escape(code))) Tj\n0 -12 Td\n"

        case .container(let children):
            var stream = ""
            for child in children {
                stream += renderContentNodeToPDF(child)
            }
            return stream
        }
    }

    private func renderContentNodePlainText(_ node: ContentNode) -> String {
        switch node {
        case .text(let text):
            return text
        case .heading(_, let text):
            return text
        case .link(_, let text):
            return text
        case .code(let code, _):
            return code
        default:
            return ""
        }
    }

    private func escape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .newlines)
    }
}
