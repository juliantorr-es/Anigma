// RendererKit+Events.swift
// Event-driven integration for RendererKit using the current AnigmaEvents API.

import Foundation
import AnigmaEvents
import CapsuleCore

public typealias EventSubscription = UUID

// MARK: - Rendering Events

public enum RenderingEvent: AnigmaEvent {
    public static let eventType = "renderer.lifecycle"

    case started(renderId: String, backend: String)
    case initialized(renderId: String, backend: String, config: RendererConfiguration)
    case frameStarted(renderId: String, frameId: String)
    case frameSubmitted(renderId: String, frameId: String)
    case frameCompleted(renderId: String, frameId: String, syncTime: TimeInterval)
    case frameFinalized
    case shutdownStarted(renderId: String)
    case shutdownCompleted(renderId: String)
    case renderPassStarted(colorAttachments: Int, hasDepth: Bool)
    case renderPassEnded
    case pipelineSet(pipelineId: String)
    case bufferBound(bufferId: String, bindingIndex: UInt32, resourceType: ResourceBinding.ResourceType)
    case textureBound(textureId: String, bindingIndex: UInt32, format: TextureFormat)
    case drawCall(primitiveType: PrimitiveType, vertexCount: UInt32)
    case indexedDrawCall(primitiveType: PrimitiveType, indexCount: UInt32)
    case computeDispatch(threadgroups: (x: UInt32, y: UInt32, z: UInt32))
    case completed(renderId: String, frameId: String, receiptRef: String)
    case failed(renderId: String, error: String)
    case notification(message: String)

    public var description: String {
        switch self {
        case .started(let renderId, let backend):
            return "RenderingEvent.started(renderId: \(renderId), backend: \(backend))"
        case .initialized(let renderId, let backend, _):
            return "RenderingEvent.initialized(renderId: \(renderId), backend: \(backend))"
        case .frameStarted(let renderId, let frameId):
            return "RenderingEvent.frameStarted(renderId: \(renderId), frameId: \(frameId))"
        case .frameSubmitted(let renderId, let frameId):
            return "RenderingEvent.frameSubmitted(renderId: \(renderId), frameId: \(frameId))"
        case .frameCompleted(let renderId, let frameId, let syncTime):
            return "RenderingEvent.frameCompleted(renderId: \(renderId), frameId: \(frameId), syncTime: \(syncTime))"
        case .frameFinalized:
            return "RenderingEvent.frameFinalized"
        case .shutdownStarted(let renderId):
            return "RenderingEvent.shutdownStarted(renderId: \(renderId))"
        case .shutdownCompleted(let renderId):
            return "RenderingEvent.shutdownCompleted(renderId: \(renderId))"
        case .renderPassStarted(let colorAttachments, let hasDepth):
            return "RenderingEvent.renderPassStarted(colorAttachments: \(colorAttachments), hasDepth: \(hasDepth))"
        case .renderPassEnded:
            return "RenderingEvent.renderPassEnded"
        case .pipelineSet(let pipelineId):
            return "RenderingEvent.pipelineSet(pipelineId: \(pipelineId))"
        case .bufferBound(let bufferId, let bindingIndex, let resourceType):
            return "RenderingEvent.bufferBound(bufferId: \(bufferId), bindingIndex: \(bindingIndex), resourceType: \(resourceType))"
        case .textureBound(let textureId, let bindingIndex, let format):
            return "RenderingEvent.textureBound(textureId: \(textureId), bindingIndex: \(bindingIndex), format: \(format))"
        case .drawCall(let primitiveType, let vertexCount):
            return "RenderingEvent.drawCall(primitiveType: \(primitiveType), vertexCount: \(vertexCount))"
        case .indexedDrawCall(let primitiveType, let indexCount):
            return "RenderingEvent.indexedDrawCall(primitiveType: \(primitiveType), indexCount: \(indexCount))"
        case .computeDispatch(let threadgroups):
            return "RenderingEvent.computeDispatch(threadgroups: \(threadgroups))"
        case .completed(let renderId, let frameId, let receiptRef):
            return "RenderingEvent.completed(renderId: \(renderId), frameId: \(frameId), receiptRef: \(receiptRef))"
        case .failed(let renderId, let error):
            return "RenderingEvent.failed(renderId: \(renderId), error: \(error))"
        case .notification(let message):
            return "RenderingEvent.notification(message: \(message))"
        }
    }
}

// MARK: - Rendering Request Events

