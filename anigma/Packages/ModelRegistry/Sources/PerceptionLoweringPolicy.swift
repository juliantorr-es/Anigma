//
//  PerceptionLoweringPolicy.swift
//  ModelRegistry
//
//  Policy for vision/document processing models with resolution variants
//  and coordinate system handling.
//

import Foundation

/// Policy for perception models (vision, document processing)
public struct PerceptionLoweringPolicy: LoweringPolicyProtocol {
    /// Workload category this policy applies to
    public let workloadCategory: WorkloadCategory = .perception
    
    /// Base policy configuration
    public let basePolicy: LoweringPolicy
    
    /// Supported resolution variants for dynamic brick generation
    public let resolutionVariants: [Resolution]
    
    /// Coordinate system handling (pixel vs normalized)
    public let coordinateSystem: CoordinateSystem
    
    /// Whether to preserve aspect ratio when resizing
    public let preserveAspectRatio: Bool
    
    /// Padding strategy for fixed-size inputs
    public let paddingStrategy: PaddingStrategy
    
    /// Color space conversion requirements
    public let colorSpaceConversion: ColorSpaceConversion?
    
    /// Whether to apply spatial pyramid pooling
    public let useSpatialPyramidPooling: Bool
    
    /// Whether to enable multi-scale feature extraction
    public let enableMultiScale: Bool
    
    /// Document-specific processing options
    public let documentOptions: DocumentProcessingOptions?
    
    public init(
        basePolicy: LoweringPolicy? = nil,
        resolutionVariants: [Resolution] = [
            Resolution(width: 224, height: 224),
            Resolution(width: 384, height: 384),
            Resolution(width: 512, height: 512),
            Resolution(width: 768, height: 768),
            Resolution(width: 1024, height: 1024)
        ],
        coordinateSystem: CoordinateSystem = .pixel,
        preserveAspectRatio: Bool = true,
        paddingStrategy: PaddingStrategy = .zero,
        colorSpaceConversion: ColorSpaceConversion? = .rgbToBgr,
        useSpatialPyramidPooling: Bool = false,
        enableMultiScale: Bool = false,
        documentOptions: DocumentProcessingOptions? = nil
    ) {
        self.basePolicy = basePolicy ?? LoweringPolicy.default(for: .perception)
        self.resolutionVariants = resolutionVariants
        self.coordinateSystem = coordinateSystem
        self.preserveAspectRatio = preserveAspectRatio
        self.paddingStrategy = paddingStrategy
        self.colorSpaceConversion = colorSpaceConversion
        self.useSpatialPyramidPooling = useSpatialPyramidPooling
        self.enableMultiScale = enableMultiScale
        self.documentOptions = documentOptions
    }
    
    /// Generate dynamic bricks based on input sizes and constraints
    public func generateBricks(
        inputConstraints: InputConstraints,
        memoryBudgetMB: Int? = nil
    ) throws -> [ModelBrick] {
        var bricks: [ModelBrick] = []
        
        // Generate bricks for each resolution variant
        for resolution in resolutionVariants {
            // Check if resolution fits within constraints
            guard resolution.width <= inputConstraints.maxWidth,
                  resolution.height <= inputConstraints.maxHeight else {
                continue
            }
            
            // Calculate memory usage for this resolution
            let estimatedMemory = estimateMemoryUsage(
                resolution: resolution,
                batchSize: inputConstraints.maxBatchSize
            )
            
            // Check memory budget if specified
            if let budget = memoryBudgetMB, estimatedMemory > budget {
                continue
            }
            
            let brick = ModelBrick(
                id: "perception_\(resolution.width)x\(resolution.height)",
                workloadCategory: .perception,
                inputConstraints: InputConstraints(
                    minWidth: resolution.width,
                    maxWidth: resolution.width,
                    minHeight: resolution.height,
                    maxHeight: resolution.height,
                    minBatchSize: 1,
                    maxBatchSize: inputConstraints.maxBatchSize,
                    minChannels: 3,
                    maxChannels: 3
                ),
                memoryBudgetMB: estimatedMemory,
                precision: basePolicy.precision,
                attentionStyle: basePolicy.attentionStyle,
                normalizationType: basePolicy.normalizationType,
                metadata: [
                    "resolution": "\(resolution.width)x\(resolution.height)",
                    "coordinate_system": coordinateSystem.rawValue,
                    "preserve_aspect_ratio": String(preserveAspectRatio),
                    "padding_strategy": paddingStrategy.rawValue,
                    "color_space_conversion": colorSpaceConversion?.rawValue ?? "none",
                    "spatial_pyramid_pooling": String(useSpatialPyramidPooling),
                    "multi_scale": String(enableMultiScale)
                ]
            )
            
            bricks.append(brick)
        }
        
        // If no bricks were generated, create a fallback brick with smallest resolution
        if bricks.isEmpty, let smallestResolution = resolutionVariants.first {
            let brick = ModelBrick(
                id: "perception_fallback_\(smallestResolution.width)x\(smallestResolution.height)",
                workloadCategory: .perception,
                inputConstraints: InputConstraints(
                    minWidth: smallestResolution.width,
                    maxWidth: smallestResolution.width,
                    minHeight: smallestResolution.height,
                    maxHeight: smallestResolution.height,
                    minBatchSize: 1,
                    maxBatchSize: 1,
                    minChannels: 3,
                    maxChannels: 3
                ),
                memoryBudgetMB: estimateMemoryUsage(resolution: smallestResolution, batchSize: 1),
                precision: basePolicy.precision,
                attentionStyle: basePolicy.attentionStyle,
                normalizationType: basePolicy.normalizationType,
                metadata: [
                    "resolution": "\(smallestResolution.width)x\(smallestResolution.height)",
                    "coordinate_system": coordinateSystem.rawValue,
                    "fallback": "true"
                ]
            )
            
            bricks.append(brick)
        }
        
        return bricks
    }
    
