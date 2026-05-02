import Foundation
import AnigmaTUI

/// A data-centric inspector view for the TUI.
/// Shows active context spans and the evidence chain (provenance).
public final class DataInspectorView: TUIBaseComponent {
    private var spans: [String] = []
    private var evidence: [String] = []
    
    public init() {
        super.init(id: "data_inspector")
    }
    
    public func update(spans: [String], evidence: [String]) {
        self.spans = spans
        self.evidence = evidence
        markDirty()
    }
    
    public override func render(engine: TUIEngine, rect: TUIRect) async {
        // Draw border
        await engine.drawBox(
            row: rect.row, 
            col: rect.col, 
            width: rect.width, 
            height: rect.height, 
            title: "INSPECTOR", 
            color: TUIEngine.Color.brightBlack
        )
        
        var currentRow = rect.row + 1
        let col = rect.col + 2
        let maxWidth = rect.width - 4
        
        guard maxWidth > 0 && rect.height > 4 else { return }
        
        // 1. Context Spans Section
        let spanTitle = engine.styled("CONTEXT SPANS", color: .brightYellow, style: .bold)
        await engine.addToFrame(row: currentRow, col: col, text: spanTitle)
        currentRow += 1
        
        if spans.isEmpty {
            await engine.addToFrame(row: currentRow, col: col, text: engine.styled("No active context", color: TUIEngine.Color.brightBlack))
            currentRow += 1
        } else {
            for span in spans.prefix(min(8, rect.height / 2 - 2)) {
                let cleanSpan = span.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                let preview = String(cleanSpan.prefix(maxWidth - 2))
                await engine.addToFrame(row: currentRow, col: col, text: "• \(preview)")
                currentRow += 1
            }
        }
        
        // 2. Evidence Chain Section (Bottom Half)
        currentRow = rect.row + rect.height / 2
        if currentRow < rect.row + rect.height - 1 {
            let evidenceTitle = engine.styled("EVIDENCE CHAIN", color: .brightGreen, style: .bold)
            await engine.addToFrame(row: currentRow, col: col, text: evidenceTitle)
            currentRow += 1
            
            if evidence.isEmpty {
                await engine.addToFrame(row: currentRow, col: col, text: engine.styled("Awaiting execution...", color: TUIEngine.Color.brightBlack))
            } else {
                let maxEvidence = rect.row + rect.height - 2
                for entry in evidence.suffix(max(1, maxEvidence - currentRow + 1)) {
                    if currentRow > maxEvidence { break }
                    let preview = String(entry.prefix(maxWidth - 2))
                    await engine.addToFrame(row: currentRow, col: col, text: engine.styled("> ", color: .green) + preview)
                    currentRow += 1
                }
            }
        }
    }
}
