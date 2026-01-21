import Foundation

// MARK: - EvidenceGraph
public struct EvidenceGraph: Renderable {
    public struct Node: Sendable {
        let id: String
        let hash: String
        let operation: String
        let children: [Node]
    }

    public var root: Node

    public init(root: Node) {
        self.root = root
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        renderNode(root, depth: 0, y: frame.origin.y, x: frame.origin.x, to: buffer)
    }

    private func renderNode(_ node: Node, depth: Int, y: Int, x: Int, to buffer: TerminalBuffer) {
        let prefix = String(repeating: "  ", count: depth) + (depth > 0 ? "┗━ " : "◈ ")
        let text = "\(prefix)\(node.operation) [\(node.hash.prefix(8))]"
        Text(text, foreground: depth == 0 ? .brightCyan : .gray).render(in: Rect(x: x, y: y, width: text.count, height: 1), to: buffer)

        var currentY = y + 1
        for child in node.children {
            renderNode(child, depth: depth + 1, y: currentY, x: x, to: buffer)
            currentY += 1 // Simplified: needs actual tree height calculation
        }
    }
}

// MARK: - WriteGateModal
public struct WriteGateModal: Renderable {
    public var proposal: String
    public var onApprove: @Sendable () -> Void

    public init(proposal: String, onApprove: @escaping @Sendable () -> Void) {
        self.proposal = proposal
        self.onApprove = onApprove
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let box = Box(borderColor: .brightYellow, title: "⚠️ GOVERNANCE APPROVAL REQUIRED", padding: 1) {
            VStack(spacing: 1) {
                Text("The agent is requesting to modify the following:", foreground: .white)
                Text(proposal, foreground: .brightYellow, attributes: [.italic])
                Spacer()
                HStack {
                    Text("[Y] Approve & Sign", foreground: .black, background: .brightGreen)
                    Spacer()
                    Text("[N] Reject", foreground: .black, background: .brightRed)
                }
            }
        }
        box.render(in: frame, to: buffer)
    }
}
