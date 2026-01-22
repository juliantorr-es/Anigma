import XCTest
@testable import RuntimeCore

final class DeterminismTests: XCTestCase {
    
    func testKernelDeterminism() throws {
        let kernel = KernelBridge()
        
        let config = SessionConfig()
        let initRequest = Kernel.InitializeRequest(
            profile: DeterminismProfile.default,
            configHash: config.configHash,
            initialEntityCapacity: 1024,
            initialComponentCapacity: 4096
        )
        _ = try kernel.initialize(request: initRequest)
        
        let events1 = createTestEventSequence(count: 10)
        let events2 = createTestEventSequence(count: 10)
        
        let result1 = try kernel.runEvents(events: events1)
        let result2 = try kernel.runEvents(events: events2)
        
        XCTAssertEqual(
            result1.stateHash,
            result2.stateHash,
            "State hashes must match for identical input sequences"
        )
        
        XCTAssertEqual(
            result1.renderPlanHash,
            result2.renderPlanHash,
            "Render plan hashes must match for identical input sequences"
        )
    }
    
    func testFixedStepAnimation() throws {
        let kernel = KernelBridge()
        let config = SessionConfig()
        let initRequest = Kernel.InitializeRequest(
            profile: DeterminismProfile.default,
            configHash: config.configHash,
            initialEntityCapacity: 1024,
            initialComponentCapacity: 4096
        )
        _ = try kernel.initialize(request: initRequest)
        
        let animation = createTestAnimation()
        
        let resultSingle = kernel.evaluateAnimation(animation, toTime: 1.5, steps: 1)
        let resultMany = kernel.evaluateAnimation(animation, toTime: 1.5, steps: 120)
        
        XCTAssertEqual(
            resultSingle.propertyValues,
            resultMany.propertyValues,
            "Animation evaluated in one step must match animation evaluated in 120 steps"
        )
    }
    
    func testTimeTickConsistency() throws {
        let kernel = KernelBridge()
        let config = SessionConfig()
        let initRequest = Kernel.InitializeRequest(
            profile: DeterminismProfile.default,
            configHash: config.configHash,
            initialEntityCapacity: 1024,
            initialComponentCapacity: 4096
        )
        _ = try kernel.initialize(request: initRequest)
        
        let tickResults = (0..<100).map { tick in
            kernel.evaluateAtTick(Int64(tick))
        }
        
        let uniqueHashes = Set(tickResults.map { $0.stateHash })
        
        XCTAssertEqual(
            uniqueHashes.count,
            100,
            "Each tick must produce a unique state hash"
        )
        
        let reverseResults = (0..<100).reversed().map { tick in
            kernel.evaluateAtTick(Int64(tick))
        }
        
        for i in 0..<100 {
            XCTAssertEqual(
                tickResults[i].stateHash,
                reverseResults[99 - i].stateHash,
                "Reversed evaluation must produce same results (time is monotonic)"
            )
        }
    }
    
    func testCoordinateQuantization() throws {
        let rawValues: [Float] = [0.0, 0.1, 0.25, 0.333333, 0.5, 0.666666, 1.0, 1.41421356, 3.14159]
        
        let quantized = rawValues.map { anigma_coord_from_float($0) }
        let restored = quantized.map { anigma_coord_to_float($0) }
        
        for (original, restoredValue) in zip(rawValues, restored) {
            XCTAssertEqual(
                original,
                restoredValue,
                accuracy: 1.0 / Float(ANIGMA_COORDINATE_SCALE),
                "Quantization must be reversible within grid precision"
            )
        }
    }
    
    func testEntityIdStability() throws {
        let id1 = EntityId.derive(from: "node123", namespace: "scene", localCounter: 0)
        let id2 = EntityId.derive(from: "node123", namespace: "scene", localCounter: 0)
        let id3 = EntityId.derive(from: "node123", namespace: "scene", localCounter: 1)
        let id4 = EntityId.derive(from: "node456", namespace: "scene", localCounter: 0)
        
        XCTAssertEqual(id1, id2, "Same inputs must produce same ID")
        XCTAssertNotEqual(id1, id3, "Different counter must produce different ID")
        XCTAssertNotEqual(id1, id4, "Different document node must produce different ID")
    }
    
