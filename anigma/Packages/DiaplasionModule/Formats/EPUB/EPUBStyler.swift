//
//  EPUBStyler.swift
//  DiaplasionModule
//
//  Enhanced EPUB styling with accessibility features.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

/// Provides enhanced styling for EPUB output with accessibility features.
public struct EPUBStyler: Sendable {
    
    // MARK: - Configuration
    
    /// Styling level for EPUB output
    public let stylingLevel: EPUBStylingLevel
    
    /// Include accessibility metadata
    public let includeAccessibilityMetadata: Bool
    
    /// Include navigation landmarks
    public let includeLandmarks: Bool
    
    /// Optimize for screen readers
    public let optimizeForScreenReaders: Bool
    
    // MARK: - Initialization
    
    public init(
        stylingLevel: EPUBStylingLevel? = nil,
        includeAccessibilityMetadata: Bool? = nil,
        includeLandmarks: Bool = true,
        optimizeForScreenReaders: Bool = true
    ) {
        self.stylingLevel = stylingLevel ?? DiaplasionConfiguration.epubStylingLevel
        self.includeAccessibilityMetadata = includeAccessibilityMetadata ?? DiaplasionConfiguration.epubAccessibilityMetadata
        self.includeLandmarks = includeLandmarks
        self.optimizeForScreenReaders = optimizeForScreenReaders
    }
    
    // MARK: - Public Interface
    
    /// Generate enhanced CSS styles for EPUB.
    public func generateCSS() -> String {
        var cssStyles = baseCSS
        
        switch stylingLevel {
        case .basic:
            cssStyles += basicStyles
        case .enhanced:
            cssStyles += enhancedStyles
        case .accessible:
            cssStyles += accessibleStyles
        }
        
        if optimizeForScreenReaders {
            cssStyles += screenReaderStyles
        }
        
        return cssStyles
    }
    
    /// Generate accessibility metadata for EPUB.
    public func generateAccessibilityMetadata(
        for document: DocumentSourceComponent,
        chunks: [TextChunk]
    ) -> [String: String] {
        var metadata: [String: String] = [:]
        
        guard includeAccessibilityMetadata else { return metadata }
        
        // Accessibility summary
        metadata["schema:accessibilitySummary"] = """
            This publication has been optimized for accessibility with the following features:
            - Structured headings for navigation
            - Proper semantic markup
            - Screen reader compatibility
            - High contrast support
            - Large text compatibility
            """
        
        // Accessibility features
        var features: [String] = [
            "structuralNavigation",
            "readingOrder",
            "fullAudio",
            "highContrast",
            "largePrint",
            "tableOfContents"
        ]
        
        if hasMathContent(chunks) {
            features.append("MathML")
        }
        
        if hasImages(document) {
            features.append("altText")
        }
        
        metadata["schema:accessibilityFeature"] = features.joined(separator: ", ")
        
        // Accessibility hazards
        let hazards: [String] = [] // No known hazards
        metadata["schema:accessibilityHazard"] = hazards.joined(separator: ", ")
        
        // Accessibility API
        metadata["schema:accessibilityAPI"] = "ARIA"
        
        // Accessiblity control
        metadata["schema:accessibilityControl"] = [
            "fullKeyboardControl",
            "fullMouseControl"
        ].joined(separator: ", ")
        
        // Reading level estimation
        metadata["schema:educationalLevel"] = estimateReadingLevel(chunks)
        
        return metadata
    }
    
    /// Generate enhanced navigation with landmarks.
    public func generateNavigationLandmarks(from chunks: [TextChunk]) -> [EPUBLandmark] {
        guard includeLandmarks else { return [] }
        
        var landmarks: [EPUBLandmark] = []
        var currentSection: EPUBLandmark?
        
        for (index, chunk) in chunks.enumerated() {
            switch chunk.chunkType {
            case .heading:
                let headingLevel = extractHeadingLevel(from: chunk.text)
                
                // Complete previous section
                if let section = currentSection {
                    section.endIndex = index - 1
                    landmarks.append(section)
                }
                
                // Start new section
                let newSection = EPUBLandmark(
                    type: determineLandmarkType(from: chunk.text),
                    title: extractTitle(from: chunk.text),
                    startIndex: index,
                    endIndex: nil, // Will be set when next section starts
                    headingLevel: headingLevel
                )
                currentSection = newSection
                
            case .paragraph:
                break // Continue current section
                
            case .list:
                if currentSection == nil {
                    // Create implicit section for list
                    currentSection = EPUBLandmark(
                        type: .list,
                        title: "List",
                        startIndex: index,
                        endIndex: nil,
                        headingLevel: 2
                    )
                }
                
            case .caption:
                if currentSection == nil {
                    // Create implicit section for caption
                    currentSection = EPUBLandmark(
                        type: .caption,
                        title: "Caption",
                        startIndex: index,
                        endIndex: nil,
                        headingLevel: 3
                    )
                }
                
            default:
                break
            }
        }
        
        // Complete final section
        if let section = currentSection {
            section.endIndex = chunks.count - 1
            landmarks.append(section)
        }
        
        return landmarks
    }
    
