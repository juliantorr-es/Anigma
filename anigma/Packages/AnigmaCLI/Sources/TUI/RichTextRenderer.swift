import Foundation
import AnigmaTUI

/// A robust renderer for Markdown in the terminal.
/// Parses text into styled segments for display.
public struct RichTextRenderer {
    public struct StyledSegment {
        public let text: String
        public let style: TUIEngine.Style
        public let color: TUIEngine.Color?
        public let background: TUIEngine.Color?
        
        public init(text: String, style: TUIEngine.Style = .reset, color: TUIEngine.Color? = nil, background: TUIEngine.Color? = nil) {
            self.text = text
            self.style = style
            self.color = color
            self.background = background
        }
    }
    
    public struct RenderedLine {
        public let segments: [StyledSegment]
    }
    
    private let theme: Theme
    
    public init(theme: Theme = .defaultTheme) {
        self.theme = theme
    }
    
    /// Parses and renders markdown text into a list of styled lines suitable for TUI display.
    public func render(text: String, width: Int) -> [RenderedLine] {
        var lines: [RenderedLine] = []
        let rawLines = text.components(separatedBy: "\n")
        
        var inCodeBlock = false
        var codeBlockLang: String? = nil
        
        for line in rawLines {
            // 1. Handle Code Blocks
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inCodeBlock.toggle()
                let cleanLine = line.trimmingCharacters(in: .whitespaces)
                if inCodeBlock {
                    codeBlockLang = cleanLine.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    // Border top
                    let border = String(repeating: "─", count: max(0, width - 2))
                    lines.append(RenderedLine(segments: [StyledSegment(text: "  ╭" + border + "╮", color: .brightBlack)]))
                    if let lang = codeBlockLang, !lang.isEmpty {
                         lines.append(RenderedLine(segments: [StyledSegment(text: "  │ \(lang)", color: .brightBlack)]))
                    }
                } else {
                    // Border bottom
                    let border = String(repeating: "─", count: max(0, width - 2))
                    lines.append(RenderedLine(segments: [StyledSegment(text: "  ╰" + border + "╯", color: .brightBlack)]))
                    codeBlockLang = nil
                }
                continue
            }
            
            if inCodeBlock {
                // Syntax highlighting placeholder (could be regex based later)
                // For now, render as cyan/code color, truncated to width
                let contentWidth = max(0, width - 4)
                let clipped = String(line.prefix(contentWidth))
                let padding = String(repeating: " ", count: max(0, contentWidth - clipped.count))
                
                lines.append(RenderedLine(segments: [
                    StyledSegment(text: "  │ ", color: .brightBlack),
                    StyledSegment(text: clipped, color: .cyan),
                    StyledSegment(text: padding + " │", color: .brightBlack)
                ]))
                continue
            }
            
            // 2. Handle Headers
            if line.hasPrefix("#") {
                let level = line.prefix(while: { $0 == "#" }).count
                let content = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
                let color: TUIEngine.Color = level == 1 ? .brightMagenta : (level == 2 ? .brightBlue : .brightCyan)
                let style: TUIEngine.Style = .bold
                
                // Wrap header text
                let wrapped = wordWrap(content, width: width)
                for w in wrapped {
                    lines.append(RenderedLine(segments: [StyledSegment(text: w, style: style, color: color)]))
                }
                continue
            }
            
            // 3. Handle Lists
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") || line.trimmingCharacters(in: .whitespaces).hasPrefix("* ") {
                let content = line.trimmingCharacters(in: .whitespaces).dropFirst(2).trimmingCharacters(in: .whitespaces)
                let wrapped = wordWrap(content, width: width - 2)
                for (i, w) in wrapped.enumerated() {
                    let prefix = i == 0 ? "• " : "  "
                    lines.append(RenderedLine(segments: [
                        StyledSegment(text: prefix, color: .yellow),
                        parseInline(w)
                    ]))
                }
                continue
            }
            
            // 4. Regular Text (with inline formatting)
            let wrapped = wordWrap(line, width: width)
            for w in wrapped {
                if w.isEmpty {
                    lines.append(RenderedLine(segments: []))
                } else {
                    lines.append(RenderedLine(segments: parseInlineComplex(w)))
                }
            }
        }
        
        return lines
    }
    
    // Parses inline styling: **bold** and `code`
    private func parseInlineComplex(_ text: String) -> [StyledSegment] {
        var segments: [StyledSegment] = []
        var remaining = text
        
        // Very basic lexer loop
        while !remaining.isEmpty {
            // Check for code `...`
            if let startRange = remaining.range(of: "`") {
                // Add text before backtick
                let prefix = String(remaining[..<startRange.lowerBound])
                if !prefix.isEmpty {
                    segments.append(StyledSegment(text: prefix, color: .white))
                }
                
                // Find closing backtick
                let afterStart = remaining[startRange.upperBound...]
                if let endRange = afterStart.range(of: "`") {
                    let code = String(afterStart[..<endRange.lowerBound])
                    segments.append(StyledSegment(text: code, color: .cyan, background: .brightBlack))
                    remaining = String(afterStart[endRange.upperBound...])
                } else {
                    // No closing backtick, treat as text
                    segments.append(StyledSegment(text: "`", color: .white))
                    remaining = String(afterStart)
                }
                continue
            }
            
            // Check for bold **...**
            if let startRange = remaining.range(of: "**") {
                // Add text before **
                let prefix = String(remaining[..<startRange.lowerBound])
                if !prefix.isEmpty {
                    segments.append(StyledSegment(text: prefix, color: .white))
                }
                
                // Find closing **
                let afterStart = remaining[startRange.upperBound...]
                if let endRange = afterStart.range(of: "**") {
                    let boldText = String(afterStart[..<endRange.lowerBound])
                    segments.append(StyledSegment(text: boldText, style: .bold, color: .brightWhite))
                    remaining = String(afterStart[endRange.upperBound...])
                } else {
                    segments.append(StyledSegment(text: "**", color: .white))
                    remaining = String(afterStart)
                }
                continue
            }
            
            // Fallback: Remaining text
            segments.append(StyledSegment(text: remaining, color: .white))
            remaining = ""
        }
        
        return segments
    }
    
    private func parseInline(_ text: String) -> StyledSegment {
        // Fallback simple parser
        return StyledSegment(text: text, color: .white)
    }
    
    private func wordWrap(_ text: String, width: Int) -> [String] {
        if text.isEmpty { return [""] }
        var lines: [String] = []
        var currentLine = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            if currentLine.count + word.count + 1 > width {
                if !currentLine.isEmpty { lines.append(currentLine); currentLine = "" }
            }
            if !currentLine.isEmpty { currentLine += " " }
            currentLine += word
        }
        if !currentLine.isEmpty { lines.append(currentLine) }
        return lines.isEmpty ? [""] : lines
    }
}