    func testRenderPlanDeterminism() throws {
        let kernel = KernelBridge()
        let config = SessionConfig()
        let initRequest = Kernel.InitializeRequest(
            profile: DeterminismProfile.default,
            configHash: config.configHash,
            initialEntityCapacity: 1024,
            initialComponentCapacity: 4096
        )
        _ = try kernel.initialize(request: initRequest)
        
        let scene = createTestScene()
        kernel.loadScene(scene)
        
        let viewport = Viewport(
            id: EntityId(high: 0, low: 1),
            origin: Point(x: 0, y: 0),
            size: Size(width: 800, height: 600),
            scale: 1.0
        )
        
        let plan1 = try kernel.generateRenderPlan(viewport: viewport)
        let plan2 = try kernel.generateRenderPlan(viewport: viewport)
        
        XCTAssertEqual(
            plan1.planHash,
            plan2.planHash,
            "Same scene and viewport must produce identical render plans"
        )
        
        XCTAssertEqual(
            plan1.ops.count,
            plan2.ops.count,
            "Op count must match"
        )
        
        for (op1, op2) in zip(plan1.ops, plan2.ops) {
            XCTAssertEqual(op1.type, op2.type, "Op types must match")
            XCTAssertEqual(op1.layerId, op2.layerId, "Layer IDs must match")
        }
    }
    
    func testDiffApplicationOrder() throws {
        let kernel = KernelBridge()
        let config = SessionConfig()
        let initRequest = Kernel.InitializeRequest(
            profile: DeterminismProfile.default,
            configHash: config.configHash,
            initialEntityCapacity: 1024,
            initialComponentCapacity: 4096
        )
        _ = try kernel.initialize(request: initRequest)
        
        let baseScene = createTestScene()
        kernel.loadScene(baseScene)
        
        let transform1 = Transform()
        let transform2 = Transform()
        
        let diffs1: [SceneDiff] = [
            .transform(entityId: EntityId(high: 0, low: 1), transform: transform1),
            .transform(entityId: EntityId(high: 0, low: 2), transform: transform2)
        ]
        
        let diffs2: [SceneDiff] = [
            .transform(entityId: EntityId(high: 0, low: 2), transform: transform2),
            .transform(entityId: EntityId(high: 0, low: 1), transform: transform1)
        ]
        
        let kernel1 = KernelBridge()
        _ = try kernel1.initialize(request: initRequest)
        kernel1.loadScene(baseScene)
        kernel1.applyDiffs(diffs1)
        let hash1 = try kernel1.computeStateHash()
        
        let kernel2 = KernelBridge()
        _ = try kernel2.initialize(request: initRequest)
        kernel2.loadScene(baseScene)
        kernel2.applyDiffs(diffs2)
        let hash2 = try kernel2.computeStateHash()
        
        XCTAssertEqual(
            hash1,
            hash2,
            "Commutative diffs in different order must produce same result"
        )
    }
    