public enum RenderingRequestEvent: AnigmaEvent {
    public static let eventType = "renderer.request"

    case request(RenderingRequest)
    case cancel(String)

    public var description: String {
        switch self {
        case .request(let request):
            return "RenderingRequestEvent.request(\(request.requestId.uuidString))"
        case .cancel(let requestId):
            return "RenderingRequestEvent.cancel(\(requestId))"
        }
    }
}

// MARK: - Work Item Helpers

public enum WorkItemPriority: Int, Sendable, Codable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

public enum WorkItemType: String, Sendable, Codable {
    case render
}

public struct WorkItem: Sendable {
    public let id: UUID
    public let type: WorkItemType
    public let priority: WorkItemPriority
    public let metadata: [String: String]
    public let request: RenderingRequest?

    public init(
        id: UUID = UUID(),
        type: WorkItemType = .render,
        priority: WorkItemPriority = .normal,
        metadata: [String: String] = [:],
        request: RenderingRequest? = nil
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.metadata = metadata
        self.request = request
    }
}

public struct RenderingRequest: Sendable {
    public let requestId: UUID
    public let rendererId: UUID
    public let backend: RendererBackend
    public let configuration: RendererConfiguration
    public let commands: [RenderingCommand]
    public let maxFramesInFlight: UInt32
    public let viewportSize: (width: UInt32, height: UInt32)
    public let enableValidation: Bool

    public init(
        requestId: UUID = UUID(),
        rendererId: UUID = UUID(),
        backend: RendererBackend = .metal,
        configuration: RendererConfiguration = RendererConfiguration(),
        commands: [RenderingCommand] = [],
        maxFramesInFlight: UInt32 = 3,
        viewportSize: (width: UInt32, height: UInt32) = (1280, 720),
        enableValidation: Bool = false
    ) {
        self.requestId = requestId
        self.rendererId = rendererId
        self.backend = backend
        self.configuration = configuration
        self.commands = commands
        self.maxFramesInFlight = maxFramesInFlight
        self.viewportSize = viewportSize
        self.enableValidation = enableValidation
    }
}

public enum RenderingCommand: Sendable {
    case beginFrame
    case renderPass(descriptor: RenderPassDescriptor)
    case setPipeline(pipeline: RenderPipeline)
    case setVertexBuffer(buffer: RenderBuffer, index: UInt32)
    case setFragmentBuffer(buffer: RenderBuffer, index: UInt32)
    case setFragmentTexture(texture: RenderTexture, index: UInt32)
    case drawPrimitives(type: PrimitiveType, vertexStart: UInt32, vertexCount: UInt32)
    case drawIndexedPrimitives(
        type: PrimitiveType,
        indexCount: UInt32,
        indexBuffer: RenderBuffer,
        indexBufferOffset: UInt64
    )
    case endRenderPass
    case submitFrame
    case dispatchCompute(pipeline: RenderPipeline, threadgroups: (x: UInt32, y: UInt32, z: UInt32))
}

// MARK: - Renderer Extensions

public extension RenderEngine {
    func initializeWithEvents(config: RendererConfiguration, eventBus: any EventBus = .shared) async throws {
        let source = id.uuidString
        _ = await eventBus.publish(
            RenderingEvent.started(renderId: source, backend: backendType.displayName),
            source: source
        )

        do {
            try await initialize(config: config)
            _ = await eventBus.publish(
                RenderingEvent.initialized(renderId: source, backend: backendType.displayName, config: config),
                source: source
            )
        } catch {
            _ = await eventBus.publish(
                RenderingEvent.failed(renderId: source, error: error.localizedDescription),
                source: source
            )
            throw error
        }
    }

    func beginFrameWithEvents(eventBus: any EventBus = .shared) async throws -> (encoder: RenderCommandEncoder, frameId: UUID) {
        let frameId = UUID()
        let source = id.uuidString
        _ = await eventBus.publish(
            RenderingEvent.frameStarted(renderId: source, frameId: frameId.uuidString),
            source: source
        )

        let encoder = try await beginFrame()
        return (encoder, frameId)
    }

    func submitFrameWithEvents(_ frame: RenderFrame, eventBus: any EventBus = .shared) async throws -> FrameSynchronization {
        let source = id.uuidString
        _ = await eventBus.publish(
            RenderingEvent.frameSubmitted(renderId: source, frameId: frame.id.uuidString),
            source: source
        )

        let sync = try await submitFrame(frame)
        _ = await eventBus.publish(
            RenderingEvent.frameCompleted(
                renderId: source,
                frameId: frame.id.uuidString,
                syncTime: sync.expectedPresentationTime
            ),
            source: source
        )
        return sync
    }