    /// Apply policy-specific transformations during lowering
    public func applyTransformations(
        to ir: ModelIR,
        stage: LoweringStage,
        outputDir: URL
    ) async throws -> ModelIR {
        var transformedIR = ir
        
        switch stage {
        case .canonicalization:
            // Apply perception-specific canonicalization
            transformedIR.metadata["perception_canonicalized"] = "true"
            transformedIR.metadata["coordinate_system"] = coordinateSystem.rawValue
            
            if let colorSpace = colorSpaceConversion {
                transformedIR.metadata["color_space_conversion"] = colorSpace.rawValue
            }
            
        case .shapeDiscipline:
            // Apply shape constraints for perception models
            transformedIR.metadata["perception_shape_discipline"] = "true"
            transformedIR.metadata["preserve_aspect_ratio"] = String(preserveAspectRatio)
            transformedIR.metadata["padding_strategy"] = paddingStrategy.rawValue
            
            if useSpatialPyramidPooling {
                transformedIR.metadata["spatial_pyramid_pooling"] = "true"
            }
            
            if enableMultiScale {
                transformedIR.metadata["multi_scale"] = "true"
            }
            
            // Apply document-specific options if present
            if let docOptions = documentOptions {
                transformedIR.metadata["document_processing"] = "true"
                transformedIR.metadata["document_orientation"] = docOptions.orientationHandling.rawValue
                transformedIR.metadata["document_text_detection"] = String(docOptions.enableTextDetection)
            }
            
        default:
            // Use base policy for other stages
            break
        }
        
        return transformedIR
    }
    
    /// Estimate memory usage for a given resolution and batch size
    private func estimateMemoryUsage(resolution: Resolution, batchSize: Int) -> Int {
        // Simplified memory estimation: pixels * channels * batch size * bytes per element
        let pixels = resolution.width * resolution.height
        let channels = 3 // RGB
        let bytesPerElement: Int
        
        switch basePolicy.precision {
        case .fp32:
            bytesPerElement = 4
        case .fp16:
            bytesPerElement = 2
        case .int8:
            bytesPerElement = 1
        case .int4:
            bytesPerElement = 1 // Packed
        case .mixed:
            bytesPerElement = 2 // Average
        }
        
        let baseMemory = pixels * channels * batchSize * bytesPerElement
        
        // Add overhead for intermediate activations (rough estimate: 2x)
        let totalMemory = baseMemory * 2
        
        // Convert to MB
        return totalMemory / (1024 * 1024)
    }
}

/// Coordinate system for perception models
public enum CoordinateSystem: String, Codable, Sendable {
    /// Pixel coordinates (0 to width-1, 0 to height-1)
    case pixel = "pixel"
    
    /// Normalized coordinates (0.0 to 1.0)
    case normalized = "normalized"
    
    /// YOLO-style coordinates (center x, center y, width, height)
    case yolo = "yolo"
    
    /// COCO-style coordinates (x_min, y_min, width, height)
    case coco = "coco"
}

