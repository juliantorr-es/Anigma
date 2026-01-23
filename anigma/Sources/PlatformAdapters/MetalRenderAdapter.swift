import Foundation
import Metal
import MetalKit
import RuntimeOrchestrator
import AnigmaNativeShims

public final class MetalRenderAdapter: @unchecked Sendable {
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw RenderError.initializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        
        // Setup a simple pipeline for rectangles/quads
        let library = device.makeDefaultLibrary()
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertex_main")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragment_main")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    public func execute(planBytes: Data, renderPass: MTLRenderPassDescriptor, drawable: CAMetalDrawable) throws {
        let view = RenderPlanView(planBytes)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        
        view.withUnsafePlan { header in
            let base = planBytes.withUnsafeBytes { $0.baseAddress! }.assumingMemoryBound(to: UInt8.self)
            
            let ops = UnsafeBufferPointer(
                start: base.advanced(by: Int(header.pointee.ops_offset)).assumingMemoryBound(to: anigma_draw_op_t.self),
                count: Int(header.pointee.op_count)
            )
            
            let transforms = UnsafeBufferPointer(
                start: base.advanced(by: Int(header.pointee.transforms_offset)).assumingMemoryBound(to: anigma_affine_i32_t.self),
                count: Int(header.pointee.transform_count)
            )
            
            // Loop through ops and draw
            for op in ops {
                switch anigma_draw_op_type_t(rawValue: op.type) {
                case ANIGMA_OP_RECT:
                    let transform = transforms[Int(op.transform_index)]
                    // drawRect(encoder, transform, op.paint_index)
                    break
                default:
                    break
                }
            }
        }
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

public enum RenderError: Error {
    case initializationFailed
}
