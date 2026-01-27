// RendererCore.swift
// RendererKit - Tier 1 graphics abstraction for Anigma
// Provides unified renderer protocol and lifecycle management

import Foundation
import CapsuleCore

// MARK: - Renderer Abstraction Protocol

/// Protocol defining the abstract renderer interface.
/// All renderers (Metal, OpenGL, CPU) must conform to this protocol.
public protocol Renderer: Sendable, AnyObject {
    /// Unique identifier for this renderer instance
    var id: UUID { get }
    
    /// The rendering backend type
    var backendType: RendererBackend { get }
    
    /// Whether the renderer is currently ready to accept commands
    var isReady: Bool { get }
    
    /// Initialize the renderer with the given configuration
    func initialize(config: RendererConfiguration) async throws
    
    /// Begin a new frame, returning a command encoder
    func beginFrame() async throws -> RenderCommandEncoder
    
    /// Submit completed frame commands and synchronize presentation
    func submitFrame(_ frame: RenderFrame) async throws -> FrameSynchronization
    
    /// Retrieve or create a pipeline with the given descriptor
    func getPipeline(descriptor: RenderPipelineDescriptor) async throws -> RenderPipeline
    
    /// Clean up resources and prepare for shutdown
    func shutdown() async throws
}

// MARK: - Renderer Backend Types

/// Enum specifying the rendering backend implementation
public enum RendererBackend: Sendable, Equatable, Codable {
    case metal
    case opengl
    case cpuSoftware
    case custom(String)
    
    public var displayName: String {
        switch self {
        case .metal:
            return "Metal"
        case .opengl:
            return "OpenGL"
        case .cpuSoftware:
            return "CPU Software"
        case .custom(let name):
            return name
        }
    }
}

// MARK: - Renderer Configuration

/// Configuration structure for renderer initialization
public struct RendererConfiguration: Sendable, Codable {
    /// The preferred backend; renderer may fall back if unavailable
    public let preferredBackend: RendererBackend
    
    /// Maximum number of in-flight frames (typically 2-3)
    public let maxFramesInFlight: UInt32
    
    /// Size of the viewport in pixels
    public let viewportSize: (width: UInt32, height: UInt32)
    
    /// Whether to enable validation layers (debug only)
    public let enableValidation: Bool
    
    /// Custom renderer-specific options
    public let customOptions: [String: String]
    
    public init(
        preferredBackend: RendererBackend = .metal,
        maxFramesInFlight: UInt32 = 3,
        viewportSize: (UInt32, UInt32) = (1280, 720),
        enableValidation: Bool = false,
        customOptions: [String: String] = [:]
    ) {
        self.preferredBackend = preferredBackend
        self.maxFramesInFlight = maxFramesInFlight
        self.viewportSize = viewportSize
        self.enableValidation = enableValidation
        self.customOptions = customOptions
    }
}

// MARK: - Render Command Encoding

/// Protocol for encoding render commands into a frame
public protocol RenderCommandEncoder: Sendable {
    /// Begin a new render pass with the given descriptor
    func beginRenderPass(_ descriptor: RenderPassDescriptor) throws -> RenderPassEncoder
    
    /// Add a compute dispatch command
    func dispatchCompute(pipeline: RenderPipeline, threadgroups: (x: UInt32, y: UInt32, z: UInt32)) throws
    
    /// Complete encoding and return the finalized frame
    func finalize() throws -> RenderFrame
}

// MARK: - Render Pass Encoding

/// Protocol for encoding commands within a render pass
public protocol RenderPassEncoder: Sendable {
    /// Set the current render pipeline
    func setRenderPipeline(_ pipeline: RenderPipeline) throws
    
    /// Set a vertex buffer at the given index
    func setVertexBuffer(_ buffer: RenderBuffer, at index: UInt32) throws
    
    /// Set a fragment (pixel) buffer at the given index
    func setFragmentBuffer(_ buffer: RenderBuffer, at index: UInt32) throws
    
    /// Set a sampled texture at the given index
    func setFragmentTexture(_ texture: RenderTexture, at index: UInt32) throws
    
    /// Draw primitives with the given vertex count
    func drawPrimitives(type: PrimitiveType, vertexStart: UInt32, vertexCount: UInt32) throws
    
    /// Draw indexed primitives
    func drawIndexedPrimitives(
        type: PrimitiveType,
        indexCount: UInt32,
        indexBuffer: RenderBuffer,
        indexBufferOffset: UInt64
    ) throws
    
