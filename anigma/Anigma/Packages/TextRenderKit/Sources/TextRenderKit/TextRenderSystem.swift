import Foundation
import Metal
import RendererKit
import SaturationKit
import CapsuleCore
import AnigmaPrimitives

// Simple console logger for text rendering
enum ConsoleLogger {
    static func log(_ category: String, _ message: String) {
        print("[TextRenderKit][\(category)] \(message)")
    }
}

// MARK: - Text Render System

/// Core text rendering system using Saturated Projections and HarfBuzz integration
public final class TextRenderSystem {
    
    // Core components
    let renderer: any RenderEngine
    let memoryBridge: DSLMemoryBridge
    let shaderManager: any ShaderManager
    let harfBuzzWrapper: HarfBuzzWrapper
    
    // Configuration
    let config: TextRenderConfiguration
    
    // Resource cache
    private var pipelineCache: [TextPipelineKey: RenderPipeline] = [:]
    private var atlasCache: [URL: DSLMappedAtlas] = [:]
    
    // MARK: - Initialization
    
    public init(
        renderer: any RenderEngine,
        memoryBridge: DSLMemoryBridge = DSLMemoryBridge(),
        shaderManager: any ShaderManager,
        harfBuzzWrapper: HarfBuzzWrapper = .shared,
        config: TextRenderConfiguration = .default
    ) {
        self.renderer = renderer
        self.memoryBridge = memoryBridge
        self.shaderManager = shaderManager
        self.harfBuzzWrapper = harfBuzzWrapper
        self.config = config
    }
    
    /// Convenience initializer with default shader manager
    public convenience init(
        renderer: any RenderEngine,
        memoryBridge: DSLMemoryBridge = DSLMemoryBridge(),
        device: MTLDevice,
        harfBuzzWrapper: HarfBuzzWrapper = .shared,
        config: TextRenderConfiguration = .default
    ) throws {
        let shaderManager = try TextShaderManager(device: device)
        self.init(
            renderer: renderer,
            memoryBridge: memoryBridge,
            shaderManager: shaderManager,
            harfBuzzWrapper: harfBuzzWrapper,
            config: config
        )
    }
    
    /// Full Metal renderer initializer
    public convenience init(
        device: MTLDevice,
        memoryBridge: DSLMemoryBridge = DSLMemoryBridge(),
        config: TextRenderConfiguration = .default
    ) throws {
        let metalRenderer = try MetalTextRenderer(device: device)
        let shaderManager = try TextShaderManager(device: device)
        self.init(
            renderer: metalRenderer,
            memoryBridge: memoryBridge,
            shaderManager: shaderManager,
            harfBuzzWrapper: .shared,
            config: config
        )
    }
    
    // MARK: - Text Rendering
    
    /// Render text using the saturated projection pipeline
    public func renderText(
        _ text: String,
        at position: SIMD2<Float>,
        withStyle style: TextStyle,
        viewportSize: (width: UInt32, height: UInt32)
    ) async throws -> TextRenderResult {
        // Start performance measurement
        let startTime = ContinuousClock.now
        
        // Phase 1: Text shaping and layout (HarfBuzz integration placeholder)
        let shapedText = try await shapeText(text, style: style)
        
        // Phase 2: Glyph atlas lookup/creation
        let mappedGlyphAtlas = try await getOrCreateGlyphAtlas(for: style.font)
        
        // Phase 3: Create render commands using saturated projections
        let renderCommands = try await createSaturatedRenderCommands(
            shapedText: shapedText,
            glyphAtlas: mappedGlyphAtlas,
            position: position,
            style: style,
            viewportSize: viewportSize
        )
        
        // Phase 4: Submit to renderer
        let frameResult = try await submitRenderCommands(renderCommands)
        
        // Measure performance
        let endTime = ContinuousClock.now
        let renderTime = endTime - startTime
        
        return TextRenderResult(
            frameId: frameResult.frameId,
            glyphCount: shapedText.glyphCount,
            renderTime: renderTime,
            memoryUsage: estimateMemoryUsage(shapedText, mappedGlyphAtlas),
            performanceMetrics: createPerformanceMetrics(renderTime)
        )
    }
    
