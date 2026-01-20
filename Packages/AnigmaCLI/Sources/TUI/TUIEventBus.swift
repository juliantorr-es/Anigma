import Foundation

/// Events that can be published on the TUI event bus
public enum TUIEvent: Sendable {
    case messageAdded(role: String, content: String)
    case tokenReceived(token: String) // For streaming updates to the last message
    case inputCommitted(text: String)
    case statusUpdated(message: String?)
    case toolCallStarted(name: String)
    case toolCallCompleted(name: String, success: Bool)
    case focusChanged(toId: String)
}

/// A simple, thread-safe event bus for TUI component communication
public actor TUIEventBus {
    public static let shared = TUIEventBus()

    private var subscribers: [UUID: @Sendable (TUIEvent) -> Void] = [:]

    private init() {}

    /// Subscribe to events. Returns a UUID that can be used to unsubscribe.
    public func subscribe(_ callback: @escaping @Sendable (TUIEvent) -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = callback
        return id
    }

    /// Unsubscribe from events
    public func unsubscribe(id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    /// Publish an event to all subscribers
    public func publish(_ event: TUIEvent) {
        for callback in subscribers.values {
            callback(event)
        }
    }
}
