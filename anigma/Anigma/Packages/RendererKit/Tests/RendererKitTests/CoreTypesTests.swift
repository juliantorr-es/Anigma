// CoreTypesTests.swift
// Tests for RendererKit core types and basic functionality

import XCTest
@testable import RendererKit

final class CoreTypesTests: XCTestCase {

    // MARK: - Renderer Backend Tests
    
    func testRendererBackendDisplayNames() {
        XCTAssertEqual(RendererBackend.metal.displayName, "Metal")
        XCTAssertEqual(RendererBackend.opengl.displayName, "OpenGL")
        XCTAssertEqual(RendererBackend.cpuSoftware.displayName, "CPU Software")
        XCTAssertEqual(RendererBackend.custom("Custom").displayName, "Custom")
    }
    
    func testRendererBackendEquality() {
        XCTAssertEqual(RendererBackend.metal, RendererBackend.metal)
        XCTAssertNotEqual(RendererBackend.metal, RendererBackend.opengl)
        XCTAssertNotEqual(RendererBackend.opengl, RendererBackend.cpuSoftware)
    }
    
    // MARK: - Texture Format Tests
    
    func testTextureFormatEquality() {
        XCTAssertEqual(TextureFormat.rgba8unorm, TextureFormat.rgba8unorm)
        XCTAssertNotEqual(TextureFormat.rgba8unorm, TextureFormat.rgba16float)
        XCTAssertEqual(TextureFormat.custom("test"), TextureFormat.custom("test"))
        XCTAssertNotEqual(TextureFormat.custom("a"), TextureFormat.custom("b"))
    }
    
    // MARK: - Primitive Type Tests
    
    func testPrimitiveTypeEquality() {
        XCTAssertEqual(PrimitiveType.point, PrimitiveType.point)
        XCTAssertEqual(PrimitiveType.line, PrimitiveType.line)
        XCTAssertEqual(PrimitiveType.lineStrip, PrimitiveType.lineStrip)
        XCTAssertEqual(PrimitiveType.triangle, PrimitiveType.triangle)
        XCTAssertEqual(PrimitiveType.triangleStrip, PrimitiveType.triangleStrip)
        
        XCTAssertNotEqual(PrimitiveType.point, PrimitiveType.line)
        XCTAssertNotEqual(PrimitiveType.triangle, PrimitiveType.lineStrip)
    }
    
    // MARK: - Load/Store Action Tests
    
    func testLoadActionEquality() {
        XCTAssertEqual(LoadAction.load, LoadAction.load)
        XCTAssertEqual(LoadAction.clear, LoadAction.clear)
        XCTAssertEqual(LoadAction.dontCare, LoadAction.dontCare)
        
        XCTAssertNotEqual(LoadAction.load, LoadAction.clear)
        XCTAssertNotEqual(LoadAction.clear, LoadAction.dontCare)
    }
    
    func testStoreActionEquality() {
        XCTAssertEqual(StoreAction.store, StoreAction.store)
        XCTAssertEqual(StoreAction.dontCare, StoreAction.dontCare)
        
        XCTAssertNotEqual(StoreAction.store, StoreAction.dontCare)
    }
    
    // MARK: - Vertex Format Tests
    
    func testVertexFormatEquality() {
        XCTAssertEqual(VertexFormat.float, VertexFormat.float)
        XCTAssertEqual(VertexFormat.float2, VertexFormat.float2)
        XCTAssertEqual(VertexFormat.float3, VertexFormat.float3)
        XCTAssertEqual(VertexFormat.float4, VertexFormat.float4)
        XCTAssertEqual(VertexFormat.uchar4, VertexFormat.uchar4)
        XCTAssertEqual(VertexFormat.ushort2, VertexFormat.ushort2)
        
        XCTAssertNotEqual(VertexFormat.float, VertexFormat.float2)
        XCTAssertNotEqual(VertexFormat.float3, VertexFormat.float4)
    }
    
    // MARK: - Blend Mode Tests
    
    func testBlendModeEquality() {
        XCTAssertEqual(BlendMode.opaque, BlendMode.opaque)
        XCTAssertEqual(BlendMode.alpha, BlendMode.alpha)
        XCTAssertEqual(BlendMode.additive, BlendMode.additive)
        
        XCTAssertNotEqual(BlendMode.opaque, BlendMode.alpha)
        XCTAssertNotEqual(BlendMode.alpha, BlendMode.additive)
    }
    
    func testCustomBlendModeEquality() {
        let blend1 = BlendMode.custom(srcFactor: .sourceAlpha, dstFactor: .oneMinusSourceAlpha)
        let blend2 = BlendMode.custom(srcFactor: .sourceAlpha, dstFactor: .oneMinusSourceAlpha)
        let blend3 = BlendMode.custom(srcFactor: .one, dstFactor: .zero)
        
        XCTAssertEqual(blend1, blend2)
        XCTAssertNotEqual(blend1, blend3)
        XCTAssertNotEqual(blend1, BlendMode.opaque)
    }
    
    // MARK: - Cull Mode Tests
    
