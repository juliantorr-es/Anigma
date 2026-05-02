import Foundation
import MetalKit

public struct Viewport: Sendable, Codable {
    public var id: EntityId
    public var origin: Point
    public var size: Size
    public var scale: Float
    
    public init(id: EntityId, origin: Point, size: Size, scale: Float = 1.0) {
        self.id = id
        self.origin = origin
        self.size = size
        self.scale = scale
    }
    
    func toKernelRect() -> Kernel.Rect {
        Kernel.Rect(
            x: anigma_coord_from_float(Float(origin.x)),
            y: anigma_coord_from_float(Float(origin.y)),
            width: anigma_coord_from_float(Float(size.width)),
            height: anigma_coord_from_float(Float(size.height))
        )
    }
}

public struct Point: Sendable, Codable, Equatable {
    public var x: Double
    public var y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    public static let zero = Point(x: 0, y: 0)
}

public struct Size: Sendable, Codable {
    public var width: Double
    public var height: Double
    
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
    
    public static let zero = Size(width: 0, height: 0)
}

public struct EntityId: Sendable, Codable, Equatable, Hashable {
    public var high: UInt64
    public var low: UInt64
    
    public init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }
    
    public static func == (lhs: EntityId, rhs: EntityId) -> Bool {
        lhs.high == rhs.high && lhs.low == rhs.low
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(high)
        hasher.combine(low)
    }
}

public struct SemanticState: Sendable {
    public var currentToolMode: ToolMode
    public var currentViewport: Viewport?
    public var selection: Set<EntityId>
    public var hoverTarget: EntityId?
    public var documentId: String?
    
    public init() {
        self.currentToolMode = .select
        self.currentViewport = nil
        self.selection = []
        self.hoverTarget = nil
        self.documentId = nil
    }
    
    public mutating func clearTransientState() {
        self.hoverTarget = nil
    }
}

public struct SessionConfig: Sendable {
    public var configHash: UInt64
    public var initialEntityCapacity: UInt32
    public var initialComponentCapacity: UInt32
    public var enableDeterminismChecks: Bool
    public var enableReplay: Bool
    
    public init(
        configHash: UInt64 = 0,
        initialEntityCapacity: UInt32 = 1024,
        initialComponentCapacity: UInt32 = 4096,
        enableDeterminismChecks: Bool = true,
        enableReplay: Bool = true
    ) {
        self.configHash = configHash
        self.initialEntityCapacity = initialEntityCapacity
        self.initialComponentCapacity = initialComponentCapacity
        self.enableDeterminismChecks = enableDeterminismChecks
        self.enableReplay = enableReplay
    }
}

public struct FrameReceipt: Sendable {
    public var eventReceipt: EventReceipt
    public var kernelReceipt: KernelReceipt
    public var simReceipt: SimulationReceipt
    public var stateHash: Data
    public var renderPlan: RenderPlan
    public var frameTime: TimeInterval
    
    public init(
        eventReceipt: EventReceipt,
        kernelReceipt: KernelReceipt,
        simReceipt: SimulationReceipt,
        stateHash: Data,
        renderPlan: RenderPlan,
        frameTime: TimeInterval
    ) {
        self.eventReceipt = eventReceipt
        self.kernelReceipt = kernelReceipt
        self.simReceipt = simReceipt
        self.stateHash = stateHash
        self.renderPlan = renderPlan
        self.frameTime = frameTime
    }
}

public struct EventReceipt: Sendable {
    public var sessionId: UUID
    public var firstEventIndex: UInt64
    public var eventCount: Int
    public var batchHash: Data
    
    public init(sessionId: UUID, firstEventIndex: UInt64, eventCount: Int, batchHash: Data) {
        self.sessionId = sessionId
        self.firstEventIndex = firstEventIndex
        self.eventCount = eventCount
        self.batchHash = batchHash
    }
}

public struct KernelReceipt: Sendable {
    public var requestId: UInt64
    public var diffCount: Int
    public var inputHash: Data
    public var outputHash: Data
    
    public init(requestId: UInt64, diffCount: Int, inputHash: Data, outputHash: Data) {
        self.requestId = requestId
        self.diffCount = diffCount
        self.inputHash = inputHash
        self.outputHash = outputHash
    }
}

public struct SimulationReceipt: Sendable {
    public var accumulatedTicks: Int64
    public var stepsTaken: Int
    public var stateHash: Data
    
    public init(accumulatedTicks: Int64, stepsTaken: Int, stateHash: Data) {
        self.accumulatedTicks = accumulatedTicks
        self.stepsTaken = stepsTaken
        self.stateHash = stateHash
    }
}

public struct RenderPlan: Sendable {
    public var opCount: Int
    public var resourceCount: Int
    public var planHash: Data
    public var ops: [DrawOp]
    
    public init(opCount: Int, resourceCount: Int, planHash: Data, ops: [DrawOp]) {
        self.opCount = opCount
        self.resourceCount = resourceCount
        self.planHash = planHash
        self.ops = ops
    }
}

public struct DrawOp: Sendable {
    public var opIndex: UInt32
    public var type: DrawOpType
    public var layerId: UInt32
    public var transform: Transform
    public var clip: Rect
    public var material: ResourceRef
}

public enum DrawOpType: UInt8, Sendable {
    case clear = 0
    case rect = 1
    case path = 2
    case text = 3
    case image = 4
    case clip = 5
    case layer = 6
}

public struct Transform: Sendable {
    public var m: [[Int32]]
    
    public init() {
        self.m = [
            [ANIGMA_COORDINATE_SCALE, 0, 0],
            [0, ANIGMA_COORDINATE_SCALE, 0],
            [0, 0, ANIGMA_COORDINATE_SCALE]
        ]
    }
}

public struct Rect: Sendable {
    public var x: Int32
    public var y: Int32
    public var width: Int32
    public var height: Int32
    
    public init(x: Int32, y: Int32, width: Int32, height: Int32) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ResourceRef: Sendable {
    public var resourceId: UInt64
    public var resourceType: UInt32
    
    public init(resourceId: UInt64, resourceType: UInt32) {
        self.resourceId = resourceId
        self.resourceType = resourceType
    }
}

public struct HitResult: Sendable {
    public var entityId: EntityId
    public var localPoint: Point
    public var hitReason: HitReason
}

public enum HitReason: UInt32, Sendable {
    case bounds = 0
    case fill = 1
    case stroke = 2
    case text = 3
}
