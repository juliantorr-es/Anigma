import Foundation
import CapsuleCore
import TelemetryCore
import DocumentIRKit

/// Internal implementation for DocumentRenderKit
/// Provides stub-first conversion from DocumentIR to RenderPlan
internal struct DocumentRenderKitInternal: Sendable {
    
    /// Convert DocumentIR to RenderPlan (stub implementation)
    internal func convert(
        document: DocumentIRNode,
        renderType: RenderType,
        layout: Layout,
        diagnostics: CapsuleDiagnostics,
        correlationID: String
    ) async throws -> RenderPlan {
        
        // Extract document information
        guard case .document(let doc) = document else {
            throw CapsuleError.invalidInput(
                field: "document",
                constraint: "Document root must be .document case"
            )
        }
        
        // Create render plan
        let renderPlanID = UUID().uuidString
        var elements: [RenderElement] = []
        
        // Convert document children to render elements
        var converter = DocumentIRToRenderElementConverter(
            layout: layout,
            diagnostics: diagnostics,
            correlationID: correlationID
        )
        
        for child in doc.children {
            let childElements = try await converter.convert(child, at: CGPoint(x: 0, y: 0))
            elements.append(contentsOf: childElements)
        }
        
        return RenderPlan(
            id: renderPlanID,
            documentID: doc.id,
            renderType: renderType,
            layout: layout,
            elements: elements,
            metadata: RenderMetadata(
                createdDate: Date(),
                version: "1.0.0",
                generator: "DocumentRenderKit Stub",
                properties: [
                    "conversion_correlation_id": AnyCodable.string(correlationID),
                    "total_elements": AnyCodable.int(elements.count)
                ]
            )
        )
    }
    
    /// Get supported render types
    internal func getSupportedRenderTypes() -> [RenderType] {
        return [
            .pdf,
            .html,
            .markdown,
            .plainText
            // Note: .canvas and .print are stubbed for Tier 2 implementation
        ]
    }
    
    /// Get default layout for render type
    internal func getDefaultLayout(for renderType: RenderType) -> Layout {
        switch renderType {
        case .pdf:
            return Layout(
                pageSize: .a4,
                margins: Margins.standard,
                orientation: .portrait,
                columns: 1
            )
        case .html:
            return Layout(
                pageSize: .a4,
                margins: Margins.narrow,
                orientation: .portrait,
                columns: 1
            )
        case .markdown:
            return Layout(
                pageSize: .a4,
                margins: Margins.standard,
                orientation: .portrait,
                columns: 1
            )
        case .plainText:
            return Layout(
                pageSize: .a4,
                margins: Margins.standard,
                orientation: .portrait,
                columns: 1
            )
        case .canvas:
            return Layout(
                pageSize: .a4,
                margins: Margins.narrow,
                orientation: .landscape,
                columns: 1
            )
        case .print:
            return Layout(
                pageSize: .a4,
                margins: Margins.standard,
                orientation: .portrait,
                columns: 2
            )
        }
    }
    
