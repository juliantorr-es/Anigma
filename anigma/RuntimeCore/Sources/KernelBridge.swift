import Foundation

public final class KernelBridge: @unchecked Sendable {
    public static let shared = KernelBridge()
    
    private var isInitialized: Bool = false
    private var instanceId: UInt64 = 0
    private var buildId: UInt64 = 0
    private var arena: UnsafeMutableRawPointer?
    private var arenaSize: size_t = 1024 * 1024
    
    private init() {}
    
    deinit {
        if isInitialized {
            anigma_shutdown()
        }
    }
    
    public struct InitializeRequest {
        public var profile: DeterminismProfile
        public var configHash: UInt64
        public var initialEntityCapacity: UInt32
        public var initialComponentCapacity: UInt32
        
        public init(
            profile: DeterminismProfile,
            configHash: UInt64,
            initialEntityCapacity: UInt32,
            initialComponentCapacity: UInt32
        ) {
            self.profile = profile
            self.configHash = configHash
            self.initialEntityCapacity = initialEntityCapacity
            self.initialComponentCapacity = initialComponentCapacity
        }
    }
    
    public struct InitializeResponse {
        public var instanceId: UInt64
        public var kernelBuildId: UInt64
        public var activeProfile: DeterminismProfile
    }
    
    public struct SimulationStepRequest {
        public var deltaTicks: Int64
        public var maxSteps: UInt32
        
        public init(deltaTicks: Int64, maxSteps: UInt32) {
            self.deltaTicks = deltaTicks
            self.maxSteps = maxSteps
        }
    }
    
    public struct SimulationStepResponse {
        public var accumulatedTicks: Int64
        public var stepsTaken: Int
        public var stateHash: Data
    }
    
    public struct HitQuery {
        public var point: Point
        public var flags: UInt32
        public var maxResults: UInt32
        public var excludeIds: [EntityId]
        
        public init(point: Point, flags: UInt32, maxResults: UInt32, excludeIds: [EntityId] = []) {
            self.point = point
            self.flags = flags
            self.maxResults = maxResults
            self.excludeIds = excludeIds
        }
    }
    
    public struct RenderPlanRequest {
        public var viewport: Rect
        public var renderFlags: UInt32
        
        public init(viewport: Rect, renderFlags: UInt32) {
            self.viewport = viewport
            self.renderFlags = renderFlags
        }
    }
    
    public func initialize(request: InitializeRequest) async throws -> InitializeResponse {
        guard !isInitialized else {
            throw KernelError.alreadyInitialized
        }
        
        arena = UnsafeMutableRawPointer.allocate(
            byteCount: arenaSize,
            alignment: MemoryLayout<UInt8>.alignment
        )
        
        var arenaImpl = anigma_arena_t(
            base: UnsafeMutableRawPointer(arena!),
            size: arenaSize,
            offset: 0
        )
        
        var req = anigma_initialize_request_t(
            profile: request.profile.toCStruct(),
            config_hash: request.configHash,
            initial_entity_capacity: request.initialEntityCapacity,
            initial_component_capacity: request.initialComponentCapacity
        )
        
        var resp = anigma_initialize_response_t()
        var errorInfo = anigma_buffer_t(data: nil, size: 0, capacity: 0)
        
        let status = anigma_initialize(&req, &resp, &arenaImpl, &errorInfo)
        
        guard status == ANIGMA_STATUS_SUCCESS else {
            throw KernelError.initFailed(status)
        }
        
        isInitialized = true
        instanceId = resp.instance_id
        buildId = resp.kernel_build_id
        
        return InitializeResponse(
            instanceId: resp.instance_id,
            kernelBuildId: resp.kernel_build_id,
            activeProfile: DeterminismProfile(from: resp.active_profile)
        )
    }
    
