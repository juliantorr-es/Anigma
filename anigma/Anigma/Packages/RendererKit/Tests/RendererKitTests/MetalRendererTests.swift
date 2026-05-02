// MetalRendererTests.swift
// Tests for MetalRenderer implementation

import XCTest
import RendererKit

final class MetalRendererTests: XCTestCase {

    var metalRenderer: MetalRenderer!
    
    override func setUp() async throws {
        metalRenderer = MetalRenderer()
        
        let config = RendererConfiguration(
            preferredBackend: .metal,
            viewportSize: (1280, 720)
        )
        
        try await metalRenderer.initialize(config: config)
    }
    
    override func tearDown() async throws {
        try await metalRenderer.shutdown()
        metalRenderer = nil
    }
    
    // MARK: - Initialization Tests
    
    func testMetalRendererInitialization() async throws {
        XCTAssertNotNil(metalRenderer)
        XCTAssertTrue(metalRenderer.isReady)
        XCTAssertEqual(metalRenderer.backendType, .metal)
        XCTAssertNotNil(metalRenderer.id)
    }
    
    func testMetalRendererInitializationFailure() async {
        // Test with invalid configuration
        let invalidRenderer = MetalRenderer()
        
        // This should fail because Metal is not available in test environment
        // We'll test the error handling path
        
        await XCTAssertThrowsErrorAsync {
            let config = RendererConfiguration(preferredBackend: .metal)
            try await invalidRenderer.initialize(config: config)
        }
    }
    
    // MARK: - Frame Management Tests
    
    func testBeginFrame() async throws {
        let encoder = try await metalRenderer.beginFrame()
        XCTAssertNotNil(encoder)
    }
    
    func testFrameLifecycle() async throws {
        // Begin frame
        let encoder = try await metalRenderer.beginFrame()
        
        // Create a simple render pass descriptor
        let descriptor = RenderPassDescriptor(
            colorAttachments: [ColorAttachmentDescriptor()],
            loadAction: .clear,
            storeAction: .store
        )
        
        // Begin render pass
        let renderPass = try encoder.beginRenderPass(descriptor)
        
        // End render pass
        try renderPass.endRenderPass()
        
        // Finalize frame
        let frame = try encoder.finalize()
        
        XCTAssertNotNil(frame)
        XCTAssertNotNil(frame.id)
        XCTAssertGreaterThan(frame.timestamp, 0)
    }
    
    // MARK: - Pipeline Management Tests
    
    func testGetPipeline() async throws {
        let descriptor = RenderPipelineDescriptor(
            vertexFunction: "test_vertex",
            fragmentFunction: "test_fragment"
        )
        
        let pipeline = try await metalRenderer.getPipeline(descriptor: descriptor)
        
        XCTAssertNotNil(pipeline)
        XCTAssertEqual(pipeline.backend, .metal)
        XCTAssertNotNil(pipeline.id)
    }
    
    // MARK: - Frame Submission Tests
    
    func testSubmitFrame() async throws {
        let frame = RenderFrame(
            id: UUID(),
            timestamp: Date().timeIntervalSince1970,
            commandData: Data()
        )
        
        let sync = try await metalRenderer.submitFrame(frame)
        
        XCTAssertNotNil(sync)
        XCTAssertEqual(sync.frameId, frame.id)
        XCTAssertGreaterThan(sync.submissionTime, 0)
        XCTAssertGreaterThan(sync.expectedPresentationTime, sync.submissionTime)
    }
    
    // MARK: - Shutdown Tests
    
    func testShutdown() async throws {
        XCTAssertTrue(metalRenderer.isReady)
        
        try await metalRenderer.shutdown()
        
        XCTAssertFalse(metalRenderer.isReady)
    }
    
    // MARK: - Error Handling Tests
    
    func testUninitializedRenderer() async {
        let uninitializedRenderer = MetalRenderer()
        
        await XCTAssertThrowsErrorAsync {
            _ = try await uninitializedRenderer.beginFrame()
        }
    }
    
    func testInvalidFrameSubmission() async throws {
        let invalidFrame = RenderFrame(
            id: UUID(),
            timestamp: 0,
            commandData: Data()
        )
        
        // This should handle the invalid frame gracefully
        let sync = try await metalRenderer.submitFrame(invalidFrame)
        XCTAssertNotNil(sync)
    }
    
    // MARK: - Helper Methods
    
    private func XCTAssertThrowsErrorAsync(
        _ expression: @autoclosure () async throws -> Void,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected error to be thrown, but none was thrown." + message(), file: file, line: line)
        } catch {
            // Expected error was thrown
        }
    }
}
