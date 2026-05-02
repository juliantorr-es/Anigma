import Foundation
import Metal
import RendererKit

// MARK: - Text Render Optimizer

/// Performance optimization system for text rendering
public final class TextRenderOptimizer: Sendable {
    
    // Configuration
    private let config: TextRenderConfiguration
    private let device: MTLDevice
    
    // Performance metrics
    private var frameHistory: [FrameMetrics] = []
    private let maxFrameHistory = 60 // 1 second at 60fps
    
    // Optimization state
    private var currentOptimizationLevel: OptimizationLevel = .balanced
    private var atlasBatchingEnabled = true
    private var shaderOptimizationEnabled = true
    private var dynamicResolutionEnabled = false
    
    // Glyph caching
    private var glyphCache: [GlyphCacheKey: CachedGlyph] = [:]
    private let maxGlyphCacheSize = 4096
    private var glyphCacheHits = 0
    private var glyphCacheMisses = 0
    
    // Pipeline caching
    private var pipelineCache: [PipelineCacheKey: MTLRenderPipelineState] = [:]
    private let maxPipelineCacheSize = 64
    
    // MARK: - Initialization
    
    public init(device: MTLDevice, config: TextRenderConfiguration = .default) {
        self.device = device
        self.config = config
        
        ConsoleLogger.log(".optimizer.init", "TextRenderOptimizer initialized")
    }
    
    // MARK: - Performance Monitoring
    
    /// Record frame metrics for analysis
    public func recordFrame(_ metrics: FrameMetrics) {
        frameHistory.append(metrics)
        
        if frameHistory.count > maxFrameHistory {
            frameHistory.removeFirst()
        }
        
        // Analyze performance and adjust settings
        analyzePerformance()
    }
    
    /// Get current performance summary
    public func getPerformanceSummary() -> PerformanceSummary {
        guard !frameHistory.isEmpty else {
            return PerformanceSummary(
                averageFrameTime: 0,
                frameTimeStdDev: 0,
                framesWithinBudget: 0,
                budgetCompliance: 0,
                optimizationLevel: currentOptimizationLevel
            )
        }
        
        let totalFrameTime = frameHistory.reduce(0) { $0 + $1.frameTime.components.attoseconds }
        let averageFrameTime = Duration(attoseconds: totalFrameTime / Int64(frameHistory.count))
        
        let withinBudget = frameHistory.filter { $0.withinBudget }.count
        let compliance = Float(withinBudget) / Float(frameHistory.count)
        
        // Calculate standard deviation
        let meanAttoseconds = Double(totalFrameTime) / Double(frameHistory.count)
        let variance = frameHistory.reduce(0.0) { 
            $0 + pow(Double($1.frameTime.components.attoseconds) - meanAttoseconds, 2)
        } / Double(frameHistory.count)
        let stdDev = Duration(attoseconds: Int64(sqrt(variance)))
        
        return PerformanceSummary(
            averageFrameTime: averageFrameTime,
            frameTimeStdDev: stdDev,
            framesWithinBudget: withinBudget,
            budgetCompliance: compliance,
            optimizationLevel: currentOptimizationLevel,
            glyphCacheHitRate: calculateCacheHitRate()
        )
    }
    
    /// Analyze performance and adjust optimization settings
    private func analyzePerformance() {
        guard frameHistory.count >= 30 else { return } // Need enough data
        
        let summary = getPerformanceSummary()
        
        // Adjust optimization level based on performance
        if summary.budgetCompliance < 0.7 {
            // Missing budget frequently - reduce quality for performance
            setOptimizationLevel(.performance)
        } else if summary.budgetCompliance > 0.95 && summary.averageFrameTime < Duration.milliseconds(8) {
            // Plenty of headroom - increase quality
            setOptimizationLevel(.quality)
        } else {
            // Balanced mode
            setOptimizationLevel(.balanced)
        }
        
        ConsoleLogger.log(".optimizer.analysis", "Performance analysis: \(summary.budgetCompliance * 100)% within budget, level: \(currentOptimizationLevel)")
    }
    
