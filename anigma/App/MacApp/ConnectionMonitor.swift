import Combine
import Foundation
import AnigmaHostMac

/// Monitors daemon connectivity independently of other operations.
@MainActor
public final class ConnectionMonitor: ObservableObject {
    @Published public private(set) var isOnline: Bool = false

    private let capability: DaemonHostCapability
    private var timer: AnyCancellable?

    public init(capability: DaemonHostCapability) {
        self.capability = capability
    }

    /// Starts periodic connectivity checks.
    public func start() {
        timer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkConnection()
                }
            }

        // Initial check
        Task {
            await checkConnection()
        }
    }

    /// Stops periodic checks.
    public func stop() {
        timer?.cancel()
        timer = nil
    }

    private func checkConnection() async {
        let status = await capability.getDaemonStatus()
        let newStatus = (status == .running)

        if isOnline != newStatus {
            isOnline = newStatus
        }
    }
}
