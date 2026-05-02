// MinimalCoreTests.swift
// Minimal tests to verify RendererKit core types compile and work

import XCTest
@testable import RendererKit

final class MinimalCoreTests: XCTestCase {

    func testBasicTypesCompile() {
        // Test that all basic types can be created
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
        
        // Test that configuration can be created
        let config = RendererConfiguration()
        XCTAssertNotNil(config)
        
        // Test that resource handles can be created
        let pipeline = RenderPipeline(id: UUID(), backend: .metal)
        XCTAssertNotNil(pipeline)
        
        let buffer = RenderBuffer(id: UUID(), sizeBytes: 1024)
        XCTAssertNotNil(buffer)
        
        let texture = RenderTexture(id: UUID(), width: 100, height: 100, format: .rgba8unorm)
        XCTAssertNotNil(texture)
        
        // Test that descriptors can be created
        let colorAttachment = ColorAttachmentDescriptor()
        XCTAssertNotNil(colorAttachment)
        
        let depthAttachment = DepthAttachmentDescriptor()
        XCTAssertNotNil(depthAttachment)
        
        let renderPass = RenderPassDescriptor()
        XCTAssertNotNil(renderPass)
        
        // Test that vertex attributes can be created
        let vertexAttr = VertexAttributeDescriptor(name: "position", format: .float3, offset: 0)
        XCTAssertNotNil(vertexAttr)
        
        // Test that pipeline descriptors can be created
        let pipelineDesc = RenderPipelineDescriptor(vertexFunction: "main")
        XCTAssertNotNil(pipelineDesc)
        
        // Test that frames can be created
        let frame = RenderFrame(id: UUID(), timestamp: 0, commandData: Data())
        XCTAssertNotNil(frame)
        
        // Test that resource bindings can be created
        let binding = ResourceBinding(resourceId: UUID(), bindingIndex: 0, resourceType: .buffer)
        XCTAssertNotNil(binding)
        
        // Test that frame synchronization can be created
        let sync = FrameSynchronization(frameId: UUID(), submissionTime: 0, expectedPresentationTime: 0, gpuWorkFence: UUID())
        XCTAssertNotNil(sync)
        
        // Test that shader binaries can be created
        let shader = ShaderBinary(data: Data(), shaderType: .vertex, entryPoint: "main")
        XCTAssertNotNil(shader)
    }
}