    public func applyDiffs(_ diffs: [SceneDiff]) async throws -> KernelReceipt {
        guard isInitialized else {
            throw KernelError.notInitialized
        }
        
        let batch = createDiffBatch(from: diffs)
        
        var outputState = anigma_buffer_t(data: nil, size: 0, capacity: 0)
        var arenaImpl = anigma_arena_t(
            base: UnsafeMutableRawPointer(arena!),
            size: arenaSize,
            offset: 0
        )
        
        let status = anigma_diff_apply(&batch, &outputState, &arenaImpl, nil)
        
        guard status == ANIGMA_STATUS_SUCCESS else {
            throw KernelError.operationFailed(status)
        }
        
        var inputHash: [UInt8] = Array(repeating: 0, count: 32)
        var outputHash: [UInt8] = Array(repeating: 0, count: 32)
        
        return KernelReceipt(
            requestId: batch.sequence_id,
            diffCount: Int(batch.diff_count),
            inputHash: Data(inputHash),
            outputHash: Data(outputHash)
        )
    }
    
    public func stepSimulation(request: SimulationStepRequest) async throws -> SimulationStepResponse {
        guard isInitialized else {
            throw KernelError.notInitialized
        }
        
        var req = anigma_simulation_step_request_t(
            delta_ticks: request.deltaTicks,
            max_steps: request.maxSteps
        )
        
        var resp = anigma_simulation_step_response_t()
        
        let status = anigma_simulation_step(&req, &resp, nil)
        
        guard status == ANIGMA_STATUS_SUCCESS else {
            throw KernelError.operationFailed(status)
        }
        
        return SimulationStepResponse(
            accumulatedTicks: resp.accumulated_time,
            stepsTaken: Int(resp.steps_taken),
            stateHash: Data(resp.state_hash)
        )
    }
    
    public func hitTest(query: HitQuery) async throws -> HitResponse {
        guard isInitialized else {
            throw KernelError.notInitialized
        }
        
        var arenaImpl = anigma_arena_t(
            base: UnsafeMutableRawPointer(arena!),
            size: arenaSize,
            offset: 0
        )
        
        var resultBuffer = anigma_hit_result_buffer_t(
            results: nil,
            count: 0,
            capacity: 0,
            total_considered: 0
        )
        
        let status = anigma_hit_test_create_buffer(&resultBuffer, query.maxResults, &arenaImpl)
        
        guard status == ANIGMA_STATUS_SUCCESS else {
            throw KernelError.operationFailed(status)
        }
        
        let cQuery = anigma_hit_query_t(
            point: anigma_point_t(x: anigma_coord_from_float(Float(query.point.x)), y: anigma_coord_from_float(Float(query.point.y))),
            flags: query.flags,
            max_results: query.maxResults,
            exclude_ids: nil,
            exclude_count: 0
        )
        
        let hitStatus = anigma_hit_test_point(nil, cQuery, query.flags, query.maxResults, nil, 0, &resultBuffer, &arenaImpl)
        
        guard hitStatus == ANIGMA_STATUS_SUCCESS else {
            return HitResponse(results: [], totalConsidered: 0)
        }
        
        var results: [HitResult] = []
        for i in 0..<Int(resultBuffer.count) {
            let cResult = resultBuffer.results[i]
            results.append(HitResult(
                entityId: EntityId(high: cResult.entity_id.high, low: cResult.entity_id.low),
                localPoint: Point(
                    x: Double(anigma_coord_to_float(cResult.local_point.x)),
                    y: Double(anigma_coord_to_float(cResult.local_point.y))
                ),
                hitReason: HitReason(rawValue: cResult.hit_reason) ?? .bounds
            ))
        }
        
        return HitResponse(results: results, totalConsidered: Int(resultBuffer.total_considered))
    }
    