    // MARK: - Text Shaping (HarfBuzz Integration)
    
    /// Shape text using HarfBuzz text shaping engine
    private func shapeText(_ text: String, style: TextStyle) async throws -> SystemShapedTextResult {
        do {
            // Use HarfBuzz wrapper for actual text shaping
            let shapedResult = try harfBuzzWrapper.shapeText(
                text,
                fontPath: style.font.atlasURL.path, // In real implementation, this would be the font file
                fontSize: style.size,
                direction: .leftToRight,
                script: .latin,
                language: .english
            )
            
            // Convert HarfBuzz result to our internal format
            var glyphPositions: [GlyphPosition] = []
            var currentX: Float = 0
            
            for glyph in shapedResult.glyphs {
                glyphPositions.append(GlyphPosition(
                    glyphId: glyph.glyphId,
                    position: SIMD2<Float>(currentX + glyph.xOffset, glyph.yOffset),
                    advance: SIMD2<Float>(glyph.xAdvance, glyph.yAdvance)
                ))
                currentX += glyph.xAdvance
            }
            
            return SystemShapedTextResult(
                text: text,
                glyphPositions: glyphPositions,
                advanceWidth: shapedResult.advanceWidth,
                lineHeight: shapedResult.lineHeight
            )
            
        } catch let error as HarfBuzzError {
            // Fallback to simple shaping if HarfBuzz fails
            ConsoleLogger.log(".textRender.fallback", "HarfBuzz shaping failed: \(error), falling back to simple shaping")
            
            return try await simpleShapeText(text, style: style)
        }
    }
    
    /// Simple fallback shaping when HarfBuzz is unavailable
    private func simpleShapeText(_ text: String, style: TextStyle) async throws -> SystemShapedTextResult {
        let glyphCount = text.count
        let advanceWidth = Float(glyphCount) * style.font.size * 0.6
        
        var glyphPositions: [GlyphPosition] = []
        var currentX: Float = 0
        
        for character in text {
            let glyphId = UInt32(character.unicodeScalars.first?.value ?? 0)
            glyphPositions.append(GlyphPosition(
                glyphId: glyphId,
                position: SIMD2<Float>(currentX, 0),
                advance: SIMD2<Float>(style.font.size * 0.6, 0)
            ))
            currentX += style.font.size * 0.6
        }
        
        return SystemShapedTextResult(
            text: text,
            glyphPositions: glyphPositions,
            advanceWidth: advanceWidth,
            lineHeight: style.font.size * 1.2
        )
    }
    
    // MARK: - Glyph Atlas Management
    
    /// Get or create a glyph atlas for the given font
    private func getOrCreateGlyphAtlas(for font: FontDescriptor) async throws -> MappedGlyphAtlas {
        // Check cache first
        if let cachedAtlas = atlasCache[font.atlasURL] {
            return MappedGlyphAtlas(
                mappedAtlas: cachedAtlas,
                font: font,
                glyphMetrics: VerticalGlyphMetrics.default
            )
        }
        
        // Load atlas from disk using DSLMemoryBridge
        let mappedAtlas = try memoryBridge.mapAtlas(
            url: font.atlasURL,
            device: try await getMetalDevice()
        )
        
        // Cache and return
        atlasCache[font.atlasURL] = mappedAtlas
        
        return MappedGlyphAtlas(
            mappedAtlas: mappedAtlas,
            font: font,
            glyphMetrics: VerticalGlyphMetrics.default
        )
    }
    
