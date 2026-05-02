// BasicCoreTests.swift
// Basic tests to verify RendererKit core types work

import XCTest
@testable import RendererKit

final class BasicCoreTests: XCTestCase {

    func testCoreTypesExist() {
        // Test that all basic types can be created and used
        
        // Test enums
        let _ = RendererBackend.metal
        let _ = TextureFormat.rgba8unorm
        let _ = PrimitiveType.triangle
        let _ = LoadAction.clear
        let _ = StoreAction.store
        let _ = VertexFormat.float3
        let _ = BlendMode.alpha
        let _ = CullMode.back
        let _ = WindingOrder.counterClockwise
        let _ = ShaderType.vertex
        
        // Test configuration
        let config = RendererConfiguration()
        XCTAssertEqual(config.preferredBackend, .metal)
        XCTAssertEqual(config.maxFramesInFlight, 3)
        XCTAssertEqual(config.viewportSize, (1280, 720))
        
        // Test resource handles
        let pipeline = RenderPipeline(id: UUID(), backend: .metal)
        XCTAssertNotNil(pipeline.id)
        
        let buffer = RenderBuffer(id: UUID(), sizeBytes: 1024)
        XCTAssertNotNil(buffer.id)
        
        let texture = RenderTexture(id: UUID(), width: 100, height: 100, format: .rgba8unorm)
        XCTAssertNotNil(texture.id)
        
        // Test descriptors
        let colorAttachment = ColorAttachmentDescriptor()
        XCTAssertNotNil(colorAttachment)
        
        let depthAttachment = DepthAttachmentDescriptor()
        XCTAssertNotNil(depthAttachment)
        
        let renderPass = RenderPassDescriptor()
        XCTAssertNotNil(renderPass)
        
        // Test vertex attributes
        let vertexAttr = VertexAttributeDescriptor(name: "position", format: .float3, offset: 0)
        XCTAssertNotNil(vertexAttr)
        
        // Test pipeline descriptors
        let pipelineDesc = RenderPipelineDescriptor(vertexFunction: "main")
        XCTAssertNotNil(pipelineDesc)
        
        // Test frames
        let frame = RenderFrame(id: UUID(), timestamp: 0, commandData: Data())
        XCTAssertNotNil(frame)
        
        // Test resource bindings
        let binding = ResourceBinding(resourceId: UUID(), bindingIndex: 0, resourceType: .buffer)
        XCTAssertNotNil(binding)
        
        // Test frame synchronization
        let sync = FrameSynchronization(frameId: UUID(), submissionTime: 0, expectedPresentationTime: 0, gpuWorkFence: UUID())
        XCTAssertNotNil(sync)
        
        // Test shader binaries
        let shader = ShaderBinary(data: Data(), shaderType: .vertex, entryPoint: "main")
        XCTAssertNotNil(shader)
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
    
    func testTextureFormatHashable() {
        let format1 = TextureFormat.rgba8unorm
        let format2 = TextureFormat.rgba8unorm
        
        XCTAssertEqual(format1, format2)
        XCTAssertEqual(format1.hashValue, format2.hashValue)
    }
}