    func testCullModeEquality() {
        XCTAssertEqual(CullMode.front, CullMode.front)
        XCTAssertEqual(CullMode.back, CullMode.back)
        XCTAssertEqual(CullMode.none, CullMode.none)
        
        XCTAssertNotEqual(CullMode.front, CullMode.back)
        XCTAssertNotEqual(CullMode.back, CullMode.none)
    }
    
    // MARK: - Winding Order Tests
    
    func testWindingOrderEquality() {
        XCTAssertEqual(WindingOrder.clockwise, WindingOrder.clockwise)
        XCTAssertEqual(WindingOrder.counterClockwise, WindingOrder.counterClockwise)
        
        XCTAssertNotEqual(WindingOrder.clockwise, WindingOrder.counterClockwise)
    }
    
    // MARK: - Shader Type Tests
    
    func testShaderTypeEquality() {
        XCTAssertEqual(ShaderType.vertex, ShaderType.vertex)
        XCTAssertEqual(ShaderType.fragment, ShaderType.fragment)
        XCTAssertEqual(ShaderType.compute, ShaderType.compute)
        
        XCTAssertNotEqual(ShaderType.vertex, ShaderType.fragment)
        XCTAssertNotEqual(ShaderType.fragment, ShaderType.compute)
    }
    
    // MARK: - Configuration Tests
    
    func testRendererConfigurationDefaults() {
        let config = RendererConfiguration()
        
        XCTAssertEqual(config.preferredBackend, .metal)
        XCTAssertEqual(config.maxFramesInFlight, 3)
        XCTAssertEqual(config.viewportSize, (1280, 720))
        XCTAssertFalse(config.enableValidation)
        XCTAssertTrue(config.customOptions.isEmpty)
    }
    
    func testRendererConfigurationCustom() {
        let config = RendererConfiguration(
            preferredBackend: .cpuSoftware,
            maxFramesInFlight: 2,
            viewportSize: (800, 600),
            enableValidation: true,
            customOptions: ["debug": "true"]
        )
        
        XCTAssertEqual(config.preferredBackend, .cpuSoftware)
        XCTAssertEqual(config.maxFramesInFlight, 2)
        XCTAssertEqual(config.viewportSize, (800, 600))
        XCTAssertTrue(config.enableValidation)
        XCTAssertEqual(config.customOptions["debug"], "true")
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
        let texture = RenderTexture(id: UUID(), width: 1024, height: 768, format: .rgba8unorm)
        
        XCTAssertNotNil(texture.id)
        XCTAssertEqual(texture.width, 1024)
        XCTAssertEqual(texture.height, 768)
        XCTAssertEqual(texture.format, .rgba8unorm)
    }
    
    // MARK: - Descriptor Tests
    
    func testColorAttachmentDescriptor() {
        let attachment = ColorAttachmentDescriptor(
            format: .rgba16float,
            clearColor: (0.25, 0.5, 0.75, 1.0)
        )
        
        XCTAssertEqual(attachment.format, .rgba16float)
        XCTAssertEqual(attachment.clearColor, (0.25, 0.5, 0.75, 1.0))
    }
    
    func testDepthAttachmentDescriptor() {
        let attachment = DepthAttachmentDescriptor(
            format: .depth32float,
            clearDepth: 0.5
        )
        
        XCTAssertEqual(attachment.format, .depth32float)
        XCTAssertEqual(attachment.clearDepth, 0.5)
    }
    
    func testRenderPassDescriptor() {
        let colorAttachment = ColorAttachmentDescriptor()
        let depthAttachment = DepthAttachmentDescriptor()
        
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
    
    // MARK: - Pipeline Descriptor Tests
    
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
    
    // MARK: - Frame Tests
    
    func testRenderFrame() {
        let frame = RenderFrame(
            id: UUID(),
            timestamp: 123.456,
            commandData: Data([0x01, 0x02, 0x03, 0x04])
        )
        
        XCTAssertNotNil(frame.id)
        XCTAssertEqual(frame.timestamp, 123.456, accuracy: 0.001)
        XCTAssertEqual(frame.commandData, Data([0x01, 0x02, 0x03, 0x04]))
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
            expectedPresentationTime: 100.1667,
            gpuWorkFence: UUID()
        )
        
        XCTAssertNotNil(sync.frameId)
        XCTAssertEqual(sync.submissionTime, 100.0, accuracy: 0.001)
        XCTAssertEqual(sync.expectedPresentationTime, 100.1667, accuracy: 0.001)
        XCTAssertNotNil(sync.gpuWorkFence)
    }
    
    // MARK: - Shader Binary Tests
    
    func testShaderBinary() {
        let binary = ShaderBinary(
            data: Data([0xFF, 0xFE, 0xFD]),
            shaderType: .vertex,
            entryPoint: "main"
        )
        
        XCTAssertEqual(binary.data, Data([0xFF, 0xFE, 0xFD]))
        XCTAssertEqual(binary.shaderType, .vertex)
        XCTAssertEqual(binary.entryPoint, "main")
    }
}