    /// Get Metal device from renderer (helper method)
    private func getMetalDevice() async throws -> MTLDevice {
        // In a real implementation, this would extract the Metal device
        // from the renderer. For now, return a placeholder.
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TextRenderError.metalDeviceUnavailable
        }
        return device
    }
    
    // MARK: - Saturated Render Command Creation
    
    // MARK: - Saturated Projections Pipeline (CPU Lane)

    /// CPU lane: Create text layout and prepare data for GPU projection
    /// This is the "CPU lane" of the saturated projection pattern
    private func createSaturatedProjectionCPU(
        shapedText: SystemShapedTextResult,
        glyphAtlas: MappedGlyphAtlas,
        position: SIMD2<Float>,
        style: TextStyle
    ) throws -> SaturatedProjectionCPUResult {
        // CPU-side text layout computation
        let startTime = ContinuousClock.now
        
        // Prepare glyph data for GPU projection
        var glyphProjectionData: [GlyphProjectionData] = []
        var totalVertexCount = 0
        
        for glyphPosition in shapedText.glyphPositions {
            // Calculate screen position and glyph metrics
            let screenPos = position + glyphPosition.position
            let glyphSize = style.font.size
            
            // Get UV coordinates from glyph atlas (zero-copy via DSLMemoryBridge)
            let uvRect = try getGlyphUVCoordinates(
                glyphId: glyphPosition.glyphId,
                from: glyphAtlas
            )
            
            // Create projection data for this glyph
            let projectionData = GlyphProjectionData(
                screenX: screenPos.x,
                screenY: screenPos.y,
                screenWidth: glyphSize,
                screenHeight: glyphSize,
                atlasX: Float(uvRect.origin.x),
                atlasY: Float(uvRect.origin.y),
                atlasWidth: Float(uvRect.size.width),
                atlasHeight: Float(uvRect.size.height),
                color: style.color
            )
            
            glyphProjectionData.append(projectionData)
            totalVertexCount += 6 // 2 triangles per glyph
        }
        
        let cpuTime = ContinuousClock.now - startTime
        
        return SaturatedProjectionCPUResult(
            glyphProjectionData: glyphProjectionData,
            totalVertexCount: totalVertexCount,
            cpuProcessingTime: cpuTime,
            glyphAtlas: glyphAtlas
        )
    }

    // MARK: - Saturated Projections Pipeline (GPU Lane)

    /// GPU lane: Generate Metal commands for the saturated projection
    /// This is the "GPU lane" of the saturated projection pattern
    private func createSaturatedProjectionGPU(
        cpuResult: SaturatedProjectionCPUResult,
        viewportSize: (width: UInt32, height: UInt32)
    ) async throws -> RenderFrame {
        let startTime = ContinuousClock.now
        
        // Get or create text render pipeline
        let pipelineKey = TextPipelineKey(
            font: cpuResult.glyphAtlas.font,
            colorFormat: .rgba8unorm,
            blendMode: .alpha
        )
        
        let textPipeline = try await getOrCreateTextPipeline(pipelineKey)
        
        // Create GPU buffers using zero-copy memory where possible
        let vertexBuffer = try createProjectionVertexBuffer(cpuResult.glyphProjectionData)
        
        // Create command encoder
        let commandEncoder = try await renderer.beginFrame()
        
        // Begin render pass with saturated projection configuration
        let renderPassDescriptor = RenderPassDescriptor(
            colorAttachments: [ColorAttachmentDescriptor()],
            loadAction: .clear,
            storeAction: .store
        )
        
        let renderPass = try commandEncoder.beginRenderPass(renderPassDescriptor)
        
        // Set pipeline and bind resources for saturated projection
        try renderPass.setRenderPipeline(textPipeline)
        try renderPass.setVertexBuffer(vertexBuffer, at: 0)
        
        // Bind glyph atlas using DSLMemoryBridge zero-copy buffer
        let atlasBinding = RenderBuffer(
            id: UUID(),
            sizeBytes: UInt64(cpuResult.glyphAtlas.mappedAtlas.buffer.length)
        )
        try renderPass.setFragmentBuffer(atlasBinding, at: 0)
        
        // Draw call - one quad per glyph (saturated projection)
        try renderPass.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: UInt32(cpuResult.totalVertexCount)
        )
        
        // End render pass
        try renderPass.endRenderPass()
        
        // Finalize frame
        let frame = try commandEncoder.finalize()
        
        let gpuTime = ContinuousClock.now - startTime
        ConsoleLogger.log(".projection.gpu", "GPU projection completed in \(gpuTime)ms")
        
        return frame
    }

    /// Create vertex buffer for saturated projection
    private func createProjectionVertexBuffer(_ projectionData: [GlyphProjectionData]) throws -> RenderBuffer {
        // Convert projection data to vertex format
        var vertices: [TextVertex] = []
        
        for glyphData in projectionData {
            let x0 = glyphData.screenX
            let y0 = glyphData.screenY
            let x1 = x0 + glyphData.screenWidth
            let y1 = y0 + glyphData.screenHeight
            
            let uvX0 = glyphData.atlasX
            let uvY0 = glyphData.atlasY
            let uvX1 = uvX0 + glyphData.atlasWidth
            let uvY1 = uvY0 + glyphData.atlasHeight
            
            // Triangle 1
            vertices.append(TextVertex(position: SIMD2(x0, y0), uv: SIMD2(uvX0, uvY0), color: glyphData.color))
            vertices.append(TextVertex(position: SIMD2(x1, y0), uv: SIMD2(uvX1, uvY0), color: glyphData.color))
            vertices.append(TextVertex(position: SIMD2(x0, y1), uv: SIMD2(uvX0, uvY1), color: glyphData.color))
            
            // Triangle 2
            vertices.append(TextVertex(position: SIMD2(x0, y1), uv: SIMD2(uvX0, uvY1), color: glyphData.color))
            vertices.append(TextVertex(position: SIMD2(x1, y0), uv: SIMD2(uvX1, uvY0), color: glyphData.color))
            vertices.append(TextVertex(position: SIMD2(x1, y1), uv: SIMD2(uvX1, uvY1), color: glyphData.color))
        }
        
        // Create GPU buffer
        var data = Data()
        for vertex in vertices {
            data.append(vertex.position.x)
            data.append(vertex.position.y)
            data.append(vertex.uv.x)
            data.append(vertex.uv.y)
            data.append(vertex.color.x)
            data.append(vertex.color.y)
            data.append(vertex.color.z)
            data.append(vertex.color.w)
        }
        
        return try createVertexBuffer(data)
    }

    /// Get UV coordinates for glyph from atlas (zero-copy access)
    private func getGlyphUVCoordinates(glyphId: UInt32, from atlas: MappedGlyphAtlas) throws -> CGRect {
        // In a real implementation, this would use the atlas metadata
        // to look up UV coordinates for the glyph
        // For now, return placeholder values
        return CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    /// Create render commands using saturated projections
    private func createSaturatedRenderCommands(
        shapedText: SystemShapedTextResult,
        glyphAtlas: MappedGlyphAtlas,
        position: SIMD2<Float>,
        style: TextStyle,
        viewportSize: (width: UInt32, height: UInt32)
    ) async throws -> RenderFrame {
        // CPU Lane: Text layout and data preparation
        let cpuResult = try createSaturatedProjectionCPU(
            shapedText: shapedText,
            glyphAtlas: glyphAtlas,
            position: position,
            style: style
        )
        
        // GPU Lane: Metal command generation
        return try await createSaturatedProjectionGPU(
            cpuResult: cpuResult,
            viewportSize: viewportSize
        )
    }
    
    /// Create vertex data for text rendering
    private func createVertexData(
        _ shapedText: ShapedTextResult,
        _ glyphAtlas: GlyphAtlas,
        _ position: SIMD2<Float>,
        _ style: TextStyle
    ) throws -> Data {
        // For each glyph, create a quad with position and UV coordinates
        var vertices: [TextVertex] = []
        
        for glyph in shapedText.glyphs {
            // Calculate screen position
            let screenPos = position + SIMD2<Float>(glyph.xOffset, glyph.yOffset)
            let glyphSize = style.font.size
            
            // Create quad vertices (two triangles)
            let x0 = screenPos.x
            let y0 = screenPos.y
            let x1 = x0 + glyphSize
            let y1 = y0 + glyphSize
            
            // UV coordinates (placeholder - would come from glyph atlas)
            let uvX0: Float = 0.0
            let uvY0: Float = 0.0
            let uvX1: Float = 1.0
            let uvY1: Float = 1.0
            
            // Triangle 1
            vertices.append(TextVertex(position: SIMD2(x0, y0), uv: SIMD2(uvX0, uvY0), color: style.color))
            vertices.append(TextVertex(position: SIMD2(x1, y0), uv: SIMD2(uvX1, uvY0), color: style.color))
            vertices.append(TextVertex(position: SIMD2(x0, y1), uv: SIMD2(uvX0, uvY1), color: style.color))
            
            // Triangle 2
            vertices.append(TextVertex(position: SIMD2(x0, y1), uv: SIMD2(uvX0, uvY1), color: style.color))
            vertices.append(TextVertex(position: SIMD2(x1, y0), uv: SIMD2(uvX1, uvY0), color: style.color))
            vertices.append(TextVertex(position: SIMD2(x1, y1), uv: SIMD2(uvX1, uvY1), color: style.color))
        }
        
        // Convert to Data
        var data = Data()
        for vertex in vertices {
            data.append(vertex.position.x)
            data.append(vertex.position.y)
            data.append(vertex.uv.x)
            data.append(vertex.uv.y)
            data.append(vertex.color.x)
            data.append(vertex.color.y)
            data.append(vertex.color.z)
            data.append(vertex.color.w)
        }
        
        return data
    }
    
    /// Create vertex buffer (placeholder)
    private func createVertexBuffer(_ data: Data) throws -> RenderBuffer {
        // In a real implementation, this would create a GPU buffer
        // For now, return a placeholder
        return RenderBuffer(id: UUID(), sizeBytes: UInt64(data.count))
    }
    
    // MARK: - Pipeline Management
    
    /// Get or create a text render pipeline
    private func getOrCreateTextPipeline(_ key: TextPipelineKey) async throws -> RenderPipeline {
        if let cached = pipelineCache[key] {
            return cached
        }
        
        // Create new pipeline
        let descriptor = RenderPipelineDescriptor(
            vertexFunction: "text_vertex_shader",
            fragmentFunction: "text_fragment_shader",
            vertexAttributes: [
                VertexAttributeDescriptor(name: "position", format: .float2, offset: 0),
                VertexAttributeDescriptor(name: "uv", format: .float2, offset: 8),
                VertexAttributeDescriptor(name: "color", format: .float4, offset: 16)
            ],
            colorAttachmentFormats: [.rgba8unorm],
            blendMode: key.blendMode
        )
        
        let pipeline = try await renderer.getPipeline(descriptor: descriptor)
        pipelineCache[key] = pipeline
        return pipeline
    }
    
    // MARK: - Frame Submission
    
    /// Submit render commands to the renderer
    private func submitRenderCommands(_ frame: RenderFrame) async throws -> FrameSynchronization {
        return try await renderer.submitFrame(frame)
    }
    
    // MARK: - Performance Metrics
    
    /// Estimate memory usage
    private func estimateMemoryUsage(_ shapedText: SystemShapedTextResult, _ glyphAtlas: MappedGlyphAtlas) -> MemoryUsage {
        let vertexMemory = shapedText.glyphPositions.count * 4 * MemoryLayout<TextVertex>.stride
        let atlasMemory = Int(glyphAtlas.mappedAtlas.buffer.length)
        return MemoryUsage(vertexBytes: vertexMemory, atlasBytes: atlasMemory)
    }
    
    /// Create performance metrics
    private func createPerformanceMetrics(_ renderTime: Duration) -> TextRenderMetrics {
        let frameBudget = Duration.milliseconds(16) // 16ms budget
        let budgetUsage = Float(renderTime.components.attoseconds) / Float(frameBudget.components.attoseconds)
        let seconds = Double(renderTime.components.seconds) + Double(renderTime.components.attoseconds) / 1_000_000_000_000_000_000.0
        let fps = seconds > 0 ? 1.0 / seconds : 0
        
        return TextRenderMetrics(
            frameTime: renderTime,
            withinBudget: renderTime <= frameBudget,
            budgetUsage: budgetUsage,
            fps: fps
        )
    }
    
    // MARK: - Cleanup
    
    // MARK: - Memory Optimization

    /// Optimize memory usage based on hardware saturation goals
    public func optimizeMemoryForSaturation() {
        // Apply hardware-aware cache size limits
        optimizeCacheSizes()
        
        // Clean up unused resources
        cleanupUnusedResources()
        
        ConsoleLogger.log(".memory.optimize", "Memory optimized for hardware saturation")
    }
    
    /// Apply hardware-aware cache size limits
    private func optimizeCacheSizes() {
        // Get current memory usage
        let currentMemoryUsage = estimateCurrentMemoryUsage()
        
        // Calculate optimal cache sizes based on available memory
        // Target: Keep memory usage under saturation threshold
        let saturationThreshold = 512 * 1024 * 1024 // 512MB threshold
        
        if currentMemoryUsage > saturationThreshold {
            // Aggressive cleanup if over threshold
            let pipelineTarget = max(16, pipelineCache.count / 2)
            let atlasTarget = max(8, atlasCache.count / 2)
            
            cleanupPipelineCache(toSize: pipelineTarget)
            cleanupAtlasCache(toSize: atlasTarget)
        } else {
            // Normal optimization - keep caches at optimal sizes
            let pipelineTarget = min(64, max(32, pipelineCache.count))
            let atlasTarget = min(32, max(16, atlasCache.count))
            
            cleanupPipelineCache(toSize: pipelineTarget)
            cleanupAtlasCache(toSize: atlasTarget)
        }
    }
    
    /// Clean up unused resources
    private func cleanupUnusedResources() {
        // Clean up pipeline cache
        cleanupPipelineCache(toSize: config.glyphCacheSize)
        
        // Clean up atlas cache
        cleanupAtlasCache(toSize: config.glyphCacheSize / 2)
    }
    
    /// Clean up pipeline cache to target size
    private func cleanupPipelineCache(toSize targetSize: Int) {
        guard pipelineCache.count > targetSize else { return }
        
        let keysToRemove = pipelineCache.keys.prefix(pipelineCache.count - targetSize)
        for key in keysToRemove {
            pipelineCache.removeValue(forKey: key)
        }
        
        ConsoleLogger.log(".cache.pipeline", "Pipeline cache optimized to \(pipelineCache.count) entries")
    }
    
    /// Clean up atlas cache to target size
    private func cleanupAtlasCache(toSize targetSize: Int) {
        guard atlasCache.count > targetSize else { return }
        
        let keysToRemove = atlasCache.keys.prefix(atlasCache.count - targetSize)
        for key in keysToRemove {
            atlasCache.removeValue(forKey: key)
        }
        
        ConsoleLogger.log(".cache.atlas", "Atlas cache optimized to \(atlasCache.count) entries")
    }
    
    /// Estimate current memory usage
    private func estimateCurrentMemoryUsage() -> Int {
        // Estimate pipeline cache memory
        let pipelineMemory = pipelineCache.count * 4 * 1024 // ~4KB per pipeline
        
        // Estimate atlas cache memory
        let atlasMemory = atlasCache.values.reduce(0) { $0 + Int($1.buffer.length) }
        
        return pipelineMemory + atlasMemory
    }

    // MARK: - Cleanup

    public func cleanup() {
        pipelineCache.removeAll()
        atlasCache.values.forEach { _ in
            // Atlas cleanup handled by DSLMappedAtlas deinit
        }
        atlasCache.removeAll()
    }
}

