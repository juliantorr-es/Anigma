import Foundation
import Metal
import MetalKit

public final class MetalRenderAdapter: @unchecked Sendable {
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState?
    
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw RenderError.initializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        
        // Pipeline state will be set up when we have shaders
        self.pipelineState = nil
    }
    
    public func execute(planBytes: Data, renderPass: MTLRenderPassDescriptor, drawable: CAMetalDrawable) throws {
        // Stub implementation - when render plan format is fully defined,
        // this will parse planBytes and issue draw calls
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            return
        }
        
        // Clear only for now
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

public enum RenderError: Error {
    case initializationFailed
}
