// RendererCoreTests.swift
// Tests for RendererKit core functionality

import XCTest
import RendererKit

final class RendererCoreTests: XCTestCase {

    // MARK: - Configuration Tests
    
    func testRendererConfigurationInitialization() {
        let config = RendererConfiguration(
            preferredBackend: .metal,
            maxFramesInFlight: 2,
            viewportSize: (1920, 1080),
            enableValidation: true,
            customOptions: ["debug": "true"]
        )
        
        XCTAssertEqual(config.preferredBackend, .metal)
        XCTAssertEqual(config.maxFramesInFlight, 2)
        XCTAssertEqual(config.viewportSize, (1920, 1080))
        XCTAssertTrue(config.enableValidation)
        XCTAssertEqual(config.customOptions["debug"], "true")
    }
    
    func testRendererConfigurationDefaults() {
        let config = RendererConfiguration()
        
        XCTAssertEqual(config.preferredBackend, .metal)
        XCTAssertEqual(config.maxFramesInFlight, 3)
        XCTAssertEqual(config.viewportSize, (1280, 720))
        XCTAssertFalse(config.enableValidation)
        XCTAssertTrue(config.customOptions.isEmpty)
    }
    
    // MARK: - Backend Type Tests
    
    func testRendererBackendDisplayNames() {
        XCTAssertEqual(RendererBackend.metal.displayName, "Metal")
        XCTAssertEqual(RendererBackend.opengl.displayName, "OpenGL")
        XCTAssertEqual(RendererBackend.cpuSoftware.displayName, "CPU Software")
        XCTAssertEqual(RendererBackend.custom("Vulkan").displayName, "Vulkan")
    }
    
    // MARK: - Texture Format Tests
    
    func testTextureFormatEquality() {
        XCTAssertEqual(TextureFormat.rgba8unorm, TextureFormat.rgba8unorm)
        XCTAssertNotEqual(TextureFormat.rgba8unorm, TextureFormat.rgba16float)
        XCTAssertEqual(TextureFormat.custom("test"), TextureFormat.custom("test"))
        XCTAssertNotEqual(TextureFormat.custom("test1"), TextureFormat.custom("test2"))
    }
    
    // MARK: - Primitive Type Tests
    
    func testPrimitiveTypeEquality() {
        XCTAssertEqual(PrimitiveType.triangle, PrimitiveType.triangle)
        XCTAssertNotEqual(PrimitiveType.triangle, PrimitiveType.line)
        XCTAssertEqual(PrimitiveType.lineStrip, PrimitiveType.lineStrip)
    }
    
    // MARK: - Load/Store Action Tests
    
    func testLoadActionEquality() {
        XCTAssertEqual(LoadAction.load, LoadAction.load)
        XCTAssertNotEqual(LoadAction.load, LoadAction.clear)
        XCTAssertEqual(LoadAction.dontCare, LoadAction.dontCare)
    }
    
    func testStoreActionEquality() {
        XCTAssertEqual(StoreAction.store, StoreAction.store)
        XCTAssertNotEqual(StoreAction.store, StoreAction.dontCare)
    }
    
    // MARK: - Render Pass Descriptor Tests
    
    func testRenderPassDescriptorInitialization() {
        let colorAttachment = ColorAttachmentDescriptor(
            format: .rgba16float,
            clearColor: (0.1, 0.2, 0.3, 1.0)
        )
        
        let depthAttachment = DepthAttachmentDescriptor(
            format: .depth32float,
            clearDepth: 0.5
        )
        
        let descriptor = RenderPassDescriptor(
            colorAttachments: [colorAttachment],
            depthAttachment: depthAttachment,
            loadAction: .clear,
            storeAction: .store
        )
        
        XCTAssertEqual(descriptor.colorAttachments.count, 1)
        XCTAssertNotNil(descriptor.depthAttachment)
        XCTAssertEqual(descriptor.loadAction, .clear)
        XCTAssertEqual(descriptor.storeAction, .store)
    }
    
    // MARK: - Color Attachment Tests
    