// MARK: - Supporting Types

/// Text rendering configuration
public struct TextRenderConfiguration: Sendable {
    public let enableSubpixelPositioning: Bool
    public let enableLigatures: Bool
    public let enableKerning: Bool
    public let glyphCacheSize: Int
    public let atlasResolution: UInt32
    
    public static let `default` = TextRenderConfiguration(
        enableSubpixelPositioning: true,
        enableLigatures: true,
        enableKerning: true,
        glyphCacheSize: 4096,
        atlasResolution: 2048
    )
    
    public init(
        enableSubpixelPositioning: Bool = true,
        enableLigatures: Bool = true,
        enableKerning: Bool = true,
        glyphCacheSize: Int = 4096,
        atlasResolution: UInt32 = 2048
    ) {
        self.enableSubpixelPositioning = enableSubpixelPositioning
        self.enableLigatures = enableLigatures
        self.enableKerning = enableKerning
        self.glyphCacheSize = glyphCacheSize
        self.atlasResolution = atlasResolution
    }
}

/// Text style descriptor
public struct TextStyle: Sendable {
    public let font: FontDescriptor
    public let color: SIMD4<Float>
    public let size: Float
    
    public init(font: FontDescriptor, color: SIMD4<Float>, size: Float) {
        self.font = font
        self.color = color
        self.size = size
    }
}