    /// Validate render plan
    internal func validate(renderPlan: RenderPlan) -> ValidationResult {
        var issues: [ValidationIssue] = []
        let warnings: [ValidationIssue] = []
        
        // Validate layout
        if layoutDimensionsExceedPageSize(renderPlan.layout) {
            issues.append(ValidationIssue(
                id: UUID().uuidString,
                severity: .error,
                message: "Layout dimensions exceed page size",
                elementID: nil
            ))
        }
        
        // Validate elements
        for element in renderPlan.elements {
            if let elementIssues = validateElement(element) {
                issues.append(contentsOf: elementIssues)
            }
        }
        
        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    // MARK: - Private Helpers
    
    private func layoutDimensionsExceedPageSize(_ layout: Layout) -> Bool {
        let pageDimensions = layout.pageSize.dimensions
        let contentWidth = pageDimensions.width - layout.margins.left - layout.margins.right
        let contentHeight = pageDimensions.height - layout.margins.top - layout.margins.bottom
        
        return contentWidth <= 0 || contentHeight <= 0
    }
    
    private func validateElement(_ element: RenderElement) -> [ValidationIssue]? {
        var issues: [ValidationIssue] = []
        
        switch element {
        case .text(let textElement):
            if textElement.content.isEmpty {
                issues.append(ValidationIssue(
                    id: UUID().uuidString,
                    severity: .warning,
                    message: "Text element has empty content",
                    elementID: textElement.id
                ))
            }
            if textElement.frame.width <= 0 || textElement.frame.height <= 0 {
                issues.append(ValidationIssue(
                    id: UUID().uuidString,
                    severity: .error,
                    message: "Text element has invalid frame dimensions",
                    elementID: textElement.id
                ))
            }
            
        case .image(let imageElement):
            if imageElement.source.isEmpty {
                issues.append(ValidationIssue(
                    id: UUID().uuidString,
                    severity: .error,
                    message: "Image element has empty source",
                    elementID: imageElement.id
                ))
            }
            
        case .container(let container):
            if container.frame.width <= 0 || container.frame.height <= 0 {
                issues.append(ValidationIssue(
                    id: UUID().uuidString,
                    severity: .error,
                    message: "Container element has invalid frame dimensions",
                    elementID: container.id
                ))
            }
            
        default:
            break
        }
        
        return issues.isEmpty ? nil : issues
    }
}

/// Converter from DocumentIR to RenderElement
internal struct DocumentIRToRenderElementConverter: Sendable {
    init(layout: Layout, diagnostics: CapsuleDiagnostics, correlationID: String, currentY: Double = 0) {
        self.layout = layout
        self.diagnostics = diagnostics
        self.correlationID = correlationID
        self.currentY = currentY
    }
    let layout: Layout
    let diagnostics: CapsuleDiagnostics
    let correlationID: String
    private var currentY: Double = 0
    
    internal mutating func convert(
        _ node: DocumentIRNode,
        at position: CGPoint
    ) async throws -> [RenderElement] {
        
        switch node {
        case .document:
            return []
            
        case .section(let section):
            return try await convertSection(section, at: position)
            
        case .paragraph(let paragraph):
            return try await convertParagraph(paragraph, at: position)
            
        case .text(let text):
            return [convertText(text, at: position)]
            
        case .emphasis(let emphasis):
            return try await convertEmphasis(emphasis, at: position)
            
        case .strong(let strong):
            return try await convertStrong(strong, at: position)
            
        case .code(let code):
            return [convertInlineCode(code, at: position)]
            
        case .codeBlock(let codeBlock):
            return [convertCodeBlock(codeBlock, at: position)]
            
        case .list(let list):
            return try await convertList(list, at: position)
            
        case .listItem(let listItem):
            return try await convertListItem(listItem, at: position)
            
        case .link(let link):
            return try await convertLink(link, at: position)
            
        case .image(let image):
            return [convertImage(image, at: position)]
            
        case .lineBreak, .hardBreak, .softBreak:
            return [RenderElement.lineBreak]
            
        default:
            // Stub implementation for remaining node types
            return []
        }
    }
    
    private mutating func convertSection(
        _ section: DocumentIRNode.Section,
        at position: CGPoint
    ) async throws -> [RenderElement] {
        var elements: [RenderElement] = []
        
        // Add heading text
        let headingStyle = TextStyle(
            fontSize: 24.0 - Double(section.level) * 2.0,
            fontWeight: .bold
        )
        
        let headingElement = RenderElement.text(TextElement(
            id: "heading-\(section.id)",
            content: section.title,
            frame: CGRect(
                x: position.x,
                y: currentY,
                width: layout.pageSize.dimensions.width - layout.margins.left - layout.margins.right,
                height: 40.0
            ),
            style: headingStyle,
            alignment: .left
        ))
        
        elements.append(headingElement)
        currentY += 50.0
        
        // Convert section children
        for child in section.children {
            let childElements = try await convert(child, at: CGPoint(x: position.x + 20, y: currentY))
            elements.append(contentsOf: childElements)
            currentY += 30.0 // Add spacing between elements
        }
        
        return elements
    }
    
