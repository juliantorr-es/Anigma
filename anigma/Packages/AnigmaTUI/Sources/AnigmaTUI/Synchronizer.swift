import Foundation

// MARK: - TUISynchronizer
/// Mirrors remote PlatformRuntime state to the local TUI loop
public actor TUISynchronizer {
    private let state: TUIState

    public init(state: TUIState) {
        self.state = state
    }

    /// Entry point for SSE-style events from the runtime
    public func handleRemoteEvent(_ event: RemoteEvent) async {
        // Logic to update TUIState reactively
        switch event {
        case .governanceChanged(_):
            // state.mode = newMode
            break
        case .evidenceGenerated(_):
            // state.lastReceipt = receipt
            break
        }
    }
}

public enum RemoteEvent: Sendable {
    case governanceChanged(String)
    case evidenceGenerated(String)
}