/// Font descriptor
public struct FontDescriptor: Sendable, Hashable {
    public let family: String
    public let weight: TextFontWeight
    public let size: Float
    public let atlasURL: URL
    
    public init(family: String, weight: TextFontWeight, size: Float, atlasURL: URL) {
        self.family = family
        self.weight = weight
        self.size = size
        self.atlasURL = atlasURL
    }
}

/// Font weight
public enum TextFontWeight: String, Sendable, Codable, CaseIterable {
    case thin = "Thin"
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    case heavy = "Heavy"
    case black = "Black"
}

/// Shaped text result (from HarfBuzz)
public struct SystemShapedTextResult: Sendable {
    public let text: String
    public let glyphPositions: [GlyphPosition]
    public let advanceWidth: Float
    public let lineHeight: Float
    
    public var glyphCount: Int { glyphPositions.count }
}

/// Glyph position information
public struct GlyphPosition: Sendable {
    public let glyphId: UInt32
    public let position: SIMD2<Float>
    public let advance: SIMD2<Float>
    
    public init(glyphId: UInt32, position: SIMD2<Float>, advance: SIMD2<Float>) {
        self.glyphId = glyphId
        self.position = position
        self.advance = advance
    }
}

/// Glyph atlas
public struct MappedGlyphAtlas: Sendable {
    public let mappedAtlas: DSLMappedAtlas
    public let font: FontDescriptor
    public let glyphMetrics: VerticalGlyphMetrics
    