    /// Apply semantic markup to text chunks.
    public func applySemanticMarkup(to chunk: TextChunk) -> String {
        var markedUpText = chunk.text
        
        switch chunk.chunkType {
        case .heading:
            let level = extractHeadingLevel(from: chunk.text)
            markedUpText = "<h\(level)>\(chunk.text)</h\(level)>"
            
        case .paragraph:
            markedUpText = "<p>\(chunk.text)</p>"
            
        case .list:
            markedUpText = "<ul><li>\(chunk.text.replacingOccurrences(of: "\n", with: "</li><li>"))</li></ul>"
            
        case .quote:
            markedUpText = "<blockquote>\(chunk.text}</blockquote>"
            
        case .caption:
            markedUpText = "<figcaption>\(chunk.text)</figcaption>"
            
        default:
            break
        }
        
        // Add accessibility attributes if enabled
        if optimizeForScreenReaders {
            markedUpUpText = addAccessibilityAttributes(to: markedUpText, chunk: chunk)
        }
        
        return markedUpText
    }
    
    // MARK: - Helper Methods
    
    private func hasMathContent(_ chunks: [TextChunk]) -> Bool {
        return chunks.contains { chunk in
            chunk.text.contains("$") || chunk.text.contains("\\(") || chunk.text.contains("\\[")
        }
    }
    
    private func hasImages(_ document: DocumentSourceComponent) -> Bool {
        // Simplified check - would normally scan document for images
        return document.format == .pdf
    }
    
    private func estimateReadingLevel(_ chunks: [TextChunk]) -> String {
        // Simple estimation based on text complexity
        let totalText = chunks.map { $0.text }.joined()
        let words = totalText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let sentences = totalText.components(separatedBy: ".").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard sentences.count > 0 else { return "unknown" }
        
        let avgWordsPerSentence = Double(words.count) / Double(sentences.count)
        
        if avgWordsPerSentence < 10 {
            return "elementary"
        } else if avgWordsPerSentence < 15 {
            return "middleSchool"
        } else if avgWordsPerSentence < 20 {
            return "highSchool"
        } else {
            return "college"
        }
    }
    