    /// End the render pass
    func endRenderPass() throws
}

// MARK: - Resource Types

/// Opaque handle to a render pipeline
public struct RenderPipeline: Sendable {
    public let id: UUID
    public let backend: RendererBackend
    
    public init(id: UUID, backend: RendererBackend) {
        self.id = id
        self.backend = backend
    }
}

/// Opaque handle to a GPU buffer
public struct RenderBuffer: Sendable {
    public let id: UUID
    public let sizeBytes: UInt64
    
    public init(id: UUID, sizeBytes: UInt64) {
        self.id = id
        self.sizeBytes = sizeBytes
    }
}

/// Opaque handle to a GPU texture
public struct RenderTexture: Sendable {
    public let id: UUID
    public let width: UInt32
    public let height: UInt32
    public let format: TextureFormat
    
    public init(id: UUID, width: UInt32, height: UInt32, format: TextureFormat) {
        self.id = id
        self.width = width
        self.height = height
        self.format = format
    }
}

// MARK: - Texture Format

/// Enum specifying texture format
public enum TextureFormat: Sendable, Equatable, Codable {
    case rgba8unorm
    case rgba16float
    case rgba32float
    case depth32float
    case stencil8
    case custom(String)
}

// MARK: - Primitive Type

/// Enum specifying primitive types for drawing
public enum PrimitiveType: Sendable, Equatable, Codable {
    case point
    case line
    case lineStrip
    case triangle
    case triangleStrip
}

// MARK: - Render Pass Descriptor

/// Descriptor for a render pass
public struct RenderPassDescriptor: Sendable {
    /// Color attachment configurations
    public let colorAttachments: [ColorAttachmentDescriptor]
    
    /// Optional depth attachment
    public let depthAttachment: DepthAttachmentDescriptor?
    
    /// Load action for color attachments
    public let loadAction: LoadAction
    
    /// Store action for color attachments
    public let storeAction: StoreAction
    
    public init(
        colorAttachments: [ColorAttachmentDescriptor] = [ColorAttachmentDescriptor()],
        depthAttachment: DepthAttachmentDescriptor? = nil,
        loadAction: LoadAction = .clear,
        storeAction: StoreAction = .store
    ) {
        self.colorAttachments = colorAttachments
        self.depthAttachment = depthAttachment
        self.loadAction = loadAction
        self.storeAction = storeAction
    }
}

/// Descriptor for a color attachment
public struct ColorAttachmentDescriptor: Sendable {
    public let format: TextureFormat
    public let clearColor: (Float, Float, Float, Float)
    
    public init(
        format: TextureFormat = .rgba8unorm,
        clearColor: (Float, Float, Float, Float) = (0.0, 0.0, 0.0, 1.0)
    ) {
        self.format = format
        self.clearColor = clearColor
    }
}

/// Descriptor for a depth attachment
public struct DepthAttachmentDescriptor: Sendable {
    public let format: TextureFormat
    public let clearDepth: Float
    
    public init(
        format: TextureFormat = .depth32float,
        clearDepth: Float = 1.0
    ) {
        self.format = format
        self.clearDepth = clearDepth
    }
}

/// Load action for attachments
public enum LoadAction: Sendable, Equatable, Codable {
    case load
    case clear
    case dontCare
}

/// Store action for attachments
public enum StoreAction: Sendable, Equatable, Codable {
    case store
    case dontCare
}

// MARK: - Render Frame

/// Complete frame containing encoded commands
public struct RenderFrame: Sendable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let commandData: Data
    public let resourceBindings: [UUID: ResourceBinding]
    
    public init(
        id: UUID,
        timestamp: TimeInterval,
        commandData: Data,
        resourceBindings: [UUID: ResourceBinding] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.commandData = commandData
        self.resourceBindings = resourceBindings
    }
}

/// Binding of a resource (buffer/texture) to a command
public struct ResourceBinding: Sendable {
    public let resourceId: UUID
    public let bindingIndex: UInt32
    public let resourceType: ResourceType
    
    public enum ResourceType: Sendable, Equatable, Codable {
        case buffer
        case texture
        case sampler
    }
    
    public init(resourceId: UUID, bindingIndex: UInt32, resourceType: ResourceType) {
        self.resourceId = resourceId
        self.bindingIndex = bindingIndex
        self.resourceType = resourceType
    }
}

// MARK: - Frame Synchronization

/// Result of frame submission providing synchronization guarantees
public struct FrameSynchronization: Sendable {
    public let frameId: UUID
    public let submissionTime: TimeInterval
    public let expectedPresentationTime: TimeInterval
    public let gpuWorkFence: UUID
    