    func testColorAttachmentDescriptor() {
        let attachment = ColorAttachmentDescriptor(
            format: .rgba32float,
            clearColor: (1.0, 0.5, 0.25, 0.75)
        )
        
        XCTAssertEqual(attachment.format, .rgba32float)
        XCTAssertEqual(attachment.clearColor, (1.0, 0.5, 0.25, 0.75))
    }
    
    // MARK: - Depth Attachment Tests
    
    func testDepthAttachmentDescriptor() {
        let attachment = DepthAttachmentDescriptor(
            format: .depth32float,
            clearDepth: 1.0
        )
        
        XCTAssertEqual(attachment.format, .depth32float)
        XCTAssertEqual(attachment.clearDepth, 1.0)
    }
    
    // MARK: - Vertex Attribute Tests
    
    func testVertexAttributeDescriptor() {
        let attribute = VertexAttributeDescriptor(
            name: "position",
            format: .float3,
            offset: 0
        )
        
        XCTAssertEqual(attribute.name, "position")
        XCTAssertEqual(attribute.format, .float3)
        XCTAssertEqual(attribute.offset, 0)
    }
    
    // MARK: - Vertex Format Tests
    
    func testVertexFormatEquality() {
        XCTAssertEqual(VertexFormat.float3, VertexFormat.float3)
        XCTAssertNotEqual(VertexFormat.float3, VertexFormat.float4)
        XCTAssertEqual(VertexFormat.uchar4, VertexFormat.uchar4)
    }
    
    // MARK: - Blend Mode Tests
    
    func testBlendModeEquality() {
        XCTAssertEqual(BlendMode.alpha, BlendMode.alpha)
        XCTAssertNotEqual(BlendMode.alpha, BlendMode.additive)
        
        let custom1 = BlendMode.custom(
            srcFactor: .sourceAlpha,
            dstFactor: .oneMinusSourceAlpha
        )
        
        let custom2 = BlendMode.custom(
            srcFactor: .sourceAlpha,
            dstFactor: .oneMinusSourceAlpha
        )
        
        XCTAssertEqual(custom1, custom2)
    }
    
    // MARK: - Cull Mode Tests
    
    func testCullModeEquality() {
        XCTAssertEqual(CullMode.back, CullMode.back)
        XCTAssertNotEqual(CullMode.back, CullMode.front)
        XCTAssertEqual(CullMode.none, CullMode.none)
    }
    
    // MARK: - Winding Order Tests
    
    func testWindingOrderEquality() {
        XCTAssertEqual(WindingOrder.counterClockwise, WindingOrder.counterClockwise)
        XCTAssertNotEqual(WindingOrder.counterClockwise, WindingOrder.clockwise)
    }
    
    // MARK: - Render Pipeline Descriptor Tests
    
    func testRenderPipelineDescriptor() {
        let vertexAttribute = VertexAttributeDescriptor(
            name: "position",
            format: .float3,
            offset: 0
        )
        
        let descriptor = RenderPipelineDescriptor(
            vertexFunction: "vertex_main",
            fragmentFunction: "fragment_main",
            vertexAttributes: [vertexAttribute],
            colorAttachmentFormats: [.rgba8unorm],
            depthAttachmentFormat: .depth32float,
            blendMode: .alpha,
            cullMode: .back,
            windingOrder: .counterClockwise
        )
        
        XCTAssertEqual(descriptor.vertexFunction, "vertex_main")
        XCTAssertEqual(descriptor.fragmentFunction, "fragment_main")
        XCTAssertEqual(descriptor.vertexAttributes.count, 1)
        XCTAssertEqual(descriptor.colorAttachmentFormats, [.rgba8unorm])
        XCTAssertEqual(descriptor.depthAttachmentFormat, .depth32float)
        XCTAssertEqual(descriptor.blendMode, .alpha)
        XCTAssertEqual(descriptor.cullMode, .back)
        XCTAssertEqual(descriptor.windingOrder, .counterClockwise)
    }
    