    private mutating func convertParagraph(
        _ paragraph: DocumentIRNode.Paragraph,
        at position: CGPoint
    ) async throws -> [RenderElement] {
        var elements: [RenderElement] = []
        
        // Convert paragraph children (inline elements)
        for child in paragraph.children {
            let childElements = try await convert(child, at: CGPoint(x: position.x, y: currentY))
            elements.append(contentsOf: childElements)
        }
        
        currentY += 20.0 // Add paragraph spacing
        return elements
    }
    
    private func convertText(_ text: DocumentIRNode.Text, at position: CGPoint) -> RenderElement {
        let style = mapTextStyle(text.style)
        let estimatedHeight = style.fontSize * 1.2
        
        return RenderElement.text(TextElement(
            id: "text-\(UUID().uuidString)",
            content: text.content,
            frame: CGRect(
                x: position.x,
                y: currentY,
                width: 200.0, // Stub: would calculate based on content
                height: estimatedHeight
            ),
            style: style,
            alignment: .left
        ))
    }
    
    private mutating func convertEmphasis(
        _ emphasis: DocumentIRNode.Emphasis,
        at position: CGPoint
    ) async throws -> [RenderElement] {
        var elements: [RenderElement] = []
        var combinedText = ""
        
        // Collect all text from children
        for child in emphasis.children {
            if case .text(let text) = child {
                combinedText += text.content
            } else {
                let childElements = try await convert(child, at: position)
                elements.append(contentsOf: childElements)
            }
        }
        
        if !combinedText.isEmpty {
            let italicStyle = TextStyle(fontStyle: .italic)
            elements.append(RenderElement.text(TextElement(
                id: emphasis.id,
                content: combinedText,
                frame: CGRect(x: position.x, y: currentY, width: 150.0, height: 16.0),
                style: italicStyle,
                alignment: .left
            )))
        }
        
        return elements
    }
    
    private mutating func convertStrong(
        _ strong: DocumentIRNode.Strong,
        at position: CGPoint
    ) async throws -> [RenderElement] {
        var elements: [RenderElement] = []
        var combinedText = ""
        
        // Collect all text from children
        for child in strong.children {
            if case .text(let text) = child {
                combinedText += text.content
            } else {
                let childElements = try await convert(child, at: position)
                elements.append(contentsOf: childElements)
            }
        }
        
        if !combinedText.isEmpty {
            let boldStyle = TextStyle(fontWeight: .bold)
            elements.append(RenderElement.text(TextElement(
                id: strong.id,
                content: combinedText,
                frame: CGRect(x: position.x, y: currentY, width: 150.0, height: 16.0),
                style: boldStyle,
                alignment: .left
            )))
        }
        
        return elements
    }
    
    private func convertInlineCode(
        _ code: DocumentIRNode.Code,
        at position: CGPoint
    ) -> RenderElement {
        let codeStyle = TextStyle(
            fontFamily: "Courier New",
            fontSize: 14.0
        )
        
        return RenderElement.text(TextElement(
            id: code.id,
            content: code.code,
            frame: CGRect(x: position.x, y: currentY, width: 100.0, height: 16.0),
            style: codeStyle,
            alignment: .left
        ))
    }
    