    // MARK: - Optimization Levels
    
    private func setOptimizationLevel(_ level: OptimizationLevel) {
        guard currentOptimizationLevel != level else { return }
        
        currentOptimizationLevel = level
        
        switch level {
        case .performance:
            atlasBatchingEnabled = true
            shaderOptimizationEnabled = true
            dynamicResolutionEnabled = true
            
        case .balanced:
            atlasBatchingEnabled = true
            shaderOptimizationEnabled = true
            dynamicResolutionEnabled = false
            
        case .quality:
            atlasBatchingEnabled = false
            shaderOptimizationEnabled = false
            dynamicResolutionEnabled = false
        }
        
        ConsoleLogger.log(".optimizer.level", "Optimization level changed to: \(level)")
    }
    
    // MARK: - Glyph Caching
    
    /// Get or create cached glyph data
    public func getCachedGlyph(
        glyphId: UInt32,
        font: FontDescriptor,
        createIfMissing: Bool = true
    ) -> CachedGlyph? {
        let cacheKey = GlyphCacheKey(glyphId: glyphId, font: font)
        
        if let cached = glyphCache[cacheKey] {
            glyphCacheHits += 1
            return cached
        }
        
        glyphCacheMisses += 1
        
        // Clean cache if full
        if glyphCache.count >= maxGlyphCacheSize {
            cleanGlyphCache()
        }
        
        // Create new cached glyph if requested
        guard createIfMissing else { return nil }
        
        let newGlyph = CachedGlyph(
            glyphId: glyphId,
            font: font,
            uvRect: calculateUVRect(for: glyphId, font: font),
            metrics: calculateGlyphMetrics(for: glyphId, font: font)
        )
        
        glyphCache[cacheKey] = newGlyph
        return newGlyph
    }
    
    /// Clean glyph cache based on LRU or other strategy
    private func cleanGlyphCache() {
        // Simple strategy: remove first N entries
        let itemsToRemove = max(1, glyphCache.count / 4)
        let keysToRemove = Array(glyphCache.keys.prefix(itemsToRemove))
        
        for key in keysToRemove {
            glyphCache.removeValue(forKey: key)
        }
        
        ConsoleLogger.log(".optimizer.cache", "Cleaned glyph cache, removed \(keysToRemove.count) entries")
    }
    
    /// Calculate cache hit rate
    private func calculateCacheHitRate() -> Float {
        guard glyphCacheHits + glyphCacheMisses > 0 else { return 0 }
        return Float(glyphCacheHits) / Float(glyphCacheHits + glyphCacheMisses)
    }
    
    // MARK: - Pipeline Caching
    
    /// Get or create cached pipeline state
    public func getCachedPipeline(
        descriptor: RendererKit.RenderPipelineDescriptor,
        device: MTLDevice
    ) throws -> MTLRenderPipelineState {
        let cacheKey = PipelineCacheKey(descriptor: descriptor)
        
        if let cached = pipelineCache[cacheKey] {
            return cached
        }
        
        // Clean cache if full
        if pipelineCache.count >= maxPipelineCacheSize {
            cleanPipelineCache()
        }
        
        // Create new pipeline state
        let mtlDescriptor = MTLRenderPipelineDescriptor()
        configureMetalDescriptor(mtlDescriptor, from: descriptor)
        
        let pipelineState = try device.makeRenderPipelineState(descriptor: mtlDescriptor)
        pipelineCache[cacheKey] = pipelineState
        
        return pipelineState
    }
    
    /// Clean pipeline cache
    private func cleanPipelineCache() {
        let itemsToRemove = max(1, pipelineCache.count / 2)
        let keysToRemove = Array(pipelineCache.keys.prefix(itemsToRemove))
        
        for key in keysToRemove {
            pipelineCache.removeValue(forKey: key)
        }
        
        ConsoleLogger.log(".optimizer.pipeline", "Cleaned pipeline cache, removed \(keysToRemove.count) entries")
    }
    