    func testEventIndexOrdering() throws {
        let orchestrator = RuntimeOrchestrator()
        let config = SessionConfig()
        
        try await orchestrator.initialize(config: config)
        
        let batch1 = PlatformEventBatch(events: [
            .pointer(PointerEvent(phase: .began, position: Point(x: 100, y: 100))),
            .pointer(PointerEvent(phase: .moved, position: Point(x: 110, y: 100))),
            .pointer(PointerEvent(phase: .ended, position: Point(x: 110, y: 100)))
        ])
        
        let receipt1 = try await orchestrator.frame(
            inputs: batch1,
            viewport: Viewport(
                id: EntityId(high: 0, low: 1),
                origin: Point(x: 0, y: 0),
                size: Size(width: 800, height: 600)
            ),
            deltaTime: 1.0/60.0
        )
        
        let batch2 = PlatformEventBatch(events: [
            .pointer(PointerEvent(phase: .began, position: Point(x: 100, y: 100))),
            .pointer(PointerEvent(phase: .moved, position: Point(x: 110, y: 100))),
            .pointer(PointerEvent(phase: .ended, position: Point(x: 110, y: 100)))
        ])
        
        let receipt2 = try await orchestrator.frame(
            inputs: batch2,
            viewport: Viewport(
                id: EntityId(high: 0, low: 1),
                origin: Point(x: 0, y: 0),
                size: Size(width: 800, height: 600)
            ),
            deltaTime: 1.0/60.0
        )
        
        XCTAssertGreaterThan(
            receipt2.eventReceipt.firstEventIndex,
            receipt1.eventReceipt.firstEventIndex,
            "Event indices must be monotonically increasing"
        )
    }
    
    func testSnapshotRestoreDeterminism() throws {
        let kernel = KernelBridge()
        let config = SessionConfig()
        let initRequest = Kernel.InitializeRequest(
            profile: DeterminismProfile.default,
            configHash: config.configHash,
            initialEntityCapacity: 1024,
            initialComponentCapacity: 4096
        )
        _ = try kernel.initialize(request: initRequest)
        
        let scene = createTestScene()
        kernel.loadScene(scene)
        
        let events = createTestEventSequence(count: 50)
        kernel.runEvents(events: events)
        
        let snapshot = try kernel.exportSnapshot()
        
        let kernel2 = KernelBridge()
        _ = try kernel2.initialize(request: initRequest)
        try kernel2.importSnapshot(snapshot)
        
        let restoredEvents = createTestEventSequence(count: 20)
        kernel.runEvents(events: restoredEvents)
        
        let finalHash1 = try kernel.computeStateHash()
        let finalHash2 = try kernel2.computeStateHash()
        
        XCTAssertEqual(
            finalHash1,
            finalHash2,
            "Restored session must produce same final state"
        )
    }
    
    private func createTestEventSequence(count: Int) -> [OSEvent] {
        var events: [OSEvent] = []
        
        for i in 0..<count {
            let position = Point(x: Double(100 + i * 10), y: Double(100 + i * 5))
            events.append(.pointer(PointerEvent(phase: .moved, position: position)))
        }
        
        return events
    }
    
    private func createTestAnimation() -> Animation {
        Animation(
            tracks: [
                AnimationTrack(
                    targetId: EntityId(high: 0, low: 1),
                    propertyPath: "transform.position.x",
                    keyframes: [
                        Keyframe(time: 0, value: 0, easing: .linear),
                        Keyframe(time: 1, value: 100, easing: .linear),
                        Keyframe(time: 2, value: 0, easing: .linear)
                    ]
                )
            ]
        )
    }
    
    private func createTestScene() -> Scene {
        Scene(nodes: [
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
                layerIndex: 0,
                renderOrder: 1
            )
        ])
    }
}

struct PointerEvent: OSEvent {
    var phase: PointerPhase
    var position: Point
    var modifierFlags: ModifierFlags = []
    var buttonMask: UInt32 = 0
    var clickCount: UInt32 = 0
}

enum PointerPhase {
    case began, moved, ended, cancelled
}

struct Animation {
    var tracks: [AnimationTrack]
}

struct AnimationTrack {
    var targetId: EntityId
    var propertyPath: String
    var keyframes: [Keyframe]
}

struct Keyframe {
    var time: Double
    var value: Float
    var easing: EasingMode
}

enum EasingMode {
    case linear
    case easeInOut
    case spring
}

struct Scene {
    var nodes: [SceneNode]
}

struct SceneNode {
    var id: EntityId
    var parentId: EntityId?
    var transform: Transform
    var layerIndex: UInt32
    var renderOrder: UInt32
}

protocol OSEvent {
    var source: String { get }
}

extension PointerEvent: OSEvent {
    var source: String { "pointer" }
}
