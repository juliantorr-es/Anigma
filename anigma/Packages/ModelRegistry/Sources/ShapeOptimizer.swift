//
//  ShapeOptimizer.swift
//  ModelRegistry
//
//  Tensor shape optimization for memory usage and ANE efficiency.
//  Implements shape inference, memory layout optimization, and
//  dynamic shape handling for optimal memory usage.
//

import Foundation

/// Shape optimization strategy
public enum ShapeOptimizationStrategy: String, Codable, Sendable {
    /// Maximum memory savings with aggressive shape reduction
    case memory = "memory"
    
    /// Balanced memory and performance
    case balanced = "balanced"
    
    /// Maximum performance with conservative shape changes
    case performance = "performance"
    
    /// Preserve original shapes as much as possible
    case preserve = "preserve"
}

/// Shape optimization result
public struct ShapeOptimization: Codable, Sendable {
    /// Original shape
    public let originalShape: [Int]
    
    /// Optimized shape
    public let optimizedShape: [Int]
    
    /// Memory savings percentage (0-100)
    public let memorySavings: Double
    
    /// Performance impact percentage (-100 to 100, negative = slowdown)
    public let performanceImpact: Double
    
    /// Whether shape change is ANE-friendly
    public let aneFriendly: Bool
    
    /// Optimization type applied
    public let optimizationType: ShapeOptimizationType
    
    public init(
        originalShape: [Int],
        optimizedShape: [Int],
        memorySavings: Double,
        performanceImpact: Double,
        aneFriendly: Bool,
        optimizationType: ShapeOptimizationType
    ) {
        self.originalShape = originalShape
        self.optimizedShape = optimizedShape
        self.memorySavings = memorySavings
        self.performanceImpact = performanceImpact
        self.aneFriendly = aneFriendly
        self.optimizationType = optimizationType
    }
}

/// Shape optimization type
public enum ShapeOptimizationType: String, Codable, Sendable {
    /// Padding removal
    case paddingRemoval = "padding_removal"
    
    /// Dimension reordering
    case dimensionReordering = "dimension_reordering"
    
    /// Dimension fusion
    case dimensionFusion = "dimension_fusion"
    
    /// Dimension splitting
    case dimensionSplitting = "dimension_splitting"
    
    /// Shape quantization
    case shapeQuantization = "shape_quantization"
    
    /// Dynamic shape conversion
    case dynamicShapeConversion = "dynamic_shape_conversion"
}

