import Foundation

/// Error types for module initialization
public enum MCPModuleInitializationError: Error, Sendable {
    case timeout(moduleName: String, elapsed: TimeInterval)
    case initializationFailed(moduleName: String, underlying: Error)
    case moduleNotFound(moduleName: String)
    case alreadyInitialized(moduleName: String)
}

/// Manages module initialization state and provides barriers for tool execution
public actor MCPModuleInitializer {
    public struct ModuleInfo: Sendable {
        public let name: String
        public let status: ModuleStatus
        public let startedAt: Date?
        public let completedAt: Date?
        public let error: String?

        var elapsedTime: TimeInterval? {
            guard let startedAt = startedAt else { return nil }
            let end = completedAt ?? Date()
            return end.timeIntervalSince(startedAt)
        }
    }

    private var modules: [String: ModuleInfo] = [:]
    private var continuations: [String: [CheckedContinuation<Void, Error>]] = [:]
    private let defaultTimeout: TimeInterval = 10.0

    public init() {}

    /// Manually marks a module as ready (useful for sequential initialization)
    public func markAsReady(name: String) {
        modules[name] = ModuleInfo(
            name: name,
            status: .ready,
            startedAt: modules[name]?.startedAt ?? Date(),
            completedAt: Date(),
            error: nil
        )
        notifyWaiters(name)
    }

    /// Manually marks a module as failed
    public func markAsFailed(name: String, error: String) {
        modules[name] = ModuleInfo(
            name: name,
            status: .failed,
            startedAt: modules[name]?.startedAt ?? Date(),
            completedAt: Date(),
            error: error
        )
        notifyWaitersWithError(name, NSError(domain: "ModuleInit", code: 1, userInfo: [NSLocalizedDescriptionKey: error]))
    }

    /// Registers a module and starts initialization
    public func initializeModule(
        name: String,
        timeout: TimeInterval? = nil,
        _ initFn: @escaping @Sendable () async throws -> Void
    ) {
        let timeout = timeout ?? defaultTimeout

        // Mark as initializing
        modules[name] = ModuleInfo(
            name: name,
            status: .initializing,
            startedAt: Date(),
            completedAt: nil,
            error: nil
        )

        // Run initialization in background
        Task {
            do {
                try await withTimeoutThrows(timeout) {
                    try await initFn()
                }

                // Mark as ready
                modules[name] = ModuleInfo(
                    name: name,
                    status: .ready,
                    startedAt: modules[name]?.startedAt,
                    completedAt: Date(),
                    error: nil
                )

                // Resume all waiting continuations
                notifyWaiters(name)
            } catch {
                let errorMsg: String
                if error is TimeoutError {
                    errorMsg = "Initialization timeout after \(timeout)s"
                } else {
                    errorMsg = error.localizedDescription
                }

                // Mark as failed
                modules[name] = ModuleInfo(
                    name: name,
                    status: .failed,
                    startedAt: modules[name]?.startedAt,
                    completedAt: Date(),
                    error: errorMsg
                )

                // Resume all waiting continuations with error
                notifyWaitersWithError(name, error)
            }
        }
    }

    /// Waits for a module to be ready, or throws if initialization fails/times out
    public func waitForModule(_ name: String) async throws {
        // Check current status
        if let module = modules[name] {
            switch module.status {
            case .ready:
                return  // Already ready
            case .failed:
                throw MCPModuleInitializationError.initializationFailed(
                    moduleName: name,
                    underlying: NSError(domain: "ModuleInit", code: 1, userInfo: ["message": module.error ?? "Unknown error"])
                )
            case .initializing, .pending:
                break  // Continue to wait below
            }
        }

        // Wait for module to be ready
        return try await withCheckedThrowingContinuation { continuation in
            // Add to waiters list
            if continuations[name] == nil {
                continuations[name] = []
            }
            continuations[name]?.append(continuation)
        }
    }

    /// Non-blocking check if module is ready
    public func isModuleReady(_ name: String) -> Bool {
        modules[name]?.status == .ready
    }

    /// Gets status of all modules
    public func getModuleStatuses() -> [String: ModuleInfo] {
        modules
    }

    /// Gets status of a specific module
    public func getModuleStatus(_ name: String) -> ModuleInfo? {
        modules[name]
    }

    // MARK: - Private Helpers

    private func notifyWaiters(_ name: String) {
        guard let waiters = continuations.removeValue(forKey: name) else { return }
        for continuation in waiters {
            continuation.resume()
        }
    }

    private func notifyWaitersWithError(_ name: String, _ error: Error) {
        guard let waiters = continuations.removeValue(forKey: name) else { return }
        for continuation in waiters {
            continuation.resume(throwing: MCPModuleInitializationError.initializationFailed(moduleName: name, underlying: error))
        }
    }
}

// MARK: - Timeout Helper

/// Timeout error
public struct TimeoutError: Error, Sendable {}

/// Executes work with a timeout
public func withTimeoutThrows<T: Sendable>(_ timeout: TimeInterval, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { @Sendable in
            try await work()
        }

        group.addTask { @Sendable in
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TimeoutError()
        }

        // Return first result (whichever completes first)
        if let result = try await group.next() {
            group.cancelAll()
            return result
        }

        throw TimeoutError()
    }
}