    public func generateRenderPlan(request: RenderPlanRequest) async throws -> RenderPlan {
        guard isInitialized else {
            throw KernelError.notInitialized
        }
        
        var plan: UnsafeMutablePointer<anigma_render_plan_t>?
        var arenaImpl = anigma_arena_t(
            base: UnsafeMutableRawPointer(arena!),
            size: arenaSize,
            offset: 0
        )
        
        let renderReq = anigma_render_plan_request_t(
            viewport: request.viewport,
            render_flags: request.renderFlags
        )
        
        let status = anigma_generate_render_plan(nil, &renderReq, &plan, &arenaImpl)
        
        guard status == ANIGMA_STATUS_SUCCESS, let cPlan = plan else {
            throw KernelError.operationFailed(status)
        }
        
        var ops: [DrawOp] = []
        for i in 0..<Int(cPlan.pointee.op_count) {
            let cOp = cPlan.pointee.ops[i]
            ops.append(DrawOp(
                opIndex: cOp.op_index,
                type: DrawOpType(rawValue: cOp.type.rawValue) ?? .clear,
                layerId: cOp.layer_id,
                transform: Transform(from: cOp.transform),
                clip: Rect(from: cOp.clip),
                material: ResourceRef(resourceId: cOp.material.resource_id, resourceType: cOp.material.resource_type)
            ))
        }
        
        return RenderPlan(
            opCount: Int(cPlan.pointee.op_count),
            resourceCount: Int(cPlan.pointee.resource_count),
            planHash: Data(cPlan.pointee.plan_hash),
            ops: ops
        )
    }
    
    public func computeStateHash() async throws -> Data {
        guard isInitialized else {
            throw KernelError.notInitialized
        }
        
        var req = anigma_state_hash_request_t(hash_algorithm: 0, components_mask: 0)
        var resp = anigma_state_hash_response_t()
        
        let status = anigma_state_hash(&req, &resp, nil)
        
        guard status == ANIGMA_STATUS_SUCCESS else {
            throw KernelError.operationFailed(status)
        }
        
        return Data(resp.hash)
    }
    
    public func runEvents(events: [OSEvent]) -> RunResult {
        return RunResult(stateHash: Data(), renderPlanHash: Data())
    }
    
    public func evaluateAnimation(_ animation: Animation, toTime: Double, steps: Int) -> AnimationResult {
        return AnimationResult(propertyValues: [:])
    }
    
    public func evaluateAtTick(_ tick: Int64) -> TickResult {
        return TickResult(stateHash: Data())
    }
    
    private func createDiffBatch(from diffs: [SceneDiff]) -> anigma_diff_batch_t {
        var batch = anigma_diff_batch_t(
            diff_count: UInt32(diffs.count),
            schema_version: 1,
            sequence_id: UInt64.random(in: 0...UInt64.max),
            diffs: []
        )
        return batch
    }
}

public enum KernelError: Error, LocalizedError {
    case notInitialized
    case alreadyInitialized
    case initFailed(UInt32)
    case operationFailed(UInt32)
    case invalidInput
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Kernel not initialized"
        case .alreadyInitialized:
            return "Kernel already initialized"
        case .initFailed(let code):
            return "Init failed with code: \(code)"
        case .operationFailed(let code):
            return "Operation failed with code: \(code)"
        case .invalidInput:
            return "Invalid input"
        }
    }
}

public struct DeterminismProfile {
    public var profileId: UInt64
    public var tickResolution: Int64
    public var coordinateScale: Int32
    public var sortTieBreakMode: UInt32
    public var flags: UInt64
    
    public static let `default` = DeterminismProfile(
        profileId: 0x414E49474D410001,
        tickResolution: 1000000,
        coordinateScale: 256,
        sortTieBreakMode: 0,
        flags: 0
    )
    
    func toCStruct() -> anigma_determinism_profile_t {
        anigma_determinism_profile_t(
            profile_id: profileId,
            tick_resolution: tickResolution,
            coordinate_scale: coordinateScale,
            sort_tie_break_mode: sortTieBreakMode,
            flags: flags
        )
    }
    
    init(from cStruct: anigma_determinism_profile_t) {
        self.profileId = cStruct.profile_id
        self.tickResolution = cStruct.tick_resolution
        self.coordinateScale = cStruct.coordinate_scale
        self.sortTieBreakMode = cStruct.sort_tie_break_mode
        self.flags = cStruct.flags
    }
}

public struct HitResponse {
    public var results: [HitResult]
    public var totalConsidered: Int
}

public struct RunResult {
    public var stateHash: Data
    public var renderPlanHash: Data
}

public struct AnimationResult {
    public var propertyValues: [String: Float]
}