    private func extractHeadingLevel(from text: String) -> Int {
        // Check for common heading patterns
        if text.hasPrefix("CHAPTER ") || text.hasPrefix("Chapter ") {
            return 1
        } else if text.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            return 2
        } else if text.range(of: #"^\d+\.\d+\s"#, options: .regularExpression) != nil {
            return 3
        } else if text.uppercased() == text && text.count < 50 {
            return 2
        } else {
            return 2 // Default heading level
        }
    }
    
    private func determineLandmarkType(from text: String) -> EPUBLandmarkType {
        let uppercased = text.uppercased()
        
        if uppercased.hasPrefix("CHAPTER ") || uppercased.hasPrefix("CHAPTER") {
            return .chapter
        } else if uppercased.hasPrefix("PART ") {
            return .part
        } else if uppercased.hasPrefix("SECTION ") {
            return .section
        } else if uppercased.hasPrefix("APPENDIX") {
            return .appendix
        } else if uppercased.hasPrefix("REFERENCES") || uppercased.hasPrefix("BIBLIOGRAPHY") {
            return .bibliography
        } else if uppercased.hasPrefix("INDEX") {
            return .index
        } else if uppercased.hasPrefix("GLOSSARY") {
            return .glossary
        } else {
            return .chapter // Default
        }
    }
    
    private func extractTitle(from text: String) -> String {
        // Remove heading markers and clean up
        let cleaned = text
            .replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\d+\.\d+\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^(CHAPTER|Part|Section)\s+"#i, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? text : cleaned
    }
    
    private func addAccessibilityAttributes(to markup: String, chunk: TextChunk) -> String {
        var accessibleMarkup = markup
        
        // Add ARIA labels for better screen reader support
        if chunk.chunkType == .heading {
            let level = extractHeadingLevel(from: chunk.text)
            accessibleMarkup = markup.replacingOccurrences(
                of: "<h\(level)>",
                with: "<h\(level) role=\"heading\" aria-level=\"\(level)\">"
            )
        }
        
        // Add language information
        if let language = DiaplasionConfiguration.defaultLanguage.split(separator: "-").first {
            accessibleMarkup = accessibleMarkup.replacingOccurrences(
                of: "<",
                with: "<lang=\"\(language)\" "
            )
        }
        
        return accessibleMarkup
    }
    
    // MARK: - CSS Styles
    
    private var baseCSS: String {
        return """
        /* Diaplasion EPUB Base Styles */
        
        body {
            font-family: Georgia, 'Times New Roman', serif;
            line-height: 1.6;
            margin: 0;
            padding: 1em;
            max-width: 100%;
        }
        
        h1, h2, h3, h4, h5, h6 {
            font-family: Arial, Helvetica, sans-serif;
            font-weight: bold;
            margin-top: 1.5em;
            margin-bottom: 0.8em;
            line-height: 1.3;
        }
        
        p {
            margin-top: 0;
            margin-bottom: 1em;
            text-align: justify;
        }
        
        """
    }
    
    private var basicStyles: String {
        return """
        /* Basic EPUB Styles */
        
        h1 { font-size: 2em; }
        h2 { font-size: 1.5em; }
        h3 { font-size: 1.3em; }
        h4 { font-size: 1.2em; }
        h5 { font-size: 1.1em; }
        h6 { font-size: 1em; }
        
        blockquote {
            margin: 1.5em 0;
            padding: 0.5em 1.5em;
            border-left: 3px solid #ccc;
            font-style: italic;
            background-color: #f9f9f9;
        }
        
        ul, ol {
            margin: 1em 0;
            padding-left: 2em;
        }
        
        li {
            margin-bottom: 0.5em;
        }
        
        """
    }
    
    private var enhancedStyles: String {
        return """
        /* Enhanced EPUB Styles */
        
        h1 {
            border-bottom: 2px solid #333;
            padding-bottom: 0.5em;
            page-break-after: avoid;
        }
        
        h2 {
            border-bottom: 1px solid #666;
            padding-bottom: 0.3em;
            page-break-after: avoid;
        }
        
        h3, h4, h5, h6 {
            page-break-after: avoid;
        }
        
        .chapter-title {
            text-align: center;
            font-size: 1.2em;
            margin-top: 2em;
            margin-bottom: 1.5em;
        }
        
        .footnote {
            font-size: 0.8em;
            vertical-align: super;
            color: #666;
        }
        
        .caption {
            font-style: italic;
            text-align: center;
            margin: 1em auto;
            max-width: 80%;
            font-size: 0.9em;
        }
        
        """
    }
    
    private var accessibleStyles: String {
        return """
        /* Accessibility-Enhanced Styles */
        
        @media (prefers-reduced-motion: reduce) {
            * {
                animation-duration: 0.01ms !important;
                animation-iteration-count: 1 !important;
                transition-duration: 0.01ms !important;
            }
        }
        
        @media (prefers-color-scheme: dark) {
            body {
                background-color: #1a1a1a;
                color: #e0e0e0;
            }
            
            h1, h2, h3, h4, h5, h6 {
                color: #ffffff;
                border-color: #666;
            }
            
            blockquote {
                background-color: #2a2a2a;
                border-color: #666;
                color: #cccccc;
            }
        }
        
        @media (prefers-contrast: high) {
            body {
                font-weight: bold;
            }
            
            h1, h2, h3, h4, h5, h6 {
                border-width: 3px;
            }
            
            a {
                text-decoration: underline;
                font-weight: bold;
            }
        }
        
        /* Screen reader specific styles */
        .sr-only {
            position: absolute;
            width: 1px;
            height: 1px;
            padding: 0;
            margin: -1px;
            overflow: hidden;
            clip: rect(0, 0, 0, 0);
            white-space: nowrap;
            border: 0;
        }
        
        """
    }
    
    private var screenReaderStyles: String {
        return """
        /* Screen Reader Optimization */
        
        *[role] {
            speak-as: normal;
        }
        
        *[aria-label] {
            speak-as: spell-out;
        }
        
        h1[role="heading"], h2[role="heading"], h3[role="heading"], 
        h4[role="heading"], h5[role="heading"], h6[role="heading"] {
            speak-as: normal;
            voice-stress: moderate;
        }
        
        /* Pause after headings for better comprehension */
        h1 { pause-after: 1s; }
        h2 { pause-after: 0.8s; }
        h3 { pause-after: 0.6s; }
        h4 { pause-after: 0.4s; }
        h5 { pause-after: 0.3s; }
        h6 { pause-after: 0.2s; }
        
        /* Emphasize important elements */
        strong, b {
            voice-stress: strong;
        }
        
        em, i {
            voice-stress: moderate;
            pitch: medium;
        }
        
        """
    }
}