    // MARK: - Atlas Batching
    
    /// Batch multiple text rendering operations into single draw calls
    public func createBatchedRenderCommands(
        shapedTexts: [ShapedTextResult],
        styles: [TextStyle],
        viewportSize: (width: UInt32, height: UInt32)
    ) throws -> BatchedRenderCommands {
        // Group by font to minimize texture switches
        var commandsByFont: [FontDescriptor: [BatchedGlyphCommand]] = [:]
        
        for (index, shapedText) in shapedTexts.enumerated() {
            guard index < styles.count else { break }
            let style = styles[index]
            
            for glyph in shapedText.glyphs {
                let command = BatchedGlyphCommand(
                    glyphId: glyph.glyphId,
                    position: glyph.position,
                    uv: calculateUVRect(for: glyph.glyphId, font: style.font),
                    color: style.color,
                    advance: glyph.advance
                )
                
                if commandsByFont[style.font] == nil {
                    commandsByFont[style.font] = [command]
                } else {
                    commandsByFont[style.font]?.append(command)
                }
            }
        }
        
        // Create vertex and index buffers for each font group
        var batchedCommands: [FontBatchedCommands] = []
        
        for (font, commands) in commandsByFont {
            let (vertexBuffer, indexBuffer) = try createBatchedBuffers(for: commands)
            
            batchedCommands.append(FontBatchedCommands(
                font: font,
                vertexBuffer: vertexBuffer,
                indexBuffer: indexBuffer,
                commandCount: commands.count
            ))
        }
        
        return BatchedRenderCommands(
            fontCommands: batchedCommands,
            totalGlyphCount: shapedTexts.reduce(0) { $0 + $1.glyphCount }
        )
    }
    
    /// Create vertex and index buffers for batched rendering
    private func createBatchedBuffers(for commands: [BatchedGlyphCommand]) throws -> (Data, Data) {
        var vertices: [TextVertex] = []
        var indices: [UInt16] = []
        var indexOffset: UInt16 = 0
        
        for command in commands {
            // Create quad (two triangles)
            let baseIndex = indexOffset
            
            // Triangle 1
            vertices.append(TextVertex(
                position: command.position,
                uv: command.uv,
                color: command.color
            ))
            
            vertices.append(TextVertex(
                position: command.position + SIMD2<Float>(command.advance.x, 0),
                uv: SIMD2<Float>(command.uv.x + 1.0, command.uv.y),
                color: command.color
            ))
            
            vertices.append(TextVertex(
                position: command.position + SIMD2<Float>(0, command.advance.y),
                uv: SIMD2<Float>(command.uv.x, command.uv.y + 1.0),
                color: command.color
            ))
            
            // Triangle 2
            vertices.append(TextVertex(
                position: command.position + SIMD2<Float>(0, command.advance.y),
                uv: SIMD2<Float>(command.uv.x, command.uv.y + 1.0),
                color: command.color
            ))
            
            vertices.append(TextVertex(
                position: command.position + SIMD2<Float>(command.advance.x, 0),
                uv: SIMD2<Float>(command.uv.x + 1.0, command.uv.y),
                color: command.color
            ))
            
            vertices.append(TextVertex(
                position: command.position + command.advance,
                uv: SIMD2<Float>(command.uv.x + 1.0, command.uv.y + 1.0),
                color: command.color
            ))
            
            // Indices for the quad
            indices.append(contentsOf: [
                baseIndex, baseIndex + 1, baseIndex + 2,
                baseIndex + 3, baseIndex + 4, baseIndex + 5
            ])
            
            indexOffset += 6
        }
        
        // Convert to Data
        var vertexData = Data()
        for vertex in vertices {
            vertexData.append(vertex.position.x)
            vertexData.append(vertex.position.y)
            vertexData.append(vertex.uv.x)
            vertexData.append(vertex.uv.y)
            vertexData.append(vertex.color.r)
            vertexData.append(vertex.color.g)
            vertexData.append(vertex.color.b)
            vertexData.append(vertex.color.a)
        }
        
        var indexData = Data()
        withUnsafeBytes(of: indices) { bufferPointer in
            indexData.append(contentsOf: bufferPointer)
        }
        
        return (vertexData, indexData)
    }
    
