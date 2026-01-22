import XCTest
@testable import RuntimeCore
@testable import PlatformAdapters

final class RuntimeIntegrationTests: XCTestCase {
    
    func testFullRuntimeLoop() async throws {
        let orchestrator = RuntimeOrchestrator()
        
        let config = SessionConfig(
            configHash: 0xDEADBEEF,
            initialEntityCapacity: 256,
            initialComponentCapacity: 1024
        )
        
        try await orchestrator.initialize(config: config)
        
        let viewport = Viewport(
            id: EntityId(high: 0, low: 1),
            origin: Point(x: 0, y: 0),
            size: Size(width: 800, height: 600),
            scale: 1.0
        )
        
        let batch = PlatformEventBatch(events: [
            NormalizedEvent(
                eventIndex: 0,
                eventType: .pointerDown,
                position: DeviceIndependentPosition(x: 100, y: 100, screenX: 100, screenY: 100),
                timestamp: 1000000,
                deviceIndependentFields: DeviceIndependentFields(
                    position: CGPoint(x: 100, y: 100),
                    modifierFlags: [],
                    buttonMask: 1,
                    clickCount: 1
                ),
                modifierFlags: [],
                buttonMask: 1,
                clickCount: 1,
                scrollDelta: nil,
                keyCode: nil,
                isRepeat: false,
                provenance: .platform(.macOS)
            )
        ])
        
        let receipt = try await orchestrator.frame(
            inputs: batch,
            viewport: viewport,
            deltaTime: 1.0 / 60.0
        )
        
        XCTAssertGreaterThan(receipt.stateHash.count, 0)
    }
    
    func testSceneGraphWithNodes() async throws {
        let kernel = KernelBridge()
        
        let initRequest = Kernel.InitializeRequest(
            profile: .default,
            configHash: 0,
            initialEntityCapacity: 256,
            initialComponentCapacity: 1024
        )
        
        _ = try await kernel.initialize(request: initRequest)
        
        let scene = createTestScene()
        
        let viewport = Rect(x: 0, y: 0, width: anigma_coord_from_float(800), height: anigma_coord_from_float(600))
        let renderRequest = Kernel.RenderPlanRequest(viewport: viewport, renderFlags: 0)
        
        let plan = try await kernel.generateRenderPlan(request: renderRequest)
        
        XCTAssertGreaterThanOrEqual(plan.opCount, 1)
    }
    
    func testAnimationDeterminism() throws {
        let kernel = KernelBridge()
        
        let animation = Animation(tracks: [
            AnimationTrack(
                targetId: EntityId(high: 0, low: 1),
                propertyPath: "transform.position.x",
                keyframes: [
                    Keyframe(time: 0, value: 0, easing: .linear),
                    Keyframe(time: 1, value: 100, easing: .easeInOutQuad),
                    Keyframe(time: 2, value: 0, easing: .linear)
                ]
            )
        ])
        
        let result1 = kernel.evaluateAnimation(animation, toTime: 0.5, steps: 1)
        let result2 = kernel.evaluateAnimation(animation, toTime: 0.5, steps: 100)
        
        if let v1 = result1.propertyValues["transform.position.x"],
           let v2 = result2.propertyValues["transform.position.x"] {
            XCTAssertEqual(v1, v2, accuracy: 0.01)
        }
    }
    
    func testTimeTickConsistency() throws {
        let kernel = KernelBridge()
        
        let tickResults = (0..<50).map { kernel.evaluateAtTick(Int64($0) * 1000000) }
        let hashes = tickResults.map { $0.stateHash }
        
        let uniqueHashes = Set(hashes)
        
        XCTAssertEqual(uniqueHashes.count, 50)
        
        let reversedResults = (0..<50).reversed().map { kernel.evaluateAtTick(Int64($0) * 1000000) }
        
        for i in 0..<50 {
            XCTAssertEqual(
                tickResults[i].stateHash,
                reversedResults[49 - i].stateHash
            )
        }
    }
    