    public init(
        frameId: UUID,
        submissionTime: TimeInterval,
        expectedPresentationTime: TimeInterval,
        gpuWorkFence: UUID
    ) {
        self.frameId = frameId
        self.submissionTime = submissionTime
        self.expectedPresentationTime = expectedPresentationTime
        self.gpuWorkFence = gpuWorkFence
    }
}

// MARK: - Render Pipeline Descriptor

/// Descriptor for creating a render pipeline
public struct RenderPipelineDescriptor: Sendable, Hashable {
    /// Vertex shader source/reference
    public let vertexFunction: String
    
    /// Fragment shader source/reference
    public let fragmentFunction: String?
    
    /// Vertex attribute descriptors
    public let vertexAttributes: [VertexAttributeDescriptor]
    
    /// Color attachment formats
    public let colorAttachmentFormats: [TextureFormat]
    
    /// Depth attachment format
    public let depthAttachmentFormat: TextureFormat?
    
    /// Blending mode
    public let blendMode: BlendMode
    
    /// Culling mode
    public let cullMode: CullMode
    
    /// Winding order
    public let windingOrder: WindingOrder
    
    public init(
        vertexFunction: String,
        fragmentFunction: String? = nil,
        vertexAttributes: [VertexAttributeDescriptor] = [],
        colorAttachmentFormats: [TextureFormat] = [.rgba8unorm],
        depthAttachmentFormat: TextureFormat? = nil,
        blendMode: BlendMode = .opaque,
        cullMode: CullMode = .back,
        windingOrder: WindingOrder = .counterClockwise
    ) {
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        self.vertexAttributes = vertexAttributes
        self.colorAttachmentFormats = colorAttachmentFormats
        self.depthAttachmentFormat = depthAttachmentFormat
        self.blendMode = blendMode
        self.cullMode = cullMode
        self.windingOrder = windingOrder
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(vertexFunction)
        hasher.combine(fragmentFunction)
        hasher.combine(colorAttachmentFormats)
        hasher.combine(depthAttachmentFormat)
        hasher.combine(blendMode)
        hasher.combine(cullMode)
        hasher.combine(windingOrder)
    }
}

/// Vertex attribute descriptor
public struct VertexAttributeDescriptor: Sendable, Hashable {
    public let name: String
    public let format: VertexFormat
    public let offset: UInt32
    
    public init(name: String, format: VertexFormat, offset: UInt32) {
        self.name = name
        self.format = format
        self.offset = offset
    }
}

/// Vertex data format
public enum VertexFormat: Sendable, Equatable, Codable, Hashable {
    case float
    case float2
    case float3
    case float4
    case uchar4
    case ushort2
}

/// Blending mode
public enum BlendMode: Sendable, Equatable, Codable, Hashable {
    case opaque
    case alpha
    case additive
    case custom(srcFactor: BlendFactor, dstFactor: BlendFactor)
    
    public enum BlendFactor: Sendable, Equatable, Codable, Hashable {
        case zero
        case one
        case sourceAlpha
        case oneMinusSourceAlpha
        case destinationAlpha
        case oneMinusDestinationAlpha
    }
}

/// Culling mode
public enum CullMode: Sendable, Equatable, Codable, Hashable {
    case front
    case back
    case none
}

/// Winding order for front face determination
public enum WindingOrder: Sendable, Equatable, Codable, Hashable {
    case clockwise
    case counterClockwise
}

// MARK: - Shader Management

/// Protocol for shader compilation and caching
public protocol ShaderManager: Sendable {
    /// Compile a shader source to a pipeline
    func compileShader(
        source: String,
        type: ShaderType,
        entryPoint: String
    ) async throws -> ShaderBinary
    
    /// Get cached shader or compile if missing
    func getOrCompileShader(
        key: String,
        source: String,
        type: ShaderType
    ) async throws -> ShaderBinary
    
    /// Clear the shader cache
    func clearCache() async throws
}

/// Enum for shader types
public enum ShaderType: Sendable, Equatable, Codable {
    case vertex
    case fragment
    case compute
}

/// Compiled shader binary
public struct ShaderBinary: Sendable {
    public let data: Data
    public let shaderType: ShaderType
    public let entryPoint: String
    
    public init(data: Data, shaderType: ShaderType, entryPoint: String) {
        self.data = data
        self.shaderType = shaderType
        self.entryPoint = entryPoint
    }
}
