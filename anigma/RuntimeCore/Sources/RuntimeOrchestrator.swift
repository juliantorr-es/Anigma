import Foundation
import AnigmaCore

public actor RuntimeOrchestrator {
    public static let shared = RuntimeOrchestrator()
    
    private let kernel: KernelBridge
    private let eventLog: EventLog
    private let snapshotManager: SnapshotManager
    private let governance: GovernanceGate
    
    private var semanticState: SemanticState
    private var sessionConfig: SessionConfig
    private var sessionId: UUID
    private var eventIndex: UInt64 = 0
    
    private var isInitialized: Bool = false
    
    public init() {
        self.kernel = KernelBridge()
        self.eventLog = EventLog()
        self.snapshotManager = SnapshotManager()
        self.governance = GovernanceGate()
        self.semanticState = SemanticState()
        self.sessionConfig = SessionConfig()
        self.sessionId = UUID()
    }
    
    public func initialize(config: SessionConfig) async throws {
        guard !isInitialized else {
            throw OrchestratorError.alreadyInitialized
        }
        
        sessionConfig = config
        
        let initRequest = Kernel.InitializeRequest(
            profile: DeterminismProfile.default,
            configHash: config.configHash,
            initialEntityCapacity: config.initialEntityCapacity,
            initialComponentCapacity: config.initialComponentCapacity
        )
        
        let response = try await kernel.initialize(request: initRequest)
        
        sessionId = UUID()
        eventIndex = 0
        isInitialized = true
        
        await snapshotManager.recordInitialization(
            sessionId: sessionId,
            kernelInstanceId: response.instanceId,
            configHash: config.configHash
        )
    }
    
    public func frame(
        inputs: PlatformEventBatch,
        viewport: Viewport,
        deltaTime: TimeInterval
    ) async throws -> FrameReceipt {
        guard isInitialized else {
            throw OrchestratorError.notInitialized
        }
        
        let frameStart = CACurrentMediaTime()
        
        let canonicalEvents = try await normalizeEvents(inputs)
        let filteredEvents = try governance.filter(events: canonicalEvents, state: semanticState)
        let eventReceipt = try eventLog.append(events: filteredEvents)
        
        let intents = try await deriveIntents(from: filteredEvents)
        let diffs = try produceDiffs(from: intents)
        
        let kernelReceipt = try await kernel.applyDiffs(diffs)
        
        let stepRequest = Kernel.SimulationStepRequest(
            deltaTicks: TimeUtils.secondsToTicks(deltaTime),
            maxSteps: 4
        )
        let simReceipt = try await kernel.stepSimulation(request: stepRequest)
        
        let renderRequest = Kernel.RenderPlanRequest(
            viewport: viewport.toKernelRect(),
            renderFlags: 0
        )
        let renderPlan = try await kernel.generateRenderPlan(request: renderRequest)
        
        let stateHash = try await kernel.computeStateHash()
        
        let receipt = FrameReceipt(
            eventReceipt: eventReceipt,
            kernelReceipt: kernelReceipt,
            simReceipt: simReceipt,
            stateHash: stateHash,
            renderPlan: renderPlan,
            frameTime: CACurrentMediaTime() - frameStart
        )
        
        await snapshotManager.recordFrame(receipt: receipt)
        
        return receipt
    }
    
    private func normalizeEvents(_ inputs: PlatformEventBatch) async throws -> [CanonicalEvent] {
        return inputs.events.enumerated().map { index, event in
            CanonicalEvent(
                eventIndex: eventIndex + UInt64(index),
                eventType: normalizeEventType(event),
                deviceIndependentFields: extractDeviceIndependent(from: event),
                timestamp: TimeUtils.monotonicNow(),
                provenance: .platform(event.source)
            )
        }
    }
    
    private func normalizeEventType(_ event: OSEvent) -> EventType {
        switch event {
        case .pointer(let pointerEvent):
            switch pointerEvent.phase {
            case .began: return .pointerDown
            case .moved: return .pointerMove
            case .ended: return .pointerUp
            case .cancelled: return .pointerCancel
            }
        case .scroll(let scrollEvent):
            return .scrollWheel
        case .key(let keyEvent):
            return keyEvent.isKeyDown ? .keyDown : .keyUp
        case .magnify:
            return .magnify
        case .rotate:
            return .rotate
        }
    }
    
    private func extractDeviceIndependent(from event: OSEvent) -> DeviceIndependentFields {
        switch event {
        case .pointer(let pointer):
            return DeviceIndependentFields(
                position: .init(x: pointer.position.x, y: pointer.position.y),
                modifierFlags: pointer.modifierFlags,
                buttonMask: pointer.buttonMask,
                clickCount: pointer.clickCount
            )
        case .scroll(let scroll):
            return DeviceIndependentFields(
                position: .init(x: scroll.position.x, y: scroll.position.y),
                modifierFlags: scroll.modifierFlags,
                scrollDelta: .init(x: scroll.deltaX, y: scroll.deltaY),
                scrollPhase: scroll.phase
            )
        case .key(let key):
            return DeviceIndependentFields(
                keyCode: key.keyCode,
                modifierFlags: key.modifierFlags,
                isRepeat: key.isRepeat
            )
        }
    }
    
    private func deriveIntents(from events: [CanonicalEvent]) async throws -> [Intent] {
        var intents: [Intent] = []
        
        for event in events {
            switch event.eventType {
            case .pointerDown:
                if let target = try await performHitTest(at: event.deviceIndependentFields.position) {
                    let intent = Intent.select(
                        target: target.entityId,
                        mode: semanticState.currentToolMode.selectionMode
                    )
                    intents.append(intent)
                }
                
            case .pointerMove:
                if let target = try await performHitTest(at: event.deviceIndependentFields.position) {
                    let intent = Intent.hover(target: target.entityId)
                    intents.append(intent)
                }
                
            case .pointerUp:
                let intent = Intent.endInteraction
                intents.append(intent)
                
            case .scrollWheel:
                let delta = event.deviceIndependentFields.scrollDelta ?? .zero
                if event.deviceIndependentFields.modifierFlags.contains(.command) {
                    let intent = Intent.zoom(factor: 1.0 + delta.y * 0.01, center: event.deviceIndependentFields.position)
                    intents.append(intent)
                } else {
                    let intent = Intent.pan(delta: .init(x: -delta.x, y: delta.y))
                    intents.append(intent)
                }
                
            case .keyDown:
                if event.deviceIndependentFields.keyCode == KeyCode.space {
                    let intent = Intent.togglePanZoom(mode: semanticState.currentToolMode)
                    intents.append(intent)
                }
                
            default:
                break
            }
        }
        
        return intents
    }
    
    private func produceDiffs(from intents: [Intent]) throws -> [SceneDiff] {
        var diffs: [SceneDiff] = []
        
        for intent in intents {
            switch intent {
            case .select(let targetId, let mode):
                let diff = SceneDiff.updateProperty(
                    entityId: targetId,
                    propertyPath: "selectionState",
                    value: PropertyValue.selectionState(mode)
                )
                diffs.append(diff)
                
            case .hover(let targetId):
                let diff = SceneDiff.updateProperty(
                    entityId: targetId,
                    propertyPath: "hoverState",
                    value: PropertyValue.hoverState(true)
                )
                diffs.append(diff)
                
            case .pan(let delta):
                if let viewport = semanticState.currentViewport {
                    let newOrigin = Point(
                        x: viewport.origin.x + delta.x,
                        y: viewport.origin.y + delta.y
                    )
                    let diff = SceneDiff.updateProperty(
                        entityId: viewport.id,
                        propertyPath: "origin",
                        value: PropertyValue.point(newOrigin)
                    )
                    diffs.append(diff)
                }
                
            case .zoom(let factor, let center):
                if let viewport = semanticState.currentViewport {
                    let newScale = viewport.scale * factor
                    let diff = SceneDiff.updateProperty(
                        entityId: viewport.id,
                        propertyPath: "scale",
                        value: PropertyValue.float(newScale)
                    )
                    diffs.append(diff)
                }
                
            case .endInteraction:
                semanticState.clearTransientState()
                
            default:
                break
            }
        }
        
        return diffs
    }
    
    private func performHitTest(at point: Point) async throws -> HitResult? {
        let query = Kernel.HitQuery(
            point: .init(x: anigma_coord_from_float(Float(point.x)), y: anigma_coord_from_float(Float(point.y))),
            flags: 0,
            maxResults: 1,
            excludeIds: [],
            excludeCount: 0
        )
        
        let result = try await kernel.hitTest(query: query)
        
        guard result.resultCount > 0 else {
            return nil
        }
        
        return HitResult(
            entityId: result.results[0].entityId,
            localPoint: result.results[0].local_point,
            hitReason: HitReason(rawValue: result.results[0].hit_reason) ?? .bounds
        )
    }
}

public enum OrchestratorError: Error, LocalizedError {
    case notInitialized
    case alreadyInitialized
    case governanceRejected
    case kernelError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "RuntimeOrchestrator has not been initialized"
        case .alreadyInitialized:
            return "RuntimeOrchestrator is already initialized"
        case .governanceRejected:
            return "Event was rejected by governance gate"
        case .kernelError(let message):
            return "Kernel error: \(message)"
        }
    }
}