    func testMetalAdapterRendering() async throws {
        let adapter = MetalRenderAdapter.shared
        
        let plan = RenderPlan(
            opCount: 2,
            resourceCount: 1,
            planHash: Data([1, 2, 3, 4]),
            ops: [
                DrawOp(
                    opIndex: 0,
                    type: .clear,
                    layerId: 0,
                    transform: Transform(),
                    clip: Rect(x: 0, y: 0, width: 800, height: 600),
                    material: ResourceRef(resourceId: 0, resourceType: 0)
                ),
                DrawOp(
                    opIndex: 1,
                    type: .rect,
                    layerId: 1,
                    transform: Transform(),
                    clip: Rect(x: 100, y: 100, width: 200, height: 100),
                    material: ResourceRef(resourceId: 1, resourceType: 0)
                )
            ]
        )
        
        let viewport = Viewport(
            id: EntityId(high: 0, low: 1),
            origin: Point(x: 0, y: 0),
            size: Size(width: 800, height: 600),
            scale: 1.0
        )
        
        await adapter.execute(plan: plan, viewport: viewport)
        
        XCTAssertFalse(adapter.isRendering)
    }
    
    func testInputEventFlow() throws {
        let inputAdapter = InputPlatformAdapter.shared
        
        let mockView = NSView()
        let mockEvent = NSEvent(
            mouseType: .leftMouseDown,
            location: CGPoint(x: 100, y: 100),
            modifierFlags: [],
            timestamp: 1,
            windowNumber: 1,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 0
        )
        
        let consumed = inputAdapter.handleEvent(mockEvent, view: mockView)
        
        XCTAssertTrue(consumed)
    }
    
    func testReplayFromSnapshot() async throws {
        let orchestrator = RuntimeOrchestrator()
        
        let config = SessionConfig(
            configHash: 0xCAFEBABE,
            initialEntityCapacity: 256,
            initialComponentCapacity: 1024
        )
        
        try await orchestrator.initialize(config: config)
        
        let viewport = Viewport(
            id: EntityId(high: 0, low: 1),
            origin: Point(x: 0, y: 0),
            size: Size(width: 800, height: 600),
            scale: 1.0
        )
        
        let events1 = createEventSequence(count: 10)
        let batch1 = PlatformEventBatch(events: events1)
        let receipt1 = try await orchestrator.frame(inputs: batch1, viewport: viewport, deltaTime: 1.0/60.0)
        
        let events2 = createEventSequence(count: 10)
        let batch2 = PlatformEventBatch(events: events2)
        let receipt2 = try await orchestrator.frame(inputs: batch2, viewport: viewport, deltaTime: 1.0/60.0)
        
        XCTAssertEqual(
            receipt1.stateHash,
            receipt2.stateHash,
            "Identical event sequences must produce identical state"
        )
    }
    
    private func createTestScene() -> [SceneNode] {
        return [
            SceneNode(
                id: EntityId(high: 0, low: 1),
                parentId: nil,
                transform: Transform(),
                layerIndex: 0,
                renderOrder: 0
            ),
            SceneNode(
                id: EntityId(high: 0, low: 2),
                parentId: EntityId(high: 0, low: 1),
                transform: Transform(),
                layerIndex: 1,
                renderOrder: 1
            )
        ]
    }
    
    private func createEventSequence(count: Int) -> [NormalizedEvent] {
        return (0..<count).map { i in
            NormalizedEvent(
                eventIndex: UInt64(i),
                eventType: .pointerMove,
                position: DeviceIndependentPosition(
                    x: Float(100 + i * 10),
                    y: Float(100 + i * 5),
                    screenX: Float(100 + i * 10),
                    screenY: Float(100 + i * 5)
                ),
                timestamp: UInt64(1000000 + i * 10000),
                deviceIndependentFields: DeviceIndependentFields(
                    position: CGPoint(x: 100 + i * 10, y: 100 + i * 5),
                    modifierFlags: [],
                    buttonMask: 0,
                    clickCount: 0
                ),
                modifierFlags: [],
                buttonMask: 0,
                clickCount: 0,
                scrollDelta: nil,
                keyCode: nil,
                isRepeat: false,
                provenance: .platform(.macOS)
            )
        }
    }
}

final class RuntimePerformanceTests: XCTestCase {
    
    func testFrameLatency() async throws {
        let orchestrator = RuntimeOrchestrator()
        
        let config = SessionConfig()
        try await orchestrator.initialize(config: config)
        
        let viewport = Viewport(
            id: EntityId(high: 0, low: 1),
            origin: Point(x: 0, y: 0),
            size: Size(width: 800, height: 600),
            scale: 1.0
        )
        
        let events = createEventSequence(count: 100)
        let batch = PlatformEventBatch(events: events)
        
        measure {
            for _ in 0..<10 {
                _ = try? Task.checkCancellation()
                _ = try? await orchestrator.frame(inputs: batch, viewport: viewport, deltaTime: 1.0/60.0)
            }
        }
    }
    