public struct TickResult {
    public var stateHash: Data
}

public struct Animation {
    public var tracks: [AnimationTrack]
}

public struct AnimationTrack {
    public var targetId: EntityId
    public var propertyPath: String
    public var keyframes: [Keyframe]
}

public struct Keyframe {
    public var time: Double
    public var value: Float
    public var easing: EasingMode
}

public enum EasingMode {
    case linear
    case easeInQuad
    case easeOutQuad
    case easeInOutQuad
    case easeInCubic
    case easeOutCubic
    case easeInOutCubic
    case easeInSine
    case easeOutSine
    case easeInOutSine
    case spring
}

extension Transform {
    init(from cTransform: anigma_transform_t) {
        self.m = [
            [Int32(cTransform.m[0][0]), Int32(cTransform.m[0][1]), Int32(cTransform.m[0][2])],
            [Int32(cTransform.m[1][0]), Int32(cTransform.m[1][1]), Int32(cTransform.m[1][2])],
            [Int32(cTransform.m[2][0]), Int32(cTransform.m[2][1]), Int32(cTransform.m[2][2])]
        ]
    }
}

extension Rect {
    init(from cRect: anigma_rect_t) {
        self.x = Int32(cRect.x)
        self.y = Int32(cRect.y)
        self.width = Int32(cRect.width)
        self.height = Int32(cRect.height)
    }
}

protocol OSEvent {}

struct PointerEvent: OSEvent {
    var phase: PointerPhase
    var position: Point
    
    enum PointerPhase {
        case began, moved, ended, cancelled
    }
}

struct SceneDiff {
    enum DiffType {
        case attach, detach, update, transform, property
    }
    var type: DiffType
    var entityId: EntityId
    var transform: Transform?
    var propertyPath: String?
    var propertyValue: PropertyValue?
}

struct PropertyValue {
    var floatValue: Float?
    var pointValue: Point?
}

import MetalKit

extension KernelBridge {
    public func evaluateAnimation(_ animation: Animation, toTime: Double, steps: Int) -> AnimationResult {
        var propertyValues: [String: Float] = [:]
        
        for track in animation.tracks {
            guard track.keyframes.count >= 2 else { continue }
            
            let targetTimeTicks = Int64(toTime * Double(ANIGMA_TICKS_PER_SECOND))
            
            for i in 0..<track.keyframes.count - 1 {
                let left = track.keyframes[i]
                let right = track.keyframes[i + 1]
                
                let leftTicks = Int64(left.time * Double(ANIGMA_TICKS_PER_SECOND))
                let rightTicks = Int64(right.time * Double(ANIGMA_TICKS_PER_SECOND))
                
                if targetTimeTicks >= leftTicks && targetTimeTicks <= rightTicks {
                    let duration = Double(rightTicks - leftTicks)
                    let elapsed = Double(targetTimeTicks - leftTicks)
                    var t = Float(elapsed / duration)
                    
                    switch right.easing {
                    case .linear:
                        break
                    case .easeInQuad:
                        t = t * t
                    case .easeOutQuad:
                        t = 2 * t - t * t
                    case .easeInOutQuad:
                        t = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
                    default:
                        break
                    }
                    
                    let value = left.value + (right.value - left.value) * t
                    propertyValues[track.propertyPath] = value
                    break
                }
            }
        }
        
        return AnimationResult(propertyValues: propertyValues)
    }
    
    public func evaluateAtTick(_ tick: Int64) -> TickResult {
        var hashInput = Data(count: 32)
        hashInput.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: tick, as: Int64.self)
        }
        
        var hashOutput = Data(count: 32)
        hashOutput.withUnsafeMutableBytes { output in
            hashInput.withUnsafeBytes { input in
                anigma_hash(input.baseAddress, input.count, output.baseAddress)
            }
        }
        
        return TickResult(stateHash: hashOutput)
    }
    
    public func runEvents(events: [OSEvent]) -> RunResult {
        var stateHash = Data(count: 32)
        var planHash = Data(count: 32)
        
        return RunResult(stateHash: stateHash, renderPlanHash: planHash)
    }
}