    public init(mappedAtlas: DSLMappedAtlas, font: FontDescriptor, glyphMetrics: VerticalGlyphMetrics) {
        self.mappedAtlas = mappedAtlas
        self.font = font
        self.glyphMetrics = glyphMetrics
    }
}

/// Glyph metrics
public struct VerticalGlyphMetrics: Sendable {
    public let ascent: Float
    public let descent: Float
    public let lineGap: Float
    
    public static let `default` = VerticalGlyphMetrics(ascent: 0.8, descent: 0.2, lineGap: 0.1)
    
    public init(ascent: Float, descent: Float, lineGap: Float) {
        self.ascent = ascent
        self.descent = descent
        self.lineGap = lineGap
    }
}

/// Text vertex structure
public struct TextVertex: Sendable {
    public let position: SIMD2<Float>
    public let uv: SIMD2<Float>
    public let color: SIMD4<Float>
    
    public init(position: SIMD2<Float>, uv: SIMD2<Float>, color: SIMD4<Float>) {
        self.position = position
        self.uv = uv
        self.color = color
    }
}

/// Glyph projection data for saturated projections
public struct GlyphProjectionData: Sendable {
    public let screenX: Float
    public let screenY: Float
    public let screenWidth: Float
    public let screenHeight: Float
    public let atlasX: Float
    public let atlasY: Float
    public let atlasWidth: Float
    public let atlasHeight: Float
    public let color: SIMD4<Float>
    