    func testRenderPlanGeneration() throws {
        let kernel = KernelBridge()
        
        let initRequest = Kernel.InitializeRequest(
            profile: .default,
            configHash: 0,
            initialEntityCapacity: 1024,
            initialComponentCapacity: 4096
        )
        
        let _ = try await kernel.initialize(request: initRequest)
        
        measure {
            for _ in 0..<100 {
                let viewport = Rect(x: 0, y: 0, width: anigma_coord_from_float(800), height: anigma_coord_from_float(600))
                let request = Kernel.RenderPlanRequest(viewport: viewport, renderFlags: 0)
                _ = try? kernel.generateRenderPlan(request: request)
            }
        }
    }
    
    private func createEventSequence(count: Int) -> [NormalizedEvent] {
        return (0..<count).map { i in
            NormalizedEvent(
                eventIndex: UInt64(i),
                eventType: .pointerMove,
                position: DeviceIndependentPosition(x: Float(i), y: Float(i), screenX: Float(i), screenY: Float(i)),
                timestamp: UInt64(i),
                deviceIndependentFields: DeviceIndependentFields(
                    position: CGPoint(x: CGFloat(i), y: CGFloat(i)),
                    modifierFlags: [],
                    buttonMask: 0,
                    clickCount: 0
                ),
                modifierFlags: [],
                buttonMask: 0,
                clickCount: 0,
                scrollDelta: nil,
                keyCode: nil,
                isRepeat: false,
                provenance: .platform(.macOS)
            )
        }
    }
}

final class DeterminismVerificationTests: XCTestCase {
    
    func testIdenticalRunsProduceIdenticalHashes() async throws {
        let orchestrator = RuntimeOrchestrator()
        
        let config = SessionConfig()
        try await orchestrator.initialize(config: config)
        
        let viewport = Viewport(
            id: EntityId(high: 0, low: 1),
            origin: Point(x: 0, y: 0),
            size: Size(width: 800, height: 600),
            scale: 1.0
        )
        
        let events = createEventSequence(count: 20)
        let batch = PlatformEventBatch(events: events)
        
        let receipts = try await withThrowingTaskGroup(of: FrameReceipt.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    try await orchestrator.frame(inputs: batch, viewport: viewport, deltaTime: 1.0/60.0)
                }
            }
            
            var results: [FrameReceipt] = []
            for try await receipt in group {
                results.append(receipt)
            }
            return results
        }
        
        let hashes = receipts.map { $0.stateHash }
        let uniqueHashes = Set(hashes)
        
        XCTAssertEqual(
            uniqueHashes.count,
            1,
            "All runs must produce identical state hash"
        )
    }
    
    func testDifferentEventsProduceDifferentHashes() async throws {
        let orchestrator = RuntimeOrchestrator()
        
        let config = SessionConfig()
        try await orchestrator.initialize(config: config)
        
        let viewport = Viewport(
            id: EntityId(high: 0, low: 1),
            origin: Point(x: 0, y: 0),
            size: Size(width: 800, height: 600),
            scale: 1.0
        )
        
        let events1 = createEventSequence(count: 10, startX: 100)
        let events2 = createEventSequence(count: 10, startX: 200)
        
        let batch1 = PlatformEventBatch(events: events1)
        let batch2 = PlatformEventBatch(events: events2)
        
        let receipt1 = try await orchestrator.frame(inputs: batch1, viewport: viewport, deltaTime: 1.0/60.0)
        let receipt2 = try await orchestrator.frame(inputs: batch2, viewport: viewport, deltaTime: 1.0/60.0)
        
        XCTAssertNotEqual(
            receipt1.stateHash,
            receipt2.stateHash,
            "Different events must produce different state"
        )
    }
    
    private func createEventSequence(count: Int, startX: Int) -> [NormalizedEvent] {
        return (0..<count).map { i in
            NormalizedEvent(
                eventIndex: UInt64(i),
                eventType: .pointerMove,
                position: DeviceIndependentPosition(
                    x: Float(startX + i * 10),
                    y: Float(i * 5),
                    screenX: Float(startX + i * 10),
                    screenY: Float(i * 5)
                ),
                timestamp: UInt64(i),
                deviceIndependentFields: DeviceIndependentFields(
                    position: CGPoint(x: CGFloat(startX + i * 10), y: CGFloat(i * 5)),
                    modifierFlags: [],
                    buttonMask: 0,
                    clickCount: 0
                ),
                modifierFlags: [],
                buttonMask: 0,
                clickCount: 0,
                scrollDelta: nil,
                keyCode: nil,
                isRepeat: false,
                provenance: .platform(.macOS)
            )
        }
    }
}