    func shutdownWithEvents(eventBus: any EventBus = .shared) async throws {
        let source = id.uuidString
        _ = await eventBus.publish(
            RenderingEvent.shutdownStarted(renderId: source),
            source: source
        )

        do {
            try await shutdown()
            _ = await eventBus.publish(
                RenderingEvent.shutdownCompleted(renderId: source),
                source: source
            )
        } catch {
            _ = await eventBus.publish(
                RenderingEvent.failed(renderId: source, error: "Shutdown failed: \(error.localizedDescription)"),
                source: source
            )
            throw error
        }
    }
}

public extension RenderCommandEncoder {
    func beginRenderPassWithEvents(
        _ descriptor: RenderPassDescriptor,
        eventBus: any EventBus = .shared
    ) async throws -> RenderPassEncoder {
        _ = await eventBus.publish(
            RenderingEvent.renderPassStarted(
                colorAttachments: descriptor.colorAttachments.count,
                hasDepth: descriptor.depthAttachment != nil
            ),
            source: "render-pass"
        )

        return try beginRenderPass(descriptor)
    }

    func dispatchComputeWithEvents(
        pipeline: RenderPipeline,
        threadgroups: (x: UInt32, y: UInt32, z: UInt32),
        eventBus: any EventBus = .shared
    ) async throws {
        _ = await eventBus.publish(
            RenderingEvent.computeDispatch(threadgroups: threadgroups),
            source: pipeline.id.uuidString
        )
        try dispatchCompute(pipeline: pipeline, threadgroups: threadgroups)
    }

    func finalizeWithEvents(eventBus: any EventBus = .shared) async throws -> RenderFrame {
        _ = await eventBus.publish(RenderingEvent.frameFinalized, source: "frame")
        return try finalize()
    }
}

public extension RenderPassEncoder {
    func setRenderPipelineWithEvents(_ pipeline: RenderPipeline, eventBus: any EventBus = .shared) async throws {
        _ = await eventBus.publish(
            RenderingEvent.pipelineSet(pipelineId: pipeline.id.uuidString),
            source: pipeline.id.uuidString
        )
        try setRenderPipeline(pipeline)
    }

    func setVertexBufferWithEvents(_ buffer: RenderBuffer, at index: UInt32, eventBus: any EventBus = .shared) async throws {
        _ = await eventBus.publish(
            RenderingEvent.bufferBound(bufferId: buffer.id.uuidString, bindingIndex: index, resourceType: .buffer),
            source: buffer.id.uuidString
        )
        try setVertexBuffer(buffer, at: index)
    }

    func setFragmentBufferWithEvents(_ buffer: RenderBuffer, at index: UInt32, eventBus: any EventBus = .shared) async throws {
        _ = await eventBus.publish(
            RenderingEvent.bufferBound(bufferId: buffer.id.uuidString, bindingIndex: index, resourceType: .buffer),
            source: buffer.id.uuidString
        )
        try setFragmentBuffer(buffer, at: index)
    }

    func setFragmentTextureWithEvents(_ texture: RenderTexture, at index: UInt32, eventBus: any EventBus = .shared) async throws {
        _ = await eventBus.publish(
            RenderingEvent.textureBound(textureId: texture.id.uuidString, bindingIndex: index, format: texture.format),
            source: texture.id.uuidString
        )
        try setFragmentTexture(texture, at: index)
    }

    func drawPrimitivesWithEvents(
        type: PrimitiveType,
        vertexStart: UInt32,
        vertexCount: UInt32,
        eventBus: any EventBus = .shared
    ) async throws {
        _ = await eventBus.publish(
            RenderingEvent.drawCall(primitiveType: type, vertexCount: vertexCount),
            source: "draw"
        )
        try drawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount)
    }

    func drawIndexedPrimitivesWithEvents(
        type: PrimitiveType,
        indexCount: UInt32,
        indexBuffer: RenderBuffer,
        indexBufferOffset: UInt64,
        eventBus: any EventBus = .shared
    ) async throws {
        _ = await eventBus.publish(
            RenderingEvent.indexedDrawCall(primitiveType: type, indexCount: indexCount),
            source: indexBuffer.id.uuidString
        )
        try drawIndexedPrimitives(
            type: type,
            indexCount: indexCount,
            indexBuffer: indexBuffer,
            indexBufferOffset: indexBufferOffset
        )
    }

    func endRenderPassWithEvents(eventBus: any EventBus = .shared) async throws {
        _ = await eventBus.publish(RenderingEvent.renderPassEnded, source: "render-pass")
        try endRenderPass()
    }
}

