import AppKit
import Combine

public final class InputPlatformAdapter: NSObject, ObservableObject {
    public static let shared = InputPlatformAdapter()
    
    @Published public var isCapturing: Bool = false
    @Published public var hasFocus: Bool = false
    @Published public var lastEventPosition: CGPoint = .zero
    
    private var trackingArea: NSTrackingArea?
    private var eventMask: NSEvent.EventTypeMask = []
    private var orchestrator: RuntimeOrchestrator?
    private var eventQueue: [NormalizedEvent] = []
    private let eventQueueLock = NSLock()
    private var eventIndex: UInt64 = 0
    
    public override init() {
        super.init()
    }
    
    public func startCapture(orchestrator: RuntimeOrchestrator) {
        guard !isCapturing else { return }
        
        self.orchestrator = orchestrator
        self.eventMask = [.leftMouseDown, .leftMouseUp, .leftMouseDragged, 
                         .rightMouseDown, .rightMouseUp, .rightMouseDragged,
                         .mouseMoved, .scrollWheel, .keyDown, .keyUp,
                         .flagsChanged, .magnify, .rotate]
        
        isCapturing = true
    }
    
    public func stopCapture() {
        isCapturing = false
        hasFocus = false
        orchestrator = nil
    }
    
    public func handleEvent(_ event: NSEvent, view: NSView) -> Bool {
        guard isCapturing else { return false }
        
        let normalized = normalizeEvent(event, view: view)
        
        eventQueueLock.lock()
        eventQueue.append(normalized)
        let count = eventQueue.count
        eventQueueLock.unlock()
        
        if count >= 10 || event.isARepeat == false {
            flushEventQueue()
        }
        
        lastEventPosition = CGPoint(x: normalized.position.x, y: normalized.position.y)
        
        return shouldConsumeEvent(event)
    }
    
    private func normalizeEvent(_ event: NSEvent, view: NSView) -> NormalizedEvent {
        let locationInView = view.convert(event.locationInWindow, from: nil)
        
        let position = DeviceIndependentPosition(
            x: Float(locationInView.x),
            y: Float(view.bounds.height - locationInView.y),
            screenX: Float(event.window?.frame.origin.x ?? 0 + locationInView.x),
            screenY: Float(event.window?.frame.origin.y ?? 0 + locationInView.y)
        )
        
        return NormalizedEvent(
            eventIndex: eventIndex,
            eventType: mapEventType(event.type),
            position: position,
            timestamp: TimeUtils.monotonicNow(),
            deviceIndependentFields: extractDeviceFields(from: event),
            modifierFlags: mapModifierFlags(event.modifierFlags),
            buttonMask: mapButtonMask(event),
            clickCount: UInt32(event.clickCount),
            scrollDelta: event.type == .scrollWheel ? extractScrollDelta(from: event) : nil,
            keyCode: event.type == .keyDown || event.type == .keyUp ? UInt32(event.keyCode) : nil,
            isRepeat: event.isARepeat,
            provenance: .platform(.macOS)
        )
    }
    
    private func mapEventType(_ type: NSEvent.EventType) -> EventType {
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return .pointerDown
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return .pointerUp
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .mouseMoved:
            return .pointerMove
        case .scrollWheel:
            return .scrollWheel
        case .keyDown:
            return .keyDown
        case .keyUp:
            return .keyUp
        case .flagsChanged:
            return .flagsChanged
        case .magnify:
            return .magnify
        case .rotate:
            return .rotate
        default:
            return .unknown
        }
    }
    
    private func extractDeviceFields(from event: NSEvent) -> DeviceIndependentFields {
        return DeviceIndependentFields(
            position: CGPoint(x: event.locationInWindow.x, y: event.locationInWindow.y),
            modifierFlags: mapModifierFlags(event.modifierFlags),
            buttonMask: mapButtonMask(event),
            clickCount: UInt32(event.clickCount),
            delta: event.type == .scrollWheel ? CGPoint(
                x: (event as? NSScrollWheel)?.deltaX ?? 0,
                y: (event as? NSScrollWheel)?.deltaY ?? 0
            ) : nil,
            keyCode: event.type == .keyDown || event.type == .keyUp ? UInt32(event.keyCode) : nil,
            isRepeat: event.isARepeat
        )
    }
    
    private func mapModifierFlags(_ flags: NSEvent.ModifierFlags) -> ModifierFlags {
        var result: ModifierFlags = []
        
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.function) { result.insert(.function) }
        if flags.contains(.capsLock) { result.insert(.capsLock) }
        
        return result
    }
    
    private func mapButtonMask(_ event: NSEvent) -> UInt32 {
        var mask: UInt32 = 0
        
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            mask |= 1 << 0
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
            mask |= 1 << 1
        default:
            break
        }
        
        return mask
    }
    
    private func extractScrollDelta(from event: NSEvent) -> ScrollDelta? {
        guard let scrollWheel = event as? NSScrollWheel else { return nil }
        
        return ScrollDelta(
            x: Float(scrollWheel.deltaX),
            y: Float(scrollWheel.deltaY),
            phase: mapScrollPhase(scrollWheel.phase),
            momentumPhase: mapScrollPhase(scrollWheel.momentumPhase)
        )
    }
    
    private func mapScrollPhase(_ phase: NSEvent.ScrollPhase) -> ScrollPhase {
        switch phase {
        case .began:
            return .began
        case .changed:
            return .changed
        case .ended:
            return .ended
        case .cancelled:
            return .cancelled
        case .mayBegin:
            return .mayBegin
        default:
            return .none
        }
    }
    
    private func shouldConsumeEvent(_ event: NSEvent) -> Bool {
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            hasFocus = true
            return true
        case .keyDown, .keyUp:
            return hasFocus
        case .scrollWheel:
            return hasFocus
        default:
            return hasFocus
        }
    }
    
    private func flushEventQueue() {
        eventQueueLock.lock()
        let events = eventQueue
        eventQueue.removeAll()
        eventQueueLock.unlock()
        
        guard !events.isEmpty else { return }
        
        let batch = PlatformEventBatch(events: events)
        
        Task {
            guard let orchestrator = self.orchestrator else { return }
            do {
                _ = try await orchestrator.handleEventBatch(batch)
            } catch {
                print("Failed to process event batch: \(error)")
            }
        }
    }
    
    public func focusCanvas(_ view: NSView) {
        view.window?.makeFirstResponder(view)
        hasFocus = true
    }
    
    public func blurCanvas(_ view: NSView) {
        view.window?.resignFirstResponder()
        hasFocus = false
    }
}

