//
//  Rasterizer.swift
//  TextRenderKit
//
//  Created by Anigma on 2026-04-09
//  Copyright © 2026 Anigma. All rights reserved.
//

import Foundation
import Metal
import CoreGraphics
import RendererKit
import SaturationKit

/// Rasterizer module for TextRenderKit
/// Handles glyph to pixel conversion (rasterization)
/// Supports both CPU and GPU rasterization paths
public final class Rasterizer: Sendable {
    
    // MARK: - Types
    
    public enum RasterizationMode: String, CaseIterable, Sendable {
        case cpu
        case gpu
        case hybrid
    }
    
    public enum RasterizationError: Error, Sendable {
        case invalidGlyph
        case invalidFont
        case deviceNotAvailable
        case textureCreationFailed
        case bufferCreationFailed
        case unsupportedFormat
        case renderingFailed
        case timeout
    }
    
    // MARK: - Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let mode: RasterizationMode
    
    // CPU rasterization cache
    private var cpuCache: [RasterizerGlyphCacheKey: CGImage] = [:]
    private let maxCPUCacheSize = 256
    private let cpuCacheLock = NSLock()
    
    // GPU rasterization cache
    private var gpuCache: [RasterizerGlyphCacheKey: MTLTexture] = [:]
    private let maxGPUCacheSize = 128
    private let gpuCacheLock = NSLock()
    
    // Performance metrics
    private var rasterizationCount: Int = 0
    private var cpuRasterizationTime: Double = 0
    private var gpuRasterizationTime: Double = 0
    
    // MARK: - Initialization
    
    public init(device: MTLDevice, mode: RasterizationMode = .hybrid) {
        self.device = device
        self.mode = mode
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = commandQueue
        
        ConsoleLogger.log(".rasterizer.init", "Rasterizer initialized with mode: \(mode.rawValue)")
    }
    
    // MARK: - Public API
    
    /// Rasterize a glyph to a texture
    /// - Parameters:
    ///   - glyph: The glyph to rasterize
    ///   - font: The font face containing the glyph
    ///   - size: The target size for rasterization
    ///   - scale: The scale factor
    /// - Returns: MTLTexture containing the rasterized glyph
    public func rasterizeGlyph(
        _ glyph: Glyph,
        font: FontFace,
        size: CGSize,
        scale: CGFloat = 1.0
    ) throws -> MTLTexture {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            rasterizationCount += 1
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            if mode == .cpu || mode == .hybrid {
                cpuRasterizationTime += duration
            } else {
                gpuRasterizationTime += duration
            }
        }
        
        let cacheKey = RasterizerGlyphCacheKey(
            glyphID: glyph.id,
            fontKey: font.key,
            size: size,
            scale: scale
        )
        
        // Try GPU cache first
        if let cachedTexture = getCachedGPUTexture(for: cacheKey) {
            return cachedTexture
        }
        
        // Try CPU cache if available
        if let cachedImage = getCachedCPUImage(for: cacheKey) {
            let texture = try createTexture(from: cachedImage)
            cacheGPUTexture(texture, for: cacheKey)
            return texture
        }
        
        // Rasterize based on mode
        let texture: MTLTexture
        switch mode {
        case .cpu:
            let image = try rasterizeGlyphOnCPU(glyph, font: font, size: size, scale: scale)
            texture = try createTexture(from: image)
            cacheCPUImage(image, for: cacheKey)
            cacheGPUTexture(texture, for: cacheKey)
            
        case .gpu:
            texture = try rasterizeGlyphOnGPU(glyph, font: font, size: size, scale: scale)
            cacheGPUTexture(texture, for: cacheKey)
            
        case .hybrid:
            // Use GPU for larger glyphs, CPU for smaller ones
            let area = size.width * size.height
            if area > 1024 { // 32x32 threshold
                texture = try rasterizeGlyphOnGPU(glyph, font: font, size: size, scale: scale)
            } else {
                let image = try rasterizeGlyphOnCPU(glyph, font: font, size: size, scale: scale)
                texture = try createTexture(from: image)
                cacheCPUImage(image, for: cacheKey)
            }
            cacheGPUTexture(texture, for: cacheKey)
        }
        
