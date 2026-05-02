import Foundation
@preconcurrency import Metal
import AnigmaPrimitives
import CapsuleCore
import CoreGraphics

// MARK: - Text Rendering Configuration

/// Configuration for text rendering operations.
public struct TextRenderingConfig: Sendable {
    public let fontName: String
    public let fontSize: Float
    public let foregroundColor: SIMD4<Float>  // RGBA
    public let bounds: CGRect
    public let lineHeight: Float?  // Optional custom line height; defaults to font metrics
    public let letterSpacing: Float
    public let wordSpacing: Float
    public let alignment: TextAlignment
    
    public init(
        fontName: String = "Helvetica",
        fontSize: Float = 12.0,
        foregroundColor: SIMD4<Float> = SIMD4(1, 1, 1, 1),  // White
        bounds: CGRect = CGRect(x: 0, y: 0, width: 512, height: 512),
        lineHeight: Float? = nil,
        letterSpacing: Float = 0.0,
        wordSpacing: Float = 1.0,
        alignment: TextAlignment = .leading
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.foregroundColor = foregroundColor
        self.bounds = bounds
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.wordSpacing = wordSpacing
        self.alignment = alignment
    }
}

public enum TextAlignment: Sendable {
    case leading
    case center
    case trailing
}

// MARK: - Glyph Layout Result

/// Result of CPU-side text layout computation.
public struct GlyphLayoutResult: Sendable {
    public let glyphs: [LayoutGlyph]
    public let totalBounds: CGRect
    public let lineCount: Int
    public let computationTimeMs: Double
    
    public init(
        glyphs: [LayoutGlyph],
        totalBounds: CGRect,
        lineCount: Int,
        computationTimeMs: Double
    ) {
        self.glyphs = glyphs
        self.totalBounds = totalBounds
        self.lineCount = lineCount
        self.computationTimeMs = computationTimeMs
    }
}

/// Individual glyph layout information.
public struct LayoutGlyph: Sendable {
    public let index: Int
    public let codepoint: UInt32
    public let atlasX: Float
    public let atlasY: Float
    public let atlasWidth: Float
    public let atlasHeight: Float
    public let screenX: Float
    public let screenY: Float
    public let screenWidth: Float
    public let screenHeight: Float
    public let advance: Float
    
    public init(
        index: Int,
        codepoint: UInt32,
        atlasX: Float,
        atlasY: Float,
        atlasWidth: Float,
        atlasHeight: Float,
        screenX: Float,
        screenY: Float,
        screenWidth: Float,
        screenHeight: Float,
        advance: Float
    ) {
        self.index = index
        self.codepoint = codepoint
        self.atlasX = atlasX
        self.atlasY = atlasY
        self.atlasWidth = atlasWidth
        self.atlasHeight = atlasHeight
        self.screenX = screenX
        self.screenY = screenY
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.advance = advance
    }
}

// MARK: - Text Rendering Request & Artifact

public struct TextRenderingRequest {
    public let text: String
    public let config: TextRenderingConfig
    public let atlasBuffer: MTLBuffer?  // Optional pre-mapped atlas via DSLMemoryBridge
    
    public init(
        text: String,
        config: TextRenderingConfig,
        atlasBuffer: MTLBuffer? = nil
    ) {
        self.text = text
        self.config = config
        self.atlasBuffer = atlasBuffer
    }
}

public struct TextRenderingArtifact: Sendable {
    public let layout: GlyphLayoutResult
    public let metalCommandsReady: Bool
    public let estimatedFrameTimeMs: Double
    
    public init(
        layout: GlyphLayoutResult,
        metalCommandsReady: Bool,
        estimatedFrameTimeMs: Double
    ) {
        self.layout = layout
        self.metalCommandsReady = metalCommandsReady
        self.estimatedFrameTimeMs = estimatedFrameTimeMs
    }
}

// MARK: - Text Renderer

