import Foundation

/// Component for the status bar at the bottom of the screen
@MainActor
public final class StatusBarView: TUIBaseComponent, @unchecked Sendable {
    private var statusMessage: String?
    private let theme = Theme.defaultTheme

    private var subscriptionId: UUID?

    public init() {
        super.init(id: "status_bar")

        Task {
            let id = await TUIEventBus.shared.subscribe { [weak self] event in
                if case .statusUpdated(let message) = event {
                    Task { @MainActor in
                        self?.setStatus(message)
                    }
                }
            }
            Task { @MainActor [weak self] in
                self?.subscriptionId = id
            }
        }
    }

    deinit {
        if let id = subscriptionId {
            Task { await TUIEventBus.shared.unsubscribe(id: id) }
        }
    }

    public func setStatus(_ message: String?) {
        self.statusMessage = message
        markDirty()
    }

    public override func render(engine: TUIEngine, rect: TUIRect) async {
        let statusText: String
        if let status = statusMessage {
            statusText = engine.styled("  \(status)  ", color: .black, bg: .yellow)
        } else {
            statusText = engine.styled("  ↑/↓: Scroll  •  Enter: Send  •  Ctrl+P: Commands  •  Ctrl+C: Exit  ", color: theme.statusBar.color, bg: theme.statusBar.bg)
        }

        // Fill the rest of the bar width with background color
        let padding = String(repeating: " ", count: max(0, rect.width - stripANSI(statusText).count))
        let fullBar = statusText + engine.styled(padding, color: theme.statusBar.color, bg: theme.statusBar.bg)

        await engine.addToFrame(row: rect.row, col: rect.col, text: fullBar)
    }

    private func stripANSI(_ text: String) -> String {
        return text.replacingOccurrences(of: #"\u{001B}\[[^m]*m"#, with: "", options: .regularExpression)
    }
}