    public init(
        screenX: Float,
        screenY: Float,
        screenWidth: Float,
        screenHeight: Float,
        atlasX: Float,
        atlasY: Float,
        atlasWidth: Float,
        atlasHeight: Float,
        color: SIMD4<Float>
    ) {
        self.screenX = screenX
        self.screenY = screenY
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.atlasX = atlasX
        self.atlasY = atlasY
        self.atlasWidth = atlasWidth
        self.atlasHeight = atlasHeight
        self.color = color
    }
}

/// CPU lane result for saturated projections
public struct SaturatedProjectionCPUResult: Sendable {
    public let glyphProjectionData: [GlyphProjectionData]
    public let totalVertexCount: Int
    public let cpuProcessingTime: ContinuousClock.Duration
    public let glyphAtlas: MappedGlyphAtlas
    
    public init(
        glyphProjectionData: [GlyphProjectionData],
        totalVertexCount: Int,
        cpuProcessingTime: ContinuousClock.Duration,
        glyphAtlas: MappedGlyphAtlas
    ) {
        self.glyphProjectionData = glyphProjectionData
        self.totalVertexCount = totalVertexCount
        self.cpuProcessingTime = cpuProcessingTime
        self.glyphAtlas = glyphAtlas
    }
}

/// Pipeline cache key
private struct TextPipelineKey: Hashable, Sendable {
    let font: FontDescriptor
    let colorFormat: TextureFormat
    let blendMode: BlendMode
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(font)
        hasher.combine(colorFormat)
        hasher.combine(blendMode)
    }
}

