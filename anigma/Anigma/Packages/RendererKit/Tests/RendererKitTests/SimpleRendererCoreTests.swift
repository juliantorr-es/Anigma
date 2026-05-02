// SimpleRendererCoreTests.swift
// Simplified tests for RendererKit core functionality

import XCTest
import RendererKit

final class SimpleRendererCoreTests: XCTestCase {

    // MARK: - Basic Type Tests
    
    func testRendererBackendTypes() {
        let backends: [RendererBackend] = [.metal, .opengl, .cpuSoftware, .custom("Test")]
        
        for backend in backends {
            XCTAssertNotNil(backend.displayName)
            XCTAssertFalse(backend.displayName.isEmpty)
        }
        
        XCTAssertEqual(RendererBackend.metal.displayName, "Metal")
        XCTAssertEqual(RendererBackend.opengl.displayName, "OpenGL")
        XCTAssertEqual(RendererBackend.cpuSoftware.displayName, "CPU Software")
        XCTAssertEqual(RendererBackend.custom("Vulkan").displayName, "Vulkan")
    }
    
    func testTextureFormats() {
        let formats: [TextureFormat] = [
            .rgba8unorm, .rgba16float, .rgba32float, 
            .depth32float, .stencil8, .custom("Test")
        ]
        
        // Test that all formats can be created and compared
        for format in formats {
            XCTAssertNotEqual(format, TextureFormat.custom("Different"))
            XCTAssertEqual(format, format)
        }
    }
    
    func testPrimitiveTypes() {
        let types: [PrimitiveType] = [.point, .line, .lineStrip, .triangle, .triangleStrip]
        
        for type in types {
            XCTAssertEqual(type, type)
            XCTAssertNotEqual(type, PrimitiveType.custom("Different"))
        }
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationCreation() {
        let config = RendererConfiguration()
        
        XCTAssertEqual(config.preferredBackend, .metal)
        XCTAssertEqual(config.maxFramesInFlight, 3)
        XCTAssertEqual(config.viewportSize, (1280, 720))
        XCTAssertFalse(config.enableValidation)
        XCTAssertTrue(config.customOptions.isEmpty)
    }
    
    func testConfigurationCustomization() {
        let config = RendererConfiguration(
            preferredBackend: .cpuSoftware,
            maxFramesInFlight: 2,
            viewportSize: (1920, 1080),
            enableValidation: true,
            customOptions: ["debug": "true", "profile": "high"]
        )
        
        XCTAssertEqual(config.preferredBackend, .cpuSoftware)
        XCTAssertEqual(config.maxFramesInFlight, 2)
        XCTAssertEqual(config.viewportSize, (1920, 1080))
        XCTAssertTrue(config.enableValidation)
        XCTAssertEqual(config.customOptions["debug"], "true")
        XCTAssertEqual(config.customOptions["profile"], "high")
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
    
    // MARK: - Descriptor Tests
    
    func testColorAttachmentDescriptor() {
        let attachment = ColorAttachmentDescriptor(
            format: .rgba16float,
            clearColor: (0.5, 0.5, 0.5, 1.0)
        )
        
        XCTAssertEqual(attachment.format, .rgba16float)
        XCTAssertEqual(attachment.clearColor, (0.5, 0.5, 0.5, 1.0))
    }
    
    func testDepthAttachmentDescriptor() {
        let attachment = DepthAttachmentDescriptor(
            format: .depth32float,
            clearDepth: 0.8
        )
        
        XCTAssertEqual(attachment.format, .depth32float)
        XCTAssertEqual(attachment.clearDepth, 0.8)
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
    
    // MARK: - Vertex Format Tests
    
    func testVertexFormats() {
        let formats: [VertexFormat] = [.float, .float2, .float3, .float4, .uchar4, .ushort2]
        
        for format in formats {
            XCTAssertEqual(format, format)
        }
        
        XCTAssertNotEqual(VertexFormat.float, VertexFormat.float2)
        XCTAssertNotEqual(VertexFormat.float3, VertexFormat.float4)
    }
    
    // MARK: - Blend Mode Tests
    
    func testBlendModes() {
        let modes: [BlendMode] = [.opaque, .alpha, .additive]
        
        for mode in modes {
            XCTAssertEqual(mode, mode)
        }
        
        XCTAssertNotEqual(BlendMode.opaque, BlendMode.alpha)
        XCTAssertNotEqual(BlendMode.alpha, BlendMode.additive)
    }
    
    func testCustomBlendMode() {
        let custom1 = BlendMode.custom(
            srcFactor: .sourceAlpha,
            dstFactor: .oneMinusSourceAlpha
        )
        
        let custom2 = BlendMode.custom(
            srcFactor: .sourceAlpha,
            dstFactor: .oneMinusSourceAlpha
        )
        
        XCTAssertEqual(custom1, custom2)
        XCTAssertNotEqual(custom1, BlendMode.opaque)
    }
    
    // MARK: - Cull Mode Tests
    
    func testCullModes() {
        let modes: [CullMode] = [.front, .back, .none]
        
        for mode in modes {
            XCTAssertEqual(mode, mode)
        }
        
        XCTAssertNotEqual(CullMode.front, CullMode.back)
        XCTAssertNotEqual(CullMode.back, CullMode.none)
    }
    
    // MARK: - Winding Order Tests
    
    func testWindingOrders() {
        let orders: [WindingOrder] = [.clockwise, .counterClockwise]
        
        for order in orders {
            XCTAssertEqual(order, order)
        }
        
        XCTAssertNotEqual(WindingOrder.clockwise, WindingOrder.counterClockwise)
    }
    
    // MARK: - Shader Type Tests
    
    func testShaderTypes() {
        let types: [ShaderType] = [.vertex, .fragment, .compute]
        
        for type in types {
            XCTAssertEqual(type, type)
        }
        
        XCTAssertNotEqual(ShaderType.vertex, ShaderType.fragment)
        XCTAssertNotEqual(ShaderType.fragment, ShaderType.compute)
    }
    
    // MARK: - Shader Binary Tests
    
    func testShaderBinary() {
        let binary = ShaderBinary(
            data: Data([0x01, 0x02, 0x03]),
            shaderType: .vertex,
            entryPoint: "main"
        )
        
        XCTAssertEqual(binary.data, Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(binary.shaderType, .vertex)
        XCTAssertEqual(binary.entryPoint, "main")
    }
    
    // MARK: - Frame Synchronization Tests
    
    func testFrameSynchronization() {
        let sync = FrameSynchronization(
            frameId: UUID(),
            submissionTime: 100.0,
            expectedPresentationTime: 100.1667, // ~60 FPS
            gpuWorkFence: UUID()
        )
        
        XCTAssertNotNil(sync.frameId)
        XCTAssertEqual(sync.submissionTime, 100.0, accuracy: 0.001)
        XCTAssertEqual(sync.expectedPresentationTime, 100.1667, accuracy: 0.001)
        XCTAssertNotNil(sync.gpuWorkFence)
    }
}