    // MARK: - Helper Methods
    
    private func configureMetalDescriptor(_ mtlDescriptor: MTLRenderPipelineDescriptor, from descriptor: RendererKit.RenderPipelineDescriptor) {
        // Vertex function
        if let vertexFunction = descriptor.vertexFunction {
            // In real implementation, we'd get the function from library
        }
        
        // Fragment function
        if let fragmentFunction = descriptor.fragmentFunction {
            // In real implementation, we'd get the function from library
        }
        
        // Color attachments
        if let firstFormat = descriptor.colorAttachmentFormats.first {
            mtlDescriptor.colorAttachments[0].pixelFormat = metalPixelFormat(from: firstFormat)
        }
        
        // Depth attachment
        if let depthFormat = descriptor.depthAttachmentFormat {
            mtlDescriptor.depthAttachmentPixelFormat = metalPixelFormat(from: depthFormat)
        }
    }
    
    private func metalPixelFormat(from format: RendererKit.TextureFormat) -> MTLPixelFormat {
        switch format {
        case .rgba8unorm: return .rgba8Unorm
        case .rgba16float: return .rgba16Float
        case .rgba32float: return .rgba32Float
        case .depth32float: return .depth32Float
        case .stencil8: return .stencil8
        case .custom(let name): 
            if name == "depth24Stencil8" { return .depth24Unorm_stencil8 }
            return .invalid
        }
    }
    
    private func calculateUVRect(for glyphId: UInt32, font: FontDescriptor) -> SIMD2<Float> {
        // In a real implementation, this would look up the actual UV coordinates
        // from the glyph atlas based on the glyph ID and font
        return SIMD2<Float>(0.0, 0.0) // Placeholder
    }
    
    private func calculateGlyphMetrics(for glyphId: UInt32, font: FontDescriptor) -> GlyphMetrics {
        // In a real implementation, this would return the actual metrics
        return GlyphMetrics.default
    }
    
    // MARK: - Dynamic Resolution (Placeholder)
    
    /// Calculate dynamic resolution scale based on performance
    public func calculateDynamicResolutionScale() -> Float {
        let summary = getPerformanceSummary()
        
        // If we're consistently within budget, we can use full resolution
        if summary.budgetCompliance > 0.95 {
            return 1.0
        }
        
        // If we're struggling, reduce resolution
        let scale = 1.0 - (0.95 - summary.budgetCompliance) * 2.0
        return max(0.7, min(1.0, scale))
    }
}

// MARK: - Supporting Types

/// Optimization level
public enum OptimizationLevel: String, Sendable, CaseIterable {
    case performance = "Performance"
    case balanced = "Balanced"
    case quality = "Quality"
}

/// Performance summary
public struct PerformanceSummary: Sendable {
    public let averageFrameTime: Duration
    public let frameTimeStdDev: Duration
    public let framesWithinBudget: Int
    public let budgetCompliance: Float
    public let optimizationLevel: OptimizationLevel
    public let glyphCacheHitRate: Float
    
    public init(
        averageFrameTime: Duration,
        frameTimeStdDev: Duration,
        framesWithinBudget: Int,
        budgetCompliance: Float,
        optimizationLevel: OptimizationLevel,
        glyphCacheHitRate: Float
    ) {
        self.averageFrameTime = averageFrameTime
        self.frameTimeStdDev = frameTimeStdDev
        self.framesWithinBudget = framesWithinBudget
        self.budgetCompliance = budgetCompliance
        self.optimizationLevel = optimizationLevel
        self.glyphCacheHitRate = glyphCacheHitRate
    }
}

/// Frame metrics
public struct FrameMetrics: Sendable {
    public let frameTime: Duration
    public let withinBudget: Bool
    public let glyphCount: Int
    public let drawCallCount: Int
    public let timestamp: Date
    