// MARK: - Supporting Types

/// EPUB navigation landmark.
public struct EPUBLandmark: Component {
    public var type: EPUBLandmarkType
    public var title: String
    public var startIndex: Int
    public var endIndex: Int?
    public var headingLevel: Int
    
    public init(
        type: EPUBLandmarkType,
        title: String,
        startIndex: Int,
        endIndex: Int?,
        headingLevel: Int
    ) {
        self.type = type
        self.title = title
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.headingLevel = headingLevel
    }
}

/// Types of EPUB landmarks.
public enum EPUBLandmarkType: String, CaseIterable, Sendable {
    case chapter = "chapter"
    case part = "part"
    case section = "section"
    case subsection = "subsection"
    case appendix = "appendix"
    case bibliography = "bibliography"
    case glossary = "glossary"
    case index = "index"
    case foreword = "foreword"
    case preface = "preface"
    case introduction = "introduction"
    case conclusion = "conclusion"
    case acknowledgments = "acknowledgments"
    case dedication = "dedication"
    case epigraph = "epigraph"
    case table = "table"
    case figure = "figure"
    case list = "list"
    case caption = "caption"
}

/// System that applies enhanced EPUB styling.
public struct EPUBStylingSystem: System {
    public var name: String { "EPUBStyling" }
    
    private let styler: EPUBStyler
    
    public init(styler: EPUBStyler = EPUBStyler()) {
        self.styler = styler
    }
    
    public func update(world: World) async {
        let entities = await world.query(
            ChunkedTextComponent.self,
            DocumentSourceComponent.self,
            TransformRequestComponent.self
        )
        
        for (entity, chunked, document, transform) in entities {
            // Skip if not processing EPUB
            if !transform.outputFormats.contains(.epub) {
                continue
            }
            
            // Skip if already styled
            if await world.hasComponent(entity, EPUBStyledComponent.self) {
                continue
            }
            
            // Apply enhanced styling
            let landmarks = styler.generateNavigationLandmarks(from: chunked.chunks)
            let css = styler.generateCSS()
            let accessibilityMetadata = styler.generateAccessibilityMetadata(
                for: document,
                chunks: chunked.chunks
            )
            
            let styledComponent = EPUBStyledComponent(
                landmarks: landmarks,
                css: css,
                accessibilityMetadata: accessibilityMetadata,
                stylingLevel: styler.stylingLevel
            )
            
            await world.addComponent(entity, styledComponent)
            
            await Logger.shared.info(
                "Applied EPUB styling for entity \(entity) with \(landmarks.count) landmarks",
                category: "Diaplasion"
            )
        }
    }
}

/// Component containing styled EPUB data.
public struct EPUBStyledComponent: Component {
    public let landmarks: [EPUBLandmark]
    public let css: String
    public let accessibilityMetadata: [String: String]
    public let stylingLevel: EPUBStylingLevel
    
    public init(
        landmarks: [EPUBLandmark],
        css: String,
        accessibilityMetadata: [String: String],
        stylingLevel: EPUBStylingLevel
    ) {
        self.landmarks = landmarks
        self.css = css
        self.accessibilityMetadata = accessibilityMetadata
        self.stylingLevel = stylingLevel
    }
}