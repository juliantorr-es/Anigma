import Foundation

// MARK: - SignalHandler
/// Handles UNIX signals for hot-reloading (SIGUSR2)
public actor SignalHandler {
    private let onReload: @Sendable () -> Void

    public init(onReload: @escaping @Sendable () -> Void) {
        self.onReload = onReload
    }

    public func start() {
        let signalSource = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
        signalSource.setEventHandler {
            self.onReload()
        }
        signalSource.resume()
        signal(SIGUSR2, SIG_IGN)
    }
}
