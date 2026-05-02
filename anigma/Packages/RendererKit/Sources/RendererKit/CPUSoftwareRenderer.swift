// CPUSoftwareRenderer.swift
// CPU-based software renderer for fallback rendering

import Foundation
import CapsuleCore

// MARK: - CPU Software Renderer

/// CPU-based software renderer for fallback and testing
public actor CPUSoftwareRenderer: @preconcurrency RenderEngine {
    public let id: UUID
    public let backendType: RendererBackend = .cpuSoftware
    
    public private(set) var isReady: Bool = false
    
    private var configuration: RendererConfiguration?
    private var frameBuffer: [UInt32]?
    // No lock needed with actor isolation
    
    public init() {
        self.id = UUID()
    }
    
    public func initialize(config: RendererConfiguration) async throws {
        let pixelCount = Int(config.viewportSize.width * config.viewportSize.height)
        self.frameBuffer = Array(repeating: 0xFFFFFFFF, count: pixelCount)
        self.configuration = config
        self.isReady = true
    }
    
    public func beginFrame() async throws -> RenderCommandEncoder {
        guard isReady else {
            throw CapsuleError.operationFailed(
                code: 10,
                message: "CPU renderer not initialized",
                context: ["backend": "CPU"]
            )
        }
        
        return CPUSoftwareCommandEncoder(frameBuffer: frameBuffer)
    }
    
    public func submitFrame(_ frame: RenderFrame) async throws -> FrameSynchronization {
        let submissionTime = Date().timeIntervalSince1970
        
        return FrameSynchronization(
            frameId: frame.id,
            submissionTime: submissionTime,
            expectedPresentationTime: submissionTime + 0.016,
            gpuWorkFence: UUID()
        )
    }
    
    public func getPipeline(descriptor: RenderPipelineDescriptor) async throws -> RenderPipeline {
        return RenderPipeline(id: UUID(), backend: .cpuSoftware)
    }
    
    public func shutdown() async throws {
        frameBuffer = nil
        isReady = false
    }
}

// MARK: - CPU Software Command Encoder

final actor CPUSoftwareCommandEncoder: @preconcurrency RenderCommandEncoder {
    private var frameBuffer: [UInt32]?
    
    init(frameBuffer: [UInt32]?) {
        self.frameBuffer = frameBuffer
    }
    
    func beginRenderPass(_ descriptor: RenderPassDescriptor) throws -> RenderPassEncoder {
        return CPUSoftwareRenderPassEncoder(frameBuffer: frameBuffer)
    }
    
    func dispatchCompute(
        pipeline: RenderPipeline,
        threadgroups: (x: UInt32, y: UInt32, z: UInt32)
    ) throws {
        // CPU compute dispatch
    }
    
    func finalize() throws -> RenderFrame {
        return RenderFrame(
            id: UUID(),
            timestamp: Date().timeIntervalSince1970,
            commandData: Data()
        )
    }
}

// MARK: - CPU Software Render Pass Encoder

