import Foundation

// MARK: - TipSystem
public struct TipSystem: Renderable {
    private let tips = [
        "Use {highlight}@filename{/highlight} to attach files to your prompt.",
        "Press {highlight}Ctrl+A E{/highlight} to view the Evidence Chain.",
        "Type {highlight}!command{/highlight} to run shell commands directly."
    ]

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let tip = tips.randomElement() ?? ""
        let segments = parseTip(tip)

        var currentX = frame.origin.x
        for segment in segments {
            let text = Text(segment.text, foreground: segment.isHighlighted ? .brightYellow : .gray)
            text.render(in: Rect(x: currentX, y: frame.origin.y, width: segment.text.count, height: 1), to: buffer)
            currentX += segment.text.count
        }
    }

    private struct TipSegment {
        let text: String
        let isHighlighted: Bool
    }

    private func parseTip(_ tip: String) -> [TipSegment] {
        // Implementation for parsing {highlight}...{/highlight} tags
        return [TipSegment(text: tip, isHighlighted: false)]
    }
}