    func testRenderPipelineDescriptorHashing() {
        let descriptor1 = RenderPipelineDescriptor(
            vertexFunction: "vertex_main",
            fragmentFunction: "fragment_main"
        )
        
        let descriptor2 = RenderPipelineDescriptor(
            vertexFunction: "vertex_main",
            fragmentFunction: "fragment_main"
        )
        
        let descriptor3 = RenderPipelineDescriptor(
            vertexFunction: "different_vertex",
            fragmentFunction: "fragment_main"
        )
        
        XCTAssertEqual(descriptor1.hashValue, descriptor2.hashValue)
        XCTAssertNotEqual(descriptor1.hashValue, descriptor3.hashValue)
    }
    
    // MARK: - Resource Handle Tests
    
    func testRenderPipelineHandle() {
        let pipeline = RenderPipeline(id: UUID(), backend: .metal)
        XCTAssertNotNil(pipeline.id)
        XCTAssertEqual(pipeline.backend, .metal)
    }
    
    func testRenderBufferHandle() {
        let buffer = RenderBuffer(id: UUID(), sizeBytes: 1024)
        XCTAssertNotNil(buffer.id)
        XCTAssertEqual(buffer.sizeBytes, 1024)
    }
    
    func testRenderTextureHandle() {
        let texture = RenderTexture(
            id: UUID(),
            width: 1024,
            height: 768,
            format: .rgba8unorm
        )
        
        XCTAssertNotNil(texture.id)
        XCTAssertEqual(texture.width, 1024)
        XCTAssertEqual(texture.height, 768)
        XCTAssertEqual(texture.format, .rgba8unorm)
    }
    
    // MARK: - Render Frame Tests
    
    func testRenderFrameInitialization() {
        let frame = RenderFrame(
            id: UUID(),
            timestamp: 123.456,
            commandData: Data([0x01, 0x02, 0x03])
        )
        
        XCTAssertNotNil(frame.id)
        XCTAssertEqual(frame.timestamp, 123.456, accuracy: 0.001)
        XCTAssertEqual(frame.commandData, Data([0x01, 0x02, 0x03]))
        XCTAssertTrue(frame.resourceBindings.isEmpty)
    }
    
    // MARK: - Resource Binding Tests
    
    func testResourceBinding() {
        let binding = ResourceBinding(
            resourceId: UUID(),
            bindingIndex: 0,
            resourceType: .buffer
        )
        
        XCTAssertNotNil(binding.resourceId)
        XCTAssertEqual(binding.bindingIndex, 0)
        XCTAssertEqual(binding.resourceType, .buffer)
    }
    
    // MARK: - Frame Synchronization Tests
    
    func testFrameSynchronization() {
        let sync = FrameSynchronization(
            frameId: UUID(),
            submissionTime: 100.0,
            expectedPresentationTime: 100.0 + (1.0 / 60.0),
            gpuWorkFence: UUID()
        )
        
        XCTAssertNotNil(sync.frameId)
        XCTAssertEqual(sync.submissionTime, 100.0, accuracy: 0.001)
        XCTAssertEqual(sync.expectedPresentationTime, 100.0 + (1.0 / 60.0), accuracy: 0.001)
        XCTAssertNotNil(sync.gpuWorkFence)
    }
    
    // MARK: - Shader Type Tests
    
    func testShaderTypeEquality() {
        XCTAssertEqual(ShaderType.vertex, ShaderType.vertex)
        XCTAssertNotEqual(ShaderType.vertex, ShaderType.fragment)
        XCTAssertEqual(ShaderType.compute, ShaderType.compute)
    }
    
    // MARK: - Shader Binary Tests
    
    func testShaderBinary() {
        let binary = ShaderBinary(
            data: Data([0xFF, 0xFE]),
            shaderType: .vertex,
            entryPoint: "main"
        )
        
        XCTAssertEqual(binary.data, Data([0xFF, 0xFE]))
        XCTAssertEqual(binary.shaderType, .vertex)
        XCTAssertEqual(binary.entryPoint, "main")
    }
}
