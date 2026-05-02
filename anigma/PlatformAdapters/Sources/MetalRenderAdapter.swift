import MetalKit
import Combine

@MainActor
public final class MetalRenderAdapter: ObservableObject {
    public static let shared = MetalRenderAdapter()
    
    @Published public var isRendering: Bool = false
    @Published public var frameTime: TimeInterval = 0
    @Published public var drawCallCount: Int = 0
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineStateCache: [PipelineKey: MTLRenderPipelineState]
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    
    private var currentPlan: RenderPlan?
    private var currentViewport: Viewport?
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        self.commandQueue = commandQueue
        
        self.pipelineStateCache = [:]
        
        setupBuffers()
    }
    
    private func setupBuffers() {
        let vertexBufferSize = 256 * 1024
        vertexBuffer = device.makeBuffer(
            length: vertexBufferSize,
            options: .storageModeShared
        )
        
        let uniformBufferSize = 256 * 1024
        uniformBuffer = device.makeBuffer(
            length: uniformBufferSize,
            options: .storageModeShared
        )
    }
    
    public func execute(plan: RenderPlan, viewport: Viewport) async {
        isRendering = true
        let startTime = CACurrentMediaTime()
        
        currentPlan = plan
        currentViewport = viewport
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let descriptor = MTLRenderPassDescriptor.default,
              let drawable = view?.currentDrawable,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            isRendering = false
            return
        }
        
        for op in plan.ops {
            encodeDrawOp(op, encoder: renderEncoder, viewport: viewport)
            drawCallCount += 1
        }
        
        renderEncoder.endEncoding()
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            isRendering = false
            return
        }
        
        blitEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        frameTime = CACurrentMediaTime() - startTime
        isRendering = false
    }
    
    private func encodeDrawOp(_ op: DrawOp, encoder: MTLRenderCommandEncoder, viewport: Viewport) {
        switch op.type {
        case .clear:
            encoder.setClearColor(MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1))
            
        case .rect:
            encodeRect(op, encoder: encoder, viewport: viewport)
            
        case .path:
            encodePath(op, encoder: encoder, viewport: viewport)
            
        case .text:
            encodeText(op, encoder: encoder, viewport: viewport)
            
        case .image:
            encodeImage(op, encoder: encoder, viewport: viewport)
            
        case .clip, .layer:
            break
        }
    }
    
    private func encodeRect(_ op: DrawOp, encoder: MTLRenderCommandEncoder, viewport: Viewport) {
        guard let pipelineState = getPipelineState(for: op) else { return }
        
        var uniforms = Uniforms(
            transform: buildTransform(op.transform, viewport: viewport),
            color: SIMD4<Float>(1, 0, 0, 1)
        )
        
        memcpy(uniformBuffer?.contents(), &uniforms, MemoryLayout<Uniforms>.size)
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        let vertices = buildRectVertices(op.clip, viewport: viewport)
        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Vertex>.size, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    private func encodePath(_ op: DrawOp, encoder: MTLRenderCommandEncoder, viewport: Viewport) {
        guard let pipelineState = getPipelineState(for: op) else { return }
        
        var uniforms = Uniforms(
            transform: buildTransform(op.transform, viewport: viewport),
            color: SIMD4<Float>(0, 0, 1, 1)
        )
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    private func encodeText(_ op: DrawOp, encoder: MTLRenderCommandEncoder, viewport: Viewport) {
        guard let pipelineState = getPipelineState(for: op) else { return }
        
        var uniforms = Uniforms(
            transform: buildTransform(op.transform, viewport: viewport),
            color: SIMD4<Float>(0, 0, 0, 1)
        )
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 2)
    }
    
    private func encodeImage(_ op: DrawOp, encoder: MTLRenderCommandEncoder, viewport: Viewport) {
        guard let pipelineState = getPipelineState(for: op) else { return }
        
        var uniforms = Uniforms(
            transform: buildTransform(op.transform, viewport: viewport),
            color: SIMD4<Float>(1, 1, 1, 1)
        )
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 2)
    }
    
    private func getPipelineState(for op: DrawOp) -> MTLRenderPipelineState? {
        let key = PipelineKey(opType: op.type, isTextured: op.material.resourceType != 0)
        
        if let existing = pipelineStateCache[key] {
            return existing
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            pipelineStateCache[key] = pipelineState
            return pipelineState
        } catch {
            print("Failed to create pipeline state: \(error)")
            return nil
        }
    }
    
    private var library: MTLLibrary? {
        device.makeDefaultLibrary()
    }
    
    private var view: MTKView?
    
    private func buildTransform(_ transform: Transform, viewport: Viewport) -> simd_float4x4 {
        let scaleX = Float(viewport.scale)
        let scaleY = Float(viewport.scale)
        
        return simd_float4x4([
            simd_float4(Float(transform.m[0][0]) / 256.0 * scaleX, 0, 0, 0),
            simd_float4(0, Float(transform.m[1][1]) / 256.0 * scaleY, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(0, 0, 0, 1)
        ])
    }
    
    private func buildRectVertices(_ rect: Rect, viewport: Viewport) -> [Vertex] {
        let x0 = Float(rect.x) / 256.0 * Float(viewport.scale)
        let y0 = Float(rect.y) / 256.0 * Float(viewport.scale)
        let x1 = (Float(rect.x) + Float(rect.width)) / 256.0 * Float(viewport.scale)
        let y1 = (Float(rect.y) + Float(rect.height)) / 256.0 * Float(viewport.scale)
        
        return [
            Vertex(position: SIMD2<Float>(x0, y0), uv: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD2<Float>(x1, y0), uv: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD2<Float>(x0, y1), uv: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD2<Float>(x1, y0), uv: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD2<Float>(x1, y1), uv: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD2<Float>(x0, y1), uv: SIMD2<Float>(0, 0)),
        ]
    }
}

private struct PipelineKey: Hashable {
    let opType: DrawOpType
    let isTextured: Bool
}

private struct Uniforms {
    var transform: simd_float4x4
    var color: SIMD4<Float>
}

private struct Vertex {
    var position: SIMD2<Float>
    var uv: SIMD2<Float>
}

import SwiftUI

public struct MetalCanvasView: UIViewRepresentable {
    @ObservedObject public var adapter: MetalRenderAdapter
    
    public init(adapter: MetalRenderAdapter = .shared) {
        self.adapter = adapter
    }
    
    public func makeUIView(context: Context) -> MTKView {
        let view = MTKView(device: adapter.device, frame: .zero)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        view.delegate = context.coordinator
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.preferredFramesPerSecond = 120
        
        return view
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.view = uiView
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(adapter: adapter)
    }
    
    public class Coordinator: NSObject, MTKViewDelegate {
        let adapter: MetalRenderAdapter
        weak var view: MTKView?
        
        init(adapter: MetalRenderAdapter) {
            self.adapter = adapter
        }
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }
        
        public func draw(in view: MTKView) {
            Task { @MainActor in
                if let plan = adapter.currentPlan, let viewport = adapter.currentViewport {
                    await adapter.execute(plan: plan, viewport: viewport)
                }
            }
        }
    }
}