/// Core text rendering engine using Saturated Projections.
/// Handles CPU-side text layout and GPU-side Metal command generation.
public actor TextRenderer {
    
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let pipelineState: MTLRenderPipelineState?
    private var layoutCache: [String: GlyphLayoutResult] = [:]
    private let cacheMaxSize: Int = 256
    
    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        
        // Initialize Metal pipeline for text rendering
        if let device = device {
            self.pipelineState = Self.createTextRenderingPipeline(device: device)
        } else {
            self.pipelineState = nil
        }
    }
    
    /// Layouts text using CPU-side text shaping.
    /// This is the "CPU lane" of the saturated projection.
    public func layoutText(_ text: String, config: TextRenderingConfig) async throws -> GlyphLayoutResult {
        let start = Date()
        
        // Check cache first
        let cacheKey = "\(text)_\(config.fontName)_\(config.fontSize)"
        if let cached = layoutCache[cacheKey] {
            return cached
        }
        
        // Perform text layout using HarfBuzz (via GlyphAtlasCapsule integration)
        let glyphs = try await self.shapeText(text, config: config)
        
        // Compute bounds
        var minX: Float = Float.infinity
        var maxX: Float = -Float.infinity
        var minY: Float = Float.infinity
        var maxY: Float = -Float.infinity
        var lineCount = 1
        var currentX: Float = Float(config.bounds.origin.x)
        var currentY: Float = Float(config.bounds.origin.y)
        
        for glyph in glyphs {
            minX = min(minX, glyph.screenX)
            maxX = max(maxX, glyph.screenX + glyph.screenWidth)
            minY = min(minY, glyph.screenY)
            maxY = max(maxY, glyph.screenY + glyph.screenHeight)
            
            // Track line breaks
            if glyph.screenX + glyph.screenWidth > Float(config.bounds.origin.x + config.bounds.size.width) {
                lineCount += 1
                currentY += config.lineHeight ?? (config.fontSize * 1.2)
            }
        }
        
        let totalBounds = CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX),
            height: CGFloat(maxY - minY)
        )
        
        let computationTime = Date().timeIntervalSince(start) * 1000  // Convert to ms
        
        let result = GlyphLayoutResult(
            glyphs: glyphs,
            totalBounds: totalBounds,
            lineCount: lineCount,
            computationTimeMs: computationTime
        )
        
        // Cache result (with eviction if cache is full)
        if layoutCache.count >= cacheMaxSize {
            let oldestKey = layoutCache.keys.first ?? ""
            layoutCache.removeValue(forKey: oldestKey)
        }
        layoutCache[cacheKey] = result
        
        return result
    }
    
    /// Generates Metal rendering commands for laid-out text.
    /// This is the "GPU lane" of the saturated projection.
    public func generateMetalCommands(
        layout: GlyphLayoutResult,
        request: TextRenderingRequest,
        to commandBuffer: MTLCommandBuffer?
    ) async throws -> TextRenderingArtifact {
        let start = Date()
        let frameTimeMs: Double
        
        // If no Metal device or command buffer, mark as ready but measure CPU time only
        if device == nil || commandBuffer == nil {
            frameTimeMs = (Date().timeIntervalSince(start)) * 1000
            return TextRenderingArtifact(
                layout: layout,
                metalCommandsReady: false,
                estimatedFrameTimeMs: frameTimeMs
            )
        }
        
        // Encode Metal render pass
        guard let commandBuffer = commandBuffer,
              let pipelineState = pipelineState
        else {
            frameTimeMs = (Date().timeIntervalSince(start)) * 1000
            return TextRenderingArtifact(
                layout: layout,
                metalCommandsReady: false,
                estimatedFrameTimeMs: frameTimeMs
            )
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        
        // Create render encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            frameTimeMs = (Date().timeIntervalSince(start)) * 1000
            return TextRenderingArtifact(
                layout: layout,
                metalCommandsReady: false,
                estimatedFrameTimeMs: frameTimeMs
            )
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Encode draw calls for each glyph
        for glyph in layout.glyphs {
            // Set vertex/fragment buffers with glyph data
            var glyphData = GlyphVertexData(
                screenX: glyph.screenX,
                screenY: glyph.screenY,
                screenWidth: glyph.screenWidth,
                screenHeight: glyph.screenHeight,
                atlasX: glyph.atlasX,
                atlasY: glyph.atlasY,
                atlasWidth: glyph.atlasWidth,
                atlasHeight: glyph.atlasHeight,
                color: request.config.foregroundColor
            )
            
            let glyphBuffer = device?.makeBuffer(bytes: &glyphData, length: MemoryLayout<GlyphVertexData>.size)
            if let glyphBuffer = glyphBuffer {
                renderEncoder.setVertexBuffer(glyphBuffer, offset: 0, index: 0)
                renderEncoder.setFragmentBuffer(glyphBuffer, offset: 0, index: 0)
            }
            
            // Set atlas texture if available
            if let atlasBuffer = request.atlasBuffer {
                renderEncoder.setFragmentBuffer(atlasBuffer, offset: 0, index: 1)
            }
            
            // Draw glyph quad (6 vertices for 2 triangles)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
        }
        
        renderEncoder.endEncoding()
        
        frameTimeMs = (Date().timeIntervalSince(start)) * 1000
        
        return TextRenderingArtifact(
            layout: layout,
            metalCommandsReady: true,
            estimatedFrameTimeMs: frameTimeMs
        )
    }
    
    // MARK: - Private Methods
    
    private func shapeText(_ text: String, config: TextRenderingConfig) async throws -> [LayoutGlyph] {
        // TODO: Integrate with GlyphAtlasCapsule for HarfBuzz shaping
        // For MVP, perform simple Latin layout
        
        var glyphs: [LayoutGlyph] = []
        var currentX: Float = Float(config.bounds.origin.x)
        var currentY: Float = Float(config.bounds.origin.y)
        let lineHeight = config.lineHeight ?? (config.fontSize * 1.2)
        
        for (index, scalar) in text.unicodeScalars.enumerated() {
            let codepoint = scalar.value
            
            // Simple glyph positioning for Latin script
            // In production, use HarfBuzz for proper shaping
            let glyphWidth = config.fontSize * 0.6  // Approximate character width
            let glyphHeight = config.fontSize
            
            // Word wrapping
            if currentX + glyphWidth > Float(config.bounds.origin.x + config.bounds.size.width) && scalar != " " {
                currentX = Float(config.bounds.origin.x)
                currentY += lineHeight
            }
            
            let glyph = LayoutGlyph(
                index: index,
                codepoint: codepoint,
                atlasX: 0,  // TODO: Query atlas for codepoint
                atlasY: 0,
                atlasWidth: glyphWidth,
                atlasHeight: glyphHeight,
                screenX: currentX,
                screenY: currentY,
                screenWidth: glyphWidth,
                screenHeight: glyphHeight,
                advance: glyphWidth + config.letterSpacing
            )
            
            glyphs.append(glyph)
            currentX += glyph.advance
            
            // Add word spacing for spaces
            if scalar == " " {
                currentX += config.wordSpacing
            }
        }
        
        return glyphs
    }
    
    private static func createTextRenderingPipeline(device: MTLDevice) -> MTLRenderPipelineState? {
        let library = device.makeDefaultLibrary()
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "textVertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "textFragmentShader")
        
        // Configure pixel format for RGBA
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            return nil
        }
    }
    
    /// Clear layout cache (useful for testing and memory management).
    public func clearCache() {
        layoutCache.removeAll()
    }
}

// MARK: - Vertex Data Structure

private struct GlyphVertexData {
    var screenX: Float
    var screenY: Float
    var screenWidth: Float
    var screenHeight: Float
    var atlasX: Float
    var atlasY: Float
    var atlasWidth: Float
    var atlasHeight: Float
    var color: SIMD4<Float>
}
