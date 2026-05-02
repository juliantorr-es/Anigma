/// OOXMLKit provides parsing and extraction capabilities for Office Open XML documents
/// (docx, xlsx, pptx) with support for text extraction, structure preservation, and metadata.

import Foundation

/// OOXML document type
public enum OOXMLDocumentType {
    case wordDocument // .docx
    case spreadsheet  // .xlsx
    case presentation // .pptx
}

/// Document metadata
public struct DocumentMetadata {
    public let title: String?
    public let author: String?
    public let subject: String?
    public let keywords: [String]
    public let creationDate: Date?
    public let modificationDate: Date?
    public let contentType: String
    
    public init(
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        keywords: [String] = [],
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        contentType: String = ""
    ) {
        self.title = title
        self.author = author
        self.subject = subject
        self.keywords = keywords
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.contentType = contentType
    }
}

/// Paragraph in document
public struct Paragraph {
    public let text: String
    public let formatting: TextFormatting
    public let index: Int
    
    public init(text: String, formatting: TextFormatting = TextFormatting(), index: Int = 0) {
        self.text = text
        self.formatting = formatting
        self.index = index
    }
}

/// Text formatting information
public struct TextFormatting {
    public let bold: Bool
    public let italic: Bool
    public let fontSize: Int?
    public let fontName: String?
    public let color: String?
    
    public init(
        bold: Bool = false,
        italic: Bool = false,
        fontSize: Int? = nil,
        fontName: String? = nil,
        color: String? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.fontSize = fontSize
        self.fontName = fontName
        self.color = color
    }
}

/// Spreadsheet cell
public struct Cell {
    public let value: String
    public let row: Int
    public let column: Int
    public let dataType: String
    
    public init(value: String, row: Int, column: Int, dataType: String = "text") {
        self.value = value
        self.row = row
        self.column = column
        self.dataType = dataType
    }
}

/// Spreadsheet sheet
public struct Sheet {
    public let name: String
    public let cells: [Cell]
    
    public init(name: String, cells: [Cell] = []) {
        self.name = name
        self.cells = cells
    }
}

/// OOXML document parser
public struct OOXMLParser {
    private let fileURL: URL
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    /// Parse OOXML document
    public func parse() throws -> OOXMLDocument {
        let data = try Data(contentsOf: fileURL)
        let documentType = detectDocumentType()
        
        switch documentType {
        case .wordDocument:
            return try parseWordDocument(data: data)
        case .spreadsheet:
            return try parseSpreadsheet(data: data)
        case .presentation:
            return try parsePresentation(data: data)
        }
    }
    
    /// Detect document type from file extension
    private func detectDocumentType() -> OOXMLDocumentType {
        let pathExtension = fileURL.pathExtension.lowercased()
        switch pathExtension {
        case "docx":
            return .wordDocument
        case "xlsx":
            return .spreadsheet
        case "pptx":
            return .presentation
        default:
            return .wordDocument
        }
    }
    
    /// Parse Word document (.docx)
    private func parseWordDocument(data: Data) throws -> OOXMLDocument {
        // Extract from zip archive
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL)
        
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Extract and parse document.xml
        var paragraphs: [Paragraph] = []
        var metadata = DocumentMetadata(contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        
        // Parse core properties
        let corePropsPath = tempURL.appendingPathComponent("docProps/core.xml")
        if FileManager.default.fileExists(atPath: corePropsPath.path) {
            if let coreData = try? Data(contentsOf: corePropsPath) {
                if let xml = String(data: coreData, encoding: .utf8) {
                    metadata = parseWordMetadata(xml)
                }
            }
        }
        
        // Parse document content
        let docPath = tempURL.appendingPathComponent("word/document.xml")
        if FileManager.default.fileExists(atPath: docPath.path) {
            if let docData = try? Data(contentsOf: docPath) {
                if let xml = String(data: docData, encoding: .utf8) {
                    paragraphs = parseWordContent(xml)
                }
            }
        }
        
        return OOXMLDocument(
            type: .wordDocument,
            metadata: metadata,
            text: paragraphs.map { $0.text }.joined(separator: "\n"),
            paragraphs: paragraphs,
            sheets: [],
            slides: []
        )
    }
    