// MARK: - Renderer Manager

public actor RendererManager {
    private let eventBus: any EventBus
    private var eventSubscriptionIds: [UUID] = []
    private var renderers: [UUID: any RenderEngine] = [:]
    private var pendingRequests: [UUID: RenderingRequest] = [:]

    public init(eventBus: any EventBus = DefaultEventBus.shared) {
        self.eventBus = eventBus
    }

    public func start() async {
        guard eventSubscriptionIds.isEmpty else { return }

        let requestId = await eventBus.subscribe(to: RenderingRequestEvent.self) { [weak self] event in
            await self?.handleRenderingRequest(event.event)
        }
        eventSubscriptionIds.append(requestId)

        let workItemId = await eventBus.subscribe(to: WorkItemCreatedEvent.self) { [weak self] event in
            await self?.handleWorkItemCreated(event.event)
        }
        eventSubscriptionIds.append(workItemId)
    }

    public func stop() async {
        for subscriptionId in eventSubscriptionIds {
            await eventBus.unsubscribe(id: subscriptionId)
        }
        eventSubscriptionIds.removeAll()
    }

    public func registerRenderer(_ renderer: any RenderEngine) {
        renderers[renderer.id] = renderer
    }

    public func unregisterRenderer(id: UUID) {
        renderers.removeValue(forKey: id)
    }

    public func getRenderer(id: UUID) -> (any RenderEngine)? {
        renderers[id]
    }

    public func createRenderingWorkItem(
        commands: [RenderingCommand],
        priority: WorkItemPriority = .normal,
        metadata: [String: String] = [:]
    ) -> WorkItem {
        WorkItem(
            type: .render,
            priority: priority,
            metadata: metadata,
            request: RenderingRequest(commands: commands)
        )
    }

    public func requestRendering(
        request: RenderingRequest,
        priority: WorkItemPriority = .normal,
        metadata: [String: String] = [:]
    ) async {
        pendingRequests[request.requestId] = request

        var requestMetadata = metadata
        requestMetadata["request_id"] = request.requestId.uuidString
        requestMetadata["renderer_id"] = request.rendererId.uuidString
        requestMetadata["backend"] = request.backend.displayName

        _ = await eventBus.publish(
            RenderingRequestEvent.request(request),
            source: request.rendererId.uuidString
        )

        _ = await eventBus.publish(
            WorkItemCreatedEvent(
                workItemId: request.requestId.uuidString,
                workItemType: WorkItemType.render.rawValue,
                priority: priority.rawValue,
                createdBy: nil,
                metadata: requestMetadata
            ),
            source: request.rendererId.uuidString
        )
    }

    public func cancelRendering(requestId: String) async {
        if let uuid = UUID(uuidString: requestId) {
            pendingRequests.removeValue(forKey: uuid)
        }

        _ = await eventBus.publish(
            RenderingRequestEvent.cancel(requestId),
            source: "renderer-manager"
        )
    }

    public func subscribeToRenderingEvents(
        handler: @escaping @Sendable (RenderingEvent) async -> Void
    ) async -> EventSubscription {
        await eventBus.subscribe(to: RenderingEvent.self) { event in
            await handler(event.event)
        }
    }

    public func subscribeToRenderingRequests(
        handler: @escaping @Sendable (RenderingRequestEvent) async -> Void
    ) async -> EventSubscription {
        await eventBus.subscribe(to: RenderingRequestEvent.self) { event in
            await handler(event.event)
        }
    }

    public func subscribeToWorkItemEvents(
        handler: @escaping @Sendable (WorkItemCreatedEvent) async -> Void
    ) async -> EventSubscription {
        await eventBus.subscribe(to: WorkItemCreatedEvent.self) { event in
            await handler(event.event)
        }
    }

    private func handleRenderingRequest(_ event: RenderingRequestEvent) async {
        switch event {
        case .request(let request):
            pendingRequests[request.requestId] = request
            _ = await eventBus.publish(
                RenderingEvent.notification(message: "Queued rendering request \(request.requestId.uuidString)"),
                source: request.rendererId.uuidString
            )

        case .cancel(let requestId):
            if let uuid = UUID(uuidString: requestId) {
                pendingRequests.removeValue(forKey: uuid)
            }
            _ = await eventBus.publish(
                RenderingEvent.notification(message: "Cancelled rendering request \(requestId)"),
                source: "renderer-manager"
            )
        }
    }

    private func handleWorkItemCreated(_ event: WorkItemCreatedEvent) async {
        guard event.workItemType == WorkItemType.render.rawValue else { return }

        let requestId = event.metadata?["request_id"].flatMap(UUID.init(uuidString:))
        let rendererId = event.metadata?["renderer_id"].flatMap(UUID.init(uuidString:))

        guard let requestId, let request = pendingRequests.removeValue(forKey: requestId) else {
            return
        }

        await processRenderingRequest(request: request, rendererId: rendererId)
    }

    private func processRenderingRequest(request: RenderingRequest, rendererId: UUID?) async {
        let targetRendererId = rendererId ?? request.rendererId

        do {
            let renderer = try await renderer(for: request, rendererId: targetRendererId)

            if !renderer.isReady {
                try await renderer.initializeWithEvents(config: request.configuration, eventBus: eventBus)
            }

            let (encoder, frameId) = try await renderer.beginFrameWithEvents(eventBus: eventBus)
            var currentPass: (any RenderPassEncoder)?

            for command in request.commands {
                switch command {
                case .beginFrame:
                    continue
                case .renderPass(let descriptor):
                    currentPass = try await encoder.beginRenderPassWithEvents(descriptor, eventBus: eventBus)
                case .setPipeline(let pipeline):
                    if let currentPass {
                        try await currentPass.setRenderPipelineWithEvents(pipeline, eventBus: eventBus)
                    }
                case .setVertexBuffer(let buffer, let index):
                    if let currentPass {
                        try await currentPass.setVertexBufferWithEvents(buffer, at: index, eventBus: eventBus)
                    }
                case .setFragmentBuffer(let buffer, let index):
                    if let currentPass {
                        try await currentPass.setFragmentBufferWithEvents(buffer, at: index, eventBus: eventBus)
                    }
                case .setFragmentTexture(let texture, let index):
                    if let currentPass {
                        try await currentPass.setFragmentTextureWithEvents(texture, at: index, eventBus: eventBus)
                    }
                case .drawPrimitives(let type, let vertexStart, let vertexCount):
                    if let currentPass {
                        try await currentPass.drawPrimitivesWithEvents(
                            type: type,
                            vertexStart: vertexStart,
                            vertexCount: vertexCount,
                            eventBus: eventBus
                        )
                    }
                case .drawIndexedPrimitives(let type, let indexCount, let indexBuffer, let indexBufferOffset):
                    if let currentPass {
                        try await currentPass.drawIndexedPrimitivesWithEvents(
                            type: type,
                            indexCount: indexCount,
                            indexBuffer: indexBuffer,
                            indexBufferOffset: indexBufferOffset,
                            eventBus: eventBus
                        )
                    }
                case .endRenderPass:
                    if let pass = currentPass {
                        try await pass.endRenderPassWithEvents(eventBus: eventBus)
                        currentPass = nil
                    }
                case .submitFrame:
                    break
                case .dispatchCompute(let pipeline, let threadgroups):
                    try await encoder.dispatchComputeWithEvents(
                        pipeline: pipeline,
                        threadgroups: threadgroups,
                        eventBus: eventBus
                    )
                }
            }

            let frame = try await encoder.finalizeWithEvents(eventBus: eventBus)
            let sync = try await renderer.submitFrameWithEvents(frame, eventBus: eventBus)

            _ = await eventBus.publish(
                RenderingEvent.completed(
                    renderId: renderer.id.uuidString,
                    frameId: frameId.uuidString,
                    receiptRef: sync.gpuWorkFence.uuidString
                ),
                source: renderer.id.uuidString
            )
        } catch {
            _ = await eventBus.publish(
                RenderingEvent.failed(renderId: targetRendererId.uuidString, error: error.localizedDescription),
                source: targetRendererId.uuidString
            )
        }
    }

    private func renderer(for request: RenderingRequest, rendererId: UUID) async throws -> any RenderEngine {
        if let renderer = renderers[rendererId] {
            return renderer
        }

        let renderer: any RenderEngine
        switch request.backend {
        case .cpuSoftware:
            renderer = CPUSoftwareRenderer()
                case .opengl:
            renderer = CPUSoftwareRenderer()
        case .metal, .custom:
            renderer = EnhancedMetalRenderer()
        }

        renderers[rendererId] = renderer
        return renderer
    }
}
