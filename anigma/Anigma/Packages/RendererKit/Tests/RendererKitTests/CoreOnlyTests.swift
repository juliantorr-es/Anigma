// CoreOnlyTests.swift
// Tests only the core RendererKit functionality without renderer implementations

import XCTest
@testable import RendererKit

final class CoreOnlyTests: XCTestCase {

    func testCoreTypesCompileAndWork() {
        // Test all the core types that don't depend on renderer implementations
        
        // 1. Test Backend Types
        let backends: [RendererBackend] = [.metal, .opengl, .cpuSoftware, .custom("Test")]
        XCTAssertEqual(backends.count, 4)
        XCTAssertEqual(RendererBackend.metal.displayName, "Metal")
        
        // 2. Test Texture Formats
        let formats: [TextureFormat] = [
            .rgba8unorm, .rgba16float, .rgba32float, .depth32float, .stencil8, .custom("Custom")
        ]
        XCTAssertEqual(formats.count, 6)
        XCTAssertEqual(TextureFormat.rgba8unorm, TextureFormat.rgba8unorm)
        XCTAssertNotEqual(TextureFormat.rgba8unorm, TextureFormat.rgba16float)
        
        // 3. Test Primitive Types
        let primitives: [PrimitiveType] = [.point, .line, .lineStrip, .triangle, .triangleStrip]
        XCTAssertEqual(primitives.count, 5)
        
        // 4. Test Load/Store Actions
        let loadActions: [LoadAction] = [.load, .clear, .dontCare]
        let storeActions: [StoreAction] = [.store, .dontCare]
        XCTAssertEqual(loadActions.count, 3)
        XCTAssertEqual(storeActions.count, 2)
        
        // 5. Test Vertex Formats
        let vertexFormats: [VertexFormat] = [.float, .float2, .float3, .float4, .uchar4, .ushort2]
        XCTAssertEqual(vertexFormats.count, 6)
        
        // 6. Test Blend Modes
        let blendModes: [BlendMode] = [.opaque, .alpha, .additive]
        XCTAssertEqual(blendModes.count, 3)
        
        // 7. Test Cull Modes
        let cullModes: [CullMode] = [.front, .back, .none]
        XCTAssertEqual(cullModes.count, 3)
        
        // 8. Test Winding Orders
        let windingOrders: [WindingOrder] = [.clockwise, .counterClockwise]
        XCTAssertEqual(windingOrders.count, 2)
        
        // 9. Test Shader Types
        let shaderTypes: [ShaderType] = [.vertex, .fragment, .compute]
        XCTAssertEqual(shaderTypes.count, 3)
    }
    
    func testConfigurationWorks() {
        // Test default configuration
        let defaultConfig = RendererConfiguration()
        XCTAssertEqual(defaultConfig.preferredBackend, .metal)
        XCTAssertEqual(defaultConfig.maxFramesInFlight, 3)
        XCTAssertEqual(defaultConfig.viewportSize, (1280, 720))
        XCTAssertFalse(defaultConfig.enableValidation)
        XCTAssertTrue(defaultConfig.customOptions.isEmpty)
        
        // Test custom configuration
        let customConfig = RendererConfiguration(
            preferredBackend: .cpuSoftware,
            maxFramesInFlight: 2,
            viewportSize: (800, 600),
            enableValidation: true,
            customOptions: ["debug": "true", "profile": "high"]
        )
        XCTAssertEqual(customConfig.preferredBackend, .cpuSoftware)
        XCTAssertEqual(customConfig.maxFramesInFlight, 2)
        XCTAssertEqual(customConfig.viewportSize, (800, 600))
        XCTAssertTrue(customConfig.enableValidation)
        XCTAssertEqual(customConfig.customOptions["debug"], "true")
        XCTAssertEqual(customConfig.customOptions["profile"], "high")
    }
    