        return texture
    }
    
    /// Clear all caches
    public func clearCaches() {
        cpuCacheLock.lock()
        cpuCache.removeAll()
        cpuCacheLock.unlock()
        
        gpuCacheLock.lock()
        gpuCache.removeAll()
        gpuCacheLock.unlock()
        
        ConsoleLogger.log(".rasterizer.cache.clear", "All rasterization caches cleared")
    }
    
    /// Optimize memory usage for hardware saturation
    public func optimizeMemoryForSaturation() {
        // Apply saturation-aware cache limits
        optimizeCPUCacheForSaturation()
        optimizeGPUCacheForSaturation()
        
        ConsoleLogger.log(".rasterizer.memory.optimize", "Rasterizer memory optimized for saturation")
    }
    
    /// Optimize CPU cache for hardware saturation
    private func optimizeCPUCacheForSaturation() {
        cpuCacheLock.lock()
        defer { cpuCacheLock.unlock() }
        
        // Saturation target: balance between performance and memory usage
        let saturationTarget = min(128, maxCPUCacheSize)
        
        if cpuCache.count > saturationTarget {
            let keysToRemove = Array(cpuCache.keys.prefix(cpuCache.count - saturationTarget))
            for key in keysToRemove {
                cpuCache.removeValue(forKey: key)
            }
            ConsoleLogger.log(".rasterizer.cache.cpu", "CPU cache optimized to \(cpuCache.count) entries")
        }
    }
    
    /// Optimize GPU cache for hardware saturation
    private func optimizeGPUCacheForSaturation() {
        gpuCacheLock.lock()
        defer { gpuCacheLock.unlock() }
        
        // Saturation target: balance between performance and memory usage
        let saturationTarget = min(64, maxGPUCacheSize)
        
        if gpuCache.count > saturationTarget {
            let keysToRemove = Array(gpuCache.keys.prefix(gpuCache.count - saturationTarget))
            for key in keysToRemove {
                gpuCache.removeValue(forKey: key)
            }
            ConsoleLogger.log(".rasterizer.cache.gpu", "GPU cache optimized to \(gpuCache.count) entries")
        }
    }
    
    /// Get performance metrics
    public func getPerformanceMetrics() -> RasterizationMetrics {
        return RasterizationMetrics(
            totalRasterizations: rasterizationCount,
            cpuTime: cpuRasterizationTime,
            gpuTime: gpuRasterizationTime,
            cpuCacheSize: cpuCache.count,
            gpuCacheSize: gpuCache.count,
            mode: mode
        )
    }
    
    // MARK: - CPU Rasterization
    
    private func rasterizeGlyphOnCPU(
        _ glyph: Glyph,
        font: FontFace,
        size: CGSize,
        scale: CGFloat
    ) throws -> CGImage {
        // Validate inputs
        guard glyph.isValid else {
            throw RasterizationError.invalidGlyph
        }
        
        // Create bitmap context
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        
        guard width > 0, height > 0 else {
            throw RasterizationError.invalidGlyph
        }
        
        let bitsPerComponent = 8
        let bytesPerRow = width
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw RasterizationError.renderingFailed
        }
        
        // Set up context for drawing
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.setStrokeColor(CGColor(gray: 0, alpha: 1))
        context.setLineWidth(1)
        
        // Draw the glyph path
        if let cgPath = glyph.path {
            context.addPath(cgPath)
            context.fillPath()
        } else {
            // Fallback: draw a simple rectangle for missing glyphs
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            context.fill(rect)
        }
        
        // Create CGImage from context
        guard let image = context.makeImage() else {
            throw RasterizationError.renderingFailed
        }
        
        return image
    }
    
    // MARK: - GPU Rasterization
    
    private func rasterizeGlyphOnGPU(
        _ glyph: Glyph,
        font: FontFace,
        size: CGSize,
        scale: CGFloat
    ) throws -> MTLTexture {
        // Validate inputs
        guard glyph.isValid else {
            throw RasterizationError.invalidGlyph
        }
        
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        
        guard width > 0, height > 0 else {
            throw RasterizationError.invalidGlyph
        }
        
        // Create texture descriptor
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .renderTarget]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw RasterizationError.textureCreationFailed
        }
        
        // Create render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        let renderPassColorAttachment = renderPassDescriptor.colorAttachments[0]!
        renderPassColorAttachment.texture = texture
        renderPassColorAttachment.loadAction = .clear
        renderPassColorAttachment.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassColorAttachment.storeAction = .store
        
        // Create command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw RasterizationError.renderingFailed
        }
        
        // Set up rendering pipeline (simplified - in production would use proper pipeline)
        renderEncoder.setRenderPipelineState(try getDefaultRasterizationPipelineState())
        
        // Draw the glyph (simplified - in production would use proper vertex data)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        // End encoding and commit
        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        if commandBuffer.status == .error {
            throw RasterizationError.renderingFailed
        }
        
        return texture
    }
    
    // MARK: - Texture Creation
    
    private func createTexture(from image: CGImage) throws -> MTLTexture {
        let width = image.width
        let height = image.height
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw RasterizationError.textureCreationFailed
        }
        
        // Get image data
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw RasterizationError.textureCreationFailed
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else {
            throw RasterizationError.textureCreationFailed
        }
        
        // Copy data to texture
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: width)
        
        return texture
    }
    
    // MARK: - Pipeline State Management
    
    private var rasterizationPipelineState: MTLRenderPipelineState?
    private let pipelineStateLock = NSLock()
    
    private func getDefaultRasterizationPipelineState() throws -> MTLRenderPipelineState {
        pipelineStateLock.lock()
        defer { pipelineStateLock.unlock() }
        
        if let pipelineState = rasterizationPipelineState {
            return pipelineState
        }
        
        // Create a simple pipeline state for rasterization
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .r8Unorm
        pipelineDescriptor.vertexFunction = try getDefaultVertexFunction()
        pipelineDescriptor.fragmentFunction = try getDefaultFragmentFunction()
        
        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
            throw RasterizationError.renderingFailed
        }
        
        rasterizationPipelineState = pipelineState
        return pipelineState
    }
    
    private func getDefaultVertexFunction() throws -> MTLFunction {
        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "rasterizationVertexShader") else {
            throw RasterizationError.renderingFailed
        }
        return vertexFunction
    }
    
    private func getDefaultFragmentFunction() throws -> MTLFunction {
        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let fragmentFunction = library.makeFunction(name: "rasterizationFragmentShader") else {
            throw RasterizationError.renderingFailed
        }
        return fragmentFunction
    }
    
    // MARK: - Cache Management
    
    private func getCachedCPUImage(for key: RasterizerGlyphCacheKey) -> CGImage? {
        cpuCacheLock.lock()
        defer { cpuCacheLock.unlock() }
        return cpuCache[key]
    }
    
    private func cacheCPUImage(_ image: CGImage, for key: RasterizerGlyphCacheKey) {
        cpuCacheLock.lock()
        defer { cpuCacheLock.unlock() }
        
        // Clean cache if needed
        if cpuCache.count >= maxCPUCacheSize {
            let keysToRemove = Array(cpuCache.keys.prefix(cpuCache.count / 2))
            for key in keysToRemove {
                cpuCache.removeValue(forKey: key)
            }
        }
        
        cpuCache[key] = image
    }
    
    private func getCachedGPUTexture(for key: RasterizerGlyphCacheKey) -> MTLTexture? {
        gpuCacheLock.lock()
        defer { gpuCacheLock.unlock() }
        return gpuCache[key]
    }
    
    private func cacheGPUTexture(_ texture: MTLTexture, for key: RasterizerGlyphCacheKey) {
        gpuCacheLock.lock()
        defer { gpuCacheLock.unlock() }
        
        // Clean cache if needed
        if gpuCache.count >= maxGPUCacheSize {
            let keysToRemove = Array(gpuCache.keys.prefix(gpuCache.count / 2))
            for key in keysToRemove {
                gpuCache.removeValue(forKey: key)
            }
        }
        
        gpuCache[key] = texture
    }
}