/// Padding strategies for fixed-size inputs
public enum PaddingStrategy: String, Codable, Sendable {
    /// Zero padding
    case zero = "zero"
    
    /// Reflection padding
    case reflection = "reflection"
    
    /// Replication padding
    case replication = "replication"
    
    /// Border padding
    case border = "border"
}

/// Color space conversion requirements
public enum ColorSpaceConversion: String, Codable, Sendable {
    /// RGB to BGR conversion
    case rgbToBgr = "rgb_to_bgr"
    
    /// RGB to grayscale
    case rgbToGray = "rgb_to_gray"
    
    /// BGR to RGB conversion
    case bgrToRgb = "bgr_to_rgb"
    
    /// YUV to RGB conversion
    case yuvToRgb = "yuv_to_rgb"
    
    /// RGB to YUV conversion
    case rgbToYuv = "rgb_to_yuv"
}

/// Document processing options
public struct DocumentProcessingOptions: Codable, Sendable {
    /// Orientation handling strategy
    public let orientationHandling: OrientationHandling
    
    /// Whether to enable text detection
    public let enableTextDetection: Bool
    
    /// Whether to enable layout analysis
    public let enableLayoutAnalysis: Bool
    
    /// Whether to enable OCR post-processing
    public let enableOCRPostProcessing: Bool
    
    /// Target DPI for document processing
    public let targetDPI: Int?
    
    public init(
        orientationHandling: OrientationHandling = .autoDetect,
        enableTextDetection: Bool = true,
        enableLayoutAnalysis: Bool = false,
        enableOCRPostProcessing: Bool = false,
        targetDPI: Int? = 300
    ) {
        self.orientationHandling = orientationHandling
        self.enableTextDetection = enableTextDetection
        self.enableLayoutAnalysis = enableLayoutAnalysis
        self.enableOCRPostProcessing = enableOCRPostProcessing
        self.targetDPI = targetDPI
    }
}

/// Orientation handling strategies
public enum OrientationHandling: String, Codable, Sendable {
    /// Auto-detect orientation
    case autoDetect = "auto_detect"
    
    /// Force portrait orientation
    case forcePortrait = "force_portrait"
    
    /// Force landscape orientation
    case forceLandscape = "force_landscape"
    
    /// Preserve original orientation
    case preserve = "preserve"
}

/// Input constraints for brick generation
public struct InputConstraints: Codable, Sendable {
    public let minWidth: Int
    public let maxWidth: Int
    public let minHeight: Int
    public let maxHeight: Int
    public let minBatchSize: Int
    public let maxBatchSize: Int
    public let minChannels: Int
    public let maxChannels: Int
    
    public init(
        minWidth: Int,
        maxWidth: Int,
        minHeight: Int,
        maxHeight: Int,
        minBatchSize: Int,
        maxBatchSize: Int,
        minChannels: Int = 3,
        maxChannels: Int = 3
    ) {
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.minBatchSize = minBatchSize
        self.maxBatchSize = maxBatchSize
        self.minChannels = minChannels
        self.maxChannels = maxChannels
    }
}

/// Model brick definition
public struct ModelBrick: Codable, Sendable {
    public let id: String
    public let workloadCategory: WorkloadCategory
    public let inputConstraints: InputConstraints
    public let memoryBudgetMB: Int
    public let precision: Precision
    public let attentionStyle: AttentionStyle
    public let normalizationType: NormalizationType
    public let metadata: [String: String]
    
    public init(
        id: String,
        workloadCategory: WorkloadCategory,
        inputConstraints: InputConstraints,
        memoryBudgetMB: Int,
        precision: Precision,
        attentionStyle: AttentionStyle,
        normalizationType: NormalizationType,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.workloadCategory = workloadCategory
        self.inputConstraints = inputConstraints
        self.memoryBudgetMB = memoryBudgetMB
        self.precision = precision
        self.attentionStyle = attentionStyle
        self.normalizationType = normalizationType
        self.metadata = metadata
    }
}

/// Protocol for workload-specific lowering policies
public protocol LoweringPolicyProtocol {
    var workloadCategory: WorkloadCategory { get }
    var basePolicy: LoweringPolicy { get }
    
    func generateBricks(
        inputConstraints: InputConstraints,
        memoryBudgetMB: Int?
    ) throws -> [ModelBrick]
    
    func applyTransformations(
        to ir: ModelIR,
        stage: LoweringStage,
        outputDir: URL
    ) async throws -> ModelIR
}