    func testResourceHandlesWork() {
        // Test pipeline handle
        let pipeline = RenderPipeline(id: UUID(), backend: .metal)
        XCTAssertNotNil(pipeline.id)
        XCTAssertEqual(pipeline.backend, .metal)
        
        // Test buffer handle
        let buffer = RenderBuffer(id: UUID(), sizeBytes: 1024)
        XCTAssertNotNil(buffer.id)
        XCTAssertEqual(buffer.sizeBytes, 1024)
        
        // Test texture handle
        let texture = RenderTexture(id: UUID(), width: 1024, height: 768, format: .rgba8unorm)
        XCTAssertNotNil(texture.id)
        XCTAssertEqual(texture.width, 1024)
        XCTAssertEqual(texture.height, 768)
        XCTAssertEqual(texture.format, .rgba8unorm)
    }
    
    func testDescriptorsWork() {
        // Test color attachment descriptor
        let colorAttachment = ColorAttachmentDescriptor(
            format: .rgba16float,
            clearColor: (0.25, 0.5, 0.75, 1.0)
        )
        XCTAssertEqual(colorAttachment.format, .rgba16float)
        XCTAssertEqual(colorAttachment.clearColor, (0.25, 0.5, 0.75, 1.0))
        
        // Test depth attachment descriptor
        let depthAttachment = DepthAttachmentDescriptor(
            format: .depth32float,
            clearDepth: 0.5
        )
        XCTAssertEqual(depthAttachment.format, .depth32float)
        XCTAssertEqual(depthAttachment.clearDepth, 0.5)
        
        // Test render pass descriptor
        let renderPass = RenderPassDescriptor(
            colorAttachments: [colorAttachment],
            depthAttachment: depthAttachment,
            loadAction: .clear,
            storeAction: .store
        )
        XCTAssertEqual(renderPass.colorAttachments.count, 1)
        XCTAssertNotNil(renderPass.depthAttachment)
        XCTAssertEqual(renderPass.loadAction, .clear)
        XCTAssertEqual(renderPass.storeAction, .store)
    }
    
    func testVertexAttributesWork() {
        let attribute = VertexAttributeDescriptor(
            name: "position",
            format: .float3,
            offset: 0
        )
        XCTAssertEqual(attribute.name, "position")
        XCTAssertEqual(attribute.format, .float3)
        XCTAssertEqual(attribute.offset, 0)
    }
    
    func testPipelineDescriptorsWork() {
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
    
    func testFramesAndSynchronizationWork() {
        // Test render frame
        let frame = RenderFrame(
            id: UUID(),
            timestamp: 123.456,
            commandData: Data([0x01, 0x02, 0x03, 0x04])
        )
        XCTAssertNotNil(frame.id)
        XCTAssertEqual(frame.timestamp, 123.456, accuracy: 0.001)
        XCTAssertEqual(frame.commandData, Data([0x01, 0x02, 0x03, 0x04]))
        XCTAssertTrue(frame.resourceBindings.isEmpty)
        
        // Test resource binding
        let binding = ResourceBinding(
            resourceId: UUID(),
            bindingIndex: 0,
            resourceType: .buffer
        )
        XCTAssertNotNil(binding.resourceId)
        XCTAssertEqual(binding.bindingIndex, 0)
        XCTAssertEqual(binding.resourceType, .buffer)
        
        // Test frame synchronization
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
    
    func testShaderBinariesWork() {
        let binary = ShaderBinary(
            data: Data([0xFF, 0xFE, 0xFD]),
            shaderType: .vertex,
            entryPoint: "main"
        )
        XCTAssertEqual(binary.data, Data([0xFF, 0xFE, 0xFD]))
        XCTAssertEqual(binary.shaderType, .vertex)
        XCTAssertEqual(binary.entryPoint, "main")
    }
    
    func testHashableConformance() {
        // Test texture format hashing
        let format1 = TextureFormat.rgba8unorm
        let format2 = TextureFormat.rgba8unorm
        let format3 = TextureFormat.rgba16float
        
        XCTAssertEqual(format1.hashValue, format2.hashValue)
        XCTAssertNotEqual(format1.hashValue, format3.hashValue)
        
        // Test pipeline descriptor hashing
        let descriptor1 = RenderPipelineDescriptor(vertexFunction: "main")
        let descriptor2 = RenderPipelineDescriptor(vertexFunction: "main")
        let descriptor3 = RenderPipelineDescriptor(vertexFunction: "different")
        
        XCTAssertEqual(descriptor1.hashValue, descriptor2.hashValue)
        XCTAssertNotEqual(descriptor1.hashValue, descriptor3.hashValue)
    }
}
