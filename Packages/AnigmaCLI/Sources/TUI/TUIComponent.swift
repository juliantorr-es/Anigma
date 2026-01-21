import Foundation

/// Protocol for a modular TUI component
public protocol TUIComponent: AnyObject {
    /// Unique identifier for the component
    var id: String { get }

    /// Whether the component is currently visible and should be rendered
    var isVisible: Bool { get set }

    /// Whether the component has changes that require a re-render
    var isDirty: Bool { get set }

    /// Renders the component into the TUI frame
    /// - Parameters:
    ///   - engine: The TUI rendering engine
    ///   - rect: The allocated region for this component
    func render(engine: TUIEngine, rect: TUIRect) async

    /// Handles a raw key event
    /// - Returns: True if the event was consumed by this component
    func handleKey(_ key: InputHandler.Key) async -> Bool

    /// Called when the component gains focus
    func onFocus() async

    /// Called when the component loses focus
    func onBlur() async
}

/// Base class for TUI components with common functionality
public class TUIBaseComponent: TUIComponent {
    public let id: String
    public var isVisible: Bool = true
    public var isDirty: Bool = true
    public var isFocused: Bool = false

    public init(id: String) {
        self.id = id
    }

    public func render(engine: TUIEngine, rect: TUIRect) async {
        // To be implemented by subclasses
    }

    public func handleKey(_ key: InputHandler.Key) async -> Bool {
        return false
    }

    public func onFocus() async {
        isFocused = true
        markDirty()
    }

    public func onBlur() async {
        isFocused = false
        markDirty()
    }

    public func markDirty() {
        self.isDirty = true
    }
}