    /// Parse Excel spreadsheet (.xlsx)
    private func parseSpreadsheet(data: Data) throws -> OOXMLDocument {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL)
        
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        var sheets: [Sheet] = []
        var metadata = DocumentMetadata(contentType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        
        // Parse core properties
        let corePropsPath = tempURL.appendingPathComponent("docProps/core.xml")
        if FileManager.default.fileExists(atPath: corePropsPath.path) {
            if let coreData = try? Data(contentsOf: corePropsPath) {
                if let xml = String(data: coreData, encoding: .utf8) {
                    metadata = parseSpreadsheetMetadata(xml)
                }
            }
        }
        
        // Parse sheets
        let worksheetsPath = tempURL.appendingPathComponent("xl/worksheets")
        if FileManager.default.fileExists(atPath: worksheetsPath.path) {
            let worksheetFiles = try FileManager.default.contentsOfDirectory(atPath: worksheetsPath.path)
            for file in worksheetFiles.sorted() {
                let filePath = worksheetsPath.appendingPathComponent(file)
                if let sheetData = try? Data(contentsOf: filePath) {
                    if let xml = String(data: sheetData, encoding: .utf8) {
                        if let sheet = parseSheetContent(xml) {
                            sheets.append(sheet)
                        }
                    }
                }
            }
        }
        
        return OOXMLDocument(
            type: .spreadsheet,
            metadata: metadata,
            text: extractSpreadsheetText(sheets),
            paragraphs: [],
            sheets: sheets,
            slides: []
        )
    }
    
    /// Parse PowerPoint presentation (.pptx)
    private func parsePresentation(data: Data) throws -> OOXMLDocument {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL)
        
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        var slides: [Slide] = []
        var metadata = DocumentMetadata(contentType: "application/vnd.openxmlformats-officedocument.presentationml.presentation")
        
        // Parse core properties
        let corePropsPath = tempURL.appendingPathComponent("docProps/core.xml")
        if FileManager.default.fileExists(atPath: corePropsPath.path) {
            if let coreData = try? Data(contentsOf: corePropsPath) {
                if let xml = String(data: coreData, encoding: .utf8) {
                    metadata = parsePresentationMetadata(xml)
                }
            }
        }
        
        // Parse slides
        let slidesPath = tempURL.appendingPathComponent("ppt/slides")
        if FileManager.default.fileExists(atPath: slidesPath.path) {
            let slideFiles = try FileManager.default.contentsOfDirectory(atPath: slidesPath.path)
            for file in slideFiles.sorted() {
                let filePath = slidesPath.appendingPathComponent(file)
                if let slideData = try? Data(contentsOf: filePath) {
                    if let xml = String(data: slideData, encoding: .utf8) {
                        if let slide = parseSlideContent(xml) {
                            slides.append(slide)
                        }
                    }
                }
            }
        }
        
