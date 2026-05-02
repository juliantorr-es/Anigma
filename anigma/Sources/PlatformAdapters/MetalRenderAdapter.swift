import Foundation
import Metal
import MetalKit
import simd

public struct Vertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
    var color: SIMD4<Float>
}

public final class MetalRenderAdapter: @unchecked Sendable {
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private let samplerState: MTLSamplerState?
    
    public convenience init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderError.initializationFailed
        }
        try self.init(device: device)
    }
    
    public init(device: MTLDevice) throws {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderError.initializationFailed
        }
        self.commandQueue = commandQueue
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        self.samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
        
        do {
            try setupPipeline()
        } catch {
            throw RenderError.pipelineSetupFailed(error)
        }
    }
    
    public func execute(planBytes: Data, renderPass: MTLRenderPassDescriptor, drawable: CAMetalDrawable) throws {
        let viewportSize = CGSize(width: drawable.texture.width, height: drawable.texture.height)
        execute(
            renderPlanData: planBytes,
            renderPassDescriptor: renderPass,
            drawable: drawable,
            viewportSize: viewportSize,
            textures: []
        )
    }
    
    public func execute(renderPlanData: Data,
                        renderPassDescriptor: MTLRenderPassDescriptor,
                        drawable: MTLDrawable,
                        viewportSize: CGSize,
                        textures: [MTLTexture]) {
        guard let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        let projectionMatrix = matrix_ortho_left_hand(0, Float(viewportSize.width), Float(viewportSize.height), 0, -1, 1)
        renderEncoder.setVertexBytes([projectionMatrix], length: MemoryLayout<simd_float4x4>.size, index: 1)
        
        let primitiveSize = 40
        let primitiveCount = renderPlanData.count / primitiveSize
        
        renderPlanData.withUnsafeBytes { ptr in
            for i in 0..<primitiveCount {
                let offset = i * primitiveSize
                
                let type = ptr.load(fromByteOffset: offset, as: Int32.self)
                
                let x = ptr.load(fromByteOffset: offset + 4, as: Float.self)
                let y = ptr.load(fromByteOffset: offset + 8, as: Float.self)
                let w = ptr.load(fromByteOffset: offset + 12, as: Float.self)
                let h = ptr.load(fromByteOffset: offset + 16, as: Float.self)
                
                let r = ptr.load(fromByteOffset: offset + 20, as: Float.self)
                let g = ptr.load(fromByteOffset: offset + 24, as: Float.self)
                let b = ptr.load(fromByteOffset: offset + 28, as: Float.self)
                let a = ptr.load(fromByteOffset: offset + 32, as: Float.self)
                
                let textureIndex = ptr.load(fromByteOffset: offset + 36, as: Int32.self)
                
                drawPrimitive(
                    type: type,
                    rect: SIMD4<Float>(x, y, w, h),
                    color: SIMD4<Float>(r, g, b, a),
                    textureIndex: textureIndex,
                    encoder: renderEncoder,
                    textures: textures
                )
            }
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func setupPipeline() throws {
        let library: MTLLibrary
        if let lib = try? device.makeDefaultLibrary() {
            library = lib
        } else {
            let bundle = Bundle(for: MetalRenderAdapter.self)
            library = try device.makeDefaultLibrary(bundle: bundle)
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func drawPrimitive(type: Int32,
                               rect: SIMD4<Float>,
                               color: SIMD4<Float>,
                               textureIndex: Int32,
                               encoder: MTLRenderCommandEncoder,
                               textures: [MTLTexture]) {
        let x = rect.x
        let y = rect.y
        let w = rect.z
        let h = rect.w
        
        let vertices: [Vertex] = [
            Vertex(position: [x, y], texCoord: [0, 0], color: color),
            Vertex(position: [x + w, y], texCoord: [1, 0], color: color),
            Vertex(position: [x, y + h], texCoord: [0, 1], color: color),
            Vertex(position: [x + w, y], texCoord: [1, 0], color: color),
            Vertex(position: [x + w, y + h], texCoord: [1, 1], color: color),
            Vertex(position: [x, y + h], texCoord: [0, 1], color: color)
        ]
        
        encoder.setVertexBytes(vertices, length: MemoryLayout<Vertex>.stride * vertices.count, index: 0)
        
        var hasTexture = false
        if type == 2 && textureIndex >= 0 && textureIndex < textures.count {
            encoder.setFragmentTexture(textures[Int(textureIndex)], index: 0)
            hasTexture = true
        }
        
        encoder.setFragmentBytes(&hasTexture, length: MemoryLayout<Bool>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}

public enum RenderError: Error {
    case initializationFailed
    case pipelineSetupFailed(Error)
}

private func matrix_ortho_left_hand(_ left: Float, _ right: Float, _ bottom: Float, _ top: Float, _ near: Float, _ far: Float) -> simd_float4x4 {
    let rsl = right - left
    let tsb = top - bottom
    let fsn = far - near

    let col1 = SIMD4<Float>(2.0 / rsl, 0, 0, 0)
    let col2 = SIMD4<Float>(0, 2.0 / tsb, 0, 0)
    let col3 = SIMD4<Float>(0, 0, 1.0 / fsn, 0)
    let col4 = SIMD4<Float>(-(right + left) / rsl, -(top + bottom) / tsb, -near / fsn, 1.0)
    
    return simd_float4x4(col1, col2, col3, col4)
}
