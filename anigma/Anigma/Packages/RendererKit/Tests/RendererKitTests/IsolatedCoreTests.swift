// IsolatedCoreTests.swift
// Completely isolated tests for RendererKit core functionality

import XCTest

// Import only the core types we need to test
@testable import RendererKit

final class IsolatedCoreTests: XCTestCase {

    // MARK: - Renderer Backend Tests
    
    func testRendererBackendTypes() {
        let backends: [RendererBackend] = [
            .metal, .opengl, .cpuSoftware, .custom("Test")
        ]
        
        XCTAssertEqual(backends.count, 4)
        XCTAssertEqual(RendererBackend.metal.displayName, "Metal")
        XCTAssertEqual(RendererBackend.opengl.displayName, "OpenGL")
        XCTAssertEqual(RendererBackend.cpuSoftware.displayName, "CPU Software")
        XCTAssertEqual(RendererBackend.custom("Vulkan").displayName, "Vulkan")
    }
    
    // MARK: - Texture Format Tests
    
    func testTextureFormatTypes() {
        let formats: [TextureFormat] = [
            .rgba8unorm, .rgba16float, .rgba32float,
            .depth32float, .stencil8, .custom("Custom")
        ]
        
        XCTAssertEqual(formats.count, 6)
        
        // Test equality
        XCTAssertEqual(TextureFormat.rgba8unorm, TextureFormat.rgba8unorm)
        XCTAssertNotEqual(TextureFormat.rgba8unorm, TextureFormat.rgba16float)
    }
    
    // MARK: - Primitive Type Tests
    
    func testPrimitiveTypes() {
        let types: [PrimitiveType] = [
            .point, .line, .lineStrip, .triangle, .triangleStrip
        ]
        
        XCTAssertEqual(types.count, 5)
        
        // Test equality
        XCTAssertEqual(PrimitiveType.triangle, PrimitiveType.triangle)
        XCTAssertNotEqual(PrimitiveType.triangle, PrimitiveType.line)
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
    
    func testResourceHandles() {
        let pipeline = RenderPipeline(id: UUID(), backend: .metal)
        let buffer = RenderBuffer(id: UUID(), sizeBytes: 1024)
        let texture = RenderTexture(id: UUID(), width: 100, height: 100, format: .rgba8unorm)
        
        XCTAssertNotNil(pipeline.id)
        XCTAssertNotNil(buffer.id)
        XCTAssertNotNil(texture.id)
        
        XCTAssertEqual(pipeline.backend, .metal)
        XCTAssertEqual(buffer.sizeBytes, 1024)
        XCTAssertEqual(texture.width, 100)
        XCTAssertEqual(texture.height, 100)
        XCTAssertEqual(texture.format, .rgba8unorm)
    }
    
    // MARK: - Descriptor Tests
    
    func testAttachmentDescriptors() {
        let colorAttachment = ColorAttachmentDescriptor(
            format: .rgba16float,
            clearColor: (0.25, 0.5, 0.75, 1.0)
        )
        
        let depthAttachment = DepthAttachmentDescriptor(
            format: .depth32float,
            clearDepth: 0.5
        )
        
        XCTAssertEqual(colorAttachment.format, .rgba16float)
        XCTAssertEqual(colorAttachment.clearColor, (0.25, 0.5, 0.75, 1.0))
        
        XCTAssertEqual(depthAttachment.format, .depth32float)
        XCTAssertEqual(depthAttachment.clearDepth, 0.5)
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
    
    // MARK: - Hashable Tests
    
    func testTextureFormatHashable() {
        let format1 = TextureFormat.rgba8unorm
        let format2 = TextureFormat.rgba8unorm
        let format3 = TextureFormat.rgba16float
        
        XCTAssertEqual(format1.hashValue, format2.hashValue)
        XCTAssertNotEqual(format1.hashValue, format3.hashValue)
    }
    
    func testPipelineDescriptorHashable() {
        let descriptor1 = RenderPipelineDescriptor(vertexFunction: "main")
        let descriptor2 = RenderPipelineDescriptor(vertexFunction: "main")
        let descriptor3 = RenderPipelineDescriptor(vertexFunction: "different")
        
        XCTAssertEqual(descriptor1.hashValue, descriptor2.hashValue)
        XCTAssertNotEqual(descriptor1.hashValue, descriptor3.hashValue)
    }
}