    public init(
        frameTime: Duration,
        withinBudget: Bool,
        glyphCount: Int,
        drawCallCount: Int,
        timestamp: Date = Date()
    ) {
        self.frameTime = frameTime
        self.withinBudget = withinBudget
        self.glyphCount = glyphCount
        self.drawCallCount = drawCallCount
        self.timestamp = timestamp
    }
}

/// Glyph cache key
private struct GlyphCacheKey: Hashable, Sendable {
    let glyphId: UInt32
    let font: FontDescriptor
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(glyphId)
        hasher.combine(font)
    }
}

/// Cached glyph data
public struct CachedGlyph: Sendable {
    public let glyphId: UInt32
    public let font: FontDescriptor
    public let uvRect: SIMD2<Float> // Top-left UV coordinate
    public let metrics: GlyphMetrics
    
    public init(glyphId: UInt32, font: FontDescriptor, uvRect: SIMD2<Float>, metrics: GlyphMetrics) {
        self.glyphId = glyphId
        self.font = font
        self.uvRect = uvRect
        self.metrics = metrics
    }
}

/// Pipeline cache key
private struct PipelineCacheKey: Hashable, Sendable {
    let vertexFunction: String
    let fragmentFunction: String?
    let colorFormat: RendererKit.TextureFormat
    
    init(descriptor: RendererKit.RenderPipelineDescriptor) {
        self.vertexFunction = descriptor.vertexFunction
        self.fragmentFunction = descriptor.fragmentFunction
        self.colorFormat = descriptor.colorAttachmentFormats[0]
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(vertexFunction)
        hasher.combine(fragmentFunction)
        hasher.combine(colorFormat)
    }
}

/// Batched glyph command
public struct BatchedGlyphCommand: Sendable {
    public let glyphId: UInt32
    public let position: SIMD2<Float>
    public let uv: SIMD2<Float>
    public let color: SIMD4<Float>
    public let advance: SIMD2<Float>
    
    public init(
        glyphId: UInt32,
        position: SIMD2<Float>,
        uv: SIMD2<Float>,
        color: SIMD4<Float>,
        advance: SIMD2<Float>
    ) {
        self.glyphId = glyphId
        self.position = position
        self.uv = uv
        self.color = color
        self.advance = advance
    }
}

/// Font batched commands
public struct FontBatchedCommands: Sendable {
    public let font: FontDescriptor
    public let vertexBuffer: Data
    public let indexBuffer: Data
    public let commandCount: Int
    
    public init(font: FontDescriptor, vertexBuffer: Data, indexBuffer: Data, commandCount: Int) {
        self.font = font
        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
        self.commandCount = commandCount
    }
}

/// Batched render commands
public struct BatchedRenderCommands: Sendable {
    public let fontCommands: [FontBatchedCommands]
    public let totalGlyphCount: Int
    
    public init(fontCommands: [FontBatchedCommands], totalGlyphCount: Int) {
        self.fontCommands = fontCommands
        self.totalGlyphCount = totalGlyphCount
    }
}

// MARK: - Text Render System Extension

extension TextRenderSystem {
    /// Optimized rendering using performance optimizer
    public func renderTextOptimized(
        _ texts: [String],
        at positions: [SIMD2<Float>],
        withStyles styles: [TextStyle],
        viewportSize: (width: UInt32, height: UInt32),
        optimizer: TextRenderOptimizer
    ) async throws -> [TextRenderResult] {
        // Shape all texts
        let shapedTexts = try await shapeAllTexts(texts, styles: styles)
        
        // Create batched commands if optimization is enabled
        if optimizer.atlasBatchingEnabled && texts.count > 1 {
            return try await renderBatchedText(shapedTexts, styles: styles, viewportSize: viewportSize, optimizer: optimizer)
        } else {
            // Individual rendering
            var results: [TextRenderResult] = []
            for (index, text) in texts.enumerated() {
                guard index < positions.count && index < styles.count else { break }
                
                let result = try await renderText(
                    text,
                    at: positions[index],
                    withStyle: styles[index],
                    viewportSize: viewportSize
                )
                results.append(result)
            }
            return results
        }
    }
    