// MARK: - Supporting Types

public struct RasterizerGlyphCacheKey: Hashable, Sendable {
    let glyphID: UInt32
    let fontKey: String
    let size: CGSize
    let scale: CGFloat
    
    public init(glyphID: UInt32, fontKey: String, size: CGSize, scale: CGFloat) {
        self.glyphID = glyphID
        self.fontKey = fontKey
        self.size = size
        self.scale = scale
    }
}

public struct RasterizationMetrics: Sendable {
    public let totalRasterizations: Int
    public let cpuTime: Double
    public let gpuTime: Double
    public let cpuCacheSize: Int
    public let gpuCacheSize: Int
    public let mode: RasterizationMode
    
    public init(
        totalRasterizations: Int,
        cpuTime: Double,
        gpuTime: Double,
        cpuCacheSize: Int,
        gpuCacheSize: Int,
        mode: RasterizationMode
    ) {
        self.totalRasterizations = totalRasterizations
        self.cpuTime = cpuTime
        self.gpuTime = gpuTime
        self.cpuCacheSize = cpuCacheSize
        self.gpuCacheSize = gpuCacheSize
        self.mode = mode
    }
}

// MARK: - Extensions

extension Glyph {
    var isValid: Bool {
        return id != 0 && bounds.width > 0 && bounds.height > 0
    }
}

extension FontFace {
    var key: String {
        return "\(familyName)-\(style)-\(weight)"
    }
}