public struct NormalizedEvent: Sendable {
    public let eventIndex: UInt64
    public let eventType: EventType
    public let position: DeviceIndependentPosition
    public let timestamp: UInt64
    public let deviceIndependentFields: DeviceIndependentFields
    public let modifierFlags: ModifierFlags
    public let buttonMask: UInt32
    public let clickCount: UInt32
    public let scrollDelta: ScrollDelta?
    public let keyCode: UInt32?
    public let isRepeat: Bool
    public let provenance: EventProvenance
}

public struct DeviceIndependentPosition: Sendable {
    public let x: Float
    public let y: Float
    public let screenX: Float
    public let screenY: Float
}

public struct DeviceIndependentFields: Sendable {
    public let position: CGPoint
    public let modifierFlags: ModifierFlags
    public let buttonMask: UInt32
    public let clickCount: UInt32
    public var delta: CGPoint?
    public var keyCode: UInt32?
    public var isRepeat: Bool
}

public struct ScrollDelta: Sendable {
    public let x: Float
    public let y: Float
    public let phase: ScrollPhase
    public let momentumPhase: ScrollPhase
}

public enum EventType: UInt8, Sendable {
    case unknown = 0
    case pointerDown = 1
    case pointerUp = 2
    case pointerMove = 3
    case pointerCancel = 4
    case scrollWheel = 5
    case keyDown = 6
    case keyUp = 7
    case flagsChanged = 8
    case magnify = 9
    case rotate = 10
}

public struct ModifierFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let shift = ModifierFlags(rawValue: 1 << 0)
    public static let control = ModifierFlags(rawValue: 1 << 1)
    public static let option = ModifierFlags(rawValue: 1 << 2)
    public static let command = ModifierFlags(rawValue: 1 << 3)
    public static let function = ModifierFlags(rawValue: 1 << 4)
    public static let capsLock = ModifierFlags(rawValue: 1 << 5)
}

public enum ScrollPhase: UInt8, Sendable {
    case none = 0
    case began = 1
    case changed = 2
    case ended = 3
    case cancelled = 4
    case mayBegin = 5
}

public enum EventProvenance: Sendable {
    case platform(PlatformSource)
    
    public enum PlatformSource: String, Sendable {
        case macOS = "macOS"
        case iOS = "iOS"
        case simulated = "simulated"
    }
}

public struct PlatformEventBatch: Sendable {
    public let events: [NormalizedEvent]
    
    public init(events: [NormalizedEvent]) {
        self.events = events
    }
}

extension RuntimeOrchestrator {
    public func handleEventBatch(_ batch: PlatformEventBatch) async throws {
        let events = batch.events.map { event -> CanonicalEvent in
            CanonicalEvent(
                eventIndex: event.eventIndex,
                eventType: EventType(rawValue: event.eventType.rawValue) ?? .unknown,
                deviceIndependentFields: DeviceIndependentFields(
                    position: CGPoint(x: event.position.x, y: event.position.y),
                    modifierFlags: event.modifierFlags,
                    buttonMask: event.buttonMask,
                    clickCount: event.clickCount
                ),
                timestamp: TimelineReference(monotonic: event.timestamp),
                provenance: event.provenance
            )
        }
        
        let canonicalEvents = try await normalizeEvents(PlatformEventBatch(events: batch.events))
        let filteredEvents = try governance.filter(events: canonicalEvents, state: semanticState)
        let receipt = try eventLog.append(events: filteredEvents)
        
        _ = receipt
    }
}
