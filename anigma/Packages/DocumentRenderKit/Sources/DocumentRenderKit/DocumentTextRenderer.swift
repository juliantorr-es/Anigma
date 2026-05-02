import Foundation
import Metal
import CoreGraphics
import RenderPlanCapsule

/// Integrates TextRenderer into document rendering pipeline.
/// Handles text composition, layout, and rendering coordination with other document elements.
public actor DocumentTextRenderer {
    
    private let textRenderer: TextRenderer
    private let device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var renderedRuns: [String: TextRenderingArtifact] = [:]
    
    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        self.device = device
        self.textRenderer = TextRenderer(device: device)
        self.commandQueue = device?.makeCommandQueue()
    }
    
    /// Renders a text run within document bounds.
    /// Manages layout caching and Metal command generation for document composition.
    public func renderTextRun(
        text: String,
        config: TextRenderingConfig,
        runId: String
    ) async throws -> DocumentTextArtifact {
        let start = Date()
        
        // Layout text
        let layout = try await textRenderer.layoutText(text, config: config)
        
        // Create rendering request
        let request = TextRenderingRequest(text: text, config: config)
        
        // Generate Metal commands if device available
        let artifact = try await textRenderer.generateMetalCommands(
            layout: layout,
            request: request,
            to: commandQueue?.makeCommandBuffer()
        )
        
        // Cache rendered run for document composition
        renderedRuns[runId] = artifact
        
        let elapsed = Date().timeIntervalSince(start) * 1000
        
        return DocumentTextArtifact(
            runId: runId,
            layout: layout,
            frameTimeMs: elapsed,
            cachedForReuse: true
        )
    }
    
    /// Composes multiple text runs into a document structure.
    /// Returns a text layer ready for document rendering pipeline.
    public func composeTextLayers(
        runs: [DocumentTextRun],
        bounds: CGRect
    ) async throws -> DocumentTextLayer {
        var composedArtifacts: [DocumentTextRunArtifact] = []
        var totalTimeMs: Double = 0
        var combinedBounds = CGRect.zero
        
        for run in runs {
            let config = TextRenderingConfig(
                fontName: run.fontName,
                fontSize: run.fontSize,
                foregroundColor: run.color,
                bounds: run.bounds.toCoreGraphicsCGRect(),
                alignment: run.alignment.toRenderPlanAlignment()
            )
            
            let artifact = try await renderTextRun(
                text: run.text,
                config: config,
                runId: run.id
            )
            
            totalTimeMs += artifact.frameTimeMs
            
            // Expand combined bounds
            combinedBounds = combinedBounds.union(artifact.layout.totalBounds)
            
            composedArtifacts.append(DocumentTextRunArtifact(
                runId: run.id,
                layout: artifact.layout,
                frameTimeMs: artifact.frameTimeMs
            ))
        }
        
        return DocumentTextLayer(
            runs: composedArtifacts,
            totalBounds: combinedBounds,
            totalFrameTimeMs: totalTimeMs,
            runCount: composedArtifacts.count
        )
    }
    
    /// Retrieves cached rendering for a run (avoids re-layout on static text).
    public func getCachedArtifact(runId: String) -> TextRenderingArtifact? {
        renderedRuns[runId]
    }
    
    /// Clears cache and resets renderer state.
    public func reset() async {
        renderedRuns.removeAll()
        await textRenderer.clearCache()
    }
}

// MARK: - Document Text Data Structures

/// Describes a single text run (e.g., a paragraph or styled span).
public struct DocumentTextRun: Sendable {
    public let id: String
    public let text: String
    public let fontName: String
    public let fontSize: Float
    public let color: SIMD4<Float>
    public let bounds: CGRect
    public let alignment: TextAlignment
    
    public init(
        id: String,
        text: String,
        fontName: String = "Helvetica",
        fontSize: Float = 12.0,
        color: SIMD4<Float> = SIMD4(0, 0, 0, 1),  // Black
        bounds: CGRect = CGRect(x: 0, y: 0, width: 512, height: 512),
        alignment: TextAlignment = .left
    ) {
        self.id = id
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.color = color
        self.bounds = bounds
        self.alignment = alignment
    }
}

/// Artifact from rendering a single text run in document context.
public struct DocumentTextArtifact: Sendable {
    public let runId: String
    public let layout: GlyphLayoutResult
    public let frameTimeMs: Double
    public let cachedForReuse: Bool
}

/// Individual run artifact in composed document layer.
public struct DocumentTextRunArtifact: Sendable {
    public let runId: String
    public let layout: GlyphLayoutResult
    public let frameTimeMs: Double
}

/// Complete text layer ready for document rendering.
public struct DocumentTextLayer: Sendable {
    public let runs: [DocumentTextRunArtifact]
    public let totalBounds: CGRect
    public let totalFrameTimeMs: Double
    public let runCount: Int
    
    /// Validates frame budget compliance.
    public var isWithinFrameBudget: Bool {
        totalFrameTimeMs < 16.0  // 16ms frame budget for 60 FPS
    }
    
    /// Calculates per-run average time.
    public var averageTimePerRun: Double {
        guard runCount > 0 else { return 0 }
        return totalFrameTimeMs / Double(runCount)
    }
}

// MARK: - Event Integration (for document rendering pipeline coordination)

/// Events published by DocumentTextRenderer for document pipeline coordination.
public enum DocumentTextRenderingEvent: Sendable {
    case renderStarted(runId: String)
    case renderCompleted(runId: String, timeMs: Double)
    case layerComposed(runCount: Int, totalTimeMs: Double)
    case cacheHit(runId: String, savedTimeMs: Double)
}

private extension TextAlignment {
    func toRenderPlanAlignment() -> RenderPlanCapsule.TextAlignment {
        switch self {
        case .left:
            return .leading
        case .center:
            return .center
        case .right, .justify:
            return .trailing
        }
    }
}

private extension CGRect {
    func toCoreGraphicsCGRect() -> CoreGraphics.CGRect {
        CoreGraphics.CGRect(x: x, y: y, width: width, height: height)
    }

    func union(_ other: CoreGraphics.CGRect) -> CGRect {
        let lhs = toCoreGraphicsCGRect()
        let unioned = lhs.union(other)
        return CGRect(
            x: unioned.origin.x,
            y: unioned.origin.y,
            width: unioned.size.width,
            height: unioned.size.height
        )
    }
}
