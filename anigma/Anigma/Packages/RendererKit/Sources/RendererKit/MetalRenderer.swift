// MetalRenderer.swift
// Metal-backed renderer implementation for macOS and iOS

import Foundation
import Metal
import MetalKit
import CapsuleCore

// MARK: - Metal Renderer

/// Metal API implementation of the Renderer protocol
public actor MetalRenderer: Renderer {
    public let id: UUID
    public let backendType: RendererBackend = .metal
    
    public private(set) var isReady: Bool = false
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineCache: [UUID: MTLRenderPipelineState] = [:]
    private var configuration: RendererConfiguration?
    private let pipelineStateLock = NSLock()
    
    // MARK: - Initialization
    
    public init() {
        self.id = UUID()
    }
    
    public func initialize(config: RendererConfiguration) async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw CapsuleError.operationFailed(
                code: 1,
                message: "Failed to create Metal device",
                context: ["backend": "Metal"]
            )
        }
        
        guard let queue = device.makeCommandQueue() else {
            throw CapsuleError.operationFailed(
                code: 2,
                message: "Failed to create Metal command queue",
                context: ["backend": "Metal"]
            )
        }
        
        self.device = device
        self.commandQueue = queue
        self.configuration = config
        self.isReady = true
    }
    
    // MARK: - Frame Management
    
    public func beginFrame() async throws -> RenderCommandEncoder {
        guard isReady, let commandQueue = commandQueue else {
            throw CapsuleError.operationFailed(
                code: 3,
                message: "Renderer not initialized",
                context: ["backend": "Metal"]
            )
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw CapsuleError.operationFailed(
                code: 4,
                message: "Failed to create command buffer",
                context: ["backend": "Metal"]
            )
        }
        
        return MetalCommandEncoder(commandBuffer: commandBuffer)
    }
    
    public func submitFrame(_ frame: RenderFrame) async throws -> FrameSynchronization {
        let submissionTime = Date().timeIntervalSince1970
        let expectedPresentationTime = submissionTime + (1.0 / 60.0) // ~60 FPS
        
        return FrameSynchronization(
            frameId: frame.id,
            submissionTime: submissionTime,
            expectedPresentationTime: expectedPresentationTime,
            gpuWorkFence: UUID()
        )
    }
    
    public func getPipeline(descriptor: RenderPipelineDescriptor) async throws -> RenderPipeline {
        let pipelineId = UUID()
        
        pipelineStateLock.lock()
        defer { pipelineStateLock.unlock() }
        
        // In a production implementation, we would compile the shader and create the pipeline here
        // For now, we store the descriptor and return an opaque handle
        
        return RenderPipeline(id: pipelineId, backend: .metal)
    }
    
    public func shutdown() async throws {
        pipelineStateLock.lock()
        defer { pipelineStateLock.unlock() }
        
        pipelineCache.removeAll()
        commandQueue = nil
        device = nil
        isReady = false
    }
}

// MARK: - Metal Command Encoder

final actor MetalCommandEncoder: RenderCommandEncoder {
    private let commandBuffer: MTLCommandBuffer
    private var frames: [RenderFrame] = []
    
    init(commandBuffer: MTLCommandBuffer) {
        self.commandBuffer = commandBuffer
    }
    
    func beginRenderPass(_ descriptor: RenderPassDescriptor) throws -> RenderPassEncoder {
        return MetalRenderPassEncoder(commandBuffer: commandBuffer, descriptor: descriptor)
    }
    
    func dispatchCompute(
        pipeline: RenderPipeline,
        threadgroups: (x: UInt32, y: UInt32, z: UInt32)
    ) throws {
        // Compute dispatch implementation
    }
    
    func finalize() throws -> RenderFrame {
        let frame = RenderFrame(
            id: UUID(),
            timestamp: Date().timeIntervalSince1970,
            commandData: Data()
        )
        
        commandBuffer.commit()
        return frame
    }
}

// MARK: - Metal Render Pass Encoder

final actor MetalRenderPassEncoder: RenderPassEncoder {
    private let commandBuffer: MTLCommandBuffer
    private let descriptor: RenderPassDescriptor
    private var renderCommandEncoder: MTLRenderCommandEncoder?
    
    init(commandBuffer: MTLCommandBuffer, descriptor: RenderPassDescriptor) {
        self.commandBuffer = commandBuffer
        self.descriptor = descriptor
    }
    
    func setRenderPipeline(_ pipeline: RenderPipeline) throws {
        // Set the pipeline state
    }
    
    func setVertexBuffer(_ buffer: RenderBuffer, at index: UInt32) throws {
        // Bind vertex buffer
    }
    
    func setFragmentBuffer(_ buffer: RenderBuffer, at index: UInt32) throws {
        // Bind fragment buffer
    }
    
    func setFragmentTexture(_ texture: RenderTexture, at index: UInt32) throws {
        // Bind fragment texture
    }
    
    func drawPrimitives(
        type: PrimitiveType,
        vertexStart: UInt32,
        vertexCount: UInt32
    ) throws {
        guard let encoder = renderCommandEncoder else {
            throw CapsuleError.operationFailed(
                code: 5,
                message: "Render command encoder not initialized",
                context: ["backend": "Metal"]
            )
        }
        
        let primitiveType = metalPrimitiveType(type)
        encoder.drawPrimitives(type: primitiveType, vertexStart: Int(vertexStart), vertexCount: Int(vertexCount))
    }
    
    func drawIndexedPrimitives(
        type: PrimitiveType,
        indexCount: UInt32,
        indexBuffer: RenderBuffer,
        indexBufferOffset: UInt64
    ) throws {
        guard let encoder = renderCommandEncoder else {
            throw CapsuleError.operationFailed(
                code: 5,
                message: "Render command encoder not initialized",
                context: ["backend": "Metal"]
            )
        }
        
        let primitiveType = metalPrimitiveType(type)
        // Bind index buffer and draw
        // encoder.drawIndexedPrimitives(...)
    }
    
    func endRenderPass() throws {
        renderCommandEncoder?.endEncoding()
    }
    
    private func metalPrimitiveType(_ type: PrimitiveType) -> MTLPrimitiveType {
        switch type {
        case .point:
            return .point
        case .line:
            return .line
        case .lineStrip:
            return .lineStrip
        case .triangle:
            return .triangle
        case .triangleStrip:
            return .triangleStrip
        }
    }
}

// MARK: - Metal Shader Manager

actor MetalShaderManager: ShaderManager {
    private var shaderCache: [String: ShaderBinary] = [:]
    private let device: MTLDevice
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func compileShader(
        source: String,
        type: ShaderType,
        entryPoint: String
    ) async throws -> ShaderBinary {
        // In production, use Metal compiler or MSL code
        return ShaderBinary(data: Data(), shaderType: type, entryPoint: entryPoint)
    }
    
    func getOrCompileShader(
        key: String,
        source: String,
        type: ShaderType
    ) async throws -> ShaderBinary {
        if let cached = shaderCache[key] {
            return cached
        }
        
        let binary = try await compileShader(source: source, type: type, entryPoint: "main")
        shaderCache[key] = binary
        return binary
    }
    
    func clearCache() async throws {
        shaderCache.removeAll()
    }
}