final actor CPUSoftwareRenderPassEncoder: @preconcurrency RenderPassEncoder {
    private var frameBuffer: [UInt32]
    
    init(frameBuffer: [UInt32]?) {
        self.frameBuffer = frameBuffer ?? Array(repeating: 0xFFFFFFFF, count: 1024 * 1024)
    }
    
    func setRenderPipeline(_ pipeline: RenderPipeline) throws {
        // Set pipeline state for software rendering
    }
    
    func setVertexBuffer(_ buffer: RenderBuffer, at index: UInt32) throws {
        // Bind vertex buffer
    }
    
    func setFragmentBuffer(_ buffer: RenderBuffer, at index: UInt32) throws {
        // Bind fragment buffer
    }
    
    func setFragmentTexture(_ texture: RenderTexture, at index: UInt32) throws {
        // Bind texture for sampling
    }
    
    func drawPrimitives(
        type: PrimitiveType,
        vertexStart: UInt32,
        vertexCount: UInt32
    ) throws {
        let width = Int(sqrt(Double(self.frameBuffer.count)))
        let height = width
        
        switch type {
        case .point:
            for i in vertexStart..<vertexStart + vertexCount {
                let x = Int(i) % width
                let y = Int(i) / width
                if x >= 0 && x < width && y >= 0 && y < height {
                    self.frameBuffer[y * width + x] = 0xFF0000FF // Red point
                }
            }
            
        case .triangle:
            if vertexCount >= 3 {
                // Simple triangle rasterization
                let v0 = (x: width / 2, y: height / 4)
                let v1 = (x: width / 4, y: 3 * height / 4)
                let v2 = (x: 3 * width / 4, y: 3 * height / 4)
                rasterizeTriangle(v0: v0, v1: v1, v2: v2, frameBuffer: &self.frameBuffer, width: width, height: height)
            }
            
        case .line:
            if vertexCount >= 2 {
                for i in stride(from: 0, to: vertexCount - 1, by: 2) {
                    let x0 = Int(vertexStart + i) % width
                    let y0 = Int(vertexStart + i) / width
                    let x1 = Int(vertexStart + i + 1) % width
                    let y1 = Int(vertexStart + i + 1) / width
                    drawLine(x0: x0, y0: y0, x1: x1, y1: y1, frameBuffer: &self.frameBuffer, width: width, height: height)
                }
            }
            
        default:
            // Unsupported primitive type
            break
        }
    }
    
    func drawIndexedPrimitives(
        type: PrimitiveType,
        indexCount: UInt32,
        indexBuffer: RenderBuffer,
        indexBufferOffset: UInt64
    ) throws {
        // Indexed software rasterization
    }
    
    func endRenderPass() throws {
        // Finalize render pass
    }
    
    // MARK: - Software Rasterization Helpers
    
    private func rasterizeTriangle(
        v0: (x: Int, y: Int),
        v1: (x: Int, y: Int),
        v2: (x: Int, y: Int),
        frameBuffer: inout [UInt32],
        width: Int,
        height: Int
    ) {
        // Simple triangle rasterization using scanlines
        let color: UInt32 = 0xFF00FF00 // Green triangle
        
        // Find bounding box
        let minX = max(0, min(v0.x, v1.x, v2.x))
        let maxX = min(width - 1, max(v0.x, v1.x, v2.x))
        let minY = max(0, min(v0.y, v1.y, v2.y))
        let maxY = min(height - 1, max(v0.y, v1.y, v2.y))
        
        // Scan through bounding box
        for y in minY...maxY {
            for x in minX...maxX {
                if pointInTriangle(x, y, v0: v0, v1: v1, v2: v2) {
                    let index = y * width + x
                    if index >= 0 && index < frameBuffer.count {
                        frameBuffer[index] = color
                    }
                }
            }
        }
    }
    
    private func pointInTriangle(
        _ x: Int, _ y: Int,
        v0: (x: Int, y: Int),
        v1: (x: Int, y: Int),
        v2: (x: Int, y: Int)
    ) -> Bool {
        // Barycentric coordinate test
        let denom = (v1.y - v2.y) * (v0.x - v2.x) + (v2.x - v1.x) * (v0.y - v2.y)
        if denom == 0 { return false }
        
        let a = ((v1.y - v2.y) * (x - v2.x) + (v2.x - v1.x) * (y - v2.y)) / denom
        let b = ((v2.y - v0.y) * (x - v2.x) + (v0.x - v2.x) * (y - v2.y)) / denom
        let c = 1 - a - b
        
        return a >= 0 && b >= 0 && c >= 0
    }
    
    private func drawLine(
        x0: Int, y0: Int,
        x1: Int, y1: Int,
        frameBuffer: inout [UInt32],
        width: Int,
        height: Int
    ) {
        // Bresenham's line algorithm
        let color: UInt32 = 0xFF00FFFF // Cyan line
        
        let dx = Swift.abs(x1 - x0)
        let dy = -Swift.abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        var x = x0
        var y = y0
        
        while true {
            if x >= 0 && x < width && y >= 0 && y < height {
                let index = y * width + x
                if index >= 0 && index < frameBuffer.count {
                    frameBuffer[index] = color
                }
            }
            
            if x == x1 && y == y1 { break }
            
            let e2 = 2 * err
            if e2 >= dy {
                err += dy
                x += sx
            }
            if e2 <= dx {
                err += dx
                y += sy
            }
        }
    }
}