    private func convertCodeBlock(
        _ codeBlock: DocumentIRNode.CodeBlock,
        at position: CGPoint
    ) -> RenderElement {
        let codeStyle = TextStyle(
            fontFamily: "Courier New",
            fontSize: 12.0
        )
        
        let estimatedHeight = Double(codeBlock.code.components(separatedBy: .newlines).count) * 15.0
        
        return RenderElement.container(ContainerElement(
            id: codeBlock.id,
            type: .paragraph,
            frame: CGRect(
                x: position.x,
                y: currentY,
                width: layout.pageSize.dimensions.width - layout.margins.left - layout.margins.right,
                height: estimatedHeight
            ),
            children: [
                .text(TextElement(
                    id: "code-content-\(codeBlock.id)",
                    content: codeBlock.code,
                    frame: CGRect(x: 10, y: 10, width: 400, height: estimatedHeight - 20),
                    style: codeStyle,
                    alignment: .left
                ))
            ],
            style: ContainerStyle(
                backgroundColor: Color(red: 0.95, green: 0.95, blue: 0.95),
                borderColor: Color(red: 0.8, green: 0.8, blue: 0.8),
                borderWidth: 1.0,
                cornerRadius: 4.0,
                padding: Margins(top: 10, right: 10, bottom: 10, left: 10)
            )
        ))
    }
    
    private mutating func convertList(
        _ list: DocumentIRNode.List,
        at position: CGPoint
    ) async throws -> [RenderElement] {
        var elements: [RenderElement] = []
        
        for (index, child) in list.children.enumerated() {
            if case .listItem(let listItem) = child {
                let itemPrefix = list.type == .ordered ? "\(index + 1)." : "•"
                
                let prefixElement = RenderElement.text(TextElement(
                    id: "prefix-\(listItem.id)",
                    content: itemPrefix,
                    frame: CGRect(x: position.x, y: currentY, width: 20, height: 16),
                    style: TextStyle(),
                    alignment: .left
                ))
                
                elements.append(prefixElement)
                
                let itemElements = try await convert(child, at: CGPoint(x: position.x + 25, y: currentY))
                elements.append(contentsOf: itemElements)
                currentY += 20.0
            }
        }
        
        return elements
    }
    
    private mutating func convertListItem(
        _ listItem: DocumentIRNode.ListItem,
        at position: CGPoint
    ) async throws -> [RenderElement] {
        var elements: [RenderElement] = []
        
        for child in listItem.children {
            let childElements = try await convert(child, at: position)
            elements.append(contentsOf: childElements)
        }
        
        return elements
    }
    
    private mutating func convertLink(
        _ link: DocumentIRNode.Link,
        at position: CGPoint
    ) async throws -> [RenderElement] {
        var linkText = link.title ?? link.url
        
        // If link has children, use their text content
        for child in link.children {
            if case .text(let text) = child {
                linkText = text.content
                break
            }
        }
        
        let linkStyle = TextStyle(
            fontWeight: .regular,
            color: Color(red: 0.0, green: 0.0, blue: 1.0)
        )
        
        return [RenderElement.text(TextElement(
            id: link.id,
            content: linkText,
            frame: CGRect(x: position.x, y: currentY, width: 150, height: 16),
            style: linkStyle,
            alignment: .left
        ))]
    }
    
    private func convertImage(
        _ image: DocumentIRNode.Image,
        at position: CGPoint
    ) -> RenderElement {
        let width = image.width ?? 200.0
        let height = image.height ?? 150.0
        
        return RenderElement.image(ImageElement(
            id: image.id,
            source: image.source,
            frame: CGRect(x: position.x, y: currentY, width: width, height: height),
            scaling: .fit,
            altText: image.altText
        ))
    }
    
    private func mapTextStyle(_ textStyle: DocumentIRNode.TextStyle) -> TextStyle {
        switch textStyle {
        case .normal:
            return TextStyle()
        case .bold:
            return TextStyle(fontWeight: .bold)
        case .italic:
            return TextStyle(fontStyle: .italic)
        case .strikethrough:
            return TextStyle() // Stub: would add strikethrough support
        case .underline:
            return TextStyle() // Stub: would add underline support
        }
    }
}

/// Point for positioning
internal struct CGPoint: Sendable {
    let x: Double
    let y: Double
    
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}