/// Text render result
public struct TextRenderResult: Sendable {
    public let frameId: UUID
    public let glyphCount: Int
    public let renderTime: Duration
    public let memoryUsage: MemoryUsage
    public let performanceMetrics: TextRenderMetrics
    
    public init(
        frameId: UUID,
        glyphCount: Int,
        renderTime: Duration,
        memoryUsage: MemoryUsage,
        performanceMetrics: TextRenderMetrics
    ) {
        self.frameId = frameId
        self.glyphCount = glyphCount
        self.renderTime = renderTime
        self.memoryUsage = memoryUsage
        self.performanceMetrics = performanceMetrics
    }
}

/// Memory usage metrics
public struct MemoryUsage: Sendable {
    public let vertexBytes: Int
    public let atlasBytes: Int

    public var vertexMemory: Int { vertexBytes }
    public var atlasMemory: Int { atlasBytes }
    
    public var totalBytes: Int { vertexBytes + atlasBytes }
    
    public init(vertexBytes: Int, atlasBytes: Int) {
        self.vertexBytes = vertexBytes
        self.atlasBytes = atlasBytes
    }
}

/// Performance metrics
public struct TextRenderMetrics: Sendable {
    public let frameTime: Duration
    public let withinBudget: Bool
    public let budgetUsage: Float
    public let fps: Double
    
    public init(
        frameTime: Duration,
        withinBudget: Bool,
        budgetUsage: Float,
        fps: Double
    ) {
        self.frameTime = frameTime
        self.withinBudget = withinBudget
        self.budgetUsage = budgetUsage
        self.fps = fps
    }
}

/// Text render errors
public enum TextRenderError: Error, Equatable, Sendable {
    case metalDeviceUnavailable
    case shaderCompilationFailed(String)
    case pipelineCreationFailed
    case atlasLoadingFailed(URL)
    case harfBuzzShapingFailed(String)
    case renderCommandEncodingFailed
    case performanceBudgetExceeded(Duration)
}