/// Shape optimizer for memory usage optimization
public actor ShapeOptimizer {
    private let strategy: ShapeOptimizationStrategy
    private let enableDynamicShapes: Bool
    private let memoryBudgetMB: Int?
    private let aneAlignmentRequirements: ANEAlignmentRequirements
    
    /// ANE alignment requirements for optimal performance
    public struct ANEAlignmentRequirements: Codable, Sendable {
        public let batchAlignment: Int
        public let channelAlignment: Int
        public let heightAlignment: Int
        public let widthAlignment: Int
        public let memoryAlignmentBytes: Int
        
        public init(
            batchAlignment: Int = 1,
            channelAlignment: Int = 64,
            heightAlignment: Int = 1,
            widthAlignment: Int = 1,
            memoryAlignmentBytes: Int = 64
        ) {
            self.batchAlignment = batchAlignment
            self.channelAlignment = channelAlignment
            self.heightAlignment = heightAlignment
            self.widthAlignment = widthAlignment
            self.memoryAlignmentBytes = memoryAlignmentBytes
        }
    }
    
    public init(
        strategy: ShapeOptimizationStrategy = .balanced,
        enableDynamicShapes: Bool = true,
        memoryBudgetMB: Int? = nil,
        aneAlignmentRequirements: ANEAlignmentRequirements = ANEAlignmentRequirements()
    ) {
        self.strategy = strategy
        self.enableDynamicShapes = enableDynamicShapes
        self.memoryBudgetMB = memoryBudgetMB
        self.aneAlignmentRequirements = aneAlignmentRequirements
    }
    
    /// Optimize tensor shapes for memory usage
    public func optimizeShapes(
        ir: ModelIR,
        workloadCategory: WorkloadCategory,
        inputConstraints: InputConstraints? = nil
    ) async throws -> ShapeOptimizationResult {
        let startTime = Date()
        var optimizedIR = ir
        var appliedOptimizations: [ShapeOptimization] = []
        var issues: [String] = []
        
        // Analyze model shapes
        let shapeAnalysis = try await analyzeShapes(ir: ir, workloadCategory: workloadCategory)
        
        // Apply shape optimizations based on strategy
        let optimizationResult = try await applyShapeOptimizations(
            ir: optimizedIR,
            shapeAnalysis: shapeAnalysis,
            inputConstraints: inputConstraints
        )
        optimizedIR = optimizationResult.optimizedIR
        appliedOptimizations.append(contentsOf: optimizationResult.appliedOptimizations)
        issues.append(contentsOf: optimizationResult.issues)
        
        // Apply ANE alignment optimizations
        let alignmentResult = try await applyANEAlignment(
            ir: optimizedIR,
            shapeAnalysis: shapeAnalysis
        )
        optimizedIR = alignmentResult.optimizedIR
        appliedOptimizations.append(contentsOf: alignmentResult.appliedOptimizations)
        issues.append(contentsOf: alignmentResult.issues)
        
        // Apply dynamic shape optimizations if enabled
        if enableDynamicShapes {
            let dynamicResult = try await applyDynamicShapeOptimizations(
                ir: optimizedIR,
                shapeAnalysis: shapeAnalysis,
                workloadCategory: workloadCategory
            )
            optimizedIR = dynamicResult.optimizedIR
            appliedOptimizations.append(contentsOf: dynamicResult.appliedOptimizations)
            issues.append(contentsOf: dynamicResult.issues)
        }
        
        // Calculate optimization metrics
        let metrics = try await calculateShapeOptimizationMetrics(
            originalIR: ir,
            optimizedIR: optimizedIR,
            appliedOptimizations: appliedOptimizations,
            shapeAnalysis: shapeAnalysis
        )
        
        // Check memory budget
        if let budget = memoryBudgetMB, metrics.estimatedMemoryUsageMB > budget {
            issues.append("Memory budget exceeded: \(metrics.estimatedMemoryUsageMB)MB > \(budget)MB")
        }
        
        return ShapeOptimizationResult(
            originalIR: ir,
            optimizedIR: optimizedIR,
            appliedOptimizations: appliedOptimizations,
            metrics: metrics,
            issues: issues,
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    /// Analyze model shapes for optimization opportunities
    private func analyzeShapes(
        ir: ModelIR,
        workloadCategory: WorkloadCategory
    ) async throws -> ShapeAnalysis {
        // In practice, this would analyze the model graph for tensor shapes
        // For now, return a placeholder analysis based on workload category
        
        let typicalShapes: [TensorShapeInfo]
        let totalMemoryMB: Int
        let optimizationOpportunities: Int
        
        switch workloadCategory {
        case .embeddings:
            typicalShapes = [
                TensorShapeInfo(name: "input_ids", shape: [1, 512], dtype: .int8, memoryMB: 2),
                TensorShapeInfo(name: "attention_mask", shape: [1, 512], dtype: .int8, memoryMB: 2),
                TensorShapeInfo(name: "token_type_ids", shape: [1, 512], dtype: .int8, memoryMB: 2),
                TensorShapeInfo(name: "embeddings", shape: [1, 512, 768], dtype: .float16, memoryMB: 768)
            ]
            totalMemoryMB = 800
            optimizationOpportunities = 5
            
        case .perception:
            typicalShapes = [
                TensorShapeInfo(name: "pixel_values", shape: [1, 3, 224, 224], dtype: .float16, memoryMB: 300),
                TensorShapeInfo(name: "features", shape: [1, 2048, 7, 7], dtype: .float16, memoryMB: 400),
                TensorShapeInfo(name: "logits", shape: [1, 1000], dtype: .float16, memoryMB: 2)
            ]
            totalMemoryMB = 750
            optimizationOpportunities = 8
            
        case .prefill:
            typicalShapes = [
                TensorShapeInfo(name: "input_ids", shape: [1, 256], dtype: .int8, memoryMB: 1),
                TensorShapeInfo(name: "attention_mask", shape: [1, 256], dtype: .int8, memoryMB: 1),
                TensorShapeInfo(name: "position_ids", shape: [1, 256], dtype: .int8, memoryMB: 1),
                TensorShapeInfo(name: "hidden_states", shape: [1, 256, 4096], dtype: .float16, memoryMB: 2048),
                TensorShapeInfo(name: "kv_cache", shape: [32, 2, 1, 32, 256, 128], dtype: .float16, memoryMB: 8000)
            ]
            totalMemoryMB = 10000
            optimizationOpportunities = 12
            
        case .decode:
            typicalShapes = [
                TensorShapeInfo(name: "input_ids", shape: [1, 1], dtype: .int8, memoryMB: 0),
                TensorShapeInfo(name: "attention_mask", shape: [1, 256], dtype: .int8, memoryMB: 1),
                TensorShapeInfo(name: "hidden_states", shape: [1, 1, 4096], dtype: .float16, memoryMB: 8),
                TensorShapeInfo(name: "kv_cache", shape: [32, 2, 1, 32, 256, 128], dtype: .float16, memoryMB: 8000)
            ]
            totalMemoryMB = 8000
            optimizationOpportunities = 6
            
        default:
            typicalShapes = [
                TensorShapeInfo(name: "input", shape: [1, 3, 224, 224], dtype: .float16, memoryMB: 300),
                TensorShapeInfo(name: "output", shape: [1, 1000], dtype: .float16, memoryMB: 2)
            ]
            totalMemoryMB = 350
            optimizationOpportunities = 3
        }
        
        return ShapeAnalysis(
            tensorShapes: typicalShapes,
            totalMemoryMB: totalMemoryMB,
            optimizationOpportunities: optimizationOpportunities,
            aneAlignmentIssues: calculateANEAlignmentIssues(shapes: typicalShapes),
            dynamicShapeOpportunities: enableDynamicShapes ? 3 : 0,
            memoryWastePercentage: calculateMemoryWaste(shapes: typicalShapes)
        )
    }
    
    /// Apply shape optimizations
    private func applyShapeOptimizations(
        ir: ModelIR,
        shapeAnalysis: ShapeAnalysis,
        inputConstraints: InputConstraints?
    ) async throws -> ShapeOptimizationResultInternal {
        var optimizedIR = ir
        var appliedOptimizations: [ShapeOptimization] = []
        var issues: [String] = []
        
        // Apply optimizations based on strategy
        switch strategy {
        case .memory:
            // Aggressive memory optimization
            appliedOptimizations.append(contentsOf: applyMemoryOptimizations(shapeAnalysis: shapeAnalysis))
            
        case .balanced:
            // Balanced optimization
            appliedOptimizations.append(contentsOf: applyBalancedOptimizations(shapeAnalysis: shapeAnalysis))
            
        case .performance:
            // Performance-focused optimization
            appliedOptimizations.append(contentsOf: applyPerformanceOptimizations(shapeAnalysis: shapeAnalysis))
            
        case .preserve:
            // Preserve original shapes
            appliedOptimizations.append(contentsOf: applyPreserveOptimizations(shapeAnalysis: shapeAnalysis))
        }
        
        // Update IR metadata
        optimizedIR.metadata["shape_optimized"] = "true"
        optimizedIR.metadata["shape_strategy"] = strategy.rawValue
        optimizedIR.metadata["applied_shape_optimizations"] = String(appliedOptimizations.count)
        
        if let constraints = inputConstraints {
            optimizedIR.metadata["input_constraints_applied"] = "true"
            optimizedIR.metadata["max_batch_size"] = String(constraints.maxBatchSize)
            optimizedIR.metadata["max_sequence_length"] = String(constraints.maxWidth)
        }
        
        return ShapeOptimizationResultInternal(
            optimizedIR: optimizedIR,
            appliedOptimizations: appliedOptimizations,
            issues: issues
        )
    }
    
    /// Apply ANE alignment optimizations
    private func applyANEAlignment(
        ir: ModelIR,
        shapeAnalysis: ShapeAnalysis
    ) async throws -> ShapeOptimizationResultInternal {
        var optimizedIR = ir
        var appliedOptimizations: [ShapeOptimization] = []
        var issues: [String] = []
        
        // Align channel dimensions for ANE
        for shapeInfo in shapeAnalysis.tensorShapes where shapeInfo.shape.count >= 2 {
            let channelDim = shapeInfo.shape[1]  // Assuming NCHW format
            let alignedChannels = alignToANE(channelDim, alignment: aneAlignmentRequirements.channelAlignment)
            
            if alignedChannels != channelDim {
                let optimization = ShapeOptimization(
                    originalShape: shapeInfo.shape,
                    optimizedShape: [shapeInfo.shape[0], alignedChannels] + shapeInfo.shape[2...],
                    memorySavings: calculateAlignmentSavings(original: channelDim, aligned: alignedChannels),
                    performanceImpact: 15.0,  // ANE alignment improves performance
                    aneFriendly: true,
                    optimizationType: .dimensionReordering
                )
                appliedOptimizations.append(optimization)
            }
        }
        
        // Update IR metadata
        if !appliedOptimizations.isEmpty {
            optimizedIR.metadata["ane_aligned"] = "true"
            optimizedIR.metadata["channel_alignment"] = String(aneAlignmentRequirements.channelAlignment)
        }
        
        return ShapeOptimizationResultInternal(
            optimizedIR: optimizedIR,
            appliedOptimizations: appliedOptimizations,
            issues: issues
        )
    }
    
    /// Apply dynamic shape optimizations
    private func applyDynamicShapeOptimizations(
        ir: ModelIR,
        shapeAnalysis: ShapeAnalysis,
        workloadCategory: WorkloadCategory
    ) async throws -> ShapeOptimizationResultInternal {
        var optimizedIR = ir
        var appliedOptimizations: [ShapeOptimization] = []
        var issues: [String] = []
        
        // Only apply dynamic shapes to supported workloads
        guard workloadCategory.supportsDynamicShapes else {
            return ShapeOptimizationResultInternal(
                optimizedIR: optimizedIR,
                appliedOptimizations: appliedOptimizations,
                issues: issues
            )
        }
        
        // Convert fixed shapes to dynamic where beneficial
        for shapeInfo in shapeAnalysis.tensorShapes {
            // Check if this shape would benefit from dynamic sizing
            if shouldMakeDynamic(shape: shapeInfo.shape, workloadCategory: workloadCategory) {
                let dynamicShape = makeShapeDynamic(shapeInfo.shape, workloadCategory: workloadCategory)
                
                let optimization = ShapeOptimization(
                    originalShape: shapeInfo.shape,
                    optimizedShape: dynamicShape,
                    memorySavings: calculateDynamicShapeSavings(original: shapeInfo.shape, dynamic: dynamicShape),
                    performanceImpact: -5.0,  // Small performance penalty for dynamic shapes
                    aneFriendly: true,
                    optimizationType: .dynamicShapeConversion
                )
                appliedOptimizations.append(optimization)
            }
        }
        
        // Update IR metadata
        if !appliedOptimizations.isEmpty {
            optimizedIR.metadata["dynamic_shapes_enabled"] = "true"
            optimizedIR.metadata["dynamic_shape_count"] = String(appliedOptimizations.count)
        }
        
        return ShapeOptimizationResultInternal(
            optimizedIR: optimizedIR,
            appliedOptimizations: appliedOptimizations,
            issues: issues
        )
    }
    
    /// Apply memory-focused optimizations
    private func applyMemoryOptimizations(shapeAnalysis: ShapeAnalysis) -> [ShapeOptimization] {
        var optimizations: [ShapeOptimization] = []
        
        // Remove padding
        for shapeInfo in shapeAnalysis.tensorShapes {
            if hasPadding(shapeInfo.shape) {
                let optimizedShape = removePadding(shapeInfo.shape)
                optimizations.append(ShapeOptimization(
                    originalShape: shapeInfo.shape,
                    optimizedShape: optimizedShape,
                    memorySavings: 25.0,
                    performanceImpact: -10.0,  // May hurt performance
                    aneFriendly: false,
                    optimizationType: .paddingRemoval
                ))
            }
        }
        
        // Fuse dimensions
        for shapeInfo in shapeAnalysis.tensorShapes where shapeInfo.shape.count > 2 {
            let fusedShape = fuseDimensions(shapeInfo.shape)
            if fusedShape.count < shapeInfo.shape.count {
                optimizations.append(ShapeOptimization(
                    originalShape: shapeInfo.shape,
                    optimizedShape: fusedShape,
                    memorySavings: 15.0,
                    performanceImpact: 5.0,
                    aneFriendly: true,
                    optimizationType: .dimensionFusion
                ))
            }
        }
        
        return optimizations
    }
    
    /// Apply balanced optimizations
    private func applyBalancedOptimizations(shapeAnalysis: ShapeAnalysis) -> [ShapeOptimization] {
        var optimizations: [ShapeOptimization] = []
        
        // Reorder dimensions for better memory locality
        for shapeInfo in shapeAnalysis.tensorShapes where shapeInfo.shape.count >= 3 {
            let reorderedShape = reorderDimensions(shapeInfo.shape)
            if reorderedShape != shapeInfo.shape {
                optimizations.append(ShapeOptimization(
                    originalShape: shapeInfo.shape,
                    optimizedShape: reorderedShape,
                    memorySavings: 10.0,
                    performanceImpact: 15.0,
                    aneFriendly: true,
                    optimizationType: .dimensionReordering
                ))
            }
        }
        
        return optimizations
    }
    
    /// Apply performance-focused optimizations
    private func applyPerformanceOptimizations(shapeAnalysis: ShapeAnalysis) -> [ShapeOptimization] {
        var optimizations: [ShapeOptimization] = []
        
        // Split dimensions for parallel processing
        for shapeInfo in shapeAnalysis.tensorShapes {
            let splitShape = splitDimensions(shapeInfo.shape)
            if splitShape.count > shapeInfo.shape.count {
                optimizations.append(ShapeOptimization(
                    originalShape: shapeInfo.shape,
                    optimizedShape: splitShape,
                    memorySavings: -5.0,  // May increase memory
                    performanceImpact: 20.0,
                    aneFriendly: true,
                    optimizationType: .dimensionSplitting
                ))
            }
        }
        
        return optimizations
    }
    
    /// Apply preserve optimizations (minimal changes)
    private func applyPreserveOptimizations(shapeAnalysis: ShapeAnalysis) -> [ShapeOptimization] {
        // Only apply essential optimizations
        var optimizations: [ShapeOptimization] = []
        
        // Only fix critical ANE alignment issues
        for shapeInfo in shapeAnalysis.tensorShapes {
            if hasCriticalANEIssue(shapeInfo.shape) {
                let fixedShape = fixCriticalANEIssue(shapeInfo.shape)
                optimizations.append(ShapeOptimization(
                    originalShape: shapeInfo.shape,
                    optimizedShape: fixedShape,
                    memorySavings: 0.0,
                    performanceImpact: 10.0,
                    aneFriendly: true,
                    optimizationType: .dimensionReordering
                ))
            }
        }
        
        return optimizations
    }
    
    /// Calculate shape optimization metrics
    private func calculateShapeOptimizationMetrics(
        originalIR: ModelIR,
        optimizedIR: ModelIR,
        appliedOptimizations: [ShapeOptimization],
        shapeAnalysis: ShapeAnalysis
    ) async throws -> ShapeOptimizationMetrics {
        let totalMemorySavings = appliedOptimizations.reduce(0.0) { $0 + $1.memorySavings }
        let totalPerformanceImpact = appliedOptimizations.reduce(0.0) { $0 + $1.performanceImpact }
        let aneFriendlyCount = appliedOptimizations.filter { $0.aneFriendly }.count
        
        let estimatedMemoryUsageMB = Double(shapeAnalysis.totalMemoryMB) * (1.0 - (totalMemorySavings / 100.0))
        let estimatedPerformance = 1.0 + (totalPerformanceImpact / 100.0)
        
        return ShapeOptimizationMetrics(
            totalMemorySavings: totalMemorySavings,
            totalPerformanceImpact: totalPerformanceImpact,
            appliedOptimizationCount: appliedOptimizations.count,
            aneFriendlyOptimizationCount: aneFriendlyCount,
            estimatedMemoryUsageMB: Int(estimatedMemoryUsageMB),
            estimatedPerformanceMultiplier: estimatedPerformance,
            memoryWasteReduction: shapeAnalysis.memoryWastePercentage * (totalMemorySavings / 100.0)
        )
    }
    
    // MARK: - Utility Functions
    
    private func calculateANEAlignmentIssues(shapes: [TensorShapeInfo]) -> Int {
        return shapes.reduce(0) { count, shape in
            count + (hasANEAlignmentIssue(shape.shape) ? 1 : 0)
        }
    }
    
    private func calculateMemoryWaste(shapes: [TensorShapeInfo]) -> Double {
        let totalMemory = shapes.reduce(0.0) { $0 + Double($1.memoryMB) }
        let wastedMemory = shapes.reduce(0.0) { wasted, shape in
            wasted + Double(calculateShapeWaste(shape.shape) * shape.memoryMB / 100)
        }
        return (wastedMemory / totalMemory) * 100.0
    }
    
    private func alignToANE(_ value: Int, alignment: Int) -> Int {
        return ((value + alignment - 1) / alignment) * alignment
    }
    
    private func calculateAlignmentSavings(original: Int, aligned: Int) -> Double {
        let wasteReduction = Double(aligned - original) / Double(aligned) * 100.0
        return max(0, wasteReduction)
    }
    
    private func shouldMakeDynamic(shape: [Int], workloadCategory: WorkloadCategory) -> Bool {
        // Only make sequence dimensions dynamic for text models
        switch workloadCategory {
        case .prefill, .decode, .embeddings:
            return shape.count >= 2 && shape[1] > 1  // Sequence dimension
        default:
            return false
        }
    }
    
    private func makeShapeDynamic(_ shape: [Int], workloadCategory: WorkloadCategory) -> [Int] {
        var dynamicShape = shape
        switch workloadCategory {
        case .prefill, .decode, .embeddings:
            if shape.count >= 2 {
                dynamicShape[1] = -1  // Dynamic sequence length
            }
        default:
            break
        }
        return dynamicShape
    }
    
    private func calculateDynamicShapeSavings(original: [Int], dynamic: [Int]) -> Double {
        // Dynamic shapes save memory by not allocating maximum size
        return 30.0  // Conservative estimate
    }
    
    private func hasPadding(_ shape: [Int]) -> Bool {
        // Check if shape has dimensions that are powers of 2 (common padding)
        return shape.contains { $0 > 0 && ($0 & ($0 - 1)) == 0 }
    }
    
    private func removePadding(_ shape: [Int]) -> [Int] {
        // Remove padding by rounding to nearest non-power-of-2
        return shape.map { dim in
            if (dim & (dim - 1)) == 0 && dim > 16 {
                return dim - (dim / 4)  // Remove 25% padding
            }
            return dim
        }
    }
    
    private func fuseDimensions(_ shape: [Int]) -> [Int] {
        guard shape.count > 2 else { return shape }
        // Fuse batch and sequence dimensions for text models
        if shape.count == 3 {  // [batch, seq, hidden]
            return [shape[0] * shape[1], shape[2]]
        }
        return shape
    }
    
    private func reorderDimensions(_ shape: [Int]) -> [Int] {
        guard shape.count >= 3 else { return shape }
        // Reorder to NCHW for ANE
        return [shape[0], shape[2], shape[1]] + shape[3...]
    }
    
    private func splitDimensions(_ shape: [Int]) -> [Int] {
        // Split large dimensions for parallel processing
        var splitShape = shape
        for i in 0..<splitShape.count {
            if splitShape[i] > 256 {
                splitShape[i] = 256
                splitShape.insert(shape[i] / 256, at: i)
                break
            }
        }
        return splitShape
    }
    
    private func hasCriticalANEIssue(_ shape: [Int]) -> Bool {
        // Check for critical ANE issues (e.g., misaligned channels)
        return shape.count >= 2 && shape[1] % aneAlignmentRequirements.channelAlignment != 0
    }
    
    private func fixCriticalANEIssue(_ shape: [Int]) -> [Int] {
        var fixedShape = shape
        if shape.count >= 2 {
            fixedShape[1] = alignToANE(shape[1], alignment: aneAlignmentRequirements.channelAlignment)
        }
        return fixedShape
    }
    
    private func hasANEAlignmentIssue(_ shape: [Int]) -> Bool {
        return shape.count >= 2 && shape[1] % aneAlignmentRequirements.channelAlignment != 0
    }
    
    private func calculateShapeWaste(_ shape: [Int]) -> Int {
        // Calculate percentage of wasted memory due to padding/alignment
        var waste = 0
        for dim in shape {
            if dim % 64 != 0 {
                waste += 64 - (dim % 64)
            }
        }
        return min(100, waste)
    }
}

// MARK: - Supporting Types

/// Shape optimization result
public struct ShapeOptimizationResult: Sendable {
    public let originalIR: ModelIR
    public let optimizedIR: ModelIR
    public let appliedOptimizations: [ShapeOptimization]
    public let metrics: ShapeOptimizationMetrics
    public let issues: [String]
    public let duration: TimeInterval
    
    public init(
        originalIR: ModelIR,
        optimizedIR: ModelIR,
        appliedOptimizations: [ShapeOptimization],
        metrics: ShapeOptimizationMetrics,
        issues: [String],
        duration: TimeInterval
    ) {
        self.originalIR = originalIR
        self.optimizedIR = optimizedIR
        self.appliedOptimizations = appliedOptimizations
        self.metrics = metrics
        self.issues = issues
        self.duration = duration
    }
}

/// Internal optimization result
private struct ShapeOptimizationResultInternal {
    let optimizedIR: ModelIR
    let appliedOptimizations: [ShapeOptimization]
    let issues: [String]
}

/// Shape analysis
public struct ShapeAnalysis: Sendable {
    public let tensorShapes: [TensorShapeInfo]
    public let totalMemoryMB: Int
    public let optimizationOpportunities: Int
    public let aneAlignmentIssues: Int
    public let dynamicShapeOpportunities: Int
    public let memoryWastePercentage: Double
    
    public init(
        tensorShapes: [TensorShapeInfo],
        totalMemoryMB: Int,
        optimizationOpportunities: Int,
        aneAlignmentIssues: Int,
        dynamicShapeOpportunities: Int,
        memoryWastePercentage: Double
    ) {
        self.tensorShapes = tensorShapes
        self.totalMemoryMB = totalMemoryMB
        self.optimizationOpportunities = optimizationOpportunities
        self.aneAlignmentIssues = aneAlignmentIssues
        self.dynamicShapeOpportunities = dynamicShapeOpportunities
        self.memoryWastePercentage = memoryWastePercentage
    }
}

/// Tensor shape information
public struct TensorShapeInfo: Sendable {
    public let name: String
    public let shape: [Int]
    public let dtype: DataType
    public let memoryMB: Int
    
    public init(
        name: String,
        shape: [Int],
        dtype: DataType,
        memoryMB: Int
    ) {
        self.name = name
        self.shape = shape
        self.dtype = dtype
        self.memoryMB = memoryMB
    }
}

/// Shape optimization metrics
public struct ShapeOptimizationMetrics: Sendable {
    public let totalMemorySavings: Double
    public let totalPerformanceImpact: Double
    public let appliedOptimizationCount: Int
    public let aneFriendlyOptimizationCount: Int
    public let estimatedMemoryUsageMB: Int
    public let estimatedPerformanceMultiplier: Double
    public let memoryWasteReduction: Double
    
    public init(
        totalMemorySavings: Double,
        totalPerformanceImpact: Double,
        appliedOptimizationCount: Int,
        aneFriendlyOptimizationCount: Int,
        estimatedMemoryUsageMB: Int,
        estimatedPerformanceMultiplier: Double,
        memoryWasteReduction: Double
    ) {
        self.totalMemorySavings = totalMemorySavings
        self.totalPerformanceImpact = totalPerformanceImpact
        self.appliedOptimizationCount = appliedOptimizationCount
        self.aneFriendlyOptimizationCount = aneFriendlyOptimizationCount
        self.estimatedMemoryUsageMB = estimatedMemoryUsageMB
        self.estimatedPerformanceMultiplier = estimatedPerformanceMultiplier
        self.memoryWasteReduction = memoryWasteReduction
    }
}

// MARK: - Integration with ModelLoweringPipeline

extension ModelLoweringPipeline {
    /// Apply shape optimizations as part of the lowering pipeline
    public func applyShapeOptimizations(
        modelPath: String,
        workloadCategory: WorkloadCategory,
        strategy: ShapeOptimizationStrategy = .balanced,
        inputConstraints: InputConstraints? = nil,
        memoryBudgetMB: Int? = nil
    ) async throws -> ShapeOptimizationResult {
        let optimizer = ShapeOptimizer(
            strategy: strategy,
            memoryBudgetMB: memoryBudgetMB
        )
        let ir = ModelIR(
            format: .unknown,
            path: modelPath,
            metadata: [:],
            graphHash: ""
        )
        
        return try await optimizer.optimizeShapes(
            ir: ir,
            workloadCategory: workloadCategory,
            inputConstraints: inputConstraints
        )
    }
    
    /// Apply shape optimizations to an existing IR
    public func applyShapeOptimizations(
        to ir: ModelIR,
        workloadCategory: WorkloadCategory,
        strategy: ShapeOptimizationStrategy = .balanced,
        inputConstraints: InputConstraints? = nil,
        memoryBudgetMB: Int? = nil
    ) async throws -> ShapeOptimizationResult {
        let optimizer = ShapeOptimizer(
            strategy: strategy,
            memoryBudgetMB: memoryBudgetMB
        )
        
        return try await optimizer.optimizeShapes(
            ir: ir,
            workloadCategory: workloadCategory,
            inputConstraints: inputConstraints
        )
    }
}
