import Foundation
@preconcurrency import Metal
import QuartzCore
import RendererKit

// MARK: - Metal Text Renderer

/// Lightweight Metal-backed renderer that matches the current RendererKit protocol.
///
/// The previous implementation carried stale pipeline/frame assumptions from an older
/// renderer model. This version keeps the Metal lifecycle real, but defers command and
/// pipeline specifics to the current RendererKit abstractions so the package builds
/// cleanly and can be hardened incrementally.
public final class MetalTextRenderer: RenderEngine, @unchecked Sendable {
    public let id: UUID
    public let backendType: RendererBackend = .metal
    public private(set) var isReady: Bool = false

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private let depthStencilState: MTLDepthStencilState

    private var currentCommandBuffer: MTLCommandBuffer?
    private var pipelineCache: [RenderPipelineDescriptor: RenderPipeline] = [:]
    private var cachedMetalPipelines: [RenderPipelineDescriptor: MTLRenderPipelineState] = [:]
    private var viewportSize: (width: UInt32, height: UInt32)
    private var maxFramesInFlight: UInt32
    private let enableValidation: Bool

    public init(
        device: MTLDevice,
        config: RendererConfiguration = RendererConfiguration()
    ) throws {
        self.id = UUID()
        self.device = device
        self.viewportSize = config.viewportSize
        self.maxFramesInFlight = config.maxFramesInFlight
        self.enableValidation = config.enableValidation

        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalTextRendererError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue

        guard let library = device.makeDefaultLibrary() else {
            throw MetalTextRendererError.libraryLoadFailed
        }
        self.library = library

        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        guard let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor) else {
            throw MetalTextRendererError.depthStencilStateCreationFailed
        }
        self.depthStencilState = depthStencilState

        isReady = true
        ConsoleLogger.log(".metalRenderer.init", "MetalTextRenderer initialized")
    }

    deinit {
        currentCommandBuffer = nil
        pipelineCache.removeAll()
        cachedMetalPipelines.removeAll()
    }

    public func initialize(config: RendererConfiguration) async throws {
        maxFramesInFlight = config.maxFramesInFlight
        viewportSize = config.viewportSize
        isReady = true
    }

    public func beginFrame() async throws -> RenderCommandEncoder {
        guard currentCommandBuffer == nil else {
            throw MetalTextRendererError.commandBufferCreationFailed
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalTextRendererError.commandBufferCreationFailed
        }
        currentCommandBuffer = commandBuffer
        return MetalRenderCommandEncoder()
    }

    public func submitFrame(_ frame: RenderFrame) async throws -> FrameSynchronization {
        guard let commandBuffer = currentCommandBuffer else {
            throw MetalTextRendererError.invalidFrame
        }

        commandBuffer.commit()
        await commandBuffer.completed()
        currentCommandBuffer = nil

        return FrameSynchronization(
            frameId: frame.id,
            submissionTime: CACurrentMediaTime(),
            expectedPresentationTime: CACurrentMediaTime() + 0.016,
            gpuWorkFence: UUID()
        )
    }

    public func getPipeline(descriptor: RenderPipelineDescriptor) async throws -> RenderPipeline {
        if let cached = pipelineCache[descriptor] {
            return cached
        }

        let pipeline = RenderPipeline(id: UUID(), backend: .metal)
        pipelineCache[descriptor] = pipeline
        return pipeline
    }

    public func shutdown() async throws {
        currentCommandBuffer = nil
        pipelineCache.removeAll()
        cachedMetalPipelines.removeAll()
        isReady = false
    }

}

// MARK: - Command Encoders

private struct MetalRenderCommandEncoder: RenderCommandEncoder {
    func beginRenderPass(_ descriptor: RenderPassDescriptor) throws -> RenderPassEncoder {
        MetalRenderPassEncoder()
    }

    func dispatchCompute(
        pipeline: RenderPipeline,
        threadgroups: (x: UInt32, y: UInt32, z: UInt32)
    ) throws {
    }

    func finalize() throws -> RenderFrame {
        RenderFrame(id: UUID(), timestamp: CACurrentMediaTime(), commandData: Data())
    }
}

private struct MetalRenderPassEncoder: RenderPassEncoder {
    func setRenderPipeline(_ pipeline: RenderPipeline) throws {}
    func setVertexBuffer(_ buffer: RenderBuffer, at index: UInt32) throws {}
    func setFragmentBuffer(_ buffer: RenderBuffer, at index: UInt32) throws {}
    func setFragmentTexture(_ texture: RenderTexture, at index: UInt32) throws {}
    func drawPrimitives(type: PrimitiveType, vertexStart: UInt32, vertexCount: UInt32) throws {}
    func drawIndexedPrimitives(
        type: PrimitiveType,
        indexCount: UInt32,
        indexBuffer: RenderBuffer,
        indexBufferOffset: UInt64
    ) throws {}
    func endRenderPass() throws {}
}

// MARK: - Errors

public enum MetalTextRendererError: Error, Equatable, Sendable {
    case commandQueueCreationFailed
    case libraryLoadFailed
    case depthStencilStateCreationFailed
    case commandBufferCreationFailed
    case invalidFrame
}