    private func shapeAllTexts(_ texts: [String], styles: [TextStyle]) async throws -> [ShapedTextResult] {
        var shapedTexts: [ShapedTextResult] = []
        
        for (index, text) in texts.enumerated() {
            guard index < styles.count else { break }
            let shaped = try await shapeText(text, style: styles[index])
            shapedTexts.append(shaped)
        }
        
        return shapedTexts
    }
    
    private func renderBatchedText(
        _ shapedTexts: [ShapedTextResult],
        styles: [TextStyle],
        viewportSize: (width: UInt32, height: UInt32),
        optimizer: TextRenderOptimizer
    ) async throws -> [TextRenderResult] {
        // Create batched commands
        let batchedCommands = try optimizer.createBatchedRenderCommands(
            shapedTexts: shapedTexts,
            styles: styles,
            viewportSize: viewportSize
        )
        
        // Render each font group
        var results: [TextRenderResult] = []
        var currentTime = ContinuousClock.now
        
        for fontCommands in batchedCommands.fontCommands {
            // Create render commands for this font group
            let renderCommands = try createBatchedRenderCommands(
                batchedCommands: fontCommands,
                viewportSize: viewportSize
            )
            
            // Submit to renderer
            let frameResult = try await submitRenderCommands(renderCommands)
            
            // Create result for this batch
            let batchTime = ContinuousClock.now - currentTime
            currentTime = ContinuousClock.now
            
            results.append(TextRenderResult(
                frameId: frameResult.frameId,
                glyphCount: batchedCommands.totalGlyphCount,
                renderTime: batchTime,
                memoryUsage: MemoryUsage(vertexBytes: fontCommands.vertexBuffer.count, atlasBytes: 0),
                performanceMetrics: createPerformanceMetrics(batchTime)
            ))
        }
        
        return results
    }
    
    private func createBatchedRenderCommands(
        batchedCommands: FontBatchedCommands,
        viewportSize: (width: UInt32, height: UInt32)
    ) throws -> RenderFrame {
        // Get pipeline
        let pipelineKey = TextPipelineKey(
            font: batchedCommands.font,
            colorFormat: .rgba8unorm,
            blendMode: .alpha
        )
        
        let textPipeline = try getOrCreateTextPipeline(pipelineKey)
        
        // Create vertex buffer (in real implementation, this would be a Metal buffer)
        let vertexBuffer = RenderBuffer(
            id: UUID(),
            sizeBytes: UInt64(batchedCommands.vertexBuffer.count)
        )
        
        // Create command encoder
        let commandEncoder = try renderer.beginFrame()
        
        // Begin render pass
        let renderPassDescriptor = RenderPassDescriptor(
            colorAttachments: [ColorAttachmentDescriptor()],
            loadAction: .clear,
            storeAction: .store
        )
        
        let renderPass = try commandEncoder.beginRenderPass(renderPassDescriptor)
        
        // Set pipeline and bind resources
        try renderPass.setRenderPipeline(textPipeline)
        try renderPass.setVertexBuffer(vertexBuffer, at: 0)
        
        // In real implementation, we'd bind the actual glyph atlas texture
        // try renderPass.setFragmentTexture(glyphAtlas, at: 0)
        
        // Draw batched commands
        let indexCount = batchedCommands.indexBuffer.count / MemoryLayout<UInt16>.stride
        try renderPass.drawIndexedPrimitives(
            type: .triangle,
            indexCount: UInt32(indexCount),
            indexBuffer: RenderBuffer(id: UUID(), sizeBytes: UInt64(batchedCommands.indexBuffer.count)),
            indexBufferOffset: 0
        )
        
        // End render pass
        try renderPass.endRenderPass()
        
        // Finalize frame
        return try commandEncoder.finalize()
    }
}