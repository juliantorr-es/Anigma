import Foundation

// MARK: - TUIEnvironment
/// Dependency injection container for the TUI tree
public struct TUIEnvironment: Sendable {
    private var storage: [String: Sendable] = [:]

    public init() {}

    public mutating func set<T: Sendable>(_ value: T, for key: String) {
        storage[key] = value
    }

    public func get<T: Sendable>(_ key: String) -> T? {
        storage[key] as? T
    }

    public static let shared = TUIEnvironment()
}

/// Helper to access environment during render pass
public protocol EnvironmentAware {
    func resolve(_ environment: TUIEnvironment)
}
