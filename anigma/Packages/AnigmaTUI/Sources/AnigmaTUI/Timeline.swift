import Foundation

// MARK: - SessionTimeline
public struct SessionTimeline: Renderable {
    public struct Milestone: Sendable {
        let timestamp: Date
        let summary: String
        let receiptId: String
    }

    public var milestones: [Milestone]
    public var currentMilestoneId: String?

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        // Vertical timeline representation
        for (i, milestone) in milestones.enumerated() {
            let isCurrent = milestone.receiptId == currentMilestoneId
            let prefix = isCurrent ? " ● " : " │ "
            let text = "\(prefix)\(milestone.summary)"

            Text(text, foreground: isCurrent ? .brightCyan : .gray).render(in: Rect(x: frame.origin.x, y: frame.origin.y + i, width: text.count, height: 1), to: buffer)
        }
    }
}

// MARK: - TimeTravelEngine
public actor TimeTravelEngine {
    public func fork(at receiptId: String) async {
        // Logic to rewind the EvidenceAuthority and branch the session
    }
}