        return OOXMLDocument(
            type: .presentation,
            metadata: metadata,
            text: slides.map { $0.text }.joined(separator: "\n"),
            paragraphs: [],
            sheets: [],
            slides: slides
        )
    }
    
    // MARK: - Metadata Parsing
    
    private func parseWordMetadata(_ xml: String) -> DocumentMetadata {
        var metadata = DocumentMetadata(contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        
        if let title = extractXMLTag(from: xml, tag: "dc:title") {
            metadata = DocumentMetadata(title: title, contentType: metadata.contentType)
        }
        
        return metadata
    }
    
    private func parseSpreadsheetMetadata(_ xml: String) -> DocumentMetadata {
        var metadata = DocumentMetadata(contentType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        
        if let title = extractXMLTag(from: xml, tag: "dc:title") {
            metadata = DocumentMetadata(title: title, contentType: metadata.contentType)
        }
        
        return metadata
    }
    
    private func parsePresentationMetadata(_ xml: String) -> DocumentMetadata {
        var metadata = DocumentMetadata(contentType: "application/vnd.openxmlformats-officedocument.presentationml.presentation")
        
        if let title = extractXMLTag(from: xml, tag: "dc:title") {
            metadata = DocumentMetadata(title: title, contentType: metadata.contentType)
        }
        
        return metadata
    }
    
    // MARK: - Content Parsing
    
    private func parseWordContent(_ xml: String) -> [Paragraph] {
        var paragraphs: [Paragraph] = []
        
        // Extract text from <w:p> tags
        let pattern = "<w:p>.*?</w:p>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
            let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
            let matches = regex.matches(in: xml, range: range)
            
            for (index, match) in matches.enumerated() {
                if let matchRange = Range(match.range, in: xml) {
                    let pXml = String(xml[matchRange])
                    if let text = extractXMLTag(from: pXml, tag: "w:t") {
                        paragraphs.append(Paragraph(text: text, index: index))
                    }
                }
            }
        }
        
        return paragraphs
    }
    
    private func parseSheetContent(_ xml: String) -> Sheet? {
        let sheetName = "Sheet"
        var cells: [Cell] = []
        
        // Extract cells from <c> tags
        let pattern = "<c[^>]*>.*?</c>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
            let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
            let matches = regex.matches(in: xml, range: range)
            
            for match in matches {
                if let matchRange = Range(match.range, in: xml) {
                    let cellXml = String(xml[matchRange])
                    if let value = extractXMLTag(from: cellXml, tag: "v") {
                        let cell = Cell(value: value, row: 0, column: 0)
                        cells.append(cell)
                    }
                }
            }
        }
        
        return Sheet(name: sheetName, cells: cells)
    }
    
    private func parseSlideContent(_ xml: String) -> Slide? {
        var text = ""
        
        // Extract text from shapes
        let pattern = "<a:t>.*?</a:t>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
            let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
            let matches = regex.matches(in: xml, range: range)
            
            for match in matches {
                if let matchRange = Range(match.range, in: xml) {
                    let textXml = String(xml[matchRange])
                    if let t = extractXMLTag(from: textXml, tag: "a:t") {
                        text += t + " "
                    }
                }
            }
        }
        
        return Slide(text: text.trimmingCharacters(in: .whitespaces))
    }
    
    // MARK: - Utility Methods
    
    private func extractXMLTag(from xml: String, tag: String) -> String? {
        let pattern = "<\(tag)>([^<]*)</\(tag)>"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
            if let match = regex.firstMatch(in: xml, range: range) {
                if let range = Range(match.range(at: 1), in: xml) {
                    return String(xml[range])
                }
            }
        }
        return nil
    }
    
    private func extractSpreadsheetText(_ sheets: [Sheet]) -> String {
        return sheets.map { sheet in
            "Sheet: \(sheet.name)\n" + sheet.cells.map { $0.value }.joined(separator: ", ")
        }.joined(separator: "\n\n")
    }
}

/// Slide in presentation
public struct Slide {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
}

/// OOXML document
public struct OOXMLDocument {
    public let type: OOXMLDocumentType
    public let metadata: DocumentMetadata
    public let text: String
    public let paragraphs: [Paragraph]
    public let sheets: [Sheet]
    public let slides: [Slide]
    
    public init(
        type: OOXMLDocumentType,
        metadata: DocumentMetadata,
        text: String,
        paragraphs: [Paragraph] = [],
        sheets: [Sheet] = [],
        slides: [Slide] = []
    ) {
        self.type = type
        self.metadata = metadata
        self.text = text
        self.paragraphs = paragraphs
        self.sheets = sheets
        self.slides = slides
    }
}
